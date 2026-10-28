use chatweave_protocol::{Limits, SchemaRegistry, Validator};
use chatweave_server::{Error, Result};
use serde_json::{Value, json};
pub fn validator() -> Result<Validator> {
    let mut registry = SchemaRegistry::default();
    for (kind, key) in [
        ("x-jiabu.record_card", "recordId"),
        ("x-jiabu.document_card", "documentId"),
    ] {
        let schema = json!({"type":"object","required":[key,"versionAtReply"],"additionalProperties":false,"properties":{"versionAtReply":{"type":"integer","minimum":1}}});
        // json! object keys containing variables must be parenthesized.
        let mut schema = schema;
        schema["properties"] = json!({"versionAtReply":{"type":"integer","minimum":1}});
        schema["properties"][key] = json!({"type":"string","format":"uuid"});
        registry
            .register(kind, 1, schema)
            .map_err(|_| Error::Unavailable)?;
    }
    Validator::new(Limits::default(), registry).map_err(|_| Error::Unavailable)
}
/// Only structured tool results enter this mapping. Model text never does.
pub fn map_tool_result(
    tool: &str,
    result: &Value,
) -> Result<Option<(&'static str, Value, String)>> {
    let card = match tool {
        "create_record" | "update_record" | "void_record" | "restore_record" => {
            Some(("x-jiabu.record_card", "recordId", "record"))
        }
        "create_document" | "update_document" | "void_document" | "restore_document" => {
            Some(("x-jiabu.document_card", "documentId", "document"))
        }
        _ => None,
    };
    if let Some((kind, key, nested)) = card {
        let entity = result.get(nested).unwrap_or(result);
        let id = entity["id"].as_str().ok_or(Error::Conflict)?;
        let version = entity["version"].as_i64().ok_or(Error::Conflict)?;
        let mut data = json!({"versionAtReply":version});
        data[key] = json!(id);
        return Ok(Some((kind, data, "已保存 / Saved".into())));
    }
    match tool {
        "query_stats" => {
            let groups = result["groups"].as_array().ok_or(Error::Conflict)?;
            if groups.is_empty() {
                return Ok(Some((
                    "metric",
                    json!({"label":"合计 / Total","value":result["total"],"unit":"分 / minor units"}),
                    "统计结果 / Statistics".into(),
                )));
            }
            let metrics:Vec<_>=groups.iter().map(|g|json!({"label":g["key"].as_str().unwrap_or("未分类 / Unclassified"),"value":g["value"],"unit":"分 / minor units"})).collect();
            Ok(Some((
                "metric_group",
                json!({"metrics":metrics}),
                "统计结果 / Statistics".into(),
            )))
        }
        "query_balance" => {
            let balances = result["balances"].as_array().ok_or(Error::Conflict)?;
            let metrics:Vec<_>=balances.iter().map(|b|json!({"label":b["account_id"].as_str().unwrap_or("账户 / Account"),"value":b["balance_minor"],"unit":"分 / minor units"})).collect();
            if metrics.len() == 1 {
                Ok(Some((
                    "metric",
                    metrics[0].clone(),
                    "余额 / Balance".into(),
                )))
            } else if metrics.is_empty() {
                Ok(None)
            } else {
                Ok(Some((
                    "metric_group",
                    json!({"metrics":metrics}),
                    "余额 / Balances".into(),
                )))
            }
        }
        "document_metric_series" => {
            let points: Vec<_> = result["points"]
                .as_array()
                .ok_or(Error::Conflict)?
                .iter()
                .map(|p| json!({"x":p["event_date"],"y":p["value"]}))
                .collect();
            if points.is_empty() {
                return Ok(None);
            }
            Ok(Some((
                "time_series",
                json!({"xType":"date","series":[{"key":"value","label":result["metric"],"points":points}]}),
                "历次数据 / History".into(),
            )))
        }
        "search_records" => {
            let rows: Vec<_> = result["records"]
                .as_array()
                .ok_or(Error::Conflict)?
                .iter()
                .map(|r| json!({"id":r["id"],"date":r["occurred_on"],"amount":r["amount_minor"]}))
                .collect();
            if rows.is_empty() {
                return Ok(None);
            }
            Ok(Some((
                "dataset",
                json!({"columns":[{"key":"id","label":"记录 / Record","type":"string"},{"key":"date","label":"日期 / Date","type":"date"},{"key":"amount","label":"金额（分） / Minor units","type":"integer"}],"rows":rows}),
                "记录 / Records".into(),
            )))
        }
        "create_account" | "update_account" => {
            let row = json!({"id":result["id"],"name":result["name"],"kind":result["kind"]});
            Ok(Some((
                "dataset",
                json!({"columns":[{"key":"id","label":"ID","type":"string"},{"key":"name","label":"账户 / Account","type":"string"},{"key":"kind","label":"种类 / Kind","type":"string"}],"rows":[row]}),
                "账户 / Account".into(),
            )))
        }
        "list_accounts" => {
            let rows: Vec<_> = result["accounts"]
                .as_array()
                .ok_or(Error::Conflict)?
                .iter()
                .map(|a| json!({"id":a["id"],"name":a["name"],"kind":a["kind"]}))
                .collect();
            if rows.is_empty() {
                return Ok(None);
            }
            Ok(Some((
                "dataset",
                json!({"columns":[{"key":"id","label":"ID","type":"string"},{"key":"name","label":"账户 / Account","type":"string"},{"key":"kind","label":"种类 / Kind","type":"string"}],"rows":rows}),
                "账户 / Accounts".into(),
            )))
        }
        _ => Ok(None),
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn custom_card_contains_only_identity_and_reply_version() {
        let mapped = map_tool_result(
            "create_record",
            &json!({"id":"00000000-0000-7000-8000-000000000004","version":2,"amount_minor":5000}),
        );
        let Ok(Some((kind, data, _))) = mapped else {
            panic!("missing card");
        };
        assert_eq!(kind, "x-jiabu.record_card");
        assert_eq!(data.as_object().map(|m| m.len()), Some(2));
        assert_eq!(data["versionAtReply"], 2);
    }
    #[test]
    fn model_text_is_never_parsed_as_business_data() {
        assert!(matches!(
            map_tool_result("model_text", &json!({"text":"午饭 50"})),
            Ok(None)
        ));
    }
}
