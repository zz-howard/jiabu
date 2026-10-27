use crate::{ApiError, AppState, Principal, PushItemAudit, RequestAudit};
use jiabu_db::{BeginError, SpaceTx, sync::VisibleModules};
use jiabu_domain::{JoinEpoch, SpaceId};
use jiabu_tools::{
    Action, Effect, Exposure, Invocation, Module, ToolCall, ToolCtx, ToolError, authorize,
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::BTreeMap;
use uuid::Uuid;

#[derive(Deserialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub struct PushRequest {
    // Parse each envelope only after item admission, so malformed metadata also
    // consumes one token and gets one safe audit. The public contract stays typed.
    #[schema(value_type = Vec<PushOpEnvelope>)]
    pub ops: Vec<Value>,
}
#[derive(Deserialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub struct PushOpEnvelope {
    pub op_id: Uuid,
    pub space_id: Uuid,
    pub join_epoch: i32,
    pub request_id: Uuid,
    pub tool: String,
    /// Runtime parsing envelope; OpenAPI uses a separate registry-generated union.
    pub args: Value,
}
#[derive(Serialize, utoipa::ToSchema)]
pub struct PushResult {
    pub op_id: Option<Uuid>,
    pub status: PushStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub problem: Option<Value>,
}
#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum PushStatus {
    Ok,
    Conflict,
    Rejected,
    SpaceUnavailable,
    MembershipChanged,
    NotProcessed,
}
#[derive(Serialize, utoipa::ToSchema)]
pub struct PushResponse {
    pub results: Vec<PushResult>,
}

