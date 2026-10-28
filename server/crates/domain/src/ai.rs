//! IO-free AI configuration and encrypted-secret records.
use serde::{Deserialize, Serialize};
use uuid::Uuid;
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskKind {
    Chat,
    ChatVision,
    Probe,
}
impl TaskKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Chat => "chat",
            Self::ChatVision => "chat_vision",
            Self::Probe => "probe",
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Billing {
    Subscription,
    Local,
    Paid,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StructuredMode {
    JsonSchema,
    ToolCall,
    JsonObject,
    PromptOnly,
}
impl StructuredMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::JsonSchema => "json_schema",
            Self::ToolCall => "tool_call",
            Self::JsonObject => "json_object",
            Self::PromptOnly => "prompt_only",
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProviderConfig {
    pub id: String,
    pub kind: String,
    pub base_url: Option<String>,
    pub billing: Billing,
    pub secret_source: Option<String>,
    #[serde(default = "enabled")]
    pub enabled: bool,
    #[serde(default = "version")]
    pub version: i32,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ModelConfig {
    #[serde(default = "Uuid::now_v7")]
    pub id: Uuid,
    pub provider_id: String,
    pub model: String,
    pub structured: StructuredMode,
    pub vision: bool,
    pub context_tokens: Option<u32>,
    #[serde(default = "enabled")]
    pub enabled: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RouteConfig {
    pub task_kind: TaskKind,
    pub position: i16,
    pub model_id: Uuid,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct BreakerConfig {
    pub failures: u32,
    pub cool_down_secs: u64,
}
impl Default for BreakerConfig {
    fn default() -> Self {
        Self {
            failures: 3,
            cool_down_secs: 60,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AiConfig {
    pub version: i64,
    pub allow_paid_fallback: bool,
    pub breaker: BreakerConfig,
    pub retry_initial_secs: u64,
    pub retry_max_secs: u64,
    pub waiting_timeout_secs: u64,
    pub host_id: Uuid,
    pub providers: Vec<ProviderConfig>,
    pub models: Vec<ModelConfig>,
    pub routes: Vec<RouteConfig>,
}
impl Default for AiConfig {
    fn default() -> Self {
        Self {
            version: 0,
            allow_paid_fallback: false,
            breaker: BreakerConfig::default(),
            retry_initial_secs: 5,
            retry_max_secs: 60,
            waiting_timeout_secs: 600,
            host_id: Uuid::nil(),
            providers: vec![],
            models: vec![],
            routes: vec![],
        }
    }
}
/// Deliberately no Debug: neither ciphertext nor credential metadata belongs in logs.
#[derive(Clone)]
pub struct EncryptedSecret {
    pub key_id: String,
    pub nonce: Vec<u8>,
    pub ciphertext: Vec<u8>,
    pub last4: String,
    pub revision: i64,
    pub usable: bool,
}

fn enabled() -> bool {
    true
}
fn version() -> i32 {
    1
}
