use ai_eval::{
    dataset::{self, Entry},
    fixture::{Providers, Scenario},
    judge::Judge,
    report, scoring,
    scoring::ResultRow,
};
use anyhow::{Context, Result};
use clap::{Parser, ValueEnum};
use std::{
    collections::BTreeSet,
    path::{Path, PathBuf},
    process::ExitCode,
    sync::Arc,
};
#[derive(Clone, Copy, ValueEnum)]
enum Provider {
    Mock,
    Live,
}
#[derive(Parser)]
#[command(about = "Evaluate synthetic entries through the complete Agent loop")]
struct Args {
    #[arg(long, value_enum, default_value = "mock")]
    provider: Provider,
    /// Live credentials/configuration source; never used for evaluation writes.
    #[arg(long)]
    database_url: Option<String>,
    /// Disposable PostgreSQL 18 cluster. Defaults to EVAL_DATABASE_URL; mock also accepts DATABASE_URL.
    #[arg(long)]
    scratch_database_url: Option<String>,
    #[arg(long)]
    out: PathBuf,
    #[arg(long)]
    dataset: Option<PathBuf>,
    /// Run only entries in this category after loading and validating the complete corpus.
    #[arg(long)]
    category: Option<String>,
    /// Exact comma-separated IDs, selected after full corpus validation and category filtering.
    #[arg(long)]
    case_ids: Option<String>,
    /// Exact enabled model name or model UUID used for the live display Judge.
    #[arg(long)]
    judge_model: Option<String>,
    /// Maximum simultaneous cases; calibration finishes before cases are admitted.
    #[arg(long, default_value_t = 2, value_parser = clap::value_parser!(u8).range(1..=2))]
    jobs: u8,
    /// Private directory for allowlisted synthetic output/input/vote evidence.
    #[arg(long)]
    evidence_dir: Option<PathBuf>,
}
fn filter_entries(entries: Vec<Entry>, category: Option<&str>) -> Result<Vec<Entry>> {
    let Some(category) = category else {
        return Ok(entries);
    };
    let filtered = entries
        .into_iter()
        .filter(|entry| entry.category == category)
        .collect::<Vec<_>>();
    anyhow::ensure!(!filtered.is_empty(), "category matched no entries");
    Ok(filtered)
}
fn filter_case_ids(entries: Vec<Entry>, requested: Option<&str>) -> Result<Vec<Entry>> {
    let Some(requested) = requested else {
        return Ok(entries);
    };
    let mut ids = BTreeSet::new();
    for id in requested.split(',').map(str::trim) {
        anyhow::ensure!(!id.is_empty(), "case IDs must not be empty");
        anyhow::ensure!(ids.insert(id), "case IDs must not repeat");
    }
    anyhow::ensure!(
        ids.iter()
            .all(|id| entries.iter().any(|entry| entry.id == *id)),
        "case ID is unknown or excluded by category"
    );
    Ok(entries
        .into_iter()
        .filter(|entry| ids.contains(entry.id.as_str()))
        .collect())
}
async fn run(args: Args) -> Result<u8> {
    let root = args.dataset.unwrap_or_else(ai_eval::dataset_root);
    let entries = filter_entries(dataset::load(&root)?, args.category.as_deref())?;
    let entries = filter_case_ids(entries, args.case_ids.as_deref())?;
    let mock = matches!(args.provider, Provider::Mock);
    let expected_ids = entries
        .iter()
        .map(|entry| entry.id.clone())
        .collect::<Vec<_>>();
    let display_ids = entries
        .iter()
        .filter(|entry| entry.category == "display")
        .map(|entry| entry.id.clone())
        .collect::<Vec<_>>();
    let mixed = !display_ids.is_empty() && display_ids.len() != expected_ids.len();
    publish_reports(&args.out, &[], &display_ids, mixed, mock, false, false)?;
    let setup = async {
        let scratch = args
            .scratch_database_url
            .or_else(|| std::env::var("EVAL_DATABASE_URL").ok())
            .or_else(|| {
                if matches!(args.provider, Provider::Mock) {
                    std::env::var("DATABASE_URL").ok()
                } else {
                    None
                }
            })
            .context("scratch database required")?;
        let providers = match args.provider {
            Provider::Mock => None,
            Provider::Live => {
                #[cfg(feature = "live")]
                {
                    let source = args
                        .database_url
                        .or_else(|| std::env::var("DATABASE_URL").ok())
                        .context("live database required")?;
                    anyhow::ensure!(source != scratch, "source and scratch must differ");
                    Some(ai_eval::live::load(&source).await?)
                }
                #[cfg(not(feature = "live"))]
                {
                    let _ = args.database_url;
                    anyhow::bail!("live feature required");
                }
            }
        };
        let judge = if matches!(args.provider, Provider::Live) {
            let requested = args
                .judge_model
                .as_deref()
                .context("--judge-model is required for live evaluation")?;
            let judge = ai_eval::judge::Judge::select(
                providers.as_ref().context("live providers missing")?,
                requested,
            )?;
            if let Err(error) = judge.calibrate().await {
                eprintln!(
                    "judge_calibration_infrastructure_error stage=judge-calibration class={}",
                    ai_eval::diagnostic::class(&error)
                );
                return Err(error);
            }
            Some(judge)
        } else {
            None
        };
        anyhow::Ok((scratch, providers, judge))
    }
    .await;
    let (scratch, providers, judge) = finish_setup(setup, &args.out, &display_ids, mixed, mock)?;
    let evidence_dir = args
        .evidence_dir
        .unwrap_or_else(|| args.out.join("evidence"));
    let context = Arc::new(EvaluationContext {
        root,
        scratch,
        providers,
        judge,
        mock,
        evidence_dir,
    });
    let batch = ai_eval::batch::run(
        entries,
        usize::from(args.jobs),
        move |entry| evaluate_case(entry, context.clone()),
        |rows| publish_reports(&args.out, rows, &display_ids, mixed, mock, false, false),
    )
    .await?;
    let incomplete = batch.infrastructure_failed
        || batch.rows.len() != expected_ids.len()
        || (!mock
            && batch
                .rows
                .iter()
                .any(|row| row.category == "display" && row.expectation_met.is_none()));
    publish_reports(
        &args.out,
        &batch.rows,
        &display_ids,
        mixed,
        mock,
        true,
        incomplete,
    )?;
    Ok(if incomplete {
        2
    } else if mock {
        u8::from(
            batch
                .rows
                .iter()
                .any(|row| row.rule_decision == scoring::RuleDecision::Fail),
        )
    } else {
        scoring::exit_code(&batch.rows)
    })
}

