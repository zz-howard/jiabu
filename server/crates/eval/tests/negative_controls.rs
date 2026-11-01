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
        message: json!({"fallbackText":"","blocks":[]}),
        tool_calls: vec![],
        tool_results: Default::default(),
        display_audit: vec![],
        display_audit_total: 0,
        display_audit_valid: 0,
        display_audit_discarded: 0,
        server_fallbacks: vec![],
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
        "\"a,b\",\"a\"\"b\nc\",\"\"\n"
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
    let legacy = [
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
    ];
    assert_eq!(&ai_eval::report::RESULTS_HEADER[..legacy.len()], &legacy);
    assert_eq!(
        &ai_eval::report::RESULTS_HEADER[legacy.len()..legacy.len() + 9],
        &[
            "display_hard",
            "display_pass",
            "display_tool_correct",
            "display_tool_total",
            "display_block_correct",
            "display_block_total",
            "display_value_correct",
            "display_value_total",
            "display_prose_pass",
        ]
    );
    for column in [
        "tier",
        "display_expected_selection",
        "display_actual_selection",
        "display_query_summary",
        "display_query_correct",
        "display_query_total",
        "display_query_not_assessable",
        "display_argument_valid",
        "display_argument_total",
        "display_audit_complete",
        "display_audit_discarded",
    ] {
        assert!(ai_eval::report::RESULTS_HEADER.contains(&column));
    }
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
    assert!(summary.contains("\"tier.core.hard_pass\""));
    let results = std::fs::read_to_string(dir.join("results.csv"))?;
    assert!(results.contains("cached_input_tokens"));
    std::fs::remove_dir_all(dir)?;
    Ok(())
}

fn display_entry(name: &str) -> dataset::Entry {
    let source = std::fs::read_to_string(ai_eval::dataset_root().join("entries").join(name))
        .expect("display entry");
    dataset::parse(&source).expect("valid display entry")
}

fn display_observation(entry: &dataset::Entry, message: Value) -> Observation {
    let mut observation = observation(json!([]), json!([]));
    observation.message = message;
    observation.tool_calls = entry
        .expect
        .display
        .as_ref()
        .unwrap()
        .source_calls
        .iter()
        .chain(&entry.expect.display.as_ref().unwrap().calls)
        .enumerate()
        .map(|(index, call)| {
            let args = if index < entry.expect.display.as_ref().unwrap().source_calls.len() {
                call.args.clone()
            } else {
                replace_call_aliases(&call.args)
            };
            json!({"tool":call.tool,"args":args,"call_id":format!("source-{index}")})
        })
        .collect();
    observation.tool_total = observation.tool_calls.len();
    observation.tool_valid = observation.tool_calls.len();
    observation.tool_results = observation
        .tool_calls
        .iter()
        .filter_map(|call| call["call_id"].as_str().map(|id| (id.to_owned(), true)))
        .collect();
    observation.display_audit = entry
        .expect
        .display
        .as_ref()
        .unwrap()
        .calls
        .iter()
        .map(|call| ai_eval::audit::DisplayAuditCall {
            tool: call.tool.clone(),
            valid: true,
            summary: json!({}),
            truncated: false,
            discarded: 0,
        })
        .collect();
    observation.display_audit_total = observation.display_audit.len();
    observation.display_audit_valid = observation.display_audit.len();
    observation
}

fn replace_call_aliases(value: &Value) -> Value {
    match value {
        Value::String(value) if value.starts_with("$call:") => {
            json!(value.trim_start_matches("$call:"))
        }
        Value::Array(values) => Value::Array(values.iter().map(replace_call_aliases).collect()),
        Value::Object(values) => Value::Object(
            values
                .iter()
                .map(|(key, value)| (key.clone(), replace_call_aliases(value)))
                .collect(),
        ),
        value => value.clone(),
    }
}

