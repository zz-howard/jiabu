use ai_eval::{
    dataset::{self, Entry},
    fixture::{Providers, Scenario},
    judge::Judge,
    report, scoring,
    scoring::ResultRow,
};
use anyhow::{Context, Result};
use clap::{Parser, ValueEnum};
use std::{path::PathBuf, process::ExitCode, sync::Arc};
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
    /// Exact enabled model name or model UUID used for the live display Judge.
    #[arg(long)]
    judge_model: Option<String>,
    /// Maximum simultaneous cases; calibration finishes before cases are admitted.
    #[arg(long, default_value_t = 2, value_parser = clap::value_parser!(u8).range(1..=2))]
    jobs: u8,
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
async fn run(args: Args) -> Result<u8> {
    let root = args.dataset.unwrap_or_else(ai_eval::dataset_root);
    let entries = filter_entries(dataset::load(&root)?, args.category.as_deref())?;
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
            return Ok(2);
        }
        Some(judge)
    } else {
        None
    };
    let context = Arc::new(EvaluationContext {
        root,
        scratch,
        providers,
        judge,
    });
    let batch = ai_eval::batch::run(
        entries,
        usize::from(args.jobs),
        move |entry| evaluate_case(entry, context.clone()),
        |rows| report::write(&args.out, rows),
    )
    .await?;
    Ok(if batch.infrastructure_failed {
        2
    } else {
        scoring::exit_code(&batch.rows)
    })
}

struct EvaluationContext {
    root: PathBuf,
    scratch: String,
    providers: Option<Providers>,
    judge: Option<Judge>,
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
        let (mut row, input) = scenario.evaluate_with_judge_input(&e).await?;
        if ai_eval::judge::should_judge(context.judge.is_some(), &e, &row) {
            stage = "judge-request";
            let judge = context.judge.as_ref().context("judge missing")?;
            let input = input.as_ref().context("display judge input missing")?;
            let outcome = judge.evaluate(input, judge.is_self_judge(&row)).await?;
            stage = "judge-apply";
            ai_eval::judge::apply(&mut row, outcome)?;
        }
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
            } else if !row.overall_pass() {
                eprintln!("{}: display_judge_failed", row.id);
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

#[cfg(test)]
mod tests {
    use super::*;

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
