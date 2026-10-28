//! Composition root: runtime-neutral DB and AI crates meet only here.
use anyhow::Result;
use async_trait::async_trait;
use jiabu_ai::{
    CallObserver, Capabilities, ModelProvider, ProviderError, RouterStore, TaskKind, TurnRequest,
    Usage,
    credentials::{
        CredentialManager, FileTokenStore, RefreshGate, SecretKey, TokenStore, VersionedToken,
    },
    siwc::{
        SiwcProvider,
        oauth::{OAuthClient, OAuthCredentials},
    },
};
use jiabu_db::{AppDb, SystemTx, ai_config::ConfigNotifications};
use secrecy::{ExposeSecret, SecretString};
use std::{sync::Arc, time::Duration};
use zeroize::Zeroizing;
struct DatabaseTokens {
    db: AppDb,
    provider: String,
    key: Arc<SecretKey>,
}
#[async_trait]
impl TokenStore for DatabaseTokens {
    async fn load(&self) -> Result<VersionedToken, ProviderError> {
        let tx = SystemTx::begin(&self.db)
            .await
            .map_err(|_| ProviderError::Transport)?;
        let secret = tx
            .ai_secret(&self.provider)
            .await
            .map_err(|_| ProviderError::Transport)?
            .ok_or(ProviderError::Auth)?;
        tx.commit().await.map_err(|_| ProviderError::Transport)?;
        let bytes = self
            .key
            .open("provider", &self.provider, "oauth", &secret)
            .map_err(|_| ProviderError::Auth)?;
        let credentials = serde_json::from_slice(&bytes).map_err(|_| ProviderError::Auth)?;
        Ok(VersionedToken {
            revision: secret.revision,
            credentials,
            usable: secret.usable,
        })
    }
    async fn compare_exchange(
        &self,
        expected: i64,
        next: &OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        let bytes = Zeroizing::new(serde_json::to_vec(next).map_err(|_| ProviderError::Transport)?);
        let secret = self
            .key
            .seal("provider", &self.provider, "oauth", &bytes)
            .map_err(|_| ProviderError::Transport)?;
        let tx = SystemTx::begin(&self.db)
            .await
            .map_err(|_| ProviderError::Transport)?;
        let changed = tx
            .rotate_ai_secret(&self.provider, expected, &secret, next.expires_at)
            .await
            .map_err(|_| ProviderError::Transport)?;
        tx.commit().await.map_err(|_| ProviderError::Transport)?;
        Ok(changed)
    }
    async fn invalidate(&self, expected: i64) -> Result<bool, ProviderError> {
        let tx = SystemTx::begin(&self.db)
            .await
            .map_err(|_| ProviderError::Auth)?;
        let changed = tx
            .invalidate_ai_secret(&self.provider, expected)
            .await
            .map_err(|_| ProviderError::Auth)?;
        tx.commit().await.map_err(|_| ProviderError::Auth)?;
        Ok(changed)
    }
}
struct EnvironmentTokens {
    name: String,
}
#[async_trait]
impl TokenStore for EnvironmentTokens {
    async fn load(&self) -> Result<VersionedToken, ProviderError> {
        let raw = Zeroizing::new(std::env::var(&self.name).map_err(|_| ProviderError::Auth)?);
        let credentials = serde_json::from_str(&raw).map_err(|_| ProviderError::Auth)?;
        Ok(VersionedToken {
            revision: 0,
            credentials,
            usable: true,
        })
    }
    async fn compare_exchange(
        &self,
        _expected: i64,
        _next: &OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        Err(ProviderError::Auth)
    }
    async fn invalidate(&self, _expected: i64) -> Result<bool, ProviderError> {
        Ok(true)
    }
}
fn refresh_gate(provider: &str, source: &str) -> Arc<RefreshGate> {
    type Gates = std::sync::Mutex<std::collections::BTreeMap<String, (String, Arc<RefreshGate>)>>;
    static GATES: std::sync::OnceLock<Gates> = std::sync::OnceLock::new();
    let mut gates = GATES
        .get_or_init(Gates::default)
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let entry = gates
        .entry(provider.to_owned())
        .or_insert_with(|| (source.to_owned(), Arc::new(RefreshGate::default())));
    if entry.0 != source {
        *entry = (source.to_owned(), Arc::new(RefreshGate::default()));
    }
    entry.1.clone()
}
async fn reload(db: &AppDb, store: &RouterStore) -> Result<()> {
    reload_with_key(db, store, SecretKey::from_environment).await
}
async fn reload_with_key(
    db: &AppDb,
    store: &RouterStore,
    read_key: impl FnOnce() -> Result<SecretKey, &'static str>,
) -> Result<()> {
    let config = db.ai_configuration().await?;
    let old = store.0.load_full();
    if config.version == old.config.version
        && config.providers.iter().all(|p| {
            p.secret_source
                .as_deref()
                .is_none_or(|s| !s.starts_with("file:") && !s.starts_with("env:"))
        })
    {
        return Ok(());
    }
    let needs_key = config.providers.iter().any(|p| {
        p.enabled && p.kind == "siwc" && matches!(p.secret_source.as_deref(), None | Some("db"))
    });
    let key = if needs_key {
        Some(Arc::new(read_key().map_err(anyhow::Error::msg)?))
    } else {
        None
    };
    let mut providers: Vec<Arc<dyn ModelProvider>> = vec![];
    for p in &config.providers {
        if !p.enabled || p.kind != "siwc" {
            continue;
        }
        let source: Arc<dyn TokenStore> = match p.secret_source.as_deref() {
            Some(s) if s.starts_with("file:") => Arc::new(FileTokenStore {
                path: s[5..].into(),
            }),
            Some(s) if s.starts_with("env:") => Arc::new(EnvironmentTokens {
                name: s[4..].into(),
            }),
            None | Some("db") => {
                let Some(key) = key.clone() else {
                    anyhow::bail!("master key required");
                };
                Arc::new(DatabaseTokens {
                    db: db.clone(),
                    provider: p.id.clone(),
                    key,
                })
            }
            _ => continue,
        };
        let manager = Arc::new(
            CredentialManager::with_gate(
                source,
                OAuthClient::official()?,
                refresh_gate(&p.id, p.secret_source.as_deref().unwrap_or("db")),
            )
            .await,
        );
        let caps = Capabilities {
            structured: jiabu_ai::StructuredMode::ToolCall,
            vision: true,
            max_images: 8,
            context_tokens: 0,
        };
        providers.push(Arc::new(SiwcProvider::new(p.id.clone(), caps, manager)?));
    }
    store.0.store(Arc::new(old.reloaded(config, providers)));
    Ok(())
}
pub async fn start(
    db: AppDb,
    store: Arc<RouterStore>,
    url: SecretString,
) -> Result<tokio::task::JoinHandle<()>> {
    // Subscribe before the initial load, so startup writes cannot be missed.
    let mut notifications = ConfigNotifications::connect(url.expose_secret()).await?;
    db.recover_lost_ai_calls().await?;
    // The default router is unavailable with version -1 until a load succeeds.
    if reload(&db, &store).await.is_err() {
        tracing::warn!(
            error_kind = "ai_config",
            "Initial AI configuration load failed"
        );
    }
    Ok(tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(60));
        loop {
            tokio::select! { _=interval.tick()=>{}, result=notifications.changed()=>{
                if result.is_err() { tokio::time::sleep(Duration::from_secs(5)).await; }
            } }
            if reload(&db, &store).await.is_err() {
                tracing::warn!(error_kind = "ai_config", "AI configuration reload failed");
            }
        }
    }))
}
/// Public for PR 2's worker composition. One instance belongs to one worker
/// attempt owner; no raw DB handle is exposed by either runtime trait.
#[allow(dead_code)] // PR 2 worker composition; persistence is covered in PR 1 DB tests.
pub struct DatabaseMeter {
    pub db: AppDb,
    pub attempt_token: uuid::Uuid,
    pub call_kind: String,
}
#[async_trait]
impl CallObserver for DatabaseMeter {
    async fn begin(
        &self,
        provider: &str,
        model: &str,
        task: TaskKind,
        request: &TurnRequest,
    ) -> Result<i64, ProviderError> {
        self.db
            .register_ai_call(jiabu_db::ai_metering::CallStart {
                run_id: if task == TaskKind::Probe {
                    None
                } else {
                    Some(request.run_id)
                },
                task: task.as_str(),
                provider,
                model,
                structured: "tool_call",
                call_kind: &self.call_kind,
                attempt_token: self.attempt_token,
            })
            .await
            .map_err(|_| ProviderError::Meter)
    }
    async fn finish(
        &self,
        id: i64,
        elapsed: Duration,
        usage: Option<&Usage>,
        error: Option<&ProviderError>,
    ) -> Result<(), ProviderError> {
        self.db
            .finish_ai_call(jiabu_db::ai_metering::CallFinish {
                id,
                attempt_token: self.attempt_token,
                latency_ms: elapsed.as_millis().min(i32::MAX as u128) as i32,
                usage: usage.map(|u| {
                    [
                        u.input_tokens,
                        u.output_tokens,
                        u.cached_input_tokens,
                        u.cache_write_tokens,
                    ]
                }),
                error_kind: error.map(ProviderError::kind),
            })
            .await
            .map_err(|_| ProviderError::Meter)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use jiabu_db_admin::ai_configuration::ConfigWrite;
    use jiabu_domain::ai::{Billing, ModelConfig, ProviderConfig, StructuredMode};
    #[test]
    fn refresh_state_is_shared_only_for_the_same_provider_and_source() {
        let first = refresh_gate("synthetic-gate", "db");
        assert!(Arc::ptr_eq(&first, &refresh_gate("synthetic-gate", "db")));
        assert!(!Arc::ptr_eq(&first, &refresh_gate("synthetic-other", "db")));
        let file = refresh_gate("synthetic-gate", "file:/tmp/synthetic-a");
        assert!(!Arc::ptr_eq(&first, &file));
        assert!(Arc::ptr_eq(
            &file,
            &refresh_gate("synthetic-gate", "file:/tmp/synthetic-a")
        ));
        let env = refresh_gate("synthetic-gate", "env:SYNTHETIC_A");
        assert!(!Arc::ptr_eq(&file, &env));
        assert!(!Arc::ptr_eq(
            &env,
            &refresh_gate("synthetic-gate", "env:SYNTHETIC_B")
        ));
        assert!(!Arc::ptr_eq(&first, &refresh_gate("synthetic-gate", "db")));
    }
    async fn wait_version(store: &RouterStore, version: i64) -> Result<()> {
        tokio::time::timeout(Duration::from_secs(5), async {
            while store.0.load().config.version <= version {
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
        })
        .await?;
        Ok(())
    }
    #[tokio::test]
    async fn notifications_reload_configuration_and_file_credentials_without_calling_real_provider()
    -> Result<()> {
        let fixture = crate::tasks::test_support::TestDb::new().await?;
        let admin = fixture.admin().await?;
        let dir = fixture.data_dir();
        std::fs::create_dir_all(&dir)?;
        let path = dir.join("synthetic-oauth.json");
        let doc = jiabu_ai::credentials::FileDocument {
            revision: 1,
            usable: true,
            credentials: OAuthCredentials {
                access_token: "synthetic-access".into(),
                refresh_token: "synthetic-refresh".into(),
                client_id: "oaiapp_fake".into(),
                account_id: "synthetic-account".into(),
                expires_at: chrono::Utc::now().timestamp() + 3600,
                host_id: uuid::Uuid::nil(),
            },
        };
        std::fs::write(&path, serde_json::to_vec(&doc)?)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600))?;
        }
        let provider = ProviderConfig {
            id: "synthetic".into(),
            kind: "siwc".into(),
            billing: Billing::Subscription,
            base_url: None,
            secret_source: Some(format!("file:{}", path.display())),
            enabled: true,
            version: 1,
        };
        admin
            .ai_write(
                ConfigWrite::Provider {
                    config: provider.clone(),
                    create: true,
                },
                "test",
            )
            .await?;
        let id = uuid::Uuid::now_v7();
        admin
            .ai_write(
                ConfigWrite::Model {
                    config: ModelConfig {
                        id,
                        provider_id: provider.id.clone(),
                        model: "synthetic-model".into(),
                        structured: StructuredMode::ToolCall,
                        vision: true,
                        context_tokens: Some(32000),
                        enabled: true,
                    },
                    create: true,
                },
                "test",
            )
            .await?;
        admin
            .ai_write(
                ConfigWrite::Route {
                    task: TaskKind::Chat,
                    models: vec![id],
                },
                "test",
            )
            .await?;
        let db = AppDb::connect(&fixture.app_url).await?;
        let store = Arc::new(RouterStore::default());
        let task = start(db.clone(), store.clone(), fixture.app_url.clone().into()).await?;
        assert!(store.0.load().availability(TaskKind::Chat).available);
        let version = store.0.load().config.version;
        admin
            .ai_write(
                ConfigWrite::ProviderEnabled {
                    id: "synthetic".into(),
                    enabled: false,
                },
                "test",
            )
            .await?;
        wait_version(&store, version).await?;
        assert!(!store.0.load().availability(TaskKind::Chat).available);
        let version = store.0.load().config.version;
        admin
            .ai_write(
                ConfigWrite::ProviderEnabled {
                    id: "synthetic".into(),
                    enabled: true,
                },
                "test",
            )
            .await?;
        wait_version(&store, version).await?;
        assert!(store.0.load().availability(TaskKind::Chat).available);
        // Both route/config and credential status are used by the same status path.
        let tokens = FileTokenStore { path };
        let current = tokens.load().await?;
        assert!(tokens.invalidate(current.revision).await?);
        let version = store.0.load().config.version;
        admin
            .ai_write(
                ConfigWrite::Route {
                    task: TaskKind::Chat,
                    models: vec![id],
                },
                "test",
            )
            .await?;
        wait_version(&store, version).await?;
        assert!(!store.0.load().availability(TaskKind::Chat).available);
        // Verify the metering trait adapter without invoking any provider transport.
        let meter = DatabaseMeter {
            db: db.clone(),
            attempt_token: uuid::Uuid::now_v7(),
            call_kind: "first".into(),
        };
        let request = TurnRequest {
            run_id: uuid::Uuid::nil(),
            session_key: "synthetic-session".into(),
            snapshot: jiabu_ai::PromptSnapshot {
                instructions: String::new(),
                tools: vec![],
                model: "unknown-model".into(),
                parameters: jiabu_ai::ModelParameters::default(),
            },
            items: vec![],
            provider_blobs: vec![],
        };
        let call = meter
            .begin("synthetic", "unknown-model", TaskKind::Probe, &request)
            .await?;
        meter
            .finish(
                call,
                Duration::from_millis(1),
                Some(&Usage::default()),
                None,
            )
            .await?;
        // completed usage must survive a subsequent journal failure, including cost.
        let owner = fixture.owner().await?;
        sqlx::query("insert into ai_prices(provider_kind,model,input,cached_input,output,cache_write,source,as_of,effective_from) values('siwc','unknown-model',10,2,20,'{\"default\":\"12\"}','https://example.invalid/prices',current_date,now()-interval '1 day')")
            .execute(&owner)
            .await?;
        struct CompletedTool(Capabilities);
        #[async_trait]
        impl ModelProvider for CompletedTool {
            fn id(&self) -> &str {
                "synthetic"
            }
            fn capabilities(&self) -> &Capabilities {
                &self.0
            }
            async fn run_turn(
                &self,
                req: &TurnRequest,
                sink: &mut dyn jiabu_ai::TurnSink,
            ) -> Result<(), ProviderError> {
                let mut state = jiabu_ai::siwc::stream::TurnState::default();
                state
                    .accept(
                        serde_json::json!({
                            "type":"response.output_item.done", "output_index":0,
                            "item":{"type":"function_call","call_id":"synthetic-call","name":"create_record","arguments":"{}"}
                        }),
                        sink,
                    )
                    .await?;
                state
                    .accept(
                        serde_json::json!({
                            "type":"response.completed", "response":{"status":"completed","usage":{
                                "input_tokens":100,"output_tokens":20,
                                "input_tokens_details":{"cached_tokens":60,"cache_write_tokens":10}
                            }}
                        }),
                        sink,
                    )
                    .await?;
                state
                    .finish(self.id(), &req.snapshot.model, "synthetic-account", sink)
                    .await
            }
        }
        struct FailTool;
        #[async_trait]
        impl jiabu_ai::TurnSink for FailTool {
            async fn emit(&mut self, event: jiabu_ai::TurnEvent) -> Result<(), ProviderError> {
                assert!(matches!(event, jiabu_ai::TurnEvent::ToolCall { .. }));
                Err(ProviderError::Sink)
            }
        }
        assert_eq!(
            jiabu_ai::measured_attempt(
                &CompletedTool(Capabilities {
                    structured: StructuredMode::ToolCall,
                    vision: true,
                    max_images: 8,
                    context_tokens: 32000,
                }),
                TaskKind::Probe,
                &request,
                &mut FailTool,
                &meter,
                Duration::from_secs(30),
            )
            .await,
            Err(ProviderError::Sink)
        );
        let row: (String, String, i32, i32, i32, i32, bool, bool) = sqlx::query_as(
            "select outcome,error_kind,input_tokens,output_tokens,cached_input_tokens,cache_write_tokens,cost_usd=0.00094,completed_at is not null from ai_calls where attempt_token=$1 order by id desc limit 1",
        )
        .bind(meter.attempt_token)
        .fetch_one(&owner)
        .await?;
        assert_eq!(
            row,
            ("failed".into(), "sink".into(), 100, 20, 60, 10, true, true)
        );
        owner.close().await;
        task.abort();
        let _ = task.await;
        // A hung provider must finish the durable row before the router returns Timeout.
        let mut config = store.0.load().config.clone();
        config.routes[0].task_kind = TaskKind::Probe;
        let barrier = Arc::new(tokio::sync::Barrier::new(2));
        let mock = jiabu_ai::mock::MockProvider::scripted(
            "synthetic",
            Capabilities {
                structured: StructuredMode::ToolCall,
                vision: true,
                max_images: 8,
                context_tokens: 32000,
            },
            vec![vec![
                jiabu_ai::mock::MockStep::Barrier(barrier.clone()),
                jiabu_ai::mock::MockStep::Delay(Duration::from_secs(600)),
            ]],
        );
        let router = jiabu_ai::AiRouter::new(config, vec![Arc::new(mock)]);
        struct Discard;
        #[async_trait]
        impl jiabu_ai::TurnSink for Discard {
            async fn emit(&mut self, _: jiabu_ai::TurnEvent) -> Result<(), ProviderError> {
                Ok(())
            }
        }
        let attempt_token = meter.attempt_token;
        let pending = tokio::spawn(async move {
            router
                .run_turn(TaskKind::Probe, &request, &mut Discard, &meter)
                .await
        });
        barrier.wait().await;
        tokio::task::yield_now().await;
        tokio::time::pause();
        tokio::time::advance(jiabu_ai::breaker::CALL_TIMEOUT + Duration::from_secs(1)).await;
        tokio::time::resume();
        assert_eq!(pending.await?, Err(ProviderError::Timeout));
        let owner = fixture.owner().await?;
        let row: (String, String, bool) = sqlx::query_as(
            "select outcome,error_kind,completed_at is not null from ai_calls where attempt_token=$1 order by id desc limit 1",
        )
        .bind(attempt_token)
        .fetch_one(&owner)
        .await?;
        assert_eq!(row, ("failed".into(), "timeout".into(), true));
        owner.close().await;

