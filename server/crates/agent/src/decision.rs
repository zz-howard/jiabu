use jiabu_db::chat_runtime::{JournalItem, ToolCallRow};
use serde_json::Value;
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NextAction {
    Model,
    Execute(String),
    Interrupt(String),
    Complete,
    InvalidJournal,
}
/// Calls are visited in provider order, never SQL row order. Non-interrupting
/// work in a turn finishes before its first question is shown.
pub fn next_action(items: &[JournalItem], calls: &[ToolCallRow]) -> NextAction {
    let Some(turn) = items.iter().rev().find(|i| i.kind == "model_turn") else {
        return NextAction::Model;
    };
    let Some(proposed) = turn.payload["calls"].as_array() else {
        return NextAction::InvalidJournal;
    };
    if proposed.is_empty() {
        return NextAction::Complete;
    }
    let mut interrupt = None;
    for proposal in proposed {
        let Some(id) = proposal["call_id"].as_str() else {
            return NextAction::InvalidJournal;
        };
        if items
            .iter()
            .any(|i| i.kind == "tool_result" && i.call_id.as_deref() == Some(id))
        {
            continue;
        }
        let Some(call) = calls.iter().find(|c| c.call_id == id) else {
            return NextAction::InvalidJournal;
        };
        match call.status.as_str() {
            "approved" => return NextAction::Execute(id.into()),
            "proposed"
                if call.tool != "ask_user"
                    && call.guard.as_ref().and_then(|g| g.get("confirmation"))
                        != Some(&Value::Bool(true)) =>
            {
                return NextAction::Execute(id.into());
            }
            "proposed" | "awaiting_user" => {
                if interrupt.is_none() {
                    interrupt = Some(id.to_owned());
                }
            }
            // A committed terminal call without a result is corrupt; never guess
            // whether its side effect happened.
            _ => return NextAction::InvalidJournal,
        }
    }
    interrupt.map_or(NextAction::Model, NextAction::Interrupt)
}
/// The first tool whose correctable failures exceed the first attempt plus
/// `MAX_TOOL_CORRECTIONS`. The model stops getting another try once this is `Some`.
pub fn corrections_exhausted<'a>(
    items: &[JournalItem],
    calls: &'a [ToolCallRow],
) -> Option<&'a str> {
    let mut counts = std::collections::BTreeMap::<&str, usize>::new();
    for item in items.iter().filter(|i| i.kind == "tool_result") {
        let code = item.payload["output"]["error"].as_str();
        if !code.is_some_and(|c| crate::CORRECTABLE_ERRORS.contains(&c)) {
            continue;
        }
        let Some(call) = calls
            .iter()
            .find(|c| item.call_id.as_deref() == Some(c.call_id.as_str()))
        else {
            continue;
        };
        let n = counts.entry(call.tool.as_str()).or_default();
        *n += 1;
        if *n > crate::MAX_TOOL_CORRECTIONS {
            return Some(call.tool.as_str());
        }
    }
    None
}
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use uuid::Uuid;
    #[test]
    fn next_action_table_covers_call_states_and_results() {
        let turn = JournalItem {
            idx: 1,
            kind: "model_turn".into(),
            call_id: None,
            payload: json!({"calls":[{"call_id":"a"},{"call_id":"b"}]}),
            provider_blob: None,
        };
        let make = |id: &str, status: &str, ask: bool| ToolCallRow {
            call_id: id.into(),
            tool: if ask { "ask_user" } else { "create_record" }.into(),
            tool_schema_version: 1,
            args: json!({}),
            effect: "read".into(),
            status: status.into(),
            idempotency_key: Uuid::nil(),
            guard: None,
        };
        assert_eq!(next_action(&[], &[]), NextAction::Model);
        assert_eq!(
            next_action(
                std::slice::from_ref(&turn),
                &[make("a", "proposed", true), make("b", "proposed", false)]
            ),
            NextAction::Execute("b".into())
        );
        for status in [
            "succeeded",
            "failed",
            "cancelled",
            "expired",
            "executing",
            "rejected",
        ] {
            assert_eq!(
                next_action(std::slice::from_ref(&turn), &[make("a", status, false)]),
                NextAction::InvalidJournal
            );
        }
        for status in ["proposed", "approved"] {
            assert_eq!(
                next_action(std::slice::from_ref(&turn), &[make("a", status, false)]),
                NextAction::Execute("a".into())
            );
        }
        let result = |id: &str| JournalItem {
            idx: 2,
            kind: "tool_result".into(),
            call_id: Some(id.into()),
            payload: json!({"output":"ok"}),
            provider_blob: None,
        };
        assert_eq!(
            next_action(
                &[turn.clone(), result("b")],
                &[make("a", "awaiting_user", true)]
            ),
            NextAction::Interrupt("a".into())
        );
        assert_eq!(
            next_action(&[turn, result("a"), result("b")], &[]),
            NextAction::Model
        );
        assert_eq!(
            next_action(
                &[JournalItem {
                    idx: 1,
                    kind: "model_turn".into(),
                    call_id: None,
                    payload: json!({"calls":[]}),
                    provider_blob: None
                }],
                &[]
            ),
            NextAction::Complete
        );
    }
}
