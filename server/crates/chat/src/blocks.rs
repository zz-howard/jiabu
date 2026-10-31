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
    registry
        .register(
            "x-jiabu.account_card",
            1,
            json!({
                "type":"object",
                "required":["accountId","versionAtReply","nameSnapshot"],
                "additionalProperties":false,
                "properties":{
                    "accountId":{"type":"string","format":"uuid"},
                    "versionAtReply":{"type":"integer","minimum":1},
                    "nameSnapshot":{"type":"string","minLength":1,"maxLength":100}
                }
            }),
        )
        .map_err(|_| Error::Unavailable)?;
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
fn map_display(tool: &str, result: &Value) -> Result<Mapped> {
    if result["status"] != "shown" {
        return Ok(None);
    }
    let expected = match tool {
        "show_metrics" => "metrics",
        "show_trend" => "trend",
        "show_records" => "records",
        "show_breakdown" => "breakdown",
        "show_bar_chart" => "category_series",
        "show_account_card" => "account_card",
        _ => return Err(Error::Conflict),
    };
    if result["display"] != expected {
        return Err(Error::Conflict);
    }
    if result["display"] != "account_card" && !result["account_card"].is_null() {
        return Err(Error::Conflict);
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
        Some("account_card") => {
            if !items.is_empty()
                || !rows.is_empty()
                || !result["trend"].is_null()
                || !result["breakdown"].is_null()
                || !result["category_series"].is_null()
                || result["measure"] != "sum"
            {
                return Err(Error::Conflict);
            }
            let account = result["account_card"]
                .as_object()
                .ok_or(Error::Conflict)?;
            let id = account
                .get("account_id")
                .and_then(Value::as_str)
                .ok_or(Error::Conflict)?;
            let version = account
                .get("version_at_reply")
                .and_then(Value::as_i64)
                .filter(|version| *version > 0)
                .ok_or(Error::Conflict)?;
            let name = account
                .get("name_snapshot")
                .and_then(Value::as_str)
                .filter(|name| !name.is_empty() && name.chars().count() <= 100)
                .ok_or(Error::Conflict)?;
            let balance = account
                .get("balance_minor")
                .and_then(Value::as_i64)
                .ok_or(Error::Conflict)?;
            if title != name
                || result["total"].as_i64() != Some(balance)
                || result["currency"].as_str().is_none()
                || !matches!(account.get("archived"), Some(Value::Bool(_)))
                || account.len() != 5
            {
                return Err(Error::Conflict);
            }
            Ok(Some((
                "x-jiabu.account_card",
                json!({
                    "accountId":id,
                    "versionAtReply":version,
                    "nameSnapshot":name
                }),
                format!("{name}：{}", money_text(balance, currency)),
            )))
        }
        Some("metrics") => {
            if !result["trend"].is_null()
                || !result["breakdown"].is_null()
                || !result["category_series"].is_null()
                || !rows.is_empty()
            {
                return Err(Error::Conflict);
            }
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
            if !items.is_empty()
                || !rows.is_empty()
                || !result["breakdown"].is_null()
                || !result["category_series"].is_null()
            {
                return Err(Error::Conflict);
            }
            let trend = result["trend"].as_object().ok_or(Error::Conflict)?;
            let source_points = trend
                .get("points")
                .and_then(Value::as_array)
                .ok_or(Error::Conflict)?;
            if source_points.is_empty() || source_points.len() > 500 {
                return Err(Error::Conflict);
            }
            match trend.get("kind").and_then(Value::as_str) {
                Some("ledger") => {
                    if trend.get("currency") != Some(&result["currency"])
                        || trend.get("measure") != Some(&result["measure"])
                    {
                        return Err(Error::Conflict);
                    }
                    let points: Result<Vec<_>> = source_points
                        .iter()
                        .map(|point| {
                            let label = point["label"].as_str().ok_or(Error::Conflict)?;
                            let value = point["value"].as_i64().ok_or(Error::Conflict)?;
                            Ok(json!({"x":label,"y":if money { json!(major(value, currency)) } else { json!(value) }}))
                        })
                        .collect();
                    let unit = if money {
                        if currency == "CNY" { "元" } else { currency }
                    } else {
                        "笔"
                    };
                    let fallback = source_points
                        .iter()
                        .map(|point| {
                            let label = point["label"].as_str().ok_or(Error::Conflict)?;
                            let value = point["value"].as_i64().ok_or(Error::Conflict)?;
                            Ok(format!("{label} {}", value_text(value)))
                        })
                        .collect::<Result<Vec<_>>>()?
                        .join("、");
                    let points = points?;
                    Ok(Some((
                        "time_series",
                        json!({"title":title,"xType":"category","yUnit":unit,"series":[{"key":"value","label":title,"unit":unit,"points":points}]}),
                        format!("{title}：{fallback}"),
                    )))
                }
                Some("measurement") => {
                    if result["currency"] != ""
                        || !result["measure"].is_null()
                        || !result["total"].is_null()
                    {
                        return Err(Error::Conflict);
                    }
                    let unit = trend
                        .get("unit")
                        .filter(|value| value.as_str().is_some_and(|unit| !unit.is_empty()));
                    if trend
                        .get("unit")
                        .is_some_and(|value| !value.is_null() && !value.is_string())
                    {
                        return Err(Error::Conflict);
                    }
                    let points: Result<Vec<_>> = source_points
                        .iter()
                        .map(|point| {
                            let date = point["date"].as_str().ok_or(Error::Conflict)?;
                            let value = point
                                .get("value")
                                .and_then(Value::as_f64)
                                .ok_or(Error::Conflict)?;
                            if !value.is_finite() {
                                return Err(Error::Conflict);
                            }
                            Ok(json!({"x":date,"y":point["value"]}))
                        })
                        .collect();
                    let suffix = unit
                        .and_then(Value::as_str)
                        .map(|u| format!(" {u}"))
                        .unwrap_or_default();
                    // A time series may contain 500 points, but ChatWeave caps a
                    // block fallback at 2,000 characters. Keep all values for
                    // short series and an explicit head/tail sample for long ones.
                    let format_fallback_point = |point: &Value| {
                        let date = point["date"].as_str().ok_or(Error::Conflict)?;
                        let value = point
                            .get("value")
                            .and_then(Value::as_f64)
                            .ok_or(Error::Conflict)?;
                        if !value.is_finite() {
                            return Err(Error::Conflict);
                        }
                        Ok(format!("{date} {}{suffix}", point["value"]))
                    };
                    let fallback = if source_points.len() <= 20 {
                        source_points
                            .iter()
                            .map(format_fallback_point)
                            .collect::<Result<Vec<_>>>()?
                            .join("、")
                    } else {
                        let head = source_points
                            .iter()
                            .take(10)
                            .map(format_fallback_point)
                            .collect::<Result<Vec<_>>>()?
                            .join("、");
                        let tail = source_points
                            .iter()
                            .skip(source_points.len() - 10)
                            .map(format_fallback_point)
                            .collect::<Result<Vec<_>>>()?
                            .join("、");
                        format!(
                            "{head}、…（中间省略 {} 个点）…、{tail}",
                            source_points.len() - 20
                        )
                    };
                    let points = points?;
                    let mut series = json!({"key":"value","label":title,"points":points});
                    let mut data = json!({"title":title,"xType":"date","series":[series.clone()]});
                    if let Some(unit) = unit {
                        series["unit"] = unit.clone();
                        data["yUnit"] = unit.clone();
                        data["series"][0] = series;
                    }
                    Ok(Some(("time_series", data, format!("{title}：{fallback}"))))
                }
                _ => Err(Error::Conflict),
            }
        }
        Some("breakdown") => {
            if !items.is_empty()
                || !rows.is_empty()
                || !result["trend"].is_null()
                || !result["category_series"].is_null()
                || result["groups_may_overlap"] == true
                || (result["measure"] != "sum" && result["measure"] != "count")
            {
                return Err(Error::Conflict);
            }
            let currency = if money {
                result["currency"]
                    .as_str()
                    .filter(|value| !value.is_empty())
                    .ok_or(Error::Conflict)?
            } else {
                currency
            };
            let payload = result["breakdown"].as_object().ok_or(Error::Conflict)?;
            if payload.len() != 1 {
                return Err(Error::Conflict);
            }
            let parts = payload
                .get("parts")
                .and_then(Value::as_array)
                .ok_or(Error::Conflict)?;
            if !(2..=6).contains(&parts.len()) {
                return Err(Error::Conflict);
            }
            let total = result["total"].as_i64().ok_or(Error::Conflict)?;
            if total <= 0 {
                return Err(Error::Conflict);
            }
            let mut sum = 0_i128;
            let mapped: Result<Vec<_>> = parts
                .iter()
                .enumerate()
                .map(|(index, part)| {
                    let object = part.as_object().ok_or(Error::Conflict)?;
                    if !(object.len() == 3
                        || (object.len() == 4 && object.contains_key("merged_count")))
                        || !part["key"].is_string()
                    {
                        return Err(Error::Conflict);
                    }
                    let label = part["label"].as_str().ok_or(Error::Conflict)?;
                    let value = part["value"].as_i64().ok_or(Error::Conflict)?;
                    // The display tool removes zero groups before mapping. A
                    // shown breakdown therefore needs at least two strictly
                    // positive parts, even though the generic protocol permits
                    // zero-valued parts.
                    if value <= 0 {
                        return Err(Error::Conflict);
                    }
                    sum += i128::from(value);
                    let mut mapped = json!({
                        "key":format!("part_{}", index + 1),
                        "label":label,
                        "value":value
                    });
                    if let Some(merged) = part.get("merged_count") {
                        let merged = merged.as_u64().ok_or(Error::Conflict)?;
                        if merged < 2 {
                            return Err(Error::Conflict);
                        }
                        mapped["mergedCount"] = json!(merged);
                    }
                    Ok(mapped)
                })
                .collect();
            let mapped = mapped?;
            if sum != i128::from(total) {
                return Err(Error::Conflict);
            }
            let mut data = json!({"title":title,"parts":mapped});
            if money {
                data["format"] = money_format(currency);
            } else {
                data["format"] = json!({"style":"integer"});
                data["unit"] = json!("笔");
            }
            let fallback = format!("{title}：{}；合计 {}", listed(parts), value_text(total));
            Ok(Some(("breakdown", data, fallback)))
        }
        Some("category_series") => {
            if !items.is_empty()
                || !rows.is_empty()
                || !result["trend"].is_null()
                || !result["breakdown"].is_null()
                || !result["total"].is_null()
                || (result["measure"] != "sum" && result["measure"] != "count")
            {
                return Err(Error::Conflict);
            }
            let currency = if money {
                result["currency"]
                    .as_str()
                    .filter(|value| !value.is_empty())
                    .ok_or(Error::Conflict)?
            } else {
                currency
            };
            let payload = result["category_series"]
                .as_object()
                .ok_or(Error::Conflict)?;
            if payload.len() != 1 {
                return Err(Error::Conflict);
            }
            let points = payload
                .get("points")
                .and_then(Value::as_array)
                .ok_or(Error::Conflict)?;
            if !(2..=12).contains(&points.len()) {
                return Err(Error::Conflict);
            }
            let mapped: Result<Vec<_>> = points
                .iter()
                .enumerate()
                .map(|(index, point)| {
                    let object = point.as_object().ok_or(Error::Conflict)?;
                    if object.len() != 3 || !point["key"].is_string() {
                        return Err(Error::Conflict);
                    }
                    let label = point["label"].as_str().ok_or(Error::Conflict)?;
                    let value = point["value"].as_i64().ok_or(Error::Conflict)?;
                    Ok(json!({
                        "key":format!("point_{}", index + 1),
                        "label":label,
                        "value":value
                    }))
                })
                .collect();
            let mut data = json!({"title":title,"points":mapped?});
            if money {
                data["format"] = money_format(currency);
            } else {
                data["format"] = json!({"style":"integer"});
                data["unit"] = json!("笔");
            }
            Ok(Some((
                "category_series",
                data,
                format!("{title}：{}", listed(points)),
            )))
        }
        Some("records") => {
            if !result["trend"].is_null()
                || !result["breakdown"].is_null()
                || !result["category_series"].is_null()
                || !items.is_empty()
            {
                return Err(Error::Conflict);
            }
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
pub fn map_tool_result(tool: &str, _args: &Value, result: &Value) -> Result<Mapped> {
    if tool.starts_with("show_") {
        return map_display(tool, result);
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
    match tool {
        "create_account" | "update_account" => {
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
                "账户".into(),
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
    fn reads_never_auto_render_and_all_existing_write_mappings_remain() -> Result<()> {
        let populated_reads = [
            (
                "query_stats",
                json!({"total":10,"groups":[{"key":"x","value":10}],"currency":"CNY"}),
            ),
            (
                "query_balance",
                json!({"balances":[{"account_id":"a","balance_minor":10}],"currency":"CNY"}),
            ),
            (
                "search_records",
                json!({"records":[{"occurred_on":"2026-01-01","kind":"expense","amount_minor":10}]}),
            ),
            (
                "document_metric_series",
                json!({"metric":"body.weight","points":[{"event_date":"2026-01-01","value":62.5}]}),
            ),
            (
                "list_accounts",
                json!({"accounts":[{"name":"钱包","kind":"real"}]}),
            ),
        ];
        for (tool, output) in populated_reads {
            assert!(
                map_tool_result(tool, &json!({}), &output)?.is_none(),
                "{tool}"
            );
        }
        let entity = json!({"id":"00000000-0000-7000-8000-000000000004","version":2});
        for tool in [
            "create_record",
            "update_record",
            "void_record",
            "restore_record",
            "create_document",
            "update_document",
            "void_document",
            "restore_document",
        ] {
            assert!(
                map_tool_result(tool, &json!({}), &entity)?.is_some(),
                "{tool}"
            );
        }
        for tool in ["create_account", "update_account"] {
            assert!(
                map_tool_result(tool, &json!({}), &json!({"name":"钱包","kind":"real"}))?.is_some(),
                "{tool}"
            );
        }
        Ok(())
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
        let trend = json!({"display":"trend","status":"shown","title":"近两月支出","demo":false,"currency":"CNY","measure":"sum","total":5000,"items":[],"rows":[],"trend":{"kind":"ledger","currency":"CNY","measure":"sum","points":[{"key":"2026-01","label":"1月","value":5000},{"key":"2026-02","label":"2月","value":0}]},"has_more":false,"groups_may_overlap":false});
        let Some((kind, data, _)) = map_tool_result("show_trend", &json!({}), &trend)? else {
            panic!("missing block");
        };
        assert_eq!(data["series"][0]["points"][0]["y"], 50.0);
        assert!(check(kind, &data).await?, "{data}");
        let breakdown = json!({"display":"breakdown","status":"shown","title":"支出构成","demo":false,"currency":"CNY","measure":"sum","total":10000,"items":[],"rows":[],"breakdown":{"parts":[{"key":"a","label":"餐饮","value":7000},{"key":"other","label":"其他（2 项）","value":3000,"merged_count":2}]},"has_more":false,"groups_may_overlap":false});
        let Some((kind, data, fallback)) =
            map_tool_result("show_breakdown", &json!({}), &breakdown)?
        else {
            panic!("missing breakdown");
        };
        assert_eq!(kind, "breakdown");
        assert_eq!(data["parts"][1]["mergedCount"], 2);
        assert_eq!(data["format"]["minorUnits"], true);
        assert!(fallback.contains("合计 ¥100.00"));
        assert!(check(kind, &data).await?, "{data}");
        let category = json!({"display":"category_series","status":"shown","title":"月度对比","demo":false,"currency":"CNY","measure":"sum","total":null,"items":[],"rows":[],"category_series":{"points":[{"key":"2026-01","label":"1月","value":5000},{"key":"2026-02","label":"2月","value":-1000}]},"has_more":false,"groups_may_overlap":false});
        let Some((kind, data, fallback)) =
            map_tool_result("show_bar_chart", &json!({}), &category)?
        else {
            panic!("missing category series");
        };
        assert_eq!(kind, "category_series");
        assert_eq!(data["points"][1]["value"], -1000);
        assert!(fallback.contains("-¥10.00"));
        assert!(check(kind, &data).await?, "{data}");
        let mut inconsistent = breakdown.clone();
        inconsistent["total"] = json!(9_999);
        assert!(map_tool_result("show_breakdown", &json!({}), &inconsistent).is_err());
        let mut zero_part = breakdown.clone();
        zero_part["breakdown"]["parts"][0]["value"] = json!(10_000);
        zero_part["breakdown"]["parts"][1]["value"] = json!(0);
        assert!(map_tool_result("show_breakdown", &json!({}), &zero_part).is_err());
        assert!(map_tool_result("show_metrics", &json!({}), &breakdown).is_err());
        let mut overflow = category.clone();
        overflow["category_series"]["points"] = json!(
            (0..13)
                .map(|index| json!({"key":format!("k{index}"),"label":format!("L{index}"),"value":index}))
                .collect::<Vec<_>>()
        );
        assert!(map_tool_result("show_bar_chart", &json!({}), &overflow).is_err());
        for (tool, valid) in [
            ("show_breakdown", breakdown.clone()),
            ("show_bar_chart", category.clone()),
        ] {
            let mut missing_currency = valid.clone();
            missing_currency
                .as_object_mut()
                .expect("display result object")
                .remove("currency");
            assert!(map_tool_result(tool, &json!({}), &missing_currency).is_err());
            let mut non_string_currency = valid;
            non_string_currency["currency"] = json!(123);
            assert!(map_tool_result(tool, &json!({}), &non_string_currency).is_err());
        }
        let measurement = json!({"display":"trend","status":"shown","title":"body.weight","demo":false,"currency":"","measure":null,"total":null,"items":[],"rows":[],"trend":{"kind":"measurement","unit":"kg","points":[{"date":"2026-01-01","value":62.5},{"date":"2026-02-01","value":0.0},{"date":"2026-03-01","value":-1.25}]},"has_more":false,"groups_may_overlap":false});
        let Some((kind, data, fallback)) = map_tool_result("show_trend", &json!({}), &measurement)?
        else {
            panic!("missing measurement trend");
        };
        assert_eq!(data["yUnit"], "kg");
        assert_eq!(data["series"][0]["points"][0]["y"], 62.5);
        assert_eq!(data["series"][0]["points"][2]["y"], -1.25);
        assert_eq!(
            fallback,
            "body.weight：2026-01-01 62.5 kg、2026-02-01 0.0 kg、2026-03-01 -1.25 kg"
        );
        assert!(check(kind, &data).await?, "{data}");
        let mut unitless = measurement.clone();
        unitless["trend"]["unit"] = Value::Null;
        let Some((_, data, _)) = map_tool_result("show_trend", &json!({}), &unitless)? else {
            panic!("missing unitless trend");
        };
        assert!(data.get("yUnit").is_none());
        unitless["trend"]["unit"] = json!("");
        let Some((kind, data, _)) = map_tool_result("show_trend", &json!({}), &unitless)? else {
            panic!("missing empty-unit trend");
        };
        assert!(data.get("yUnit").is_none());
        assert!(check(kind, &data).await?, "{data}");
        let mut too_many = unitless.clone();
        too_many["trend"]["points"] = json!(
            (0..501)
                .map(|i| json!({"date":"2026-01-01","value":i}))
                .collect::<Vec<_>>()
        );
        assert!(map_tool_result("show_trend", &json!({}), &too_many).is_err());
        let mut at_limit = unitless.clone();
        at_limit["trend"]["points"] = json!(
            (0..500)
                .map(|i| json!({"date":"2026-01-01","value":i}))
                .collect::<Vec<_>>()
        );
        let Some((kind, data, fallback)) = map_tool_result("show_trend", &json!({}), &at_limit)?
        else {
            panic!("missing 500-point trend");
        };
        assert!(fallback.contains("中间省略 480 个点"));
        assert!(fallback.chars().count() <= 2_000);
        assert!(check(kind, &data).await?, "{data}");
        let mut inconsistent = measurement.clone();
        inconsistent["currency"] = json!("CNY");
        assert!(map_tool_result("show_trend", &json!({}), &inconsistent).is_err());
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
