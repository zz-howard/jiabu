use super::*;
use crate::templates::{self, Field, Template, ValueType};
use std::collections::{BTreeMap, BTreeSet};
#[derive(Clone, Debug, thiserror::Error)]
#[error("{rule}")]
pub struct ContentError {
    pub pointer: String,
    pub rule: &'static str,
}
fn error(pointer: &str, rule: &'static str) -> ContentError {
    ContentError {
        pointer: pointer.to_owned(),
        rule,
    }
}
fn select(value: &Value, field: Option<&Field>) -> bool {
    let Ok(selected) = serde_json::from_value::<Selected>(value.clone()) else {
        return false;
    };
    field.is_none_or(|f| f.options.iter().flatten().any(|o| o.id == selected.id))
}
fn atom(
    kind: ValueType,
    value: &Value,
    unit: &mut Option<String>,
    field: Option<&Field>,
) -> Result<bool, &'static str> {
    if kind != ValueType::Number && unit.is_some() {
        return Err("unit");
    }
    match kind {
        ValueType::Text => {
            let text = value.as_str().ok_or("type")?;
            if field
                .and_then(|f| f.max_length)
                .is_some_and(|n| text.chars().count() > n as usize)
            {
                return Err("max_length");
            }
            Ok(false)
        }
        ValueType::Number => {
            if unit.is_none() {
                *unit = field.and_then(|f| f.unit.clone());
            }
            if unit.as_ref().is_some_and(|u| u.chars().count() > 32) {
                return Err("unit");
            }
            if let Some(units) = field.and_then(|f| f.units.as_ref())
                && !unit.as_ref().is_some_and(|u| units.contains(u))
            {
                return Err("unit");
            }
            if value.is_null() {
                return Ok(false);
            }
            let n = value.as_f64().filter(|n| n.is_finite()).ok_or("type")?;
            Ok(field.is_some_and(|f| {
                f.min.is_some_and(|min| n < min) || f.max.is_some_and(|max| n > max)
            }))
        }
        ValueType::Date => {
            if value.is_null() {
                return Ok(false);
            }
            let text = value.as_str().ok_or("type")?;
            if text.len() != 10
                || text.bytes().enumerate().any(|(i, b)| {
                    if i == 4 || i == 7 {
                        b != b'-'
                    } else {
                        !b.is_ascii_digit()
                    }
                })
            {
                return Err("date");
            }
            let date = NaiveDate::parse_from_str(text, "%Y-%m-%d").map_err(|_| "date")?;
            if date.format("%Y-%m-%d").to_string() != text {
                return Err("date");
            }
            Ok(false)
        }
        ValueType::SingleSelect => {
            if select(value, field) {
                Ok(false)
            } else {
                Err("option")
            }
        }
        ValueType::MultiSelect => {
            let values = value.as_array().ok_or("type")?;
            let mut ids = BTreeSet::new();
            if !values
                .iter()
                .all(|v| select(v, field) && ids.insert(v["id"].as_str().unwrap_or("")))
            {
                return Err("option");
            }
            Ok(false)
        }
        _ => Err("type"),
    }
}
/// Mutates only declared defaults and uncertain flags. Labels/selected labels remain snapshots.
pub fn normalize_content(
    content: &mut Content,
    template: Option<&Template>,
) -> Result<Vec<String>, ContentError> {
    let size = serde_json::to_vec(content)
        .map_err(|_| error("/content", "structure"))?
        .len();
    if content.v != 1 || content.items.len() > 200 || size > 256 * 1024 {
        return Err(error("/content", "limit"));
    }
    let mut keys = BTreeSet::new();
    let mut images = Vec::new();
    for (index, item) in content.items.iter_mut().enumerate() {
        let pointer = format!("/content/items/{index}");
        if !templates::validation_key(&item.key) || !keys.insert(item.key.clone()) {
            return Err(error(&pointer, "key"));
        }
        let field = template.and_then(|t| t.fields.iter().find(|f| f.key == item.key));
        if template.is_some() && field.is_none() {
            return Err(error(&pointer, "unknown_field"));
        }
        if field.is_some_and(|f| f.kind != item.kind) {
            return Err(error(&pointer, "type"));
        }
        let metric = field.and_then(|f| f.metric.clone());
        if item.metric.is_some() && item.metric != metric {
            return Err(error(&pointer, "metric"));
        }
        item.metric = metric;
        let uncertain = match item.kind {
            ValueType::Image => {
                if item.unit.is_some() {
                    return Err(error(&pointer, "unit"));
                }
                let values: Vec<ImageValue> = serde_json::from_value(item.value.clone())
                    .map_err(|_| error(&pointer, "type"))?;
                if values.len() > field.and_then(|f| f.max_items).unwrap_or(10) as usize {
                    return Err(error(&pointer, "max_items"));
                }
                for image in values {
                    if image.blob.len() != 64
                        || !image
                            .blob
                            .bytes()
                            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
                    {
                        return Err(error(&pointer, "blob"));
                    }
                    images.push(image.blob);
                }
                false
            }
            ValueType::Table => {
                if item.unit.is_some() {
                    return Err(error(&pointer, "unit"));
                }
                let mut table: TableValue = serde_json::from_value(item.value.clone())
                    .map_err(|_| error(&pointer, "table"))?;
                if table.rows.len() > 200 {
                    return Err(error(&pointer, "rows"));
                }
                let mut column_keys = BTreeSet::new();
                let mut uncertain = false;
                for column in &mut table.columns {
                    if !templates::validation_key(&column.key)
                        || !column_keys.insert(column.key.clone())
                    {
                        return Err(error(&pointer, "column"));
                    }
                    let declared = field
                        .and_then(|f| f.columns.as_ref())
                        .and_then(|cs| cs.iter().find(|c| c.key == column.key))
                        .map(|c| c.field());
                    if field.is_some() && declared.is_none() {
                        return Err(error(&pointer, "unknown_column"));
                    }
                    if declared
                        .as_ref()
                        .is_some_and(|d| d.kind != ValueType::from(column.kind))
                    {
                        return Err(error(&pointer, "column_type"));
                    }
                    // Validate and persist units even for an empty table.
                    let empty = match column.kind {
                        templates::ColumnType::Number => Value::Null,
                        _ => Value::String(String::new()),
                    };
                    if column.kind == templates::ColumnType::Number {
                        atom(
                            column.kind.into(),
                            &empty,
                            &mut column.unit,
                            declared.as_ref(),
                        )
                        .map_err(|rule| error(&pointer, rule))?;
                    } else if column.unit.is_some() {
                        return Err(error(&pointer, "unit"));
                    }
                    for row in &table.rows {
                        if let Some(value) = row.get(&column.key) {
                            uncertain |= atom(
                                column.kind.into(),
                                value,
                                &mut column.unit,
                                declared.as_ref(),
                            )
                            .map_err(|rule| error(&pointer, rule))?;
                        }
                    }
                }
                if table
                    .rows
                    .iter()
                    .any(|row| row.keys().any(|key| !column_keys.contains(key)))
                {
                    return Err(error(&pointer, "unknown_column"));
                }
                if let Some(mapping) = field.and_then(|f| f.metric_columns.as_ref()) {
                    // Metric identity cannot be forged by substituting a different column definition.
                    for key in [&mapping.item, &mapping.value]
                        .into_iter()
                        .chain(mapping.unit.iter())
                    {
                        if !column_keys.contains(key) {
                            return Err(error(&pointer, "metric_columns"));
                        }
                    }
                    if let Some(unit_key) = &mapping.unit
                        && table.rows.iter().any(|r| {
                            r.get(unit_key)
                                .and_then(Value::as_str)
                                .is_some_and(|u| u.chars().count() > 32)
                        })
                    {
                        return Err(error(&pointer, "unit"));
                    }
                }
                item.value = serde_json::to_value(table).map_err(|_| error(&pointer, "table"))?;
                uncertain
            }
            kind => atom(kind, &item.value, &mut item.unit, field)
                .map_err(|rule| error(&pointer, rule))?,
        };
        if uncertain {
            item.uncertain = Some(true);
        }
    }
    if serde_json::to_vec(content)
        .map_err(|_| error("/content", "structure"))?
        .len()
        > 256 * 1024
    {
        return Err(error("/content", "limit"));
    }
    Ok(images)
}
pub fn subject_rules(template: Option<&Template>, kinds: &[SubjectKind]) -> bool {
    let Some(template) = template else {
        return true;
    };
    let mut counts = BTreeMap::new();
    for kind in kinds {
        *counts.entry(*kind).or_insert(0u32) += 1;
    }
    template.subjects.iter().all(|r| {
        let n = counts.get(&r.kind).copied().unwrap_or(0);
        n >= r.min && r.max.is_none_or(|max| n <= max)
    }) && counts
        .keys()
        .all(|kind| template.subjects.iter().any(|r| &r.kind == kind))
}
pub fn render_title(
    template: &Template,
    content: &Content,
    subject: &str,
    locale: &str,
) -> Option<String> {
    let source = templates::localized(template.title.as_ref()?, locale);
    templates::placeholders(source).ok()?;
    let mut rest = source;
    let mut result = String::new();
    while let Some(start) = rest.find('{') {
        result.push_str(&rest[..start]);
        let end = rest[start + 1..].find('}')? + start + 1;
        let key = &rest[start + 1..end];
        let replacement = if key == "subject" {
            subject.to_owned()
        } else {
            content
                .items
                .iter()
                .find(|i| i.key == key)
                .map(|i| match &i.value {
                    Value::Null => String::new(),
                    Value::String(s) => s.clone(),
                    Value::Number(n) => format!(
                        "{}{}",
                        n,
                        i.unit.as_ref().map_or(String::new(), |u| format!(" {u}"))
                    ),
                    Value::Object(o) => o
                        .get("label")
                        .and_then(Value::as_str)
                        .unwrap_or("")
                        .to_owned(),
                    Value::Array(v) => v
                        .iter()
                        .filter_map(|x| x.get("label").and_then(Value::as_str))
                        .collect::<Vec<_>>()
                        .join(", "),
                    _ => String::new(),
                })
                .unwrap_or_default()
        };
        result.push_str(&replacement);
        rest = &rest[end + 1..];
    }
    result.push_str(rest);
    Some(result.trim().to_owned())
}
/// Template is trusted; client metric strings alone never make a value comparable.
pub fn metric_values(
    document: &Document,
    template: &Template,
    metric: &str,
) -> Vec<(f64, Option<String>)> {
    let mut values = Vec::new();
    for item in &document.content.items {
        let Some(field) = template
            .fields
            .iter()
            .find(|f| f.key == item.key && f.kind == item.kind)
        else {
            continue;
        };
        if field.kind == ValueType::Number && field.metric.as_deref() == Some(metric) {
            if let Some(value) = item.value.as_f64().filter(|n| n.is_finite()) {
                values.push((value, item.unit.clone()));
            }
        } else if let (Some(prefix), Some(mapping)) = (&field.metric, &field.metric_columns) {
            let Ok(table) = serde_json::from_value::<TableValue>(item.value.clone()) else {
                continue;
            };
            for row in table.rows {
                let Some(id) = row
                    .get(&mapping.item)
                    .and_then(|v| v.get("id"))
                    .and_then(Value::as_str)
                else {
                    continue;
                };
                if format!("{prefix}.{id}") != metric {
                    continue;
                }
                let Some(value) = row
                    .get(&mapping.value)
                    .and_then(Value::as_f64)
                    .filter(|n| n.is_finite())
                else {
                    continue;
                };
                let unit = if let Some(key) = &mapping.unit {
                    row.get(key).and_then(Value::as_str).map(str::to_owned)
                } else {
                    table
                        .columns
                        .iter()
                        .find(|c| c.key == mapping.value)
                        .and_then(|c| c.unit.clone())
                };
                values.push((value, unit));
            }
        }
    }
    values
}
