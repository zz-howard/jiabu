//! Step 1: authenticated route contracts; runtime operations return unavailable.
use crate::{ApiError, AppState, SessionOnly};
use axum::{
    Json,
    extract::{Path, State, rejection::JsonRejection},
    http::{HeaderMap, StatusCode},
};
use jiabu_db::{Mode, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

#[derive(Deserialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub struct MessageInput {
    pub id: Uuid,
    pub text: Option<String>,
    #[serde(default)]
    pub images: Vec<String>,
}
#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StartResponse {
    pub user_message_id: Uuid,
    pub message_id: Uuid,
}

async fn check_space(
    state: &AppState,
    principal: &jiabu_db::Principal,
    space: Uuid,
    headers: &HeaderMap,
    writing: bool,
) -> Result<SpaceTx, ApiError> {
    let tx = SpaceTx::begin(
        &state.db,
        principal.user_id,
        &[(SpaceId(space), None)],
        Mode::Read,
    )
    .await?;
    // Identity and membership precede epoch, request validation, and future replay.
    if writing {
        let epoch = headers
            .get("x-jiabu-join-epoch")
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.parse::<i32>().ok())
            .filter(|epoch| *epoch > 0)
            .ok_or_else(ApiError::bad_request)?;
        tx.tool_member(
            SpaceId(space),
            principal.user_id,
            Some(JoinEpoch(epoch)),
            false,
        )?;
        headers
            .get("idempotency-key")
            .and_then(|value| value.to_str().ok())
            .and_then(|value| Uuid::parse_str(value).ok())
            .ok_or_else(|| ApiError::new(StatusCode::BAD_REQUEST, "idempotency_key_required"))?;
    }
    Ok(tx)
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/chat/messages",security(("bearer"=[])),params(("space_id"=Uuid,Path)),request_body(content=MessageInput,example=json!({"id":"019a0000-0000-7000-8000-000000000001","text":"午饭 50"})),responses((status=200,body=StartResponse,description="Message identifiers",example=json!({"userMessageId":"019a0000-0000-7000-8000-000000000001","messageId":"019a0000-0000-7000-8000-000000000003"})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=503,body=crate::Problem,description="Step 1 runtime unavailable",example=json!({"type":"urn:jiabu:error:unavailable","title":"unavailable","status":503,"code":"unavailable","request_id":"019a0000-0000-7000-8000-000000000004"}))))]
pub(crate) async fn send(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path(space): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<MessageInput>, JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let _tx = check_space(&state, &principal, space, &headers, true).await?;
    let input = super::input(body)?;
    let response = state
        .runs
        .start(
            &principal,
            jiabu_agent::StartMessage {
                id: input.id,
                text: input.text,
                images: input.images,
            },
        )
        .await?;
    Ok(Json(
        serde_json::to_value(StartResponse {
            user_message_id: response.user_message_id,
            message_id: response.message_id,
        })
        .map_err(|_| ApiError::internal())?,
    ))
}

#[utoipa::path(get,path="/v1/spaces/{space_id}/chat/messages/{message_id}/stream",security(("bearer"=[])),params(("space_id"=Uuid,Path),("message_id"=Uuid,Path)),responses((status=200,description="Resumable ChatWeave event stream",content_type="text/event-stream"),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=503,body=crate::Problem,description="Step 1 runtime unavailable",example=json!({"type":"urn:jiabu:error:unavailable","title":"unavailable","status":503,"code":"unavailable","request_id":"019a0000-0000-7000-8000-000000000004"}))))]
pub(crate) async fn stream(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path((space, message_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let _tx = check_space(&state, &principal, space, &headers, false).await?;
    let _ = message_id;
    Err(ApiError::new(
        StatusCode::SERVICE_UNAVAILABLE,
        "unavailable",
    ))
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/chat/actions",security(("bearer"=[])),params(("space_id"=Uuid,Path)),request_body(content=Value,example=json!({"protocolVersion":"0.1","id":"019a0000-0000-7000-8000-000000000002","context":{"conversationId":"019a0000-0000-7000-8000-000000000005","messageId":"019a0000-0000-7000-8000-000000000003","blockId":"question"},"type":"choice.select","target":"clarification.answer","payload":{"selected":["lunch"]}})),responses((status=200,body=Value,description="Accepted operation",example=json!({"status":"accepted"})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=503,body=crate::Problem,description="Step 1 runtime unavailable",example=json!({"type":"urn:jiabu:error:unavailable","title":"unavailable","status":503,"code":"unavailable","request_id":"019a0000-0000-7000-8000-000000000004"}))))]
pub(crate) async fn action(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path(space): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<Value>, JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let _tx = check_space(&state, &principal, space, &headers, true).await?;
    state.runs.answer(&principal, super::input(body)?).await?;
    Err(ApiError::new(
        StatusCode::SERVICE_UNAVAILABLE,
        "unavailable",
    ))
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/chat/messages/{message_id}/stop",security(("bearer"=[])),params(("space_id"=Uuid,Path),("message_id"=Uuid,Path)),responses((status=200,body=Value,description="Accepted operation",example=json!({"status":"accepted"})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=503,body=crate::Problem,description="Step 1 runtime unavailable",example=json!({"type":"urn:jiabu:error:unavailable","title":"unavailable","status":503,"code":"unavailable","request_id":"019a0000-0000-7000-8000-000000000004"}))))]
pub(crate) async fn stop(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path((space, message_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let _tx = check_space(&state, &principal, space, &headers, true).await?;
    state.runs.stop(&principal, message_id).await?;
    Err(ApiError::new(
        StatusCode::SERVICE_UNAVAILABLE,
        "unavailable",
    ))
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/chat/messages/{message_id}/retry",security(("bearer"=[])),params(("space_id"=Uuid,Path),("message_id"=Uuid,Path)),responses((status=200,body=StartResponse,description="Message identifiers",example=json!({"userMessageId":"019a0000-0000-7000-8000-000000000001","messageId":"019a0000-0000-7000-8000-000000000003"})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=503,body=crate::Problem,description="Step 1 runtime unavailable",example=json!({"type":"urn:jiabu:error:unavailable","title":"unavailable","status":503,"code":"unavailable","request_id":"019a0000-0000-7000-8000-000000000004"}))))]
pub(crate) async fn retry(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path((space, message_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let _tx = check_space(&state, &principal, space, &headers, true).await?;
    let _response = state.runs.retry(&principal, message_id).await?;
    Err(ApiError::new(
        StatusCode::SERVICE_UNAVAILABLE,
        "unavailable",
    ))
}

#[utoipa::path(get,path="/v1/spaces/{space_id}/chat/active-messages",security(("bearer"=[])),params(("space_id"=Uuid,Path)),responses((status=200,body=Value,description="Runtime result",example=json!({"messages":[]})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=503,body=crate::Problem,description="Step 1 runtime unavailable",example=json!({"type":"urn:jiabu:error:unavailable","title":"unavailable","status":503,"code":"unavailable","request_id":"019a0000-0000-7000-8000-000000000004"}))))]
pub(crate) async fn active(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path(space): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let _tx = check_space(&state, &principal, space, &headers, false).await?;
    Err(ApiError::new(
        StatusCode::SERVICE_UNAVAILABLE,
        "unavailable",
    ))
}
