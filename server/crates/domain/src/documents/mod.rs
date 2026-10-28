//! Documents, subject contracts and pure content validation.
mod validation;
use crate::{ledger::Page, templates::ValueType};
use chrono::{DateTime, NaiveDate, Utc};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use unicode_normalization::UnicodeNormalization;
use uuid::Uuid;
pub use validation::{
    ContentError, metric_values, normalize_content, render_title, subject_rules, validate_content,
};
use validator::Validate;

#[derive(
    Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, JsonSchema,
)]
#[serde(rename_all = "snake_case")]
pub enum SubjectKind {
    FamilyMember,
    Pet,
    Property,
    Vehicle,
    Other,
}
pub fn normalize_name(name: &str) -> String {
    name.nfkc().collect::<String>().trim().to_owned()
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct Content {
    pub v: u8,
    pub items: Vec<ContentItem>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct ContentItem {
    pub key: String,
    #[serde(rename = "type")]
    pub kind: ValueType,
    pub label: String,
    pub value: Value,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub unit: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metric: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub uncertain: Option<bool>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Selected {
    pub id: String,
    pub label: String,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct ImageValue {
    pub blob: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub caption: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct TableColumn {
    pub key: String,
    pub label: String,
    #[serde(rename = "type")]
    pub kind: crate::templates::ColumnType,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub unit: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct TableValue {
    pub columns: Vec<TableColumn>,
    pub rows: Vec<std::collections::BTreeMap<String, Value>>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct CreateDocument {
    pub id: Option<Uuid>,
    pub template_id: Option<String>,
    pub title: Option<String>,
    pub event_date: Option<NaiveDate>,
    #[serde(default)]
    pub subject_ids: Vec<Uuid>,
    pub content: Content,
}
fn nullable<'de, D, T>(d: D) -> Result<Option<Option<T>>, D::Error>
where
    D: serde::Deserializer<'de>,
    T: Deserialize<'de>,
{
    Option::<T>::deserialize(d).map(Some)
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct DocumentPatch {
    #[serde(
        default,
        deserialize_with = "nullable",
        skip_serializing_if = "Option::is_none"
    )]
    pub template_id: Option<Option<String>>,
    pub title: Option<String>,
    pub event_date: Option<NaiveDate>,
    pub subject_ids: Option<Vec<Uuid>>,
    pub content: Option<Content>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct UpdateDocument {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
    #[validate(nested)]
    pub changes: DocumentPatch,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct Versioned {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct GetDocument {
    pub id: Uuid,
}
#[derive(Clone, Debug, Default, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct DocumentFilters {
    pub subject_id: Option<Uuid>,
    #[serde(default)]
    pub unassociated: bool,
    pub template_id: Option<String>,
    pub from: Option<NaiveDate>,
    pub to: Option<NaiveDate>,
    pub created_by_member_id: Option<Uuid>,
    pub status: Option<Status>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct SearchDocuments {
    #[serde(default)]
    #[validate(nested)]
    pub filters: DocumentFilters,
    #[serde(default)]
    #[validate(nested)]
    pub page: Page,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ListSubjects {
    pub kind: Option<SubjectKind>,
    #[serde(default)]
    pub include_archived: bool,
    #[serde(default)]
    #[validate(nested)]
    pub page: Page,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct CreateSubject {
    pub id: Option<Uuid>,
    pub kind: SubjectKind,
    pub name: String,
    pub member_id: Option<Uuid>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct UpdateSubject {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
    pub name: Option<String>,
    #[serde(
        default,
        deserialize_with = "nullable",
        skip_serializing_if = "Option::is_none"
    )]
    pub member_id: Option<Option<Uuid>>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct MetricSeries {
    pub subject_id: Uuid,
    pub metric: String,
    pub from: Option<NaiveDate>,
    pub to: Option<NaiveDate>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum Status {
    Active,
    Voided,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum Origin {
    Chat,
    Manual,
    Api,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Subject {
    pub id: Uuid,
    pub space_id: Uuid,
    pub module: String,
    pub visibility: Option<Value>,
    pub kind: SubjectKind,
    pub name: String,
    pub member_id: Option<Uuid>,
    pub archived_at: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub created_by_member_id: Uuid,
    pub version: i32,
    pub change_seq: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Document {
    pub id: Uuid,
    pub space_id: Uuid,
    pub module: String,
    pub visibility: Option<Value>,
    pub template_id: Option<String>,
    pub template_version: Option<i32>,
    pub title: String,
    pub event_date: NaiveDate,
    pub subject_ids: Vec<Uuid>,
    pub content: Content,
    pub status: Status,
    pub origin: Origin,
    pub run_id: Option<Uuid>,
    pub created_by_member_id: Uuid,
    pub updated_by_member_id: Uuid,
    pub version: i32,
    pub change_seq: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct SubjectsResult {
    pub subjects: Vec<Subject>,
    pub has_more: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct DocumentsResult {
    pub documents: Vec<Document>,
    pub has_more: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct MetricPoint {
    pub document_id: Uuid,
    pub event_date: NaiveDate,
    pub value: f64,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct Excluded {
    pub document_id: Uuid,
    pub unit: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct MetricResult {
    pub subject_id: Uuid,
    pub metric: String,
    pub unit: Option<String>,
    pub points: Vec<MetricPoint>,
    pub excluded: Vec<Excluded>,
}
#[cfg(test)]
mod tests;
