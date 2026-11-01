use crate::{
    agent_fixture::{call, done, text},
    dataset::{Behavior, Entry, RecordSpec},
};
use anyhow::{Context, Result};
use jiabu_ai::mock::TurnScript;
use serde_json::{Value, json};
use std::collections::BTreeMap;
use uuid::Uuid;
#[derive(Default)]
pub struct Identities {
    pub accounts: BTreeMap<String, Uuid>,
    pub records: BTreeMap<String, Uuid>,
    pub versions: BTreeMap<String, i32>,
    pub tags: BTreeMap<String, Uuid>,
}
impl Identities {
    fn account(&self, key: &Option<String>) -> Result<Option<Uuid>> {
        key.as_ref()
            .map(|k| {
                self.accounts
                    .get(k)
                    .copied()
                    .context("unknown account alias")
            })
            .transpose()
    }
    pub fn args(&self, r: &RecordSpec) -> Result<(String, Value)> {
        let mut fields = json!({});
        for (key, value) in [
            ("kind", r.kind.as_ref().map(|v| json!(v))),
            ("amount_minor", r.amount_minor.map(|v| json!(v))),
            ("occurred_on", r.occurred_on.map(|v| json!(v))),
        ] {
            if let Some(v) = value {
                fields[key] = v;
            }
        }
        for (key, value) in [
            ("account_id", self.account(&r.account)?),
            ("purpose_id", self.account(&r.purpose)?),
            ("to_account_id", self.account(&r.to_account)?),
            ("to_purpose_id", self.account(&r.to_purpose)?),
        ] {
            if let Some(v) = value {
                fields[key] = json!(v);
            }
        }
        let preset_keys = r
            .preset_key
            .iter()
            .chain(&r.preset_keys)
            .collect::<Vec<_>>();
        if !preset_keys.is_empty() {
            fields["tag_ids"] = Value::Array(
                preset_keys
                    .into_iter()
                    .map(|key| {
                        self.tags
                            .get(key)
                            .copied()
                            .map(|id| json!(id))
                            .context("unknown preset")
                    })
                    .collect::<Result<_>>()?,
            );
        }
        if let Some(k) = &r.refund_of {
            fields["refund_of_id"] = json!(self.records.get(k).context("unknown refund parent")?);
        }
        if r.operation == "create" {
            return Ok(("create_record".into(), fields));
        }
        let target = r.target.as_ref().context("missing target")?;
        let id = self.records.get(target).context("unknown target")?;
        let version = self.versions.get(target).copied().unwrap_or(1);
        let args = if r.operation == "update" {
            let patch = fields.as_object_mut().context("fields")?;
            patch.remove("kind");
            patch.remove("refund_of_id");
            json!({"id":id,"expected_version":version,"changes":fields})
        } else {
            json!({"id":id,"expected_version":version})
        };
        Ok((format!("{}_record", r.operation), args))
    }
    pub fn display_args(&self, value: &Value) -> Result<Value> {
        self.display_args_with_calls(value, &BTreeMap::new())
    }
    pub fn display_args_with_calls(
        &self,
        value: &Value,
        calls: &BTreeMap<String, String>,
    ) -> Result<Value> {
        Ok(match value {
            Value::String(value) if value.starts_with("$account:") => {
                let alias = value.trim_start_matches("$account:");
                json!(
                    self.accounts
                        .get(alias)
                        .context("unknown display account alias")?
                )
            }
            Value::String(value) if value.starts_with("$call:") => json!(
                calls
                    .get(value)
                    .context("unknown display source-call alias")?
            ),
            Value::Array(values) => Value::Array(
                values
                    .iter()
                    .map(|value| self.display_args_with_calls(value, calls))
                    .collect::<Result<_>>()?,
            ),
            Value::Object(values) => Value::Object(
                values
                    .iter()
                    .map(|(key, value)| {
                        Ok((key.clone(), self.display_args_with_calls(value, calls)?))
                    })
                    .collect::<Result<_>>()?,
            ),
            value => value.clone(),
        })
    }
}
pub fn scripts(e: &Entry, ids: &Identities) -> Result<Vec<TurnScript>> {
    if let Some(display) = &e.expect.display {
        let display = &display.alternatives[0];
        let final_text = if display.fallback_contains.is_empty() {
            if e.locale == "en" {
                "Displayed.".to_owned()
            } else {
                "已展示。".to_owned()
            }
        } else {
            display.fallback_contains.join("；")
        };
        if display.calls.is_empty() && display.source_calls.is_empty() {
            return Ok(vec![vec![text(&final_text), done()]]);
        }
        let call_aliases: BTreeMap<_, _> = display
            .source_calls
            .iter()
            .enumerate()
            .map(|(index, _)| (format!("$call:source-{index}"), format!("source-{index}")))
            .collect();
        let mut turns = Vec::new();
        if !display.source_calls.is_empty() {
            let mut source_turn = display
                .source_calls
                .iter()
                .enumerate()
                .map(|(index, call_spec)| {
                    Ok(call(
                        &format!("source-{index}"),
                        &call_spec.tool,
                        ids.display_args(&call_spec.args)?,
                    ))
                })
                .collect::<Result<Vec<_>>>()?;
            source_turn.push(done());
            turns.push(source_turn);
        }
        if !display.calls.is_empty() {
            let mut turn = display
                .calls
                .iter()
                .enumerate()
                .map(|(index, call_spec)| {
                    Ok(call(
                        &format!("display-{index}"),
                        &call_spec.tool,
                        ids.display_args_with_calls(&call_spec.args, &call_aliases)?,
                    ))
                })
                .collect::<Result<Vec<_>>>()?;
            turn.push(done());
            turns.push(turn);
        }
        turns.push(vec![text(&final_text), done()]);
        return Ok(turns);
    }
    Ok(match e.expect.behavior {
        Behavior::AskUser => vec![vec![
            call(
                "question",
                "ask_user",
                json!({"prompt":"请补充缺少的信息 / Please clarify the missing information","options":[],"fields":[]}),
            ),
            done(),
        ]],
        Behavior::NoWrite => vec![vec![text("你好 / Hello"), done()]],
        _ => {
            let mut turn = Vec::new();
            for (i, r) in e.expect.records.iter().enumerate() {
                let (tool, args) = ids.args(r)?;
                turn.push(call(&format!("record-{i}"), &tool, args));
            }
            turn.push(done());
            vec![turn, vec![text("已保存 / Saved"), done()]]
        }
    })
}
