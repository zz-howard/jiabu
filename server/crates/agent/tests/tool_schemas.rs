//! Offline guard for strict function calling: a tool schema change fails CI, not live
//! chat. Upstream rejects the whole request when a `strict` tool's schema leaves a
//! property out of `required` (ai-layer 4.2), so strict is sent only when compatible.
use jiabu_ai::siwc::request::strict_compatible;
/// Optional fields are not rewritten as required-but-nullable (in patch tools null
/// clears and omission keeps), so these are sent `strict: false`. A new tool must be
/// strict-compatible or be added here deliberately.
const NON_STRICT: [&str; 19] = [
    "ask_user",
    "create_account",
    "create_document",
    "create_record",
    "create_subject",
    "create_tag",
    "document_metric_series",
    "list_accounts",
    "list_subjects",
    "list_tags",
    "query_balance",
    "query_stats",
    "search_documents",
    "search_records",
    "set_allocation_plan",
    "update_account",
    "update_document",
    "update_record",
    "update_subject",
];
#[test]
fn every_agent_tool_is_strict_compatible_or_explicitly_non_strict() {
    let registry = jiabu_tools::builtin_registry();
    let mut non_strict: Vec<&str> = registry
        .agent_tools()
        .filter(|t| !strict_compatible(t.parameters()))
        .map(|t| t.name())
        .collect();
    non_strict.sort_unstable();
    let mut expected = NON_STRICT.to_vec();
    expected.sort_unstable();
    assert_eq!(non_strict, expected);
}
#[test]
fn agent_tool_schemas_are_snapshotted() {
    let registry = jiabu_tools::builtin_registry();
    for tool in registry.agent_tools() {
        insta::assert_json_snapshot!(tool.name(), tool.parameters());
    }
}
