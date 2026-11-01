//! Isolated synthetic display evidence. Never export provider events or credentials.
use crate::{
    dataset::Entry,
    scoring::{Observation, ResultRow},
};
use anyhow::{Result, ensure};
use serde_json::{Value, json};
use std::{
    io::Write,
    os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt},
    path::Path,
};

fn safe(value: &Value) -> bool {
    match value {
        Value::Object(map) => map.iter().all(|(key, value)| {
            !matches!(
                key.to_lowercase().as_str(),
                "authorization"
                    | "headers"
                    | "access_token"
                    | "refresh_token"
                    | "api_key"
                    | "password"
                    | "provider_blob"
                    | "reasoning"
                    | "thoughts"
                    | "encrypted_content"
            ) && safe(value)
        }),
        Value::Array(values) => values.iter().all(safe),
        Value::String(text) => !text.contains("://") && !text.to_lowercase().contains("bearer "),
        _ => true,
    }
}
pub fn write(dir: &Path, id: &str, stage: &str, value: &Value) -> Result<()> {
    ensure!(safe(value), "evidence contains forbidden material");
    ensure!(
        !id.is_empty()
            && !stage.is_empty()
            && [id, stage].iter().all(|value| value
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'-')),
        "unsafe evidence id"
    );
    std::fs::DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(dir)?;
    std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700))?;
    let mut file = std::fs::OpenOptions::new()
        .create_new(true)
        .write(true)
        .mode(0o600)
        .open(dir.join(format!("{id}-{stage}.json")))?;
    file.write_all(&serde_json::to_vec_pretty(value)?)?;
    Ok(())
}
pub fn capture(
    entry: &Entry,
    obs: &Observation,
    row: &ResultRow,
    input: Option<&crate::judge::JudgeInput>,
) -> Value {
    let blocks = obs.message["blocks"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let rendered = blocks
        .iter()
        .map(|b| json!({"type":b["type"],"data":b["data"]}))
        .collect::<Vec<_>>();
    let component_fallbacks = blocks
        .iter()
        .filter(|b| b["type"] != "markdown")
        .map(|b| json!({"type":b["type"],"fallback_text":b["fallbackText"]}))
        .collect::<Vec<_>>();
    let tools = obs
        .tool_calls
        .iter()
        .filter(|call| {
            matches!(
                call["tool"].as_str(),
                Some(
                    "query_stats"
                        | "search_records"
                        | "query_balance"
                        | "show_metrics"
                        | "show_breakdown"
                        | "show_bar_chart"
                        | "show_trend"
                        | "show_records"
                        | "show_account_card"
                )
            )
        })
        .map(|call| json!({"tool":call["tool"],"call_id":call["call_id"],"args":call["args"]}))
        .collect::<Vec<_>>();
    json!({"assessment_version":crate::report::EXPECTATION_VERSION,"case_id":entry.id,"synthetic_request":entry.input.text,"today":entry.today,"timezone":entry.timezone,"synthetic_setup":entry.setup,"visible_prose":crate::judge::visible_prose(&obs.message),"rendered_blocks":rendered,"component_fallbacks_not_additional_visible_prose":component_fallbacks,"server_fallback_evidence_not_additional_visible_prose":obs.server_fallbacks,"aggregate_transport_fallback_not_additional_visible_prose":obs.message["fallbackText"],"source_tool_calls":tools,"actual_synthetic_records":obs.final_state["records"],"rule_decision":row.rule_decision,"rule_reason_codes":row.reasons,"expectation_met":row.expectation_met,"judgment_source":row.judgment_source,"prepared_judge_input_not_necessarily_sent":input})
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn evidence_rejects_credentials_urls_and_thoughts() {
        for v in [
            json!({"access_token":"hidden"}),
            json!({"rendered_blocks":[{"reasoning":"hidden"}]}),
            json!({"text":"https://example.invalid"}),
            json!({"text":"Bearer hidden"}),
        ] {
            assert!(!safe(&v));
        }
        assert!(safe(
            &json!({"visible_prose":"本月暂无支出。","rendered_blocks":[{"type":"metric","data":{"value":0}}]})
        ));
    }
    #[test]
    fn evidence_files_are_private_and_refuse_overwrite_or_unsafe_names() -> Result<()> {
        let dir = std::env::temp_dir().join(format!("jiabu-evidence-{}", uuid::Uuid::now_v7()));
        let data = json!({"expectation_met":true});
        write(&dir, "display-001", "judge-vote-1", &data)?;
        assert_eq!(std::fs::metadata(&dir)?.permissions().mode() & 0o777, 0o700);
        assert_eq!(
            std::fs::metadata(dir.join("display-001-judge-vote-1.json"))?
                .permissions()
                .mode()
                & 0o777,
            0o600
        );
        assert!(write(&dir, "display-001", "judge-vote-1", &data).is_err());
        assert!(write(&dir, "display-001", "../../escaped", &data).is_err());
        assert!(write(&dir, "../bad", "result", &data).is_err());
        assert!(write(&dir, "display-001", "result", &json!({"headers":{}})).is_err());
        assert!(!dir.join("display-001-result.json").exists());
        std::fs::remove_dir_all(dir)?;
        Ok(())
    }
}
