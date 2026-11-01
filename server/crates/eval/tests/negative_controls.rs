use ai_eval::{
    dataset::{self, Behavior, RecordSpec},
    fixture::{Scenario, invoke},
    judge::{self, JudgeOutcome, JudgeVote},
    mock::{self, Identities},
    scoring::{self, Observation, Questions},
};
use anyhow::{Context, Result};
use jiabu_ai::Usage;
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
        baseline: json!({"currency":"CNY","records":[],"events":[]}),
        final_state: json!({"currency":"CNY","records":records,"events":events}),
        message: json!({"fallbackText":"","blocks":[]}),
        tool_calls: vec![],
        tool_results: Default::default(),
        balance_results: Default::default(),
        display_audit: vec![],
        display_audit_total: 0,
        display_audit_valid: 0,
        display_audit_discarded: 0,
        server_fallbacks: vec![],
        calls: vec![],
        tested_models: Default::default(),
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
    display_observation_for(entry, 0, message)
}

fn display_observation_for(
    entry: &dataset::Entry,
    alternative_index: usize,
    message: Value,
) -> Observation {
    let mut observation = observation(json!([]), json!([]));
    let alternative = &entry
        .expect
        .display
        .as_ref()
        .unwrap()
        .alternatives[alternative_index];
    observation.message = message;
    observation.tool_calls = alternative
        .source_calls
        .iter()
        .chain(&alternative.calls)
        .enumerate()
        .map(|(index, call)| {
            let args = if index < alternative.source_calls.len() {
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
    observation.display_audit = alternative
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
fn flexible_display_alternatives_are_complete_and_never_mixed() {
    let entry = display_entry("display-001.yaml");
    let prose = "虚构日常 68.00 元，虚构储备 32.00 元。";
    let message = json!({
        "fallbackText": prose,
        "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
    });
    let row = scoring::score(
        &entry,
        &Identities::default(),
        &display_observation_for(&entry, 3, message),
    );
    assert!(row.display_pass, "{:?}", row.reasons);
    assert_eq!(row.display_selected, "prose");
    assert_eq!(row.display_acceptable, "breakdown,bars,metrics,prose");

    let invented = "虚构日常 68.00 元，虚构储备 32.00 元，另有 1.00 元。";
    let message = json!({
        "fallbackText": invented,
        "blocks":[{"type":"markdown","data":{"text":invented},"fallbackText":invented}]
    });
    assert!(!scoring::score(
        &entry,
        &Identities::default(),
        &display_observation_for(&entry, 3, message),
    )
    .display_pass);

    let swapped = "虚构日常 32.00 元；虚构储备 68.00 元。";
    let message = json!({
        "fallbackText": swapped,
        "blocks":[{"type":"markdown","data":{"text":swapped},"fallbackText":swapped}]
    });
    assert!(!scoring::score(
        &entry,
        &Identities::default(),
        &display_observation_for(&entry, 3, message),
    )
    .display_pass);

    let mixed = json!({"fallbackText":"ok","blocks":[{
        "type":"metric_group",
        "data":{"metrics":[
            {"label":"虚构日常","value":6800},
            {"label":"虚构储备","value":3200}
        ]},
        "fallbackText":"ok"
    }]});
    assert!(!scoring::score(
        &entry,
        &Identities::default(),
        &display_observation_for(&entry, 1, mixed),
    )
    .display_pass);
}

#[test]
fn balance_prose_requires_sanitized_target_currency_and_value_evidence() {
    let entry = display_entry("display-015.yaml");
    let account_id = uuid::Uuid::parse_str("00000000-0000-7000-8000-000000000015").unwrap();
    let mut ids = Identities::default();
    ids.accounts.insert("bank".into(), account_id);
    let prose = "虚构银行卡余额为 -68.00 元。";
    let message = json!({
        "fallbackText":prose,
        "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
    });
    let mut observed = display_observation_for(&entry, 1, message);
    observed.balance_results.insert(
        "source-0".into(),
        scoring::BalanceResult {
            currency: "CNY".into(),
            balances: vec![(account_id.to_string(), -6800)],
        },
    );
    let row = scoring::score(&entry, &ids, &observed);
    assert!(row.display_pass, "{:?}", row.reasons);
    assert_eq!(row.display_selected, "prose");
    let judge_input = judge::JudgeInput::from_observation(&entry, &observed, &row)
        .expect("display-015 prose judge input");
    assert_eq!(judge_input.actual_candidate["visible_prose"], prose);
    assert_eq!(
        judge_input.actual_candidate["rendered_blocks"],
        json!([{ "type":"markdown", "data":{"text":prose} }])
    );
    assert_eq!(
        judge_input.actual_candidate["source_balance_results"],
        json!([{
            "call_id":"source-0","currency":"CNY","balances":[[account_id.to_string(),-6800]]
        }])
    );

    let mut wrong_currency = observed.clone();
    wrong_currency
        .balance_results
        .get_mut("source-0")
        .unwrap()
        .currency = "USD".into();
    assert!(!scoring::score(&entry, &ids, &wrong_currency).display_pass);
    let mut wrong_balance = observed.clone();
    wrong_balance
        .balance_results
        .get_mut("source-0")
        .unwrap()
        .balances[0]
        .1 = -6700;
    assert!(!scoring::score(&entry, &ids, &wrong_balance).display_pass);
    let mut wrong_account = observed.clone();
    wrong_account
        .balance_results
        .get_mut("source-0")
        .unwrap()
        .balances[0]
        .0 = uuid::Uuid::nil().to_string();
    assert!(!scoring::score(&entry, &ids, &wrong_account).display_pass);
    let mut failed = observed.clone();
    failed.tool_results.insert("source-0".into(), false);
    assert!(!scoring::score(&entry, &ids, &failed).display_pass);
    let mut missing = observed.clone();
    missing.balance_results.clear();
    assert!(!scoring::score(&entry, &ids, &missing).display_pass);
    let extra = "虚构银行卡余额为 -68.00 元，另一个余额为 1.00 元。";
    let mut invented = observed;
    invented.message = json!({
        "fallbackText":extra,
        "blocks":[{"type":"markdown","data":{"text":extra},"fallbackText":extra}]
    });
    assert!(!scoring::score(&entry, &ids, &invented).display_pass);
}

fn alternative_message(entry: &dataset::Entry, index: usize) -> Value {
    let alternative = &entry.expect.display.as_ref().unwrap().alternatives[index];
    if alternative.blocks.is_empty() {
        let prose = alternative
            .facts
            .iter()
            .map(|fact| match fact {
                dataset::DisplayFact::Aggregate { label, value_minor } => {
                    format!("{label} {:.2} 元", *value_minor as f64 / 100.0)
                }
                dataset::DisplayFact::Record {
                    date,
                    record_kind,
                    amount_minor,
                    account,
                    purpose,
                    note,
                    ..
                } => {
                    let name = |alias: &Option<String>| {
                        alias
                            .as_ref()
                            .and_then(|alias| {
                                entry
                                    .setup
                                    .accounts
                                    .iter()
                                    .find(|account| account.key == *alias)
                            })
                            .map(|account| account.name.clone())
                            .unwrap_or_default()
                    };
                    format!(
                        "{date} {record_kind} {} {} {:.2} 元 {}",
                        name(account),
                        name(purpose),
                        *amount_minor as f64 / 100.0,
                        note.as_deref().unwrap_or_default()
                    )
                }
                dataset::DisplayFact::NoData => "本月没有记录。".into(),
                dataset::DisplayFact::AccountBalance { .. } => unreachable!(),
            })
            .collect::<Vec<_>>()
            .join("；");
        return json!({
            "fallbackText": prose,
            "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
        });
    }
    let blocks = alternative
        .blocks
        .iter()
        .map(|expected| {
            let data = match expected.kind.as_str() {
                "metric" => json!({
                    "label":expected.labels[0],
                    "value":expected.values_minor[0]
                }),
                "metric_group" => json!({"metrics":expected.labels.iter().zip(&expected.values_minor).map(|(label,value)|json!({"label":label,"value":value})).collect::<Vec<_>>()}),
                "breakdown" => json!({"parts":expected.labels.iter().zip(&expected.values_minor).map(|(label,value)|json!({"label":label,"value":value})).collect::<Vec<_>>()}),
                "category_series" => json!({"points":expected.labels.iter().zip(&expected.values_minor).map(|(label,value)|json!({"label":label,"value":value})).collect::<Vec<_>>()}),
                "time_series" => json!({"yUnit":"元","series":[{"points":expected.labels.iter().zip(&expected.values_minor).map(|(label,value)|json!({"x":label,"y":*value as f64/100.0})).collect::<Vec<_>>()}]}),
                "dataset" if expected.labels.first().is_some_and(|label| label.starts_with("2026-")) => json!({
                    "columns":[{"key":"date"},{"key":"kind"},{"key":"amount"},{"key":"purpose"},{"key":"account"},{"key":"note"}],
                    "rows":expected.labels.iter().zip(&expected.values_minor).map(|(date,amount)| {
                        let fact = alternative.facts.iter().find_map(|fact| match fact {
                            dataset::DisplayFact::Record { date: fact_date, record_kind, account, purpose, note, .. }
                                if fact_date.to_string() == date.as_str() => Some((record_kind, account, purpose, note)),
                            _ => None,
                        }).expect("record fact");
                        let name = |alias: &Option<String>| alias.as_ref().and_then(|alias| {
                            entry.setup.accounts.iter().find(|candidate| candidate.key == *alias)
                        }).map(|candidate| candidate.name.clone());
                        json!({"date":date,"kind":fact.0,"amount":amount,"account":name(fact.1),"purpose":name(fact.2),"note":fact.3})
                    }).collect::<Vec<_>>()
                }),
                "dataset" => json!({"columns":[{"key":"label"}],"rows":expected.labels.iter().zip(&expected.values_minor).map(|(label,value)|json!({"label":label,"value":value})).collect::<Vec<_>>()}),
                other => panic!("unsupported test block {other}"),
            };
            json!({"type":expected.kind,"data":data,"fallbackText":"ok"})
        })
        .collect::<Vec<_>>();
    json!({"fallbackText":alternative.fallback_contains.join("；"),"blocks":blocks})
}

#[test]
fn every_declared_flexible_path_passes_its_complete_contract() {
    for (name, skip) in [
        ("display-001.yaml", None),
        ("display-004.yaml", None),
        ("display-005.yaml", None),
        ("display-008.yaml", None),
        ("display-013.yaml", None),
        ("display-014.yaml", None),
        ("display-015.yaml", Some(1)),
        ("display-016.yaml", None),
        ("display-018.yaml", None),
        ("display-020.yaml", None),
    ] {
        let entry = display_entry(name);
        for index in 0..entry.expect.display.as_ref().unwrap().alternatives.len() {
            if skip == Some(index) {
                continue;
            }
            let mut observed = display_observation_for(
                &entry,
                index,
                alternative_message(&entry, index),
            );
            observed.server_fallbacks = entry.expect.display.as_ref().unwrap().alternatives[index]
                .server_fallback_contains
                .clone();
            let row = scoring::score(&entry, &Identities::default(), &observed);
            assert!(row.display_pass, "{}[{index}] {:?}", entry.id, row.reasons);
            assert_eq!(
                row.display_selected,
                entry.expect.display.as_ref().unwrap().alternatives[index].id
            );
        }
    }
}

#[test]
fn record_blocks_require_complete_typed_facts_and_reject_conflicting_markdown() {
    let entry = display_entry("display-005.yaml");
    let valid = alternative_message(&entry, 0);
    assert!(
        scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, valid.clone()),
        )
        .display_pass
    );
    for pointer in [
        "/blocks/0/data/rows/0/kind",
        "/blocks/0/data/rows/0/account",
        "/blocks/0/data/rows/0/purpose",
    ] {
        let mut missing = valid.clone();
        *missing.pointer_mut(pointer).unwrap() = Value::Null;
        assert!(
            !scoring::score(
                &entry,
                &Identities::default(),
                &display_observation(&entry, missing),
            )
            .display_pass,
            "missing typed field survived: {pointer}"
        );
    }
    let mut conflict = valid;
    conflict["blocks"].as_array_mut().unwrap().push(json!({
        "type":"markdown",
        "data":{"text":"这些其实都是收入。"},
        "fallbackText":"这些其实都是收入。"
    }));
    assert!(
        !scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, conflict),
        )
        .display_pass
    );
}