/// Finalize the report even when provider loading or Judge setup fails before case admission.
fn finish_setup<T>(
    result: Result<T>,
    out: &Path,
    display_ids: &[String],
    mixed: bool,
    mock: bool,
) -> Result<T> {
    if result.is_err() {
        publish_reports(out, &[], display_ids, mixed, mock, true, true)?;
    }
    result
}

/// Keep display assessment separate from the legacy record-writing corpus report.
fn publish_reports(
    out: &Path,
    rows: &[ResultRow],
    display_ids: &[String],
    mixed: bool,
    mock: bool,
    finished: bool,
    infrastructure_failed: bool,
) -> Result<()> {
    if display_ids.is_empty() {
        return report::write(out, rows);
    }
    if mixed {
        let legacy = rows
            .iter()
            .filter(|row| row.category != "display")
            .cloned()
            .collect::<Vec<_>>();
        report::write(out, &legacy)?;
    }
    let display_rows = rows
        .iter()
        .filter(|row| row.category == "display")
        .cloned()
        .collect::<Vec<_>>();
    let display_out = if mixed {
        out.join("display-expectations")
    } else {
        out.to_path_buf()
    };
    report::write_expectations(
        &display_out,
        &display_rows,
        display_ids,
        mock,
        finished,
        infrastructure_failed,
    )
}

