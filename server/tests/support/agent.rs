//! Shared real-PG Agent fixture; original runtime tests retain their scripts.
#![allow(dead_code)]
use super::support;
use anyhow::{Context, Result};
use jiabu_agent::*;
use jiabu_ai::{
    mock::{MockProvider, MockStep, TurnScript},
    *,
};
use jiabu_chat::*;
use jiabu_db::chat_runtime::RunRow;
use jiabu_db::{AppDb, Mode, Principal, SpaceTx, Via};
use jiabu_domain::{JoinEpoch, SessionId, SpaceId};
use serde_json::{Value, json};
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;
pub struct Fixture {
    pub test: support::TestDb,
    pub db: AppDb,
    pub owner: PgPool,
    pub p: Principal,
    pub space: SpaceId,
    pub runtime: Arc<Runtime>,
    pub mock: Arc<MockProvider>,
    pub hub: Arc<StreamHub>,
}
pub fn done() -> MockStep {
    MockStep::Emit(TurnEvent::Done {
        usage: Usage::default(),
    })
}
pub fn text(s: &str) -> MockStep {
    MockStep::Emit(TurnEvent::TextDelta(s.into()))
}
pub fn call(id: &str, tool: &str, args: Value) -> MockStep {
    MockStep::Emit(TurnEvent::ToolCall {
        call_id: id.into(),
        name: tool.into(),
        args_raw: args.to_string(),
    })
}
pub fn question() -> TurnScript {
    vec![
        call(
            "question",
            "ask_user",
            json!({"prompt":"选择用途 / Choose purpose","options":[{"id":"dining","label":"餐饮 / Dining"},{"id":"transport","label":"交通 / Transport"}]}),
        ),
        done(),
    ]
}
impl Fixture {
    pub async fn new(scripts: Vec<TurnScript>) -> Result<Self> {
        let test = support::TestDb::new().await?;
        let plan = test
            .seed("runtime-fiction", "test-only-unused-hash")
            .await?;
        Self::build(test, plan, scripts).await
    }
    pub async fn build(
        test: support::TestDb,
        plan: jiabu_domain::space_init::SpaceInit,
        scripts: Vec<TurnScript>,
    ) -> Result<Self> {
        let db = AppDb::connect(&test.app_url).await?;
        let owner = test.owner().await?;
        let p = Principal {
            user_id: plan.user_id,
            via: Via::Session {
                session_id: SessionId(Uuid::now_v7()),
                kind: jiabu_db::auth::SessionKind::Full,
            },
            user: jiabu_db::auth::User {
                id: plan.user_id.0,
                username: "runtime-fiction".into(),
                locale: "zh-CN".into(),
            },
        };
        let model = Uuid::now_v7();
        let config = AiConfig {
            providers: vec![ProviderConfig {
                id: "synthetic".into(),
                kind: "mock".into(),
                base_url: None,
                billing: Billing::Local,
                secret_source: None,
                enabled: true,
                version: 1,
            }],
            models: vec![ModelConfig {
                id: model,
                provider_id: "synthetic".into(),
                model: "fake-model".into(),
                structured: StructuredMode::ToolCall,
                vision: true,
                context_tokens: Some(8192),
                enabled: true,
            }],
            routes: vec![RouteConfig {
                task_kind: TaskKind::Chat,
                position: 0,
                model_id: model,
            }],
            ..AiConfig::default()
        };
        let mock = Arc::new(MockProvider::scripted(
            "synthetic",
            Capabilities {
                structured: StructuredMode::ToolCall,
                vision: true,
                max_images: 8,
                context_tokens: 8192,
            },
            scripts,
        ));
        let router = Arc::new(RouterStore::default());
        router
            .0
            .store(Arc::new(AiRouter::new(config, vec![mock.clone()])));
        let templates = Arc::new(jiabu_tools::templates::TemplateStore::empty()?);
        let tools = Arc::new(jiabu_tools::ToolRegistry::with_templates(
            templates.clone(),
        )?);
        let hub = Arc::new(StreamHub::default());
        let runtime = Arc::new(Runtime::new(
            db.clone(),
            router,
            tools,
            templates,
            hub.clone(),
            Arc::new(RuntimeMeter {
                db: db.clone(),
                token: Uuid::now_v7(),
            }),
        ));
        Ok(Self {
            test,
            db,
            owner,
            p,
            space: plan.space_id,
            runtime,
            mock,
            hub,
        })
    }
    pub fn runs(&self) -> ScopedRuns {
        RunService.scoped(
            self.db.clone(),
            self.space,
            JoinEpoch(1),
            self.hub.clone(),
            self.runtime.tools.clone(),
            self.runtime.templates.clone(),
        )
    }
    pub async fn start(&self) -> Result<StartResponse> {
        Ok(self
            .runs()
            .start(
                &self.p,
                StartMessage {
                    id: Uuid::now_v7(),
                    text: Some("虚构输入 / Synthetic input".into()),
                    images: vec![],
                },
            )
            .await?)
    }
    pub async fn run(&self, message: Uuid) -> Result<RunRow> {
        let tx =
            SpaceTx::begin(&self.db, self.p.user_id, &[(self.space, None)], Mode::Write).await?;
        let run = tx
            .run_for_message(self.space, message)
            .await?
            .context("missing run")?;
        tx.commit().await?;
        Ok(run)
    }
    pub async fn checkpoint(&self, message: Uuid) -> Result<Checkpoint> {
        PgCheckpointStore {
            db: self.db.clone(),
            scope: self.scope().await?,
        }
        .load(&message.to_string())
        .await?
        .context("missing checkpoint")
    }
    pub async fn scope(&self) -> Result<ChatScope> {
        let tx =
            SpaceTx::begin(&self.db, self.p.user_id, &[(self.space, None)], Mode::Read).await?;
        let scope = ChatScope {
            space_id: self.space,
            member_id: tx.member(self.space).id(),
            user_id: self.p.user_id,
        };
        tx.commit().await?;
        Ok(scope)
    }
    pub async fn answer(&self, message: Uuid) -> Result<Value> {
        let cp = self.checkpoint(message).await?;
        let run = self.run(message).await?;
        Ok(
            json!({"protocolVersion":"0.1","id":Uuid::now_v7(),"context":{"conversationId":run.conversation_id,"messageId":message,"blockId":cp.message.0["interrupt"]["blockId"]},"type":"choice.select","target":"clarification.answer","payload":{"selected":["dining"]}}),
        )
    }
    pub async fn work(&self) -> Result<bool> {
        Ok(self.runtime.work_once(Uuid::now_v7()).await?)
    }
    pub async fn expire_lease(&self, id: Uuid) -> Result<()> {
        sqlx::query("update agent_runs set lease_until=now()-interval '1 second' where id=$1")
            .bind(id)
            .execute(&self.owner)
            .await?;
        Ok(())
    }
}
