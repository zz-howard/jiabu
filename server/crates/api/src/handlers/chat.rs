//! Session-only chat endpoints. Authorization precedes validation and replay.
use crate::{ApiError, AppState, SessionOnly};
use axum::{
    Json,
    extract::{Path, Query, State, rejection::JsonRejection},
    http::{HeaderMap, StatusCode},
};
use jiabu_db::{Mode, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use uuid::Uuid;

#[derive(Deserialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub struct FileInput {
    pub sha256: String,
    pub name: String,
}
#[derive(Deserialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub struct MessageInput {
    pub id: Uuid,
    pub text: Option<String>,
    #[serde(default)]
    pub images: Vec<String>,
    #[serde(default)]
    pub files: Vec<FileInput>,
}
#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StartResponse {
    pub user_message_id: Uuid,
    pub message_id: Uuid,
}

#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ActiveMessage {
    pub message_id: Uuid,
    pub conversation_id: Uuid,
    #[schema(minimum = 0)]
    pub last_seq: i32,
    pub reply_to: Uuid,
    /// ChatWeave status: streaming or paused (includes queued/waiting_ai runs).
    pub status: String,
}
#[derive(Serialize, utoipa::ToSchema)]
pub struct ActiveResponse {
    pub messages: Vec<ActiveMessage>,
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

fn idempotency_key(headers: &HeaderMap) -> Result<Uuid, ApiError> {
    headers
        .get("idempotency-key")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse().ok())
        .ok_or_else(|| ApiError::new(StatusCode::BAD_REQUEST, "idempotency_key_required"))
}
fn bind(state: &AppState, tx: &SpaceTx, space: Uuid) -> jiabu_agent::ScopedRuns {
    state.runs.scoped(
        state.db.clone(),
        SpaceId(space),
        tx.member(SpaceId(space)).join_epoch(),
        state.chat_hub.clone(),
        state.tools.clone(),
        state.templates.clone(),
    )
}
fn start_response(response: jiabu_agent::StartResponse) -> Json<Value> {
    Json(json!({"userMessageId":response.user_message_id,"messageId":response.message_id}))
}
fn stream_error(error: jiabu_chat::ChatError) -> ApiError {
    match error {
        jiabu_chat::ChatError::NotFound => ApiError::not_found(),
        jiabu_chat::ChatError::InvalidRequest(_) => ApiError::bad_request(),
        _ => ApiError::new(StatusCode::SERVICE_UNAVAILABLE, "unavailable"),
    }
}
fn resume_options(headers: &HeaderMap) -> Result<jiabu_chat::ResumeOptions, ApiError> {
    let capabilities = headers
        .get("chatweave-capabilities")
        .map(|value| value.to_str().map_err(|_| ApiError::bad_request()))
        .transpose()?
        .unwrap_or_default();
    let features: Vec<_> = capabilities
        .split(';')
        .filter_map(|part| part.trim().strip_prefix("features="))
        .flat_map(|features| features.split(',').map(str::trim))
        .collect();
    Ok(jiabu_chat::ResumeOptions {
        snapshots: features.contains(&"stream.snapshot"),
        activity: features.contains(&"stream.activity"),
        ..jiabu_chat::ResumeOptions::default()
    })
}
#[derive(Default, Deserialize)]
pub(crate) struct StreamQuery {
    after: Option<String>,
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/chat/messages",security(("bearer"=[])),params(("space_id"=Uuid,Path),("X-Jiabu-Join-Epoch"=i32,Header,description="Current membership epoch"),("Idempotency-Key"=Uuid,Header,description="Message/action id for submit/action; operation key for stop/retry")),request_body(content=MessageInput,example=json!({"id":"019a0000-0000-7000-8000-000000000001","text":"午饭 50"})),responses((status=200,body=StartResponse,description="Message identifiers",example=json!({"userMessageId":"019a0000-0000-7000-8000-000000000001","messageId":"019a0000-0000-7000-8000-000000000003"})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=400,body=crate::Problem,description="Invalid headers or cursor"),(status=409,body=crate::Problem,description="Membership, idempotency or runtime conflict"),(status=422,body=crate::Problem,description="Invalid input")))]
pub(crate) async fn send(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path(space): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<MessageInput>, JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let tx = check_space(&state, &principal, space, &headers, true).await?;
    let input = super::input(body)?;
    if input.id != idempotency_key(&headers)? {
        return Err(ApiError::new(
            StatusCode::BAD_REQUEST,
            "idempotency_key_mismatch",
        ));
    }
    let runs = bind(&state, &tx, space);
    tx.commit().await?;
    Ok(start_response(
        runs.start(
            &principal,
            jiabu_agent::StartMessage {
                id: input.id,
                text: input.text,
                images: input.images,
                files: input
                    .files
                    .into_iter()
                    .map(|file| jiabu_agent::SubmittedFile {
                        sha256: file.sha256,
                        name: file.name,
                    })
                    .collect(),
            },
        )
        .await?,
    ))
}

#[utoipa::path(get,path="/v1/spaces/{space_id}/chat/messages/{message_id}/stream",security(("bearer"=[])),params(("space_id"=Uuid,Path),("message_id"=Uuid,Path),("ChatWeave-Capabilities"=Option<String>,Header,description="v=0.1; features=stream.resume,stream.snapshot,stream.activity"),("Last-Event-ID"=Option<String>,Header,description="Last reliable sequence; overrides after"),("after"=Option<String>,Query,description="Resume cursor when Last-Event-ID is absent")),responses((status=200,body=String,description="Resumable ChatWeave event stream; 15s heartbeat, 5min idle timeout; snapshot/activity require capability declarations",content_type="text/event-stream",example="event: message.start\ndata: {\"protocolVersion\":\"0.1\",\"messageId\":\"019a0000-0000-7000-8000-000000000003\",\"type\":\"message.start\",\"message\":{\"id\":\"019a0000-0000-7000-8000-000000000003\",\"role\":\"assistant\",\"conversationId\":\"019a0000-0000-7000-8000-000000000005\",\"createdAt\":\"2026-01-01T00:00:00Z\"},\"seq\":1}\n\n"),(status=503,body=crate::Problem,description="Stream storage unavailable"),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=400,body=crate::Problem,description="Invalid headers or cursor"),(status=409,body=crate::Problem,description="Membership, idempotency or runtime conflict"),(status=422,body=crate::Problem,description="Invalid input")))]
pub(crate) async fn stream(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path((space, message_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
    query: Result<Query<StreamQuery>, axum::extract::rejection::QueryRejection>,
) -> Result<axum::response::Response, ApiError> {
    let tx = check_space(&state, &principal, space, &headers, false).await?;
    let stored = tx
        .message(SpaceId(space), message_id)
        .await?
        .ok_or_else(ApiError::not_found)?;
    if stored.message["role"] != "assistant" {
        return Err(ApiError::not_found());
    }
    let scope = jiabu_chat::ChatScope {
        space_id: SpaceId(space),
        member_id: tx.member(SpaceId(space)).id(),
        user_id: principal.user_id,
    };
    tx.commit().await?;
    let Query(query) = query.map_err(|_| ApiError::bad_request())?;
    let service = jiabu_chat::resume_service(state.db.clone(), scope, state.chat_hub.clone());
    jiabu_chat::sse_response(
        &service,
        &message_id.to_string(),
        &headers,
        query.after.as_deref(),
        resume_options(&headers)?,
    )
    .await
    .map_err(stream_error)
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/chat/actions",security(("bearer"=[])),params(("space_id"=Uuid,Path),("X-Jiabu-Join-Epoch"=i32,Header,description="Current membership epoch"),("Idempotency-Key"=Uuid,Header,description="Message/action id for submit/action; operation key for stop/retry")),request_body(content=Value,example=json!({"protocolVersion":"0.1","id":"019a0000-0000-7000-8000-000000000002","context":{"conversationId":"019a0000-0000-7000-8000-000000000005","messageId":"019a0000-0000-7000-8000-000000000003","blockId":"question"},"type":"choice.select","target":"clarification.answer","payload":{"selected":["lunch"]}})),responses((status=200,body=Value,description="Accepted operation",example=json!({"status":"accepted","resume":{"messageId":"019a0000-0000-7000-8000-000000000003"}})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=400,body=crate::Problem,description="Invalid headers or cursor"),(status=409,body=crate::Problem,description="Membership, idempotency or runtime conflict"),(status=422,body=crate::Problem,description="Invalid input")))]
pub(crate) async fn action(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path(space): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<Value>, JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let tx = check_space(&state, &principal, space, &headers, true).await?;
    let request = super::input(body)?;
    let key = idempotency_key(&headers)?;
    let runs = bind(&state, &tx, space);
    tx.commit().await?;
    Ok(Json(
        runs.answer_with_key(&principal, request, &state.tools, key)
            .await?,
    ))
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/chat/messages/{message_id}/stop",security(("bearer"=[])),params(("space_id"=Uuid,Path),("message_id"=Uuid,Path),("X-Jiabu-Join-Epoch"=i32,Header,description="Current membership epoch"),("Idempotency-Key"=Uuid,Header,description="Message/action id for submit/action; operation key for stop/retry")),responses((status=200,body=Value,description="Accepted operation",example=json!({"status":"accepted"})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=400,body=crate::Problem,description="Invalid headers or cursor"),(status=409,body=crate::Problem,description="Membership, idempotency or runtime conflict"),(status=422,body=crate::Problem,description="Invalid input")))]
pub(crate) async fn stop(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path((space, message_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let tx = check_space(&state, &principal, space, &headers, true).await?;
    let runs = bind(&state, &tx, space);
    tx.commit().await?;
    runs.stop(&principal, message_id).await?;
    Ok(Json(json!({"status":"accepted"})))
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/chat/messages/{message_id}/retry",security(("bearer"=[])),params(("space_id"=Uuid,Path),("message_id"=Uuid,Path),("X-Jiabu-Join-Epoch"=i32,Header,description="Current membership epoch"),("Idempotency-Key"=Uuid,Header,description="Message/action id for submit/action; operation key for stop/retry")),responses((status=200,body=StartResponse,description="Message identifiers",example=json!({"userMessageId":"019a0000-0000-7000-8000-000000000001","messageId":"019a0000-0000-7000-8000-000000000003"})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=400,body=crate::Problem,description="Invalid headers or cursor"),(status=409,body=crate::Problem,description="Membership, idempotency or runtime conflict"),(status=422,body=crate::Problem,description="Invalid input")))]
pub(crate) async fn retry(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path((space, message_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let tx = check_space(&state, &principal, space, &headers, true).await?;
    let runs = bind(&state, &tx, space);
    tx.commit().await?;
    Ok(start_response(runs.retry(&principal, message_id).await?))
}

#[utoipa::path(get,path="/v1/spaces/{space_id}/chat/active-messages",security(("bearer"=[])),params(("space_id"=Uuid,Path)),responses((status=200,body=ActiveResponse,description="Own queued/running/waiting_ai/paused assistant messages in FIFO order",example=json!({"messages":[{"messageId":"019a0000-0000-7000-8000-000000000003","conversationId":"019a0000-0000-7000-8000-000000000005","lastSeq":1,"replyTo":"019a0000-0000-7000-8000-000000000001","status":"streaming"}]})),(status=403,body=crate::Problem,description="API keys cannot use AI"),(status=404,body=crate::Problem,description="Not found"),(status=400,body=crate::Problem,description="Invalid headers or cursor"),(status=409,body=crate::Problem,description="Membership, idempotency or runtime conflict"),(status=422,body=crate::Problem,description="Invalid input")))]
pub(crate) async fn active(
    SessionOnly(principal): SessionOnly,
    State(state): State<AppState>,
    Path(space): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let tx = check_space(&state, &principal, space, &headers, false).await?;
    let messages = tx.active_chat_messages(SpaceId(space)).await?;
    tx.commit().await?;
    Ok(Json(json!({"messages":messages})))
}
