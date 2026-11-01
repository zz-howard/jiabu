use crate::scoring::{Count, Questions, ResultRow, percentile};
use anyhow::Result;
use std::{collections::BTreeSet, fs::File, io::Write, path::Path};
pub const RESULTS_HEADER: &[&str] = &[
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
    "display_hard",
    "display_pass",
    "display_tool_correct",
    "display_tool_total",
    "display_block_correct",
    "display_block_total",
    "display_value_correct",
    "display_value_total",
    "display_prose_pass",
    "tier",
    "display_expected_selection",
    "display_actual_selection",
    "display_acceptable_alternatives",
    "display_selected_alternative",
    "display_query_summary",
    "display_query_correct",
    "display_query_total",
    "display_query_not_assessable",
    "display_argument_valid",
    "display_argument_total",
    "display_audit_complete",
    "display_audit_discarded",
    "judge_model",
    "judge_self",
    "judge_pass_votes",
    "judge_fail_votes",
    "judge_votes_json",
];
/// RFC 4180; always quote cells to preserve empty fields and embedded JSON.
pub fn csv_row(cells: &[String]) -> String {
    format!(
        "{}\n",
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
            &RESULTS_HEADER
                .iter()
                .map(|value| (*value).to_owned())
                .collect::<Vec<_>>(),
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
                r.display_hard.to_string(),
                r.display_pass.to_string(),
                r.display_tools.correct.to_string(),
                r.display_tools.total.to_string(),
                r.display_blocks.correct.to_string(),
                r.display_blocks.total.to_string(),
                r.display_values.correct.to_string(),
                r.display_values.total.to_string(),
                r.prose_pass.to_string(),
                r.tier.clone(),
                r.display_expected.clone(),
                r.display_actual.clone(),
                r.display_acceptable.clone(),
                r.display_selected.clone(),
                r.display_query_summary.clone(),
                r.display_queries.correct.to_string(),
                r.display_queries.total.to_string(),
                r.display_query_not_assessable.to_string(),
                r.display_arguments.correct.to_string(),
                r.display_arguments.total.to_string(),
                r.display_audit_complete.to_string(),
                r.display_audit_discarded.to_string(),
                r.judge_model.clone(),
                opt(r.judge_self),
                opt(r.judge_pass_votes),
                opt(r.judge_fail_votes),
                r.judge_votes.clone(),
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
    let (
        mut display_tools,
        mut display_queries,
        mut display_arguments,
        mut display_blocks,
        mut display_values,
    ) = (
        Count::default(),
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
        display_tools.add(&r.display_tools);
        display_queries.add(&r.display_queries);
        display_arguments.add(&r.display_arguments);
        display_blocks.add(&r.display_blocks);
        display_values.add(&r.display_values);
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
        ("display_tool_accuracy", display_tools),
        ("display_query_accuracy", display_queries),
        ("display_argument_validity", display_arguments),
        ("display_block_accuracy", display_blocks),
        ("display_value_accuracy", display_values),
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
    for tier in ["core", "integration", "stress"] {
        let selected: Vec<_> = rows.iter().filter(|row| row.tier == tier).collect();
        let mut selection = Count::default();
        let mut query = Count::default();
        let mut arguments = Count::default();
        for row in &selected {
            selection.add(&row.display_tools);
            query.add(&row.display_queries);
            arguments.add(&row.display_arguments);
        }
        for (name, count) in [
            ("display_selection", selection),
            ("display_query", query),
            ("display_argument", arguments),
        ] {
            file.write_all(
                csv_row(&[
                    format!("tier.{tier}.{name}"),
                    opt(count.rate()),
                    count.correct.to_string(),
                    count.total.to_string(),
                ])
                .as_bytes(),
            )?;
        }
        let passed = selected.iter().filter(|row| row.hard_pass).count();
        file.write_all(
            csv_row(&[
                format!("tier.{tier}.hard_pass"),
                opt((!selected.is_empty()).then_some(passed as f64 / selected.len() as f64)),
                passed.to_string(),
                selected.len().to_string(),
            ])
            .as_bytes(),
        )?;
        let not_assessable: usize = selected
            .iter()
            .map(|row| row.display_query_not_assessable)
            .sum();
        file.write_all(
            csv_row(&[
                format!("tier.{tier}.display_query_not_assessable"),
                not_assessable.to_string(),
                String::new(),
                String::new(),
            ])
            .as_bytes(),
        )?;
    }
    let judged = rows
        .iter()
        .filter(|row| row.tier == "core" && row.judge_self.is_some())
        .collect::<Vec<_>>();
    let judge_passed = judged
        .iter()
        .filter(|row| row.judge_pass_votes.is_some_and(|votes| votes >= 2))
        .count();
    let judge_pass_votes = judged
        .iter()
        .filter_map(|row| row.judge_pass_votes)
        .sum::<usize>();
    let judge_fail_votes = judged
        .iter()
        .filter_map(|row| row.judge_fail_votes)
        .sum::<usize>();
    let judge_self_count = judged
        .iter()
        .filter(|row| row.judge_self == Some(true))
        .count();
    let judge_models = judged
        .iter()
        .map(|row| row.judge_model.clone())
        .collect::<BTreeSet<_>>();
    let tested_models = rows
        .iter()
        .flat_map(|row| row.tested_models.iter().cloned())
        .collect::<BTreeSet<_>>();
    for (name, value, numerator, denominator) in [
        (
            "judge.core.pass_rate",
            opt((!judged.is_empty()).then_some(judge_passed as f64 / judged.len() as f64)),
            judge_passed.to_string(),
            judged.len().to_string(),
        ),
        (
            "judge.pass_votes",
            judge_pass_votes.to_string(),
            String::new(),
            String::new(),
        ),
        (
            "judge.fail_votes",
            judge_fail_votes.to_string(),
            String::new(),
            String::new(),
        ),
        (
            "judge.total_votes",
            (judge_pass_votes + judge_fail_votes).to_string(),
            String::new(),
            String::new(),
        ),
        (
            "judge.self_judge_count",
            judge_self_count.to_string(),
            String::new(),
            String::new(),
        ),
        (
            "judge.tested_models_json",
            serde_json::to_string(&tested_models)?,
            String::new(),
            String::new(),
        ),
        (
            "judge.ranking_models_json",
            serde_json::to_string(&judge_models)?,
            String::new(),
            String::new(),
        ),
    ] {
        file.write_all(csv_row(&[name.into(), value, numerator, denominator]).as_bytes())?;
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
        (
            "display_query_not_assessable",
            rows.iter()
                .map(|row| row.display_query_not_assessable)
                .sum::<usize>()
                .to_string(),
        ),
    ] {
        file.write_all(csv_row(&[name.into(), value, String::new(), String::new()]).as_bytes())?;
    }
    Ok(())
}

/// Binary expectation contract. Mock rows validate only the pipeline, never model effect.
pub const EXPECTATION_VERSION: &str = "expectation-v1";
pub fn write_expectations(
    out: &Path,
    rows: &[ResultRow],
    expected_ids: &[String],
    mock: bool,
    finished: bool,
    infrastructure_failed: bool,
) -> Result<()> {
    std::fs::create_dir_all(out)?;
    let mut file = File::create(out.join("results.csv"))?;
    file.write_all(
        csv_row(
            &[
                "id",
                "assessment_version",
                "mode",
                "execution_status",
                "expectation_met",
                "judgment_source",
                "rule_decision",
                "rule_reason_codes",
                "judge_model",
                "judge_self",
                "judge_true_votes",
                "judge_false_votes",
                "judge_votes_json",
            ]
            .map(str::to_owned),
        )
        .as_bytes(),
    )?;
    for id in expected_ids {
        let row = rows.iter().find(|row| row.id == *id);
        let execution = if row.is_some_and(|row| mock || row.expectation_met.is_some()) {
            if mock {
                "mock_pipeline_completed"
            } else {
                "completed"
            }
        } else if finished {
            "unfinished_infrastructure"
        } else {
            "pending"
        };
        let rule = row
            .map(|row| match row.rule_decision {
                crate::scoring::RuleDecision::Pass => "pass",
                crate::scoring::RuleDecision::Fail => "fail",
                crate::scoring::RuleDecision::NeedsJudge => "needs_judge",
            })
            .unwrap_or("");
        file.write_all(
            csv_row(&[
                id.clone(),
                EXPECTATION_VERSION.into(),
                if mock { "mock_pipeline" } else { "live" }.into(),
                execution.into(),
                if mock {
                    String::new()
                } else {
                    row.and_then(|r| r.expectation_met)
                        .map(|v| v.to_string())
                        .unwrap_or_default()
                },
                if mock {
                    "not_judged_mock".into()
                } else {
                    row.map(|r| r.judgment_source.clone()).unwrap_or_default()
                },
                rule.into(),
                row.map(|r| r.reasons.join(";")).unwrap_or_default(),
                row.map(|r| r.judge_model.clone()).unwrap_or_default(),
                row.and_then(|r| r.judge_self)
                    .map(|v| v.to_string())
                    .unwrap_or_default(),
                row.and_then(|r| r.judge_pass_votes)
                    .map(|v| v.to_string())
                    .unwrap_or_default(),
                row.and_then(|r| r.judge_fail_votes)
                    .map(|v| v.to_string())
                    .unwrap_or_default(),
                row.map(|r| r.judge_votes.clone()).unwrap_or_default(),
            ])
            .as_bytes(),
        )?;
    }
    let met = if mock {
        0
    } else {
        rows.iter()
            .filter(|r| r.expectation_met == Some(true))
            .count()
    };
    let not_met = if mock {
        0
    } else {
        rows.iter()
            .filter(|r| r.expectation_met == Some(false))
            .count()
    };
    let incomplete = if finished {
        expected_ids
            .len()
            .saturating_sub(if mock { rows.len() } else { met + not_met })
    } else {
        0
    };
    let infrastructure_failed = infrastructure_failed || incomplete > 0;
    let mut summary = File::create(out.join("summary.csv"))?;
    summary.write_all(csv_row(&["metric".into(), "value".into()]).as_bytes())?;
    for (metric, value) in [
        ("assessment_version", EXPECTATION_VERSION.to_owned()),
        ("mode", if mock { "mock_pipeline" } else { "live" }.into()),
        (
            "execution_status",
            if !finished {
                "running"
            } else if infrastructure_failed {
                "infrastructure_incomplete"
            } else {
                "completed"
            }
            .into(),
        ),
        ("expected_cases", expected_ids.len().to_string()),
        ("completed_cases", rows.len().to_string()),
        ("expectation_met", met.to_string()),
        ("expectation_not_met", not_met.to_string()),
        ("unfinished_infrastructure", incomplete.to_string()),
        (
            "rule_decisions",
            if mock {
                0
            } else {
                rows.iter().filter(|r| r.judgment_source == "rule").count()
            }
            .to_string(),
        ),
        (
            "judge_decisions",
            if mock {
                0
            } else {
                rows.iter().filter(|r| r.judgment_source == "judge").count()
            }
            .to_string(),
        ),
        (
            "needs_judge",
            rows.iter()
                .filter(|r| r.rule_decision == crate::scoring::RuleDecision::NeedsJudge)
                .count()
                .to_string(),
        ),
        (
            "mock_proven_rule_failures",
            if mock {
                rows.iter()
                    .filter(|r| r.rule_decision == crate::scoring::RuleDecision::Fail)
                    .count()
            } else {
                0
            }
            .to_string(),
        ),
        (
            "judge_valid_votes",
            rows.iter()
                .map(|r| r.judge_pass_votes.unwrap_or(0) + r.judge_fail_votes.unwrap_or(0))
                .sum::<usize>()
                .to_string(),
        ),
    ] {
        summary.write_all(csv_row(&[metric.into(), value]).as_bytes())?;
    }
    Ok(())
}

#[cfg(test)]
mod expectation_tests {
    use super::*;

    #[test]
    fn empty_finished_report_is_unfinished_infrastructure_with_no_quality_score() -> Result<()> {
        let out =
            std::env::temp_dir().join(format!("jiabu-expectation-report-{}", uuid::Uuid::now_v7()));
        write_expectations(
            &out,
            &[],
            &["display-001".into(), "display-002".into()],
            false,
            true,
            true,
        )?;
        let results = std::fs::read_to_string(out.join("results.csv"))?;
        let summary = std::fs::read_to_string(out.join("summary.csv"))?;
        assert_eq!(results.matches("unfinished_infrastructure").count(), 2);
        assert!(!results.contains("display_prose_pass"));
        assert!(!results.contains("overall_pass"));
        assert!(summary.contains("\"expectation_met\",\"0\""));
        assert!(summary.contains("\"expectation_not_met\",\"0\""));
        assert!(summary.contains("\"unfinished_infrastructure\",\"2\""));
        Ok(())
    }
}