#[test]
fn display_negative_controls_kill_kind_value_demo_capability_and_duplicate_mutations() {
    let metric = display_entry("display-003.yaml");
    let good_metric = json!({"fallbackText":"ok","blocks":[{
        "type":"metric",
        "data":{"label":"2026年10月支出","value":9900},
        "fallbackText":"2026年10月支出：99.00 元"
    }]});
    let good = scoring::score(
        &metric,
        &Identities::default(),
        &display_observation(&metric, good_metric.clone()),
    );
    assert!(good.display_pass);
    for pointer in [
        "/source/query/period/from",
        "/source/query/group_by",
        "/source/demo",
    ] {
        let mut bad = display_observation(&metric, good_metric.clone());
        *bad.tool_calls[0]["args"]
            .pointer_mut(pointer)
            .expect("display argument") = match pointer {
            "/source/query/period/from" => json!("2026-09-01"),
            "/source/query/group_by" => json!("purpose"),
            _ => json!("monthly_spending"),
        };
        assert!(
            !scoring::score(&metric, &Identities::default(), &bad).display_pass,
            "argument mutation survived: {pointer}"
        );
    }
    let mut wrong_kind = good_metric.clone();
    wrong_kind["blocks"][0]["type"] = json!("metric_group");
    assert!(
        !scoring::score(
            &metric,
            &Identities::default(),
            &display_observation(&metric, wrong_kind),
        )
        .display_pass
    );
    let mut wrong_value = good_metric.clone();
    wrong_value["blocks"][0]["data"]["value"] = json!(9901);
    assert!(
        !scoring::score(
            &metric,
            &Identities::default(),
            &display_observation(&metric, wrong_value),
        )
        .display_pass
    );
    let mut duplicate = good_metric;
    let extra = duplicate["blocks"][0].clone();
    duplicate["blocks"].as_array_mut().unwrap().push(extra);
    assert!(
        !scoring::score(
            &metric,
            &Identities::default(),
            &display_observation(&metric, duplicate),
        )
        .display_pass
    );

    let demo = display_entry("display-009.yaml");
    let demo_message = json!({"fallbackText":"【演示数据】","blocks":[{
        "type":"metric_group",
        "data":{"title":"本月支出","metrics":[
            {"label":"餐饮","value":142000},{"label":"居家","value":98000},
            {"label":"购物","value":75000},{"label":"交通","value":41000},
            {"label":"其他","value":72600}
        ]},
        "fallbackText":"本月支出"
    }]});
    assert!(
        !scoring::score(
            &demo,
            &Identities::default(),
            &display_observation(&demo, demo_message),
        )
        .display_pass
    );

    let fallback = display_entry("display-016.yaml");
    let leaked_component = json!({"fallbackText":"虚构日常；虚构储备","blocks":[{
        "type":"metric_group","data":{"metrics":[]},"fallbackText":"unexpected"
    }]});
    assert!(
        !scoring::score(
            &fallback,
            &Identities::default(),
            &display_observation(&fallback, leaked_component),
        )
        .display_pass
    );
    let model_spoof = json!({
        "fallbackText":"虚构日常；虚构储备",
        "blocks":[{"type":"markdown","data":{"text":"虚构日常；虚构储备"},"fallbackText":"虚构日常；虚构储备"}]
    });
    assert!(
        !scoring::score(
            &fallback,
            &Identities::default(),
            &display_observation(&fallback, model_spoof),
        )
        .display_pass,
        "model prose must not satisfy a server fallback assertion"
    );

    let linked = display_entry("display-002.yaml");
    let mut wrong_link = display_observation(
        &linked,
        json!({"fallbackText":"ok","blocks":[{
            "type":"metric_group",
            "data":{"metrics":[{"label":"虚构日常","value":6800},{"label":"虚构储备","value":3200}]},
            "fallbackText":"ok"
        }]}),
    );
    wrong_link.tool_calls[1]["args"]["source"]["from_call"] = json!("different-call");
    assert!(!scoring::score(&linked, &Identities::default(), &wrong_link).display_pass);

    let account = display_entry("display-007.yaml");
    let account_id = uuid::Uuid::now_v7();
    let mut identities = Identities::default();
    identities.accounts.insert("bank".into(), account_id);
    let mut account_observation = display_observation(
        &account,
        json!({"fallbackText":"虚构银行卡：-¥68.00","blocks":[{
            "type":"x-jiabu.account_card",
            "data":{"accountId":account_id,"versionAtReply":1,"nameSnapshot":"虚构银行卡"},
            "fallbackText":"虚构银行卡：-¥68.00"
        }]}),
    );
    account_observation.tool_calls[0]["args"]["account_id"] = json!(account_id);
    account_observation.server_fallbacks = vec!["虚构银行卡：-¥68.00".into()];
    assert!(scoring::score(&account, &identities, &account_observation).display_pass);
    account_observation.server_fallbacks = vec!["虚构银行卡：+¥68.00".into()];
    assert!(!scoring::score(&account, &identities, &account_observation).display_pass);
    account_observation.server_fallbacks = vec!["虚构银行卡：-¥68.00".into()];
    account_observation.tool_calls[0]["args"]["account_id"] = json!(uuid::Uuid::now_v7());
    assert!(!scoring::score(&account, &identities, &account_observation).display_pass);
}

