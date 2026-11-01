use ai_eval::dataset;
#[test]
fn corpus_schema_coverage_presets_and_real_jpegs() -> anyhow::Result<()> {
    let entries = dataset::load(&ai_eval::dataset_root())?;
    assert_eq!(entries.len(), 84);
    for id in ["display-013", "display-014", "display-015", "display-016"] {
        assert_eq!(
            entries.iter().find(|entry| entry.id == id).unwrap().tier,
            dataset::EvaluationTier::Integration
        );
    }
    for id in [
        "display-009",
        "display-017",
        "en-ambiguous-008",
        "en-ambiguous-009",
    ] {
        assert_eq!(
            entries.iter().find(|entry| entry.id == id).unwrap().tier,
            dataset::EvaluationTier::Stress
        );
    }
    assert_eq!(
        entries
            .iter()
            .find(|entry| entry.id == "display-001")
            .unwrap()
            .tier,
        dataset::EvaluationTier::Core
    );
    let case = |id: &str| entries.iter().find(|entry| entry.id == id).unwrap();
    assert_eq!(
        case("display-006").input.text,
        "2026年5月到10月每个月分别花了多少？请用柱状图比较。"
    );
    assert_eq!(
        case("display-008").input.text,
        "我 2026 年 10 月花了多少钱？"
    );
    for id in ["display-013", "display-014", "display-015", "display-016"] {
        let prompt = &case(id).input.text;
        assert!(
            !prompt.contains("组件") && !prompt.contains("支持"),
            "{id}: {prompt}"
        );
    }
    assert!(case("display-009").input.text.contains("月度支出分类占比"));
    let replacement = case("display-018");
    assert_eq!(
        replacement
            .setup
            .records
            .iter()
            .map(|record| record.record.amount_minor.unwrap())
            .collect::<Vec<_>>(),
        vec![5000, 6800]
    );
    let display = replacement.expect.display.as_ref().unwrap();
    assert_eq!(display.alternatives[0].expected_invalid_calls, 0);
    assert_eq!(display.alternatives[0].expected_business_errors, 0);
    assert_eq!(display.alternatives[0].calls[0].tool, "show_bar_chart");
    for (id, expected) in [
        ("display-001", vec!["breakdown", "bars", "metrics", "prose"]),
        ("display-004", vec!["trend", "bars", "metrics", "prose"]),
        ("display-005", vec!["records", "prose"]),
        ("display-008", vec!["metric_no_data", "prose_no_data"]),
        ("display-013", vec!["metrics", "prose"]),
        ("display-014", vec!["dataset", "prose"]),
        ("display-015", vec!["metric", "prose"]),
        ("display-016", vec!["server_markdown", "prose"]),
        ("display-018", vec!["bars", "trend", "metrics", "prose"]),
        ("display-020", vec!["bars", "metrics", "prose"]),
    ] {
        assert_eq!(
            case(id)
                .expect
                .display
                .as_ref()
                .unwrap()
                .alternatives
                .iter()
                .map(|alternative| alternative.id.as_str())
                .collect::<Vec<_>>(),
            expected,
            "{id}"
        );
    }
    Ok(())
}
#[test]
fn rejects_duplicate_keys_multiple_documents_unknown_fields_and_non_string_keys() {
    for invalid in [
        "id: one\nid: two",
        "---\nid: one\n---\nid: two",
        "42: value",
        "id: &anchor value",
        "id: value\nunknown: field",
    ] {
        assert!(dataset::parse(invalid).is_err());
    }
}

#[test]
fn tier_defaults_to_core_and_rejects_unknown() {
    let source =
        std::fs::read_to_string(ai_eval::dataset_root().join("entries/display-001.yaml")).unwrap();
    assert_eq!(
        dataset::parse(&source).unwrap().tier,
        dataset::EvaluationTier::Core
    );
    assert!(!source.lines().any(|line| line.starts_with("tier:")));
    let invalid = format!("{source}\ntier: impossible\n");
    assert!(dataset::parse(&invalid).is_err());
}

