use super::*;
use std::collections::BTreeSet;
/// Fixed categories only: never format a template value into a log or error.
#[derive(Clone, Copy, Debug, thiserror::Error)]
#[error("{0}")]
pub struct TemplateError(pub &'static str);
pub fn key_valid(key: &str) -> bool {
    let bytes = key.as_bytes();
    (1..=32).contains(&bytes.len())
        && bytes[0].is_ascii_lowercase()
        && bytes
            .iter()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || *b == b'_')
}
fn language(text: &Localized) -> Result<(), TemplateError> {
    if !text.contains_key("zh-Hans") {
        return Err(TemplateError("language"));
    }
    Ok(())
}
pub fn placeholders(text: &str) -> Result<Vec<&str>, TemplateError> {
    let mut rest = text;
    let mut result = Vec::new();
    while let Some(start) = rest.find(['{', '}']) {
        if rest.as_bytes()[start] == b'}' {
            return Err(TemplateError("title"));
        }
        rest = &rest[start + 1..];
        let end = rest.find('}').ok_or(TemplateError("title"))?;
        let key = &rest[..end];
        if key.is_empty() || key.contains('{') {
            return Err(TemplateError("title"));
        }
        result.push(key);
        rest = &rest[end + 1..];
    }
    Ok(result)
}
fn field(field: &Field) -> Result<(), TemplateError> {
    if !key_valid(&field.key) {
        return Err(TemplateError("field_key"));
    }
    language(&field.label)?;
    if let Some(help) = &field.help {
        language(help)?;
    }
    if field.min.zip(field.max).is_some_and(|(a, b)| a > b)
        || field.min.is_some_and(|n| !n.is_finite())
        || field.max.is_some_and(|n| !n.is_finite())
    {
        return Err(TemplateError("range"));
    }
    if field.kind != ValueType::Number
        && (field.unit.is_some()
            || field.units.is_some()
            || field.digits.is_some()
            || field.min.is_some()
            || field.max.is_some())
    {
        return Err(TemplateError("field_shape"));
    }
    if field.kind != ValueType::Text && (field.multiline.is_some() || field.max_length.is_some()) {
        return Err(TemplateError("field_shape"));
    }
    if field.kind != ValueType::Image && field.max_items.is_some() {
        return Err(TemplateError("field_shape"));
    }
    if field.unit.as_ref().is_some_and(|u| u.chars().count() > 32)
        || field.units.as_ref().is_some_and(|us| {
            us.iter().any(|u| u.chars().count() > 32)
                || field.unit.as_ref().is_some_and(|u| !us.contains(u))
        })
    {
        return Err(TemplateError("unit"));
    }
    let select = matches!(field.kind, ValueType::SingleSelect | ValueType::MultiSelect);
    if select != field.options.is_some() {
        return Err(TemplateError("options"));
    }
    if let Some(options) = &field.options {
        let mut ids = BTreeSet::new();
        for option in options {
            language(&option.label)?;
            if option.id.is_empty() || !ids.insert(&option.id) {
                return Err(TemplateError("options"));
            }
        }
    }
    if (field.kind == ValueType::Table) != field.columns.is_some() {
        return Err(TemplateError("columns"));
    }
    if let Some(columns) = &field.columns {
        let mut keys = BTreeSet::new();
        for column in columns {
            if !keys.insert(&column.key) {
                return Err(TemplateError("columns"));
            }
            field_column(column)?;
        }
    }
    if field.metric.as_ref().is_some_and(|m| m.is_empty())
        || field.metric.is_some() && !matches!(field.kind, ValueType::Number | ValueType::Table)
    {
        return Err(TemplateError("metric"));
    }
    if (field.kind == ValueType::Table && field.metric.is_some()) != field.metric_columns.is_some()
    {
        return Err(TemplateError("metric_columns"));
    }
    if let Some(mapping) = &field.metric_columns {
        let columns = field
            .columns
            .as_deref()
            .ok_or(TemplateError("metric_columns"))?;
        let has =
            |key: &str, kind: ColumnType| columns.iter().any(|c| c.key == key && c.kind == kind);
        if !has(&mapping.item, ColumnType::SingleSelect)
            || !has(&mapping.value, ColumnType::Number)
            || mapping
                .unit
                .as_ref()
                .is_some_and(|key| !has(key, ColumnType::Text))
        {
            return Err(TemplateError("metric_columns"));
        }
    }
    Ok(())
}
fn field_column(column: &Column) -> Result<(), TemplateError> {
    field(&column.field())
}
pub fn validate(template: &Template, official: bool) -> Result<(), TemplateError> {
    if template.version < 1 {
        return Err(TemplateError("protocol"));
    }
    let parts: Vec<_> = template.id.split('.').collect();
    if parts.len() != 2
        || parts.iter().any(|p| {
            p.is_empty()
                || !p
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_')
        })
    {
        return Err(TemplateError("id"));
    }
    if !official && template.id.starts_with("jiabu.") {
        return Err(TemplateError("reserved_namespace"));
    }
    language(&template.name)?;
    for text in [&template.description, &template.title]
        .into_iter()
        .flatten()
    {
        language(text)?;
    }
    let mut keys = BTreeSet::new();
    for f in &template.fields {
        if !keys.insert(f.key.as_str()) {
            return Err(TemplateError("field_key"));
        }
        field(f)?;
    }
    if template.event_date_field.as_ref().is_some_and(|key| {
        !template
            .fields
            .iter()
            .any(|f| &f.key == key && f.kind == ValueType::Date)
    }) {
        return Err(TemplateError("event_date"));
    }
    if let Some(title) = &template.title {
        for text in title.values() {
            for key in placeholders(text)? {
                if key != "subject" && !keys.contains(key) {
                    return Err(TemplateError("title"));
                }
            }
        }
    }
    let mut shown = BTreeSet::new();
    for group in template.layout.iter().flatten() {
        language(&group.label)?;
        for key in &group.fields {
            if !keys.contains(key.as_str()) || !shown.insert(key) {
                return Err(TemplateError("layout"));
            }
        }
    }
    let mut kinds = BTreeSet::new();
    for rule in &template.subjects {
        if !kinds.insert(rule.kind) || rule.max.is_some_and(|max| max < rule.min) {
            return Err(TemplateError("subjects"));
        }
    }
    if template
        .ai
        .as_ref()
        .and_then(|a| a.hints.as_ref())
        .is_some_and(|h| h.chars().count() > 2000)
    {
        return Err(TemplateError("hints"));
    }
    Ok(())
}