#[test]
fn display_selection_query_validity_and_transport_are_independent() {
    let linked = display_entry("display-002.yaml");
    let message = json!({"fallbackText":"ok","blocks":[{"type":"metric_group","data":{"metrics":[{"label":"虚构日常","value":6800},{"label":"虚构储备","value":3200}]},"fallbackText":"ok"}]});
    let mut direct = display_observation(&linked, message.clone());
    let source = direct.tool_calls.remove(0)["args"].clone();
    direct.tool_calls[0]["args"]["source"] = json!({
        "query": {"measure":source["measure"],"kinds":source["kinds"],"period":source["period"],"group_by":source["group_by"],"account_id":null,"purpose_id":null,"tag_id":null,"member_id":null},
        "from_call":null,"demo":null
    });
    direct.tool_results.clear();
    let good = scoring::score(&linked, &Identities::default(), &direct);
    assert_eq!(good.display_queries.rate(), Some(1.0));
    assert!(good.display_pass);

    let mut wrong_selection = direct.clone();
    wrong_selection.tool_calls[0]["tool"] = json!("show_breakdown");
    wrong_selection.display_audit[0].tool = "show_breakdown".into();
    let selected = scoring::score(&linked, &Identities::default(), &wrong_selection);
    assert_eq!(selected.display_tools.rate(), Some(0.0));
    assert_eq!(selected.display_queries.rate(), Some(1.0));

    let mut invalid = direct.clone();
    invalid.display_audit[0].valid = false;
    invalid.display_audit_valid = 0;
    let invalid = scoring::score(&linked, &Identities::default(), &invalid);
    assert_eq!(invalid.display_arguments.rate(), Some(0.0));
    assert_eq!(invalid.display_queries.total, 0);
    assert_eq!(invalid.display_query_not_assessable, 1);

    let mut unresolved = display_observation(&linked, message);
    unresolved.tool_results.clear();
    let unresolved = scoring::score(&linked, &Identities::default(), &unresolved);
    assert_eq!(unresolved.display_queries.total, 0);
    assert_eq!(unresolved.display_query_not_assessable, 1);
    assert!(!unresolved.hard_pass);
}