        // Missing master key must preserve the published router and its version.
        let mut db_provider = provider;
        db_provider.secret_source = Some("db".into());
        admin
            .ai_write(
                ConfigWrite::Provider {
                    config: db_provider,
                    create: false,
                },
                "test",
            )
            .await?;
        let key =
            SecretKey::new("synthetic-key".into(), vec![7; 32]).map_err(anyhow::Error::msg)?;
        let secret = key
            .seal(
                "provider",
                "synthetic",
                "oauth",
                &serde_json::to_vec(&doc.credentials)?,
            )
            .map_err(anyhow::Error::msg)?;
        admin
            .ai_save_oauth(
                "synthetic",
                &secret,
                &doc.credentials.client_id,
                doc.credentials.expires_at,
                "test",
            )
            .await?;
        let old = store.0.load_full();
        assert!(
            reload_with_key(&db, &store, || Err("temporarily unreadable"))
                .await
                .is_err()
        );
        assert!(Arc::ptr_eq(&old, &store.0.load_full()));
        assert_eq!(store.0.load().config.version, old.config.version);

        // Startup publishes the default unavailable status with an unloaded version.
        let initial = RouterStore::default();
        assert!(
            reload_with_key(&db, &initial, || Err("temporarily unreadable"))
                .await
                .is_err()
        );
        assert!(!initial.0.load().availability(TaskKind::Chat).available);
        assert_eq!(initial.0.load().config.version, -1);
        let version = db.ai_configuration().await?.version;
        // The next fallback uses the same reload path, with no configuration change.
        reload_with_key(&db, &initial, || Ok(key)).await?;
        assert_eq!(initial.0.load().config.version, version);
        assert!(initial.0.load().availability(TaskKind::Chat).available);
        reload_with_key(&db, &initial, || Err("must not reread a loaded version")).await?;
        assert!(initial.0.load().availability(TaskKind::Chat).available);
        db.close().await?;
        Ok(())
    }
}
