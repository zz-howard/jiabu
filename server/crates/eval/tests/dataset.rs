use ai_eval::dataset;
#[test]
fn corpus_schema_coverage_presets_and_real_jpegs() -> anyhow::Result<()> {
    let entries = dataset::load(&ai_eval::dataset_root())?;
    assert_eq!(entries.len(), 64);
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
