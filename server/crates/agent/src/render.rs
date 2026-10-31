use jiabu_ai::{PromptSnapshot, RequestItem, TurnRequest};
use jiabu_db::chat_runtime::JournalItem;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use uuid::Uuid;
#[derive(Clone, Serialize, Deserialize)]
pub struct FrozenPrompt {
    #[serde(default)]
    pub frozen_for: Option<Uuid>,
    #[serde(default)]
    pub drop_provider_blobs: bool,
    pub snapshot: PromptSnapshot,
    pub context: Value,
    pub input: Value,
    pub history: Vec<Value>,
    pub permissions: Value,
    pub tool_versions: Value,
}
/// Recursively sort maps, independently of serde_json's preserve_order feature.
/// Strings (in particular args_raw), image references and arrays remain intact.
pub fn canonical(value: &Value) -> Value {
    match value {
        Value::Object(map) => {
            let sorted: std::collections::BTreeMap<_, _> =
                map.iter().map(|(k, v)| (k.clone(), canonical(v))).collect();
            let mut map = serde_json::Map::new();
            for (k, v) in sorted {
                map.insert(k, v);
            }
            Value::Object(map)
        }
        Value::Array(a) => Value::Array(a.iter().map(canonical).collect()),
        v => v.clone(),
    }
}
pub fn bytes(value: &Value) -> Result<Vec<u8>, serde_json::Error> {
    serde_json::to_vec(&canonical(value))
}
pub fn truncate_history(history: &[Value], byte_budget: usize) -> Vec<Value> {
    let mut used = 0usize;
    let mut result = Vec::new();
    for message in history.iter().rev() {
        let n = message.to_string().len();
        if used.saturating_add(n) > byte_budget {
            break;
        }
        used += n;
        result.push(message.clone());
    }
    result.reverse();
    result
}
/// Six independently frozen segments. Only segment six grows within a run.
pub fn segments(prompt: &FrozenPrompt, journal: &[JournalItem]) -> [Value; 6] {
    [
        json!({"instructions":prompt.snapshot.instructions}),
        json!({"tools":prompt.snapshot.tools}),
        prompt.context.clone(),
        json!(prompt.history),
        prompt.input.clone(),
        json!(journal),
    ]
}
pub fn render_request(
    run: Uuid,
    session: String,
    prompt: &FrozenPrompt,
    journal: &[JournalItem],
) -> Result<TurnRequest, serde_json::Error> {
    let mut snapshot = prompt.snapshot.clone();
    snapshot.instructions = format!(
        "{}\nSPACE_CONTEXT\n{}",
        snapshot.instructions,
        String::from_utf8_lossy(&bytes(&prompt.context)?)
    );
    let mut items = Vec::new();
    for message in &prompt.history {
        items.push(RequestItem::Message {
            role: message["role"].as_str().unwrap_or("assistant").into(),
            text: message["fallbackText"].as_str().unwrap_or_default().into(),
            images: vec![],
            files: vec![],
        });
    }
    items.push(RequestItem::Message {
        role: "user".into(),
        text: serde_json::to_string(&canonical(&prompt.input))?,
        images: prompt.input["images"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(|v| v.as_str().map(str::to_owned))
            .collect(),
        files: prompt.input["files"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(|file| {
                Some(jiabu_ai::FileAttachment {
                    name: file["name"].as_str()?.to_owned(),
                    mime: file["mime"].as_str()?.to_owned(),
                    data: file["sha256"].as_str()?.to_owned(),
                })
            })
            .collect(),
    });
    for item in journal {
        match item.kind.as_str() {
            "model_turn" => {
                // Turns journaled with `assistant_message` items replay every output item
                // in order. Older turns only kept the text, which replays first.
                let ordered = item.payload["items"]
                    .as_array()
                    .is_some_and(|i| i.iter().any(|v| v["kind"] == "assistant_message"));
                if !ordered
                    && let Some(text) = item.payload["text"].as_str().filter(|t| !t.is_empty())
                {
                    items.push(RequestItem::Message {
                        role: "assistant".into(),
                        text: text.into(),
                        images: vec![],
                        files: vec![],
                    });
                }
                if let Some(output) = item.payload["items"].as_array() {
                    for v in output {
                        if let Some(idx) = v["blob_index"].as_u64() {
                            if prompt.drop_provider_blobs {
                                continue;
                            }
                            if let Some(blob) = item
                                .provider_blob
                                .as_ref()
                                .and_then(|b| b.get(idx as usize))
                            {
                                items.push(serde_json::from_value(blob.clone())?);
                            }
                        } else {
                            items.push(serde_json::from_value(v.clone())?);
                        }
                    }
                }
            }
            "tool_result" => {
                if let Some(call_id) = &item.call_id {
                    items.push(RequestItem::ToolResult {
                        call_id: call_id.clone(),
                        output: serde_json::to_string(&canonical(&item.payload["output"]))?,
                    });
                }
            }
            "note" if item.payload.get("frozen_prompt").is_some() => {}
            "note" | "interrupt_answer" => items.push(RequestItem::Message {
                role: "developer".into(),
                text: serde_json::to_string(&canonical(&item.payload))?,
                images: vec![],
                files: vec![],
            }),
            _ => {}
        }
    }
    Ok(TurnRequest {
        run_id: run,
        session_key: session,
        snapshot,
        items,
    })
}

pub fn static_instructions(catalog: &[u8]) -> String {
    format!(
        "You are 家簿 / Jiabu. Use tools for facts and writes. Ask about ambiguous dates. Use context IDs and bilingual preset aliases. Match the user's language; locale is a fallback. Never reveal reasoning.\nUI\nDISPLAY_TOOLS: show_metrics, show_trend, show_records, show_breakdown, show_bar_chart\n组件中的数字只能来自工具或服务端查询，不能自行填写。展示组件后只用一两句话说结论，不要重复罗列数字；一句普通文字更清楚时不要展示组件。只有用户明确要求演示或示例时才可使用 demo 数据。不要使用 Mermaid、字符/ASCII 图表、HTML、代码块图表，或超过 5 行的 Markdown 表格。\nTEMPLATES\n{}",
        String::from_utf8_lossy(catalog)
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn history_truncates_whole_recent_messages_without_state() {
        let h = vec![json!({"text":"older"}), json!({"text":"recent"})];
        assert_eq!(
            truncate_history(&h, h[1].to_string().len()),
            vec![h[1].clone()]
        );
    }
    #[test]
    fn canonical_preserves_raw_arguments_and_array_order() {
        let v = json!({"z":[2,1],"a":"{ \"x\" : 1 }"});
        assert_eq!(
            bytes(&v).ok(),
            Some(br#"{"a":"{ \"x\" : 1 }","z":[2,1]}"#.to_vec())
        );
    }
    #[test]
    fn static_prompt_declares_display_capabilities_and_ui_rules() {
        let prompt = static_instructions(b"[]");
        for required in [
            "UI\nDISPLAY_TOOLS: show_metrics, show_trend, show_records, show_breakdown, show_bar_chart",
            "数字只能来自工具或服务端查询",
            "只用一两句话说结论",
            "不要重复罗列数字",
            "一句普通文字更清楚时不要展示组件",
            "明确要求演示或示例",
            "Mermaid",
            "字符/ASCII 图表",
            "HTML",
            "代码块图表",
            "超过 5 行的 Markdown 表格",
        ] {
            assert!(prompt.contains(required), "missing UI rule: {required}");
        }
    }
}
