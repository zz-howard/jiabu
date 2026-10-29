use ai_eval::{dataset, fixture::Scenario, report, scoring};
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
}
async fn run(args: Args) -> Result<u8> {
    let root = args.dataset.unwrap_or_else(ai_eval::dataset_root);
    let entries = dataset::load(&root)?;
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
    let mut rows = Vec::new();
    for e in entries {
        let result = async {
            let scenario = Scenario::new(&e, &root, &scratch, providers.as_ref(), None).await?;
            scenario.evaluate(&e).await
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