#[test]
fn legacy_global_invalid_and_business_error_invariants_still_gate_display() {
    let mut entry = display_entry("display-003.yaml");
    let display = entry.expect.display.as_mut().unwrap();
    display.expected_invalid_calls = 1;
    display.expected_business_errors = 1;
    let message = json!({"fallbackText":"ok","blocks":[{"type":"metric","data":{"label":"2026年10月支出","value":9900},"fallbackText":"ok"}]});
    let mut observed = display_observation(&entry, message);
    observed.tool_total += 1;
    observed.business_errors = 1;
    assert!(scoring::score(&entry, &Identities::default(), &observed).display_pass);
    observed.business_errors = 0;
    let row = scoring::score(&entry, &Identities::default(), &observed);
    assert!(!row.display_pass);
    assert!(
        row.reasons
            .contains(&"display_business_error_mismatch".into())
    );
    assert!(!row.hard_pass);
}

#[test]
fn display_call_pairing_covers_missing_extra_reordered_and_unpersisted_invalid_calls() {
    let entry = display_entry("display-009.yaml");
    let message = json!({"fallbackText":"","blocks":[]});
    let base = display_observation(&entry, message);
    let mut missing = base.clone();
    missing.tool_calls.pop();
    missing.display_audit.pop();
    missing.display_audit_total = 2;
    missing.display_audit_valid = 2;
    let row = scoring::score(&entry, &Identities::default(), &missing);
    assert_eq!(row.display_tools.total, 3);
    assert_eq!(
        row.display_arguments,
        scoring::Count {
            correct: 2,
            total: 2
        }
    );
    let mut extra = base.clone();
    extra.tool_calls.push(json!({"tool":"show_metrics","call_id":"extra","args":entry.expect.display.as_ref().unwrap().calls[0].args.clone()}));
    extra.display_audit.push(ai_eval::audit::DisplayAuditCall {
        tool: "show_metrics".into(),
        valid: true,
        summary: json!({}),
        truncated: false,
        discarded: 0,
    });
    extra.display_audit_total = 4;
    extra.display_audit_valid = 4;
    assert_eq!(
        scoring::score(&entry, &Identities::default(), &extra)
            .display_tools
            .total,
        4
    );
    let mut reordered = base.clone();
    reordered.tool_calls.swap(0, 1);
    reordered.display_audit.swap(0, 1);
    assert!(
        scoring::score(&entry, &Identities::default(), &reordered)
            .display_tools
            .rate()
            .unwrap()
            < 1.0
    );

    let mut invalid = base;
    invalid.display_audit[0].valid = false;
    invalid.display_audit_valid = 2;
    invalid.tool_calls.remove(0);
    let row = scoring::score(&entry, &Identities::default(), &invalid);
    assert_eq!(row.display_query_not_assessable, 1);
    assert_eq!(row.display_queries.total, 2);
    assert_eq!(row.display_queries.correct, 2);
}

#[test]
fn source_reference_requires_earlier_compatible_succeeded_call() {
    let entry = display_entry("display-002.yaml");
    let message = json!({"fallbackText":"ok","blocks":[{"type":"metric_group","data":{"metrics":[{"label":"虚构日常","value":6800},{"label":"虚构储备","value":3200}]},"fallbackText":"ok"}]});
    let base = display_observation(&entry, message);
    for mutation in ["missing", "failed", "later", "incompatible"] {
        let mut observed = base.clone();
        match mutation {
            "missing" => {
                observed.tool_results.remove("source-0");
            }
            "failed" => {
                observed.tool_results.insert("source-0".into(), false);
            }
            "later" => {
                observed.tool_calls.swap(0, 1);
            }
            "incompatible" => {
                observed.tool_calls[0]["tool"] = json!("search_records");
            }
            _ => unreachable!(),
        }
        let row = scoring::score(&entry, &Identities::default(), &observed);
        assert_eq!(row.display_query_not_assessable, 1, "{mutation}");
        assert_eq!(row.display_queries.total, 0, "{mutation}");
    }
}

