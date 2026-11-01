use ai_eval::{
    dataset::{self, Entry},
    fixture::Scenario,
    report, scoring,
};
use anyhow::{Context, Result};
use clap::{Parser, ValueEnum};
use std::{path::PathBuf, process::ExitCode};
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
        if judge.calibrate().await.is_err() {
            eprintln!("judge_calibration_infrastructure_error");
            return Ok(2);
        }
        Some(judge)
    } else {
        None
    };
    let mut rows = Vec::new();
    for e in entries {
        let result = async {
            let scenario = Scenario::new(&e, &root, &scratch, providers.as_ref(), None).await?;
            let (mut row, input) = scenario.evaluate_with_judge_input(&e).await?;
            if ai_eval::judge::should_judge(judge.is_some(), &e, &row) {
                let judge = judge.as_ref().context("judge missing")?;
                let input = input.as_ref().context("display judge input missing")?;
                let outcome = judge.evaluate(input, judge.is_self_judge(&row)).await?;
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
                }
                rows.push(row);
                report::write(&args.out, &rows)?;
            }
            Err(_) => {
                // Never format DB/transport errors: these may include a URL or content.
                eprintln!("{}: infrastructure_error", e.id);
                return Ok(2);
            }
        }
    }
    Ok(scoring::exit_code(&rows))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn category_argument_filters_the_validated_corpus_and_must_match() -> Result<()> {
        let args = Args::try_parse_from([
            "ai-eval",
            "--out",
            "unused",
            "--category",
            "display",
        ])?;
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
