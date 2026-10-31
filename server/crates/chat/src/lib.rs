//! ChatWeave adaptation: stage producer events, persist atomically, publish last.
mod blocks;
mod capabilities;
mod staging;
use async_trait::async_trait;
pub use blocks::{MappedOutput, map_tool_result, map_tool_result_for, validator};
pub use capabilities::{CapabilityError, ClientCapabilities};
pub use chatweave_protocol::{DocumentKind, Message, StreamEvent};
pub use chatweave_server::checkpoint::{Checkpoint, CheckpointStore};
pub use chatweave_server::event_log::{
    BroadcastHub as StreamHub, EventLog, EventSink, ReplayBatch,
};
pub use chatweave_server::resume::{EventStream, ResumeOptions, ResumeService};
pub use chatweave_server::stream::{BlockHandle, MessageStream, RecordedAnswer, StreamConfig};
use chatweave_server::{Error, Result};
pub use jiabu_db::chat_runtime::RunLease;
use jiabu_db::{AppDb, Mode, SpaceTx};
use jiabu_domain::{MemberId, SpaceId, UserId};
pub use staging::StagedStream;
use std::sync::Arc;
use uuid::Uuid;
#[derive(Clone, Copy)]
pub struct ChatScope {
    pub space_id: SpaceId,
    pub member_id: MemberId,
    pub user_id: UserId,
}
impl ChatScope {
    async fn read(&self, db: &AppDb) -> Result<SpaceTx> {
        let tx = SpaceTx::begin_snapshot(db, self.user_id, self.space_id)
            .await
            .map_err(|_| Error::NotFound)?;
        if tx.member(self.space_id).id() != self.member_id {
            return Err(Error::NotFound);
        }
        Ok(tx)
    }
}
pub struct PgEventLog {
    pub db: AppDb,
    pub scope: ChatScope,
}
#[async_trait]
impl EventLog for PgEventLog {
    // Unscoped producer writes are deliberately forbidden. RunEmitter is the
    // only durable producer, including when called through ChatWeave.
    async fn append(&self, _event: StreamEvent) -> Result<()> {
        Err(Error::Unavailable)
    }
    async fn read_after(&self, id: &str, after: u64) -> Result<ReplayBatch> {
        self.read_range(id, after, i32::MAX as u64).await
    }
    async fn read_range(&self, id: &str, after: u64, through: u64) -> Result<ReplayBatch> {
        if through < after || through > i32::MAX as u64 {
            return Err(Error::InvalidRequest("invalid cursor".into()));
        }
        let id = id.parse().map_err(|_| Error::NotFound)?;
        let tx = self.scope.read(&self.db).await?;
        let message = tx
            .message(self.scope.space_id, id)
            .await
            .map_err(|_| Error::Unavailable)?
            .ok_or(Error::NotFound)?;
        let head = message.last_seq as u64;
        let end = through.min(head);
        let events: Vec<_> = tx
            .chat_events(self.scope.space_id, id, after as i32, end as i32)
            .await
            .map_err(|_| Error::Unavailable)?
            .into_iter()
            .map(StreamEvent)
            .collect();
        let covered = after <= head
            && events.len() as u64 == end.saturating_sub(after)
            && events
                .iter()
                .enumerate()
                .all(|(i, e)| e.0["seq"].as_u64() == Some(after + i as u64 + 1));
        tx.commit().await.map_err(|_| Error::Unavailable)?;
        Ok(ReplayBatch {
            events,
            head,
            covered,
        })
    }
}
pub struct PgCheckpointStore {
    pub db: AppDb,
    pub scope: ChatScope,
}
#[async_trait]
impl CheckpointStore for PgCheckpointStore {
    async fn load(&self, id: &str) -> Result<Option<Checkpoint>> {
        let id = id.parse().map_err(|_| Error::NotFound)?;
        let tx = self.scope.read(&self.db).await?;
        let message = tx
            .message(self.scope.space_id, id)
            .await
            .map_err(|_| Error::Unavailable)?;
        tx.commit().await.map_err(|_| Error::Unavailable)?;
        Ok(message.map(checkpoint))
    }
    async fn commit(&self, _checkpoint: Checkpoint, _expected: Option<u64>) -> Result<()> {
        Err(Error::Unavailable)
    }
}
/// A batch contains the complete fold, even when ChatWeave's periodic checkpoint
/// interval has not elapsed. Thus a committed text delta never lacks a checkpoint.
pub struct EmissionBatch {
    pub events: Vec<StreamEvent>,
    pub checkpoint: Checkpoint,
    pub expected_seq: u64,
}
pub struct RunEmitter {
    pub lease: RunLease,
    pub scope: ChatScope,
    pub hub: Arc<StreamHub>,
}
impl RunEmitter {
    pub async fn persist(&self, tx: &SpaceTx, batch: &EmissionBatch) -> Result<()> {
        let run = tx
            .guard_run(self.scope.space_id, self.lease)
            .await
            .map_err(|_| Error::Conflict)?;
        if run.assistant_message_id.to_string()
            != batch.checkpoint.message.0["id"]
                .as_str()
                .unwrap_or_default()
            || run.member_id != self.scope.member_id.0
        {
            return Err(Error::Conflict);
        }
        persist(tx, self.scope.space_id, batch).await?;
        tx.guard_run(self.scope.space_id, self.lease)
            .await
            .map_err(|_| Error::Conflict)?;
        Ok(())
    }
    pub async fn commit(&self, tx: SpaceTx, batch: EmissionBatch) -> Result<()> {
        self.persist(&tx, &batch).await?;
        tx.commit().await.map_err(|_| Error::Unavailable)?;
        publish(&self.hub, batch).await
    }
}
/// Used by authorized user transitions and the sweeper while holding the run row
/// and the space lock. Worker callers must use RunEmitter::persist instead.
pub async fn persist(tx: &SpaceTx, space: SpaceId, batch: &EmissionBatch) -> Result<()> {
    let id: Uuid = batch.checkpoint.message.0["id"]
        .as_str()
        .ok_or(Error::Conflict)?
        .parse()
        .map_err(|_| Error::Conflict)?;
    if batch.checkpoint.last_seq != batch.expected_seq + batch.events.len() as u64 {
        return Err(Error::Conflict);
    }
    tx.save_emission(
        space,
        id,
        i32::try_from(batch.expected_seq).map_err(|_| Error::Conflict)?,
        batch.checkpoint.message.0.clone(),
        batch.events.iter().map(|e| e.0.clone()).collect(),
        serde_json::to_value(&batch.checkpoint.step_work_ms).map_err(|_| Error::Conflict)?,
    )
    .await
    .map_err(|_| Error::Conflict)
}
pub async fn publish(hub: &StreamHub, batch: EmissionBatch) -> Result<()> {
    for event in batch.events {
        hub.publish(event).await?;
    }
    Ok(())
}
pub fn resume_service(db: AppDb, scope: ChatScope, hub: Arc<StreamHub>) -> ResumeService {
    ResumeService::new(
        Arc::new(PgEventLog {
            db: db.clone(),
            scope,
        }),
        hub,
        Arc::new(PgCheckpointStore { db, scope }),
    )
}
/// Opening a stream always rechecks live membership and message ownership.
pub async fn open_stream(
    db: AppDb,
    scope: ChatScope,
    hub: Arc<StreamHub>,
    id: Uuid,
    options: ResumeOptions,
) -> Result<EventStream> {
    let tx = SpaceTx::begin(&db, scope.user_id, &[(scope.space_id, None)], Mode::Read)
        .await
        .map_err(|_| Error::NotFound)?;
    if tx.member(scope.space_id).id() != scope.member_id
        || tx
            .message(scope.space_id, id)
            .await
            .map_err(|_| Error::Unavailable)?
            .is_none()
    {
        return Err(Error::NotFound);
    }
    tx.commit().await.map_err(|_| Error::Unavailable)?;
    resume_service(db, scope, hub)
        .open(&id.to_string(), options)
        .await
}

