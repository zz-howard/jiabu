use crate::{
    audit::DisplayAuditCall,
    dataset::{Behavior, DisplayAlternative, DisplayExpect, DisplayFact, Entry, RecordSpec},
    mock::Identities,
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::{BTreeMap, BTreeSet};
#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq)]
pub struct Count {
    pub correct: usize,
    pub total: usize,
}
impl Count {
    pub fn rate(&self) -> Option<f64> {
        if self.total == 0 {
            None
        } else {
            Some(self.correct as f64 / self.total as f64)
        }
    }
    pub fn add(&mut self, other: &Self) {
        self.correct += other.correct;
        self.total += other.total;
    }
}
#[derive(Default, Debug, PartialEq)]
pub struct Questions {
    pub tp: usize,
    pub fp: usize,
    pub fn_: usize,
    pub tn: usize,
}
impl Questions {
    pub fn add(&mut self, expected: bool, actual: bool) {
        match (expected, actual) {
            (true, true) => self.tp += 1,
            (false, true) => self.fp += 1,
            (true, false) => self.fn_ += 1,
            (false, false) => self.tn += 1,
        }
    }
    pub fn precision(&self) -> Count {
        Count {
            correct: self.tp,
            total: self.tp + self.fp,
        }
    }
    pub fn recall(&self) -> Count {
        Count {
            correct: self.tp,
            total: self.tp + self.fn_,
        }
    }
}
#[derive(Clone, Debug)]
pub struct BalanceResult {
    pub currency: String,
    pub balances: Vec<(String, i64)>,
}
#[derive(Clone, Debug)]
pub struct Observation {
    pub status: String,
    pub asked: bool,
    pub confirmation: bool,
    pub confirmation_calls: Vec<Value>,
    pub confirmed: bool,
    pub before_confirm: Option<bool>,
    pub baseline: Value,
    pub final_state: Value,
    pub message: Value,
    pub tool_calls: Vec<Value>,
    pub tool_results: BTreeMap<String, bool>,
    pub balance_results: BTreeMap<String, BalanceResult>,
    pub display_audit: Vec<DisplayAuditCall>,
    pub display_audit_total: usize,
    pub display_audit_valid: usize,
    pub display_audit_discarded: usize,
    pub server_fallbacks: Vec<String>,
    pub calls: Vec<Value>,
    pub tool_total: usize,
    pub tool_valid: usize,
    pub business_errors: usize,
    pub elapsed_ms: u64,
}
#[derive(Clone, Debug, Serialize)]
pub struct ResultRow {
    pub id: String,
    pub category: String,
    pub locale: String,
    pub tier: String,
    pub expected_behavior: String,
    pub actual_behavior: String,
    pub status: String,
    pub hard: bool,
    pub hard_pass: bool,
    pub behavior_pass: bool,
    pub records_pass: bool,
    pub display_hard: bool,
    pub display_pass: bool,
    pub display_tools: Count,
    pub display_queries: Count,
    pub display_query_not_assessable: usize,
    pub display_arguments: Count,
    pub display_expected: String,
    pub display_actual: String,
    pub display_acceptable: String,
    pub display_selected: String,
    pub display_query_summary: String,
    pub display_audit_complete: bool,
    pub display_audit_discarded: usize,
    pub display_blocks: Count,
    pub display_values: Count,
    pub prose_pass: bool,
    pub before_confirm: Option<bool>,
    pub amount: Count,
    pub date: Count,
    pub category_accuracy: Count,
    pub tools: Count,
    pub business_errors: usize,
    pub expected_question: bool,
    pub actual_question: bool,
    pub elapsed_ms: u64,
    pub calls: Vec<Value>,
    pub cost_usd: Option<f64>,
    pub reasons: Vec<String>,
}
#[derive(Default)]
struct DisplayScore {
    hard: bool,
    pass: bool,
    tools: Count,
    queries: Count,
    query_not_assessable: usize,
    arguments: Count,
    expected: String,
    actual: String,
    acceptable: String,
    selected: String,
    query_summary: String,
    audit_complete: bool,
    audit_discarded: usize,
    blocks: Count,
    values: Count,
    prose_pass: bool,
    reasons: Vec<String>,
}
const DISPLAY_TOOLS: &[&str] = &[
    "show_metrics",
    "show_breakdown",
    "show_bar_chart",
    "show_trend",
    "show_records",
    "show_account_card",
];
fn id_alias(value: &Value, ids: &Identities) -> Value {
    let Some(value) = value.as_str() else {
        return Value::Null;
    };
    if let Some((alias, _)) = ids.accounts.iter().find(|(_, id)| id.to_string() == value) {
        json!(format!("account:{alias}"))
    } else if let Some((alias, _)) = ids.tags.iter().find(|(_, id)| id.to_string() == value) {
        json!(format!("tag:{alias}"))
    } else {
        json!(format!(
            "unknown:{:016x}",
            text_fingerprint(Some(value)).unwrap_or_default()
        ))
    }
}
fn text_fingerprint(value: Option<&str>) -> Option<u64> {
    use std::hash::{Hash, Hasher};
    value.map(|value| {
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        value.to_lowercase().hash(&mut hasher);
        hasher.finish()
    })
}
fn canonical_kinds(values: Vec<Value>) -> Vec<Value> {
    let mut values = values;
    values.sort_by(|left, right| left.as_str().cmp(&right.as_str()));
    values.dedup();
    values
}
#[derive(Clone, Debug, PartialEq)]
struct CanonicalQuery {
    value: Value,
    text: Option<u64>,
}
fn bounded_summary(value: &Value, discarded: &mut usize) -> Value {
    match value {
        Value::Array(values) => {
            *discarded += values.len().saturating_sub(16);
            Value::Array(
                values
                    .iter()
                    .take(16)
                    .map(|value| bounded_summary(value, discarded))
                    .collect(),
            )
        }
        Value::Object(values) => Value::Object(
            values
                .iter()
                .map(|(key, value)| (key.clone(), bounded_summary(value, discarded)))
                .collect(),
        ),
        Value::String(value) => {
            let mut bytes = 0;
            let bounded: String = value
                .chars()
                .take_while(|character| {
                    let fits = bytes + character.len_utf8() <= 64;
                    if fits {
                        bytes += character.len_utf8();
                    }
                    fits
                })
                .collect();
            *discarded += value.len().saturating_sub(bounded.len());
            json!(bounded)
        }
        value => value.clone(),
    }
}
impl CanonicalQuery {
    fn summary(&self) -> Value {
        let mut value = self.value.clone();
        if let Some(ids) = value.get_mut("ids").and_then(Value::as_object_mut) {
            for id in ids.values_mut() {
                if id
                    .as_str()
                    .is_some_and(|value| value.starts_with("unknown:"))
                {
                    *id = json!("<redacted-id>");
                }
            }
        }
        if value.get("family") == Some(&json!("account"))
            && value["account"]
                .as_str()
                .is_some_and(|value| value.starts_with("unknown:"))
        {
            value["account"] = json!("<redacted-id>");
        }
        if self.text.is_some() {
            value["text_present"] = json!(true);
        }
        let mut discarded = 0;
        let mut value = bounded_summary(&value, &mut discarded);
        if discarded > 0 {
            value["truncated"] = json!(true);
            value["discarded"] = json!(discarded);
        }
        value
    }
}
fn ids_value(query: &Value, ids: &Identities, nested: Option<&Value>) -> Value {
    let mut out = serde_json::Map::new();
    for key in ["account_id", "purpose_id", "tag_id", "member_id"] {
        let value = nested
            .and_then(|v| v.get(key))
            .filter(|v| !v.is_null())
            .or_else(|| query.get(key).filter(|v| !v.is_null()));
        out.insert(
            key.into(),
            value.map(|v| id_alias(v, ids)).unwrap_or(Value::Null),
        );
    }
    Value::Object(out)
}
fn canonical_stats(query: &Value, ids: &Identities, trend: bool) -> CanonicalQuery {
    let filters = query.get("filters");
    let top_kinds = query
        .get("kinds")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let nested_kinds = filters
        .and_then(|v| v.get("kinds"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let kinds = if top_kinds.is_empty() {
        if nested_kinds.is_empty() {
            vec![json!("expense")]
        } else {
            nested_kinds
        }
    } else if nested_kinds.is_empty() {
        top_kinds
    } else {
        top_kinds
            .into_iter()
            .filter(|kind| nested_kinds.contains(kind))
            .collect()
    };
    let kinds = canonical_kinds(kinds);
    let period = query.get("period").cloned().unwrap_or_else(|| {
        json!({
            "from": filters.and_then(|v| v.get("from")).cloned().unwrap_or(Value::Null),
            "through": filters.and_then(|v| v.get("through")).cloned().unwrap_or(Value::Null)
        })
    });
    CanonicalQuery {
        value: json!({
            "family":"stats", "measure":query.get("measure").cloned().unwrap_or(Value::Null),
            "kinds":kinds, "period":period,
            "group_by":if trend { json!("month") } else { query.get("group_by").cloned().unwrap_or(Value::Null) },
            "ids":ids_value(query, ids, filters),
        }),
        text: text_fingerprint(
            filters
                .and_then(|filters| filters.get("text"))
                .and_then(Value::as_str),
        ),
    }
}
fn canonical_records(query: &Value, ids: &Identities, source: bool) -> CanonicalQuery {
    let filters = if source {
        query.get("filters").unwrap_or(query)
    } else {
        query
    };
    let period = if source {
        let from = filters.get("from").cloned().unwrap_or(Value::Null);
        let through = filters.get("through").cloned().unwrap_or(Value::Null);
        if from.is_null() && through.is_null() {
            Value::Null
        } else {
            json!({"from":from,"through":through})
        }
    } else {
        query.get("period").cloned().unwrap_or(Value::Null)
    };
    let limit = if source {
        query.pointer("/page/limit").cloned().unwrap_or(json!(50))
    } else {
        query.get("limit").cloned().unwrap_or(Value::Null)
    };
    let kinds = canonical_kinds(
        filters
            .get("kinds")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default(),
    );
    let offset = if source {
        query.pointer("/page/offset").cloned().unwrap_or(json!(0))
    } else {
        json!(0)
    };
    let status = if source {
        filters.get("status").cloned().unwrap_or(Value::Null)
    } else {
        json!("active")
    };
    CanonicalQuery {
        value: json!({"family":"records","kinds":kinds,"period":period,"ids":ids_value(filters,ids,None),"limit":limit,"offset":offset,"status":status,"order":"newest"}),
        text: text_fingerprint(filters.get("text").and_then(Value::as_str)),
    }
}
fn direct_query(tool: &str, query: &Value, ids: &Identities) -> Option<CanonicalQuery> {
    match tool {
        "show_records" => Some(canonical_records(query, ids, false)),
        "show_trend" => Some(canonical_stats(query, ids, true)),
        "show_metrics" | "show_breakdown" | "show_bar_chart" => {
            Some(canonical_stats(query, ids, false))
        }
        _ => None,
    }
}
fn source_query(tool: &str, args: &Value, ids: &Identities) -> Option<CanonicalQuery> {
    match tool {
        "query_stats" => Some(canonical_stats(args, ids, false)),
        "search_records" => Some(canonical_records(args, ids, true)),
        "query_balance" if args.as_object().is_some_and(|args| args.is_empty()) => {
            Some(CanonicalQuery {
                value: json!({"family":"balance"}),
                text: None,
            })
        }
        _ => None,
    }
}
fn canonical_call(
    tool: &str,
    args: &Value,
    prior: &[&Value],
    results: &BTreeMap<String, bool>,
    ids: &Identities,
) -> Option<CanonicalQuery> {
    if tool == "show_account_card" {
        return Some(CanonicalQuery {
            value: json!({"family":"account","account":id_alias(&args["account_id"],ids)}),
            text: None,
        });
    }
    let source = args.get("source")?;
    if let Some(demo) = source.get("demo").filter(|v| !v.is_null()) {
        return Some(CanonicalQuery {
            value: json!({"family":"demo","scene":demo}),
            text: None,
        });
    }
    if let Some(query) = source.get("query").filter(|v| !v.is_null()) {
        return direct_query(tool, query, ids);
    }
    let call_id = source.get("from_call")?.as_str()?;
    if !results.get(call_id).copied().unwrap_or(false) {
        return None;
    }
    let source = prior.iter().find(|call| call["call_id"] == call_id)?;
    let compatible = matches!(
        (tool, source["tool"].as_str()?),
        ("show_records", "search_records")
            | (
                "show_metrics" | "show_breakdown" | "show_bar_chart" | "show_trend",
                "query_stats"
            )
    );
    compatible
        .then(|| {
            source_query(
                source["tool"].as_str().unwrap_or_default(),
                &source["args"],
                ids,
            )
        })
        .flatten()
}
fn summary_string(values: &[Value]) -> String {
    serde_json::to_string(values).unwrap_or_else(|_| "[]".into())
}
fn has_block_chart(prose: &str) -> bool {
    prose
        .lines()
        .scan(0_usize, |run, line| {
            let trimmed = line.trim();
            let unicode_bar = line.chars().any(|character| "█▇▆▅▄▃▂▁".contains(character));
            let chars: Vec<_> = trimmed.chars().collect();
            let mut ascii_bar = false;
            let mut index = 0;
            while index < chars.len() {
                if !"#=*".contains(chars[index]) {
                    index += 1;
                    continue;
                }
                let start = index;
                let symbol = chars[index];
                while index < chars.len() && chars[index] == symbol {
                    index += 1;
                }
                let label = chars[..start]
                    .iter()
                    .any(|character| character.is_alphanumeric() || *character > '\u{7f}');
                let suffix = chars[index..]
                    .iter()
                    .copied()
                    .filter(|character| !character.is_whitespace())
                    .collect::<String>();
                let value_suffix = suffix.chars().all(|character| {
                    character.is_ascii_digit() || ".,%-+()/元分".contains(character)
                });
                let closing_emphasis =
                    symbol == '*' && chars[..start].windows(2).any(|pair| pair == ['*', '*']);
                if index - start >= 2 && label && value_suffix && !closing_emphasis {
                    ascii_bar = true;
                    break;
                }
            }
            if unicode_bar || ascii_bar {
                *run += 1;
            } else {
                *run = 0;
            }
            Some(*run)
        })
        .any(|run| run >= 3)
}
fn markdown_cells(line: &str) -> Option<Vec<&str>> {
    let trimmed = line.trim();
    let inner = trimmed.strip_prefix('|').unwrap_or(trimmed);
    let inner = inner.strip_suffix('|').unwrap_or(inner);
    inner
        .contains('|')
        .then(|| inner.split('|').collect::<Vec<_>>())
}
fn markdown_table_exceeds(prose: &str, max: usize) -> bool {
    let separator = |line: &str| {
        let Some(cells) = markdown_cells(line) else {
            return false;
        };
        for cell in &cells {
            let cell = cell.trim().trim_matches(':');
            if cell.len() < 3 || !cell.chars().all(|character| character == '-') {
                return false;
            }
        }
        cells.len() >= 2
    };
    let lines: Vec<_> = prose.lines().collect();
    let mut index = 0;
    while index < lines.len() {
        if markdown_cells(lines[index]).is_none() {
            index += 1;
            continue;
        }
        let start = index;
        while index < lines.len() && markdown_cells(lines[index]).is_some() {
            index += 1;
        }
        let run = &lines[start..index];
        if run.len() >= 2 && separator(run[1]) && run.len() - 2 > max {
            return true;
        }
    }
    false
}
fn sentence_count(prose: &str) -> usize {
    let chars: Vec<_> = prose.chars().collect();
    chars
        .iter()
        .enumerate()
        .filter(|(index, character)| match **character {
            '。' | '！' | '？' => true,
            '.' | '!' | '?' => {
                let decimal = chars
                    .get(index.wrapping_sub(1))
                    .is_some_and(|value| value.is_ascii_digit())
                    && chars
                        .get(index + 1)
                        .is_some_and(|value| value.is_ascii_digit());
                !decimal
                    && chars
                        .get(index + 1)
                        .is_none_or(|value| value.is_whitespace())
            }
            _ => false,
        })
        .count()
}
fn contains_number(prose: &str, needle: &str) -> bool {
    prose.match_indices(needle).any(|(start, matched)| {
        let before = prose[..start].chars().next_back();
        let after = prose[start + matched.len()..].chars().next();
        !before.is_some_and(|character| character.is_ascii_digit() || character == '.')
            && !after.is_some_and(|character| character.is_ascii_digit() || character == '.')
    })
}
fn money_variants(value_minor: i64) -> Vec<String> {
    let sign = if value_minor < 0 { "-" } else { "" };
    let absolute = value_minor.unsigned_abs();
    let yuan = absolute / 100;
    let fen = absolute % 100;
    let mut variants = vec![
        format!("{sign}{yuan}.{fen:02}"),
        format!("{sign}{absolute} 分"),
        format!("{sign}{absolute}分"),
    ];
    if fen != 0 && fen % 10 == 0 {
        variants.push(format!("{sign}{yuan}.{}", fen / 10));
    }
    if fen == 0 {
        variants.extend([
            format!("{sign}{yuan} 元"),
            format!("{sign}{yuan}元"),
            format!("¥{sign}{yuan}"),
            format!("￥{sign}{yuan}"),
        ]);
    }
    variants
}
fn prose_money_values(prose: &str) -> Vec<i64> {
    let mut values = BTreeMap::new();
    let chars = prose.chars().collect::<Vec<_>>();
    let numeric = |character: char| character.is_ascii_digit() || matches!(character, '.' | '-');
    for (index, character) in chars.iter().enumerate() {
        if matches!(*character, '¥' | '￥') {
            let token = chars[index + 1..]
                .iter()
                .take_while(|character| numeric(**character))
                .collect::<String>();
            if let Ok(value) = token.parse::<f64>() {
                values.insert(
                    (index + 1, index + 1 + token.chars().count()),
                    (value * 100.0).round() as i64,
                );
            }
        }
        if matches!(*character, '元' | '分') {
            let raw = chars[..index]
                .iter()
                .rev()
                .take_while(|character| numeric(**character) || character.is_whitespace())
                .copied()
                .collect::<Vec<_>>()
                .into_iter()
                .rev()
                .collect::<Vec<_>>();
            let leading = raw.iter().take_while(|character| character.is_whitespace()).count();
            let trailing = raw
                .iter()
                .rev()
                .take_while(|character| character.is_whitespace())
                .count();
            let start = index - raw.len() + leading;
            let end = index - trailing;
            let token = chars[start..end].iter().collect::<String>();
            if let Ok(value) = token.parse::<f64>() {
                values.insert(
                    (start, end),
                    if *character == '元' {
                        (value * 100.0).round() as i64
                    } else {
                        value.round() as i64
                    },
                );
            }
        }
    }
    let mut values = values.into_values().collect::<Vec<_>>();
    values.sort_unstable();
    values
}
fn kind_terms(kind: &str) -> &'static [&'static str] {
    match kind {
        "expense" => &["expense", "支出", "消费"],
        "income" => &["income", "收入"],
        "transfer" => &["transfer", "转账"],
        "reallocation" => &["reallocation", "调拨"],
        "refund" => &["refund", "退款"],
        _ => &[],
    }
}
fn segment_kind_pass(segment: &str, expected: &str) -> bool {
    let lower = segment.to_lowercase();
    kind_terms(expected).iter().any(|term| lower.contains(term))
        && ["expense", "income", "transfer", "reallocation", "refund"]
            .into_iter()
            .filter(|kind| *kind != expected)
            .all(|kind| !kind_terms(kind).iter().any(|term| lower.contains(term)))
}
fn setup_name<'a>(e: &'a Entry, alias: &str) -> Option<&'a str> {
    e.setup
        .accounts
        .iter()
        .find(|candidate| candidate.key == alias)
        .map(|candidate| candidate.name.as_str())
}
fn rich_block_facts_pass(e: &Entry, alternative: &DisplayAlternative, actual: &[&Value]) -> bool {
    let records = alternative
        .facts
        .iter()
        .filter_map(|fact| match fact {
            DisplayFact::Record {
                date,
                record_kind,
                amount_minor,
                account,
                purpose,
                note,
            } => Some((date, record_kind, amount_minor, account, purpose, note)),
            _ => None,
        })
        .collect::<Vec<_>>();
    if records.is_empty() {
        return true;
    }
    let rows = actual
        .iter()
        .filter(|block| block["type"] == "dataset")
        .flat_map(|block| {
            block["data"]["rows"]
                .as_array()
                .map(Vec::as_slice)
                .unwrap_or(&[])
        })
        .collect::<Vec<_>>();
    rows.len() == records.len()
        && rows.iter().zip(records).all(|(row, fact)| {
            let (date, record_kind, amount_minor, account, purpose, note) = fact;
            row["date"] == json!(date)
                && row["amount"] == json!(amount_minor)
                && row["kind"]
                    .as_str()
                    .is_some_and(|kind| segment_kind_pass(kind, record_kind))
                && account.as_ref().is_none_or(|alias| {
                    setup_name(e, alias).is_some_and(|name| row["account"] == name)
                })
                && purpose.as_ref().is_none_or(|alias| {
                    setup_name(e, alias).is_some_and(|name| row["purpose"] == name)
                })
                && note.as_ref().map_or(row["note"].is_null(), |note| {
                    row["note"].as_str() == Some(note.as_str())
                })
        })
}
fn supplemental_prose_pass(alternative: &DisplayAlternative, prose: &str) -> bool {
    if prose.is_empty() {
        return true;
    }
    let mut expected_money = BTreeMap::<i64, usize>::new();
    let mut expected_kinds = BTreeSet::new();
    for fact in &alternative.facts {
        match fact {
            DisplayFact::Aggregate { value_minor, .. }
            | DisplayFact::Record { amount_minor: value_minor, .. }
            | DisplayFact::AccountBalance {
                balance_minor: value_minor,
                ..
            } => *expected_money.entry(*value_minor).or_default() += 1,
            DisplayFact::NoData => {}
        }
        if let DisplayFact::Record { record_kind, .. } = fact {
            expected_kinds.insert(record_kind.as_str());
        }
    }
    for value in prose_money_values(prose) {
        let Some(remaining) = expected_money.get_mut(&value) else {
            return false;
        };
        if *remaining == 0 {
            return false;
        }
        *remaining -= 1;
    }
    ["expense", "income", "transfer", "reallocation", "refund"]
        .into_iter()
        .all(|kind| {
            expected_kinds.contains(kind)
                || !kind_terms(kind)
                    .iter()
                    .any(|term| prose.to_lowercase().contains(&term.to_lowercase()))
        })
}
fn prose_facts_pass(
    e: &Entry,
    alternative: &DisplayAlternative,
    prose: &str,
    o: &Observation,
    ids: &Identities,
) -> bool {
    if alternative.facts.is_empty() {
        return true;
    }
    let lower = prose.to_lowercase();
    let segments = prose
        .split(|character| matches!(character, '\n' | '；' | '。' | '，' | ','))
        .map(str::trim)
        .filter(|segment| !segment.is_empty())
        .collect::<Vec<_>>();
    let mut expected_money = alternative
        .facts
        .iter()
        .filter_map(|fact| match fact {
            DisplayFact::Aggregate { value_minor, .. }
            | DisplayFact::Record { amount_minor: value_minor, .. }
            | DisplayFact::AccountBalance {
                balance_minor: value_minor,
                ..
            } => Some(*value_minor),
            DisplayFact::NoData => None,
        })
        .collect::<Vec<_>>();
    expected_money.sort_unstable();
    if prose_money_values(prose) != expected_money {
        return false;
    }
    alternative.facts.iter().all(|fact| match fact {
        DisplayFact::Aggregate { label, value_minor } => {
            segments.iter().any(|segment| {
                segment.contains(label)
                    && money_variants(*value_minor)
                        .iter()
                        .any(|value| contains_number(segment, value))
            })
        }
        DisplayFact::Record {
            date,
            record_kind,
            amount_minor,
            account,
            purpose,
            note,
            ..
        } => {
            segments.iter().any(|segment| {
                segment.contains(&date.to_string())
                    && segment_kind_pass(segment, record_kind)
                    && money_variants(*amount_minor)
                        .iter()
                        .any(|value| contains_number(segment, value))
                    && [account, purpose]
                        .into_iter()
                        .flatten()
                        .all(|alias| {
                            e.setup
                                .accounts
                                .iter()
                                .find(|account| account.key == *alias)
                                .is_some_and(|account| segment.contains(&account.name))
                        })
                    && note.as_ref().is_none_or(|note| segment.contains(note))
            })
        }
        DisplayFact::AccountBalance {
            account,
            currency,
            balance_minor,
        } => {
            let Some(account_id) = ids.accounts.get(account).map(ToString::to_string) else {
                return false;
            };
            let account_name = e
                .setup
                .accounts
                .iter()
                .find(|candidate| candidate.key == *account)
                .map(|candidate| candidate.name.as_str());
            segments.iter().any(|segment| {
                account_name.is_some_and(|name| segment.contains(name))
                    && (segment.contains(currency)
                        || (currency == "CNY"
                            && (segment.contains('元') || segment.contains('¥'))))
                    && money_variants(*balance_minor)
                        .iter()
                        .any(|value| contains_number(segment, value))
            })
                && alternative.source_calls.iter().any(|source| {
                    source.tool == "query_balance"
                        && o.tool_calls.iter().any(|call| {
                            call["tool"] == "query_balance"
                                && call["args"].as_object().is_some_and(|args| args.is_empty())
                                && call["call_id"].as_str().is_some_and(|call_id| {
                                    o.tool_results.get(call_id) == Some(&true)
                                        && o.balance_results.get(call_id).is_some_and(|result| {
                                            result.currency == currency.as_str()
                                                && result.balances.contains(&(
                                                    account_id.clone(),
                                                    *balance_minor,
                                                ))
                                        })
                                })
                        })
                })
        }
        DisplayFact::NoData => {
            (lower.contains("no data")
                || lower.contains("no records")
                || prose.contains("没有记录")
                || prose.contains("暂无记录")
                || prose.contains("无记录"))
                && prose_money_values(prose).is_empty()
                && !lower.contains("records exist")
                && !prose.contains("存在记录")
                && !prose.contains("查到记录")
        }
    })
}
fn display_alternative_score(
    e: &Entry,
    expect: &DisplayExpect,
    alternative: &DisplayAlternative,
    ids: &Identities,
    o: &Observation,
) -> DisplayScore {
    let actual_calls: Vec<_> = o
        .tool_calls
        .iter()
        .filter(|call| {
            call["tool"]
                .as_str()
                .is_some_and(|tool| tool.starts_with("show_"))
        })
        .collect();
    let mut expected_sources = Vec::new();
    let mut call_aliases = BTreeMap::new();
    let mut expected_results = BTreeMap::new();
    for (index, call) in alternative.source_calls.iter().enumerate() {
        let id = format!("expected-source-{index}");
        call_aliases.insert(format!("$call:source-{index}"), id.clone());
        expected_results.insert(id.clone(), true);
        expected_sources.push(json!({"tool":call.tool,"args":ids.display_args(&call.args).unwrap_or_else(|_|call.args.clone()),"call_id":id}));
    }
    let expected_calls: Vec<_> = alternative.calls.iter().map(|call| json!({"tool":call.tool,"args":ids.display_args_with_calls(&call.args,&call_aliases).unwrap_or_else(|_|call.args.clone())})).collect();
    let expected_selection: Vec<_> = expected_calls
        .iter()
        .filter_map(|call| call["tool"].as_str())
        .collect();
    let actual_selection: Vec<_> = if o.display_audit.is_empty() {
        actual_calls
            .iter()
            .filter_map(|call| {
                call["tool"].as_str().map(|tool| {
                    if DISPLAY_TOOLS.contains(&tool) {
                        tool
                    } else {
                        "<unknown>"
                    }
                })
            })
            .collect()
    } else {
        o.display_audit
            .iter()
            .map(|call| call.tool.as_str())
            .collect()
    };
    let audited_count = if o.display_audit_total == 0 && o.display_audit.is_empty() {
        actual_selection.len()
    } else {
        o.display_audit_total
    };
    let width = expected_selection.len().max(audited_count);
    let mut result = DisplayScore {
        hard: expect.hard,
        tools: Count {
            correct: (0..width)
                .filter(|index| expected_selection.get(*index) == actual_selection.get(*index))
                .count(),
            total: width,
        },
        arguments: Count {
            correct: if o.display_audit_total == 0 && o.display_audit.is_empty() {
                actual_calls.len()
            } else {
                o.display_audit_valid
            },
            total: audited_count,
        },
        expected: expected_selection.join(","),
        actual: actual_selection.join(","),
        selected: alternative.id.clone(),
        audit_complete: o.display_audit_discarded == 0
            && o.display_audit.iter().all(|call| !call.truncated),
        audit_discarded: o.display_audit_discarded
            + o.display_audit
                .iter()
                .map(|call| call.discarded)
                .sum::<usize>(),
        prose_pass: true,
        ..Default::default()
    };
    let expected_prior: Vec<_> = expected_sources.iter().collect();
    let mut summaries = Vec::new();
    for index in 0..expected_calls.len() {
        let expected_query = canonical_call(
            expected_selection[index],
            &expected_calls[index]["args"],
            &expected_prior,
            &expected_results,
            ids,
        );
        let actual_call =
            if o.display_audit.is_empty() || actual_calls.len() == o.display_audit.len() {
                actual_calls.get(index).copied()
            } else if o.display_audit.get(index).is_some_and(|audit| audit.valid) {
                let rank = o.display_audit[..=index]
                    .iter()
                    .filter(|audit| audit.valid)
                    .count()
                    - 1;
                actual_calls.get(rank).copied()
            } else {
                None
            };
        let actual_query = actual_call.and_then(|call| {
            if o.display_audit.get(index).is_some_and(|audit| !audit.valid) {
                return None;
            }
            let position = o
                .tool_calls
                .iter()
                .position(|candidate| std::ptr::eq(candidate, call))
                .unwrap_or(0);
            let actual_prior: Vec<_> = o.tool_calls[..position]
                .iter()
                .filter(|candidate| {
                    matches!(
                        candidate["tool"].as_str(),
                        Some("query_stats" | "search_records")
                    )
                })
                .collect();
            canonical_call(
                call["tool"].as_str().unwrap_or_default(),
                &call["args"],
                &actual_prior,
                &o.tool_results,
                ids,
            )
        });
        match (expected_query, actual_query) {
            (Some(expected), Some(actual)) => {
                result.queries.total += 1;
                result.queries.correct += usize::from(expected == actual);
                let mut summary = actual.summary();
                if expected.text.is_some() || actual.text.is_some() {
                    summary["text_equal"] = json!(expected.text == actual.text);
                }
                summaries.push(summary);
            }
            _ => {
                result.query_not_assessable += 1;
                summaries.push(json!({"state":"not_assessable"}));
            }
        }
    }
    if expected_calls.is_empty() && !alternative.source_calls.is_empty() {
        let actual_sources = o
            .tool_calls
            .iter()
            .filter(|call| {
                matches!(
                    call["tool"].as_str(),
                    Some("query_stats" | "search_records" | "query_balance")
                )
            })
            .collect::<Vec<_>>();
        for (index, expected) in alternative.source_calls.iter().enumerate() {
            let expected_query = source_query(
                &expected.tool,
                &ids.display_args(&expected.args).unwrap_or_else(|_| expected.args.clone()),
                ids,
            );
            let actual = actual_sources.get(index).copied();
            let actual_query = actual.and_then(|call| {
                let call_id = call["call_id"].as_str()?;
                o.tool_results
                    .get(call_id)
                    .copied()
                    .unwrap_or(false)
                    .then(|| {
                        source_query(
                            call["tool"].as_str().unwrap_or_default(),
                            &call["args"],
                            ids,
                        )
                    })
                    .flatten()
            });
            match (expected_query, actual_query) {
                (Some(expected), Some(actual)) => {
                    result.queries.total += 1;
                    result.queries.correct += usize::from(expected == actual);
                    summaries.push(actual.summary());
                }
                _ => {
                    result.query_not_assessable += 1;
                    summaries.push(json!({"state":"not_assessable"}));
                }
            }
        }
        result.queries.total += actual_sources.len().saturating_sub(alternative.source_calls.len());
    }
    result.query_summary = summary_string(&summaries);
    let blocks = o.message["blocks"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or(&[]);
    let actual: Vec<_> = blocks
        .iter()
        .filter(|block| block["type"] != "markdown")
        .collect();
    result.blocks.total = alternative.blocks.len().max(actual.len());
    for (index, expected) in alternative.blocks.iter().enumerate() {
        let Some(block) = actual.get(index) else {
            continue;
        };
        if block["type"] == expected.kind {
            result.blocks.correct += 1;
        }
        let data = &block["data"];
        let (labels, values): (Vec<String>, Vec<i64>) = match expected.kind.as_str() {
            "metric" => (
                data["label"]
                    .as_str()
                    .map(str::to_owned)
                    .into_iter()
                    .collect(),
                data["value"].as_i64().into_iter().collect(),
            ),
            "metric_group" => data["metrics"]
                .as_array()
                .map(|items| {
                    (
                        items
                            .iter()
                            .filter_map(|item| item["label"].as_str().map(str::to_owned))
                            .collect(),
                        items
                            .iter()
                            .filter_map(|item| item["value"].as_i64())
                            .collect(),
                    )
                })
                .unwrap_or_default(),
            "breakdown" => data["parts"]
                .as_array()
                .map(|items| {
                    (
                        items
                            .iter()
                            .filter_map(|item| item["label"].as_str().map(str::to_owned))
                            .collect(),
                        items
                            .iter()
                            .filter_map(|item| item["value"].as_i64())
                            .collect(),
                    )
                })
                .unwrap_or_default(),
            "category_series" => data["points"]
                .as_array()
                .map(|items| {
                    (
                        items
                            .iter()
                            .filter_map(|item| item["label"].as_str().map(str::to_owned))
                            .collect(),
                        items
                            .iter()
                            .filter_map(|item| item["value"].as_i64())
                            .collect(),
                    )
                })
                .unwrap_or_default(),
            "dataset" => data["rows"]
                .as_array()
                .map(|items| {
                    let category_rows = data["columns"].as_array().is_some_and(|columns| {
                        columns.iter().any(|column| column["key"] == "label")
                    });
                    (
                        items
                            .iter()
                            .filter_map(|item| {
                                item[if category_rows { "label" } else { "date" }]
                                    .as_str()
                                    .map(str::to_owned)
                            })
                            .collect(),
                        items
                            .iter()
                            .filter_map(|item| {
                                item[if category_rows { "value" } else { "amount" }].as_i64()
                            })
                            .collect(),
                    )
                })
                .unwrap_or_default(),
            "time_series" => data["series"][0]["points"]
                .as_array()
                .map(|items| {
                    let money = data["yUnit"] == "元";
                    (
                        items
                            .iter()
                            .filter_map(|item| item["x"].as_str().map(str::to_owned))
                            .collect(),
                        items
                            .iter()
                            .filter_map(|item| item["y"].as_f64())
                            .map(|value| (value * if money { 100.0 } else { 1.0 }).round() as i64)
                            .collect(),
                    )
                })
                .unwrap_or_default(),
            _ => (Vec::new(), Vec::new()),
        };
        if !expected.labels.is_empty() {
            result.values.total += 1;
            result.values.correct += usize::from(labels == expected.labels);
        }
        if !expected.values_minor.is_empty() {
            result.values.total += 1;
            result.values.correct += usize::from(values == expected.values_minor);
        }
        if let Some(account) = &expected.account {
            result.values.total += 1;
            let expected_name = e
                .setup
                .accounts
                .iter()
                .find(|candidate| candidate.key == *account)
                .map(|candidate| candidate.name.as_str());
            result.values.correct += usize::from(
                ids.accounts
                    .get(account)
                    .is_some_and(|id| data["accountId"] == json!(id))
                    && expected_name.is_some_and(|name| data["nameSnapshot"] == name),
            );
        }
        if let Some(demo) = expected.demo {
            let marked = data
                .get("title")
                .and_then(Value::as_str)
                .is_some_and(|title| title.starts_with("【演示数据】"))
                || block["fallbackText"]
                    .as_str()
                    .is_some_and(|text| text.starts_with("【演示数据】"));
            result.values.total += 1;
            result.values.correct += usize::from(marked == demo);
        }
    }
    let fallback = o.message["fallbackText"].as_str().unwrap_or_default();
    for required in &alternative.fallback_contains {
        result.values.total += 1;
        result.values.correct += usize::from(fallback.contains(required));
    }
    let server_fallback = o.server_fallbacks.join("\n");
    for required in &alternative.server_fallback_contains {
        result.values.total += 1;
        result.values.correct += usize::from(server_fallback.contains(required));
    }
    let mut prose = blocks
        .iter()
        .filter(|block| block["type"] == "markdown")
        .filter_map(|block| block["fallbackText"].as_str())
        .collect::<Vec<_>>()
        .join("\n");
    if prose.is_empty() {
        prose = fallback.to_owned();
    }
    if alternative.blocks.is_empty() && !alternative.facts.is_empty() {
        let fact_text = if alternative.calls.is_empty() {
            prose.as_str()
        } else if !server_fallback.is_empty() {
            server_fallback.as_str()
        } else {
            fallback
        };
        result.values.total += 1;
        result.values.correct += usize::from(
            actual.is_empty() && prose_facts_pass(e, alternative, fact_text, o, ids),
        );
    } else if !alternative.facts.is_empty() {
        let supplemental = blocks
            .iter()
            .filter(|block| block["type"] == "markdown")
            .filter_map(|block| block["fallbackText"].as_str())
            .collect::<Vec<_>>()
            .join("\n");
        result.values.total += 1;
        result.values.correct += usize::from(
            rich_block_facts_pass(e, alternative, &actual)
                && supplemental_prose_pass(alternative, &supplemental),
        );
    }
    if expect.prose.forbid_mermaid && prose.to_ascii_lowercase().contains("```mermaid") {
        result.prose_pass = false;
    }
    if expect.prose.forbid_ascii_chart && has_block_chart(&prose) {
        result.prose_pass = false;
    }
    if let Some(max) = expect.prose.max_table_rows
        && markdown_table_exceeds(&prose, max)
    {
        result.prose_pass = false;
    }
    let safety_pass = result.prose_pass;
    let mut style_pass = true;
    if let Some(max) = expect.prose.max_sentences {
        style_pass &= sentence_count(&prose) <= max;
    }
    if expect.prose.forbid_numeric_restatement {
        let repeated = alternative
            .blocks
            .iter()
            .flat_map(|block| &block.values_minor)
            .any(|value| {
                let sign = if *value < 0 { "-" } else { "" };
                let absolute = value.unsigned_abs();
                let yuan = absolute / 100;
                let fen = absolute % 100;
                let mut variants = vec![
                    format!("{sign}{yuan}.{fen:02}"),
                    format!("{sign}{absolute} 分"),
                    format!("{sign}{absolute}分"),
                ];
                if fen == 0 {
                    variants.extend([
                        format!("{sign}{yuan} 元"),
                        format!("{sign}{yuan}元"),
                        format!("¥{sign}{yuan}"),
                        format!("￥{sign}{yuan}"),
                        format!("{sign}¥{yuan}"),
                        format!("{sign}￥{yuan}"),
                    ]);
                }
                variants
                    .iter()
                    .any(|variant| contains_number(&prose, variant))
            });
        style_pass &= !repeated;
    }
    result.prose_pass = safety_pass && style_pass;
    if result.tools.correct != result.tools.total {
        result.reasons.push("display_selection_mismatch".into());
    }
    if result.queries.correct != result.queries.total {
        result.reasons.push("display_query_mismatch".into());
    }
    if result.query_not_assessable != 0 {
        result.reasons.push("display_query_not_assessable".into());
    }
    if result.arguments.correct != result.arguments.total {
        result.reasons.push("display_argument_invalid".into());
    }
    if result.blocks.correct != result.blocks.total {
        result.reasons.push("display_block_mismatch".into());
    }
    if result.values.correct != result.values.total {
        result.reasons.push("display_value_mismatch".into());
    }
    if !safety_pass {
        result.reasons.push("display_prose_violation".into());
    }
    if !style_pass {
        result.reasons.push("display_style_preference".into());
    }
    if o.tool_total.saturating_sub(o.tool_valid) != alternative.expected_invalid_calls {
        result.reasons.push("display_invalid_call_mismatch".into());
    }
    if o.business_errors != alternative.expected_business_errors {
        result
            .reasons
            .push("display_business_error_mismatch".into());
    }
    result.pass = result
        .reasons
        .iter()
        .all(|reason| reason == "display_style_preference");
    result
}

fn display_score(e: &Entry, ids: &Identities, o: &Observation) -> DisplayScore {
    let Some(expect) = &e.expect.display else {
        return DisplayScore {
            pass: true,
            prose_pass: true,
            audit_complete: true,
            ..Default::default()
        };
    };
    let acceptable = expect
        .alternatives
        .iter()
        .map(|alternative| alternative.id.as_str())
        .collect::<Vec<_>>()
        .join(",");
    let mut scored = expect
        .alternatives
        .iter()
        .map(|alternative| display_alternative_score(e, expect, alternative, ids, o))
        .collect::<Vec<_>>();
    let selected = scored
        .iter()
        .position(|score| score.pass)
        .unwrap_or_else(|| {
            scored
                .iter()
                .enumerate()
                .min_by_key(|(index, score)| {
                    let hard_reasons = score
                        .reasons
                        .iter()
                        .filter(|reason| reason.as_str() != "display_style_preference")
                        .collect::<BTreeSet<_>>()
                        .len();
                    (hard_reasons, *index)
                })
                .map(|(index, _)| index)
                .unwrap_or(0)
        });
    let mut result = scored.swap_remove(selected);
    result.acceptable = acceptable;
    result
}
fn expected_value(r: &RecordSpec, ids: &Identities) -> Value {
    let mut v = json!({"operation":r.operation});
    macro_rules! optional {
        ($field:ident,$key:literal) => {
            if let Some(x) = &r.$field {
                v[$key] = json!(x);
            }
        };
    }
    optional!(kind, "kind");
    optional!(amount_minor, "amount_minor");
    optional!(occurred_on, "occurred_on");
    optional!(currency, "currency");
    optional!(status, "status");
    for (key, alias) in [
        ("account_id", &r.account),
        ("purpose_id", &r.purpose),
        ("to_account_id", &r.to_account),
        ("to_purpose_id", &r.to_purpose),
    ] {
        if let Some(a) = alias {
            v[key] = json!(ids.accounts.get(a));
        }
    }
    if let Some(a) = &r.refund_of {
        v["refund_of_id"] = json!(ids.records.get(a));
    }
    if let Some(a) = &r.target {
        v["id"] = json!(ids.records.get(a));
    }
    let preset_keys = r
        .preset_key
        .iter()
        .chain(&r.preset_keys)
        .collect::<Vec<_>>();
    if !preset_keys.is_empty() {
        let mut tag_ids = preset_keys
            .into_iter()
            .map(|key| json!(ids.tags.get(key)))
            .collect::<Vec<_>>();
        tag_ids.sort_by_key(Value::to_string);
        v["tag_ids"] = Value::Array(tag_ids);
    }
    v
}

fn differences(expected: &Value, actual: &Value) -> usize {
    expected
        .as_object()
        .map(|o| o.iter().filter(|(k, v)| actual[*k] != **v).count())
        .unwrap_or(1)
}
/// Minimum cost assignment (Hungarian), O(n^3), deterministic ascending ties.
/// A full match outweighs all field differences across the complete assignment.
pub fn pairing(expected: &[Value], actual: &[Value]) -> Vec<Option<usize>> {
    let n = expected.len().max(actual.len());
    if n == 0 {
        return vec![];
    }
    let full_weight = (n as i64 + 1) * 64;
    let cost = |i: usize, j: usize| -> i64 {
        if i >= expected.len() {
            return if j >= actual.len() {
                0
            } else {
                full_weight + 32
            };
        }
        if j >= actual.len() {
            return full_weight + 32;
        }
        let d = differences(&expected[i], &actual[j]);
        let target_wrong = expected[i]
            .get("id")
            .is_some_and(|id| actual[j]["id"] != *id);
        if target_wrong {
            full_weight * (n as i64 + 2)
        } else if d == 0 {
            0
        } else {
            full_weight + d as i64
        }
    };
    let (mut u, mut v, mut p, mut way) = (
        vec![0_i64; n + 1],
        vec![0_i64; n + 1],
        vec![0_usize; n + 1],
        vec![0_usize; n + 1],
    );
    for i in 1..=n {
        p[0] = i;
        let mut j0 = 0;
        let mut minv = vec![i64::MAX; n + 1];
        let mut used = vec![false; n + 1];
        loop {
            used[j0] = true;
            let i0 = p[j0];
            let mut delta = i64::MAX;
            let mut j1 = 0;
            for j in 1..=n {
                if !used[j] {
                    let cur = cost(i0 - 1, j - 1) - u[i0] - v[j];
                    if cur < minv[j] {
                        minv[j] = cur;
                        way[j] = j0;
                    }
                    if minv[j] < delta {
                        delta = minv[j];
                        j1 = j;
                    }
                }
            }
            for j in 0..=n {
                if used[j] {
                    u[p[j]] += delta;
                    v[j] -= delta;
                } else {
                    minv[j] -= delta;
                }
            }
            j0 = j1;
            if p[j0] == 0 {
                break;
            }
        }
        loop {
            let j1 = way[j0];
            p[j0] = p[j1];
            j0 = j1;
            if j0 == 0 {
                break;
            }
        }
    }
    let mut out = vec![None; expected.len()];
    for j in 1..=n {
        if p[j] > 0 && p[j] <= expected.len() && j <= actual.len() {
            out[p[j] - 1] = Some(j - 1);
        }
    }
    out
}
pub fn score(e: &Entry, ids: &Identities, o: &Observation) -> ResultRow {
    let baseline_events = o.baseline["events"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or(&[]);
    let baseline_max = baseline_events
        .iter()
        .filter_map(|e| e["id"].as_i64())
        .max()
        .unwrap_or(0);
    let events = o.final_state["events"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or(&[]);
    let changes: Vec<_> = events
        .iter()
        .filter(|e| e["id"].as_i64().unwrap_or(0) > baseline_max)
        .collect();
    let no_changes = changes.is_empty() && o.final_state == o.baseline;
    let actual: Vec<Value> = changes
        .iter()
        .filter(|e| e["entity_kind"] == "record")
        .map(|event| {
            let mut r = o.final_state["records"]
                .as_array()
                .and_then(|rows| rows.iter().find(|r| r["id"] == event["entity_id"]))
                .cloned()
                .unwrap_or_else(|| event["after"].clone());
            r["operation"] = event["kind"].clone();
            r["currency"] = o.final_state["currency"].clone();
            if let Some(tags) = r["tag_ids"].as_array_mut() {
                tags.sort_by_key(Value::to_string);
            }
            r
        })
        .collect();
    let expected: Vec<_> = e
        .expect
        .records
        .iter()
        .map(|r| expected_value(r, ids))
        .collect();
    let matches = pairing(&expected, &actual);
    let records_pass = actual.len() == expected.len()
        && changes.len() == actual.len()
        && expected
            .iter()
            .zip(&matches)
            .all(|(r, j)| j.is_some_and(|j| differences(r, &actual[j]) == 0));
    let completed = o.status == "completed";
    let confirmation_matches = e.expect.records.iter().all(|r| {
        let target = r.target.as_ref().and_then(|t| ids.records.get(t));
        target.is_some()
            && o.confirmation_calls.iter().any(|c| {
                c["tool"] == format!("{}_record", r.operation) && c["args"]["id"] == json!(target)
            })
    });
    let behavior_pass = match e.expect.behavior {
        Behavior::AskUser => o.status == "paused" && o.asked && !o.confirmation && no_changes,
        Behavior::NoWrite => completed && no_changes && !o.asked && !o.confirmation,
        Behavior::Write => completed && !no_changes && !o.asked && !o.confirmation,
        Behavior::ConfirmThenWrite => {
            completed
                && o.confirmation
                && confirmation_matches
                && o.confirmed
                && o.before_confirm == Some(true)
        }
    };
    let display = display_score(e, ids, o);
    let hard_pass = (!e.expect.hard
        || (behavior_pass && (e.expect.behavior != Behavior::ConfirmThenWrite || records_pass)))
        && (!display.hard || (behavior_pass && display.pass));
    let actual_behavior = if o.confirmation {
        "confirm_then_write"
    } else if o.asked {
        if no_changes {
            "ask_user"
        } else {
            "write_then_ask"
        }
    } else if !no_changes {
        "write"
    } else if completed {
        "no_write"
    } else {
        "failed"
    };
    let metric = |keys: &[&str]| {
        let mut count = Count::default();
        for (r, j) in expected.iter().zip(&matches) {
            let fields: Vec<_> = keys.iter().filter(|k| r.get(**k).is_some()).collect();
            if fields.is_empty() {
                continue;
            }
            count.total += 1;
            if j.is_some_and(|j| fields.iter().all(|k| r[**k] == actual[j][**k])) {
                count.correct += 1;
            }
        }
        // Missing records are in the expected denominator; extra writes cannot
        // disappear simply because no expected field was declared for them.
        count.total += actual.len().saturating_sub(expected.len());
        count
    };
    let costs: Option<Vec<f64>> = o
        .calls
        .iter()
        .map(|c| c["cost_usd"].as_str()?.parse().ok())
        .collect();
    let cost_usd = if o.calls.is_empty() {
        None
    } else {
        costs.map(|v| v.iter().sum())
    };
    let mut reasons = Vec::new();
    if !behavior_pass {
        reasons.push("behavior_mismatch".into());
    }
    if !records_pass {
        reasons.push("record_mismatch".into());
    }
    if o.tool_total != o.tool_valid
        && e.expect
            .display
            .as_ref()
            .is_none_or(|display| {
                display
                    .alternatives
                    .iter()
                    .all(|alternative| alternative.expected_invalid_calls == 0)
            })
    {
        reasons.push("invalid_tool_arguments".into());
    }
    reasons.extend(display.reasons.clone());
    ResultRow {
        id: e.id.clone(),
        category: e.category.clone(),
        locale: e.locale.clone(),
        tier: e.tier.as_str().into(),
        expected_behavior: e.expect.behavior.as_str().into(),
        actual_behavior: actual_behavior.into(),
        status: o.status.clone(),
        hard: e.expect.hard || display.hard,
        hard_pass,
        behavior_pass,
        records_pass,
        display_hard: display.hard,
        display_pass: display.pass,
        display_tools: display.tools,
        display_queries: display.queries,
        display_query_not_assessable: display.query_not_assessable,
        display_arguments: display.arguments,
        display_expected: display.expected,
        display_actual: display.actual,
        display_acceptable: display.acceptable,
        display_selected: display.selected,
        display_query_summary: display.query_summary,
        display_audit_complete: display.audit_complete,
        display_audit_discarded: display.audit_discarded,
        display_blocks: display.blocks,
        display_values: display.values,
        prose_pass: display.prose_pass,
        before_confirm: o.before_confirm,
        amount: metric(&["amount_minor", "currency"]),
        date: metric(&["occurred_on"]),
        category_accuracy: metric(&["tag_ids"]),
        tools: Count {
            correct: o.tool_valid,
            total: o.tool_total,
        },
        business_errors: o.business_errors,
        expected_question: e.expect.behavior == Behavior::AskUser,
        actual_question: o.asked,
        elapsed_ms: o.elapsed_ms,
        calls: o.calls.clone(),
        cost_usd,
        reasons,
    }
}
pub fn exit_code(rows: &[ResultRow]) -> u8 {
    if rows.iter().any(|r| !r.hard_pass) {
        1
    } else {
        0
    }
}
pub fn percentile(values: &[u64], percent: usize) -> Option<u64> {
    if values.is_empty() {
        return None;
    }
    let mut v = values.to_vec();
    v.sort_unstable();
    Some(
        v[(v.len() * percent)
            .div_ceil(100)
            .saturating_sub(1)
            .min(v.len() - 1)],
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_summary_truncates_utf8_strings_with_discarded_count() {
        let query = CanonicalQuery {
            value: json!({"family":"界".repeat(22)}),
            text: None,
        };
        let summary = query.summary();
        let family = summary["family"].as_str().unwrap();
        assert_eq!(family.len(), 63);
        assert_eq!(family.chars().count(), 21);
        assert_eq!(summary["truncated"], true);
        assert_eq!(summary["discarded"], 3);
    }
}
