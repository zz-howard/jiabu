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
    assert!(case("display-008").input.text.contains("本月没有记录"));
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
    assert_eq!(display.expected_invalid_calls, 0);
    assert_eq!(display.expected_business_errors, 0);
    assert_eq!(display.calls[0].tool, "show_bar_chart");
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
    let invalid = source.replace(
        "timezone: \"Asia/Shanghai\"",
        "timezone: \"Asia/Shanghai\"\ntier: impossible",
    );
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
    rejects(|entry| entry.expect.display.as_mut().unwrap().calls[0].tool = "bad_tool".into());
    rejects(|entry| entry.expect.display.as_mut().unwrap().blocks[0].kind = "bad_block".into());
    rejects(|entry| {
        entry.expect.display.as_mut().unwrap().blocks[0].values_minor[0] = i64::MIN;
    });
    rejects(|entry| entry.expect.display.as_mut().unwrap().blocks[0].demo = Some(true));
    rejects(|entry| {
        entry.client_capabilities = Some(dataset::ClientCapabilitiesSpec {
            blocks: [("markdown".into(), 1)].into_iter().collect(),
        });
    });
    rejects(|entry| {
        let display = entry.expect.display.as_mut().unwrap();
        display.blocks.clear();
        display.fallback_contains.clear();
    });
    rejects(|entry| entry.expect.behavior = dataset::Behavior::Write);
    rejects(|entry| {
        entry.expect.display.as_mut().unwrap().calls[0].args["source"]["from_call"] =
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
        .source_calls[0]
        .args["from_call"] = serde_json::json!("$call:source-0");
    assert!(dataset::validate(&invalid_source_alias, &root).is_err());
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
    let float = std::fs::read_to_string(root.join("entries/display-001.yaml"))?
        .replace("values_minor: [6800, 3200]", "values_minor: [68.5, 3200]");
    assert!(dataset::parse(&float).is_err());
    Ok(())
}