async fn push_one(
    state: &AppState,
    principal: &Principal,
    op: &PushOpEnvelope,
    ticket: &PushItemAudit,
) -> Result<Value, ToolError> {
    if op.join_epoch <= 0 {
        return Err(ToolError::new(400, "bad_request"));
    }
    // Keep S3's read preflight + unique business write transaction. All authorization,
    // replay, execution and commit remain in ToolRegistry::invoke, in that order.
    let mut ctx = ToolCtx::begin(
        &state.db,
        principal.clone(),
        SpaceId(op.space_id),
        Some(JoinEpoch(op.join_epoch)),
        Effect::LocalWrite,
        Invocation {
            idempotency_key: Some(op.op_id),
            replay_key: Some(op.op_id.to_string()),
            run_id: None,
            request_id: op.request_id,
            now: state.clock.now(),
        },
    )
    .await?;
    // Scope is checked for EVERY item after live membership, including read and
    // AgentOnly tools that push will subsequently reject as not syncable.
    ticket.attach(&mut ctx).map_err(item_error)?;
    let tool = state.tools.get(&op.tool)?;
    if tool.effect() != Effect::LocalWrite || tool.exposure() == Exposure::AgentOnly {
        return Err(ToolError::new(422, "tool_not_syncable"));
    }
    // Validate the S3 discriminated union, never a second argument DTO inventory.
    let typed: ToolCall = serde_json::from_value(json!({"tool":op.tool,"args":op.args}))
        .map_err(|_| ToolError::invalid())?;
    state
        .tools
        .invoke(typed.name(), op.args.clone(), &ctx)
        .await
}
fn item_error(error: ApiError) -> ToolError {
    let mut result = ToolError::new(error.status.as_u16(), error.code);
    result.retry_after = error.retry_after;
    result
}
fn metadata_id(raw: &Value, field: &str) -> Option<Uuid> {
    raw.get(field)?
        .as_str()
        .and_then(|value| Uuid::parse_str(value).ok())
}
fn item_problem(error: ToolError, request_id: Uuid) -> Value {
    let mut problem = json!({"type":format!("urn:jiabu:error:{}",error.code),"title":error.code,"status":error.status,"code":error.code,"request_id":request_id});
    // A 200 batch has no per-item HTTP headers. Carry S5's seconds-to-retry in
    // the item's problem; admission-level 429 still uses HTTP Retry-After.
    if let Some(seconds) = error.retry_after {
        problem["retry_after"] = json!(seconds);
    }
    if let Some(current) = error.current {
        problem["current"] = current;
    }
    if let Some(errors) = error.errors {
        problem["errors"] = json!(errors);
    } else if error.code == "validation_failed" {
        problem["errors"] = json!([{"pointer":"/","rule":"invalid"}]);
    }
    problem
}
pub async fn push(
    state: &AppState,
    principal: &Principal,
    audit: &RequestAudit,
    request: PushRequest,
) -> Result<PushResponse, ApiError> {
    if request.ops.len() > 50 {
        return Err(ApiError::new(
            axum::http::StatusCode::PAYLOAD_TOO_LARGE,
            "payload_too_large",
        ));
    }
    audit.suppress_push_batch()?;
    let mut stopped = false;
    let mut results = Vec::with_capacity(request.ops.len());
    for raw in request.ops {
        let was_stopped = stopped;
        let op_id = metadata_id(&raw, "op_id");
        let request_id =
            metadata_id(&raw, "request_id").unwrap_or_else(crate::middleware::request_id);
        let mut item = PushResult {
            op_id,
            status: PushStatus::NotProcessed,
            result: None,
            problem: None,
        };
        // begin_push_item reuses the HTTP debit for the first item and debits
        // exactly once for each later item, before parsing/transaction work.
        let result = match audit.begin_push_item(
            state,
            principal,
            metadata_id(&raw, "space_id"),
            raw.get("tool").and_then(Value::as_str),
            op_id,
            metadata_id(&raw, "request_id"),
        ) {
            Err(error) => Err(item_error(error)),
            Ok(ticket) => {
                let result = if stopped {
                    Ok(None)
                } else {
                    async {
                        let op: PushOpEnvelope =
                            serde_json::from_value(raw).map_err(|_| ToolError::invalid())?;
                        push_one(state, principal, &op, &ticket).await.map(Some)
                    }
                    .await
                };
                let outcome = match &result {
                    Ok(Some(_)) => "ok",
                    Ok(None) => "not_processed",
                    Err(error) => error.code,
                };
                // invoke owns success/error audit when reached; finish shares its
                // receipt and fills only failures before invoke/context creation.
                match ticket.finish(state, outcome).await {
                    Ok(()) => result,
                    Err(error) => Err(item_error(error)),
                }
            }
        };
        // Preserve S4's internal-error boundary: every following item remains
        // not_processed, even if its admission is subsequently rate-limited.
        // Accounting/finish above still run; no later business work is attempted.
        if was_stopped {
            results.push(item);
            continue;
        }
        match result {
            Ok(Some(result)) => {
                item.status = PushStatus::Ok;
                item.result = Some(result);
            }
            Ok(None) => (),
            Err(error) if error.status >= 500 => {
                stopped = true;
                item.problem = Some(json!({"code":"internal","request_id":request_id}));
                tracing::error!(%request_id, code="internal", "Sync operation failed");
            }
            Err(error) if error.space_unavailable => item.status = PushStatus::SpaceUnavailable,
            Err(error) if error.code == "membership_changed" => {
                item.status = PushStatus::MembershipChanged
            }
            Err(error) => {
                item.status = if error.status == 409 && error.code == "version_conflict" {
                    PushStatus::Conflict
                } else {
                    PushStatus::Rejected
                };
                item.problem = Some(item_problem(error, request_id));
            }
        }
        results.push(item);
    }
    Ok(PushResponse { results })
}
#[derive(Deserialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub struct PullRequest {
    /// At most 50 spaces per request.
    pub spaces: BTreeMap<Uuid, i64>,
    #[serde(default = "default_limit")]
    pub limit: u32,
}
fn default_limit() -> u32 {
    500
}
pub async fn pull(
    state: &AppState,
    principal: &Principal,
    request: PullRequest,
) -> Result<Value, ApiError> {
    if request.spaces.len() > 50
        || !(1..=500).contains(&request.limit)
        || request.spaces.values().any(|cursor| *cursor < 0)
    {
        return Err(ApiError::bad_request());
    }
    let mut spaces = Vec::new();
    let mut unavailable = Vec::new();
    for (id, cursor) in request.spaces {
        let space = SpaceId(id);
        let tx = match SpaceTx::begin_snapshot(&state.db, principal.user_id, space).await {
            Ok(tx) => tx,
            Err(BeginError::NotFound) => {
                unavailable.push(id);
                continue;
            }
            Err(error) => return Err(error.into()),
        };
        let member = tx.member(space);
        let visible = VisibleModules {
            ledger: authorize(member, Module::Ledger, Action::Read).is_ok(),
            documents: authorize(member, Module::Documents, Action::Read).is_ok(),
        };
        spaces.push(tx.sync_page(space, cursor, request.limit, visible).await?);
        tx.commit().await?;
    }
    Ok(json!({"spaces":spaces,"unavailable":unavailable}))
}