#[test]
fn record_kind_is_bound_to_each_row_and_conflicts_are_rejected() {
    let entry = display_entry("display-005.yaml");
    let score = |prose: &str| {
        let message = json!({
            "fallbackText":prose,
            "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
        });
        scoring::score(
            &entry,
            &Identities::default(),
            &display_observation_for(&entry, 1, message),
        )
    };
    let correct = "支出明细\n2026-10-03 支出 虚构银行卡 虚构日常 30.00 元\n2026-10-02 支出 虚构银行卡 虚构日常 20.00 元\n2026-10-01 支出 虚构银行卡 虚构日常 10.00 元";
    assert!(score(correct).display_pass);
    assert!(!score(&correct.replace("2026-10-03 支出", "2026-10-03 收入")).display_pass);
    assert!(
        !score(&correct.replace("2026-10-03 支出", "2026-10-03 支出、收入")).display_pass
    );
}

#[test]
fn prose_money_accepts_trimmed_decimals_and_deduplicates_symbol_plus_unit() {
    let entry = display_entry("display-019.yaml");
    for prose in ["本月总支出：68 元。", "本月总支出 ¥68.00 元"] {
        let message = json!({
            "fallbackText":prose,
            "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
        });
        let row = scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message),
        );
        assert!(row.display_pass, "{prose}: {:?}", row.reasons);
    }
    let wrong = "本月总支出：69 元。";
    let message = json!({
        "fallbackText":wrong,
        "blocks":[{"type":"markdown","data":{"text":wrong},"fallbackText":wrong}]
    });
    assert!(
        !scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message),
        )
        .display_pass
    );
}

