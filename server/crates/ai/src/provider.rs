use crate::types::*;
use async_trait::async_trait;
use std::time::{Duration, Instant};
#[derive(Clone, Debug, thiserror::Error, PartialEq, Eq)]
pub enum ProviderError {
    /// Output already reached the sink; callers must retain it and start a new block.
    #[error("partial output: {source}")]
    PartialOutput { source: Box<ProviderError> },
    #[error("rate limited")]
    RateLimited { retry_after: Option<Duration> },
    #[error("quota exhausted")]
    QuotaExhausted,
    #[error("credentials unavailable")]
    Auth,
    #[error("unsupported request: {0}")]
    Unsupported(&'static str),
    #[error("invalid upstream output")]
    InvalidOutput,
    #[error("encrypted reasoning rejected")]
    BlobRejected,
    #[error("provider timed out")]
    Timeout,
    #[error("upstream transport failure")]
    Transport,
    #[error("event persistence failed")]
    Sink,
    #[error("meter persistence failed")]
    Meter,
}
impl ProviderError {
    pub fn kind(&self) -> &'static str {
        match self {
            Self::PartialOutput { .. } => "partial_output",
            Self::RateLimited { .. } => "rate_limited",
            Self::QuotaExhausted => "quota",
            Self::Auth => "auth",
            Self::Unsupported(_) => "unsupported",
            Self::InvalidOutput => "invalid_output",
            Self::BlobRejected => "blob_rejected",
            Self::Timeout => "timeout",
            Self::Transport => "transport",
            Self::Sink => "sink",
            Self::Meter => "meter",
        }
    }
}
#[async_trait]
pub trait TurnSink: Send {
    async fn emit(&mut self, event: TurnEvent) -> Result<(), ProviderError>;
}
#[async_trait]
pub trait ModelProvider: Send + Sync {
    fn id(&self) -> &str;
    fn capabilities(&self) -> &Capabilities;
    fn credentials_available(&self) -> bool {
        true
    }
    async fn run_turn(
        &self,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
    ) -> Result<(), ProviderError>;
}
/// Every physical HTTP attempt calls begin BEFORE transport, and finish independently
/// of the run journal, including the one-time blob/invalid-output retries.
#[async_trait]
pub trait CallObserver: Send + Sync {
    async fn begin(
        &self,
        provider: &str,
        model: &str,
        task: TaskKind,
        req: &TurnRequest,
    ) -> Result<i64, ProviderError>;
    async fn finish(
        &self,
        id: i64,
        elapsed: Duration,
        usage: Option<&Usage>,
        error: Option<&ProviderError>,
    ) -> Result<(), ProviderError>;
}
pub struct AttemptSink<'a> {
    pub inner: &'a mut dyn TurnSink,
    pub usage: Option<Usage>,
}
#[async_trait]
impl TurnSink for AttemptSink<'_> {
    async fn emit(&mut self, event: TurnEvent) -> Result<(), ProviderError> {
        if let TurnEvent::Done { usage } = &event {
            self.usage = Some(usage.clone());
        }
        self.inner.emit(event).await
    }
}
pub async fn measured_attempt(
    provider: &dyn ModelProvider,
    task: TaskKind,
    req: &TurnRequest,
    sink: &mut dyn TurnSink,
    observer: &dyn CallObserver,
    budget: Duration,
) -> Result<(), ProviderError> {
    let deadline = tokio::time::Instant::now() + budget;
    let id = observer
        .begin(provider.id(), &req.snapshot.model, task, req)
        .await?;
    let started = Instant::now();
    let mut tap = AttemptSink {
        inner: sink,
        usage: None,
    };
    // Registration and finalization are never dropped by the provider deadline.
    let result = if tokio::time::Instant::now() >= deadline {
        Err(ProviderError::Timeout)
    } else {
        tokio::time::timeout_at(deadline, provider.run_turn(req, &mut tap))
            .await
            .unwrap_or(Err(ProviderError::Timeout))
    };
    observer
        .finish(
            id,
            started.elapsed(),
            tap.usage.as_ref(),
            result.as_ref().err(),
        )
        .await?;
    result
}