struct EvaluationContext {
    root: PathBuf,
    scratch: String,
    providers: Option<Providers>,
    judge: Option<Judge>,
    mock: bool,
    evidence_dir: PathBuf,
}

async fn evaluate_case(e: Entry, context: Arc<EvaluationContext>) -> Result<ResultRow> {
    let mut stage = "fixture-init";
    let result = async {
        let scenario = Scenario::new(
            &e,
            &context.root,
            &context.scratch,
            context.providers.as_ref(),
            None,
        )
        .await?;
        stage = "actor-evaluate";
        let (mut row, input) = scenario.evaluate_with_capture(&e, Some(&context.evidence_dir)).await?;
        if ai_eval::judge::should_judge(context.judge.is_some(), &e, &row) {
            stage = "judge-request";
            let judge = context.judge.as_ref().context("judge missing")?;
            let input = input.as_ref().context("display judge input missing")?;
            ai_eval::evidence::write(&context.evidence_dir, &e.id, "judge-input", &serde_json::to_value(input)?)?;
            let outcome = judge.evaluate_recording(input, judge.is_self_judge(&row), |index, vote| {
                ai_eval::evidence::write(&context.evidence_dir, &e.id, &format!("judge-vote-{}", index + 1), &serde_json::to_value(vote)?)
            }).await?;
            stage = "judge-apply";
            ai_eval::judge::apply(&mut row, outcome)?;
        }
        if !context.mock && row.category == "display" && row.expectation_met.is_none() {
            anyhow::bail!("required expectation judgment missing");
        }
        ai_eval::evidence::write(&context.evidence_dir, &e.id, "result", &serde_json::json!({"assessment_version":report::EXPECTATION_VERSION,"case_id":e.id,"mode":if context.mock {"mock_pipeline"} else {"live"},"rule_decision":row.rule_decision,"expectation_met":if context.mock {None}else{row.expectation_met},"judgment_source":if context.mock {"not_judged_mock"}else{row.judgment_source.as_str()},"judge_model":row.judge_model,"judge_self":row.judge_self,"judge_true_votes":row.judge_pass_votes,"judge_false_votes":row.judge_fail_votes,"votes":if row.judge_votes.is_empty(){serde_json::Value::Null}else{serde_json::from_str::<serde_json::Value>(&row.judge_votes)?}}))?;
        anyhow::Ok(row)
    }
    .await;
    match result {
        Ok(row) => {
            if !row.hard_pass {
                eprintln!(
                    "{}: hard_standard_failed ({})",
                    row.id,
                    row.reasons.join(";")
                );
            } else if !context.mock && row.expectation_met == Some(false) {
                eprintln!(
                    "{}: expectation_not_met source={}",
                    row.id, row.judgment_source
                );
            }
            Ok(row)
        }
        Err(error) => {
            eprintln!(
                "{}: infrastructure_error stage={} class={}",
                e.id,
                ai_eval::diagnostic::stage(&error, stage),
                ai_eval::diagnostic::class(&error)
            );
            Err(error)
        }
    }
}

