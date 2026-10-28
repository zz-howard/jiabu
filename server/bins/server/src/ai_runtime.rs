//! Composition root: runtime-neutral DB and AI crates meet only here.
use anyhow::Result;
use async_trait::async_trait;
use jiabu_ai::{
    CallObserver, Capabilities, ModelProvider, ProviderError, RouterStore, TaskKind, TurnRequest,
    Usage,
    credentials::{CredentialManager, FileTokenStore, SecretKey, TokenStore, VersionedToken},
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
            .map_err(|_| ProviderError::Auth)?;
        let secret = tx
            .ai_secret(&self.provider)
            .await
            .map_err(|_| ProviderError::Auth)?
            .ok_or(ProviderError::Auth)?;
        tx.commit().await.map_err(|_| ProviderError::Auth)?;
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
        let bytes = Zeroizing::new(serde_json::to_vec(next).map_err(|_| ProviderError::Auth)?);
        let secret = self
            .key
            .seal("provider", &self.provider, "oauth", &bytes)
            .map_err(|_| ProviderError::Auth)?;
        let tx = SystemTx::begin(&self.db)
            .await
            .map_err(|_| ProviderError::Auth)?;
        let changed = tx
            .rotate_ai_secret(&self.provider, expected, &secret, next.expires_at)
            .await
            .map_err(|_| ProviderError::Auth)?;
        tx.commit().await.map_err(|_| ProviderError::Auth)?;
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
fn refresh_gate(provider: &str) -> Arc<tokio::sync::Mutex<()>> {
    type Gates = std::sync::Mutex<std::collections::BTreeMap<String, Arc<tokio::sync::Mutex<()>>>>;
    static GATES: std::sync::OnceLock<Gates> = std::sync::OnceLock::new();
    let mut gates = GATES
        .get_or_init(Gates::default)
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    gates
        .entry(provider.to_owned())
        .or_insert_with(|| Arc::new(tokio::sync::Mutex::new(())))
        .clone()
}
async fn reload(db: &AppDb, store: &RouterStore) -> Result<()> {
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
    let key = SecretKey::from_environment().ok().map(Arc::new);
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
                    continue;
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
            CredentialManager::with_gate(source, OAuthClient::official()?, refresh_gate(&p.id))
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
    reload(&db, &store).await?;
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
        task.abort();
        let _ = task.await;
        db.close().await?;
        Ok(())
    }
}
