use ai_eval::{
    dataset::{self, Behavior, RecordSpec},
    fixture::{Scenario, invoke},
    mock::{self, Identities},
    scoring::{self, Observation, Questions},
};
use anyhow::{Context, Result};
use serde_json::{Value, json};
fn ambiguity() -> dataset::Entry {
    dataset::parse(include_str!("../../../eval/entries/zh-ambiguous-001.yaml")).unwrap()
}
fn confirmation() -> dataset::Entry {
    dataset::parse(include_str!("../../../eval/entries/zh-confirm-001.yaml")).unwrap()
}
fn observation(events: Value, records: Value) -> Observation {
    Observation {
        status: "completed".into(),
        asked: false,
        confirmation: false,
        confirmation_calls: vec![],
        confirmed: false,
        before_confirm: None,
        baseline: json!({"records":[],"events":[]}),
        final_state: json!({"records":records,"events":events}),
        calls: vec![],
        tool_total: 1,
        tool_valid: 1,
        business_errors: 0,
        elapsed_ms: 1,
    }
}
#[test]
fn bad_model_writes_ambiguous_date_fails_hard_and_exit_code_is_nonzero() {
    let event = json!({"id":1,"entity_kind":"record","entity_id":"fake","kind":"create","after":{"id":"fake","amount_minor":1800,"occurred_on":"2026-03-04"}});
    let row = scoring::score(
        &ambiguity(),
        &Identities::default(),
        &observation(json!([event]), json!([])),
    );
    assert!(!row.hard_pass);
    assert_eq!(scoring::exit_code(&[row]), 1);
}
#[test]
fn skips_confirmation_or_mutates_before_confirmation_is_hard_failure() {
    for before in [None, Some(false)] {
        let mut o = observation(json!([]), json!([]));
        o.confirmation = before.is_some();
        o.confirmed = before.is_some();
        o.before_confirm = before;
        let row = scoring::score(&confirmation(), &Identities::default(), &o);
        assert!(!row.hard_pass);
        assert_eq!(scoring::exit_code(&[row]), 1);
    }
}
#[test]
fn known_question_confusion_matrix_precision_recall_and_zero_denominators() {
    let mut q = Questions::default();
    for pair in [
        (true, true),
        (true, true),
        (false, true),
        (true, false),
        (false, false),
    ] {
        q.add(pair.0, pair.1);
    }
    assert_eq!((q.tp, q.fp, q.fn_, q.tn), (2, 1, 1, 1));
    assert_eq!(q.precision().rate(), Some(2.0 / 3.0));
    assert_eq!(q.recall().rate(), Some(2.0 / 3.0));
    assert_eq!(Questions::default().precision().rate(), None);
    assert_eq!(Questions::default().recall().rate(), None);
}
#[test]
fn assignment_handles_reordering_duplicates_missing_extra_and_partial_fields() {
    let expected = vec![
        json!({"amount_minor":5000,"kind":"expense"}),
        json!({"amount_minor":1000}),
    ];
    assert_eq!(
        scoring::pairing(
            &expected,
            &[
                json!({"amount_minor":1000}),
                json!({"amount_minor":5000,"kind":"expense"})
            ]
        ),
        vec![Some(1), Some(0)]
    );
    assert_eq!(scoring::pairing(&expected, &[]), vec![None, None]);
    let mut e = ambiguity();
    e.category = "multi_record".into();
    e.expect.behavior = Behavior::Write;
    e.expect.hard = false;
    e.expect.records = vec![RecordSpec {
        operation: "create".into(),
        amount_minor: Some(5000),
        ..RecordSpec::default()
    }];
    let event = |id, amount| json!({"id":id,"entity_kind":"record","entity_id":id,"kind":"create","after":{"id":id,"amount_minor":amount}});
    for amounts in [vec![5000, 5000], vec![5000, 1000], vec![]] {
        let events: Vec<_> = amounts
            .iter()
            .enumerate()
            .map(|(i, a)| event(i + 1, *a))
            .collect();
        let r = scoring::score(
            &e,
            &Identities::default(),
            &observation(json!(events), json!([])),
        );
        assert!(!r.records_pass);
        assert!(r.amount.rate() != Some(1.0));
    }
}
#[test]
fn csv_quotes_json_newlines_and_percentiles_unknown_costs() {
    assert_eq!(
        ai_eval::report::csv_row(&["a,b".into(), "a\"b\nc".into(), "".into()]),
        "\"a,b\",\"a\"\"b\nc\",\"\"\r\n"
    );
    assert_eq!(scoring::percentile(&[90, 10, 30, 20, 40], 50), Some(30));
    assert_eq!(scoring::percentile(&[90, 10, 30, 20, 40], 95), Some(90));
    assert_eq!(scoring::percentile(&[], 95), None);
    let row = scoring::score(
        &ambiguity(),
        &Identities::default(),
        &observation(json!([]), json!([])),
    );
    assert_eq!(row.cost_usd, None);
}
#[tokio::test]
async fn scripted_bad_model_writes_before_asking_through_real_agent() -> Result<()> {
    let e = ambiguity();
    let scratch = std::env::var("DATABASE_URL")?;
    let root = ai_eval::dataset_root();
    // Prepare identities normally, then replace only the mock router scripts.
    let scenario = Scenario::new(&e, &root, &scratch, None, None).await?;
    let mut bad = e.clone();
    bad.expect.behavior = Behavior::Write;
    bad.expect.records = vec![RecordSpec {
        operation: "create".into(),
        kind: Some("expense".into()),
        amount_minor: Some(1800),
        occurred_on: Some(chrono::NaiveDate::from_ymd_opt(2026, 3, 4).context("date")?),
        account: Some("cash".into()),
        purpose: Some("daily".into()),
        ..RecordSpec::default()
    }];
    replace_scripts(&scenario, mock::scripts(&bad, &scenario.ids)?);
    let result = scenario.evaluate(&e).await?;
    assert!(!result.hard_pass);
    assert_eq!(scoring::exit_code(&[result]), 1);
    Ok(())
}
#[tokio::test]
async fn scripted_bad_model_creates_instead_of_confirming_and_direct_target_mutation_are_detected()
-> Result<()> {
    let e = confirmation();
    let scratch = std::env::var("DATABASE_URL")?;
    let root = ai_eval::dataset_root();
    let scenario = Scenario::new(&e, &root, &scratch, None, None).await?;
    let mut bad = e.clone();
    bad.expect.behavior = Behavior::Write;
    bad.expect.records[0].operation = "create".into();
    bad.expect.records[0].target = None;
    let scripts = mock::scripts(&bad, &scenario.ids)?;
    replace_scripts(&scenario, scripts);
    let row = scenario.evaluate(&e).await?;
    assert!(!row.hard_pass);
    assert_eq!(scoring::exit_code(&[row]), 1);
    let scenario = Scenario::new(&e, &root, &scratch, None, None).await?;
    let message = scenario.submit(&e).await?;
    scenario.drive(message).await?;
    let id = scenario.ids.records["old"];
    invoke(
        &scenario.f,
        "update_record",
        json!({"id":id,"expected_version":1,"changes":{"amount_minor":9000}}),
    )
    .await?;
    let o = scenario.observe(message, Some(false), false, 1).await?;
    let row = scoring::score(&e, &scenario.ids, &o);
    assert!(!row.hard_pass);
    Ok(())
}
fn replace_scripts(s: &Scenario, scripts: Vec<jiabu_ai::mock::TurnScript>) {
    use jiabu_ai::*;
    use std::sync::Arc;
    let config = s.f.runtime.router.0.load().config.clone();
    let mock = Arc::new(jiabu_ai::mock::MockProvider::scripted(
        "synthetic",
        Capabilities {
            structured: StructuredMode::ToolCall,
            vision: true,
            max_images: 8,
            files: false,
            max_files: 0,
            context_tokens: 8192,
        },
        scripts,
    ));
    let audited = Arc::new(ai_eval::audit::AuditedProvider {
        inner: mock,
        registry: s.f.runtime.tools.clone(),
        audit: s.audit.clone(),
    });
    s.f.runtime
        .router
        .0
        .store(Arc::new(AiRouter::new(config, vec![audited])));
}

