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
            RequestItem::Message { role, text, images } => {
                if !matches!(role.as_str(), "user" | "assistant" | "developer") { return Err(ProviderError::Unsupported("message role")); }
                if role == "assistant" && !images.is_empty() { return Err(ProviderError::Unsupported("assistant images")); }
                let mut content = vec![json!({"type":"input_text","text":text})];
                for image in images {
                    if !image.starts_with("data:image/jpeg;base64,") { return Err(ProviderError::Unsupported("JPEG data URL required")); }
                    content.push(json!({"type":"input_image","image_url":image,"detail":"auto"}));
                }
                json!({"role":role,"content":content})
            },
            RequestItem::ToolCall { call_id,name,args_raw } => json!({"type":"function_call","call_id":call_id,"namespace":"jiabu","name":name.strip_prefix("jiabu.").unwrap_or(name),"arguments":args_raw}),
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
    let tools: Vec<_> = req.snapshot.tools.iter().map(|t| json!({"type":"function","name":t.name,"description":t.description,"parameters":t.parameters,"strict":true})).collect();
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
