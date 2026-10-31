use crate::{ProviderError, types::*};
use serde_json::{Value, json};
/// Build by allowlist. Never serialize SDK default fields into the wire request.
pub fn body(
    req: &TurnRequest,
    provider_id: &str,
    account_id: &str,
) -> Result<Value, ProviderError> {
    let mut input = vec![];
    for item in &req.items {
        input.push(match item {
            RequestItem::Message { role, text, images, files } => {
                if !matches!(role.as_str(), "user" | "assistant" | "developer") { return Err(ProviderError::Unsupported("message role")); }
                if role == "assistant" && !images.is_empty() { return Err(ProviderError::Unsupported("assistant images")); }
                if role == "assistant" && !files.is_empty() { return Err(ProviderError::Unsupported("assistant files")); }
                // Upstream rejects `input_text` parts in assistant history (invalid_value at
                // input[n].content[0]); plain string content is valid for every role.
                if role == "assistant" { input.push(json!({"role":role,"content":text})); continue; }
                let mut content = vec![json!({"type":"input_text","text":text})];
                for image in images {
                    if !image.starts_with("data:image/jpeg;base64,") { return Err(ProviderError::Unsupported("JPEG data URL required")); }
                    content.push(json!({"type":"input_image","image_url":image,"detail":"auto"}));
                }
                for file in files {
                    if file.mime != "application/pdf" || !file.data.starts_with("data:application/pdf;base64,") {
                        return Err(ProviderError::Unsupported("PDF data URL required"));
                    }
                    content.push(json!({"type":"input_file","filename":file.name,"file_data":file.data}));
                }
                json!({"role":role,"content":content})
            },
            RequestItem::ToolCall { call_id,name,args_raw } => json!({"type":"function_call","call_id":call_id,"namespace":"jiabu","name":name.strip_prefix("jiabu.").unwrap_or(name),"arguments":args_raw}),
            // Model output replays in its output position as an easy input message with
            // string content (as for history) plus its `phase`, which upstream asks
            // stateless clients to preserve on assistant messages.
            RequestItem::AssistantMessage { text, phase } => {
                if text.is_empty() { continue; }
                let mut message = json!({"role":"assistant","content":text});
                if let Some(phase) = phase { message["phase"] = json!(phase); }
                message
            },
            RequestItem::ToolResult { call_id,output } => json!({"type":"function_call_output","call_id":call_id,"output":output}),
            RequestItem::ProviderBlob(blob) => {
                if blob.provider_id != provider_id
                    || blob.model != req.snapshot.model
                    || blob.account_id != account_id
                {
                    continue;
                }
                blob.item.clone()
            },
        });
    }
    let tools: Vec<_> = req
        .snapshot
        .tools
        .iter()
        .map(|t| json!({"type":"function","name":t.name,"description":t.description,"parameters":t.parameters,"strict":strict_compatible(&t.parameters)}))
        .collect();
    let tools = if tools.is_empty() {
        vec![]
    } else {
        vec![
            json!({"type":"namespace","name":"jiabu","description":"Jiabu household tools","tools":tools}),
        ]
    };
    let mut body = json!({"model":req.snapshot.model,"instructions":req.snapshot.instructions,"input":input,"tools":tools,
        "store":false,"stream":true,"prompt_cache_key":req.session_key,"include":["reasoning.encrypted_content"]});
    let params = &req.snapshot.parameters;
    if let Some(effort) = &params.reasoning_effort {
        if !matches!(
            effort.as_str(),
            "none" | "minimal" | "low" | "medium" | "high" | "xhigh"
        ) {
            return Err(ProviderError::Unsupported("reasoning effort"));
        }
        body["reasoning"] = json!({"effort":effort});
    }
    if let Some(verbosity) = &params.verbosity {
        if !matches!(verbosity.as_str(), "low" | "medium" | "high") {
            return Err(ProviderError::Unsupported("verbosity"));
        }
        body["text"] = json!({"verbosity":verbosity});
    }
    if let Some(choice) = &params.tool_choice {
        if !matches!(choice.as_str(), "auto" | "none" | "required") {
            return Err(ProviderError::Unsupported("tool choice"));
        }
        body["tool_choice"] = json!(choice);
    }
    // Validate the upstream typed contract while keeping the allowlisted JSON intact.
    let _: async_openai::types::responses::CreateResponse =
        serde_json::from_value(body.clone()).map_err(|_| ProviderError::InvalidOutput)?;
    Ok(body)
}

/// Upstream rejects a strict function whose objects leave a declared property out of
/// `required` or allow additional properties. Optional fields are not rewritten as
/// required-but-nullable (in patch tools null clears and omission keeps), so such
/// tools are sent `strict: false` and the agent validates their arguments.
pub fn strict_compatible(schema: &Value) -> bool {
    match schema {
        Value::Object(map) => {
            let is_object = map.contains_key("properties")
                || match map.get("type") {
                    Some(Value::String(t)) => t == "object",
                    Some(Value::Array(types)) => types.iter().any(|t| t == "object"),
                    _ => false,
                };
            if is_object {
                if map.get("additionalProperties") != Some(&Value::Bool(false)) {
                    return false;
                }
                let required: Vec<&str> = map
                    .get("required")
                    .and_then(Value::as_array)
                    .map(|r| r.iter().filter_map(Value::as_str).collect())
                    .unwrap_or_default();
                if let Some(properties) = map.get("properties").and_then(Value::as_object)
                    && properties.keys().any(|k| !required.contains(&k.as_str()))
                {
                    return false;
                }
            }
            // `properties` and `$defs` map names to schemas; the maps are not schemas.
            map.iter().all(|(key, value)| match (key.as_str(), value) {
                ("properties" | "$defs" | "definitions", Value::Object(named)) => {
                    named.values().all(strict_compatible)
                }
                _ => strict_compatible(value),
            })
        }
        Value::Array(items) => items.iter().all(strict_compatible),
        _ => true,
    }
}
