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
    if let Some(a) = &r.preset_key {
        v["tag_ids"] = json!([ids.tags.get(a)]);
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
    let hard_pass = !e.expect.hard
        || (behavior_pass && (e.expect.behavior != Behavior::ConfirmThenWrite || records_pass));
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
    if o.tool_total != o.tool_valid {
        reasons.push("invalid_tool_arguments".into());
    }
    ResultRow {
        id: e.id.clone(),
        category: e.category.clone(),
        locale: e.locale.clone(),
        expected_behavior: e.expect.behavior.as_str().into(),
        actual_behavior: actual_behavior.into(),
        status: o.status.clone(),
        hard: e.expect.hard,
        hard_pass,
        behavior_pass,
        records_pass,
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