#[test]
fn display_schema_rejects_cross_field_inconsistencies() -> anyhow::Result<()> {
    let root = ai_eval::dataset_root();
    let entries = dataset::load(&root)?;
    let index = entries
        .iter()
        .position(|entry| entry.id == "display-001")
        .expect("display fixture");
    let rejects = |mutate: fn(&mut dataset::Entry)| {
        let mut changed = entries.clone();
        mutate(&mut changed[index]);
        assert!(dataset::validate(&changed, &root).is_err());
    };
    rejects(|entry| entry.setup.accounts.push(entry.setup.accounts[0].clone()));
    rejects(|entry| {
        entry.expect.display.as_mut().unwrap().alternatives[0].calls[0].tool = "bad_tool".into()
    });
    rejects(|entry| {
        let duplicate = entry.expect.display.as_ref().unwrap().alternatives[0].clone();
        entry
            .expect
            .display
            .as_mut()
            .unwrap()
            .alternatives
            .push(duplicate);
    });
    rejects(|entry| {
        entry.expect.display.as_mut().unwrap().alternatives[0].blocks[0].kind = "bad_block".into()
    });
    rejects(|entry| {
        entry.expect.display.as_mut().unwrap().alternatives[0].blocks[0].values_minor[0] = i64::MIN;
    });
    rejects(|entry| {
        entry.expect.display.as_mut().unwrap().alternatives[0].blocks[0].demo = Some(true)
    });
    rejects(|entry| {
        entry.client_capabilities = Some(dataset::ClientCapabilitiesSpec {
            blocks: [("markdown".into(), 1)].into_iter().collect(),
        });
    });
    rejects(|entry| {
        let display = entry.expect.display.as_mut().unwrap();
        display.alternatives[0].blocks.clear();
        display.alternatives[0].fallback_contains.clear();
    });
    rejects(|entry| entry.expect.behavior = dataset::Behavior::Write);
    rejects(|entry| {
        entry.expect.display.as_mut().unwrap().alternatives[0].calls[0].args["source"]["from_call"] =
            serde_json::json!("$call:source-99");
    });
    let linked = entries
        .iter()
        .position(|entry| entry.id == "display-002")
        .expect("source-call fixture");
    let mut invalid_source_alias = entries.clone();
    invalid_source_alias[linked]
        .expect
        .display
        .as_mut()
        .unwrap()
        .alternatives[0]
        .source_calls[0]
        .args["from_call"] = serde_json::json!("$call:source-0");
    assert!(dataset::validate(&invalid_source_alias, &root).is_err());
    let balance = entries
        .iter()
        .position(|entry| entry.id == "display-015")
        .expect("balance fixture");
    let mut nonempty_balance = entries.clone();
    nonempty_balance[balance]
        .expect
        .display
        .as_mut()
        .unwrap()
        .alternatives[1]
        .source_calls[0]
        .args["account_id"] = serde_json::json!("$account:bank");
    assert!(dataset::validate(&nonempty_balance, &root).is_err());
    let mut v1_display = entries
        .iter()
        .find(|entry| entry.schema_version == 1)
        .expect("v1 fixture")
        .clone();
    v1_display.category = "display".into();
    let mut with_v1_display = entries.clone();
    with_v1_display[0] = v1_display;
    assert!(dataset::validate(&with_v1_display, &root).is_err());
    let v1_record = entries
        .iter()
        .position(|entry| entry.schema_version == 1 && !entry.expect.records.is_empty())
        .expect("v1 record fixture");
    let mut v1_multi_tag = entries.clone();
    v1_multi_tag[v1_record].expect.records[0].preset_key = None;
    v1_multi_tag[v1_record].expect.records[0].preset_keys = vec!["dining".into()];
    assert!(dataset::validate(&v1_multi_tag, &root).is_err());
    let source = std::fs::read_to_string(root.join("entries/display-001.yaml"))?;
    let float = source.replacen("\n        - 6800\n", "\n        - 68.5\n", 1);
    assert_ne!(
        float, source,
        "float control must actually modify the fixture"
    );
    assert!(dataset::parse(&float).is_err());
    Ok(())
}