#[test]
fn trend_source_reference_preserves_and_checks_grouping() {
    let entry = display_entry("display-004.yaml");
    let message = json!({"fallbackText":"ok","blocks":[]});
    let mut observed = display_observation(&entry, message);
    observed.tool_calls = vec![
        json!({"tool":"query_stats","call_id":"stats","args":{"measure":"sum","kinds":["expense"],"period":{"from":"2026-08-01","through":"2026-10-31"},"group_by":"month","filters":{"account_id":null,"purpose_id":null,"tag_id":null,"member_id":null}}}),
        json!({"tool":"show_trend","call_id":"display","args":{"source":{"query":null,"from_call":"stats","demo":null}}}),
    ];
    observed.tool_results = [("stats".to_owned(), true), ("display".to_owned(), true)]
        .into_iter()
        .collect();
    assert_eq!(
        scoring::score(&entry, &Identities::default(), &observed)
            .display_queries
            .rate(),
        Some(1.0)
    );
    observed.tool_calls[0]["args"]["group_by"] = json!("purpose");
    assert_eq!(
        scoring::score(&entry, &Identities::default(), &observed)
            .display_queries
            .rate(),
        Some(0.0)
    );
}

#[test]
fn stats_kinds_are_compared_as_a_sorted_deduplicated_set() {
    let mut entry = display_entry("display-003.yaml");
    entry.expect.display.as_mut().unwrap().calls[0].args["source"]["query"]["kinds"] =
        json!(["income", "expense", "income"]);
    let message = json!({"fallbackText":"ok","blocks":[{"type":"metric","data":{"label":"2026年10月支出","value":9900},"fallbackText":"ok"}]});
    let mut observed = display_observation(&entry, message);
    observed.tool_calls[0]["args"]["source"]["query"]["kinds"] = json!(["expense", "income"]);
    assert_eq!(
        scoring::score(&entry, &Identities::default(), &observed)
            .display_queries
            .rate(),
        Some(1.0)
    );
}

#[test]
fn record_query_direct_and_successful_source_call_are_equivalent() {
    let entry = display_entry("display-005.yaml");
    let message = json!({"fallbackText":"ok","blocks":[{"type":"dataset","data":{"columns":[{"key":"date"}],"rows":[{"date":"2026-10-03","amount":3000},{"date":"2026-10-02","amount":2000},{"date":"2026-10-01","amount":1000}]},"fallbackText":"ok"}]});
    let mut observed = display_observation(&entry, message);
    observed.tool_calls = vec![
        json!({"tool":"search_records","call_id":"records","args":{"filters":{"kinds":["expense"],"from":"2026-10-01","through":"2026-10-31","account_id":null,"purpose_id":null,"tag_id":null,"member_id":null,"text":null,"status":"active"},"page":{"limit":3,"offset":0}}}),
        json!({"tool":"show_records","call_id":"display","args":{"source":{"query":null,"from_call":"records","demo":null}}}),
    ];
    observed.tool_results = [("records".to_owned(), true), ("display".to_owned(), true)]
        .into_iter()
        .collect();
    let row = scoring::score(&entry, &Identities::default(), &observed);
    assert_eq!(row.display_queries.rate(), Some(1.0));
    assert!(row.display_pass);
    for (pointer, value) in [
        ("/args/page/limit", json!(2)),
        ("/args/page/offset", json!(1)),
        ("/args/filters/status", json!("voided")),
    ] {
        let mut wrong = observed.clone();
        *wrong.tool_calls[0].pointer_mut(pointer).unwrap() = value;
        assert_eq!(
            scoring::score(&entry, &Identities::default(), &wrong)
                .display_queries
                .rate(),
            Some(0.0),
            "{pointer}"
        );
    }
    observed.tool_calls[0]["args"]["filters"]["text"] = json!("different search");
    let row = scoring::score(&entry, &Identities::default(), &observed);
    assert_eq!(row.display_queries.rate(), Some(0.0));
    assert!(!row.display_query_summary.contains("different search"));

    let mut kinds_entry = entry.clone();
    kinds_entry.expect.display.as_mut().unwrap().calls[0].args["source"]["query"]["kinds"] =
        json!(["income", "expense", "income"]);
    observed.tool_calls[0]["args"]["filters"]["text"] = Value::Null;
    observed.tool_calls[0]["args"]["filters"]["kinds"] = json!(["expense", "income", "expense"]);
    assert_eq!(
        scoring::score(&kinds_entry, &Identities::default(), &observed)
            .display_queries
            .rate(),
        Some(1.0)
    );

    let mut text_entry = entry.clone();
    text_entry.expect.display.as_mut().unwrap().calls[0].args["source"]["query"]["text"] =
        json!(" Lunch ");
    observed.tool_calls[0]["args"]["filters"]["kinds"] = json!(["expense"]);
    observed.tool_calls[0]["args"]["filters"]["text"] = json!(" lunch ");
    assert_eq!(
        scoring::score(&text_entry, &Identities::default(), &observed)
            .display_queries
            .rate(),
        Some(1.0)
    );
    observed.tool_calls[0]["args"]["filters"]["text"] = json!("lunch");
    assert_eq!(
        scoring::score(&text_entry, &Identities::default(), &observed)
            .display_queries
            .rate(),
        Some(0.0)
    );
}

