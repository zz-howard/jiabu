pub use jiabu_domain::ai::{StructuredMode, TaskKind};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Capabilities {
    pub structured: StructuredMode,
    pub vision: bool,
    pub max_images: u8,
    pub context_tokens: u32,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ToolDefinition {
    pub name: String,
    pub description: String,
    pub parameters: Value,
}
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct ModelParameters {
    pub reasoning_effort: Option<String>,
    pub verbosity: Option<String>,
    pub tool_choice: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PromptSnapshot {
    pub instructions: String,
    pub tools: Vec<ToolDefinition>,
    pub model: String,
    #[serde(default)]
    pub parameters: ModelParameters,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RequestItem {
    Message {
        role: String,
        text: String,
        images: Vec<String>,
    },
    ToolCall {
        call_id: String,
        name: String,
        args_raw: String,
    },
    ToolResult {
        call_id: String,
        output: String,
    },
    /// Replay in its original output position, only when all scope identifiers match.
    ProviderBlob(ProviderBlob),
}
/// Never log provider blobs; scope must match all three identifiers.
#[derive(Clone, Serialize, Deserialize)]
pub struct ProviderBlob {
    pub provider_id: String,
    pub model: String,
    pub account_id: String,
    pub item: Value,
}
impl std::fmt::Debug for ProviderBlob {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("ProviderBlob([redacted])")
    }
}
#[derive(Clone, Serialize, Deserialize)]
pub struct TurnRequest {
    pub run_id: Uuid,
    pub session_key: String,
    pub snapshot: PromptSnapshot,
    pub items: Vec<RequestItem>,
}
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Usage {
    pub input_tokens: i32,
    pub output_tokens: i32,
    pub cached_input_tokens: i32,
    pub cache_write_tokens: i32,
}
#[derive(Clone)]
pub enum TurnEvent {
    TextDelta(String),
    ToolCall {
        call_id: String,
        name: String,
        args_raw: String,
    },
    ProviderBlob(ProviderBlob),
    /// The agent must persist this note before a new measured attempt.
    Note(String),
    Done {
        usage: Usage,
    },
}
