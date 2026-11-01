use ai_eval::{dataset, fixture::Scenario, report, scoring};
use anyhow::{Context, Result};
#[tokio::test]
async fn full_mock_suite_uses_real_pg_agent_worker_without_claiming_model_expectations()
-> Result<()> {
    let root = ai_eval::dataset_root();
    let entries = dataset::load(&root)?;
    let scratch = std::env::var("DATABASE_URL").context("DATABASE_URL")?;
    let mut rows = Vec::new();
    for e in entries {
        let scenario = Scenario::new(&e, &root, &scratch, None, None).await?;
        let name = scenario.f.test.name.clone();
        let (row, input) = scenario.evaluate_with_judge_input(&e).await?;
        assert!(
            row.hard_pass && row.behavior_pass && row.records_pass,
            "{} {:?}",
            row.id,
            row.reasons
        );
        if e.expect.display.is_some() {
            let input = input.context("complete display evidence")?;
            assert_eq!(
                input.test_reference["fixture_identities"]["accounts"],
                serde_json::to_value(&scenario.ids.accounts)?
            );
            assert_eq!(row.expectation_met, None);
            assert_eq!(row.rule_decision, scoring::RuleDecision::NeedsJudge);
        }
        for c in [&row.amount, &row.date, &row.category_accuracy] {
            if c.total > 0 {
                assert_eq!(c.rate(), Some(1.0), "{}", row.id);
            }
        }
        let expected_invalid = e
            .expect
            .display
            .as_ref()
            .map_or(0, |display| display.alternatives[0].expected_invalid_calls);
        assert_eq!(
            row.tools.total - row.tools.correct,
            expected_invalid,
            "{}",
            row.id
        );
        let expected_business_errors = e
            .expect
            .display
            .as_ref()
            .map_or(0, |display| display.alternatives[0].expected_business_errors);
        assert_eq!(row.business_errors, expected_business_errors, "{}", row.id);
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
    assert_eq!(
        scoring::exit_code(&rows),
        2,
        "unjudged model expectations remain unfinished"
    );
    let non_display = rows
        .iter()
        .filter(|row| row.category != "display")
        .cloned()
        .collect::<Vec<_>>();
    assert_eq!(scoring::exit_code(&non_display), 0);
    let dir = std::env::temp_dir().join(format!("jiabu-eval-report-{}", uuid::Uuid::now_v7()));
    report::write(&dir, &non_display)?;
    let display_rows = rows
        .iter()
        .filter(|row| row.category == "display")
        .cloned()
        .collect::<Vec<_>>();
    let ids = display_rows
        .iter()
        .map(|row| row.id.clone())
        .collect::<Vec<_>>();
    report::write_expectations(
        &dir.join("display-expectations"),
        &display_rows,
        &ids,
        true,
        true,
        false,
    )?;
    let display_summary = std::fs::read_to_string(dir.join("display-expectations/summary.csv"))?;
    assert!(display_summary.contains("\"expectation_met\",\"0\""));
    assert!(display_summary.contains("\"expectation_not_met\",\"0\""));
    let summary = std::fs::read_to_string(dir.join("summary.csv"))?;
    for metric in [
        "amount_precision",
        "date_accuracy",
        "category_accuracy",
        "question_precision",
        "question_recall",
        "ambiguous_date_recall",
    ] {
        assert!(summary.contains(&format!("\"{metric}\",\"1\"")), "{metric}");
    }
    assert!(summary.contains("\"tool_argument_validity\","));
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
    let display = std::fs::read_to_string(dir.join("display-expectations/results.csv"))?;
    assert_eq!(display.lines().count(), 21);
    assert!(display.contains("mock_pipeline_completed"));
    assert!(!display.contains("display_pass"));
    assert!(!display.contains("clear_natural_expression"));
    assert!(dir.join("summary.csv").is_file());
    std::fs::remove_dir_all(dir)?;
    Ok(())
}
