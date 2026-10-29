use ai_eval::{dataset, fixture::Scenario, report, scoring};
use anyhow::{Context, Result};
#[tokio::test]
async fn full_mock_suite_uses_real_pg_agent_worker_and_scores_one_hundred_percent() -> Result<()> {
    let root = ai_eval::dataset_root();
    let entries = dataset::load(&root)?;
    let scratch = std::env::var("DATABASE_URL").context("DATABASE_URL")?;
    let mut rows = Vec::new();
    for e in entries {
        let scenario = Scenario::new(&e, &root, &scratch, None, None).await?;
        let name = scenario.f.test.name.clone();
        let row = scenario.evaluate(&e).await?;
        assert!(
            row.hard_pass && row.behavior_pass && row.records_pass,
            "{} {:?}",
            row.id,
            row.reasons
        );
        for c in [&row.amount, &row.date, &row.category_accuracy, &row.tools] {
            if c.total > 0 {
                assert_eq!(c.rate(), Some(1.0), "{}", row.id);
            }
        }
        assert_eq!(row.business_errors, 0, "{}", row.id);
        rows.push(row);
        drop(scenario);
        let pool = sqlx::PgPool::connect(&scratch).await?;
        let exists: bool =
            sqlx::query_scalar("select exists(select 1 from pg_database where datname=$1)")
                .bind(name)
                .fetch_one(&pool)
                .await?;
        assert!(!exists, "temporary database leaked");
        pool.close().await;
    }
    assert_eq!(scoring::exit_code(&rows), 0);
    let dir = std::env::temp_dir().join(format!("jiabu-eval-report-{}", uuid::Uuid::now_v7()));
    report::write(&dir, &rows)?;
    let summary = std::fs::read_to_string(dir.join("summary.csv"))?;
    for metric in [
        "tool_argument_validity",
        "amount_precision",
        "date_accuracy",
        "category_accuracy",
        "question_precision",
        "question_recall",
        "ambiguous_date_recall",
    ] {
        assert!(summary.contains(&format!("\"{metric}\",\"1\"")), "{metric}");
    }
    assert!(summary.contains("\"hard_failure_count\",\"0\""));
    std::fs::remove_dir_all(dir)?;
    Ok(())
}
#[tokio::test]
async fn binary_mock_entry_point_emits_csv_and_success_exit_status() -> Result<()> {
    let dir = std::env::temp_dir().join(format!("jiabu-eval-cli-{}", uuid::Uuid::now_v7()));
    // Captured output is never printed, even if a future dependency emits secrets.
    let output = tokio::process::Command::new(env!("CARGO_BIN_EXE_ai-eval"))
        .args(["--provider", "mock", "--out"])
        .arg(&dir)
        .output()
        .await?;
    assert!(
        output.status.success(),
        "mock CLI failed (output suppressed)"
    );
    let results = std::fs::read_to_string(dir.join("results.csv"))?;
    assert_eq!(results.lines().count(), 65);
    assert!(dir.join("summary.csv").is_file());
    std::fs::remove_dir_all(dir)?;
    Ok(())
}
