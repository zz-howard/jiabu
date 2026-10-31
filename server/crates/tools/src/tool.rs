use crate::{Action, Module, ToolCtx, ToolError};
use jiabu_db::SpaceTx;
use schemars::JsonSchema;
use serde::{Serialize, de::DeserializeOwned};
use serde_json::Value;
use std::{future::Future, pin::Pin};
use validator::Validate;

pub type ToolFuture<'a, T> = Pin<Box<dyn Future<Output = T> + Send + 'a>>;
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Effect {
    Read,
    LocalWrite,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Exposure {
    AgentAndApi,
    ApiOnly,
    AgentOnly,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum StepKind {
    ListAccounts,
    ListTags,
    QueryBalance,
    QueryStats,
    SearchRecords,
    GetRecord,
    CreateRecord,
    UpdateRecord,
    VoidRecord,
    RestoreRecord,
    CreateAccount,
    UpdateAccount,
    ArchiveAccount,
    SetAllocationPlan,
    CreateTag,
    RenameTag,
    DeleteTag,
    AskUser,
    ListSubjects,
    SearchDocuments,
    GetDocument,
    DocumentMetricSeries,
    CreateDocument,
    UpdateDocument,
    VoidDocument,
    RestoreDocument,
    CreateSubject,
    UpdateSubject,
    ArchiveSubject,
    DeleteSubject,
    ShowMetrics,
    ShowTrend,
    ShowRecords,
    ShowBreakdown,
    ShowBarChart,
    ShowAccountCard,
}
pub struct StepLabel(pub &'static str);
pub struct StepSummary(pub &'static str);
pub trait TypedTool: Send + Sync + 'static {
    type Args: DeserializeOwned + Serialize + JsonSchema + Validate + Send + Sync + 'static;
    type Output: Serialize + JsonSchema + Send + 'static;
    fn name(&self) -> &'static str;
    fn description(&self) -> &'static str;
    fn module(&self) -> Module {
        Module::Ledger
    }
    fn action(&self) -> Action {
        if self.effect() == Effect::Read {
            Action::Read
        } else {
            Action::Write
        }
    }
    fn effect(&self) -> Effect;
    fn exposure(&self) -> Exposure {
        Exposure::AgentAndApi
    }
    fn schema_version(&self) -> u32 {
        1
    }
    fn requires_confirmation(&self, _args: &Self::Args) -> bool {
        false
    }
    fn step_kind(&self) -> StepKind;
    // Static labels are safe before we implement authorized name resolution in S7.
    fn step_label(&self, args: &Self::Args, ctx: &ToolCtx) -> StepLabel;
    fn step_summary(&self, _outcome: &Self::Output) -> Option<StepSummary> {
        None
    }
    /// Business rules beyond the schema, as field pointer plus rule; empty passes.
    fn check(&self, _args: &Self::Args) -> Vec<jiabu_db::ValidationIssue> {
        Vec::new()
    }
    fn example_args(&self) -> Value;
    fn example_output(&self) -> Value;
    fn execute<'a>(
        &'a self,
        args: Self::Args,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Self::Output, ToolError>>;
}
/// Object-safe, schema-cached view of a typed tool. Only this adapter deserializes.
pub trait AgentTool: Send + Sync {
    fn api_path(&self) -> String {
        format!("/v1/spaces/{{space_id}}/tools/{}", self.name())
    }
    fn name(&self) -> &'static str;
    fn description(&self) -> &'static str;
    fn parameters(&self) -> &Value;
    fn output_schema(&self) -> &Value;
    fn module(&self) -> Module;
    fn action(&self) -> Action;
    fn effect(&self) -> Effect;
    fn exposure(&self) -> Exposure;
    fn schema_version(&self) -> u32;
    fn step_kind(&self) -> StepKind;
    fn step_label(&self, args: &dyn ValidatedCall, ctx: &ToolCtx) -> StepLabel {
        args.step_label(ctx)
    }
    fn requires_confirmation(&self, args: &dyn ValidatedCall) -> bool {
        args.requires_confirmation()
    }
    fn step_summary(&self, _outcome: &Value) -> Option<StepSummary> {
        None
    }
    fn example_args(&self) -> Value;
    fn example_output(&self) -> Value;
    fn validate(&self, raw: Value) -> Result<Box<dyn ValidatedCall>, ToolError>;
}
pub trait ValidatedCall: Send {
    fn step_label(&self, ctx: &ToolCtx) -> StepLabel;
    fn requires_confirmation(&self) -> bool;
    fn execute<'a>(
        self: Box<Self>,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Value, ToolError>>;
}
pub(crate) struct TypedAdapter<T: TypedTool> {
    tool: std::sync::Arc<T>,
    parameters: Value,
    output: Value,
    validator: jsonschema::Validator,
}
impl<T: TypedTool> TypedAdapter<T> {
    pub fn new(tool: T) -> Result<Self, ToolError> {
        let parameters = serde_json::to_value(schemars::schema_for!(T::Args))
            .map_err(|_| ToolError::internal())?;
        let output = serde_json::to_value(schemars::schema_for!(T::Output))
            .map_err(|_| ToolError::internal())?;
        let validator =
            jsonschema::validator_for(&parameters).map_err(|_| ToolError::internal())?;
        Ok(Self {
            tool: std::sync::Arc::new(tool),
            parameters,
            output,
            validator,
        })
    }
}
struct Call<T: TypedTool> {
    tool: std::sync::Arc<T>,
    args: T::Args,
}
impl<T: TypedTool> ValidatedCall for Call<T> {
    fn step_label(&self, ctx: &ToolCtx) -> StepLabel {
        self.tool.step_label(&self.args, ctx)
    }
    fn requires_confirmation(&self) -> bool {
        self.tool.requires_confirmation(&self.args)
    }
    fn execute<'a>(
        self: Box<Self>,
        ctx: &'a ToolCtx,
        tx: &'a SpaceTx,
    ) -> ToolFuture<'a, Result<Value, ToolError>> {
        Box::pin(async move {
            let result = self.tool.execute(self.args, ctx, tx).await?;
            serde_json::to_value(result).map_err(|_| ToolError::internal())
        })
    }
}
impl<T: TypedTool> AgentTool for TypedAdapter<T> {
    fn name(&self) -> &'static str {
        self.tool.name()
    }
    fn description(&self) -> &'static str {
        self.tool.description()
    }
    fn parameters(&self) -> &Value {
        &self.parameters
    }
    fn output_schema(&self) -> &Value {
        &self.output
    }
    fn module(&self) -> Module {
        self.tool.module()
    }
    fn action(&self) -> Action {
        self.tool.action()
    }
    fn effect(&self) -> Effect {
        self.tool.effect()
    }
    fn exposure(&self) -> Exposure {
        self.tool.exposure()
    }
    fn schema_version(&self) -> u32 {
        self.tool.schema_version()
    }
    fn step_kind(&self) -> StepKind {
        self.tool.step_kind()
    }
    fn example_args(&self) -> Value {
        self.tool.example_args()
    }
    fn example_output(&self) -> Value {
        self.tool.example_output()
    }
    fn validate(&self, raw: Value) -> Result<Box<dyn ValidatedCall>, ToolError> {
        if !self.validator.is_valid(&raw) {
            let mut error = ToolError::invalid();
            error.errors = Some(schema_issues(&self.validator, &raw));
            return Err(error);
        }
        let args: T::Args = serde_json::from_value(raw).map_err(|_| ToolError::invalid())?;
        args.validate().map_err(|errors| {
            let mut error = ToolError::invalid();
            error.errors = Some(
                errors
                    .field_errors()
                    .into_iter()
                    .flat_map(|(field, issues)| {
                        issues.iter().map(move |issue| jiabu_db::ValidationIssue {
                            pointer: format!("/{field}"),
                            rule: issue.code.to_string(),
                        })
                    })
                    .collect(),
            );
            error
        })?;
        let issues = self.tool.check(&args);
        if !issues.is_empty() {
            let mut error = ToolError::invalid();
            error.errors = Some(issues);
            return Err(error);
        }
        Ok(Box::new(Call {
            tool: self.tool.clone(),
            args,
        }))
    }
}
/// Field-level schema violations: JSON pointer plus the failing keyword. Only
/// schema-shaped names are reported: any pointer segment that is not a short
/// identifier or index (a map key or unexpected property the model made up, which may
/// carry user text) becomes `*`. Instance values never appear.
fn schema_issues(validator: &jsonschema::Validator, raw: &Value) -> Vec<jiabu_db::ValidationIssue> {
    use jsonschema::error::ValidationErrorKind;
    const LIMIT: usize = 16;
    let mut issues = Vec::new();
    let mut push = |pointer: String, rule: &str| {
        let issue = jiabu_db::ValidationIssue {
            pointer: safe_pointer(&pointer),
            rule: rule.into(),
        };
        if !issues
            .iter()
            .any(|i: &jiabu_db::ValidationIssue| i.pointer == issue.pointer && i.rule == issue.rule)
        {
            issues.push(issue);
        }
    };
    for error in validator.iter_errors(raw).take(LIMIT) {
        let path = error.instance_path().to_string();
        match error.kind() {
            ValidationErrorKind::Required { property } => {
                push(
                    format!("{path}/{}", property.as_str().unwrap_or("")),
                    "required",
                );
            }
            ValidationErrorKind::AdditionalProperties { unexpected } => {
                for name in unexpected {
                    push(format!("{path}/{name}"), "unknown_property");
                }
            }
            kind => push(path, kind.keyword()),
        }
    }
    if issues.is_empty() {
        issues.push(jiabu_db::ValidationIssue {
            pointer: "/".into(),
            rule: "schema".into(),
        });
    }
    issues.truncate(LIMIT);
    issues
}
/// `/a/0/b` stays; segments outside `[A-Za-z0-9_]{1,40}` become `*`; empty is `/`.
pub(crate) fn safe_pointer(pointer: &str) -> String {
    let segments: Vec<&str> = pointer
        .split('/')
        .skip(1)
        .map(|segment| {
            if (1..=40).contains(&segment.len())
                && segment
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || b == b'_')
            {
                segment
            } else {
                "*"
            }
        })
        .collect();
    if segments.is_empty() {
        "/".into()
    } else {
        format!("/{}", segments.join("/"))
    }
}