#[test]
fn every_prose_guard_has_a_focused_negative_control() {
    let entry = display_entry("display-019.yaml");
    let assert_rejected = |prose: &str| {
        let message = json!({
            "fallbackText":"本月总支出 68.00 元",
            "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
        });
        let row = scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message),
        );
        assert!(!row.prose_pass, "prose mutation survived: {prose}");
    };
    assert_rejected("```mermaid\ngraph TD\nA-->B\n```");
    assert_rejected("餐饮 ███\n交通 ██\n购物 █");
    assert_rejected("|a|b|\n|---|---|\n|1|2|\n|3|4|\n|5|6|\n|7|8|\n|9|10|\n|11|12|");
    assert_rejected("餐饮 ###\n交通 ==\n购物 **");
    assert_rejected("第一句。第二句。");
    assert_rejected("First. Second.");

    let message = |prose: &str| {
        json!({
            "fallbackText":format!("本月总支出 68.00 元\n{prose}"),
            "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
        })
    };
    let five_rows = "|a|b|\n|---|---|\n|1|2|\n|3|4|\n|5|6|\n|7|8|\n|9|10|";
    assert!(
        scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message(five_rows)),
        )
        .prose_pass
    );
    let six_rows = format!("{five_rows}\n|11|12|");
    assert!(
        !scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message(&six_rows)),
        )
        .prose_pass
    );

    let five_rows_no_outer = "a | b\n--- | ---\n1 | 2\n3 | 4\n5 | 6\n7 | 8\n9 | 10";
    assert!(
        scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message(five_rows_no_outer)),
        )
        .prose_pass
    );
    let six_rows_no_outer = format!("{five_rows_no_outer}\n11 | 12");
    assert!(
        !scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message(&six_rows_no_outer)),
        )
        .prose_pass
    );

    for prose in [
        "## 一\n## 二\n## 三",
        "**一**\n**二**\n**三**",
        "- **一** 正文\n- **二** 正文\n- **三** 正文",
        "---\n===\n***",
        "a | b\nc | d\ne | f\ng | h\ni | j\nk | l",
    ] {
        assert!(
            scoring::score(
                &entry,
                &Identities::default(),
                &display_observation(&entry, message(prose)),
            )
            .prose_pass,
            "markdown was mistaken for an ASCII chart: {prose}"
        );
    }
}