#[test]
fn prose_only_mock_uses_typed_facts_and_wrong_value_is_rejected() -> Result<()> {
    use jiabu_ai::{mock::MockStep, types::TurnEvent};

    let entry = display_entry("display-019.yaml");
    let scripts = mock::scripts(&entry, &Identities::default())?;
    let prose = scripts
        .last()
        .and_then(|script| script.first())
        .and_then(|step| match step {
            MockStep::Emit(TurnEvent::TextDelta(text)) => Some(text.as_str()),
            _ => None,
        })
        .context("prose-only mock text")?;
    assert_eq!(prose, "本月总支出 68.00 元");

    let score = |text: &str| {
        let message = json!({
            "fallbackText":text,
            "blocks":[{"type":"markdown","data":{"text":text},"fallbackText":text}]
        });
        scoring::score(
            &entry,
            &Identities::default(),
            &display_observation(&entry, message),
        )
    };
    assert!(score(prose).display_pass);
    assert!(!score(&prose.replace("68.00", "69.00")).display_pass);
    Ok(())
}

#[test]
fn component_mock_does_not_echo_typed_facts_as_prose() -> Result<()> {
    use jiabu_ai::{mock::MockStep, types::TurnEvent};

    let entry = display_entry("display-016.yaml");
    let scripts = mock::scripts(&entry, &Identities::default())?;
    let prose = scripts
        .last()
        .and_then(|script| script.first())
        .and_then(|step| match step {
            MockStep::Emit(TurnEvent::TextDelta(text)) => Some(text.as_str()),
            _ => None,
        })
        .context("component mock trailing text")?;
    assert_eq!(prose, "已展示。");
    assert!(!prose.contains("虚构日常"));
    assert!(!prose.contains("68.00"));
    Ok(())
}

