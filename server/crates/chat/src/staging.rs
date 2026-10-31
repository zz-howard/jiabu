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
    /// Markdown is a delta stream, never a component block.data event.
    pub async fn markdown(&self, text: &str) -> Result<()> {
        let block = self.stream.start_block("markdown", 1, "").await?;
        block.append_text(text).await?;
        block.finish().await
    }
    /// A card the protocol rejects (e.g. more than 12 metrics, or a message that
    /// would exceed its size limit) is skipped rather than failing the run; the
    /// complete tool result still reaches the model. The check runs on a copy of
    /// the current stream so the real stream is never left with a half-open block.
    /// Returns whether the block was emitted.
    pub async fn component(&self, kind: &str, data: Value, fallback: &str) -> Result<bool> {
        let scratch = Self::load(Checkpoint {
            message: self.stream.message().await?,
            last_seq: self.stream.last_seq().await,
            step_work_ms: Default::default(),
        })
        .await?;
        if scratch
            .emit_component(kind, data.clone(), fallback)
            .await
            .is_err()
        {
            return Ok(false);
        }
        self.emit_component(kind, data, fallback).await?;
        Ok(true)
    }
    async fn emit_component(&self, kind: &str, data: Value, fallback: &str) -> Result<()> {
        let block = self.stream.start_block(kind, 1, fallback).await?;
        block.data(data, fallback, None).await?;
        block.finish().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn component_over_protocol_limits_is_skipped_not_failed() -> Result<()> {
        let mut stage = StagedStream::start(StreamConfig::new(Uuid::now_v7().to_string())).await?;
        let metrics = |n: usize| {
            serde_json::json!({"metrics": (0..n)
                .map(|i| serde_json::json!({"label": format!("虚构账户 {i}"), "value": i, "unit": "分"}))
                .collect::<Vec<_>>()})
        };
        stage.component("metric_group", metrics(13), "余额").await?;
        stage.component("metric_group", metrics(2), "余额").await?;
        let blocks = stage.batch().await?.checkpoint.message.0["blocks"].clone();
        let blocks = blocks.as_array().ok_or(Error::Conflict)?;
        assert_eq!(blocks.len(), 1);
        assert_eq!(
            blocks[0]["data"]["metrics"].as_array().map(Vec::len),
            Some(2)
        );
        Ok(())
    }

    #[tokio::test]
    async fn component_that_would_overflow_the_message_is_skipped() -> Result<()> {
        let mut stage = StagedStream::start(StreamConfig::new(Uuid::now_v7().to_string())).await?;
        // 200 rows x 3 cells of 90 chars: each card ~58 KiB (under the 64 KiB block
        // limit and dataset row/cell limits); five exceed the 256 KiB message limit.
        let cell = |i: usize| format!("{i:090}");
        let rows: Vec<_> = (0..200)
            .map(|i| serde_json::json!({"a": cell(i), "b": cell(i), "c": cell(i)}))
            .collect();
        let columns: Vec<_> = ["a", "b", "c"]
            .iter()
            .map(|k| serde_json::json!({"key": k, "label": "虚构", "type": "string"}))
            .collect();
        let data = serde_json::json!({"columns": columns, "rows": rows});
        for _ in 0..5 {
            stage.component("dataset", data.clone(), "记录").await?;
        }
        let message = stage.batch().await?.checkpoint.message;
        let blocks = message.0["blocks"].as_array().ok_or(Error::Conflict)?.len();
        assert!((1..5).contains(&blocks), "{blocks} cards");
        assert!(
            serde_json::to_vec(&message.0)
                .map_err(|_| Error::Conflict)?
                .len()
                <= 256 * 1024
        );
        Ok(())
    }

    #[tokio::test]
    async fn markdown_terminal_text_uses_deltas_and_replays_to_checkpoint() -> Result<()> {
        for stopped in [false, true] {
            let mut stage =
                StagedStream::start(StreamConfig::new(Uuid::now_v7().to_string())).await?;
            let initial = stage.batch().await?.checkpoint;
            stage
                .markdown("虚构收尾文字 / Synthetic terminal text")
                .await?;
            if stopped {
                stage.stream.stop().await?;
            } else {
                stage.stream.fail("虚构失败 / Synthetic failure").await?;
            }
            let batch = stage.batch().await?;
            assert!(batch.events.iter().any(|e| e.event_type() == "block.delta"));
            assert!(!batch.events.iter().any(|e| e.event_type() == "block.data"));
            let mut fold = FoldState::from_checkpoint(initial.message, initial.last_seq)
                .map_err(|_| Error::Conflict)?;
            for event in &batch.events {
                validator()?
                    .validate(DocumentKind::Event, &event.0)
                    .map_err(|_| Error::Conflict)?;
                fold.apply(event.clone()).map_err(|_| Error::Conflict)?;
            }
            assert_eq!(
                fold.message().map_err(|_| Error::Conflict)?.0,
                batch.checkpoint.message.0
            );
            assert_eq!(batch.checkpoint.message.rev(), 1);
            assert!(
                batch.checkpoint.message.0["fallbackText"]
                    .as_str()
                    .is_some_and(|text| text.contains("虚构收尾文字"))
            );
        }
        Ok(())
    }
}
