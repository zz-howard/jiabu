//! Validate every delivered ToolCall before forwarding to the runtime. Invalid
//! calls may be rejected before journal commit; keep counts, never raw content.
use async_trait::async_trait;
use jiabu_ai::*;
use serde::Serialize;
use serde_json::{Value, json};
use std::{
    sync::{
        Arc, Mutex,
        atomic::{AtomicUsize, Ordering},
    },
    time::Duration,
};
pub const DISPLAY_AUDIT_LIMIT: usize = 16;
#[derive(Clone, Debug, Serialize)]
pub struct DisplayAuditCall {
    pub tool: String,
    pub valid: bool,
    pub summary: Value,
    pub truncated: bool,
    pub discarded: usize,
}
pub struct ToolAudit {
    pub total: AtomicUsize,
    pub valid: AtomicUsize,
    pub display: Mutex<Vec<DisplayAuditCall>>,
    pub display_total: AtomicUsize,
    pub display_valid: AtomicUsize,
    pub display_discarded: AtomicUsize,
}
impl Default for ToolAudit {
    fn default() -> Self {
        Self {
            total: AtomicUsize::new(0),
            valid: AtomicUsize::new(0),
            display: Mutex::new(Vec::new()),
            display_total: AtomicUsize::new(0),
            display_valid: AtomicUsize::new(0),
            display_discarded: AtomicUsize::new(0),
        }
    }
}
pub struct AuditedProvider {
    pub inner: Arc<dyn ModelProvider>,
    pub registry: Arc<jiabu_tools::ToolRegistry>,
    pub audit: Arc<ToolAudit>,
}
struct Sink<'a> {
    inner: &'a mut dyn TurnSink,
    registry: &'a jiabu_tools::ToolRegistry,
    audit: &'a ToolAudit,
}
fn known_display(name: &str) -> Option<&'static str> {
    match name {
        "show_metrics" => Some("show_metrics"),
        "show_breakdown" => Some("show_breakdown"),
        "show_bar_chart" => Some("show_bar_chart"),
        "show_trend" => Some("show_trend"),
        "show_records" => Some("show_records"),
        "show_account_card" => Some("show_account_card"),
        _ => None,
    }
}
fn bounded(value: &str) -> String {
    let mut bytes = 0;
    value
        .chars()
        .take_while(|character| {
            let fits = bytes + character.len_utf8() <= 64;
            if fits {
                bytes += character.len_utf8();
            }
            fits
        })
        .collect()
}
fn enum_value(value: &Value, discarded: &mut usize) -> Value {
    value.as_str().map_or(Value::Null, |value| {
        let bounded = bounded(value);
        *discarded += value.len().saturating_sub(bounded.len());
        json!(bounded)
    })
}
fn sanitize_query(query: &Value, discarded: &mut usize) -> Value {
    let mut out = serde_json::Map::new();
    for key in ["measure", "group_by", "order"] {
        if let Some(value) = query.get(key) {
            out.insert(key.into(), enum_value(value, discarded));
        }
    }
    if let Some(kinds) = query.get("kinds").and_then(Value::as_array) {
        *discarded += kinds.len().saturating_sub(16);
        out.insert(
            "kinds".into(),
            Value::Array(
                kinds
                    .iter()
                    .take(16)
                    .map(|value| enum_value(value, discarded))
                    .collect(),
            ),
        );
    }
    if let Some(period) = query.get("period") {
        out.insert(
            "period".into(),
            json!({"from":enum_value(&period["from"],discarded),"through":enum_value(&period["through"],discarded)}),
        );
    }
    for key in ["account_id", "purpose_id", "tag_id", "member_id"] {
        if query.get(key).is_some_and(|value| !value.is_null()) {
            out.insert(key.into(), json!("<redacted-id>"));
        }
    }
    if let Some(limit) = query.get("limit").and_then(Value::as_u64) {
        out.insert("limit".into(), json!(limit));
    }
    if query.get("text").is_some_and(|value| !value.is_null()) {
        out.insert("text_present".into(), json!(true));
    }
    Value::Object(out)
}
fn sanitized_summary(name: Option<&str>, args: Option<&Value>) -> (Value, usize) {
    let (Some(name), Some(args)) = (name, args) else {
        return (json!({}), 0);
    };
    if name == "show_account_card" {
        return (
            json!({"account_id_present":!args["account_id"].is_null()}),
            0,
        );
    }
    let source = &args["source"];
    if !source["demo"].is_null() {
        let mut discarded = 0;
        let summary = json!({"source":"demo","scene":enum_value(&source["demo"],&mut discarded)});
        return (summary, discarded);
    }
    if !source["from_call"].is_null() {
        return (json!({"source":"from_call"}), 0);
    }
    if !source["query"].is_null() {
        let mut discarded = 0;
        let query = sanitize_query(&source["query"], &mut discarded);
        return (
            json!({"source":"query","query":query,"truncated":discarded>0,"discarded":discarded}),
            discarded,
        );
    }
    (json!({}), 0)
}
#[async_trait]
impl TurnSink for Sink<'_> {
    fn record_usage(&mut self, usage: &Usage) {
        self.inner.record_usage(usage);
    }
    async fn emit(&mut self, event: TurnEvent) -> Result<(), ProviderError> {
        if let TurnEvent::ToolCall { name, args_raw, .. } = &event {
            self.audit.total.fetch_add(1, Ordering::Relaxed);
            let valid = (|| {
                let tool = self.registry.get(name).ok()?;
                if tool.exposure() == jiabu_tools::Exposure::ApiOnly {
                    return None;
                }
                let args: serde_json::Value = serde_json::from_str(args_raw).ok()?;
                tool.validate(args.clone()).ok()?;
                if name == "ask_user" {
                    serde_json::from_value::<jiabu_tools::AskArgs>(args)
                        .ok()?
                        .check()
                        .ok()?;
                }
                Some(())
            })()
            .is_some();
            if valid {
                self.audit.valid.fetch_add(1, Ordering::Relaxed);
            }
            let known = known_display(name);
            if known.is_some() || name.starts_with("show_") {
                self.audit.display_total.fetch_add(1, Ordering::Relaxed);
                if valid {
                    self.audit.display_valid.fetch_add(1, Ordering::Relaxed);
                }
                let args = serde_json::from_str::<Value>(args_raw).ok();
                let (summary, discarded) = if valid {
                    sanitized_summary(known, args.as_ref())
                } else {
                    (json!({}), 0)
                };
                let call = DisplayAuditCall {
                    tool: known.unwrap_or("<unknown>").into(),
                    valid,
                    summary,
                    truncated: discarded > 0,
                    discarded,
                };
                let mut display = self.audit.display.lock().unwrap_or_else(|e| e.into_inner());
                if display.len() < DISPLAY_AUDIT_LIMIT {
                    display.push(call);
                } else {
                    self.audit.display_discarded.fetch_add(1, Ordering::Relaxed);
                }
            }
        }
        self.inner.emit(event).await
    }
}
#[async_trait]
impl ModelProvider for AuditedProvider {
    fn id(&self) -> &str {
        self.inner.id()
    }
    fn capabilities(&self) -> &Capabilities {
        self.inner.capabilities()
    }
    fn credentials_available(&self) -> bool {
        self.inner.credentials_available()
    }
    async fn run_turn(
        &self,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
    ) -> Result<(), ProviderError> {
        self.inner
            .run_turn(
                req,
                &mut Sink {
                    inner: sink,
                    registry: &self.registry,
                    audit: &self.audit,
                },
            )
            .await
    }
    async fn run_turn_observed(
        &self,
        task: TaskKind,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
        observer: &dyn CallObserver,
        budget: Duration,
    ) -> Result<(), ProviderError> {
        // Delegate the observed method so SIWC refresh retries retain independent metering.
        self.inner
            .run_turn_observed(
                task,
                req,
                &mut Sink {
                    inner: sink,
                    registry: &self.registry,
                    audit: &self.audit,
                },
                observer,
                budget,
            )
            .await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sanitized_summary_truncates_utf8_strings_on_byte_boundaries() {
        let long = "界".repeat(22);
        let args = json!({"source":{"query":{"order":long},"from_call":null,"demo":null}});
        let (summary, discarded) = sanitized_summary(Some("show_records"), Some(&args));
        let order = summary["query"]["order"].as_str().unwrap();
        assert_eq!(order.as_bytes().len(), 63);
        assert_eq!(order.chars().count(), 21);
        assert_eq!(discarded, 3);
        assert_eq!(summary["truncated"], true);
        assert_eq!(summary["discarded"], 3);
    }
}
