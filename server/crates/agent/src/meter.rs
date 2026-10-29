//! Database metering remains independent of the run's transactional journal.
use jiabu_ai::{CallObserver, ProviderError, TaskKind, TurnRequest, Usage};
use jiabu_db::{
    AppDb,
    ai_metering::{CallFinish, CallStart},
};
use sha2::{Digest, Sha256};
use std::time::Duration;
use uuid::Uuid;
pub struct RuntimeMeter {
    pub db: AppDb,
    pub token: Uuid,
}
#[async_trait::async_trait]
impl CallObserver for RuntimeMeter {
    async fn begin(
        &self,
        provider: &str,
        model: &str,
        task: TaskKind,
        request: &TurnRequest,
    ) -> Result<i64, ProviderError> {
        let kind = self
            .db
            .runtime_call_kind(request.run_id)
            .await
            .map_err(|_| ProviderError::Meter)?;
        let id = self
            .db
            .register_ai_call(CallStart {
                run_id: Some(request.run_id),
                task: task.as_str(),
                provider,
                model,
                structured: "tool_call",
                call_kind: &kind,
                attempt_token: self.token,
            })
            .await
            .map_err(|_| ProviderError::Meter)?;
        let prefix=crate::render::bytes(&serde_json::json!({"instructions":request.snapshot.instructions,"tools":request.snapshot.tools})).map_err(|_|ProviderError::Meter)?;
        self.db
            .set_ai_prefix_hash(id, self.token, Sha256::digest(prefix).to_vec())
            .await
            .map_err(|_| ProviderError::Meter)?;
        Ok(id)
    }
    async fn finish(
        &self,
        id: i64,
        elapsed: Duration,
        usage: Option<&Usage>,
        error: Option<&ProviderError>,
    ) -> Result<(), ProviderError> {
        self.db
            .finish_ai_call(CallFinish {
                id,
                attempt_token: self.token,
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
