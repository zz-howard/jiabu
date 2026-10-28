//! Synthetic conversations, real PG18, scripted providers. Never a live model.
#[path = "../../../tests/support/mod.rs"]
mod support;
use anyhow::{Context, Result};
use futures_util::StreamExt;
use jiabu_agent::*;
use jiabu_ai::{
    mock::{MockProvider, MockStep, TurnScript},
    *,
};
use jiabu_chat::{PgCheckpointStore, PgEventLog, *};
use jiabu_db::chat_runtime::{RunLease, RunRow};
use jiabu_db::{AppDb, Mode, Principal, SpaceTx, Via};
use jiabu_domain::{JoinEpoch, SessionId, SpaceId};
use serde_json::{Value, json};
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;
struct Fixture {
    test: support::TestDb,
    db: AppDb,
    owner: PgPool,
    p: Principal,
    space: SpaceId,
    runtime: Arc<Runtime>,
    mock: Arc<MockProvider>,
    hub: Arc<StreamHub>,
}
fn done() -> MockStep {
    MockStep::Emit(TurnEvent::Done {
        usage: Usage::default(),
    })
}
fn text(s: &str) -> MockStep {
    MockStep::Emit(TurnEvent::TextDelta(s.into()))
}
fn call(id: &str, tool: &str, args: Value) -> MockStep {
    MockStep::Emit(TurnEvent::ToolCall {
        call_id: id.into(),
        name: tool.into(),
        args_raw: args.to_string(),
    })
}
fn question() -> TurnScript {
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
    async fn new(scripts: Vec<TurnScript>) -> Result<Self> {
        let test = support::TestDb::new().await?;
        let plan = test
            .seed("runtime-fiction", "test-only-unused-hash")
            .await?;
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
    fn runs(&self) -> ScopedRuns {
        RunService.scoped(
            self.db.clone(),
            self.space,
            JoinEpoch(1),
            self.hub.clone(),
            self.runtime.tools.clone(),
            self.runtime.templates.clone(),
        )
    }
    async fn start(&self) -> Result<StartResponse> {
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
    async fn run(&self, message: Uuid) -> Result<RunRow> {
        let tx =
            SpaceTx::begin(&self.db, self.p.user_id, &[(self.space, None)], Mode::Write).await?;
        let run = tx
            .run_for_message(self.space, message)
            .await?
            .context("missing run")?;
        tx.commit().await?;
        Ok(run)
    }
    async fn checkpoint(&self, message: Uuid) -> Result<Checkpoint> {
        PgCheckpointStore {
            db: self.db.clone(),
            scope: self.scope().await?,
        }
        .load(&message.to_string())
        .await?
        .context("missing checkpoint")
    }
    async fn scope(&self) -> Result<ChatScope> {
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
    async fn answer(&self, message: Uuid) -> Result<Value> {
        let cp = self.checkpoint(message).await?;
        let run = self.run(message).await?;
        Ok(
            json!({"protocolVersion":"0.1","id":Uuid::now_v7(),"context":{"conversationId":run.conversation_id,"messageId":message,"blockId":cp.message.0["interrupt"]["blockId"]},"type":"choice.select","target":"clarification.answer","payload":{"selected":["dining"]}}),
        )
    }
    async fn work(&self) -> Result<bool> {
        Ok(self.runtime.work_once(Uuid::now_v7()).await?)
    }
    async fn expire_lease(&self, id: Uuid) -> Result<()> {
        sqlx::query("update agent_runs set lease_until=now()-interval '1 second' where id=$1")
            .bind(id)
            .execute(&self.owner)
            .await?;
        Ok(())
    }
}
#[tokio::test]
async fn mock_text_finishes_with_rev_one_and_durable_ordered_events() -> Result<()> {
    let f = Fixture::new(vec![vec![text("已完成 / Done"), done()]]).await?;
    let response = f.start().await?;
    assert!(f.work().await?);
    assert_eq!(f.run(response.message_id).await?.status, "completed");
    let cp = f.checkpoint(response.message_id).await?;
    assert_eq!(cp.message.rev(), 1);
    assert_eq!(cp.message.status(), "complete");
    let log = PgEventLog {
        db: f.db.clone(),
        scope: f.scope().await?,
    };
    let batch = log.read_after(&response.message_id.to_string(), 0).await?;
    assert!(batch.covered);
    assert_eq!(batch.head, cp.last_seq);
    assert_eq!(
        batch.events.last().context("end")?.event_type(),
        "message.end"
    );
    let bytes = f.mock.requests();
    assert_eq!(bytes.len(), 1);
    assert!(bytes[0].snapshot.instructions.contains("TEMPLATES"));
    Ok(())
}
#[tokio::test]
async fn message_pause_resume_final_revisions_and_change_seq() -> Result<()> {
    let f = Fixture::new(vec![question(), vec![text("已回答 / Answered"), done()]]).await?;
    let r = f.start().await?;
    f.work().await?;
    let paused = f.checkpoint(r.message_id).await?;
    assert_eq!(paused.message.rev(), 0);
    assert_eq!(paused.message.status(), "paused");
    let before: i64 = sqlx::query_scalar("select change_seq from chat_entries where id=$1")
        .bind(r.message_id)
        .fetch_one(&f.owner)
        .await?;
    let action = f.answer(r.message_id).await?;
    f.runs().answer(&f.p, action, &f.runtime.tools).await?;
    let resumed = f.checkpoint(r.message_id).await?;
    assert_eq!(resumed.message.rev(), 0);
    assert_eq!(resumed.message.status(), "streaming");
    f.work().await?;
    let final_cp = f.checkpoint(r.message_id).await?;
    assert_eq!(final_cp.message.rev(), 1);
    let after: i64 = sqlx::query_scalar("select change_seq from chat_entries where id=$1")
        .bind(r.message_id)
        .fetch_one(&f.owner)
        .await?;
    assert!(after > before);
    Ok(())
}
#[tokio::test]
async fn two_devices_answer_exactly_one_interrupt_resolution() -> Result<()> {
    let f = Fixture::new(vec![question()]).await?;
    let r = f.start().await?;
    f.work().await?;
    let a = f.answer(r.message_id).await?;
    let b = f.answer(r.message_id).await?;
    let runs = f.runs();
    let (a, b) = tokio::join!(
        runs.answer(&f.p, a, &f.runtime.tools),
        runs.answer(&f.p, b, &f.runtime.tools)
    );
    assert_ne!(a.is_ok(), b.is_ok());
    let n: i64 = sqlx::query_scalar(
        "select count(*) from agent_run_items where run_id=$1 and kind='interrupt_answer'",
    )
    .bind(f.run(r.message_id).await?.id)
    .fetch_one(&f.owner)
    .await?;
    assert_eq!(n, 1);
    Ok(())
}
#[tokio::test]
async fn action_duplicate_id_replays_bound_result_and_rejects_changed_payload() -> Result<()> {
    let f = Fixture::new(vec![question()]).await?;
    let r = f.start().await?;
    f.work().await?;
    let action = f.answer(r.message_id).await?;
    let first = f
        .runs()
        .answer(&f.p, action.clone(), &f.runtime.tools)
        .await?;
    assert_eq!(
        first,
        f.runs()
            .answer(&f.p, action.clone(), &f.runtime.tools)
            .await?
    );
    let mut changed = action;
    changed["payload"] = json!({"selected":["transport"]});
    assert!(
        f.runs()
            .answer(&f.p, changed, &f.runtime.tools)
            .await
            .is_err()
    );
    Ok(())
}
#[tokio::test]
async fn action_rejects_option_absent_from_stored_block() -> Result<()> {
    let f = Fixture::new(vec![question()]).await?;
    let r = f.start().await?;
    f.work().await?;
    let mut action = f.answer(r.message_id).await?;
    action["payload"] = json!({"selected":["forged"]});
    assert!(
        f.runs()
            .answer(&f.p, action, &f.runtime.tools)
            .await
            .is_err()
    );
    assert_eq!(f.run(r.message_id).await?.status, "paused");
    Ok(())
}
#[tokio::test]
async fn answer_races_stop_single_resolution() -> Result<()> {
    let f = Fixture::new(vec![question()]).await?;
    let r = f.start().await?;
    f.work().await?;
    let action = f.answer(r.message_id).await?;
    let runs = f.runs();
    let (answer, stop) = tokio::join!(
        runs.answer(&f.p, action, &f.runtime.tools),
        runs.stop(&f.p, r.message_id)
    );
    assert!(stop.is_ok());
    let run = f.run(r.message_id).await?;
    assert_eq!(run.status, "cancelled");
    assert!(!matches!(
        f.checkpoint(r.message_id).await?.message.status(),
        "streaming" | "paused"
    ));
    // Answer may precede stop; at most one user answer is recorded either way.
    let n: i64 = sqlx::query_scalar("select count(*) from chat_actions where message_id=$1")
        .bind(r.message_id)
        .fetch_one(&f.owner)
        .await?;
    assert_eq!(n, if answer.is_ok() { 1 } else { 0 });
    Ok(())
}
#[tokio::test]
async fn queued_b_remains_blocked_when_running_a_later_pauses() -> Result<()> {
    let f = Fixture::new(vec![question()]).await?;
    let a = f.start().await?;
    // Claim A without executing; B arrives while A is running.
    let owner = Uuid::now_v7();
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let run = tx.claim_run(f.space, owner).await?.context("claim")?;
    tx.commit().await?;
    let b = f.start().await?;
    assert!(!f.work().await?);
    // Return A to queued solely as a test fixture, then exercise real pause.
    sqlx::query(
        "update agent_runs set status='queued',lease_owner=null,lease_until=null where id=$1",
    )
    .bind(run.id)
    .execute(&f.owner)
    .await?;
    f.work().await?;
    assert_eq!(f.run(a.message_id).await?.status, "paused");
    assert!(!f.work().await?);
    assert_eq!(f.run(b.message_id).await?.status, "queued");
    Ok(())
}
#[tokio::test]
async fn new_c_closes_paused_a_but_does_not_overtake_queued_b() -> Result<()> {
    let f = Fixture::new(vec![
        question(),
        vec![text("B"), done()],
        vec![text("C"), done()],
    ])
    .await?;
    let a = f.start().await?;
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let claimed = tx
        .claim_run(f.space, Uuid::now_v7())
        .await?
        .context("claim")?;
    tx.commit().await?;
    let b = f.start().await?;
    sqlx::query(
        "update agent_runs set status='queued',lease_owner=null,lease_until=null where id=$1",
    )
    .bind(claimed.id)
    .execute(&f.owner)
    .await?;
    f.work().await?;
    let c = f.start().await?;
    assert_eq!(f.run(a.message_id).await?.status, "cancelled");
    f.work().await?;
    assert_eq!(f.run(b.message_id).await?.status, "completed");
    assert_eq!(f.run(c.message_id).await?.status, "queued");
    f.work().await?;
    assert_eq!(f.run(c.message_id).await?.status, "completed");
    Ok(())
}
#[tokio::test]
async fn reclaimed_run_rejects_writes_from_the_same_owners_earlier_epoch() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    f.start().await?;
    let owner = Uuid::now_v7();
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let run = tx.claim_run(f.space, owner).await?.context("claim")?;
    tx.commit().await?;
    // Pause, answer and reclaim by the same worker leave status, owner and
    // lease unchanged; only the epoch tells the old holder apart.
    sqlx::query("update agent_runs set lease_epoch=lease_epoch+1 where id=$1")
        .bind(run.id)
        .execute(&f.owner)
        .await?;
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let stale = RunLease {
        run_id: run.id,
        owner,
        epoch: run.lease_epoch,
    };
    assert!(tx.guard_run(f.space, stale).await.is_err());
    let current = RunLease {
        epoch: run.lease_epoch + 1,
        ..stale
    };
    assert!(tx.guard_run(f.space, current).await.is_ok());
    tx.rollback().await?;
    Ok(())
}
#[tokio::test]
async fn later_message_waits_behind_earlier_run_backing_off_for_ai() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let a = f.start().await?;
    let b = f.start().await?;
    sqlx::query("update agent_runs set status='waiting_ai',waiting_ai_since=now(),run_after=now()+interval '1 minute' where assistant_message_id=$1")
        .bind(a.message_id)
        .execute(&f.owner)
        .await?;
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    assert!(tx.claim_run(f.space, Uuid::now_v7()).await?.is_none());
    tx.rollback().await?;
    assert_eq!(f.run(b.message_id).await?.status, "queued");
    Ok(())
}
#[tokio::test]
async fn workers_skip_locked_claim_each_run_once_and_fifo_uses_uuid_tiebreak() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let a = f.start().await?;
    let b = f.start().await?;
    sqlx::query("update agent_runs set created_at='2026-01-01' where space_id=$1")
        .bind(f.space.0)
        .execute(&f.owner)
        .await?;
    let (db, user, space) = (&f.db, f.p.user_id, f.space);
    let claim = |owner| async move {
        let tx = SpaceTx::begin(db, user, &[(space, None)], Mode::Write).await?;
        let run = tx.claim_run(space, owner).await?;
        tx.commit().await?;
        anyhow::Ok(run)
    };
    let (x, y) = tokio::join!(claim(Uuid::now_v7()), claim(Uuid::now_v7()));
    let (x, y) = (x?, y?);
    assert_ne!(x.is_some(), y.is_some());
    let actual = x.or(y).context("one winner")?;
    assert_eq!(actual.assistant_message_id, a.message_id);
    assert_eq!(f.run(b.message_id).await?.status, "queued");
    Ok(())
}
#[tokio::test]
async fn lease_expiry_interrupts_and_never_requeues_or_calls_provider() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let claimed = tx
        .claim_run(f.space, Uuid::now_v7())
        .await?
        .context("claim")?;
    tx.commit().await?;
    f.expire_lease(claimed.id).await?;
    f.runtime.sweep().await?;
    assert_eq!(f.run(r.message_id).await?.status, "interrupted");
    assert_eq!(
        f.checkpoint(r.message_id).await?.message.status(),
        "interrupted"
    );
    assert!(!f.work().await?);
    assert!(f.mock.requests().is_empty());
    Ok(())
}
#[tokio::test]
async fn stale_lease_epoch_rejects_every_worker_write_kind() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    f.start().await?;
    let owner = Uuid::now_v7();
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let run = tx.claim_run(f.space, owner).await?.context("claim")?;
    tx.commit().await?;
    f.expire_lease(run.id).await?;
    f.runtime.sweep().await?;
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let stale = RunLease {
        run_id: run.id,
        owner,
        epoch: run.lease_epoch,
    };
    assert!(tx.guard_run(f.space, stale).await.is_err());
    assert!(tx.renew_run(f.space, stale).await.is_err());
    assert!(
        tx.append_journal(f.space, stale, "note", None, json!({"text":"stale"}), None)
            .await
            .is_err()
    );
    assert!(tx.wait_for_ai(f.space, stale).await.is_err());
    assert!(tx.model_turn_committed(f.space, stale).await.is_err());
    assert!(tx.pause_run(f.space, stale, json!({}), "x").await.is_err());
    tx.rollback().await?;
    Ok(())
}
#[tokio::test]
async fn partial_output_preserves_committed_text_and_interrupts_without_automatic_recovery()
-> Result<()> {
    let f = Fixture::new(vec![vec![
        text("这段已保存的虚构文字有足够的二十个字符 / Persisted"),
        MockStep::Fail(ProviderError::Transport),
    ]])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "interrupted");
    assert!(
        f.checkpoint(r.message_id).await?.message.0["fallbackText"]
            .as_str()
            .context("text")?
            .contains("已保存")
    );
    assert_eq!(f.mock.requests().len(), 1);
    assert!(!f.work().await?);
    Ok(())
}
#[tokio::test]
async fn stop_waiting_ai_for_manual_entry_never_calls_provider() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    f.runtime
        .router
        .0
        .store(Arc::new(AiRouter::new(AiConfig::default(), vec![])));
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "waiting_ai");
    f.runs().stop(&f.p, r.message_id).await?;
    assert!(!f.work().await?);
    assert!(f.mock.requests().is_empty());
    Ok(())
}
#[tokio::test]
async fn one_retry_per_run_returns_same_new_reply_to_two_devices() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    f.runs().stop(&f.p, r.message_id).await?;
    let runs = f.runs();
    let (a, b) = tokio::join!(
        runs.retry(&f.p, r.message_id),
        runs.retry(&f.p, r.message_id)
    );
    assert_eq!(a?.message_id, b?.message_id);
    let n: i64 = sqlx::query_scalar("select count(*) from agent_runs where retry_of_run_id=$1")
        .bind(f.run(r.message_id).await?.id)
        .fetch_one(&f.owner)
        .await?;
    assert_eq!(n, 1);
    Ok(())
}
#[tokio::test]
async fn service_layer_key_rejected_without_runs_or_model_calls() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let mut key = f.p.clone();
    key.via = Via::ApiKey {
        id: Uuid::now_v7(),
        name: "synthetic-key".into(),
        scope: "read_write".into(),
    };
    let runs = f.runs();
    assert_eq!(
        runs.start(
            &key,
            StartMessage {
                id: Uuid::now_v7(),
                text: Some("fake".into()),
                images: vec![]
            }
        )
        .await
        .err()
        .context("denied")?
        .code,
        "api_key_ai_not_allowed"
    );
    assert_eq!(
        runs.retry(&key, Uuid::now_v7())
            .await
            .err()
            .context("denied")?
            .code,
        "api_key_ai_not_allowed"
    );
    let n: i64 = sqlx::query_scalar("select count(*) from agent_runs")
        .fetch_one(&f.owner)
        .await?;
    assert_eq!(n, 0);
    assert!(f.mock.requests().is_empty());
    Ok(())
}
#[tokio::test]
async fn chat_cleaned_log_returns_snapshot_with_authoritative_head() -> Result<()> {
    let f = Fixture::new(vec![vec![text("完成 / Done"), done()]]).await?;
    let r = f.start().await?;
    f.work().await?;
    let cp = f.checkpoint(r.message_id).await?;
    sqlx::query("update chat_entries set updated_at=now()-interval '11 minutes' where id=$1")
        .bind(r.message_id)
        .execute(&f.owner)
        .await?;
    sqlx::query(
        "update chat_stream_events set created_at=now()-interval '11 minutes' where message_id=$1",
    )
    .bind(r.message_id)
    .execute(&f.owner)
    .await?;
    f.db.cleanup_chat_logs().await?;
    let log = PgEventLog {
        db: f.db.clone(),
        scope: f.scope().await?,
    };
    let batch = log.read_after(&r.message_id.to_string(), 0).await?;
    assert!(!batch.covered);
    assert_eq!(batch.head, cp.last_seq);
    let mut events = resume_service(f.db.clone(), f.scope().await?, f.hub.clone())
        .open(&r.message_id.to_string(), ResumeOptions::default())
        .await?;
    let event = events.next().await.context("snapshot")??;
    assert_eq!(event.event_type(), "message.snapshot");
    assert_eq!(event.0["message"], cp.message.0);
    assert!(events.next().await.is_none());
    Ok(())
}
#[tokio::test]
async fn membership_epoch_change_cancels_instead_of_executing() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    sqlx::query("update space_members set join_epoch=join_epoch+1 where space_id=$1")
        .bind(f.space.0)
        .execute(&f.owner)
        .await?;
    f.runtime.sweep().await?;
    let status: String =
        sqlx::query_scalar("select status from agent_runs where assistant_message_id=$1")
            .bind(r.message_id)
            .fetch_one(&f.owner)
            .await?;
    assert_eq!(status, "cancelled");
    assert!(f.mock.requests().is_empty());
    Ok(())
}
#[tokio::test]
async fn retry_lunch_50_parking_10_writes_only_parking_and_keeps_original_keys() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    let account = Uuid::now_v7();
    let ctx = jiabu_tools::ToolCtx::begin(
        &f.db,
        f.p.clone(),
        f.space,
        Some(JoinEpoch(1)),
        jiabu_tools::Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(account),
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: chrono::Utc::now(),
        },
    )
    .await?;
    f.runtime
        .tools
        .invoke(
            "create_account",
            json!({"kind":"real","name":"虚构钱包","opening_on":"2026-01-01"}),
            &ctx,
        )
        .await?;
    let purpose = Uuid::now_v7();
    let ctx = jiabu_tools::ToolCtx::begin(
        &f.db,
        f.p.clone(),
        f.space,
        Some(JoinEpoch(1)),
        jiabu_tools::Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(purpose),
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: chrono::Utc::now(),
        },
    )
    .await?;
    f.runtime
        .tools
        .invoke(
            "create_account",
            json!({"kind":"purpose","name":"虚构餐饮用途","opening_on":"2026-01-01"}),
            &ctx,
        )
        .await?;
    let lunch = json!({"kind":"expense","amount_minor":5000,"occurred_on":"2026-01-01","account_id":account,"purpose_id":purpose});
    let mut parking = lunch.clone();
    parking["amount_minor"] = json!(1000);
    let mut invalid_parking = parking.clone();
    invalid_parking["account_id"] = json!(Uuid::now_v7());
    let scripts = vec![
        vec![
            call("lunch", "create_record", lunch),
            call("parking", "create_record", invalid_parking),
            done(),
        ],
        vec![
            text("虚构中断输出已经达到合批的字符数量，保留这部分。"),
            MockStep::Fail(ProviderError::Transport),
        ],
        vec![call("parking_retry", "create_record", parking), done()],
        vec![text("已补记停车 / Parking saved"), done()],
    ];
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
    let config = f.runtime.router.0.load().config.clone();
    f.runtime
        .router
        .0
        .store(Arc::new(AiRouter::new(config, vec![mock.clone()])));
    f.mock = mock;
    let a = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(a.message_id).await?.status, "interrupted");
    let old = f.run(a.message_id).await?;
    let retry = f.runs().retry(&f.p, a.message_id).await?;
    let new = f.run(retry.message_id).await?;
    let old_key: Uuid = sqlx::query_scalar(
        "select idempotency_key from agent_tool_calls where run_id=$1 and call_id='lunch'",
    )
    .bind(old.id)
    .fetch_one(&f.owner)
    .await?;
    let new_key: Uuid = sqlx::query_scalar(
        "select idempotency_key from agent_tool_calls where run_id=$1 and call_id='lunch'",
    )
    .bind(new.id)
    .fetch_one(&f.owner)
    .await?;
    assert_eq!(old_key, new_key);
    f.work().await?;
    let amounts: Vec<i64> = sqlx::query_scalar(
        "select amount_minor from records where space_id=$1 order by amount_minor",
    )
    .bind(f.space.0)
    .fetch_all(&f.owner)
    .await?;
    assert_eq!(amounts, vec![1000, 5000]);
    let cp = f.checkpoint(retry.message_id).await?;
    let cards: Vec<_> = cp.message.0["blocks"]
        .as_array()
        .context("blocks")?
        .iter()
        .filter(|b| b["type"] == "x-jiabu.record_card")
        .collect();
    assert_eq!(cards.len(), 1);
    assert_ne!(cards[0]["data"]["recordId"], old_key.to_string());
    let count: i64 = sqlx::query_scalar("select count(*) from entity_events where entity_id=$1 ")
        .bind(old_key)
        .fetch_one(&f.owner)
        .await?;
    // Audit representation may use the domain action name; the row identity and
    // tool_result are the essential once-only invariants below.
    assert_eq!(count, 1);
    let results:i64=sqlx::query_scalar("select count(*) from agent_run_items where run_id=$1 and kind='tool_result' and call_id='lunch'").bind(new.id).fetch_one(&f.owner).await?;
    assert_eq!(results, 1);
    Ok(())
}
#[tokio::test]
async fn crash_inside_tool_transaction_rolls_back_business_journal_and_events() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    let owner = Uuid::now_v7();
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let run = tx.claim_run(f.space, owner).await?.context("claim")?;
    tx.commit().await?;
    let lease = RunLease {
        run_id: run.id,
        owner,
        epoch: run.lease_epoch,
    };
    let id = tool_idempotency_key(run.id, "account");
    let mut tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    tx.guard_run(f.space, lease).await?;
    let ctx = jiabu_tools::ToolCtx::for_transaction(
        &f.db,
        f.p.clone(),
        &tx,
        f.space,
        JoinEpoch(1),
        jiabu_tools::Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(id),
            replay_key: Some(format!("agent:{id}")),
            run_id: Some(run.id),
            request_id: run.id,
            now: chrono::Utc::now(),
        },
    )?
    .bind_run_lease(lease)?;
    let prepared = f.runtime.tools.prepare_agent(
        "create_account",
        json!({"kind":"real","name":"事务内虚构账户","opening_on":"2026-01-01"}),
    )?;
    f.runtime
        .tools
        .invoke_in_tx(prepared, &ctx, &mut tx)
        .await?;
    tx.append_journal(
        f.space,
        lease,
        "tool_result",
        Some("account"),
        json!({"output":"synthetic"}),
        None,
    )
    .await?;
    tx.rollback().await?; // crash before commit, after both business and result
    let n: i64 = sqlx::query_scalar("select count(*) from accounts where id=$1")
        .bind(id)
        .fetch_one(&f.owner)
        .await?;
    assert_eq!(n, 0);
    let n: i64 = sqlx::query_scalar(
        "select count(*) from agent_run_items where run_id=$1 and call_id='account'",
    )
    .bind(run.id)
    .fetch_one(&f.owner)
    .await?;
    assert_eq!(n, 0);
    let n: i64 = sqlx::query_scalar("select count(*) from entity_events where entity_id=$1")
        .bind(id)
        .fetch_one(&f.owner)
        .await?;
    assert_eq!(n, 0);
    assert_eq!(f.checkpoint(r.message_id).await?.last_seq, 1);
    Ok(())
}
#[tokio::test]
async fn tools_agent_api_share_execution_and_agentonly_apionly_are_blocked() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    assert!(
        f.runtime
            .tools
            .prepare_agent("delete_tag", json!({"id":Uuid::nil(),"expected_version":1}))
            .is_err()
    );
    let ctx = jiabu_tools::ToolCtx::begin(
        &f.db,
        f.p.clone(),
        f.space,
        Some(JoinEpoch(1)),
        jiabu_tools::Effect::Read,
        jiabu_tools::Invocation {
            idempotency_key: None,
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: chrono::Utc::now(),
        },
    )
    .await?;
    assert!(
        f.runtime
            .tools
            .invoke("ask_user", json!({"prompt":"fake"}), &ctx)
            .await
            .is_err()
    );
    let available = f
        .runtime
        .tools
        .agent_tools()
        .map(|t| t.name())
        .collect::<Vec<_>>();
    assert!(available.contains(&"ask_user"));
    assert!(!available.contains(&"delete_tag"));
    Ok(())
}
struct GateLog {
    inner: PgEventLog,
    arrived: Arc<tokio::sync::Notify>,
    release: Arc<tokio::sync::Notify>,
    once: std::sync::atomic::AtomicBool,
}
#[async_trait::async_trait]
impl EventLog for GateLog {
    async fn append(&self, event: StreamEvent) -> jiabu_chat::ChatResult<()> {
        self.inner.append(event).await
    }
    async fn read_after(&self, id: &str, after: u64) -> jiabu_chat::ChatResult<ReplayBatch> {
        let batch = self.inner.read_after(id, after).await?;
        if !self.once.swap(true, std::sync::atomic::Ordering::SeqCst) {
            self.arrived.notify_one();
            self.release.notified().await;
        }
        Ok(batch)
    }
    async fn read_range(
        &self,
        id: &str,
        after: u64,
        through: u64,
    ) -> jiabu_chat::ChatResult<ReplayBatch> {
        self.inner.read_range(id, after, through).await
    }
}
#[tokio::test]
async fn sse_subscribes_before_log_read_and_cannot_lose_terminal_event() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    let scope = f.scope().await?;
    let arrived = Arc::new(tokio::sync::Notify::new());
    let release = Arc::new(tokio::sync::Notify::new());
    let service = ResumeService::new(
        Arc::new(GateLog {
            inner: PgEventLog {
                db: f.db.clone(),
                scope,
            },
            arrived: arrived.clone(),
            release: release.clone(),
            once: std::sync::atomic::AtomicBool::new(false),
        }),
        f.hub.clone(),
        Arc::new(PgCheckpointStore {
            db: f.db.clone(),
            scope,
        }),
    );
    let message = r.message_id.to_string();
    let opening =
        tokio::spawn(async move { service.open(&message, ResumeOptions::default()).await });
    arrived.notified().await;
    f.runs().stop(&f.p, r.message_id).await?;
    release.notify_one();
    let mut events = opening.await??;
    let mut last = 0;
    let mut end = 0;
    while let Some(event) = events.next().await {
        let event = event?;
        let seq = event.0["seq"].as_u64().context("seq")?;
        assert_eq!(seq, last + 1);
        last = seq;
        if event.event_type() == "message.end" {
            end += 1;
        }
    }
    assert_eq!(end, 1);
    assert_eq!(last, f.checkpoint(r.message_id).await?.last_seq);
    Ok(())
}
#[tokio::test]
async fn sse_gap_repairs_from_postgres_and_matches_unbroken_fold() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    let scope = f.scope().await?;
    let hub = Arc::new(StreamHub::new(32));
    let mut events = resume_service(f.db.clone(), scope, hub.clone())
        .open(&r.message_id.to_string(), ResumeOptions::default())
        .await?;
    let first = events.next().await.context("start")??;
    let mut fold = jiabu_chat::FoldState::new();
    fold.apply(first)?;
    f.runs().stop(&f.p, r.message_id).await?;
    let batch = PgEventLog {
        db: f.db.clone(),
        scope,
    }
    .read_after(&r.message_id.to_string(), 1)
    .await?;
    hub.publish(batch.events.last().context("end")?.clone())
        .await?;
    while let Some(event) = events.next().await {
        fold.apply(event?)?;
    }
    assert_eq!(
        fold.message()?.0,
        f.checkpoint(r.message_id).await?.message.0
    );
    Ok(())
}
#[tokio::test]
async fn sse_lagged_disconnects_instead_of_skipping_events() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    let scope = f.scope().await?;
    let hub = Arc::new(StreamHub::new(1));
    let mut events = resume_service(f.db.clone(), scope, hub.clone())
        .open(&r.message_id.to_string(), ResumeOptions::default())
        .await?;
    events.next().await.context("start")??;
    f.runs().stop(&f.p, r.message_id).await?;
    let batch = PgEventLog {
        db: f.db.clone(),
        scope,
    }
    .read_after(&r.message_id.to_string(), 1)
    .await?;
    assert!(batch.events.len() > 1);
    for event in batch.events {
        hub.publish(event).await?;
    }
    assert!(matches!(
        events.next().await,
        Some(Err(jiabu_chat::ChatError::Lagged))
    ));
    Ok(())
}
#[tokio::test]
async fn journal_retention_seven_and_thirty_days_preserves_retry_rules_and_role_grants()
-> Result<()> {
    let blob = ProviderBlob {
        provider_id: "synthetic".into(),
        model: "fake-model".into(),
        account_id: "fiction".into(),
        item: json!({"encrypted_content":"synthetic-opaque"}),
    };
    let f = Fixture::new(vec![vec![
        MockStep::Emit(TurnEvent::ProviderBlob(blob)),
        text("虚构完成"),
        done(),
    ]])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    let before:bool=sqlx::query_scalar("select exists(select 1 from agent_run_items where run_id=$1 and provider_blob is not null)").bind(run.id).fetch_one(&f.owner).await?;
    assert!(before);
    sqlx::query("update agent_runs set ended_at=now()-interval '8 days' where id=$1")
        .bind(run.id)
        .execute(&f.owner)
        .await?;
    f.db.cleanup_chat_logs().await?;
    let count: i64 = sqlx::query_scalar(
        "select count(*) from agent_run_items where run_id=$1 and provider_blob is not null",
    )
    .bind(run.id)
    .fetch_one(&f.owner)
    .await?;
    assert_eq!(count, 0);
    assert!(f.run(r.message_id).await?.journal_compacted_at.is_none());
    sqlx::query("update agent_runs set ended_at=now()-interval '31 days' where id=$1")
        .bind(run.id)
        .execute(&f.owner)
        .await?;
    f.db.cleanup_chat_logs().await?;
    assert!(f.run(r.message_id).await?.journal_compacted_at.is_some());
    assert_eq!(
        f.runs()
            .retry(&f.p, r.message_id)
            .await
            .err()
            .context("retry denied")?
            .code,
        "retry_unavailable"
    );
    let app = PgPool::connect(&f.test.app_url).await?;
    let permission:bool=sqlx::query_scalar("select has_function_privilege('jiabu_app','retain_agent_journals(integer)','execute') and not has_function_privilege('jiabu_admin','retain_agent_journals(integer)','execute') and not has_table_privilege('jiabu_app','agent_run_items','update')").fetch_one(&app).await?;
    assert!(permission);
    let public:bool=sqlx::query_scalar("select exists(select 1 from pg_proc p cross join lateral aclexplode(p.proacl) a where p.oid='retain_agent_journals(integer)'::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE')").fetch_one(&f.owner).await?;
    assert!(!public);
    let path: Vec<String> = sqlx::query_scalar(
        "select proconfig from pg_proc where oid='retain_agent_journals(integer)'::regprocedure",
    )
    .fetch_one(&f.owner)
    .await?;
    assert!(
        path.iter()
            .any(|s| s == "search_path=pg_catalog, public, pg_temp")
    );
    app.close().await;
    Ok(())
}
#[tokio::test]
async fn answer_races_expiry_single_resolution() -> Result<()> {
    let f = Fixture::new(vec![question()]).await?;
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    // The frozen action and durable interrupt must share one deadline.
    let expired = "2025-01-01T00:00:00.000000Z";
    sqlx::query("update agent_runs set open_interrupt=jsonb_set(open_interrupt,'{expires_at}',to_jsonb($2::text)) where id=$1").bind(run.id).bind(expired).execute(&f.owner).await?;
    let mut message = f.checkpoint(r.message_id).await?.message.0;
    let block = message["interrupt"]["blockId"]
        .as_str()
        .context("block")?
        .to_owned();
    for b in message["blocks"].as_array_mut().context("blocks")? {
        if b["id"] == block {
            b["data"]["action"]["expiresAt"] = json!(expired);
        }
    }
    sqlx::query("update chat_entries set message=$2 where id=$1")
        .bind(r.message_id)
        .bind(message)
        .execute(&f.owner)
        .await?;
    // Keep journal's frozen deadline aligned with fixture's interrupt.
    // Application roles cannot edit it; test owner models an old persisted run.
    sqlx::query("update agent_run_items set payload=jsonb_set(payload,'{expires_at}',to_jsonb($2::text)) where run_id=$1 and kind='interrupt'").bind(run.id).bind(expired).execute(&f.owner).await?;
    let action = f.answer(r.message_id).await?;
    let runs = f.runs();
    let (answer, sweep) = tokio::join!(
        runs.answer(&f.p, action, &f.runtime.tools),
        f.runtime.sweep()
    );
    sweep?;
    assert!(answer.is_err());
    assert_eq!(f.run(r.message_id).await?.status, "expired");
    let cp = f.checkpoint(r.message_id).await?;
    assert_eq!(cp.message.status(), "interrupted");
    assert_eq!(cp.message.rev(), 1);
    Ok(())
}
#[tokio::test]
async fn waiting_ai_ten_minute_budget_fails_without_provider_call() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    f.runtime
        .router
        .0
        .store(Arc::new(AiRouter::new(AiConfig::default(), vec![])));
    let r = f.start().await?;
    f.work().await?;
    sqlx::query("update agent_runs set waiting_ai_since=now()-interval '11 minutes' where assistant_message_id=$1").bind(r.message_id).execute(&f.owner).await?;
    f.runtime.sweep().await?;
    assert_eq!(f.run(r.message_id).await?.status, "failed");
    assert!(f.mock.requests().is_empty());
    assert_eq!(f.checkpoint(r.message_id).await?.message.rev(), 1);
    Ok(())
}
#[tokio::test]
async fn model_total_deadline_fails_with_deterministic_text_and_finalized_meter() -> Result<()> {
    let mut f = Fixture::new(vec![vec![
        MockStep::Delay(std::time::Duration::from_secs(30)),
        done(),
    ]])
    .await?;
    Arc::get_mut(&mut f.runtime)
        .context("unique runtime")?
        .budget
        // Long enough for meter registration to reach the provider, far below the 30 s mock delay.
        .model_call = std::time::Duration::from_secs(1);
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "failed");
    let n: i64 = sqlx::query_scalar(
        "select count(*) from ai_calls where run_id=$1 and completed_at is null",
    )
    .bind(f.run(r.message_id).await?.id)
    .fetch_one(&f.owner)
    .await?;
    assert_eq!(n, 0);
    assert_eq!(f.mock.requests().len(), 1);
    Ok(())
}
#[tokio::test]
async fn model_idle_deadline_fails_without_followup_model_closure() -> Result<()> {
    let mut f = Fixture::new(vec![vec![
        MockStep::Delay(std::time::Duration::from_secs(30)),
        done(),
    ]])
    .await?;
    Arc::get_mut(&mut f.runtime)
        .context("unique runtime")?
        .budget
        .model_idle = std::time::Duration::from_millis(10);
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "failed");
    assert_eq!(f.mock.requests().len(), 1);
    Ok(())
}
#[tokio::test]
async fn twenty_model_turns_budget_fails_before_twenty_first_call() -> Result<()> {
    let f = Fixture::new(
        (0..21)
            .map(|i| vec![call(&format!("read_{i}"), "list_tags", json!({})), done()])
            .collect(),
    )
    .await?;
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "failed");
    assert_eq!(f.mock.requests().len(), 20);
    assert_eq!(f.run(r.message_id).await?.model_turns, 20);
    Ok(())
}
#[tokio::test]
async fn active_budget_fails_before_call_and_paused_time_does_not_count() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    Arc::get_mut(&mut f.runtime)
        .context("unique runtime")?
        .budget
        .active = std::time::Duration::ZERO;
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "failed");
    assert!(f.mock.requests().is_empty());
    Ok(())
}
#[tokio::test]
async fn graceful_shutdown_interrupts_claimed_owned_run_instead_of_releasing_to_queue() -> Result<()>
{
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    // Register owner via work_once on an empty queue first, then emulate a
    // worker crash immediately after claim with that same process owner.
    f.runs().stop(&f.p, r.message_id).await?;
    let owner = Uuid::now_v7();
    assert!(!f.runtime.work_once(owner).await?);
    let second = f.start().await?;
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    tx.claim_run(f.space, owner).await?.context("claim")?;
    tx.commit().await?;
    let handle = f.runtime.clone().spawn();
    handle.stop_claiming();
    handle.shutdown().await;
    assert_eq!(f.run(second.message_id).await?.status, "interrupted");
    assert_eq!(
        f.checkpoint(second.message_id).await?.message.status(),
        "interrupted"
    );
    assert!(f.mock.requests().is_empty());
    Ok(())
}
struct FailAfterAccount;
impl jiabu_tools::TypedTool for FailAfterAccount {
    type Args = jiabu_domain::ledger::CreateAccount;
    type Output = Value;
    fn name(&self) -> &'static str {
        "fail_after_account"
    }
    fn description(&self) -> &'static str {
        "Synthetic business rollback injection"
    }
    fn effect(&self) -> jiabu_tools::Effect {
        jiabu_tools::Effect::LocalWrite
    }
    fn step_kind(&self) -> jiabu_tools::StepKind {
        jiabu_tools::StepKind::CreateAccount
    }
    fn step_label(&self, _: &Self::Args, _: &jiabu_tools::ToolCtx) -> jiabu_tools::StepLabel {
        jiabu_tools::StepLabel("虚构回滚")
    }
    fn example_args(&self) -> Value {
        json!({"kind":"real","name":"虚构失败账户","opening_on":"2026-01-01"})
    }
    fn example_output(&self) -> Value {
        json!({})
    }
    fn execute<'a>(
        &'a self,
        args: Self::Args,
        ctx: &'a jiabu_tools::ToolCtx,
        tx: &'a SpaceTx,
    ) -> jiabu_tools::tool::ToolFuture<'a, Result<Value, jiabu_db::OperationError>> {
        Box::pin(async move {
            tx.ledger_create_account(
                ctx.space_id,
                ctx.new_id(args.id)?,
                args,
                &ctx.audit(tx.member(ctx.space_id)),
            )
            .await?;
            Err(jiabu_db::OperationError::new(422, "synthetic_failure"))
        })
    }
}
#[tokio::test]
async fn savepoint_business_failure_keeps_outer_failure_result_but_no_business_audit_or_replay()
-> Result<()> {
    let mut f = Fixture::new(vec![
        vec![
            call(
                "failure",
                "fail_after_account",
                json!({"kind":"real","name":"虚构失败账户","opening_on":"2026-01-01"}),
            ),
            done(),
        ],
        vec![text("没有保存 / Nothing saved"), done()],
    ])
    .await?;
    Arc::get_mut(&mut Arc::get_mut(&mut f.runtime).context("runtime")?.tools)
        .context("registry")?
        .register(FailAfterAccount)?;
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    let id = tool_idempotency_key(run.id, "failure");
    for table in ["accounts", "entity_events"] {
        let query = if table == "accounts" {
            "select count(*) from accounts where id=$1"
        } else {
            "select count(*) from entity_events where entity_id=$1"
        };
        let n: i64 = sqlx::query_scalar(query)
            .bind(id)
            .fetch_one(&f.owner)
            .await?;
        assert_eq!(n, 0);
    }
    let n: i64 = sqlx::query_scalar("select count(*) from idempotency where key=$1")
        .bind(format!("agent:{id}"))
        .fetch_one(&f.owner)
        .await?;
    assert_eq!(n, 0);
    let payload:Value=sqlx::query_scalar("select payload from agent_run_items where run_id=$1 and call_id='failure' and kind='tool_result'").bind(run.id).fetch_one(&f.owner).await?;
    assert_eq!(payload["output"]["error"], "synthetic_failure");
    assert_eq!(run.status, "completed");
    Ok(())
}
struct SlowRead;
impl jiabu_tools::TypedTool for SlowRead {
    type Args = jiabu_domain::ledger::ListTags;
    type Output = Value;
    fn name(&self) -> &'static str {
        "slow_read"
    }
    fn description(&self) -> &'static str {
        "Synthetic tool timeout"
    }
    fn effect(&self) -> jiabu_tools::Effect {
        jiabu_tools::Effect::Read
    }
    fn step_kind(&self) -> jiabu_tools::StepKind {
        jiabu_tools::StepKind::ListTags
    }
    fn step_label(&self, _: &Self::Args, _: &jiabu_tools::ToolCtx) -> jiabu_tools::StepLabel {
        jiabu_tools::StepLabel("虚构慢查询")
    }
    fn example_args(&self) -> Value {
        json!({})
    }
    fn example_output(&self) -> Value {
        json!({})
    }
    fn execute<'a>(
        &'a self,
        _: Self::Args,
        _: &'a jiabu_tools::ToolCtx,
        _: &'a SpaceTx,
    ) -> jiabu_tools::tool::ToolFuture<'a, Result<Value, jiabu_db::OperationError>> {
        Box::pin(async {
            tokio::time::sleep(std::time::Duration::from_secs(30)).await;
            Ok(json!({}))
        })
    }
}
#[tokio::test]
async fn tool_ten_second_deadline_abandons_whole_transaction() -> Result<()> {
    let mut f = Fixture::new(vec![vec![call("slow", "slow_read", json!({})), done()]]).await?;
    Arc::get_mut(&mut Arc::get_mut(&mut f.runtime).context("runtime")?.tools)
        .context("registry")?
        .register(SlowRead)?;
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    assert_eq!(run.status, "failed");
    let n: i64 = sqlx::query_scalar(
        "select count(*) from agent_run_items where run_id=$1 and kind='tool_result'",
    )
    .bind(run.id)
    .fetch_one(&f.owner)
    .await?;
    assert_eq!(n, 0);
    Ok(())
}
#[tokio::test]
async fn sse_commit_before_broadcast_survives_crash() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    let owner = Uuid::now_v7();
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let run = tx.claim_run(f.space, owner).await?.context("claim")?;
    tx.commit().await?;
    let cp = f.checkpoint(r.message_id).await?;
    let mut stage = StagedStream::load(cp).await?;
    stage.stream.stop().await?;
    let batch = stage.batch().await?;
    let emitter = RunEmitter {
        lease: RunLease {
            run_id: run.id,
            owner,
            epoch: run.lease_epoch,
        },
        scope: f.scope().await?,
        hub: f.hub.clone(),
    };
    let mut live = f.hub.subscribe(&r.message_id.to_string()).await?;
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    emitter.persist(&tx, &batch).await?;
    tx.finish_run(f.space, run.id, "interrupted", Some("synthetic_crash"))
        .await?;
    tx.commit().await?;
    // Simulate process loss here: deliberately do not publish the committed batch.
    assert!(
        tokio::time::timeout(std::time::Duration::from_millis(10), live.recv())
            .await
            .is_err()
    );
    let mut replay = resume_service(
        f.db.clone(),
        f.scope().await?,
        Arc::new(StreamHub::default()),
    )
    .open(
        &r.message_id.to_string(),
        ResumeOptions {
            after: 1,
            ..ResumeOptions::default()
        },
    )
    .await?;
    let mut actual = Vec::new();
    while let Some(event) = replay.next().await {
        actual.push(event?.0);
    }
    assert_eq!(
        actual,
        batch.events.into_iter().map(|e| e.0).collect::<Vec<_>>()
    );
    Ok(())
}
#[tokio::test]
async fn action_module_denial_precedes_receipt_lookup_even_on_replay() -> Result<()> {
    let f = Fixture::new(vec![question()]).await?;
    let r = f.start().await?;
    f.work().await?;
    let action = f.answer(r.message_id).await?;
    f.runs()
        .answer(&f.p, action.clone(), &f.runtime.tools)
        .await?;
    sqlx::query("update space_member_grants set level='none' where member_id=(select member_id from agent_runs where assistant_message_id=$1) and module='ledger'").bind(r.message_id).execute(&f.owner).await?;
    // Make an accidental receipt read fail visibly. Correct authorization never
    // reaches this table, even though this action ID has an accepted receipt.
    sqlx::query("revoke select on chat_actions from jiabu_app")
        .execute(&f.owner)
        .await?;
    let error = f
        .runs()
        .answer(&f.p, action, &f.runtime.tools)
        .await
        .err()
        .context("denied")?;
    assert_eq!(error.status, 404);
    Ok(())
}
#[tokio::test]
async fn other_member_cannot_access_conversation_or_checkpoint() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    let other = f
        .test
        .seed("other-fiction", "test-only-unused-hash")
        .await?;
    sqlx::query("insert into space_members(space_id,user_id,display_name,role,status,joined_at,change_seq) values($1,$2,'虚构另一成员','member','active',now(),nextval('change_seq'))").bind(f.space.0).bind(other.user_id.0).execute(&f.owner).await?;
    let p = Principal {
        user_id: other.user_id,
        via: Via::Session {
            session_id: SessionId(Uuid::now_v7()),
            kind: jiabu_db::auth::SessionKind::Full,
        },
        user: jiabu_db::auth::User {
            id: other.user_id.0,
            username: "other-fiction".into(),
            locale: "zh-CN".into(),
        },
    };
    assert_eq!(
        f.runs()
            .stop(&p, r.message_id)
            .await
            .err()
            .context("denied")?
            .status,
        404
    );
    let tx = SpaceTx::begin(&f.db, p.user_id, &[(f.space, None)], Mode::Read).await?;
    let scope = ChatScope {
        space_id: f.space,
        member_id: tx.member(f.space).id(),
        user_id: p.user_id,
    };
    tx.commit().await?;
    assert!(
        PgCheckpointStore {
            db: f.db.clone(),
            scope
        }
        .load(&r.message_id.to_string())
        .await?
        .is_none()
    );
    assert!(
        open_stream(
            f.db.clone(),
            scope,
            f.hub.clone(),
            r.message_id,
            ResumeOptions::default()
        )
        .await
        .is_err()
    );
    Ok(())
}
#[tokio::test]
async fn clarification_form_and_free_text_from_second_device_resume_same_message() -> Result<()> {
    for free_text in [false, true] {
        let f=Fixture::new(vec![vec![call("form","ask_user",json!({"prompt":"填写虚构信息","fields":[{"key":"date","label":"日期","type":"date","required":true}]})),done()],vec![text("已收到 / Received"),done()]]).await?;
        let r = f.start().await?;
        f.work().await?;
        let cp = f.checkpoint(r.message_id).await?;
        let run = f.run(r.message_id).await?;
        let mut second = f.p.clone();
        second.via = Via::Session {
            session_id: SessionId(Uuid::now_v7()),
            kind: jiabu_db::auth::SessionKind::Full,
        };
        let payload = if free_text {
            json!({"freeText":"虚构的明天 / Fictional tomorrow"})
        } else {
            json!({"values":{"date":"2026-01-01"}})
        };
        let request = json!({"protocolVersion":"0.1","id":Uuid::now_v7(),"context":{"messageId":r.message_id,"conversationId":run.conversation_id,"blockId":cp.message.0["interrupt"]["blockId"]},"type":"form.submit","target":"clarification.answer","payload":payload});
        f.runs().answer(&second, request, &f.runtime.tools).await?;
        f.work().await?;
        assert_eq!(f.run(r.message_id).await?.status, "completed");
        assert_eq!(
            f.checkpoint(r.message_id).await?.message.0["id"],
            r.message_id.to_string()
        );
    }
    Ok(())
}
#[tokio::test]
async fn confirmation_guard_changed_account_does_not_archive() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    let account = Uuid::now_v7();
    let ctx = jiabu_tools::ToolCtx::begin(
        &f.db,
        f.p.clone(),
        f.space,
        Some(JoinEpoch(1)),
        jiabu_tools::Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(account),
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: chrono::Utc::now(),
        },
    )
    .await?;
    f.runtime
        .tools
        .invoke(
            "create_account",
            json!({"kind":"real","name":"虚构确认账户","opening_on":"2026-01-01"}),
            &ctx,
        )
        .await?;
    let scripts = vec![
        vec![
            call(
                "archive",
                "archive_account",
                json!({"id":account,"expected_version":1}),
            ),
            done(),
        ],
        vec![text("数据已变化，请重新确认 / Data changed"), done()],
    ];
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
    let config = f.runtime.router.0.load().config.clone();
    f.runtime
        .router
        .0
        .store(Arc::new(AiRouter::new(config, vec![mock.clone()])));
    f.mock = mock;
    let r = f.start().await?;
    f.work().await?;
    let cp = f.checkpoint(r.message_id).await?;
    let run = f.run(r.message_id).await?;
    let ctx = jiabu_tools::ToolCtx::begin(
        &f.db,
        f.p.clone(),
        f.space,
        Some(JoinEpoch(1)),
        jiabu_tools::Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(Uuid::now_v7()),
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: chrono::Utc::now(),
        },
    )
    .await?;
    f.runtime
        .tools
        .invoke(
            "update_account",
            json!({"id":account,"expected_version":1,"name":"虚构已修改账户"}),
            &ctx,
        )
        .await?;
    let action = json!({"protocolVersion":"0.1","id":Uuid::now_v7(),"context":{"messageId":r.message_id,"conversationId":run.conversation_id,"blockId":cp.message.0["interrupt"]["blockId"]},"type":"confirmation.respond","target":"pending_operation.confirm","payload":{"outcome":"confirm"}});
    f.runs().answer(&f.p, action, &f.runtime.tools).await?;
    f.work().await?;
    let active: bool =
        sqlx::query_scalar("select archived_at is null and version=2 from accounts where id=$1")
            .bind(account)
            .fetch_one(&f.owner)
            .await?;
    assert!(active);
    let args: Value = sqlx::query_scalar(
        "select args from agent_tool_calls where run_id=$1 and call_id='archive'",
    )
    .bind(run.id)
    .fetch_one(&f.owner)
    .await?;
    assert_eq!(args["expected_version"], 1);
    Ok(())
}
#[tokio::test]
async fn final_amendment_increments_rev_and_change_seq_without_reusing_stream_seq() -> Result<()> {
    let f = Fixture::new(vec![vec![text("虚构完成 / Complete"), done()]]).await?;
    let r = f.start().await?;
    f.work().await?;
    let cp = f.checkpoint(r.message_id).await?;
    let mut message = cp.message;
    message.0["rev"] = json!(2);
    message.0["fallbackText"] = json!("虚构更正 / Amended");
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    revise_final(&tx, f.space, r.message_id, 1, message.clone()).await?;
    tx.commit().await?;
    let next = f.checkpoint(r.message_id).await?;
    assert_eq!(next.message.rev(), 2);
    assert_eq!(next.last_seq, cp.last_seq);
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    assert!(
        revise_final(&tx, f.space, r.message_id, 1, message)
            .await
            .is_err()
    );
    tx.rollback().await?;
    Ok(())
}
#[tokio::test]
async fn retention_races_retry_without_partial_copy() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    f.runs().stop(&f.p, r.message_id).await?;
    let old = f.run(r.message_id).await?;
    sqlx::query("update agent_runs set ended_at=now()-interval '31 days' where id=$1")
        .bind(old.id)
        .execute(&f.owner)
        .await?;
    let runs = f.runs();
    let (retry, retention) = tokio::join!(runs.retry(&f.p, r.message_id), f.db.cleanup_chat_logs());
    retention?;
    match retry {
        Ok(child) => {
            let new = f.run(child.message_id).await?;
            let n: i64 = sqlx::query_scalar("select count(*) from agent_run_items where run_id=$1")
                .bind(new.id)
                .fetch_one(&f.owner)
                .await?;
            assert!(n >= 3);
            let uncompacted:bool=sqlx::query_scalar("select not exists(select 1 from agent_run_items where run_id=$1 and payload->>'compacted'='true')").bind(new.id).fetch_one(&f.owner).await?;
            assert!(uncompacted);
        }
        Err(error) => {
            assert_eq!(error.code, "retry_unavailable");
            let n: i64 =
                sqlx::query_scalar("select count(*) from agent_runs where retry_of_run_id=$1")
                    .bind(old.id)
                    .fetch_one(&f.owner)
                    .await?;
            assert_eq!(n, 0);
        }
    }
    Ok(())
}
#[tokio::test]
async fn paused_run_survives_process_and_log_loss_then_answers() -> Result<()> {
    let f = Fixture::new(vec![
        question(),
        vec![text("恢复回答 / Answered after restart"), done()],
    ])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    sqlx::query("delete from chat_stream_events where message_id=$1")
        .bind(r.message_id)
        .execute(&f.owner)
        .await?;
    let new_hub = Arc::new(StreamHub::default());
    let restarted = Runtime::new(
        f.db.clone(),
        f.runtime.router.clone(),
        f.runtime.tools.clone(),
        f.runtime.templates.clone(),
        new_hub.clone(),
        Arc::new(RuntimeMeter {
            db: f.db.clone(),
            token: Uuid::now_v7(),
        }),
    );
    restarted.sweep().await?;
    assert_eq!(f.run(r.message_id).await?.status, "paused");
    let runs = RunService.scoped(
        f.db.clone(),
        f.space,
        JoinEpoch(1),
        new_hub,
        f.runtime.tools.clone(),
        f.runtime.templates.clone(),
    );
    let request = f.answer(r.message_id).await?;
    runs.answer(&f.p, request, &f.runtime.tools).await?;
    restarted.work_once(Uuid::now_v7()).await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    Ok(())
}
#[tokio::test]
async fn stream_checkpoint_and_journal_rollback_together_before_final_commit() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    let r = f.start().await?;
    let owner = Uuid::now_v7();
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    let run = tx.claim_run(f.space, owner).await?.context("claim")?;
    tx.commit().await?;
    let before = f.checkpoint(r.message_id).await?;
    let mut stage = StagedStream::load(before.clone()).await?;
    stage.stream.finish().await?;
    let batch = stage.batch().await?;
    let lease = RunLease {
        run_id: run.id,
        owner,
        epoch: run.lease_epoch,
    };
    let emitter = RunEmitter {
        lease,
        scope: f.scope().await?,
        hub: f.hub.clone(),
    };
    let tx = SpaceTx::begin(&f.db, f.p.user_id, &[(f.space, None)], Mode::Write).await?;
    tx.append_journal(
        f.space,
        lease,
        "model_turn",
        None,
        json!({"text":"synthetic","calls":[],"items":[]}),
        None,
    )
    .await?;
    emitter.persist(&tx, &batch).await?;
    tx.finish_run(f.space, run.id, "completed", None).await?;
    tx.rollback().await?;
    assert_eq!(
        f.checkpoint(r.message_id).await?.message.0,
        before.message.0
    );
    assert_eq!(f.run(r.message_id).await?.status, "running");
    let n: i64 = sqlx::query_scalar(
        "select count(*) from agent_run_items where run_id=$1 and kind='model_turn'",
    )
    .bind(run.id)
    .fetch_one(&f.owner)
    .await?;
    assert_eq!(n, 0);
    Ok(())
}
#[tokio::test]
async fn stop_preserves_committed_write_and_reports_count_without_model_closure() -> Result<()> {
    let barrier = Arc::new(tokio::sync::Barrier::new(2));
    let f = Fixture::new(vec![
        vec![
            call(
                "account",
                "create_account",
                json!({"kind":"real","name":"虚构已提交账户","opening_on":"2026-01-01"}),
            ),
            done(),
        ],
        vec![
            MockStep::Barrier(barrier.clone()),
            MockStep::Delay(std::time::Duration::from_secs(30)),
            done(),
        ],
    ])
    .await?;
    let r = f.start().await?;
    let stop = async {
        barrier.wait().await;
        f.runs().stop(&f.p, r.message_id).await
    };
    let (work, stop) = tokio::join!(f.work(), stop);
    work?;
    stop?;
    let run = f.run(r.message_id).await?;
    assert_eq!(run.status, "cancelled");
    let id = tool_idempotency_key(run.id, "account");
    let n: i64 = sqlx::query_scalar("select count(*) from accounts where id=$1")
        .bind(id)
        .fetch_one(&f.owner)
        .await?;
    assert_eq!(n, 1);
    assert_eq!(f.mock.requests().len(), 2);
    let cp = f.checkpoint(r.message_id).await?;
    assert!(
        cp.message.0["fallbackText"]
            .as_str()
            .context("summary")?
            .contains("已保存 1 项")
    );
    Ok(())
}
#[tokio::test]
async fn waiting_ai_commit_emits_valid_degraded_activity_without_reliable_seq() -> Result<()> {
    let f = Fixture::new(vec![]).await?;
    f.runtime
        .router
        .0
        .store(Arc::new(AiRouter::new(AiConfig::default(), vec![])));
    let r = f.start().await?;
    let mut live = f.hub.subscribe(&r.message_id.to_string()).await?;
    f.work().await?;
    let event = live.recv().await?.context("activity")?;
    assert_eq!(event.event_type(), "message.activity");
    assert_eq!(event.0["activity"]["phase"], "degraded");
    assert!(event.0.get("seq").is_none());
    validator()?.validate(DocumentKind::Event, &event.0)?;
    assert_eq!(f.run(r.message_id).await?.status, "waiting_ai");
    let n:i64=sqlx::query_scalar("select count(*) from chat_stream_events where message_id=$1 and event->>'type'='message.activity'").bind(r.message_id).fetch_one(&f.owner).await?;
    assert_eq!(n, 0);
    Ok(())
}
