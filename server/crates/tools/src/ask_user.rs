use crate::{
    Effect, Exposure, StepKind, StepLabel, ToolCtx, ToolError, TypedTool, tool::ToolFuture,
};
use jiabu_db::SpaceTx;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use validator::Validate;
#[derive(Clone, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct AskOption {
    pub id: String,
    pub label: String,
}
#[derive(Clone, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct AskField {
    pub key: String,
    pub label: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub required: bool,
}
#[derive(Clone, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct AskArgs {
    #[validate(length(min = 1, max = 2000))]
    pub prompt: String,
    #[serde(default)]
    pub options: Vec<AskOption>,
    #[serde(default)]
    pub fields: Vec<AskField>,
}
impl AskArgs {
    pub fn check(&self) -> Result<(), ToolError> {
        self.validate().map_err(|_| ToolError::invalid())?;
        if (!self.options.is_empty() && !self.fields.is_empty())
            || self.options.len() > 10
            || self.options.len() == 1
            || self.fields.len() > 12
        {
            return Err(ToolError::invalid());
        }
        let mut keys = std::collections::BTreeSet::new();
        for o in &self.options {
            if o.id.is_empty() || o.label.is_empty() || !keys.insert(o.id.as_str()) {
                return Err(ToolError::invalid());
            }
        }
        keys.clear();
        for f in &self.fields {
            if f.key.is_empty()
                || f.label.is_empty()
                || !matches!(f.kind.as_str(), "text" | "number" | "date" | "boolean")
                || !keys.insert(f.key.as_str())
            {
                return Err(ToolError::invalid());
            }
        }
        Ok(())
    }
}
#[derive(Serialize, JsonSchema)]
pub struct AskOutput {
    pub answer: Value,
}
pub(super) struct AskUser;
impl TypedTool for AskUser {
    type Args = AskArgs;
    type Output = AskOutput;
    fn name(&self) -> &'static str {
        "ask_user"
    }
    fn description(&self) -> &'static str {
        "Ask one question using choices, a form, or free text; suspend until the user answers."
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
    fn step_label(&self, _: &Self::Args, _: &ToolCtx) -> StepLabel {
        StepLabel("等待回答")
    }
    fn example_args(&self) -> Value {
        json!({"prompt":"选择分类 / Choose category","options":[{"id":"dining","label":"餐饮 / Dining"},{"id":"transport","label":"交通 / Transport"}],"fields":[]})
    }
    fn example_output(&self) -> Value {
        json!({"answer":{"selected":["dining"]}})
    }
    fn execute<'a>(
        &'a self,
        _: Self::Args,
        _: &'a ToolCtx,
        _: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>> {
        Box::pin(async { Err(ToolError::new(409, "agent_interrupt_required")) })
    }
}
