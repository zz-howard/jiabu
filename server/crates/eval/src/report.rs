use crate::scoring::{Count, Questions, ResultRow, percentile};
use anyhow::Result;
use std::{io::Write, path::Path};
/// RFC 4180; always quote cells to preserve empty fields and embedded JSON.
pub fn csv_row(cells: &[String]) -> String {
    format!(
        "{}\r\n",
        cells
            .iter()
            .map(|s| format!("\"{}\"", s.replace('"', "\"\"")))
            .collect::<Vec<_>>()
            .join(",")
    )
}
fn opt<T: ToString>(v: Option<T>) -> String {
    v.map(|v| v.to_string()).unwrap_or_default()
}
pub fn write(out: &Path, rows: &[ResultRow]) -> Result<()> {
    std::fs::create_dir_all(out)?;
    let mut file = std::fs::File::create(out.join("results.csv"))?;
    file.write_all(
        csv_row(
            &[
                "id",
                "category",
                "locale",
                "expected_behavior",
                "actual_behavior",
                "hard",
                "hard_pass",
                "status",
                "behavior_pass",
                "records_pass",
                "before_confirm_no_write",
                "amount_correct",
                "amount_total",
                "amount_accuracy",
                "date_correct",
                "date_total",
                "date_accuracy",
                "category_correct",
                "category_total",
                "category_accuracy",
                "tool_valid",
                "tool_total",
                "tool_validity",
                "business_errors",
                "latency_ms",
                "calls_json",
                "cost_usd",
                "failure_reasons",
            ]
            .map(str::to_owned),
        )
        .as_bytes(),
    )?;
    for r in rows {
        file.write_all(
            csv_row(&[
                r.id.clone(),
                r.category.clone(),
                r.locale.clone(),
                r.expected_behavior.clone(),
                r.actual_behavior.clone(),
                r.hard.to_string(),
                r.hard_pass.to_string(),
                r.status.clone(),
                r.behavior_pass.to_string(),
                r.records_pass.to_string(),
                opt(r.before_confirm),
                r.amount.correct.to_string(),
                r.amount.total.to_string(),
                opt(r.amount.rate()),
                r.date.correct.to_string(),
                r.date.total.to_string(),
                opt(r.date.rate()),
                r.category_accuracy.correct.to_string(),
                r.category_accuracy.total.to_string(),
                opt(r.category_accuracy.rate()),
                r.tools.correct.to_string(),
                r.tools.total.to_string(),
                opt(r.tools.rate()),
                r.business_errors.to_string(),
                r.elapsed_ms.to_string(),
                serde_json::to_string(&r.calls)?,
                opt(r.cost_usd),
                r.reasons.join(";"),
            ])
            .as_bytes(),
        )?;
    }
    let mut file = std::fs::File::create(out.join("summary.csv"))?;
    file.write_all(
        csv_row(&["metric", "value", "numerator", "denominator"].map(str::to_owned)).as_bytes(),
    )?;
    let (mut amount, mut date, mut category, mut tools) = (
        Count::default(),
        Count::default(),
        Count::default(),
        Count::default(),
    );
    let (mut questions, mut ambiguous) = (Questions::default(), Questions::default());
    for r in rows {
        amount.add(&r.amount);
        date.add(&r.date);
        category.add(&r.category_accuracy);
        tools.add(&r.tools);
        questions.add(r.expected_question, r.actual_question);
        if r.category == "ambiguous_date" {
            ambiguous.add(true, r.actual_question);
        }
    }
    for (name, count) in [
        ("tool_argument_validity", tools),
        ("amount_precision", amount),
        ("date_accuracy", date),
        ("category_accuracy", category),
        ("question_precision", questions.precision()),
        ("question_recall", questions.recall()),
        ("ambiguous_date_recall", ambiguous.recall()),
    ] {
        file.write_all(
            csv_row(&[
                name.into(),
                opt(count.rate()),
                count.correct.to_string(),
                count.total.to_string(),
            ])
            .as_bytes(),
        )?;
    }
    let latency: Vec<_> = rows.iter().map(|r| r.elapsed_ms).collect();
    let known: Vec<_> = rows.iter().filter_map(|r| r.cost_usd).collect();
    // A suite mean is unknown if any entry has unknown usage or tariff.
    let mean = if !rows.is_empty() && known.len() == rows.len() {
        Some(known.iter().sum::<f64>() / rows.len() as f64)
    } else {
        None
    };
    for (name, value) in [
        ("latency_p50_ms", opt(percentile(&latency, 50))),
        ("latency_p95_ms", opt(percentile(&latency, 95))),
        ("mean_cost_usd", opt(mean)),
        ("unknown_cost_count", (rows.len() - known.len()).to_string()),
        (
            "hard_failure_count",
            rows.iter().filter(|r| !r.hard_pass).count().to_string(),
        ),
        ("entries", rows.len().to_string()),
        ("question_tp", questions.tp.to_string()),
        ("question_fp", questions.fp.to_string()),
        ("question_fn", questions.fn_.to_string()),
    ] {
        file.write_all(csv_row(&[name.into(), value, String::new(), String::new()]).as_bytes())?;
    }
    Ok(())
}