#[test]
fn no_data_prose_accepts_natural_zero_and_rejects_conflicting_semantics() {
    let entry = display_entry("display-008.yaml");
    let score = |prose: &str| {
        let message = json!({
            "fallbackText":prose,
            "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
        });
        scoring::score(
            &entry,
            &Identities::default(),
            &display_observation_for(&entry, 1, message),
        )
    };
    assert!(score("本月支出为 0 元。").display_pass);
    for prose in [
        "本月支出为 1 元。",
        "本月存在记录，支出为 0 元。",
        "演示数据：本月支出为 0 元。",
        "图表示例：本月支出为 0 元。",
    ] {
        assert!(!score(prose).display_pass, "{prose}");
    }
}

#[test]
fn closest_failed_alternative_ties_use_fixture_order() {
    let mut entry = display_entry("display-003.yaml");
    let mut second = entry.expect.display.as_ref().unwrap().alternatives[0].clone();
    entry.expect.display.as_mut().unwrap().alternatives[0].id = "first".into();
    second.id = "second".into();
    entry.expect.display.as_mut().unwrap().alternatives.push(second);
    let wrong = json!({"fallbackText":"ok","blocks":[]});
    let row = scoring::score(
        &entry,
        &Identities::default(),
        &display_observation(&entry, wrong),
    );
    assert!(!row.display_pass);
    assert_eq!(row.display_selected, "first");
    assert_eq!(row.display_acceptable, "first,second");
}

