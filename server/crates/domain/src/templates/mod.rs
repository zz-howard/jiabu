//! jiabu.template/1: declarations and pure rules; no filesystem or database IO.
mod compatibility;
mod validation;
use crate::documents::SubjectKind;
pub use compatibility::compatible;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
pub use validation::key_valid as validation_key;
pub use validation::{TemplateError, placeholders, validate};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Localized(pub BTreeMap<String, String>);
impl std::ops::Deref for Localized {
    type Target = BTreeMap<String, String>;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
impl std::ops::DerefMut for Localized {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.0
    }
}
impl JsonSchema for Localized {
    fn schema_name() -> std::borrow::Cow<'static, str> {
        "Localized".into()
    }
    fn json_schema(_generator: &mut schemars::SchemaGenerator) -> schemars::Schema {
        schemars::json_schema!({"type":"object","required":["zh-Hans"],"additionalProperties":{"type":"string"}})
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum Protocol {
    #[serde(rename = "jiabu.template/1")]
    V1,
}
pub fn localized<'a>(text: &'a Localized, locale: &str) -> &'a str {
    text.get(locale)
        .or_else(|| text.get("zh-Hans"))
        .map_or("", String::as_str)
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ValueType {
    Text,
    Number,
    Date,
    Image,
    SingleSelect,
    MultiSelect,
    Table,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ColumnType {
    Text,
    Number,
    Date,
    SingleSelect,
}
impl From<ColumnType> for ValueType {
    fn from(value: ColumnType) -> Self {
        match value {
            ColumnType::Text => Self::Text,
            ColumnType::Number => Self::Number,
            ColumnType::Date => Self::Date,
            ColumnType::SingleSelect => Self::SingleSelect,
        }
    }
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct SelectOption {
    pub id: String,
    pub label: Localized,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct SubjectRule {
    pub kind: SubjectKind,
    pub min: u32,
    pub max: Option<u32>,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct MetricColumns {
    pub item: String,
    pub value: String,
    pub unit: Option<String>,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Column {
    #[schemars(regex(pattern = "^[a-z][a-z0-9_]{0,31}$"))]
    pub key: String,
    pub label: Localized,
    pub help: Option<Localized>,
    #[serde(rename = "type")]
    pub kind: ColumnType,
    #[serde(default)]
    pub required: bool,
    pub unit: Option<String>,
    pub units: Option<Vec<String>>,
    pub digits: Option<u32>,
    pub min: Option<f64>,
    pub max: Option<f64>,
    pub multiline: Option<bool>,
    pub max_length: Option<u32>,
    pub options: Option<Vec<SelectOption>>,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Field {
    #[schemars(regex(pattern = "^[a-z][a-z0-9_]{0,31}$"))]
    pub key: String,
    pub label: Localized,
    pub help: Option<Localized>,
    #[serde(rename = "type")]
    pub kind: ValueType,
    #[serde(default)]
    pub required: bool,
    pub unit: Option<String>,
    pub units: Option<Vec<String>>,
    pub digits: Option<u32>,
    pub min: Option<f64>,
    pub max: Option<f64>,
    pub multiline: Option<bool>,
    pub max_length: Option<u32>,
    pub options: Option<Vec<SelectOption>>,
    pub columns: Option<Vec<Column>>,
    pub max_items: Option<u32>,
    pub metric: Option<String>,
    pub metric_columns: Option<MetricColumns>,
}
impl Column {
    pub fn field(&self) -> Field {
        Field {
            key: self.key.clone(),
            label: self.label.clone(),
            help: self.help.clone(),
            kind: self.kind.into(),
            required: self.required,
            unit: self.unit.clone(),
            units: self.units.clone(),
            digits: self.digits,
            min: self.min,
            max: self.max,
            multiline: self.multiline,
            max_length: self.max_length,
            options: self.options.clone(),
            columns: None,
            max_items: None,
            metric: None,
            metric_columns: None,
        }
    }
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct LayoutGroup {
    pub label: Localized,
    pub fields: Vec<String>,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Ai {
    #[schemars(length(max = 2000))]
    pub hints: Option<String>,
    #[serde(default)]
    pub extract_from_images: bool,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Template {
    pub protocol: Protocol,
    #[schemars(regex(pattern = r"^[a-z0-9_]+\.[a-z0-9_]+$"))]
    pub id: String,
    #[schemars(range(min = 1))]
    pub version: i32,
    pub name: Localized,
    pub description: Option<Localized>,
    pub subjects: Vec<SubjectRule>,
    pub event_date_field: Option<String>,
    pub title: Option<Localized>,
    pub fields: Vec<Field>,
    pub layout: Option<Vec<LayoutGroup>>,
    pub ai: Option<Ai>,
}
pub fn schema() -> schemars::Schema {
    schemars::schema_for!(Template)
}
pub const OFFICIAL: &[(&str, &str)] = &[
    (
        "checkup.json",
        include_str!("../../../../templates/official/checkup.json"),
    ),
    (
        "vision.json",
        include_str!("../../../../templates/official/vision.json"),
    ),
    (
        "vaccination.json",
        include_str!("../../../../templates/official/vaccination.json"),
    ),
    (
        "certificate.json",
        include_str!("../../../../templates/official/certificate.json"),
    ),
];
#[cfg(test)]
mod tests;
