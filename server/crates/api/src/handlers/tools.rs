use crate::{ApiError, AppState, Principal, middleware};
use axum::{
    Extension, Json,
    extract::{Path, State, rejection::JsonRejection},
    http::HeaderMap,
};
use jiabu_domain::{JoinEpoch, SpaceId};
use jiabu_tools::{Effect, Invocation, ToolCtx};
use serde_json::Value;
use uuid::Uuid;
#[derive(Clone, Copy)]
pub(crate) struct ToolName(pub &'static str);
#[derive(serde::Serialize, utoipa::ToSchema)]
pub struct ToolDescription {
    name: String,
    description: String,
    effect: String,
    parameters: Value,
    output_schema: Value,
    schema_version: u32,
}
#[derive(serde::Serialize, utoipa::ToSchema)]
pub struct ToolDirectory {
    tools: Vec<ToolDescription>,
}

#[utoipa::path(get,path="/v1/spaces/{space_id}/tools",security(("bearer"=[])),params(("space_id"=Uuid,Path)),responses((status=200,body=ToolDirectory,description="Tools allowed for the current member",example=json!({"tools":[]})),(status=404,body=crate::Problem,description="Not found"),(status=429,body=crate::Problem,description="API key rate limited")))]
pub(crate) async fn list(
    State(state): State<AppState>,
    principal: Principal,
    Path(space): Path<Uuid>,
) -> Result<Json<Value>, ApiError> {
    let ctx = ToolCtx::begin(
        &state.db,
        principal,
        SpaceId(space),
        None,
        Effect::Read,
        Invocation {
            idempotency_key: None,
            replay_key: None,
            run_id: None,
            request_id: middleware::request_id(),
            now: state.clock.now(),
        },
    )
    .await?;
    Ok(Json(state.tools.available(&ctx).await?))
}
/// One handler for all concrete tool paths. Each operation's schemas/examples are
/// generated in tool_openapi from the same TypedTool used by direct invoke.
// The operation annotation here documents the generic implementation; the catalog
// mounts only concrete registered paths and supplies each concrete operation.
#[utoipa::path(post,path="/v1/spaces/{space_id}/tools",operation_id="tool_dispatch",security(("bearer"=[])),params(("space_id"=Uuid,Path)),request_body(content=Value,example=json!({})),responses((status=200,body=Value,description="Typed tool result",example=json!({}))))]
pub(crate) async fn invoke(
    State(state): State<AppState>,
    principal: Principal,
    Path(space): Path<Uuid>,
    Extension(ToolName(name)): Extension<ToolName>,
    Extension(audit): Extension<crate::middleware::api_key_audit::RequestAudit>,
    headers: HeaderMap,
    body: Result<Json<Value>, JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let tool = state.tools.get(name)?;
    tracing::Span::current().record("tool", name);
    let writing = tool.effect() == Effect::LocalWrite;
    let (key, epoch) = if writing {
        let key = headers
            .get("idempotency-key")
            .and_then(|value| value.to_str().ok())
            .map(str::to_owned);
        let epoch = headers
            .get("x-jiabu-join-epoch")
            .map(|value| {
                value
                    .to_str()
                    .ok()
                    .and_then(|s| s.parse::<i32>().ok())
                    .filter(|n| *n > 0)
                    .map(JoinEpoch)
                    .ok_or_else(ApiError::bad_request)
            })
            .transpose();
        (key, epoch)
    } else {
        (None, Ok(None))
    };
    // Begin checks live membership/epoch before parsing tool arguments or replaying.
    let mut ctx = ToolCtx::begin(
        &state.db,
        principal.clone(),
        SpaceId(space),
        epoch.as_ref().ok().copied().flatten(),
        tool.effect(),
        Invocation {
            idempotency_key: key
                .as_ref()
                .map(|key| Uuid::new_v5(&principal.user_id.0, key.as_bytes())),
            replay_key: key,
            run_id: None,
            request_id: middleware::request_id(),
            now: state.clock.now(),
        },
    )
    .await?;
    let _ = epoch?;
    ctx.audit_completed = audit.completed.clone();
    let args = super::input(body)?;
    Ok(Json(state.tools.invoke(name, args, &ctx).await?))
}
