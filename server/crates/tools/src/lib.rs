//! The single module authorization entry point.
use jiabu_db::{ActiveMember, GrantLevel};
use jiabu_domain::NotFound;
#[derive(Clone, Copy)]
pub enum Module {
    Ledger,
    Documents,
}
#[derive(Clone, Copy)]
pub enum Action {
    Read,
    Write,
    Manage,
}
fn permits(level: GrantLevel, action: Action) -> Result<(), NotFound> {
    let required = match action {
        Action::Read => GrantLevel::Read,
        Action::Write => GrantLevel::Write,
        Action::Manage => GrantLevel::Manage,
    };
    if level >= required {
        Ok(())
    } else {
        Err(NotFound)
    }
}
pub fn authorize(member: &ActiveMember, module: Module, action: Action) -> Result<(), NotFound> {
    permits(
        match module {
            Module::Ledger => member.ledger_grant(),
            Module::Documents => member.documents_grant(),
        },
        action,
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn authorization_matrix() {
        for (i, level) in [
            GrantLevel::None,
            GrantLevel::Read,
            GrantLevel::Write,
            GrantLevel::Manage,
        ]
        .into_iter()
        .enumerate()
        {
            for (j, action) in [Action::Read, Action::Write, Action::Manage]
                .into_iter()
                .enumerate()
            {
                assert_eq!(permits(level, action).is_ok(), i > j);
            }
        }
    }
}

pub mod api_key;
mod ask_user;
mod context;
mod documents;
mod ledger;
mod registry;
pub mod templates;
pub mod tool;
pub use context::{Invocation, ToolCtx};
pub use jiabu_db::OperationError as ToolError;
#[derive(serde::Serialize, serde::Deserialize, schemars::JsonSchema)]
#[serde(untagged)]
pub enum ToolCall {
    Ledger(Box<ledger::ToolCall>),
    Documents(Box<documents::ToolCall>),
}
impl ToolCall {
    pub fn name(&self) -> &'static str {
        match self {
            Self::Ledger(call) => call.name(),
            Self::Documents(call) => call.name(),
        }
    }
}
pub use registry::ToolRegistry;
pub use tool::{
    AgentTool, Effect, Exposure, StepKind, StepLabel, StepSummary, TypedTool, ValidatedCall,
};

/// Constructed once during startup/OpenAPI generation; schema failures are startup errors.
pub fn builtin_registry() -> std::sync::Arc<ToolRegistry> {
    static REGISTRY: std::sync::OnceLock<std::sync::Arc<ToolRegistry>> = std::sync::OnceLock::new();
    REGISTRY
        .get_or_init(|| {
            match templates::TemplateStore::empty()
                .and_then(|store| ToolRegistry::with_templates(std::sync::Arc::new(store)))
            {
                Ok(registry) => std::sync::Arc::new(registry),
                Err(error) => panic!("invalid built-in tool schema: {}", error.code),
            }
        })
        .clone()
}

#[cfg(test)]
mod registry_tests {
    use super::*;
    #[test]
    fn fixed_order_exposure_schemas_confirmation_and_unknown_fields() -> Result<(), ToolError> {
        let registry = ToolRegistry::ledger()?;
        let expected = [
            "list_accounts",
            "list_tags",
            "query_balance",
            "query_stats",
            "search_records",
            "get_record",
            "create_record",
            "update_record",
            "void_record",
            "restore_record",
            "create_account",
            "update_account",
            "archive_account",
            "set_allocation_plan",
            "create_tag",
            "rename_tag",
            "delete_tag",
            "ask_user",
        ];
        assert_eq!(
            registry.tools().map(|t| t.name()).collect::<Vec<_>>(),
            expected
        );
        for tool in registry.tools() {
            let args = tool.example_args();
            let call = tool.validate(args.clone())?;
            assert_eq!(tool.schema_version(), 1);
            assert_eq!(
                tool.requires_confirmation(call.as_ref()),
                matches!(
                    tool.name(),
                    "update_record" | "void_record" | "restore_record" | "archive_account"
                )
            );
            let mut injected = args;
            injected["space_id"] = serde_json::json!(uuid::Uuid::nil());
            assert!(
                tool.validate(injected).is_err(),
                "{} accepted a space parameter",
                tool.name()
            );
        }
        assert_eq!(registry.get("delete_tag")?.exposure(), Exposure::ApiOnly);
        assert_eq!(registry.get("ask_user")?.exposure(), Exposure::AgentOnly);
        assert!(
            registry
                .agent_tools()
                .all(|t| t.exposure() != Exposure::ApiOnly)
        );
        assert!(registry.get("create_record")?.validate(serde_json::json!({"kind":"allocation","amount_minor":1,"occurred_on":"2026-01-01","purpose_id":uuid::Uuid::nil()})).is_err());
        Ok(())
    }
}
