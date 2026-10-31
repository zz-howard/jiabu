use crate::{
    dataset::{Behavior, Entry, RecordSpec},
    mock::Identities,
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
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
    blocks: Count,
    values: Count,
    prose_pass: bool,
    reasons: Vec<String>,
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
fn display_score(e: &Entry, ids: &Identities, o: &Observation) -> DisplayScore {
    let Some(expect) = &e.expect.display else {
        return DisplayScore {
            pass: true,
            prose_pass: true,
            ..Default::default()
        };
    };
    let actual_calls: Vec<_> = o
        .tool_calls
        .iter()
        .filter(|call| {
            call["tool"].as_str().is_some_and(|tool| {
                tool.starts_with("show_") || matches!(tool, "query_stats" | "search_records")
            })
        })
        .collect();
    let mut call_aliases = std::collections::BTreeMap::new();
    for (index, _) in expect.source_calls.iter().enumerate() {
        if let Some(call_id) = actual_calls
            .get(index)
            .and_then(|call| call["call_id"].as_str())
        {
            call_aliases.insert(format!("$call:source-{index}"), call_id.to_owned());
        }
    }
    let expected_calls = expect
        .source_calls
        .iter()
        .chain(&expect.calls)
        .map(|call| {
            ids.display_args_with_calls(&call.args, &call_aliases)
                .map(|args| json!({"tool":call.tool,"args":args}))
        })
        .collect::<anyhow::Result<Vec<_>>>()
        .unwrap_or_default();
    let actual_calls: Vec<_> = actual_calls
        .iter()
        .map(|call| json!({"tool":call["tool"],"args":call["args"]}))
        .collect();
    let mut result = DisplayScore {
        hard: expect.hard,
        tools: Count {
            correct: usize::from(actual_calls == expected_calls),
            total: 1,
        },
        prose_pass: true,
        ..Default::default()
    };
    let blocks = o.message["blocks"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or(&[]);
    let actual: Vec<_> = blocks
        .iter()
        .filter(|block| block["type"] != "markdown")
        .collect();
    result.blocks.total = expect.blocks.len().max(actual.len());
    for (index, expected) in expect.blocks.iter().enumerate() {
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
    for required in &expect.fallback_contains {
        result.values.total += 1;
        result.values.correct += usize::from(fallback.contains(required));
    }
    let server_fallback = o.server_fallbacks.join("\n");
    for required in &expect.server_fallback_contains {
        result.values.total += 1;
        result.values.correct += usize::from(server_fallback.contains(required));
    }
    let prose = blocks
        .iter()
        .filter(|block| block["type"] == "markdown")
        .filter_map(|block| block["fallbackText"].as_str())
        .collect::<Vec<_>>()
        .join("\n");
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
        let repeated = expect
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
        result.reasons.push("display_tool_mismatch".into());
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
    if o.tool_total.saturating_sub(o.tool_valid) != expect.expected_invalid_calls {
        result.reasons.push("display_invalid_call_mismatch".into());
    }
    if o.business_errors != expect.expected_business_errors {
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
            .is_none_or(|display| display.expected_invalid_calls == 0)
    {
        reasons.push("invalid_tool_arguments".into());
    }
    reasons.extend(display.reasons.clone());
    ResultRow {
        id: e.id.clone(),
        category: e.category.clone(),
        locale: e.locale.clone(),
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
