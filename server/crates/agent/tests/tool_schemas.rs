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
#[test]
fn wire_strict_flags_are_snapshotted() {
    let registry = jiabu_tools::builtin_registry();
    let flags: std::collections::BTreeMap<_, _> = registry
        .agent_tools()
        .map(|t| (t.name(), strict_compatible(t.parameters())))
        .collect();
    insta::assert_json_snapshot!("strict_flags", flags);
}
fn prompt_display_tools(instructions: &str) -> Vec<&str> {
    instructions
        .lines()
        .find_map(|line| line.strip_prefix("DISPLAY_TOOLS: "))
        .into_iter()
        .flat_map(|line| line.split(',').map(str::trim))
        .filter(|name| !name.is_empty())
        .collect()
}
fn confirmation_block(instructions: &str) -> &str {
    let (_, rest) = instructions
        .split_once("\nGUARDED_CONFIRMATION\n")
        .expect("guarded confirmation block");
    rest.split_once("\nUI\n")
        .expect("UI follows guarded confirmation block")
        .0
}
fn prompt_guarded_tools(block: &str) -> Vec<&str> {
    block
        .lines()
        .find_map(|line| {
            line.split_once("Only these tools are guarded: ")
                .map(|(_, value)| value)
        })
        .and_then(|tools| tools.strip_suffix('.'))
        .into_iter()
        .flat_map(|tools| tools.split(',').map(str::trim))
        .filter(|name| !name.is_empty())
        .collect()
}
#[test]
fn rendered_static_prompt_matches_the_complete_golden() {
    let catalog = r#"[{"id":"fake-template","label":"虚构模板 / Fake template"}]"#.as_bytes();
    let rendered = jiabu_agent::render::static_instructions(catalog);
    assert_eq!(
        rendered,
        include_str!("golden/static-instructions.txt").trim_end_matches('\n')
    );
    assert_eq!(rendered.matches("\nGUARDED_CONFIRMATION\n").count(), 1);
    assert!(!rendered.contains("BEHAVIOR_RULES"));
    assert!(!rendered.contains("Capability downgrade and fallback are server-owned"));
    assert!(!rendered.contains("plain-text/text-only/no-card-or-chart"));
}
#[test]
fn guarded_confirmation_inventory_matches_the_live_registry() {
    let registry = jiabu_tools::builtin_registry();
    let instructions = jiabu_agent::render::static_instructions(b"[]");
    let prompt_names = prompt_guarded_tools(confirmation_block(&instructions));
    let registered_names: Vec<_> = registry
        .agent_tools()
        .filter_map(|tool| {
            let call = tool
                .validate(tool.example_args())
                .unwrap_or_else(|_| panic!("{} example args must validate", tool.name()));
            tool.requires_confirmation(call.as_ref())
                .then_some(tool.name())
        })
        .collect();
    assert_eq!(prompt_names, registered_names);
    for unguarded in [
        "restore_document",
        "update_account",
        "get_record",
        "create_record",
    ] {
        assert!(
            !prompt_names.contains(&unguarded),
            "{unguarded} is unguarded"
        );
    }
}
#[test]
fn guarded_confirmation_examples_have_frozen_shape_and_boundaries() {
    let instructions = jiabu_agent::render::static_instructions(b"[]");
    let block = confirmation_block(&instructions);
    let positives: Vec<_> = block
        .lines()
        .filter(|line| line.starts_with('P'))
        .collect();
    let negatives: Vec<_> = block
        .lines()
        .filter(|line| line.starts_with('N'))
        .collect();
    assert_eq!(positives.len(), 5);
    assert_eq!(negatives.len(), 2);
    assert!(
        "GUARDED_CONFIRMATION\n".chars().count() + block.chars().count() <= 1_450,
        "confirmation block exceeded the frozen size ceiling"
    );
    for (line, tool) in positives.iter().zip([
        "update_record",
        "void_record",
        "restore_record",
        "archive_account",
        "update_document",
    ]) {
        assert!(line.contains(tool), "missing {tool}: {line}");
        assert!(
            !line.contains("ask_user"),
            "positive example asks the user: {line}"
        );
    }
    assert!(negatives[0].contains("search/read"));
    assert!(negatives[0].contains("ask_user"));
    assert!(negatives[0].contains("Never invent id/version or call a write"));
    assert!(negatives[1].contains("create_record"));
    assert!(!negatives[1].contains("ask_user"));
    for guarded in prompt_guarded_tools(block) {
        assert!(
            !negatives[1].contains(&format!("=> {guarded}(")),
            "create counterexample calls guarded tool {guarded}"
        );
    }
    assert!(block.contains("Never call ask_user merely to ask “confirm?”"));
}
fn description_contract(tool: &dyn jiabu_tools::AgentTool, description: &str) -> bool {
    let headings = ["\n何时用：", "\n何时别用：", "\n例："];
    if headings
        .iter()
        .any(|heading| description.matches(heading).count() != 1)
    {
        return false;
    }
    let positions: Vec<_> = headings
        .iter()
        .filter_map(|heading| description.find(heading))
        .collect();
    if !positions.windows(2).all(|pair| pair[0] < pair[1]) {
        return false;
    }
    let Some(example) = description.split_once("\n例：").map(|(_, value)| value) else {
        return false;
    };
    serde_json::from_str(example)
        .ok()
        .is_some_and(|args| tool.validate(args).is_ok())
}
#[test]
fn display_prompt_descriptions_and_strict_schemas_match_the_registry() {
    let registry = jiabu_tools::builtin_registry();
    let display: Vec<_> = registry
        .agent_tools()
        .filter(|tool| jiabu_tools::is_display_tool(tool.name()))
        .collect();
    let instructions = jiabu_agent::render::static_instructions(b"[]");
    assert_eq!(instructions.matches("\nDISPLAY_TOOLS: ").count(), 1);
    let mut prompt_names = prompt_display_tools(&instructions);
    let mut registered_names: Vec<_> = display.iter().map(|tool| tool.name()).collect();
    prompt_names.sort_unstable();
    registered_names.sort_unstable();
    assert_eq!(prompt_names, registered_names);
    // Negative control: the comparison notices a newly registered but unguided tool.
    let mut added = registered_names.clone();
    added.push("show_future");
    added.sort_unstable();
    assert_ne!(prompt_names, added);
    for tool in display {
        assert!(
            description_contract(tool, tool.description()),
            "{} description is missing guidance or a valid example",
            tool.name()
        );
        assert!(
            strict_compatible(tool.parameters()),
            "{} display schema must remain strict-compatible",
            tool.name()
        );
    }
}
#[test]
fn display_description_contract_rejects_missing_sections_and_bad_examples() {
    let registry = jiabu_tools::builtin_registry();
    let tool = registry.get("show_metrics").expect("show_metrics");
    let description = tool.description();
    for heading in ["\n何时用：", "\n何时别用：", "\n例："] {
        assert!(!description_contract(
            tool,
            &description.replacen(heading, "\n", 1)
        ));
    }
    let prefix = description.split_once("\n例：").expect("example").0;
    assert!(!description_contract(
        tool,
        &format!("{prefix}\n例：not-json")
    ));
    assert!(!description_contract(tool, &format!("{prefix}\n例：{{}}")));
    assert!(!description_contract(
        tool,
        &description
            .replace("\n何时用：", "\nTEMP：")
            .replace("\n何时别用：", "\n何时用：")
            .replace("\nTEMP：", "\n何时别用：")
    ));
}
#[test]
fn schema_violations_name_the_field_and_keyword_without_values() {
    let registry = jiabu_tools::builtin_registry();
    let tool = registry.get("create_record").expect("create_record");
    let issues = |args: serde_json::Value| -> Vec<(String, String)> {
        match tool.validate(args) {
            Ok(_) => vec![],
            Err(error) => error
                .errors
                .unwrap_or_default()
                .into_iter()
                .map(|i| (i.pointer, i.rule))
                .collect(),
        }
    };
    let wrong = issues(serde_json::json!({
        "kind":"expense","amount_minor":"十八元","occurred_on":"2026-01-01","surprise":1
    }));
    assert!(
        wrong.contains(&("/amount_minor".into(), "type".into())),
        "{wrong:?}"
    );
    assert!(
        wrong.contains(&("/surprise".into(), "unknown_property".into())),
        "{wrong:?}"
    );
    assert!(!format!("{wrong:?}").contains("十八元"));
    // A made-up property name may carry user text; only identifier-shaped names survive.
    let invented = issues(serde_json::json!({
        "kind":"expense","amount_minor":1800,"occurred_on":"2026-01-01","我的备注 secret":1
    }));
    assert_eq!(invented, vec![("/*".into(), "unknown_property".into())]);
    let missing = issues(serde_json::json!({}));
    assert!(
        missing.contains(&("/kind".into(), "required".into())),
        "{missing:?}"
    );
    // Negative control: valid arguments report nothing.
    assert!(
        issues(
            serde_json::json!({"kind":"expense","amount_minor":1800,"occurred_on":"2026-01-01"})
        )
        .is_empty()
    );
}
