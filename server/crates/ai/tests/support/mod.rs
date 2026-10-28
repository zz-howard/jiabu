#![allow(dead_code)]
use async_trait::async_trait;
use jiabu_ai::credentials::{TokenStore, VersionedToken};
use jiabu_ai::siwc::oauth::OAuthCredentials;
use jiabu_ai::*;
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};
use uuid::Uuid;
#[derive(Default)]
pub struct Sink(pub Vec<TurnEvent>);
#[async_trait]
impl TurnSink for Sink {
    async fn emit(&mut self, event: TurnEvent) -> Result<(), ProviderError> {
        self.0.push(event);
        Ok(())
    }
}
#[derive(Default)]
pub struct Meter {
    pub calls: Mutex<Vec<(String, String)>>,
    pub results: Mutex<Vec<Option<String>>>,
}
#[async_trait]
impl CallObserver for Meter {
    async fn begin(
        &self,
        p: &str,
        m: &str,
        _task: TaskKind,
        _req: &TurnRequest,
    ) -> Result<i64, ProviderError> {
        let mut c = self.calls.lock().unwrap();
        c.push((p.into(), m.into()));
        Ok(c.len() as i64)
    }
    async fn finish(
        &self,
        _id: i64,
        _elapsed: Duration,
        _usage: Option<&Usage>,
        error: Option<&ProviderError>,
    ) -> Result<(), ProviderError> {
        self.results
            .lock()
            .unwrap()
            .push(error.map(|e| e.kind().to_owned()));
        Ok(())
    }
}
pub struct Tokens(pub Mutex<VersionedToken>);
impl Tokens {
    pub fn new(expires_at: i64) -> Arc<Self> {
        Arc::new(Self(Mutex::new(VersionedToken {
            revision: 1,
            usable: true,
            credentials: OAuthCredentials {
                access_token: "synthetic-access".into(),
                refresh_token: "synthetic-refresh".into(),
                client_id: "oaiapp_fake".into(),
                account_id: "synthetic-account".into(),
                expires_at,
                host_id: Uuid::nil(),
            },
        })))
    }
}
#[async_trait]
impl TokenStore for Tokens {
    async fn load(&self) -> Result<VersionedToken, ProviderError> {
        Ok(self.0.lock().unwrap().clone())
    }
    async fn compare_exchange(
        &self,
        revision: i64,
        next: &OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        let mut v = self.0.lock().unwrap();
        if v.revision != revision {
            return Ok(false);
        }
        v.revision += 1;
        v.credentials = next.clone();
        v.usable = true;
        Ok(true)
    }
    async fn invalidate(&self, revision: i64) -> Result<bool, ProviderError> {
        let mut v = self.0.lock().unwrap();
        if v.revision != revision {
            return Ok(false);
        }
        v.revision += 1;
        v.usable = false;
        Ok(true)
    }
}
pub fn request() -> TurnRequest {
    TurnRequest {
        run_id: Uuid::nil(),
        session_key: "00000000-0000-7000-8000-000000000001".into(),
        snapshot: PromptSnapshot {
            instructions: "Use household tools.".into(),
            model: "synthetic-model".into(),
            parameters: ModelParameters::default(),
            tools: vec![ToolDefinition {
                name: "create_record".into(),
                description: "Create a synthetic record".into(),
                parameters: serde_json::json!({"type":"object","properties":{"amount":{"type":"integer"}},"required":["amount"],"additionalProperties":false}),
            }],
        },
        items: vec![RequestItem::Message {
            role: "user".into(),
            text: "Synthetic receipt".into(),
            images: vec!["data:image/jpeg;base64,/9j/2Q==".into()],
        }],
        provider_blobs: vec![],
    }
}
pub fn capabilities() -> Capabilities {
    Capabilities {
        structured: StructuredMode::ToolCall,
        vision: true,
        max_images: 8,
        context_tokens: 32000,
    }
}
pub fn config() -> AiConfig {
    let mut c = AiConfig {
        version: 1,
        ..AiConfig::default()
    };
    for (n, billing) in [(1, Billing::Subscription), (2, Billing::Paid)] {
        let id = format!("fake-{n}");
        let model_id = Uuid::from_u128(n);
        c.providers.push(ProviderConfig {
            id: id.clone(),
            kind: "mock".into(),
            base_url: None,
            billing,
            secret_source: None,
            enabled: true,
            version: 1,
        });
        c.models.push(ModelConfig {
            id: model_id,
            provider_id: id,
            model: format!("model-{n}"),
            structured: StructuredMode::ToolCall,
            vision: true,
            context_tokens: Some(32000),
            enabled: true,
        });
        c.routes.push(RouteConfig {
            task_kind: TaskKind::Chat,
            position: n as i16,
            model_id,
        });
    }
    c
}
pub fn sse(events: &[serde_json::Value]) -> String {
    events.iter().map(|e| format!("data: {e}\n\n")).collect()
}
pub fn completed() -> serde_json::Value {
    serde_json::json!({"type":"response.completed","response":{"status":"completed","output":[],"usage":{"input_tokens":100,"output_tokens":12,"input_tokens_details":{"cached_tokens":60,"cache_write_tokens":10}}}})
}
