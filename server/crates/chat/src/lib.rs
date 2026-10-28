//! S7 transport boundaries. Persistence and emission deliberately fail closed in step 1.
use async_trait::async_trait;
use chatweave_server::{Error, Result};

pub use chatweave_protocol::{Message, StreamEvent};
pub use chatweave_server::checkpoint::{Checkpoint, CheckpointStore};
pub use chatweave_server::event_log::{BroadcastHub as StreamHub, EventLog, ReplayBatch};
pub use chatweave_server::resume::{ResumeOptions, ResumeService};
pub use chatweave_server::sse::sse_response;

/// Scope is supplied only after host membership and conversation authorization.
#[derive(Clone, Copy)]
pub struct ChatScope {
    pub space_id: jiabu_domain::SpaceId,
    pub member_id: jiabu_domain::MemberId,
}

pub struct PgEventLog {
    pub db: jiabu_db::AppDb,
    pub scope: ChatScope,
}
#[async_trait]
impl EventLog for PgEventLog {
    async fn append(&self, _event: StreamEvent) -> Result<()> {
        // Durable writes must eventually go through RunEmitter's guarded transaction.
        Err(Error::Unavailable)
    }
    async fn read_after(&self, _message_id: &str, _after: u64) -> Result<ReplayBatch> {
        Err(Error::Unavailable)
    }
    async fn read_range(
        &self,
        _message_id: &str,
        _after: u64,
        _through: u64,
    ) -> Result<ReplayBatch> {
        Err(Error::Unavailable)
    }
}

pub struct PgCheckpointStore {
    pub db: jiabu_db::AppDb,
    pub scope: ChatScope,
}
#[async_trait]
impl CheckpointStore for PgCheckpointStore {
    async fn load(&self, _message_id: &str) -> Result<Option<Checkpoint>> {
        Err(Error::Unavailable)
    }
    async fn commit(&self, _checkpoint: Checkpoint, _expected_seq: Option<u64>) -> Result<()> {
        Err(Error::Unavailable)
    }
}

/// No event may be broadcast before the guarded SpaceTx has committed.
/// Step 1 exposes the batch boundary without pretending persistence has succeeded.
pub struct RunEmitter {
    pub run_id: uuid::Uuid,
    pub lease_epoch: i64,
}
pub struct EmissionBatch {
    pub events: Vec<StreamEvent>,
    pub checkpoint: Checkpoint,
}
impl RunEmitter {
    pub async fn commit(&self, _tx: &mut jiabu_db::SpaceTx, _batch: EmissionBatch) -> Result<()> {
        Err(Error::Unavailable)
    }
}