pub fn validate_action_request(value: &serde_json::Value) -> Result<()> {
    validator()?
        .validate(chatweave_protocol::DocumentKind::ActionRequest, value)
        .map_err(|_| Error::Conflict)
}
pub use chatweave_protocol::FoldState;
pub use chatweave_server::{Error as ChatError, Result as ChatResult};

pub fn checkpoint(stored: jiabu_db::chat_runtime::StoredMessage) -> Checkpoint {
    Checkpoint {
        message: Message(stored.message),
        last_seq: stored.last_seq as u64,
        step_work_ms: stored.step_work_ms,
    }
}
/// Host-authored terminal accounting text. ChatWeave still generates and folds
/// every block/step closure. Re-fold after changing the terminal explanation so
/// replay and the persisted checkpoint remain byte-equivalent.
pub fn terminal_summary(
    initial: &Checkpoint,
    mut batch: EmissionBatch,
    summary: &str,
) -> Result<EmissionBatch> {
    if let Some(end) = batch
        .events
        .last_mut()
        .filter(|e| e.event_type() == "message.end")
    {
        let fallback = end.0["fallbackText"].as_str().unwrap_or_default();
        end.0["fallbackText"] = serde_json::json!(format!("{fallback}\n\n{summary}"));
        if end.0.get("error").is_some() {
            end.0["error"]["message"] = serde_json::json!(summary);
        }
    }
    let mut fold = FoldState::from_checkpoint(initial.message.clone(), initial.last_seq)
        .map_err(|_| Error::Conflict)?;
    for event in &batch.events {
        validator()?
            .validate(chatweave_protocol::DocumentKind::Event, &event.0)
            .map_err(|_| Error::Conflict)?;
        fold.apply(event.clone()).map_err(|_| Error::Conflict)?;
    }
    let message = fold.message().map_err(|_| Error::Conflict)?;
    validator()?
        .validate(chatweave_protocol::DocumentKind::Message, &message.0)
        .map_err(|_| Error::Conflict)?;
    batch.checkpoint.message = message;
    Ok(batch)
}
/// Reuses ChatWeave framing/headers/15s heartbeat. Ping chunks do not reset the
/// host's independent five-minute idle deadline.
pub async fn sse_response(
    service: &ResumeService,
    message_id: &str,
    headers: &axum::http::HeaderMap,
    after: Option<&str>,
    options: ResumeOptions,
) -> Result<axum::response::Response> {
    use futures_util::StreamExt;
    let response =
        chatweave_server::sse::sse_response(service, message_id, headers, after, options).await?;
    let (parts, body) = response.into_parts();
    let stream = Box::pin(body.into_data_stream());
    let idle = std::time::Duration::from_secs(300);
    let stream = futures_util::stream::unfold(
        (stream, tokio::time::Instant::now() + idle),
        move |(mut stream, mut deadline)| async move {
            match tokio::time::timeout_at(deadline, stream.next()).await {
                Ok(Some(chunk)) => {
                    if chunk.as_ref().is_ok_and(|bytes| !bytes.starts_with(b":")) {
                        deadline = tokio::time::Instant::now() + idle;
                    }
                    Some((chunk, (stream, deadline)))
                }
                _ => None,
            }
        },
    );
    Ok(axum::response::Response::from_parts(
        parts,
        axum::body::Body::from_stream(stream),
    ))
}
/// Called after host module authorization for a persisted block amendment.
/// A final amendment changes rev/change_seq, never the streaming watermark.
pub async fn revise_final(
    tx: &SpaceTx,
    space: SpaceId,
    id: Uuid,
    expected_rev: i32,
    message: Message,
) -> Result<()> {
    validator()?
        .validate(chatweave_protocol::DocumentKind::Message, &message.0)
        .map_err(|_| Error::Conflict)?;
    tx.revise_final_chat_message(space, id, expected_rev, message.0)
        .await
        .map_err(|_| Error::Conflict)
}
