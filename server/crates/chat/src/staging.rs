use crate::*;
use chatweave_server::event_log::Subscription;
use serde_json::Value;
use tokio::sync::Mutex;
#[derive(Default)]
struct Stage {
    events: Vec<StreamEvent>,
    checkpoint: Option<Checkpoint>,
}
#[derive(Default)]
struct Buffer(Mutex<Stage>);
#[async_trait]
impl EventLog for Buffer {
    async fn append(&self, event: StreamEvent) -> Result<()> {
        self.0.lock().await.events.push(event);
        Ok(())
    }
    async fn read_after(&self, _id: &str, _after: u64) -> Result<ReplayBatch> {
        Err(Error::Unavailable)
    }
    async fn read_range(&self, _id: &str, _after: u64, _through: u64) -> Result<ReplayBatch> {
        Err(Error::Unavailable)
    }
}
#[async_trait]
impl CheckpointStore for Buffer {
    async fn load(&self, _id: &str) -> Result<Option<Checkpoint>> {
        Err(Error::Unavailable)
    }
    async fn commit(&self, cp: Checkpoint, _expected: Option<u64>) -> Result<()> {
        self.0.lock().await.checkpoint = Some(cp);
        Ok(())
    }
}
#[async_trait]
impl EventSink for Buffer {
    async fn subscribe(&self, _id: &str) -> Result<Subscription> {
        Err(Error::Unavailable)
    }
    async fn publish(&self, _event: StreamEvent) -> Result<()> {
        Ok(())
    }
}
/// Buffer is private and never used for replay or recovery. A failed outer
/// transaction discards this instance; callers must not keep producing on it.
pub struct StagedStream {
    pub stream: MessageStream,
    buffer: Arc<Buffer>,
    expected: u64,
}
impl StagedStream {
    pub async fn start(config: StreamConfig) -> Result<Self> {
        let buffer = Arc::new(Buffer::default());
        let stream = MessageStream::start(
            config,
            Arc::new(validator()?),
            buffer.clone(),
            buffer.clone(),
            buffer.clone(),
        )
        .await?;
        Ok(Self {
            stream,
            buffer,
            expected: 0,
        })
    }
    /// Only normal paused/waiting continuations and deterministic terminal
    /// closure use this. Expired model streams are never resumed into a model.
    pub async fn load(cp: Checkpoint) -> Result<Self> {
        let buffer = Arc::new(Buffer::default());
        let id = cp.message.0["id"]
            .as_str()
            .ok_or(Error::Conflict)?
            .to_owned();
        let expected = cp.last_seq;
        let stream = MessageStream::from_checkpoint(
            cp,
            StreamConfig::new(id),
            Arc::new(validator()?),
            buffer.clone(),
            buffer.clone(),
            buffer.clone(),
        )
        .await?;
        Ok(Self {
            stream,
            buffer,
            expected,
        })
    }
    pub async fn batch(&mut self) -> Result<EmissionBatch> {
        let message = self.stream.message().await?;
        let seq = self.stream.last_seq().await;
        let mut buffer = self.buffer.0.lock().await;
        let events = std::mem::take(&mut buffer.events);
        let step_work_ms = buffer
            .checkpoint
            .as_ref()
            .map(|cp| cp.step_work_ms.clone())
            .unwrap_or_default();
        let batch = EmissionBatch {
            events,
            checkpoint: Checkpoint {
                message,
                last_seq: seq,
                step_work_ms,
            },
            expected_seq: self.expected,
        };
        self.expected = seq;
        Ok(batch)
    }
    pub async fn component(&self, kind: &str, data: Value, fallback: &str) -> Result<()> {
        let block = self.stream.start_block(kind, 1, fallback).await?;
        block.data(data, fallback, None).await?;
        block.finish().await
    }
}