#[test]
fn alternative_report_is_sanitized_and_contains_only_ids() -> Result<()> {
    let entry = display_entry("display-001.yaml");
    let prose = "虚构日常 68.00 元；虚构储备 32.00 元。";
    let message = json!({
        "fallbackText":prose,
        "blocks":[{"type":"markdown","data":{"text":prose},"fallbackText":prose}]
    });
    let row = scoring::score(
        &entry,
        &Identities::default(),
        &display_observation_for(&entry, 3, message),
    );
    let dir = std::env::temp_dir().join(format!(
        "jiabu-eval-alternative-report-{}",
        uuid::Uuid::now_v7()
    ));
    ai_eval::report::write(&dir, &[row])?;
    let results = std::fs::read_to_string(dir.join("results.csv"))?;
    assert!(results.contains("breakdown,bars,metrics,prose"));
    assert!(results.contains("\"prose\""));
    assert!(!results.contains(&entry.input.text));
    assert!(!results.contains(prose));
    std::fs::remove_dir_all(dir)?;
    Ok(())
}

#[test]
fn judge_report_allowlist_excludes_request_prose_and_usage() -> Result<()> {
    let input = judge::JudgeInput {
        schema_version: 2,
        locale: "en-US".into(),
        user_request: "raw-user-request-sentinel".into(),
        today: "2026-10-21".into(),
        timezone: "Asia/Shanghai".into(),
        as_of: "2026-10-21T12:00:00Z".into(),
        test_reference: json!({"currency":"CNY","amount_unit":"minor","fact_sets":[],"baseline_records":[]}),
        actual_candidate: json!({"status":"completed","visible_prose":"raw-visible-prose-sentinel","rendered_blocks":[],"source_calls":[]}),
        supporting_fallback_evidence: json!({}),
        client_capabilities: json!({}),
    };
    let serialized_input = serde_json::to_string(&input)?;
    assert!(serialized_input.contains("raw-user-request-sentinel"));
    assert!(serialized_input.contains("raw-visible-prose-sentinel"));
    let mut row = scoring::score(
        &ambiguity(),
        &Identities::default(),
        &observation(json!([]), json!([])),
    );
    row.tested_models.insert("synthetic/candidate-z".into());
    row.tested_models.insert("synthetic/candidate-a".into());
    let vote = JudgeVote {
        expectation_met: true,
    };
    judge::apply(
        &mut row,
        JudgeOutcome {
            model_snapshot: "synthetic/model@00000000-0000-0000-0000-000000000000".into(),
            self_judge: false,
            votes: vec![vote.clone(), vote.clone(), vote],
            pass_votes: 3,
            fail_votes: 0,
            pass: true,
            usage: vec![Usage {
                input_tokens: 987_654,
                output_tokens: 123_456,
                cached_input_tokens: 456_789,
                cache_write_tokens: 111_111,
            }],
        },
    )?;
    let dir = std::env::temp_dir().join(format!(
        "jiabu-eval-judge-report-{}",
        uuid::Uuid::now_v7()
    ));
    ai_eval::report::write(&dir, &[row])?;
    let results = std::fs::read_to_string(dir.join("results.csv"))?;
    let summary = std::fs::read_to_string(dir.join("summary.csv"))?;
    for forbidden in [
        "raw-user-request-sentinel",
        "raw-visible-prose-sentinel",
        "987654",
        "123456",
        "456789",
        "111111",
    ] {
        assert!(!results.contains(forbidden));
        assert!(!summary.contains(forbidden));
    }
    let judge_columns = ai_eval::report::RESULTS_HEADER
        .iter()
        .filter(|column| column.starts_with("judge_"))
        .copied()
        .collect::<Vec<_>>();
    assert_eq!(
        judge_columns,
        [
            "judge_model",
            "judge_self",
            "judge_pass_votes",
            "judge_fail_votes",
            "judge_votes_json",
        ]
    );
    for expected in [
        "judge.core.pass_rate",
        "judge.pass_votes",
        "judge.fail_votes",
        "judge.total_votes",
        "judge.self_judge_count",
        "judge.tested_models_json",
        "judge.ranking_models_json",
        "synthetic/candidate-a",
        "synthetic/candidate-z",
        "synthetic/model@00000000-0000-0000-0000-000000000000",
    ] {
        assert!(summary.contains(expected));
    }
    assert!(summary.contains("\"judge.core.pass_rate\",\"1\",\"1\",\"1\""));
    assert!(summary.contains("\"judge.pass_votes\",\"3\""));
    assert!(summary.contains("\"judge.fail_votes\",\"0\""));
    assert!(summary.contains("\"judge.total_votes\",\"3\""));
    assert!(summary.contains("\"judge.self_judge_count\",\"0\""));
    assert!(summary.contains(
        "\"judge.tested_models_json\",\"[\"\"synthetic/candidate-a\"\",\"\"synthetic/candidate-z\"\"]\""
    ));
    std::fs::remove_dir_all(dir)?;
    Ok(())
}