#[test]
fn sentence_count_and_numeric_restatement_are_soft_findings() {
    let entry = display_entry("display-001.yaml");
    let message = json!({"fallbackText":"ok","blocks":[
        {"type":"breakdown","data":{"parts":[
            {"label":"虚构日常","value":6800},{"label":"虚构储备","value":3200}
        ]},"fallbackText":"ok"},
        {"type":"markdown","data":{"text":"68.00，32.00。第二句。第三句。"},"fallbackText":"68.00，32.00。第二句。第三句。"}
    ]});
    let row = scoring::score(
        &entry,
        &Identities::default(),
        &display_observation(&entry, message),
    );
    assert!(!row.prose_pass);
    assert!(row.display_pass && row.hard_pass);
    assert!(row.reasons.contains(&"display_style_preference".into()));

    for prose in ["68.00", "68 元", "¥68", "6800 分"] {
        let message = json!({"fallbackText":"ok","blocks":[
            {"type":"breakdown","data":{"parts":[
                {"label":"虚构日常","value":6800},{"label":"虚构储备","value":3200}
            ]},"fallbackText":"ok"},
            {"type":"markdown","data":{"text":prose},"fallbackText":prose}
        ]});
        let row = scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message),
        );
        assert!(!row.prose_pass, "numeric restatement survived: {prose}");
        assert!(row.display_pass && row.hard_pass);
    }
    for prose in ["168.00", "168 元", "¥680", "16800 分"] {
        let message = json!({"fallbackText":"ok","blocks":[
            {"type":"breakdown","data":{"parts":[
                {"label":"虚构日常","value":6800},{"label":"虚构储备","value":3200}
            ]},"fallbackText":"ok"},
            {"type":"markdown","data":{"text":prose},"fallbackText":prose}
        ]});
        assert!(
            scoring::score(
                &entry,
                &Identities::default(),
                &display_observation(&entry, message),
            )
            .prose_pass,
            "numeric substring was mistaken for a restatement: {prose}"
        );
    }
}

#[tokio::test]
async fn observe_credits_only_persisted_display_fallback_blocks() -> Result<()> {
    use ai_eval::agent_fixture::{done, text};

    let entry = display_entry("display-016.yaml");
    let scratch = std::env::var("DATABASE_URL")?;
    let root = ai_eval::dataset_root();

    let positive = Scenario::new(&entry, &root, &scratch, None, None).await?;
    let message = positive.submit(&entry).await?;
    positive.drive(message).await?;
    let observed = positive.observe(message, None, false, 0).await?;
    assert_eq!(observed.tool_results.get("display-0"), Some(&true));
    assert!(observed.server_fallbacks.iter().any(|fallback| {
        fallback.contains("虚构日常 ¥68.00") && fallback.contains("虚构储备 ¥32.00")
    }));
    assert!(
        observed
            .server_fallbacks
            .iter()
            .all(|fallback| !fallback.contains("已展示")),
        "later model Markdown must not inherit display provenance"
    );
    assert!(scoring::score(&entry, &positive.ids, &observed).display_pass);
    for (correct, wrong) in [("68.00", "168.00"), ("32.00", "132.00")] {
        let mut wrong_amount = observed.clone();
        wrong_amount.server_fallbacks = wrong_amount
            .server_fallbacks
            .iter()
            .map(|fallback| fallback.replace(correct, wrong))
            .collect();
        assert!(!scoring::score(&entry, &positive.ids, &wrong_amount).display_pass);
    }

    let spoof = Scenario::new(
        &entry,
        &root,
        &scratch,
        None,
        Some(vec![vec![text("虚构日常；虚构储备"), done()]]),
    )
    .await?;
    let message = spoof.submit(&entry).await?;
    spoof.drive(message).await?;
    let observed = spoof.observe(message, None, false, 0).await?;
    assert!(observed.server_fallbacks.is_empty());
    assert!(!scoring::score(&entry, &spoof.ids, &observed).display_pass);
    Ok(())
}

