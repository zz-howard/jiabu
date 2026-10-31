//! Display tools (genUI): the model chooses what to show and how to query it; the
//! server runs the query and fills every name and number. crates/chat maps the
//! output to a block. Model arguments never carry the numbers that are shown.
use crate::{
    Effect, Exposure, StepKind, StepLabel, ToolCtx, ToolError, ToolRegistry, TypedTool,
    tool::ToolFuture,
};
use chrono::{Datelike, NaiveDate};
use jiabu_db::{SpaceTx, ValidationIssue, ledger::Entity};
use jiabu_domain::{
    SpaceId,
    documents::{MetricResult, MetricSeries},
    ledger::*,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::{Value, json};
use std::collections::HashMap;
use uuid::Uuid;
use validator::Validate;

/// Display tools are agent-only reads whose results become chat blocks. They run
/// like reads, unlike the other agent-only tool (ask_user), which interrupts.
pub fn is_display_tool(name: &str) -> bool {
    name.starts_with("show_")
}

const MAX_PERIOD_MONTHS: i32 = 24;
const MAX_RECORDS: u32 = 50;
const MAX_TEXT_CHARS: usize = 100;
/// metric_group holds at most 12 metrics: 11 largest groups plus one merged rest.
const MAX_METRICS: usize = 12;
const MAX_BREAKDOWN_PARTS: usize = 6;
const MAX_CATEGORY_POINTS: usize = 12;
/// ChatWeave's time_series schema accepts at most 500 points per series.
const MAX_TREND_POINTS: usize = 500;
/// Words in the user's own input that allow fixed demo data.
const DEMO_WORDS: [&str; 7] = ["演示", "示例", "样子", "样例", "demo", "example", "sample"];

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum DemoScene {
    MonthlySpending,
    HalfYearTrend,
    RecentRecords,
}
/// Schema only: the property must be present and may be null. Strict mode needs
/// every property in `required`; a plain `Option` field would be left out.
struct Nullable<T>(std::marker::PhantomData<T>);
impl<T: JsonSchema> JsonSchema for Nullable<T> {
    fn inline_schema() -> bool {
        true
    }
    fn schema_name() -> std::borrow::Cow<'static, str> {
        <Option<T>>::schema_name()
    }
    fn json_schema(generator: &mut schemars::SchemaGenerator) -> schemars::Schema {
        <Option<T>>::json_schema(generator)
    }
}
/// Exactly one way to get the numbers. Every property is present (strict mode);
/// the unused ones are null.
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct Source<Q> {
    /// Query the ledger. Same meaning as the matching query tool's arguments.
    #[schemars(with = "Nullable<Q>")]
    pub query: Option<Q>,
    /// call_id of a succeeded query call from an earlier turn of this reply.
    #[schemars(with = "Nullable<String>")]
    pub from_call: Option<String>,
    /// Fixed sample data, only when the user explicitly asked for a demo.
    #[schemars(with = "Nullable<DemoScene>")]
    pub demo: Option<DemoScene>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct StatsQuery {
    pub measure: Measure,
    /// Empty means expenses.
    pub kinds: Vec<RecordKind>,
    pub period: Period,
    #[schemars(with = "Nullable<GroupBy>")]
    pub group_by: Option<GroupBy>,
    #[schemars(with = "Nullable<Uuid>")]
    pub account_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub purpose_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub tag_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub member_id: Option<Uuid>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct TrendQuery {
    pub measure: Measure,
    /// Empty means expenses.
    pub kinds: Vec<RecordKind>,
    pub period: Period,
    #[schemars(with = "Nullable<Uuid>")]
    pub account_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub purpose_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub tag_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub member_id: Option<Uuid>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct RecordsQuery {
    /// Empty means every kind.
    pub kinds: Vec<RecordKind>,
    #[schemars(with = "Nullable<Period>")]
    pub period: Option<Period>,
    #[schemars(with = "Nullable<Uuid>")]
    pub account_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub purpose_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub tag_id: Option<Uuid>,
    #[schemars(with = "Nullable<Uuid>")]
    pub member_id: Option<Uuid>,
    /// Matches inside notes.
    #[schemars(with = "Nullable<String>")]
    pub text: Option<String>,
    /// 1–50, newest first.
    pub limit: u32,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ShowMetrics {
    pub source: Source<StatsQuery>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ShowTrend {
    pub source: Source<TrendQuery>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ShowRecords {
    pub source: Source<RecordsQuery>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ShowBreakdown {
    pub source: Source<StatsQuery>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ShowBarChart {
    pub source: Source<StatsQuery>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, Validate)]
#[serde(deny_unknown_fields)]
pub struct ShowAccountCard {
    pub account_id: Uuid,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum DisplayKind {
    Metrics,
    Trend,
    Records,
    Breakdown,
    CategorySeries,
    AccountCard,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum DisplayStatus {
    Shown,
    /// Nothing matched. Not a mistake: say so in text.
    NoData,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct DisplayItem {
    pub key: String,
    pub label: String,
    /// Minor units for `sum`, a count for `count`.
    pub value: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub merged_count: Option<usize>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct DisplayRow {
    pub date: NaiveDate,
    pub kind: String,
    pub amount_minor: i64,
    pub purpose: Option<String>,
    pub account: Option<String>,
    pub note: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct LedgerTrendPoint {
    pub key: String,
    pub label: String,
    /// Minor units for `sum`, a count for `count`.
    pub value: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct MeasurementTrendPoint {
    pub date: NaiveDate,
    pub value: f64,
}
/// Trend values are deliberately discriminated: document measurements are not
/// ledger minor units and may be fractional or unitless.
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum TrendPayload {
    Ledger {
        currency: String,
        measure: Measure,
        points: Vec<LedgerTrendPoint>,
    },
    Measurement {
        unit: Option<String>,
        points: Vec<MeasurementTrendPoint>,
    },
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct BreakdownPayload {
    pub parts: Vec<DisplayItem>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct CategorySeriesPayload {
    pub points: Vec<LedgerTrendPoint>,
}
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct AccountCardPayload {
    pub account_id: Uuid,
    pub version_at_reply: i32,
    pub name_snapshot: String,
    pub balance_minor: i64,
    pub archived: bool,
}
/// Everything shown is here, filled by the server. The model reads it to write a
/// one- or two-sentence conclusion; crates/chat maps it to the block.
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
pub struct DisplayOutput {
    pub display: DisplayKind,
    pub status: DisplayStatus,
    pub title: String,
    pub demo: bool,
    pub currency: String,
    pub measure: Option<Measure>,
    pub total: Option<i64>,
    pub items: Vec<DisplayItem>,
    pub rows: Vec<DisplayRow>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub trend: Option<TrendPayload>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub breakdown: Option<BreakdownPayload>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub category_series: Option<CategorySeriesPayload>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub account_card: Option<AccountCardPayload>,
    pub has_more: bool,
    /// Tag groups can overlap, so their sum may exceed the total.
    pub groups_may_overlap: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub note: Option<String>,
}
impl DisplayOutput {
    fn new(display: DisplayKind, title: String, currency: String) -> Self {
        Self {
            display,
            status: DisplayStatus::Shown,
            title,
            demo: false,
            currency,
            measure: None,
            total: None,
            items: vec![],
            rows: vec![],
            trend: None,
            breakdown: None,
            category_series: None,
            account_card: None,
            has_more: false,
            groups_may_overlap: false,
            note: None,
        }
    }
    fn no_data(mut self) -> Self {
        self.status = DisplayStatus::NoData;
        self.note = Some("Nothing matched. Tell the user in text; do not use demo data.".into());
        self
    }
}

fn issue(pointer: &str, rule: &str) -> ValidationIssue {
    ValidationIssue {
        pointer: pointer.into(),
        rule: rule.into(),
    }
}
fn source_issues<Q>(source: &Source<Q>, scene: DemoScene, issues: &mut Vec<ValidationIssue>) {
    let chosen = [
        source.query.is_some(),
        source.from_call.is_some(),
        source.demo.is_some(),
    ];
    if chosen.iter().filter(|c| **c).count() != 1 {
        issues.push(issue(
            "/source",
            "source: exactly one of query|from_call|demo is not null",
        ));
    }
    if source.demo.is_some_and(|d| d != scene) {
        let rule = format!("demo: {}", json!(scene).as_str().unwrap_or_default());
        issues.push(issue("/source/demo", &rule));
    }
    if source
        .from_call
        .as_ref()
        .is_some_and(|id| id.is_empty() || id.len() > 128)
    {
        issues.push(issue("/source/from_call", "from_call: a call_id"));
    }
}
fn months(period: &Period) -> i32 {
    (period.through.year() - period.from.year()) * 12 + period.through.month() as i32
        - period.from.month() as i32
        + 1
}
fn period_issues(period: &Period, pointer: &str, issues: &mut Vec<ValidationIssue>) {
    if period.from > period.through {
        issues.push(issue(pointer, "period: from <= through"));
    } else if months(period) > MAX_PERIOD_MONTHS {
        issues.push(issue(pointer, "period: at most 24 months"));
    }
}

/// Reused query arguments bypass `check`, so apply the same period rules after
/// reconstructing them from the journal. The model supplied `from_call`, not
/// the original query, therefore feedback must point at that field.
fn validate_reused_period(period: &Period) -> Result<(), ToolError> {
    let mut issues = Vec::new();
    period_issues(period, "/source/from_call", &mut issues);
    if let Some(problem) = issues.into_iter().next() {
        Err(ToolError::invalid_at("/source/from_call", &problem.rule))
    } else {
        Ok(())
    }
}

fn filters(
    account_id: Option<Uuid>,
    purpose_id: Option<Uuid>,
    tag_id: Option<Uuid>,
    member_id: Option<Uuid>,
) -> Filters {
    Filters {
        account_id,
        purpose_id,
        tag_id,
        member_id,
        ..Filters::default()
    }
}
/// The query tools report an id outside this space as not found.
fn query_error(error: ToolError) -> ToolError {
    if error.status == 404 {
        ToolError::invalid_at("/source/query", "ids: from SPACE_CONTEXT")
    } else {
        error
    }
}
fn account_error(error: ToolError) -> ToolError {
    if error.status == 404 {
        ToolError::invalid_at("/account_id", "account_id: from SPACE_CONTEXT")
    } else {
        error
    }
}
/// Raw arguments and output of a succeeded allowlisted call from this run.
async fn referenced_raw(
    ctx: &ToolCtx,
    tx: &SpaceTx,
    call_id: &str,
    tools: &[&str],
) -> Result<(String, Value, Value), ToolError> {
    let rule = format!(
        "from_call: a succeeded {} call from an earlier turn",
        tools.join(" or ")
    );
    let invalid = || ToolError::invalid_at("/source/from_call", &rule);
    let run = ctx.run_id.ok_or_else(invalid)?;
    let call = tx
        .calls(ctx.space_id, run)
        .await?
        .into_iter()
        .find(|c| {
            c.call_id == call_id && tools.contains(&c.tool.as_str()) && c.status == "succeeded"
        })
        .ok_or_else(invalid)?;
    let output = tx
        .journal(ctx.space_id, run)
        .await?
        .into_iter()
        .find(|i| i.kind == "tool_result" && i.call_id.as_deref() == Some(call_id))
        .map(|i| i.payload["output"].clone())
        .ok_or_else(invalid)?;
    Ok((call.tool, call.args, output))
}
/// Typed arguments and output of one expected succeeded call.
async fn referenced<A: DeserializeOwned, O: DeserializeOwned>(
    ctx: &ToolCtx,
    tx: &SpaceTx,
    call_id: &str,
    tool: &str,
) -> Result<(A, O), ToolError> {
    let rule = format!("from_call: a succeeded {tool} call from an earlier turn");
    let invalid = || ToolError::invalid_at("/source/from_call", &rule);
    let (_, args, output) = referenced_raw(ctx, tx, call_id, &[tool]).await?;
    Ok((
        serde_json::from_value(args).map_err(|_| invalid())?,
        serde_json::from_value(output).map_err(|_| invalid())?,
    ))
}
/// Demo data is allowed only when the user's own input asks for it.
async fn require_demo_request(ctx: &ToolCtx, tx: &SpaceTx) -> Result<(), ToolError> {
    let refused = || {
        ToolError::invalid_at(
            "/source/demo",
            "demo_not_requested: query the ledger instead",
        )
    };
    let run = ctx.run_id.ok_or_else(refused)?;
    let text = tx
        .journal(ctx.space_id, run)
        .await?
        .into_iter()
        .find(|i| i.kind == "input")
        .and_then(|i| i.payload["text"].as_str().map(str::to_lowercase))
        .unwrap_or_default();
    if DEMO_WORDS.iter().any(|w| text.contains(w)) {
        Ok(())
    } else {
        Err(refused())
    }
}

/// Names from the space context, so blocks never show internal ids.
struct Names(HashMap<String, String>);
impl Names {
    async fn load(tx: &SpaceTx, space: SpaceId) -> Result<Self, ToolError> {
        let context = tx.space_context(space).await?;
        let mut names = HashMap::new();
        for list in ["accounts", "tags", "members"] {
            for entry in context[list].as_array().into_iter().flatten() {
                // Preset tags carry no name, only their catalogue key.
                let name = entry["name"].as_str().or_else(|| {
                    jiabu_domain::presets::PRESETS
                        .iter()
                        .find(|p| entry["preset_key"] == p.preset_key)
                        .map(|p| p.zh)
                });
                if let (Some(id), Some(name)) = (entry["id"].as_str(), name) {
                    names.insert(id.to_owned(), name.to_owned());
                }
            }
        }
        Ok(Self(names))
    }
    fn get(&self, id: Option<Uuid>) -> Option<String> {
        id.map(|id| {
            self.0
                .get(&id.to_string())
                .cloned()
                .unwrap_or_else(|| "已删除".into())
        })
    }
    fn group(&self, group_by: Option<GroupBy>, key: Option<&str>) -> String {
        match (key, group_by) {
            (Some(key), Some(GroupBy::Month)) => key.to_owned(),
            (Some(key), _) => self.0.get(key).cloned().unwrap_or_else(|| "已删除".into()),
            (None, Some(GroupBy::Tag)) => "无标签".into(),
            (None, Some(GroupBy::Purpose)) => "无用途".into(),
            (None, Some(GroupBy::Account)) => "无账户".into(),
            (None, Some(GroupBy::Member)) => "未知成员".into(),
            (None, _) => "合计".into(),
        }
    }
}
fn kind_label(kind: RecordKind) -> &'static str {
    match kind {
        RecordKind::Expense => "支出",
        RecordKind::Income => "收入",
        RecordKind::Transfer => "转账",
        RecordKind::Allocation => "分配",
        RecordKind::Reallocation => "调拨",
        RecordKind::Refund => "退款",
    }
}
fn kinds_label(kinds: &[RecordKind], measure: Measure) -> String {
    let base = match kinds {
        [] => "支出".to_owned(),
        [kind] => kind_label(*kind).to_owned(),
        _ => "收支".to_owned(),
    };
    match measure {
        Measure::Sum => base,
        Measure::Count => format!("{base}笔数"),
    }
}
fn period_label(period: &Period) -> String {
    let (from, through) = (period.from, period.through);
    let month_end = through
        .checked_add_days(chrono::Days::new(1))
        .is_some_and(|d| d.day() == 1);
    if from.day() == 1 && month_end {
        if months(period) == 1 {
            return format!("{}年{}月", from.year(), from.month());
        }
        return format!(
            "{}年{}月–{}年{}月",
            from.year(),
            from.month(),
            through.year(),
            through.month()
        );
    }
    format!("{from} 至 {through}")
}
fn group_label(group_by: Option<GroupBy>) -> &'static str {
    match group_by {
        Some(GroupBy::Tag) => " · 按标签",
        Some(GroupBy::Purpose) => " · 按用途",
        Some(GroupBy::Account) => " · 按账户",
        Some(GroupBy::Member) => " · 按成员",
        Some(GroupBy::Month) | None => "",
    }
}

/// Largest groups first; past the block limit the rest merge into one item.
fn metric_items(
    groups: Vec<StatsGroup>,
    group_by: Option<GroupBy>,
    names: &Names,
) -> Vec<DisplayItem> {
    let mut items: Vec<DisplayItem> = groups
        .into_iter()
        .map(|g| DisplayItem {
            label: names.group(group_by, g.key.as_deref()),
            key: g.key.unwrap_or_else(|| "none".into()),
            value: g.value,
            merged_count: None,
        })
        .collect();
    items.sort_by(|a, b| b.value.cmp(&a.value).then_with(|| a.label.cmp(&b.label)));
    if items.len() > MAX_METRICS {
        let rest = items.split_off(MAX_METRICS - 1);
        items.push(DisplayItem {
            key: "other".into(),
            label: format!("其他（{} 项）", rest.len()),
            value: rest.iter().map(|i| i.value).sum(),
            merged_count: Some(rest.len()),
        });
    }
    items
}

fn sorted_group_items(
    groups: Vec<StatsGroup>,
    group_by: GroupBy,
    names: &Names,
) -> Vec<DisplayItem> {
    let mut items: Vec<_> = groups
        .into_iter()
        .map(|group| DisplayItem {
            label: names.group(Some(group_by), group.key.as_deref()),
            key: group.key.unwrap_or_else(|| "none".into()),
            value: group.value,
            merged_count: None,
        })
        .collect();
    items.sort_by(|a, b| {
        b.value
            .cmp(&a.value)
            .then_with(|| a.label.cmp(&b.label))
            .then_with(|| a.key.cmp(&b.key))
    });
    items
}

fn breakdown_parts(
    stats: &StatsResult,
    group_by: GroupBy,
    names: &Names,
    pointer: &str,
) -> Result<Vec<DisplayItem>, ToolError> {
    if stats.tag_groups_may_overlap {
        return Err(ToolError::invalid_at(
            pointer,
            "not_a_breakdown: overlapping groups; use show_bar_chart",
        ));
    }
    if stats.groups.iter().any(|group| group.value < 0) {
        return Err(ToolError::invalid_at(
            pointer,
            "not_a_breakdown: every group must be non-negative; use show_bar_chart",
        ));
    }
    let groups: Vec<_> = stats
        .groups
        .iter()
        .filter(|group| group.value != 0)
        .cloned()
        .collect();
    if groups.is_empty() {
        return Ok(vec![]);
    }
    if groups.len() == 1 {
        return Err(ToolError::invalid_at(
            pointer,
            "not_a_breakdown: at least two non-zero groups; use show_metrics",
        ));
    }
    let sum: i128 = groups.iter().map(|group| i128::from(group.value)).sum();
    if sum != i128::from(stats.total) || stats.total <= 0 {
        return Err(ToolError::invalid_at(
            pointer,
            "not_a_breakdown: source groups must sum exactly to a positive total",
        ));
    }
    let items = sorted_group_items(groups, group_by, names);
    let mut named = Vec::new();
    let mut merged = Vec::new();
    for item in items {
        let below_three_percent = i128::from(item.value) * 100 < i128::from(stats.total) * 3;
        if below_three_percent || named.len() == MAX_BREAKDOWN_PARTS - 1 {
            merged.push(item);
        } else {
            named.push(item);
        }
    }
    if !merged.is_empty() {
        let merged_count = merged.len();
        named.push(DisplayItem {
            key: "other".into(),
            label: format!("其他（{merged_count} 项）"),
            value: merged.iter().map(|item| item.value).sum(),
            merged_count: (merged_count >= 2).then_some(merged_count),
        });
    }
    debug_assert!(named.len() <= MAX_BREAKDOWN_PARTS);
    Ok(named)
}

fn category_points(
    stats: &StatsResult,
    query: &QueryStats,
    names: &Names,
    pointer: &str,
) -> Result<Vec<LedgerTrendPoint>, ToolError> {
    let Some(group_by) = query.group_by else {
        return Err(ToolError::invalid_at(pointer, "group_by: required"));
    };
    if stats.groups.is_empty() {
        return Ok(vec![]);
    }
    let items = if group_by == GroupBy::Month {
        let keys = month_keys(&query.period);
        let mut values = HashMap::new();
        for group in &stats.groups {
            let Some(key) = &group.key else {
                return Err(ToolError::invalid_at(
                    pointer,
                    "month groups: valid calendar months",
                ));
            };
            if !keys.iter().any(|(expected, _)| expected == key)
                || values.insert(key.clone(), group.value).is_some()
            {
                return Err(ToolError::invalid_at(
                    pointer,
                    "month groups: unique months inside period",
                ));
            }
        }
        keys.into_iter()
            .map(|(key, label)| DisplayItem {
                value: values.get(&key).copied().unwrap_or_default(),
                key,
                label,
                merged_count: None,
            })
            .collect()
    } else {
        sorted_group_items(stats.groups.clone(), group_by, names)
    };
    if items.len() == 1 {
        return Err(ToolError::invalid_at(
            pointer,
            "not_a_category_series: at least two points; use show_metrics",
        ));
    }
    let mut items = items;
    // Month buckets keep every calendar month up to the 12-point limit.
    // Categorical comparisons reserve the twelfth point for an explicit
    // "other" bucket whenever there is anything beyond the first eleven.
    if group_by != GroupBy::Month && items.len() >= MAX_CATEGORY_POINTS {
        let rest = items.split_off(MAX_CATEGORY_POINTS - 1);
        let merged_count = rest.len();
        let merged_value = i64::try_from(
            rest.iter().map(|item| i128::from(item.value)).sum::<i128>(),
        )
        .map_err(|_| ToolError::invalid_at(pointer, "category values: merged sum must fit i64"))?;
        items.push(DisplayItem {
            key: "other".into(),
            label: format!("其他（{merged_count} 项）"),
            value: merged_value,
            merged_count: Some(merged_count),
        });
    }
    Ok(items
        .into_iter()
        .map(|item| LedgerTrendPoint {
            key: item.key,
            label: item.label,
            value: item.value,
        })
        .collect())
}
fn month_keys(period: &Period) -> Vec<(String, String)> {
    let span_years = period.from.year() != period.through.year();
    let (mut year, mut month) = (period.from.year(), period.from.month());
    let mut keys = Vec::new();
    for _ in 0..months(period).max(0) {
        let label = if span_years {
            format!("{year}年{month}月")
        } else {
            format!("{month}月")
        };
        keys.push((format!("{year:04}-{month:02}"), label));
        (year, month) = if month == 12 {
            (year + 1, 1)
        } else {
            (year, month + 1)
        };
    }
    keys
}

fn demo_output(scene: DemoScene, currency: String) -> DisplayOutput {
    let item = |key: &str, label: &str, value: i64| DisplayItem {
        key: key.into(),
        label: label.into(),
        value,
        merged_count: None,
    };
    let mut output = match scene {
        DemoScene::MonthlySpending => {
            let mut o =
                DisplayOutput::new(DisplayKind::Metrics, "本月支出 · 按用途".into(), currency);
            o.items = vec![
                item("demo-1", "餐饮", 142_000),
                item("demo-2", "居家", 98_000),
                item("demo-3", "购物", 75_000),
                item("demo-4", "交通", 41_000),
                item("demo-5", "其他", 72_600),
            ];
            o.measure = Some(Measure::Sum);
            o
        }
        DemoScene::HalfYearTrend => {
            let mut o = DisplayOutput::new(DisplayKind::Trend, "近 6 个月支出".into(), currency);
            let values = [382_000, 405_500, 361_200, 452_800, 418_900, 428_600];
            let points = values
                .iter()
                .enumerate()
                .map(|(i, v)| LedgerTrendPoint {
                    key: format!("demo-{}", i + 1),
                    label: format!("第 {} 月", i + 1),
                    value: *v,
                })
                .collect();
            o.measure = Some(Measure::Sum);
            o.total = Some(values.iter().sum());
            o.trend = Some(TrendPayload::Ledger {
                currency: o.currency.clone(),
                measure: Measure::Sum,
                points,
            });
            o
        }
        DemoScene::RecentRecords => {
            let mut o = DisplayOutput::new(DisplayKind::Records, "最近记录".into(), currency);
            let row =
                |day: u32, kind: &str, amount: i64, purpose: &str, account: &str, note: &str| {
                    DisplayRow {
                        date: NaiveDate::from_ymd_opt(2026, 1, day).unwrap_or_default(),
                        kind: kind.into(),
                        amount_minor: amount,
                        purpose: Some(purpose.into()),
                        account: Some(account.into()),
                        note: Some(note.into()),
                    }
                };
            o.rows = vec![
                row(12, "支出", 6_800, "餐饮", "示例银行卡", "午饭"),
                row(11, "支出", 23_900, "居家", "示例钱包", "日用品"),
                row(10, "收入", 1_200_000, "工资", "示例银行卡", "工资"),
            ];
            o
        }
    };
    if !output.items.is_empty() {
        output.total = Some(output.items.iter().map(|item| item.value).sum());
    }
    output.demo = true;
    output.title = format!("【演示数据】{}", output.title);
    output
}

fn breakdown_demo(currency: String) -> DisplayOutput {
    let parts = [
        ("demo_1", "餐饮", 142_000),
        ("demo_2", "居家", 98_000),
        ("demo_3", "购物", 75_000),
        ("demo_4", "交通", 41_000),
        ("other", "其他（2 项）", 72_600),
    ]
    .into_iter()
    .map(|(key, label, value)| DisplayItem {
        key: key.into(),
        label: label.into(),
        value,
        merged_count: (key == "other").then_some(2),
    })
    .collect::<Vec<_>>();
    let mut output = DisplayOutput::new(
        DisplayKind::Breakdown,
        "【演示数据】本月支出 · 按用途".into(),
        currency,
    );
    output.demo = true;
    output.measure = Some(Measure::Sum);
    output.total = Some(parts.iter().map(|part| part.value).sum());
    output.breakdown = Some(BreakdownPayload { parts });
    output
}

fn category_demo(currency: String) -> DisplayOutput {
    let values = [382_000, 405_500, 361_200, 452_800, 418_900, 428_600];
    let points = values
        .into_iter()
        .enumerate()
        .map(|(index, value)| LedgerTrendPoint {
            key: format!("demo_{}", index + 1),
            label: format!("第 {} 月", index + 1),
            value,
        })
        .collect();
    let mut output = DisplayOutput::new(
        DisplayKind::CategorySeries,
        "【演示数据】近 6 个月支出".into(),
        currency,
    );
    output.demo = true;
    output.measure = Some(Measure::Sum);
    output.category_series = Some(CategorySeriesPayload { points });
    output
}

fn measurement_trend(result: MetricResult) -> Result<DisplayOutput, ToolError> {
    if result.points.len() > MAX_TREND_POINTS {
        return Err(ToolError::invalid_at(
            "/source/from_call",
            "from_call: document_metric_series has at most 500 points",
        ));
    }
    let mut output = DisplayOutput::new(DisplayKind::Trend, result.metric, String::new());
    if result.points.is_empty() {
        return Ok(output.no_data());
    }
    output.trend = Some(TrendPayload::Measurement {
        unit: result.unit.filter(|unit| !unit.is_empty()),
        points: result
            .points
            .into_iter()
            .map(|point| MeasurementTrendPoint {
                date: point.event_date,
                value: point.value,
            })
            .collect(),
    });
    Ok(output)
}

fn referenced_measurement_trend(
    query: MetricSeries,
    result: MetricResult,
) -> Result<DisplayOutput, ToolError> {
    if result.subject_id != query.subject_id || result.metric != query.metric {
        return Err(ToolError::invalid_at(
            "/source/from_call",
            "from_call: result subject_id and metric match the referenced query",
        ));
    }
    measurement_trend(result)
}

struct ShowMetricsTool;
impl TypedTool for ShowMetricsTool {
    type Args = ShowMetrics;
    type Output = DisplayOutput;
    fn name(&self) -> &'static str {
        "show_metrics"
    }
    fn description(&self) -> &'static str {
        "在回答里展示 1–12 个关键数字（指标卡；分组时最大的 11 组加“其他”）。服务端查询并填入名字和数字，你只说明查什么。\n何时用：用户问总额、各用途/标签/账户/成员各花了多少。\n何时别用：随时间变化（用 show_trend）；要看具体哪几笔（用 show_records）；一个数字一句话就能说清时直接用文字。\n展示后用一两句话说结论，不要把数字再列一遍。\n例：{\"source\":{\"query\":{\"measure\":\"sum\",\"kinds\":[\"expense\"],\"period\":{\"from\":\"2026-10-01\",\"through\":\"2026-10-31\"},\"group_by\":\"purpose\",\"account_id\":null,\"purpose_id\":null,\"tag_id\":null,\"member_id\":null},\"from_call\":null,\"demo\":null}}"
    }
    fn effect(&self) -> Effect {
        Effect::Read
    }
    fn exposure(&self) -> Exposure {
        Exposure::AgentOnly
    }
    fn step_kind(&self) -> StepKind {
        StepKind::ShowMetrics
    }
    fn step_label(&self, _: &Self::Args, _: &ToolCtx) -> StepLabel {
        StepLabel("整理数字")
    }
    fn check(&self, args: &Self::Args) -> Vec<ValidationIssue> {
        let mut issues = vec![];
        source_issues(&args.source, DemoScene::MonthlySpending, &mut issues);
        if let Some(q) = &args.source.query {
            period_issues(&q.period, "/source/query/period", &mut issues);
            if q.group_by == Some(GroupBy::Month) {
                issues.push(issue(
                    "/source/query/group_by",
                    "group_by: tag|purpose|account|member|null (months: show_trend)",
                ));
            }
        }
        issues
    }
    fn example_args(&self) -> Value {
        json!({"source":{"query":{"measure":"sum","kinds":["expense"],"period":{"from":"2026-01-01","through":"2026-01-31"},"group_by":"purpose","account_id":null,"purpose_id":null,"tag_id":null,"member_id":null},"from_call":null,"demo":null}})
    }
    fn example_output(&self) -> Value {
        json!({"display":"metrics","status":"shown","title":"2026年1月支出 · 按用途","demo":false,"currency":"CNY","measure":"sum","total":5000,"items":[{"key":"00000000-0000-7000-8000-000000000002","label":"示例用途","value":5000}],"rows":[],"has_more":false,"groups_may_overlap":false})
    }
    fn execute<'a>(
        &'a self,
        args: Self::Args,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>> {
        Box::pin(async move {
            let space = ctx.space_id;
            let currency = tx.ledger_currency(space).await?;
            let (query, stats) = match args.source {
                Source {
                    demo: Some(scene), ..
                } => {
                    require_demo_request(ctx, tx).await?;
                    return Ok(demo_output(scene, currency));
                }
                Source {
                    from_call: Some(id),
                    ..
                } => {
                    let (query, stats): (QueryStats, StatsResult) =
                        referenced(ctx, tx, &id, "query_stats").await?;
                    validate_reused_period(&query.period)?;
                    if query.group_by == Some(GroupBy::Month) {
                        return Err(ToolError::invalid_at(
                            "/source/from_call",
                            "from_call: query_stats not grouped by month (months: show_trend)",
                        ));
                    }
                    (query, stats)
                }
                Source { query: Some(q), .. } => {
                    let query = QueryStats {
                        measure: q.measure,
                        kinds: q.kinds,
                        period: q.period,
                        group_by: q.group_by,
                        filters: filters(q.account_id, q.purpose_id, q.tag_id, q.member_id),
                    };
                    let stats = tx
                        .ledger_stats(space, query.clone())
                        .await
                        .map_err(query_error)?;
                    (query, stats)
                }
                _ => {
                    return Err(ToolError::invalid_at(
                        "/source",
                        "source: exactly one of query|from_call|demo is not null",
                    ));
                }
            };
            let server_title = format!(
                "{}{}{}",
                period_label(&query.period),
                kinds_label(&query.kinds, query.measure),
                group_label(query.group_by)
            );
            let mut output = DisplayOutput::new(DisplayKind::Metrics, server_title, stats.currency);
            output.measure = Some(query.measure);
            if stats.groups.is_empty() {
                return Ok(output.no_data());
            }
            let names = Names::load(tx, space).await?;
            output.total = Some(stats.total);
            output.groups_may_overlap = stats.tag_groups_may_overlap;
            output.items = metric_items(stats.groups, query.group_by, &names);
            Ok(output)
        })
    }
}

struct ShowTrendTool;
impl TypedTool for ShowTrendTool {
    type Args = ShowTrend;
    type Output = DisplayOutput;
    fn name(&self) -> &'static str {
        "show_trend"
    }
    fn description(&self) -> &'static str {
        "在回答里展示折线：账本按月趋势（2–24 个月，没有记录的月份补 0），或复用一次成功的 document_metric_series 查询展示资料指标历次值。服务端填入日期、数字和单位，你只说明查什么。\n何时用：用户问趋势、每个月花了多少、和前几个月比怎样，或问体重等资料指标的历次变化。\n何时别用：只看一个期间的总数或构成（用 show_metrics）；账本趋势不到 2 个月；只有一个数字一句话就能说清。\n展示后用一两句话说结论，不要把数字再列一遍。\n例：{\"source\":{\"query\":{\"measure\":\"sum\",\"kinds\":[\"expense\"],\"period\":{\"from\":\"2026-05-01\",\"through\":\"2026-10-31\"},\"account_id\":null,\"purpose_id\":null,\"tag_id\":null,\"member_id\":null},\"from_call\":null,\"demo\":null}}"
    }
    fn effect(&self) -> Effect {
        Effect::Read
    }
    fn exposure(&self) -> Exposure {
        Exposure::AgentOnly
    }
    fn step_kind(&self) -> StepKind {
        StepKind::ShowTrend
    }
    fn step_label(&self, _: &Self::Args, _: &ToolCtx) -> StepLabel {
        StepLabel("整理趋势")
    }
    fn check(&self, args: &Self::Args) -> Vec<ValidationIssue> {
        let mut issues = vec![];
        source_issues(&args.source, DemoScene::HalfYearTrend, &mut issues);
        if let Some(q) = &args.source.query {
            period_issues(&q.period, "/source/query/period", &mut issues);
            if months(&q.period) < 2 {
                issues.push(issue(
                    "/source/query/period",
                    "period: at least 2 months (one period: show_metrics)",
                ));
            }
        }
        issues
    }
    fn example_args(&self) -> Value {
        json!({"source":{"query":{"measure":"sum","kinds":["expense"],"period":{"from":"2026-01-01","through":"2026-02-28"},"account_id":null,"purpose_id":null,"tag_id":null,"member_id":null},"from_call":null,"demo":null}})
    }
    fn example_output(&self) -> Value {
        json!({"display":"trend","status":"shown","title":"2026年1月–2026年2月支出","demo":false,"currency":"CNY","measure":"sum","total":5000,"items":[],"rows":[],"trend":{"kind":"ledger","currency":"CNY","measure":"sum","points":[{"key":"2026-01","label":"1月","value":5000},{"key":"2026-02","label":"2月","value":0}]},"has_more":false,"groups_may_overlap":false})
    }
    fn execute<'a>(
        &'a self,
        args: Self::Args,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>> {
        Box::pin(async move {
            let space = ctx.space_id;
            let (query, stats) = match args.source {
                Source {
                    demo: Some(scene), ..
                } => {
                    require_demo_request(ctx, tx).await?;
                    let currency = tx.ledger_currency(space).await?;
                    return Ok(demo_output(scene, currency));
                }
                Source {
                    from_call: Some(id),
                    ..
                } => {
                    let invalid = || {
                        ToolError::invalid_at(
                            "/source/from_call",
                            "from_call: valid query_stats or document_metric_series result",
                        )
                    };
                    let (tool, call_args, call_output) =
                        referenced_raw(ctx, tx, &id, &["query_stats", "document_metric_series"])
                            .await?;
                    if tool == "document_metric_series" {
                        let query: MetricSeries =
                            serde_json::from_value(call_args).map_err(|_| invalid())?;
                        let result: MetricResult =
                            serde_json::from_value(call_output).map_err(|_| invalid())?;
                        return referenced_measurement_trend(query, result);
                    }
                    let query: QueryStats =
                        serde_json::from_value(call_args).map_err(|_| invalid())?;
                    let stats: StatsResult =
                        serde_json::from_value(call_output).map_err(|_| invalid())?;
                    validate_reused_period(&query.period)?;
                    if query.group_by != Some(GroupBy::Month) || months(&query.period) < 2 {
                        return Err(ToolError::invalid_at(
                            "/source/from_call",
                            "from_call: query_stats grouped by month over at least 2 months",
                        ));
                    }
                    (query, stats)
                }
                Source { query: Some(q), .. } => {
                    let query = QueryStats {
                        measure: q.measure,
                        kinds: q.kinds,
                        period: q.period,
                        group_by: Some(GroupBy::Month),
                        filters: filters(q.account_id, q.purpose_id, q.tag_id, q.member_id),
                    };
                    let stats = tx
                        .ledger_stats(space, query.clone())
                        .await
                        .map_err(query_error)?;
                    (query, stats)
                }
                _ => {
                    return Err(ToolError::invalid_at(
                        "/source",
                        "source: exactly one of query|from_call|demo is not null",
                    ));
                }
            };
            let server_title = format!(
                "{}{}",
                period_label(&query.period),
                kinds_label(&query.kinds, query.measure)
            );
            let mut output = DisplayOutput::new(DisplayKind::Trend, server_title, stats.currency);
            output.measure = Some(query.measure);
            if stats.groups.is_empty() {
                return Ok(output.no_data());
            }
            output.total = Some(stats.total);
            let points = month_keys(&query.period)
                .into_iter()
                .map(|(key, label)| LedgerTrendPoint {
                    value: stats
                        .groups
                        .iter()
                        .find(|g| g.key.as_deref() == Some(key.as_str()))
                        .map_or(0, |g| g.value),
                    key,
                    label,
                })
                .collect();
            output.trend = Some(TrendPayload::Ledger {
                currency: output.currency.clone(),
                measure: query.measure,
                points,
            });
            Ok(output)
        })
    }
}

struct ShowBreakdownTool;
impl TypedTool for ShowBreakdownTool {
    type Args = ShowBreakdown;
    type Output = DisplayOutput;
    fn name(&self) -> &'static str {
        "show_breakdown"
    }
    fn description(&self) -> &'static str {
        "在回答里展示占比构成（2–6部分，小于 3% 或超出的组合并为“其他”）。服务端查询并填入名字和数字，你只说查什么。\n何时用：用户问一个总体按用途、账户、成员或不重叠标签的构成占比。\n何时别用：按月或数值可为负时用 show_bar_chart；标签组可重叠；只有一组时用 show_metrics 或文字。\n例：{\"source\":{\"query\":{\"measure\":\"sum\",\"kinds\":[\"expense\"],\"period\":{\"from\":\"2026-10-01\",\"through\":\"2026-10-31\"},\"group_by\":\"purpose\",\"account_id\":null,\"purpose_id\":null,\"tag_id\":null,\"member_id\":null},\"from_call\":null,\"demo\":null}}"
    }
    fn effect(&self) -> Effect {
        Effect::Read
    }
    fn exposure(&self) -> Exposure {
        Exposure::AgentOnly
    }
    fn step_kind(&self) -> StepKind {
        StepKind::ShowBreakdown
    }
    fn step_label(&self, _: &Self::Args, _: &ToolCtx) -> StepLabel {
        StepLabel("整理构成")
    }
    fn check(&self, args: &Self::Args) -> Vec<ValidationIssue> {
        let mut issues = vec![];
        source_issues(&args.source, DemoScene::MonthlySpending, &mut issues);
        if let Some(query) = &args.source.query {
            period_issues(&query.period, "/source/query/period", &mut issues);
            if query.group_by.is_none() || query.group_by == Some(GroupBy::Month) {
                issues.push(issue(
                    "/source/query/group_by",
                    "group_by: purpose|account|member|tag",
                ));
            }
        }
        issues
    }
    fn example_args(&self) -> Value {
        json!({"source":{"query":{"measure":"sum","kinds":["expense"],"period":{"from":"2026-01-01","through":"2026-01-31"},"group_by":"purpose","account_id":null,"purpose_id":null,"tag_id":null,"member_id":null},"from_call":null,"demo":null}})
    }
    fn example_output(&self) -> Value {
        json!({"display":"breakdown","status":"shown","title":"2026年1月支出 · 按用途","demo":false,"currency":"CNY","measure":"sum","total":5000,"items":[],"rows":[],"breakdown":{"parts":[{"key":"a","label":"餐饮","value":3000},{"key":"b","label":"交通","value":2000}]},"has_more":false,"groups_may_overlap":false})
    }
    fn execute<'a>(
        &'a self,
        args: Self::Args,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>> {
        Box::pin(async move {
            let space = ctx.space_id;
            let (query, stats, pointer) = match args.source {
                Source { demo: Some(_), .. } => {
                    require_demo_request(ctx, tx).await?;
                    return Ok(breakdown_demo(tx.ledger_currency(space).await?));
                }
                Source {
                    from_call: Some(id),
                    ..
                } => {
                    let (query, stats): (QueryStats, StatsResult) =
                        referenced(ctx, tx, &id, "query_stats").await?;
                    validate_reused_period(&query.period)?;
                    if query.group_by.is_none() || query.group_by == Some(GroupBy::Month) {
                        return Err(ToolError::invalid_at(
                            "/source/from_call",
                            "from_call: query_stats grouped by purpose|account|member|tag",
                        ));
                    }
                    (query, stats, "/source/from_call")
                }
                Source {
                    query: Some(query), ..
                } => {
                    let query = QueryStats {
                        measure: query.measure,
                        kinds: query.kinds,
                        period: query.period,
                        group_by: query.group_by,
                        filters: filters(
                            query.account_id,
                            query.purpose_id,
                            query.tag_id,
                            query.member_id,
                        ),
                    };
                    let stats = tx
                        .ledger_stats(space, query.clone())
                        .await
                        .map_err(query_error)?;
                    (query, stats, "/source/query")
                }
                _ => {
                    return Err(ToolError::invalid_at(
                        "/source",
                        "source: exactly one of query|from_call|demo is not null",
                    ));
                }
            };
            let group_by = query.group_by.ok_or_else(|| {
                ToolError::invalid_at(pointer, "group_by: purpose|account|member|tag")
            })?;
            let title = format!(
                "{}{}{}",
                period_label(&query.period),
                kinds_label(&query.kinds, query.measure),
                group_label(query.group_by)
            );
            let mut output =
                DisplayOutput::new(DisplayKind::Breakdown, title, stats.currency.clone());
            output.measure = Some(query.measure);
            output.total = Some(stats.total);
            let names = Names::load(tx, space).await?;
            let parts = breakdown_parts(&stats, group_by, &names, pointer)?;
            if parts.is_empty() {
                return Ok(output.no_data());
            }
            output.breakdown = Some(BreakdownPayload { parts });
            Ok(output)
        })
    }
}

struct ShowBarChartTool;
impl TypedTool for ShowBarChartTool {
    type Args = ShowBarChart;
    type Output = DisplayOutput;
    fn name(&self) -> &'static str {
        "show_bar_chart"
    }
    fn description(&self) -> &'static str {
        "在回答里展示离散柱状图（2–12 个月份或类别；服务端排序、补零并填入名字和数字）。\n何时用：用户要比较各月、用途、账户、成员或标签的数值大小，包括负值或重叠标签。\n何时别用：只有一个数值时用 show_metrics 或文字；要表达整体占比时用 show_breakdown；要看连续趋势时用 show_trend。\n例：{\"source\":{\"query\":{\"measure\":\"sum\",\"kinds\":[\"expense\"],\"period\":{\"from\":\"2026-05-01\",\"through\":\"2026-10-31\"},\"group_by\":\"month\",\"account_id\":null,\"purpose_id\":null,\"tag_id\":null,\"member_id\":null},\"from_call\":null,\"demo\":null}}"
    }
    fn effect(&self) -> Effect {
        Effect::Read
    }
    fn exposure(&self) -> Exposure {
        Exposure::AgentOnly
    }
    fn step_kind(&self) -> StepKind {
        StepKind::ShowBarChart
    }
    fn step_label(&self, _: &Self::Args, _: &ToolCtx) -> StepLabel {
        StepLabel("整理对比")
    }
    fn check(&self, args: &Self::Args) -> Vec<ValidationIssue> {
        let mut issues = vec![];
        source_issues(&args.source, DemoScene::HalfYearTrend, &mut issues);
        if let Some(query) = &args.source.query {
            period_issues(&query.period, "/source/query/period", &mut issues);
            if query.group_by.is_none() {
                issues.push(issue("/source/query/group_by", "group_by: required"));
            } else if query.group_by == Some(GroupBy::Month)
                && !(2..=12).contains(&months(&query.period))
            {
                issues.push(issue(
                    "/source/query/period",
                    "period: 2..12 calendar months for month grouping",
                ));
            }
        }
        issues
    }
    fn example_args(&self) -> Value {
        json!({"source":{"query":{"measure":"sum","kinds":["expense"],"period":{"from":"2026-01-01","through":"2026-02-28"},"group_by":"month","account_id":null,"purpose_id":null,"tag_id":null,"member_id":null},"from_call":null,"demo":null}})
    }
    fn example_output(&self) -> Value {
        json!({"display":"category_series","status":"shown","title":"2026年1月–2026年2月支出","demo":false,"currency":"CNY","measure":"sum","total":null,"items":[],"rows":[],"category_series":{"points":[{"key":"2026-01","label":"1月","value":3000},{"key":"2026-02","label":"2月","value":2000}]},"has_more":false,"groups_may_overlap":false})
    }
    fn execute<'a>(
        &'a self,
        args: Self::Args,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>> {
        Box::pin(async move {
            let space = ctx.space_id;
            let (query, stats, pointer) = match args.source {
                Source { demo: Some(_), .. } => {
                    require_demo_request(ctx, tx).await?;
                    return Ok(category_demo(tx.ledger_currency(space).await?));
                }
                Source {
                    from_call: Some(id),
                    ..
                } => {
                    let (query, stats): (QueryStats, StatsResult) =
                        referenced(ctx, tx, &id, "query_stats").await?;
                    validate_reused_period(&query.period)?;
                    if query.group_by.is_none()
                        || (query.group_by == Some(GroupBy::Month)
                            && !(2..=12).contains(&months(&query.period)))
                    {
                        return Err(ToolError::invalid_at(
                            "/source/from_call",
                            "from_call: grouped query_stats; month grouping spans 2..12 months",
                        ));
                    }
                    (query, stats, "/source/from_call")
                }
                Source {
                    query: Some(query), ..
                } => {
                    let query = QueryStats {
                        measure: query.measure,
                        kinds: query.kinds,
                        period: query.period,
                        group_by: query.group_by,
                        filters: filters(
                            query.account_id,
                            query.purpose_id,
                            query.tag_id,
                            query.member_id,
                        ),
                    };
                    let stats = tx
                        .ledger_stats(space, query.clone())
                        .await
                        .map_err(query_error)?;
                    (query, stats, "/source/query")
                }
                _ => {
                    return Err(ToolError::invalid_at(
                        "/source",
                        "source: exactly one of query|from_call|demo is not null",
                    ));
                }
            };
            let title = format!(
                "{}{}{}",
                period_label(&query.period),
                kinds_label(&query.kinds, query.measure),
                group_label(query.group_by)
            );
            let mut output =
                DisplayOutput::new(DisplayKind::CategorySeries, title, stats.currency.clone());
            output.measure = Some(query.measure);
            output.groups_may_overlap = stats.tag_groups_may_overlap;
            let names = Names::load(tx, space).await?;
            let points = category_points(&stats, &query, &names, pointer)?;
            if points.is_empty() {
                return Ok(output.no_data());
            }
            output.category_series = Some(CategorySeriesPayload { points });
            Ok(output)
        })
    }
}

struct ShowAccountCardTool;
impl TypedTool for ShowAccountCardTool {
    type Args = ShowAccountCard;
    type Output = DisplayOutput;
    fn name(&self) -> &'static str {
        "show_account_card"
    }
    fn description(&self) -> &'static str {
        "在回答里展示一个可点开看流水的账户卡。账户名称和余额由服务端查询，卡片到达 App 后会用本地账本实时更新。\n何时用：用户问某个已在 SPACE_CONTEXT 里的真实账户或用途账户还有多少钱，或要查看这个账户的流水。\n何时别用：用户没有指明账户或上下文里找不到唯一账户；要比较多个账户时用 show_metrics 或 show_bar_chart；不要猜 ID、名称或金额。\n例：{\"account_id\":\"00000000-0000-7000-8000-000000000001\"}"
    }
    fn effect(&self) -> Effect {
        Effect::Read
    }
    fn exposure(&self) -> Exposure {
        Exposure::AgentOnly
    }
    fn step_kind(&self) -> StepKind {
        StepKind::ShowAccountCard
    }
    fn step_label(&self, _: &Self::Args, _: &ToolCtx) -> StepLabel {
        StepLabel("整理账户")
    }
    fn example_args(&self) -> Value {
        json!({"account_id":"00000000-0000-7000-8000-000000000001"})
    }
    fn example_output(&self) -> Value {
        json!({"display":"account_card","status":"shown","title":"示例账户","demo":false,"currency":"CNY","measure":"sum","total":5000,"items":[],"rows":[],"account_card":{"account_id":"00000000-0000-7000-8000-000000000001","version_at_reply":2,"name_snapshot":"示例账户","balance_minor":5000,"archived":false},"has_more":false,"groups_may_overlap":false})
    }
    fn execute<'a>(
        &'a self,
        args: Self::Args,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>> {
        Box::pin(async move {
            let space = ctx.space_id;
            let account: Account = serde_json::from_value(
                tx.ledger_snapshot(space, Entity::Account, args.account_id)
                    .await
                    .map_err(account_error)?,
            )
            .map_err(|_| ToolError::internal())?;
            let balances = tx
                .ledger_balance(
                    space,
                    QueryBalance {
                        account_id: Some(args.account_id),
                    },
                )
                .await
                .map_err(account_error)?;
            let balance = balances
                .balances
                .into_iter()
                .find(|balance| balance.account_id == args.account_id)
                .ok_or_else(ToolError::internal)?;
            let mut output = DisplayOutput::new(
                DisplayKind::AccountCard,
                account.name.clone(),
                balances.currency,
            );
            output.measure = Some(Measure::Sum);
            output.total = Some(balance.balance_minor);
            output.account_card = Some(AccountCardPayload {
                account_id: account.id,
                version_at_reply: account.version,
                name_snapshot: account.name,
                balance_minor: balance.balance_minor,
                archived: account.archived_at.is_some(),
            });
            Ok(output)
        })
    }
}

struct ShowRecordsTool;
impl TypedTool for ShowRecordsTool {
    type Args = ShowRecords;
    type Output = DisplayOutput;
    fn name(&self) -> &'static str {
        "show_records"
    }
    fn description(&self) -> &'static str {
        "在回答里展示记录明细表（日期、类型、金额、用途、账户、备注；最新的在前，最多 50 条；只含有效记录）。服务端查询并填入。\n何时用：用户要看具体是哪几笔、最近记了什么、某个用途或账户的明细。\n何时别用：只要合计或构成（用 show_metrics）；只有一两笔时直接用文字。\n展示后用一两句话说结论，不要把记录再列一遍。\n例：{\"source\":{\"query\":{\"kinds\":[\"expense\"],\"period\":{\"from\":\"2026-10-01\",\"through\":\"2026-10-31\"},\"account_id\":null,\"purpose_id\":null,\"tag_id\":null,\"member_id\":null,\"text\":null,\"limit\":20},\"from_call\":null,\"demo\":null}}"
    }
    fn effect(&self) -> Effect {
        Effect::Read
    }
    fn exposure(&self) -> Exposure {
        Exposure::AgentOnly
    }
    fn step_kind(&self) -> StepKind {
        StepKind::ShowRecords
    }
    fn step_label(&self, _: &Self::Args, _: &ToolCtx) -> StepLabel {
        StepLabel("整理明细")
    }
    fn check(&self, args: &Self::Args) -> Vec<ValidationIssue> {
        let mut issues = vec![];
        source_issues(&args.source, DemoScene::RecentRecords, &mut issues);
        if let Some(q) = &args.source.query {
            if let Some(period) = &q.period {
                period_issues(period, "/source/query/period", &mut issues);
            }
            if !(1..=MAX_RECORDS).contains(&q.limit) {
                issues.push(issue("/source/query/limit", "limit: 1..50"));
            }
            if q.text
                .as_ref()
                .is_some_and(|t| t.is_empty() || t.chars().count() > MAX_TEXT_CHARS)
            {
                issues.push(issue(
                    "/source/query/text",
                    "text: 1-100 characters or null",
                ));
            }
        }
        issues
    }
    fn example_args(&self) -> Value {
        json!({"source":{"query":{"kinds":[],"period":{"from":"2026-01-01","through":"2026-01-31"},"account_id":null,"purpose_id":null,"tag_id":null,"member_id":null,"text":null,"limit":20},"from_call":null,"demo":null}})
    }
    fn example_output(&self) -> Value {
        json!({"display":"records","status":"shown","title":"2026年1月记录","demo":false,"currency":"CNY","measure":null,"total":null,"items":[],"rows":[{"date":"2026-01-01","kind":"支出","amount_minor":5000,"purpose":"示例用途","account":"示例银行卡","note":null}],"has_more":false,"groups_may_overlap":false})
    }
    fn execute<'a>(
        &'a self,
        args: Self::Args,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>> {
        Box::pin(async move {
            let space = ctx.space_id;
            let currency = tx.ledger_currency(space).await?;
            let (period, mut result) = match args.source {
                Source {
                    demo: Some(scene), ..
                } => {
                    require_demo_request(ctx, tx).await?;
                    return Ok(demo_output(scene, currency));
                }
                Source {
                    from_call: Some(id),
                    ..
                } => {
                    let (search, result): (SearchRecords, RecordsResult) =
                        referenced(ctx, tx, &id, "search_records").await?;
                    let period = search
                        .filters
                        .from
                        .zip(search.filters.through)
                        .map(|(from, through)| Period { from, through });
                    if let Some(period) = &period {
                        validate_reused_period(period)?;
                    }
                    (period, result)
                }
                Source { query: Some(q), .. } => {
                    let search = SearchRecords {
                        filters: Filters {
                            text: q.text,
                            from: q.period.as_ref().map(|p| p.from),
                            through: q.period.as_ref().map(|p| p.through),
                            kinds: q.kinds,
                            status: Some(RecordStatus::Active),
                            ..filters(q.account_id, q.purpose_id, q.tag_id, q.member_id)
                        },
                        page: Page {
                            limit: q.limit,
                            offset: 0,
                        },
                    };
                    (
                        q.period,
                        tx.ledger_search(space, search).await.map_err(query_error)?,
                    )
                }
                _ => {
                    return Err(ToolError::invalid_at(
                        "/source",
                        "source: exactly one of query|from_call|demo is not null",
                    ));
                }
            };
            let server_title = match &period {
                Some(p) => format!("{}记录", period_label(p)),
                None => "记录明细".into(),
            };
            // A reused search may include voided records; the table shows active ones.
            result.records.retain(|r| r.status == RecordStatus::Active);
            let mut output = DisplayOutput::new(DisplayKind::Records, server_title, currency);
            if result.records.is_empty() {
                return Ok(output.no_data());
            }
            let names = Names::load(tx, space).await?;
            output.has_more = result.has_more || result.records.len() > MAX_RECORDS as usize;
            output.rows = result
                .records
                .into_iter()
                .take(MAX_RECORDS as usize)
                .map(|r| {
                    let pair = |a: Option<String>, b: Option<String>| match (a, b) {
                        (Some(a), Some(b)) => Some(format!("{a} → {b}")),
                        (a, b) => a.or(b),
                    };
                    DisplayRow {
                        date: r.occurred_on,
                        kind: kind_label(r.kind).into(),
                        amount_minor: r.amount_minor,
                        purpose: pair(names.get(r.purpose_id), names.get(r.to_purpose_id)),
                        account: pair(names.get(r.account_id), names.get(r.to_account_id)),
                        note: r.note,
                    }
                })
                .collect();
            Ok(output)
        })
    }
}

pub(crate) fn register(registry: &mut ToolRegistry) -> Result<(), ToolError> {
    registry.register(ShowMetricsTool)?;
    registry.register(ShowTrendTool)?;
    registry.register(ShowRecordsTool)?;
    registry.register(ShowBreakdownTool)?;
    registry.register(ShowBarChartTool)?;
    registry.register(ShowAccountCardTool)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn rules(tool: &dyn crate::AgentTool, args: Value) -> Vec<(String, String)> {
        match tool.validate(args) {
            Ok(_) => vec![],
            Err(e) => e
                .errors
                .unwrap_or_default()
                .into_iter()
                .map(|i| (i.pointer, i.rule))
                .collect(),
        }
    }
    #[test]
    fn business_rules_name_the_field_and_rule() -> Result<(), ToolError> {
        let registry = ToolRegistry::ledger()?;
        let metrics = registry.get("show_metrics")?;
        // Negative control: the example passes.
        assert!(rules(metrics, metrics.example_args()).is_empty());
        let mut two = metrics.example_args();
        two["source"]["demo"] = json!("monthly_spending");
        assert_eq!(rules(metrics, two)[0].0, "/source");
        let mut none = metrics.example_args();
        none["source"]["query"] = Value::Null;
        assert_eq!(rules(metrics, none)[0].0, "/source");
        let mut month = metrics.example_args();
        month["source"]["query"]["group_by"] = json!("month");
        assert_eq!(rules(metrics, month)[0].0, "/source/query/group_by");
        let mut backwards = metrics.example_args();
        backwards["source"]["query"]["period"] =
            json!({"from":"2026-02-01","through":"2026-01-01"});
        assert_eq!(
            rules(metrics, backwards),
            vec![(
                "/source/query/period".to_owned(),
                "period: from <= through".to_owned()
            )]
        );
        let mut long = metrics.example_args();
        long["source"]["query"]["period"] = json!({"from":"2024-01-01","through":"2026-01-31"});
        assert_eq!(rules(metrics, long)[0].1, "period: at most 24 months");
        let mut scene = metrics.example_args();
        scene["source"]["query"] = Value::Null;
        scene["source"]["demo"] = json!("recent_records");
        assert_eq!(
            rules(metrics, scene),
            vec![(
                "/source/demo".to_owned(),
                "demo: monthly_spending".to_owned()
            )]
        );
        let trend = registry.get("show_trend")?;
        assert!(rules(trend, trend.example_args()).is_empty());
        let mut one = trend.example_args();
        one["source"]["query"]["period"] = json!({"from":"2026-01-01","through":"2026-01-31"});
        assert_eq!(rules(trend, one)[0].0, "/source/query/period");
        let records = registry.get("show_records")?;
        assert!(rules(records, records.example_args()).is_empty());
        let mut many = records.example_args();
        many["source"]["query"]["limit"] = json!(51);
        assert_eq!(rules(records, many)[0].0, "/source/query/limit");
        let breakdown = registry.get("show_breakdown")?;
        assert!(rules(breakdown, breakdown.example_args()).is_empty());
        let mut month = breakdown.example_args();
        month["source"]["query"]["group_by"] = json!("month");
        assert_eq!(rules(breakdown, month)[0].0, "/source/query/group_by");
        let bars = registry.get("show_bar_chart")?;
        assert!(rules(bars, bars.example_args()).is_empty());
        let mut thirteen = bars.example_args();
        thirteen["source"]["query"]["period"] = json!({"from":"2025-12-01","through":"2026-12-31"});
        assert_eq!(rules(bars, thirteen)[0].0, "/source/query/period");
        Ok(())
    }
    #[test]
    fn metric_items_keep_eleven_largest_and_merge_the_rest() {
        let names = Names(HashMap::new());
        let groups = (1..=14)
            .map(|i| StatsGroup {
                key: None,
                value: i,
            })
            .collect();
        let items = metric_items(groups, Some(GroupBy::Tag), &names);
        assert_eq!(items.len(), MAX_METRICS);
        assert_eq!(items[0].value, 14);
        assert_eq!(items[11].label, "其他（3 项）");
        assert_eq!(items[11].value, 1 + 2 + 3);
        assert_eq!(
            items.iter().map(|i| i.value).sum::<i64>(),
            (1..=14_i64).sum::<i64>()
        );
    }
    #[test]
    fn breakdown_uses_exact_three_percent_and_deterministic_merging() {
        let names = Names(HashMap::from([
            ("a".into(), "A".into()),
            ("b".into(), "B".into()),
            ("c".into(), "C".into()),
            ("d".into(), "D".into()),
        ]));
        let stats = StatsResult {
            currency: "CNY".into(),
            total: 10_000,
            groups: [("a", 5_000), ("b", 4_401), ("c", 300), ("d", 299)]
                .into_iter()
                .map(|(key, value)| StatsGroup {
                    key: Some(key.into()),
                    value,
                })
                .collect(),
            tag_groups_may_overlap: false,
        };
        let parts =
            breakdown_parts(&stats, GroupBy::Purpose, &names, "/source/query").expect("breakdown");
        assert_eq!(
            parts
                .iter()
                .map(|part| part.label.as_str())
                .collect::<Vec<_>>(),
            ["A", "B", "C", "其他（1 项）"]
        );
        assert_eq!(parts.last().map(|part| part.value), Some(299));
        assert_eq!(parts.last().and_then(|part| part.merged_count), None);

        let names = Names(
            (1..=8)
                .map(|value| (value.to_string(), format!("G{value}")))
                .collect(),
        );
        let stats = StatsResult {
            currency: "CNY".into(),
            total: 100,
            groups: [40, 20, 15, 10, 7, 4, 3, 1]
                .into_iter()
                .enumerate()
                .map(|(index, value)| StatsGroup {
                    key: Some((index + 1).to_string()),
                    value,
                })
                .collect(),
            tag_groups_may_overlap: false,
        };
        let parts = breakdown_parts(&stats, GroupBy::Account, &names, "/source/query")
            .expect("merged breakdown");
        assert_eq!(parts.len(), 6);
        assert_eq!(parts[5].value, 8);
        assert_eq!(parts[5].merged_count, Some(3));
        assert_eq!(parts.iter().map(|part| part.value).sum::<i64>(), 100);
    }
    #[test]
    fn breakdown_rejects_unsuitable_source_shapes() {
        let names = Names(HashMap::new());
        let stats = |values: &[i64], total: i64, overlap: bool| StatsResult {
            currency: "CNY".into(),
            total,
            groups: values
                .iter()
                .enumerate()
                .map(|(index, value)| StatsGroup {
                    key: Some(index.to_string()),
                    value: *value,
                })
                .collect(),
            tag_groups_may_overlap: overlap,
        };
        assert!(
            breakdown_parts(&stats(&[0, 0], 0, false), GroupBy::Purpose, &names, "p")
                .expect("zero values are no data")
                .is_empty()
        );
        for unsuitable in [
            stats(&[10], 10, false),
            stats(&[10, -1], 9, false),
            stats(&[6, 4], 10, true),
            stats(&[6, 4], 11, false),
        ] {
            assert!(
                breakdown_parts(&unsuitable, GroupBy::Tag, &names, "p").is_err(),
                "{unsuitable:?}"
            );
        }
    }
    #[test]
    fn category_series_fills_months_and_reserves_other_for_categories() {
        let period = Period {
            from: NaiveDate::from_ymd_opt(2026, 1, 1).unwrap_or_default(),
            through: NaiveDate::from_ymd_opt(2026, 3, 31).unwrap_or_default(),
        };
        let query = QueryStats {
            measure: Measure::Sum,
            kinds: vec![],
            period,
            group_by: Some(GroupBy::Month),
            filters: Filters::default(),
        };
        let stats = StatsResult {
            currency: "CNY".into(),
            total: 5,
            groups: vec![
                StatsGroup {
                    key: Some("2026-01".into()),
                    value: 10,
                },
                StatsGroup {
                    key: Some("2026-03".into()),
                    value: -5,
                },
            ],
            tag_groups_may_overlap: false,
        };
        let points = category_points(&stats, &query, &Names(HashMap::new()), "/source/query")
            .expect("months");
        assert_eq!(
            points.iter().map(|point| point.value).collect::<Vec<_>>(),
            [10, 0, -5]
        );

        let twelve_month_query = QueryStats {
            period: Period {
                from: NaiveDate::from_ymd_opt(2026, 1, 1).unwrap_or_default(),
                through: NaiveDate::from_ymd_opt(2026, 12, 31).unwrap_or_default(),
            },
            ..query.clone()
        };
        let twelve_months = category_points(
            &stats,
            &twelve_month_query,
            &Names(HashMap::new()),
            "/source/query",
        )
        .expect("twelve months");
        assert_eq!(twelve_months.len(), 12);
        assert_eq!(twelve_months[11].key, "2026-12");

        let names = Names(
            (1..=13)
                .map(|value| (value.to_string(), format!("G{value:02}")))
                .collect(),
        );
        let query = QueryStats {
            group_by: Some(GroupBy::Tag),
            ..query
        };
        for count in [11_i64, 12, 13] {
            let stats = StatsResult {
                currency: "CNY".into(),
                total: (1..=count).sum(),
                groups: (1..=count)
                    .map(|value| StatsGroup {
                        key: Some(value.to_string()),
                        value,
                    })
                    .collect(),
                tag_groups_may_overlap: true,
            };
            let points =
                category_points(&stats, &query, &names, "/source/query").expect("categories");
            assert_eq!(points.len(), count.min(12) as usize);
            assert_eq!(points[0].value, count);
            if count >= 12 {
                let merged_count = count - 11;
                assert_eq!(
                    points[11].value,
                    (1..=merged_count).sum::<i64>(),
                    "count={count}"
                );
                assert_eq!(
                    points[11].label,
                    format!("其他（{merged_count} 项）"),
                    "count={count}"
                );
            }
        }

        let overflow = StatsResult {
            currency: "CNY".into(),
            total: 0,
            groups: (0..13)
                .map(|index| StatsGroup {
                    key: Some((index + 1).to_string()),
                    value: i64::MAX,
                })
                .collect(),
            tag_groups_may_overlap: false,
        };
        assert!(category_points(&overflow, &query, &names, "p").is_err());
    }
    #[test]
    fn trend_months_and_period_labels() {
        let p = |a: (i32, u32, u32), b: (i32, u32, u32)| Period {
            from: NaiveDate::from_ymd_opt(a.0, a.1, a.2).unwrap_or_default(),
            through: NaiveDate::from_ymd_opt(b.0, b.1, b.2).unwrap_or_default(),
        };
        let keys = month_keys(&p((2025, 11, 1), (2026, 2, 28)));
        assert_eq!(
            keys.iter().map(|k| k.0.as_str()).collect::<Vec<_>>(),
            ["2025-11", "2025-12", "2026-01", "2026-02"]
        );
        assert_eq!(keys[0].1, "2025年11月");
        assert_eq!(
            period_label(&p((2026, 10, 1), (2026, 10, 31))),
            "2026年10月"
        );
        assert_eq!(
            period_label(&p((2026, 5, 1), (2026, 10, 31))),
            "2026年5月–2026年10月"
        );
        assert_eq!(
            period_label(&p((2026, 10, 2), (2026, 10, 31))),
            "2026-10-02 至 2026-10-31"
        );
    }
    #[test]
    fn demo_output_is_marked() {
        for scene in [
            DemoScene::MonthlySpending,
            DemoScene::HalfYearTrend,
            DemoScene::RecentRecords,
        ] {
            let output = demo_output(scene, "CNY".into());
            assert!(output.demo);
            assert!(output.title.starts_with("【演示数据】"));
        }
        let trend = demo_output(DemoScene::HalfYearTrend, "CNY".into());
        assert_eq!(trend.total, Some(2_449_000));
        assert!(matches!(trend.trend, Some(TrendPayload::Ledger { .. })));
    }
    #[test]
    fn document_measurements_keep_fractional_values_units_and_limits() {
        let point = |value| jiabu_domain::documents::MetricPoint {
            document_id: Uuid::now_v7(),
            event_date: NaiveDate::from_ymd_opt(2026, 1, 2).unwrap_or_default(),
            value,
        };
        let output = measurement_trend(MetricResult {
            subject_id: Uuid::now_v7(),
            metric: "body.weight".into(),
            unit: Some("kg".into()),
            points: vec![point(62.5), point(0.0), point(-1.25)],
            excluded: vec![],
        })
        .expect("measurement trend");
        let value = serde_json::to_value(output).expect("serialized trend");
        assert_eq!(value["currency"], "");
        assert_eq!(value["trend"]["kind"], "measurement");
        assert_eq!(value["trend"]["unit"], "kg");
        assert_eq!(value["trend"]["points"][0]["value"], 62.5);
        assert_eq!(value["trend"]["points"][1]["value"], 0.0);
        assert_eq!(value["trend"]["points"][2]["value"], -1.25);

        let empty_unit = measurement_trend(MetricResult {
            subject_id: Uuid::now_v7(),
            metric: "body.weight".into(),
            unit: Some(String::new()),
            points: vec![point(62.5)],
            excluded: vec![],
        })
        .expect("empty unit is unitless");
        let value = serde_json::to_value(empty_unit).expect("serialized unitless trend");
        assert!(value["trend"]["unit"].is_null());

        let empty = measurement_trend(MetricResult {
            subject_id: Uuid::now_v7(),
            metric: "unitless".into(),
            unit: None,
            points: vec![],
            excluded: vec![],
        })
        .expect("empty measurement");
        assert_eq!(empty.status, DisplayStatus::NoData);
        assert!(empty.trend.is_none());

        let too_many = measurement_trend(MetricResult {
            subject_id: Uuid::now_v7(),
            metric: "body.weight".into(),
            unit: Some("kg".into()),
            points: (0..=MAX_TREND_POINTS).map(|_| point(1.0)).collect(),
            excluded: vec![],
        })
        .expect_err("more than 500 points");
        assert_eq!(
            too_many
                .errors
                .and_then(|errors| errors.into_iter().next())
                .map(|e| (e.pointer, e.rule)),
            Some((
                "/source/from_call".into(),
                "from_call: document_metric_series has at most 500 points".into()
            ))
        );
    }
    #[test]
    fn document_measurement_result_must_match_the_referenced_query() {
        let subject = Uuid::now_v7();
        let query = || MetricSeries {
            subject_id: subject,
            metric: "body.weight".into(),
            from: None,
            to: None,
        };
        let result = |subject_id, metric: &str| MetricResult {
            subject_id,
            metric: metric.into(),
            unit: Some("kg".into()),
            points: vec![jiabu_domain::documents::MetricPoint {
                document_id: Uuid::now_v7(),
                event_date: NaiveDate::from_ymd_opt(2026, 1, 2).unwrap_or_default(),
                value: 62.5,
            }],
            excluded: vec![],
        };
        assert!(referenced_measurement_trend(query(), result(subject, "body.weight")).is_ok());
        for mismatch in [
            result(Uuid::now_v7(), "body.weight"),
            result(subject, "body.height"),
        ] {
            let error = referenced_measurement_trend(query(), mismatch)
                .expect_err("mismatched result must be rejected");
            assert_eq!(
                error
                    .errors
                    .and_then(|errors| errors.into_iter().next())
                    .map(|issue| (issue.pointer, issue.rule)),
                Some((
                    "/source/from_call".into(),
                    "from_call: result subject_id and metric match the referenced query".into()
                ))
            );
        }
    }
}
