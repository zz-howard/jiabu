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
/// Display format for money: raw minor units, the renderer divides (ChatWeave).
fn money_format(currency: &str) -> Value {
    json!({"style":"currency","currency":currency,"minorUnits":true})
}
fn decimals(currency: &str) -> u32 {
    jiabu_domain::money::CURRENCIES
        .iter()
        .find(|c| c.code == currency)
        .map_or(2, |c| u32::from(c.decimals))
}
/// `¥1,234.50` for fallback text; other currencies keep their code.
pub fn money_text(minor: i64, currency: &str) -> String {
    let scale = 10_i64.pow(decimals(currency));
    let abs = minor.unsigned_abs();
    let whole = (abs / scale.unsigned_abs()).to_string();
    let mut grouped = String::new();
    for (i, c) in whole.chars().enumerate() {
        if i > 0 && (whole.len() - i).is_multiple_of(3) {
            grouped.push(',');
        }
        grouped.push(c);
    }
    let fraction = if scale > 1 {
        format!(
            ".{:0width$}",
            abs % scale.unsigned_abs(),
            width = decimals(currency) as usize
        )
    } else {
        String::new()
    };
    let sign = if minor < 0 { "-" } else { "" };
    match currency {
        "CNY" => format!("{sign}¥{grouped}{fraction}"),
        _ => format!("{sign}{currency} {grouped}{fraction}"),
    }
}
/// Yuan as a plain number, for chart axes that do not apply a format.
fn major(minor: i64, currency: &str) -> f64 {
    minor as f64 / 10_f64.powi(decimals(currency) as i32)
}
fn kind_label(kind: &str) -> &str {
    match kind {
        "expense" => "支出",
        "income" => "收入",
        "transfer" => "转账",
        "allocation" => "分配",
        "reallocation" => "调拨",
        "refund" => "退款",
        "real" => "账户",
        "purpose" => "用途",
        other => other,
    }
}
type Mapped = Option<(&'static str, Value, String)>;
/// A display tool's output is already complete: names and numbers come from the
/// server's own query. Nothing here reads model arguments.
fn map_display(result: &Value) -> Result<Mapped> {
    if result["status"] != "shown" {
        return Ok(None);
    }
    let title = result["title"].as_str().ok_or(Error::Conflict)?;
    let currency = result["currency"].as_str().unwrap_or("CNY");
    let money = result["measure"] != "count";
    let value_text = |v: i64| {
        if money {
            money_text(v, currency)
        } else {
            format!("{v} 笔")
        }
    };
    let metric = |label: &Value, value: &Value| {
        let mut metric = json!({"label":label,"value":value});
        if money {
            metric["format"] = money_format(currency);
        } else {
            metric["unit"] = json!("笔");
        }
        metric
    };
    let items = result["items"].as_array().ok_or(Error::Conflict)?;
    let rows = result["rows"].as_array().ok_or(Error::Conflict)?;
    let listed = |items: &[Value]| {
        items
            .iter()
            .map(|i| {
                format!(
                    "{} {}",
                    i["label"].as_str().unwrap_or_default(),
                    value_text(i["value"].as_i64().unwrap_or_default())
                )
            })
            .collect::<Vec<_>>()
            .join("、")
    };
    match result["display"].as_str() {
        Some("metrics") => {
            let total = result["total"].as_i64().unwrap_or_default();
            let total_text = if result["groups_may_overlap"] == true {
                format!(
                    "合计 {}（标签可重叠，各项之和可能大于合计）",
                    value_text(total)
                )
            } else {
                format!("合计 {}", value_text(total))
            };
            let fallback = if items.len() == 1 {
                format!(
                    "{title}：{}",
                    value_text(items[0]["value"].as_i64().unwrap_or_default())
                )
            } else {
                format!("{title}：{}；{total_text}", listed(items))
            };
            if items.len() == 1 {
                let label = if items[0]["key"] == "none" {
                    json!(title)
                } else {
                    json!(format!(
                        "{title} · {}",
                        items[0]["label"].as_str().unwrap_or_default()
                    ))
                };
                return Ok(Some((
                    "metric",
                    metric(&label, &items[0]["value"]),
                    fallback,
                )));
            }
            let metrics: Vec<_> = items
                .iter()
                .map(|i| metric(&i["label"], &i["value"]))
                .collect();
            Ok(Some((
                "metric_group",
                json!({"title":title,"metrics":metrics,"summary":total_text}),
                fallback,
            )))
        }
        Some("trend") => {
            let points: Vec<_> = items
                .iter()
                .map(|i| {
                    let v = i["value"].as_i64().unwrap_or_default();
                    json!({"x":i["label"],"y":if money { json!(major(v, currency)) } else { json!(v) }})
                })
                .collect();
            let unit = if money {
                if currency == "CNY" { "元" } else { currency }
            } else {
                "笔"
            };
            Ok(Some((
                "time_series",
                json!({"title":title,"xType":"category","yUnit":unit,"series":[{"key":"value","label":title,"unit":unit,"points":points}]}),
                format!("{title}：{}", listed(items)),
            )))
        }
        Some("records") => {
            let data_rows: Vec<_> = rows
                .iter()
                .map(|r| {
                    json!({"date":r["date"],"kind":r["kind"],"amount":r["amount_minor"],"purpose":r["purpose"],"account":r["account"],"note":r["note"]})
                })
                .collect();
            let columns = json!([
                {"key":"date","label":"日期","type":"date"},
                {"key":"kind","label":"类型","type":"string"},
                {"key":"amount","label":"金额","type":"currency","format":money_format(currency)},
                {"key":"purpose","label":"用途","type":"string"},
                {"key":"account","label":"账户","type":"string"},
                {"key":"note","label":"备注","type":"string"}
            ]);
            let mut data = json!({"title":title,"columns":columns,"rows":data_rows});
            if result["has_more"] == true {
                data["caption"] = json!(format!("只显示最近 {} 条", rows.len()));
            }
            let lines = rows
                .iter()
                .map(|r| {
                    format!(
                        "{} {} {}{}",
                        r["date"].as_str().unwrap_or_default(),
                        r["kind"].as_str().unwrap_or_default(),
                        money_text(r["amount_minor"].as_i64().unwrap_or_default(), currency),
                        r["purpose"]
                            .as_str()
                            .map(|p| format!(" {p}"))
                            .unwrap_or_default()
                    )
                })
                .collect::<Vec<_>>()
                .join("；");
            Ok(Some(("dataset", data, format!("{title}：{lines}"))))
        }
        _ => Err(Error::Conflict),
    }
}
/// Only structured tool results enter this mapping. Model text never does; the
/// arguments only say how a result was asked for (e.g. sum or count).
pub fn map_tool_result(tool: &str, args: &Value, result: &Value) -> Result<Mapped> {
    if tool.starts_with("show_") {
        return map_display(result);
    }
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
        return Ok(Some((kind, data, "已保存".into())));
    }
    let currency = result["currency"].as_str().unwrap_or("CNY");
    let money_metric = |label: &Value, value: &Value| json!({"label":label,"value":value,"format":money_format(currency)});
    match tool {
        "query_stats" => {
            let groups = result["groups"].as_array().ok_or(Error::Conflict)?;
            let metric = |label: &Value, value: &Value| {
                if args["measure"] == "count" {
                    json!({"label":label,"value":value,"unit":"笔"})
                } else {
                    money_metric(label, value)
                }
            };
            if groups.is_empty() {
                return Ok(Some((
                    "metric",
                    metric(&json!("合计"), &result["total"]),
                    "统计结果".into(),
                )));
            }
            let metrics: Vec<_> = groups
                .iter()
                .map(|g| metric(&json!(g["key"].as_str().unwrap_or("未分类")), &g["value"]))
                .collect();
            Ok(Some((
                "metric_group",
                json!({"metrics":metrics}),
                "统计结果".into(),
            )))
        }
        "query_balance" => {
            let balances = result["balances"].as_array().ok_or(Error::Conflict)?;
            let metrics: Vec<_> = balances
                .iter()
                .map(|b| {
                    money_metric(
                        &json!(b["account_id"].as_str().unwrap_or("账户")),
                        &b["balance_minor"],
                    )
                })
                .collect();
            if metrics.len() == 1 {
                Ok(Some(("metric", metrics[0].clone(), "余额".into())))
            } else if metrics.is_empty() {
                Ok(None)
            } else {
                Ok(Some((
                    "metric_group",
                    json!({"metrics":metrics}),
                    "余额".into(),
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
                "历次数据".into(),
            )))
        }
        "search_records" => {
            let rows: Vec<_> = result["records"]
                .as_array()
                .ok_or(Error::Conflict)?
                .iter()
                .map(|r| json!({"date":r["occurred_on"],"kind":kind_label(r["kind"].as_str().unwrap_or_default()),"amount":r["amount_minor"],"note":r["note"]}))
                .collect();
            if rows.is_empty() {
                return Ok(None);
            }
            Ok(Some((
                "dataset",
                json!({"columns":[{"key":"date","label":"日期","type":"date"},{"key":"kind","label":"类型","type":"string"},{"key":"amount","label":"金额","type":"currency","format":money_format(currency)},{"key":"note","label":"备注","type":"string"}],"rows":rows}),
                "记录".into(),
            )))
        }
        "create_account" | "update_account" | "list_accounts" => {
            let accounts = match result["accounts"].as_array() {
                Some(accounts) => accounts.clone(),
                None => vec![result.clone()],
            };
            let rows: Vec<_> = accounts
                .iter()
                .map(|a| json!({"name":a["name"],"kind":kind_label(a["kind"].as_str().unwrap_or_default())}))
                .collect();
            if rows.is_empty() {
                return Ok(None);
            }
            Ok(Some((
                "dataset",
                json!({"columns":[{"key":"name","label":"名称","type":"string"},{"key":"kind","label":"种类","type":"string"}],"rows":rows}),
                if tool == "list_accounts" {
                    "账户列表"
                } else {
                    "账户"
                }
                .into(),
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
            &json!({}),
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
            map_tool_result("model_text", &json!({}), &json!({"text":"午饭 50"})),
            Ok(None)
        ));
    }
    #[test]
    fn money_text_groups_digits_and_keeps_the_sign() {
        assert_eq!(money_text(428_600, "CNY"), "¥4,286.00");
        assert_eq!(money_text(-5, "CNY"), "-¥0.05");
        assert_eq!(money_text(1_234_567, "JPY"), "JPY 1,234,567");
        assert_eq!(money_text(100_000_000, "USD"), "USD 1,000,000.00");
    }
    /// Whether the block passes the same protocol check a real reply applies.
    async fn check(kind: &str, data: &Value) -> Result<bool> {
        let stage =
            crate::StagedStream::start(crate::StreamConfig::new(uuid::Uuid::now_v7().to_string()))
                .await?;
        stage.component(kind, data.clone(), "x").await
    }
    #[tokio::test]
    async fn display_output_maps_to_validated_blocks_with_names_and_money_format() -> Result<()> {
        let metrics = json!({"display":"metrics","status":"shown","title":"2026年10月支出 · 按用途","demo":false,"currency":"CNY","measure":"sum","total":240000,"items":[{"key":"a","label":"餐饮","value":142000},{"key":"b","label":"居家","value":98000}],"rows":[],"has_more":false,"groups_may_overlap":false});
        let Some((kind, data, fallback)) = map_tool_result("show_metrics", &json!({}), &metrics)?
        else {
            panic!("missing block");
        };
        assert_eq!(kind, "metric_group");
        assert_eq!(data["metrics"][0]["label"], "餐饮");
        assert_eq!(data["metrics"][0]["format"]["minorUnits"], true);
        assert_eq!(
            fallback,
            "2026年10月支出 · 按用途：餐饮 ¥1,420.00、居家 ¥980.00；合计 ¥2,400.00"
        );
        assert!(check(kind, &data).await?, "{data}");
        let trend = json!({"display":"trend","status":"shown","title":"近两月支出","demo":false,"currency":"CNY","measure":"sum","total":5000,"items":[{"key":"2026-01","label":"1月","value":5000},{"key":"2026-02","label":"2月","value":0}],"rows":[],"has_more":false,"groups_may_overlap":false});
        let Some((kind, data, _)) = map_tool_result("show_trend", &json!({}), &trend)? else {
            panic!("missing block");
        };
        assert_eq!(data["series"][0]["points"][0]["y"], 50.0);
        assert!(check(kind, &data).await?, "{data}");
        let records = json!({"display":"records","status":"shown","title":"【演示数据】最近记录","demo":true,"currency":"CNY","measure":null,"total":null,"items":[],"rows":[{"date":"2026-01-12","kind":"支出","amount_minor":6800,"purpose":"餐饮","account":"示例银行卡","note":null}],"has_more":true,"groups_may_overlap":false});
        let Some((kind, data, fallback)) = map_tool_result("show_records", &json!({}), &records)?
        else {
            panic!("missing block");
        };
        assert!(fallback.starts_with("【演示数据】"));
        assert_eq!(data["caption"], "只显示最近 1 条");
        assert!(check(kind, &data).await?, "{data}");
        // Negative control: nothing matched means no block, and the check rejects junk.
        let mut empty = metrics.clone();
        empty["status"] = json!("no_data");
        assert!(map_tool_result("show_metrics", &json!({}), &empty)?.is_none());
        assert!(!check("metric_group", &json!({"metrics":[]})).await?);
        Ok(())
    }
}