#[tokio::test]
async fn invalid_display_call_fault_injection_keeps_one_sentence_text_fallback() -> Result<()> {
    use ai_eval::agent_fixture::{call, done, text};
    let entry = display_entry("display-018.yaml");
    let scratch = std::env::var("DATABASE_URL")?;
    let root = ai_eval::dataset_root();
    let scenario=Scenario::new(&entry,&root,&scratch,None,Some(vec![
        vec![call("invalid","show_metrics",json!({"source":{"query":{"measure":"sum","kinds":["expense"],"period":{"from":"2026-09-01","through":"2026-10-31"},"group_by":"month","account_id":null,"purpose_id":null,"tag_id":null,"member_id":null},"from_call":null,"demo":null}})),done()],
        vec![text("展示参数不合规，改用文字说明。"),done()],
    ])).await?;
    let message = scenario.submit(&entry).await?;
    scenario.drive(message).await?;
    let observed = scenario.observe(message, None, false, 0).await?;
    let blocks = observed.message["blocks"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or(&[]);
    assert!(blocks.iter().all(|block| block["type"] == "markdown"));
    let prose = blocks
        .iter()
        .filter_map(|block| block["data"]["text"].as_str())
        .collect::<Vec<_>>()
        .join("\n");
    assert!(prose.contains("改用文字说明"));
    assert_eq!(
        prose
            .chars()
            .filter(|character| matches!(character, '。' | '！' | '？'))
            .count(),
        1
    );
    assert_eq!(observed.display_audit_valid, 0);
    assert_eq!(observed.tool_results.get("invalid"), Some(&false));
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
    let record_args = json!({"source":{"query":{"kinds":vec!["expense";17],"period":null,"account_id":null,"purpose_id":null,"tag_id":null,"member_id":null,"text":"Bearer secret-text https://example.invalid","limit":3},"from_call":null,"demo":null}});
    let mut script = vec![
        ai_eval::agent_fixture::call(
            "invalid",
            "create_record",
            json!({"amount_minor":"not-an-integer"}),
        ),
        ai_eval::agent_fixture::call("unknown", "missing_tool", json!({})),
        ai_eval::agent_fixture::call(
            "unknown-display",
            "show_bearer_secret",
            json!({"token":"secret"}),
        ),
        ai_eval::agent_fixture::call("valid-display", "show_records", record_args.clone()),
        ai_eval::agent_fixture::call(
            "valid",
            "ask_user",
            json!({"prompt":"Please clarify","options":[],"fields":[]}),
        ),
    ];
    for index in 0..17 {
        script.push(ai_eval::agent_fixture::call(
            &format!("repeat-{index}"),
            "show_records",
            record_args.clone(),
        ));
    }
    script.push(ai_eval::agent_fixture::done());
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
        vec![script],
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
    assert_eq!(audit.total.load(Ordering::Relaxed), 22);
    assert_eq!(audit.valid.load(Ordering::Relaxed), 19);
    let display = audit.display.lock().unwrap();
    assert_eq!(display.len(), 16);
    assert_eq!(display[0].tool, "<unknown>");
    assert_eq!(display[1].tool, "show_records");
    assert!(display[1].truncated);
    assert_eq!(display[1].discarded, 1);
    assert_eq!(display[1].summary["truncated"], true);
    assert_eq!(display[1].summary["discarded"], 1);
    let evidence = serde_json::to_string(&*display)?;
    for secret in ["bearer_secret", "Bearer secret-text", "example.invalid"] {
        assert!(!evidence.contains(secret));
    }
    assert_eq!(audit.display_discarded.load(Ordering::Relaxed), 3);
    assert_eq!(audit.display_total.load(Ordering::Relaxed), 19);
    assert_eq!(audit.display_valid.load(Ordering::Relaxed), 18);
    let mut row_entry = display_entry("display-005.yaml");
    row_entry.expect.display.as_mut().unwrap().calls[0].args["source"]["query"]["kinds"] =
        json!(vec!["expense"; 17]);
    let mut observed = display_observation(&row_entry, json!({"fallbackText":"","blocks":[]}));
    observed.display_audit[0].truncated = true;
    observed.display_audit[0].discarded = 3;
    let row = scoring::score(&row_entry, &Identities::default(), &observed);
    assert!(!row.display_audit_complete);
    assert_eq!(row.display_audit_discarded, 3);
    Ok(())
}