#[tokio::main]
async fn main() -> ExitCode {
    match run(Args::parse()).await {
        Ok(code) => ExitCode::from(code),
        Err(_) => {
            eprintln!("evaluation_configuration_or_data_error; see eval/README.md");
            ExitCode::from(2)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn calibration_failure_replaces_pending_display_report_with_unfinished() -> Result<()> {
        let out =
            std::env::temp_dir().join(format!("jiabu-calibration-report-{}", uuid::Uuid::now_v7()));
        let ids = vec!["display-001".into(), "display-002".into()];
        publish_reports(&out, &[], &ids, false, false, false, false)?;
        assert!(std::fs::read_to_string(out.join("results.csv"))?.contains("pending"));
        publish_reports(&out, &[], &ids, false, false, true, true)?;
        let results = std::fs::read_to_string(out.join("results.csv"))?;
        assert!(!results.contains("pending"));
        assert_eq!(results.matches("unfinished_infrastructure").count(), 2);
        Ok(())
    }

    #[test]
    fn startup_failure_finalizes_all_expected_display_cases() -> Result<()> {
        let out = std::env::temp_dir().join(format!("jiabu-setup-report-{}", uuid::Uuid::now_v7()));
        let ids = vec!["display-001".into(), "display-002".into()];
        publish_reports(&out, &[], &ids, false, false, false, false)?;
        let error = finish_setup::<()>(
            Err(anyhow::anyhow!("synthetic setup failure")),
            &out,
            &ids,
            false,
            false,
        );
        assert!(error.is_err());
        let results = std::fs::read_to_string(out.join("results.csv"))?;
        assert!(!results.contains("pending"));
        assert_eq!(results.matches("unfinished_infrastructure").count(), 2);
        Ok(())
    }

    #[test]
    fn mixed_corpus_has_a_separate_binary_display_report() -> Result<()> {
        let out = std::env::temp_dir().join(format!("jiabu-mixed-report-{}", uuid::Uuid::now_v7()));
        publish_reports(&out, &[], &["display-001".into()], true, false, true, true)?;
        let legacy = std::fs::read_to_string(out.join("results.csv"))?;
        let display = std::fs::read_to_string(out.join("display-expectations/results.csv"))?;
        assert!(!legacy.contains("display-001"));
        assert!(display.contains("display-001"));
        assert!(display.contains("expectation_met"));
        assert!(!display.contains("display_prose_pass"));
        Ok(())
    }

    #[test]
    fn jobs_default_to_two_and_only_accept_one_or_two() -> Result<()> {
        assert_eq!(
            Args::try_parse_from(["ai-eval", "--out", "unused"])?.jobs,
            2
        );
        for value in ["1", "2"] {
            assert!(Args::try_parse_from(["ai-eval", "--out", "unused", "--jobs", value]).is_ok());
        }
        for value in ["0", "3"] {
            assert!(Args::try_parse_from(["ai-eval", "--out", "unused", "--jobs", value]).is_err());
        }
        Ok(())
    }

    #[test]
    fn case_ids_select_exact_cases_in_corpus_order_after_category() -> Result<()> {
        let args = Args::try_parse_from([
            "ai-eval",
            "--out",
            "unused",
            "--category",
            "display",
            "--case-ids",
            "display-020, display-014",
        ])?;
        let entries = dataset::load(&ai_eval::dataset_root())?;
        let category = filter_entries(entries, args.category.as_deref())?;
        let selected = filter_case_ids(category.clone(), args.case_ids.as_deref())?;
        assert_eq!(
            selected
                .iter()
                .map(|entry| entry.id.as_str())
                .collect::<Vec<_>>(),
            ["display-014", "display-020"]
        );
        assert_eq!(filter_case_ids(category.clone(), None)?.len(), 20);
        for invalid in [
            "",
            ",",
            "display-014,",
            "display-014,,display-020",
            "display-014,display-014",
            "display-014, display-014",
            "unknown",
            "display-014,unknown",
            "zh-ambiguous-001",
        ] {
            assert!(
                filter_case_ids(category.clone(), Some(invalid)).is_err(),
                "{invalid}"
            );
        }
        Ok(())
    }

    #[test]
    fn category_argument_filters_the_validated_corpus_and_must_match() -> Result<()> {
        let args = Args::try_parse_from(["ai-eval", "--out", "unused", "--category", "display"])?;
        let entries = dataset::load(&ai_eval::dataset_root())?;
        let filtered = filter_entries(entries.clone(), args.category.as_deref())?;
        assert_eq!(filtered.len(), 20);
        assert!(filtered.iter().all(|entry| entry.category == "display"));
        assert!(filter_entries(entries, Some("not-a-category")).is_err());
        Ok(())
    }
}
