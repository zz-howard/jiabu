use crate::{
    Effect, Exposure, StepKind, StepLabel, ToolCtx, ToolError, TypedTool, tool::ToolFuture,
};
use jiabu_db::SpaceTx;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use validator::Validate;
#[derive(Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct AskArgs {}
#[derive(Serialize, JsonSchema)]
pub struct AskOutput {}
pub(super) struct AskUser;
impl TypedTool for AskUser {
    type Args = AskArgs;
    type Output = AskOutput;
    fn name(&self) -> &'static str {
        "ask_user"
    }
    fn description(&self) -> &'static str {
        "S7 conversation interruption placeholder"
    }
    fn effect(&self) -> Effect {
        Effect::Read
    }
    fn exposure(&self) -> Exposure {
        Exposure::AgentOnly
    }
    fn step_kind(&self) -> StepKind {
        StepKind::AskUser
    }
    fn step_label(&self, _args: &Self::Args, _ctx: &ToolCtx) -> StepLabel {
        StepLabel("等待回答")
    }
    fn example_args(&self) -> Value {
        json!({})
    }
    fn example_output(&self) -> Value {
        json!({})
    }
    fn execute<'a>(
        &'a self,
        _args: Self::Args,
        _ctx: &'a ToolCtx,
        _tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>> {
        Box::pin(async { Err(ToolError::new(503, "unavailable")) })
    }
}
