use crate::{
    agent_fixture::Fixture,
    audit::{AuditedProvider, ToolAudit},
    dataset::{Behavior, Entry},
    mock::{self, Identities},
    scoring::{Observation, ResultRow, score},
    support,
};
use anyhow::{Context, Result, ensure};
use base64::Engine;
use jiabu_agent::{ImageLoader, StartMessage};
use jiabu_ai::*;
use jiabu_db::{Mode, SpaceTx};
use jiabu_domain::JoinEpoch;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    collections::BTreeMap,
    path::Path,
    sync::{Arc, atomic::Ordering},
    time::{Duration, Instant},
};
use uuid::Uuid;

/// Configuration contains no credentials; providers hold the existing credential manager.
pub struct Providers {
    pub config: AiConfig,
    pub providers: Vec<Arc<dyn ModelProvider>>,
    pub prices: Vec<Value>,
}
pub struct Scenario {
    pub f: Fixture,
    pub ids: Identities,
    pub audit: Arc<ToolAudit>,
    pub baseline: Value,
    pub images: Vec<String>,
}
struct Images(BTreeMap<String, String>);
#[async_trait::async_trait]
impl ImageLoader for Images {
    async fn original(&self, sha: &str) -> Result<String, jiabu_db::OperationError> {
        self.0
            .get(sha)
            .cloned()
            .ok_or_else(jiabu_db::OperationError::not_found)
    }
}
impl Scenario {
    pub async fn new(
        e: &Entry,
        root: &Path,
        scratch: &str,
        providers: Option<&Providers>,
        override_scripts: Option<Vec<jiabu_ai::mock::TurnScript>>,
    ) -> Result<Self> {
        let test = support::TestDb::with_url(scratch).await?;
        let mut plan = support::plan("eval-fiction");
        plan.timezone = e.timezone.clone();
        plan.currency = e.setup.currency.clone();
        test.admin()
            .await?
            .create("eval-fiction", "test-only-unused-hash", &plan, "eval")
            .await?;
        let mut f = Fixture::build(test, plan, vec![]).await?;
        f.p.user.locale = e.locale.clone();
        // Worker reconstructs its principal from users, so persist locale too.
        sqlx::query("update users set locale=$1 where id=$2")
            .bind(&e.locale)
            .bind(f.p.user_id.0)
            .execute(&f.owner)
            .await?;
        let mut ids = Identities::default();
        let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Read).await?;
        let ctx = tx.space_context(f.space).await?;
        for tag in ctx["tags"].as_array().context("tags")? {
            if let Some(key) = tag["preset_key"].as_str() {
                ids.tags
                    .insert(key.into(), serde_json::from_value(tag["id"].clone())?);
            }
        }
        tx.commit().await?;
        for account in &e.setup.accounts {
            let result = invoke(
                &f,
                "create_account",
                json!({"kind":account.kind,"name":account.name,"opening_on":account.opening_on}),
            )
            .await?;
            ids.accounts.insert(
                account.key.clone(),
                serde_json::from_value(result["id"].clone())?,
            );
        }
        for record in &e.setup.records {
            let (tool, args) = ids.args(&record.record)?;
            let result = invoke(&f, &tool, args).await?;
            let id: Uuid = serde_json::from_value(result["id"].clone())?;
            ids.records.insert(record.key.clone(), id);
            let version = if record.record.status.as_deref() == Some("voided") {
                invoke(&f, "void_record", json!({"id":id,"expected_version":1})).await?;
                2
            } else {
                1
            };
            ids.versions.insert(record.key.clone(), version);
        }
        let audit = Arc::new(ToolAudit::default());
        let runtime = Arc::get_mut(&mut f.runtime).context("exclusive runtime")?;
        let (config, provider_list) = if let Some(p) = providers {
            (p.config.clone(), p.providers.clone())
        } else {
            let scripts = if let Some(s) = override_scripts {
                s
            } else {
                mock::scripts(e, &ids)?
            };
            let provider = Arc::new(jiabu_ai::mock::MockProvider::scripted(
                "synthetic",
                Capabilities {
                    structured: StructuredMode::ToolCall,
                    vision: true,
                    max_images: 8,
                    context_tokens: 8192,
                },
                scripts,
            ));
            let mut config = runtime.router.0.load().config.clone();
            let model = config.models[0].id;
            config.routes.push(RouteConfig {
                task_kind: TaskKind::ChatVision,
                position: 0,
                model_id: model,
            });
            (config, vec![provider as Arc<dyn ModelProvider>])
        };
        let wrapped = provider_list
            .into_iter()
            .map(|inner| {
                Arc::new(AuditedProvider {
                    inner,
                    registry: runtime.tools.clone(),
                    audit: audit.clone(),
                }) as Arc<dyn ModelProvider>
            })
            .collect();
        runtime.router = Arc::new(RouterStore::default());
        runtime
            .router
            .0
            .store(Arc::new(AiRouter::new(config.clone(), wrapped)));
        import_config(
            &f.test,
            &config,
            providers.map(|p| p.prices.as_slice()).unwrap_or(&[]),
        )
        .await?;
        let mut images = Vec::new();
        let mut loader = BTreeMap::new();
        for file in &e.input.images {
            let bytes =
                std::fs::read(root.join(file)).context("receipt missing; run gen_receipts.py")?;
            ensure!(
                image::guess_format(&bytes)? == image::ImageFormat::Jpeg,
                "invalid receipt"
            );
            let decoded = image::load_from_memory_with_format(&bytes, image::ImageFormat::Jpeg)?;
            let hash: String = Sha256::digest(&bytes)
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect();
            let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
            let digest = Sha256::digest(&bytes);
            tx.save_blob(
                f.space,
                &digest[..],
                i64::try_from(bytes.len())?,
                (
                    i32::try_from(decoded.width())?,
                    i32::try_from(decoded.height())?,
                ),
                chrono::Utc::now(),
            )
            .await?;
            tx.add_blob_ref(f.space, "chat", &digest[..], chrono::Utc::now())
                .await?;
            tx.commit().await?;
            loader.insert(
                hash.clone(),
                format!(
                    "data:image/jpeg;base64,{}",
                    base64::engine::general_purpose::STANDARD.encode(bytes)
                ),
            );
            images.push(hash);
        }
        Arc::get_mut(&mut f.runtime)
            .context("exclusive runtime")?
            .images = Some(Arc::new(Images(loader)));
        let baseline = state(&f).await?;
        Ok(Self {
            f,
            ids,
            audit,
            baseline,
            images,
        })
    }
    pub async fn submit(&self, e: &Entry) -> Result<Uuid> {
        let at = e
            .today
            .and_hms_opt(12, 0, 0)
            .context("fixed time")?
            .and_utc();
        Ok(self
            .f
            .runs()
            .start_at(
                &self.f.p,
                StartMessage {
                    id: Uuid::now_v7(),
                    text: Some(e.input.text.clone()),
                    images: self.images.clone(),
                },
                at,
            )
            .await?
            .message_id)
    }
    pub async fn drive(&self, message: Uuid) -> Result<()> {
        tokio::time::timeout(Duration::from_secs(660), async {
            loop {
                let run = self.f.run(message).await?;
                if !matches!(run.status.as_str(), "queued" | "running" | "waiting_ai") {
                    break;
                }
                if !self.f.work().await? {
                    tokio::time::sleep(Duration::from_millis(50)).await;
                }
            }
            anyhow::Ok(())
        })
        .await
        .context("evaluation deadline")??;
        Ok(())
    }
    async fn drive_scored(&self, message: Uuid) -> Result<bool> {
        match self.drive(message).await {
            Ok(()) => Ok(false),
            Err(error) if error.is::<tokio::time::error::Elapsed>() => {
                // Cancel the persisted run after dropping the worker future;
                // a model deadline is a scored failure, not a passing question.
                self.f.runs().stop(&self.f.p, message).await?;
                Ok(true)
            }
            Err(error) => Err(error),
        }
    }
    pub async fn answer(&self, message: Uuid, payload: Value) -> Result<()> {
        let cp = self.f.checkpoint(message).await?;
        let run = self.f.run(message).await?;
        let block_id = &cp.message.0["interrupt"]["blockId"];
        let block = cp.message.0["blocks"]
            .as_array()
            .context("blocks")?
            .iter()
            .find(|b| &b["id"] == block_id)
            .context("interrupt block")?;
        let action = json!({"protocolVersion":"0.1","id":Uuid::now_v7(),"context":{"conversationId":run.conversation_id,"messageId":message,"blockId":block_id},"type":block["data"]["action"]["type"],"target":block["data"]["action"]["target"],"payload":payload});
        self.f
            .runs()
            .answer(&self.f.p, action, &self.f.runtime.tools)
            .await?;
        Ok(())
    }
    pub async fn observe(
        &self,
        message: Uuid,
        before_confirm: Option<bool>,
        confirmed: bool,
        elapsed_ms: u64,
    ) -> Result<Observation> {
        let run = self.f.run(message).await?;
        let tx = SpaceTx::begin(
            &self.f.db,
            self.f.p.user_id,
            &[(self.f.space, None)],
            Mode::Read,
        )
        .await?;
        let journal = tx.journal(self.f.space, run.id).await?;
        let calls = tx.evaluation_calls(self.f.space, run.id).await?;
        let final_state = tx.evaluation_state(self.f.space).await?;
        tx.commit().await?;
        let mut interrupts = Vec::new();
        for item in &journal {
            if item.kind == "interrupt" {
                interrupts.push(item.payload.clone());
            }
        }
        let tool_calls = journal
            .iter()
            .filter(|i| i.kind == "model_turn")
            .flat_map(|i| i.payload["calls"].as_array().into_iter().flatten())
            .cloned()
            .collect::<Vec<_>>();
        let asked = interrupts.iter().any(|i| {
            tool_calls
                .iter()
                .any(|c| c["tool"] == "ask_user" && c["call_id"] == i["call_id"])
        });
        let confirmation_calls: Vec<_> = tool_calls
            .iter()
            .filter(|c| {
                c["tool"] != "ask_user" && interrupts.iter().any(|i| c["call_id"] == i["call_id"])
            })
            .cloned()
            .collect();
        let confirmation = !confirmation_calls.is_empty();
        Ok(Observation {
            status: run.status,
            asked,
            confirmation,
            confirmation_calls,
            confirmed,
            before_confirm,
            baseline: self.baseline.clone(),
            final_state,
            calls,
            tool_total: self.audit.total.load(Ordering::Relaxed),
            tool_valid: self.audit.valid.load(Ordering::Relaxed),
            business_errors: journal
                .iter()
                .filter(|i| i.kind == "tool_result" && i.payload["output"].get("error").is_some())
                .count(),
            elapsed_ms,
        })
    }
    pub async fn evaluate(&self, e: &Entry) -> Result<ResultRow> {
        let clock = Instant::now();
        let message = self.submit(e).await?;
        let mut timed_out = self.drive_scored(message).await?;
        let mut before = None;
        let mut confirmed = false;
        if e.expect.behavior == Behavior::ConfirmThenWrite
            && self.f.run(message).await?.status == "paused"
        {
            let observation = self.observe(message, None, false, 0).await?;
            if observation.confirmation {
                before = Some(state(&self.f).await? == self.baseline);
                self.answer(message, json!({"outcome":"confirm"})).await?;
                confirmed = true;
                timed_out |= self.drive_scored(message).await?;
            }
        }
        let obs = self
            .observe(
                message,
                before,
                confirmed,
                clock.elapsed().as_millis().min(u64::MAX as u128) as u64,
            )
            .await?;
        let mut row = score(e, &self.ids, &obs);
        if timed_out {
            row.reasons.push("evaluation_timeout".into());
            row.behavior_pass = false;
            if row.hard {
                row.hard_pass = false;
            }
        }
        Ok(row)
    }
}
pub async fn state(f: &Fixture) -> Result<Value> {
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Read).await?;
    let value = tx.evaluation_state(f.space).await?;
    tx.commit().await?;
    Ok(value)
}
pub async fn invoke(f: &Fixture, tool: &str, args: Value) -> Result<Value> {
    let key = Uuid::now_v7();
    let ctx = jiabu_tools::ToolCtx::begin(
        &f.db,
        f.p.clone(),
        f.space,
        Some(JoinEpoch(1)),
        f.runtime.tools.get(tool)?.effect(),
        jiabu_tools::Invocation {
            idempotency_key: Some(key),
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: chrono::Utc::now(),
        },
    )
    .await?;
    Ok(f.runtime.tools.invoke(tool, args, &ctx).await?)
}
async fn import_config(test: &support::TestDb, config: &AiConfig, prices: &[Value]) -> Result<()> {
    use jiabu_db_admin::ai_configuration::{ConfigWrite, PriceInput};
    let admin = test.admin().await?;
    for p in &config.providers {
        admin
            .ai_write(
                ConfigWrite::Provider {
                    config: p.clone(),
                    create: true,
                },
                "eval",
            )
            .await?;
    }
    for m in &config.models {
        admin
            .ai_write(
                ConfigWrite::Model {
                    config: m.clone(),
                    create: true,
                },
                "eval",
            )
            .await?;
    }
    if prices.is_empty() && config.providers.iter().all(|p| p.kind == "mock") {
        for model in &config.models {
            admin
                .ai_write(
                    ConfigWrite::Price(PriceInput {
                        provider_kind: "mock".into(),
                        model: model.model.clone(),
                        currency: "USD".into(),
                        input: "0".into(),
                        cached_input: Some("0".into()),
                        output: "0".into(),
                        cache_write: Some(json!({"default":"0"})),
                        long_context: None,
                        source: "https://example.invalid/synthetic-zero-tariff".into(),
                        as_of: chrono::NaiveDate::from_ymd_opt(2026, 1, 1)
                            .context("tariff date")?,
                        effective_from: chrono::DateTime::parse_from_rfc3339(
                            "2026-01-01T00:00:00Z",
                        )?
                        .with_timezone(&chrono::Utc),
                    }),
                    "eval",
                )
                .await?;
        }
    }
    for price in prices {
        admin
            .ai_write(
                ConfigWrite::Price(serde_json::from_value::<PriceInput>(price.clone())?),
                "eval",
            )
            .await?;
    }
    Ok(())
}