#[test]
fn judge_failure_preserves_the_deterministic_hard_gate() -> Result<()> {
    let entry = display_entry("display-003.yaml");
    let message = json!({"fallbackText":"ok","blocks":[{
        "type":"metric",
        "data":{"label":"2026年10月支出","value":9900},
        "fallbackText":"2026年10月支出：99.00 元"
    }]});
    let mut row = scoring::score(
        &entry,
        &Identities::default(),
        &display_observation(&entry, message),
    );
    assert!(row.hard_pass);
    assert!(row.display_pass);
    let fail_vote = JudgeVote {
        expectation_met: false,
    };
    let pass_vote = JudgeVote {
        expectation_met: true,
    };
    judge::apply(
        &mut row,
        JudgeOutcome {
            model_snapshot: "synthetic/judge@1".into(),
            self_judge: false,
            votes: vec![fail_vote.clone(), fail_vote, pass_vote],
            pass_votes: 1,
            fail_votes: 2,
            pass: false,
            usage: vec![],
        },
    )?;
    assert!(row.hard_pass);
    assert_eq!(row.expectation_met, Some(false));
    assert!(row.display_pass, "legacy diagnostic remains independent");
    assert!(!row.overall_pass());
    assert_eq!(scoring::exit_code(std::slice::from_ref(&row)), 1);
    let dir = std::env::temp_dir().join(format!(
        "jiabu-eval-judge-layering-{}",
        uuid::Uuid::now_v7()
    ));
    ai_eval::report::write(&dir, &[row])?;
    let summary = std::fs::read_to_string(dir.join("summary.csv"))?;
    assert!(summary.contains("\"tier.core.hard_pass\",\"1\",\"1\",\"1\""));
    assert!(summary.contains("\"judge.core.pass_rate\",\"0\",\"0\",\"1\""));
    assert!(summary.contains("\"hard_failure_count\",\"0\""));
    std::fs::remove_dir_all(dir)?;
    Ok(())
}

