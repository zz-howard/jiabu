//! S7 runtime contracts. Step 1 does not claim, enqueue, or execute runs.
use jiabu_db::{OperationError, Principal};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub const WORKER_COUNT: usize = 2;
pub const LEASE_SECS: u64 = 60;
pub const RENEW_SECS: u64 = 20;
pub const SHUTDOWN_GRACE_SECS: u64 = 20;
pub const MAX_MODEL_TURNS: u32 = 20;
pub const MAX_ACTIVE_SECS: u64 = 600;
pub const MAX_WAITING_AI_SECS: u64 = 600;
pub const MODEL_CALL_TIMEOUT_SECS: u64 = 300;
pub const TOOL_TIMEOUT_SECS: u64 = 10;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RunStatus {
    Queued,
    Running,
    Paused,
    WaitingAi,
    Completed,
    Cancelled,
    Expired,
    Failed,
    Interrupted,
}
#[derive(Clone, Copy, Debug)]
pub struct Lease {
    pub run_id: Uuid,
    pub owner: Uuid,
    pub epoch: i64,
}
/// New calls only. A user retry copies the original stored key verbatim.
pub fn tool_idempotency_key(run_id: Uuid, call_id: &str) -> Uuid {
    Uuid::new_v5(&run_id, call_id.as_bytes())
}

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct StartMessage {
    pub id: Uuid,
    pub text: Option<String>,
    #[serde(default)]
    pub images: Vec<String>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartResponse {
    pub user_message_id: Uuid,
    pub message_id: Uuid,
}
#[derive(Clone, Default)]
pub struct RunService;
impl RunService {
    pub async fn start(
        &self,
        principal: &Principal,
        _input: StartMessage,
    ) -> Result<StartResponse, OperationError> {
        principal.require_ai_session()?;
        Err(OperationError::new(503, "unavailable"))
    }
    pub async fn retry(
        &self,
        principal: &Principal,
        _message_id: Uuid,
    ) -> Result<StartResponse, OperationError> {
        principal.require_ai_session()?;
        Err(OperationError::new(503, "unavailable"))
    }
    pub async fn stop(
        &self,
        principal: &Principal,
        _message_id: Uuid,
    ) -> Result<(), OperationError> {
        principal.require_ai_session()?;
        Err(OperationError::new(503, "unavailable"))
    }
    pub async fn answer(
        &self,
        principal: &Principal,
        _action: serde_json::Value,
    ) -> Result<(), OperationError> {
        principal.require_ai_session()?;
        Err(OperationError::new(503, "unavailable"))
    }
}

/// Worker and sweeper are contracts only; no background tasks start in step 1.
/// Expired leases, shutdown timeouts and PartialOutput end as Interrupted.
/// Only an explicit user retry creates a replacement run.
pub struct Worker {
    pub id: Uuid,
    pub router: std::sync::Arc<jiabu_ai::RouterStore>,
    pub tools: std::sync::Arc<jiabu_tools::ToolRegistry>,
}
pub struct Sweeper;
pub struct ToolExecutor {
    pub registry: std::sync::Arc<jiabu_tools::ToolRegistry>,
}