#[test]
fn fixed_target_and_refund_reallocation_identity_participate_in_pairing() {
    let expected = vec![
        json!({"id":"old","amount_minor":100}),
        json!({"refund_of_id":"parent","amount_minor":100}),
        json!({"to_purpose_id":"saving","amount_minor":100}),
    ];
    let actual = vec![
        json!({"to_purpose_id":"saving","amount_minor":100}),
        json!({"id":"old","amount_minor":100}),
        json!({"refund_of_id":"parent","amount_minor":100}),
    ];
    assert_eq!(
        scoring::pairing(&expected, &actual),
        vec![Some(1), Some(2), Some(0)]
    );
}
#[test]
fn failure_status_and_write_then_void_cannot_pass_hard_question() {
    let e = ambiguity();
    let mut o = observation(json!([]), json!([]));
    o.asked = true;
    o.status = "failed".into();
    assert!(!scoring::score(&e, &Identities::default(), &o).hard_pass);
    o.status = "paused".into();
    o.final_state["events"] = json!([{"id":1,"entity_kind":"record","kind":"create","after":{}},{"id":2,"entity_kind":"record","kind":"void","after":{}}]);
    assert!(!scoring::score(&e, &Identities::default(), &o).hard_pass);
}
#[test]
fn unknown_costs_remain_blank_in_summary_and_calls_are_preserved() -> Result<()> {
    let mut o = observation(json!([]), json!([]));
    o.calls = vec![
        json!({"call_kind":"first","cached_input_tokens":null,"cache_write_tokens":null,"uncached_input_tokens":null,"cost_usd":null}),
    ];
    let row = scoring::score(&ambiguity(), &Identities::default(), &o);
    assert_eq!(row.cost_usd, None);
    let dir = std::env::temp_dir().join(format!("jiabu-eval-unknown-{}", uuid::Uuid::now_v7()));
    ai_eval::report::write(&dir, &[row])?;
    let summary = std::fs::read_to_string(dir.join("summary.csv"))?;
    assert!(summary.contains("\"mean_cost_usd\",\"\""));
    assert!(summary.contains("\"unknown_cost_count\",\"1\""));
    let results = std::fs::read_to_string(dir.join("results.csv"))?;
    assert!(results.contains("cached_input_tokens"));
    std::fs::remove_dir_all(dir)?;
    Ok(())
}
#[tokio::test]
async fn tool_argument_audit_counts_invalid_calls_before_runtime_can_discard_them() -> Result<()> {
    use jiabu_ai::*;
    use std::sync::{Arc, atomic::Ordering};
    struct Discard;
    #[async_trait::async_trait]
    impl TurnSink for Discard {
        async fn emit(&mut self, _: TurnEvent) -> Result<(), ProviderError> {
            Ok(())
        }
    }
    let audit = Arc::new(ai_eval::audit::ToolAudit::default());
    let inner = Arc::new(jiabu_ai::mock::MockProvider::scripted(
        "synthetic",
        Capabilities {
            structured: StructuredMode::ToolCall,
            vision: false,
            max_images: 0,
            files: false,
            max_files: 0,
            context_tokens: 8192,
        },
        vec![vec![
            ai_eval::agent_fixture::call(
                "invalid",
                "create_record",
                json!({"amount_minor":"not-an-integer"}),
            ),
            ai_eval::agent_fixture::call("unknown", "missing_tool", json!({})),
            ai_eval::agent_fixture::call(
                "valid",
                "ask_user",
                json!({"prompt":"Please clarify","options":[],"fields":[]}),
            ),
            ai_eval::agent_fixture::done(),
        ]],
    ));
    let provider = ai_eval::audit::AuditedProvider {
        inner,
        registry: jiabu_tools::builtin_registry(),
        audit: audit.clone(),
    };
    provider
        .run_turn(
            &TurnRequest {
                run_id: uuid::Uuid::nil(),
                session_key: "synthetic-session".into(),
                snapshot: PromptSnapshot {
                    instructions: String::new(),
                    tools: vec![],
                    model: "fake-model".into(),
                    parameters: ModelParameters::default(),
                },
                items: vec![],
            },
            &mut Discard,
        )
        .await?;
    assert_eq!(audit.total.load(Ordering::Relaxed), 3);
    assert_eq!(audit.valid.load(Ordering::Relaxed), 1);
    Ok(())
}