#[test]
fn summary_keeps_tested_models_when_hard_gate_skips_every_judge() -> Result<()> {
    let event = json!({
        "id":1,
        "entity_kind":"record",
        "entity_id":"fake",
        "kind":"create",
        "after":{"id":"fake","amount_minor":1800,"occurred_on":"2026-03-04"}
    });
    let mut row = scoring::score(
        &ambiguity(),
        &Identities::default(),
        &observation(json!([event]), json!([])),
    );
    assert!(!row.hard_pass);
    assert!(row.judge_self.is_none());
    row.tested_models.insert("synthetic/candidate-only".into());
    let dir = std::env::temp_dir().join(format!(
        "jiabu-eval-unjudged-model-report-{}",
        uuid::Uuid::now_v7()
    ));
    ai_eval::report::write(&dir, &[row])?;
    let summary = std::fs::read_to_string(dir.join("summary.csv"))?;
    assert!(summary.contains("\"judge.core.pass_rate\",\"\",\"0\",\"0\""));
    assert!(summary.contains("synthetic/candidate-only"));
    assert!(summary.contains("\"judge.ranking_models_json\",\"[]\""));
    std::fs::remove_dir_all(dir)?;
    Ok(())
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
    let mut aggregate_total = display_observation(&fallback, json!({"fallbackText":"","blocks":[]}));
    aggregate_total.server_fallbacks = vec![
        "虚构日常 ¥68.00；虚构储备 ¥32.00；合计 ¥100.00".into(),
    ];
    assert!(
        scoring::score(&fallback, &Identities::default(), &aggregate_total).display_pass,
        "the exact aggregate sum is a valid server fallback total"
    );
    for wrong in [
        "虚构日常 ¥68.00；虚构储备 ¥32.00；合计 ¥101.00",
        "虚构日常 ¥68.00；虚构储备 ¥32.00；合计 ¥100.00；其他 ¥1.00",
    ] {
        let mut extra = aggregate_total.clone();
        extra.server_fallbacks = vec![wrong.into()];
        assert!(
            !scoring::score(&fallback, &Identities::default(), &extra).display_pass,
            "wrong or additional server fallback amount survived: {wrong}"
        );
    }

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
    let account_result = json!({
        "display":"account_card",
        "status":"shown",
        "title":"虚构银行卡",
        "demo":false,
        "currency":"CNY",
        "measure":"sum",
        "total":-6800,
        "items":[],
        "rows":[],
        "account_card":{
            "account_id":account_id,
            "version_at_reply":1,
            "name_snapshot":"虚构银行卡",
            "balance_minor":-6800,
            "archived":false
        },
        "has_more":false,
        "groups_may_overlap":false
    });
    let (account_kind, account_data, account_fallback) = jiabu_chat::map_tool_result(
        "show_account_card",
        &json!({}),
        &account_result,
    )
    .expect("account mapper")
    .expect("account component");
    assert_eq!(account_kind, "x-jiabu.account_card");
    let mut account_observation = display_observation(
        &account,
        json!({"fallbackText":account_fallback.clone(),"blocks":[{
            "type":account_kind,
            "data":account_data,
            "fallbackText":account_fallback.clone()
        }]}),
    );
    account_observation.tool_calls[0]["args"]["account_id"] = json!(account_id);
    account_observation.server_fallbacks = vec![account_fallback];
    let account_row = scoring::score(&account, &identities, &account_observation);
    assert!(account_row.display_pass);
    assert_eq!(account_row.display_selected, "exact");
    let judge_input =
        judge::JudgeInput::from_observation(&account, &account_observation, &account_row)
            .expect("display-007 judge input");
    assert_eq!(
        judge_input.actual_candidate["rendered_blocks"][0],
        json!({
            "type":"x-jiabu.account_card", "data":account_observation.message["blocks"][0]["data"]
        })
    );
    assert!(
        judge_input.actual_candidate["rendered_blocks"][0]["data"]
            .get("balance_minor")
            .is_none()
    );
    assert_eq!(
        judge_input.actual_candidate["source_balance_results"],
        json!([])
    );
    assert_eq!(judge_input.actual_candidate["visible_prose"], "");
    assert_eq!(
        judge_input.supporting_fallback_evidence["server_fallbacks"],
        json!(["虚构银行卡：-¥68.00"])
    );
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
    assert!(unresolved.hard_pass);
    assert_eq!(unresolved.rule_decision, scoring::RuleDecision::NeedsJudge);
    assert_eq!(unresolved.expectation_met, None);
}

