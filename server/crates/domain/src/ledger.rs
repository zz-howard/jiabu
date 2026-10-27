//! Ledger contracts shared by tools and scoped persistence. No IO lives here.
use chrono::{DateTime, NaiveDate, Utc};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum AccountKind {
    Real,
    Purpose,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum CreateKind {
    Expense,
    Income,
    Transfer,
    Reallocation,
    Refund,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum RecordKind {
    Expense,
    Income,
    Transfer,
    Allocation,
    Reallocation,
    Refund,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum RecordStatus {
    Active,
    Voided,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum Origin {
    Chat,
    Manual,
    Api,
    Allocation,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum Measure {
    Sum,
    Count,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum GroupBy {
    Tag,
    Purpose,
    Account,
    Member,
    Month,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct Page {
    #[serde(default = "default_limit")]
    #[validate(range(min = 1, max = 200))]
    pub limit: u32,
    #[serde(default)]
    pub offset: u32,
}
pub fn default_limit() -> u32 {
    50
}
impl Default for Page {
    fn default() -> Self {
        Self {
            limit: default_limit(),
            offset: 0,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ListAccounts {
    #[serde(default)]
    pub include_archived: bool,
    #[serde(default)]
    #[validate(nested)]
    pub page: Page,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ListTags {
    #[serde(default)]
    pub include_deleted: bool,
    #[serde(default)]
    #[validate(nested)]
    pub page: Page,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct QueryBalance {
    pub account_id: Option<Uuid>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct GetRecord {
    pub id: Uuid,
}
#[derive(Clone, Debug, Default, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct Filters {
    #[validate(length(max = 500))]
    pub text: Option<String>,
    pub account_id: Option<Uuid>,
    pub purpose_id: Option<Uuid>,
    pub tag_id: Option<Uuid>,
    pub member_id: Option<Uuid>,
    pub from: Option<NaiveDate>,
    pub through: Option<NaiveDate>,
    #[serde(default)]
    pub kinds: Vec<RecordKind>,
    pub status: Option<RecordStatus>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct SearchRecords {
    #[serde(default)]
    #[validate(nested)]
    pub filters: Filters,
    #[serde(default)]
    #[validate(nested)]
    pub page: Page,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct Period {
    pub from: NaiveDate,
    pub through: NaiveDate,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct QueryStats {
    pub measure: Measure,
    #[serde(default)]
    pub kinds: Vec<RecordKind>,
    #[validate(nested)]
    pub period: Period,
    pub group_by: Option<GroupBy>,
    #[serde(default)]
    #[validate(nested)]
    pub filters: Filters,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct CreateRecord {
    pub id: Option<Uuid>,
    pub kind: CreateKind,
    #[validate(range(min = 1))]
    pub amount_minor: i64,
    pub occurred_on: NaiveDate,
    pub account_id: Option<Uuid>,
    pub to_account_id: Option<Uuid>,
    pub purpose_id: Option<Uuid>,
    pub to_purpose_id: Option<Uuid>,
    pub refund_of_id: Option<Uuid>,
    #[serde(default)]
    pub tag_ids: Vec<Uuid>,
    #[validate(length(max = 500))]
    pub note: Option<String>,
    #[serde(default)]
    pub attachments: Vec<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct RecordPatch {
    #[validate(range(min = 1))]
    pub amount_minor: Option<i64>,
    pub occurred_on: Option<NaiveDate>,
    pub account_id: Option<Uuid>,
    pub to_account_id: Option<Uuid>,
    pub purpose_id: Option<Uuid>,
    pub to_purpose_id: Option<Uuid>,
    pub tag_ids: Option<Vec<Uuid>>,
    #[serde(
        default,
        deserialize_with = "nullable",
        skip_serializing_if = "Option::is_none"
    )]
    pub note: Option<Option<String>>,
    pub attachments: Option<Vec<String>>,
}
fn nullable<'de, D: serde::Deserializer<'de>>(
    deserializer: D,
) -> Result<Option<Option<String>>, D::Error> {
    Option::<String>::deserialize(deserializer).map(Some)
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct UpdateRecord {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
    #[validate(nested)]
    pub changes: RecordPatch,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct VersionedRecord {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct CreateAccount {
    pub id: Option<Uuid>,
    pub kind: AccountKind,
    #[validate(length(min = 1, max = 30))]
    pub name: String,
    #[serde(default)]
    pub is_reserve: bool,
    #[serde(default)]
    pub opening_balance_minor: i64,
    pub opening_on: NaiveDate,
    #[serde(default)]
    pub sort_key: i32,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct UpdateAccount {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
    #[validate(length(min = 1, max = 30))]
    pub name: Option<String>,
    pub is_reserve: Option<bool>,
    pub opening_balance_minor: Option<i64>,
    pub opening_on: Option<NaiveDate>,
    pub sort_key: Option<i32>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ArchiveAccount {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct SetAllocationPlan {
    pub account_id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: Option<i32>,
    #[validate(range(min = 1))]
    pub amount_minor: i64,
    #[validate(range(min = 1, max = 31))]
    pub day_of_month: i16,
    pub enabled: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct CreateTag {
    pub id: Option<Uuid>,
    #[validate(length(min = 1, max = 30))]
    pub name: String,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct RenameTag {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
    #[validate(length(min = 1, max = 30))]
    pub name: String,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct DeleteTag {
    pub id: Uuid,
    #[validate(range(min = 1))]
    pub expected_version: i32,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Account {
    pub id: Uuid,
    pub space_id: Uuid,
    pub module: String,
    pub visibility: Option<serde_json::Value>,
    pub kind: AccountKind,
    pub name: String,
    pub is_reserve: bool,
    pub opening_balance_minor: i64,
    pub opening_on: NaiveDate,
    pub sort_key: i32,
    pub created_by_member_id: Uuid,
    pub archived_at: Option<DateTime<Utc>>,
    pub version: i32,
    pub change_seq: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct AllocationPlan {
    pub account_id: Uuid,
    pub space_id: Uuid,
    pub amount_minor: i64,
    pub day_of_month: i16,
    pub enabled: bool,
    pub next_run_on: NaiveDate,
    pub last_run_month: Option<String>,
    pub version: i32,
    pub change_seq: i64,
    pub updated_at: DateTime<Utc>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Tag {
    pub id: Uuid,
    pub space_id: Uuid,
    pub module: String,
    pub preset_key: Option<String>,
    pub name: Option<String>,
    pub created_by_member_id: Option<Uuid>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub version: i32,
    pub change_seq: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Record {
    pub id: Uuid,
    pub space_id: Uuid,
    pub module: String,
    pub visibility: Option<serde_json::Value>,
    pub kind: RecordKind,
    pub amount_minor: i64,
    pub occurred_on: NaiveDate,
    pub account_id: Option<Uuid>,
    pub to_account_id: Option<Uuid>,
    pub purpose_id: Option<Uuid>,
    pub to_purpose_id: Option<Uuid>,
    pub refund_of_id: Option<Uuid>,
    pub tag_ids: Vec<Uuid>,
    pub note: Option<String>,
    pub attachments: Vec<String>,
    pub status: RecordStatus,
    pub void_reason: Option<String>,
    pub origin: Origin,
    pub run_id: Option<Uuid>,
    pub created_by_member_id: Option<Uuid>,
    pub updated_by_member_id: Option<Uuid>,
    pub version: i32,
    pub change_seq: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct AccountsResult {
    pub accounts: Vec<Account>,
    pub has_more: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct TagsResult {
    pub tags: Vec<Tag>,
    pub has_more: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct RecordsResult {
    pub records: Vec<Record>,
    pub has_more: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Balance {
    pub account_id: Uuid,
    pub balance_minor: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct BalanceResult {
    pub currency: String,
    pub balances: Vec<Balance>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct StatsGroup {
    pub key: Option<String>,
    pub value: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct StatsResult {
    pub currency: String,
    pub total: i64,
    pub groups: Vec<StatsGroup>,
    pub tag_groups_may_overlap: bool,
}

/// IO-free record shape, shared with persistence validation.
pub fn valid_record_shape(record: &Record) -> bool {
    let expected = match record.kind {
        RecordKind::Expense => [true, false, true, false, false],
        RecordKind::Income => [true, false, false, false, false],
        RecordKind::Transfer => [true, true, false, false, false],
        RecordKind::Allocation => [false, false, true, false, false],
        RecordKind::Reallocation => [false, false, true, true, false],
        RecordKind::Refund => [true, false, true, false, true],
    };
    let ids = [
        record.account_id,
        record.to_account_id,
        record.purpose_id,
        record.to_purpose_id,
        record.refund_of_id,
    ];
    ids.iter()
        .zip(expected)
        .all(|(id, required)| id.is_some() == required)
        && !(record.kind == RecordKind::Transfer && record.account_id == record.to_account_id)
        && !(record.kind == RecordKind::Reallocation && record.purpose_id == record.to_purpose_id)
}
pub fn refund_within_limit(already: i64, additional: i64, original: i64) -> bool {
    crate::Money(already)
        .checked_add(crate::Money(additional))
        .is_some_and(|sum| sum.0 <= original)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn refund_overflow_never_wraps_and_nullable_note_is_explicit() {
        assert!(!refund_within_limit(i64::MAX, 1, i64::MAX));
        assert!(refund_within_limit(30, 70, 100));
        let absent: RecordPatch = serde_json::from_str("{}").unwrap();
        assert_eq!(absent.note, None);
        let clear: RecordPatch = serde_json::from_str("{\"note\":null}").unwrap();
        assert_eq!(clear.note, Some(None));
    }
}
