//! Durable chat runs. HTTP binding remains a separate delivery step.
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
/// Failed calls per tool that the model may follow with another try before the run
/// fails: the first attempt plus this many corrections.
pub const MAX_TOOL_CORRECTIONS: usize = 2;
/// Tool-result error codes that ask the model to change its arguments.
pub const CORRECTABLE_ERRORS: [&str; 3] =
    ["invalid_arguments", "unknown_tool", "validation_failed"];
/// A failed tool result counts toward the correction bound whatever its code: the
/// model chose the arguments, and any repeated failure on the same tool should stop.
/// Only the retry migration's `tool_schema_changed` (not the model's doing) is exempt.
pub fn counts_as_failure(output: &serde_json::Value) -> bool {
    output["error"]
        .as_str()
        .is_some_and(|c| c != "tool_schema_changed")
}
/// Failures that name what to fix get a correction hint in their tool result.
fn correctable(output: &serde_json::Value) -> bool {
    output["error"]
        .as_str()
        .is_some_and(|c| CORRECTABLE_ERRORS.contains(&c))
        || output["errors"].as_array().is_some_and(|e| !e.is_empty())
}
/// What the model sees for a failed call: the code plus field-level issues when known.
pub fn tool_error_output(error: &OperationError) -> serde_json::Value {
    let mut output = serde_json::json!({"error": error.code});
    if let Some(errors) = &error.errors {
        output["errors"] = serde_json::json!(errors);
    }
    if correctable(&output) {
        output["note"] = serde_json::json!(
            "Fix the listed fields and call the tool again, or ask the user for the missing information."
        );
    }
    output
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
/// Stateless facade. Bind db/space/epoch/hub with scoped() for runtime work.
/// Legacy unbound calls remain fail-closed until HTTP handlers are wired in step 3.
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

mod decision;
mod executor;
pub mod render;
mod runtime;
mod service;
pub use decision::{
    NextAction, corrections_exhausted, newly_unavailable_displays, next_action,
    unavailable_displays,
};
pub use executor::ToolExecutor;
pub use runtime::{ImageLoader, Runtime, RuntimeHandle};
pub use service::ScopedRuns;
mod meter;
pub use meter::RuntimeMeter;
mod budget;
pub use budget::RunBudget;