#[test]
fn actual_invalid_arguments_remain_rule_failures_without_legacy_business_error_preferences() {
    let mut entry = display_entry("display-003.yaml");
    let display = entry.expect.display.as_mut().unwrap();
    display.alternatives[0].expected_invalid_calls = 1;
    display.alternatives[0].expected_business_errors = 1;
    let message = json!({"fallbackText":"ok","blocks":[{"type":"metric","data":{"label":"2026年10月支出","value":9900},"fallbackText":"ok"}]});
    let mut observed = display_observation(&entry, message);
    observed.tool_total += 1;
    observed.business_errors = 1;
    assert!(scoring::score(&entry, &Identities::default(), &observed).display_pass);
    observed.business_errors = 0;
    let row = scoring::score(&entry, &Identities::default(), &observed);
    assert!(!row.display_pass);
    assert!(row.reasons.contains(&"rule_invalid_tool_arguments".into()));
    assert!(
        !row.reasons
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
    extra.tool_calls.push(json!({"tool":"show_metrics","call_id":"extra","args":entry.expect.display.as_ref().unwrap().alternatives[0].calls[0].args.clone()}));
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
    entry.expect.display.as_mut().unwrap().alternatives[0].calls[0].args["source"]["query"]["kinds"] =
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
    let message = alternative_message(&entry, 0);
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
    kinds_entry.expect.display.as_mut().unwrap().alternatives[0].calls[0].args["source"]["query"]["kinds"] =
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
    text_entry.expect.display.as_mut().unwrap().alternatives[0].calls[0].args["source"]["query"]["text"] =
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
fn internal_style_preferences_never_decide_expectation_or_appear_in_rule_reasons() {
    let mut entry = display_entry("display-001.yaml");
    entry
        .expect
        .display
        .as_mut()
        .unwrap()
        .prose
        .forbid_numeric_restatement = true;
    for prose in [
        "68.00",
        "68 元",
        "¥68",
        "6800 分",
        "68.00，32.00。第二句。第三句。",
    ] {
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
        assert_eq!(row.rule_decision, scoring::RuleDecision::NeedsJudge);
        assert_eq!(row.expectation_met, None);
        assert!(row.reasons.is_empty());
        assert!(!row.overall_pass());
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
    row_entry.expect.display.as_mut().unwrap().alternatives[0].calls[0].args["source"]["query"]["kinds"] =
        json!(vec!["expense"; 17]);
    let mut observed = display_observation(&row_entry, json!({"fallbackText":"","blocks":[]}));
    observed.display_audit[0].truncated = true;
    observed.display_audit[0].discarded = 3;
    let row = scoring::score(&row_entry, &Identities::default(), &observed);
    assert!(!row.display_audit_complete);
    assert_eq!(row.display_audit_discarded, 3);
    Ok(())
}
