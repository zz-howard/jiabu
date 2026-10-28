//! Bounded SSE decoder. output_item.done is authoritative; deltas are UI-only.
use crate::{ProviderError, TurnSink, types::*};
use serde_json::Value;
use std::collections::BTreeMap;
const LIMIT: usize = 8 * 1024 * 1024;
#[derive(Default)]
pub struct Decoder {
    buffer: Vec<u8>,
    data: Vec<String>,
    size: usize,
}
impl Decoder {
    pub fn push(&mut self, chunk: &[u8]) -> Result<Vec<Value>, ProviderError> {
        self.buffer.extend_from_slice(chunk);
        if self.buffer.len() > LIMIT {
            return Err(ProviderError::InvalidOutput);
        }
        let mut result = vec![];
        while let Some(pos) = self.buffer.iter().position(|b| *b == b'\n') {
            let line: Vec<_> = self.buffer.drain(..=pos).collect();
            let line = std::str::from_utf8(&line)
                .map_err(|_| ProviderError::InvalidOutput)?
                .trim_end_matches(['\r', '\n']);
            if line.is_empty() {
                if !self.data.is_empty() {
                    let data = self.data.join("\n");
                    self.data.clear();
                    self.size = 0;
                    if data != "[DONE]" {
                        result.push(
                            serde_json::from_str(&data)
                                .map_err(|_| ProviderError::InvalidOutput)?,
                        );
                    }
                }
            } else if let Some(data) = line.strip_prefix("data:") {
                let data = data.strip_prefix(' ').unwrap_or(data);
                self.size += data.len();
                if self.size > LIMIT {
                    return Err(ProviderError::InvalidOutput);
                }
                self.data.push(data.into());
            }
        }
        Ok(result)
    }
}
#[derive(Default)]
pub struct TurnState {
    items: BTreeMap<u64, Value>,
    text: BTreeMap<u64, String>,
    completed: bool,
    pub usage: Option<Usage>,
}
impl TurnState {
    pub fn completed(&self) -> bool {
        self.completed
    }
    pub async fn accept(
        &mut self,
        event: Value,
        sink: &mut dyn TurnSink,
    ) -> Result<(), ProviderError> {
        if self.completed {
            return Err(ProviderError::InvalidOutput);
        }
        match event["type"].as_str().ok_or(ProviderError::InvalidOutput)? {
            "response.output_text.delta" => {
                let delta = event["delta"]
                    .as_str()
                    .ok_or(ProviderError::InvalidOutput)?;
                let index = event["output_index"]
                    .as_u64()
                    .ok_or(ProviderError::InvalidOutput)?;
                self.text.entry(index).or_default().push_str(delta);
                sink.emit(TurnEvent::TextDelta(delta.into())).await?;
            }
            "response.output_item.done" => {
                let index = event["output_index"]
                    .as_u64()
                    .ok_or(ProviderError::InvalidOutput)?;
                let item = event
                    .get("item")
                    .cloned()
                    .ok_or(ProviderError::InvalidOutput)?;
                if let Some(old) = self.items.get(&index)
                    && old != &item
                {
                    return Err(ProviderError::InvalidOutput);
                }
                self.items.insert(index, item);
            }
            "response.completed" => {
                if event["response"]["status"]
                    .as_str()
                    .is_some_and(|s| s != "completed")
                {
                    return Err(ProviderError::InvalidOutput);
                }
                let usage = &event["response"]["usage"];
                if !usage.is_object()
                    || !usage["input_tokens"].is_i64()
                    || !usage["output_tokens"].is_i64()
                {
                    return Err(ProviderError::InvalidOutput);
                }
                let token = |v: &Value| -> Result<i32, ProviderError> {
                    let n = v.as_i64().unwrap_or(0);
                    if n < 0 {
                        return Err(ProviderError::InvalidOutput);
                    }
                    i32::try_from(n).map_err(|_| ProviderError::InvalidOutput)
                };
                self.usage = Some(Usage {
                    input_tokens: token(&usage["input_tokens"])?,
                    output_tokens: token(&usage["output_tokens"])?,
                    cached_input_tokens: token(&usage["input_tokens_details"]["cached_tokens"])?,
                    cache_write_tokens: token(
                        &usage["input_tokens_details"]["cache_write_tokens"],
                    )?,
                });
                self.completed = true;
            }
            "response.failed" | "error" => return Err(error(&event)),
            "response.incomplete" => return Err(ProviderError::InvalidOutput),
            _ => {} // reasoning summaries and partial function arguments are discarded.
        }
        Ok(())
    }
    /// Only publish complete calls/blobs after completed. Never append done-text to
    /// already streamed text, and never trust completed.output (empty with store=false).
    pub async fn finish(
        &self,
        provider: &str,
        model: &str,
        account: &str,
        sink: &mut dyn TurnSink,
    ) -> Result<(), ProviderError> {
        if !self.completed
            || self
                .text
                .keys()
                .any(|index| !self.items.contains_key(index))
        {
            return Err(ProviderError::InvalidOutput);
        }
        for (index, item) in &self.items {
            match item["type"].as_str() {
                Some("function_call") => {
                    let get = |key: &str| {
                        item[key]
                            .as_str()
                            .map(str::to_owned)
                            .ok_or(ProviderError::InvalidOutput)
                    };
                    let name = get("name")?;
                    let name = if name.starts_with("jiabu.") {
                        name
                    } else {
                        format!("jiabu.{name}")
                    };
                    sink.emit(TurnEvent::ToolCall {
                        call_id: get("call_id")?,
                        name,
                        args_raw: get("arguments")?,
                    })
                    .await?;
                }
                Some("reasoning") if item["encrypted_content"].is_string() => {
                    let mut opaque = serde_json::json!({"type":"reasoning","encrypted_content":item["encrypted_content"],"summary":[]});
                    if let Some(id) = item.get("id") {
                        opaque["id"] = id.clone();
                    }
                    sink.emit(TurnEvent::ProviderBlob(ProviderBlob {
                        provider_id: provider.into(),
                        model: model.into(),
                        account_id: account.into(),
                        item: opaque,
                    }))
                    .await?;
                }
                Some("message") => {
                    let content = item["content"]
                        .as_array()
                        .ok_or(ProviderError::InvalidOutput)?;
                    let mut full = String::new();
                    for part in content {
                        if part["type"] == "output_text" {
                            full.push_str(
                                part["text"].as_str().ok_or(ProviderError::InvalidOutput)?,
                            );
                        }
                    }
                    let prefix = self.text.get(index).map(String::as_str).unwrap_or("");
                    let suffix = full
                        .strip_prefix(prefix)
                        .ok_or(ProviderError::InvalidOutput)?;
                    if !suffix.is_empty() {
                        sink.emit(TurnEvent::TextDelta(suffix.into())).await?;
                    }
                }
                _ => return Err(ProviderError::InvalidOutput),
            }
        }
        sink.emit(TurnEvent::Done {
            usage: self.usage.clone().ok_or(ProviderError::InvalidOutput)?,
        })
        .await
    }
}
pub fn error(event: &Value) -> ProviderError {
    let err = event
        .get("response")
        .and_then(|r| r.get("error"))
        .or_else(|| event.get("error"))
        .unwrap_or(event);
    match err["code"].as_str().unwrap_or("") {
        "subscription_sharing_usage_limit_exceeded"
        | "subscription_sharing_usage_unavailable"
        | "insufficient_quota" => ProviderError::QuotaExhausted,
        "invalid_api_key" | "invalid_token" | "token_expired" => ProviderError::Auth,
        "permission_denied"
        | "insufficient_permissions"
        | "model_not_found"
        | "model_access_denied" => ProviderError::Unsupported("permission denied"),
        "invalid_encrypted_content" | "encrypted_content_invalid" => ProviderError::BlobRejected,
        "rate_limit_exceeded" => ProviderError::RateLimited { retry_after: None },
        _ => ProviderError::InvalidOutput,
    }
}
