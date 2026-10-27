use super::space_models::*;
use crate::{ApiError, AppState, SessionOnly, middleware, services::spaces as service};
use axum::{
    Json,
    extract::{Path, State, rejection::JsonRejection},
    http::{HeaderMap, StatusCode},
};
use jiabu_db::{Mode, SpaceTx, spaces::Reply};
use jiabu_domain::{
    SpaceId,
    spaces::{Change, CreateSpace},
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct Create {
    id: Uuid,
    name: String,
    accent_color: String,
    #[serde(default = "default_currency")]
    currency: String,
    timezone: String,
}
fn default_currency() -> String {
    "CNY".into()
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct Rename {
    name: Option<String>,
    accent_color: Option<String>,
    expected_version: i32,
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct Delete {
    name: String,
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct Invite {
    username: String,
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct Transfer {
    member_id: Uuid,
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct DisplayName {
    display_name: String,
    expected_version: i32,
}

pub(crate) fn data<T: serde::de::DeserializeOwned>(body: Value) -> Result<T, ApiError> {
    serde_json::from_value(body).map_err(|_| ApiError::internal())
}
pub(crate) fn response<T: serde::de::DeserializeOwned>(
    reply: Reply,
) -> Result<(StatusCode, Json<T>), ApiError> {
    Ok((
        StatusCode::from_u16(reply.status).map_err(|_| ApiError::internal())?,
        Json(data(reply.body)?),
    ))
}
fn value<T: Serialize>(input: &T) -> Result<Value, ApiError> {
    serde_json::to_value(input).map_err(|_| ApiError::internal())
}

#[utoipa::path(get,path="/v1/spaces",security(("bearer"=[])),responses((status=200,body=Spaces,description="Active spaces, caller grants and member lists",example=json!({"spaces":[]})),(status=403,body=crate::Problem,description="Session required")))]
pub(crate) async fn list(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
) -> Result<Json<Spaces>, ApiError> {
    // S5: allow read-only API keys here when API-key authentication is implemented.
    Ok(Json(data(state.db.list_spaces(principal.user_id).await?)?))
}

#[utoipa::path(post,path="/v1/spaces",security(("bearer"=[])),params(("Idempotency-Key"=String,Header)),request_body(content=Create,example=json!({"id":"019a0000-0000-7000-8000-000000000001","name":"示例空间","accent_color":"pine","currency":"CNY","timezone":"Asia/Shanghai"})),responses((status=201,body=Space,description="Space initialized",example=json!({"id":"019a0000-0000-7000-8000-000000000001","name":"示例空间","accent_color":"pine","currency":"CNY","timezone":"Asia/Shanghai","is_default":false,"version":1,"change_seq":100})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn create(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    headers: HeaderMap,
    body: Result<Json<Create>, JsonRejection>,
) -> Result<(StatusCode, Json<Space>), ApiError> {
    let input = super::input(body)?;
    let operation = service::operation(&headers, "POST", "/v1/spaces", value(&input)?)?;
    response(
        state
            .db
            .create_space(
                principal.user_id,
                &principal.user.username,
                CreateSpace {
                    id: input.id,
                    name: input.name,
                    accent_color: input.accent_color,
                    currency: input.currency,
                    timezone: input.timezone,
                },
                &operation,
                middleware::request_id(),
            )
            .await?,
    )
}

#[utoipa::path(patch,path="/v1/spaces/{space_id}",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=Rename,example=json!({"name":"示例新名","expected_version":1})),responses((status=200,body=Space,description="Current result",example=json!({"id":"019a0000-0000-7000-8000-000000000001","name":"示例新名","accent_color":"indigo","currency":"JPY","timezone":"Asia/Tokyo","is_default":false,"version":2,"change_seq":100})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn rename(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<Rename>, JsonRejection>,
) -> Result<(StatusCode, Json<Space>), ApiError> {
    let input = super::input(body)?;
    let path = format!("/v1/spaces/{space_id}");
    let operation = service::operation(&headers, "PATCH", &path, value(&input)?)?;
    response(
        service::change(
            &state,
            &principal,
            SpaceId(space_id),
            service::epoch(&headers)?,
            Change::Rename {
                name: input.name,
                accent_color: input.accent_color,
                expected_version: input.expected_version,
            },
            operation,
        )
        .await?,
    )
}

#[utoipa::path(delete,path="/v1/spaces/{space_id}",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=Delete,example=json!({"name":"示例空间"})),responses((status=200,body=StateResponse,description="Current result",example=json!({"status":"deleted"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn delete(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<Delete>, JsonRejection>,
) -> Result<(StatusCode, Json<StateResponse>), ApiError> {
    let input = super::input(body)?;
    let path = format!("/v1/spaces/{space_id}");
    let operation = service::operation(&headers, "DELETE", &path, value(&input)?)?;
    response(
        service::change(
            &state,
            &principal,
            SpaceId(space_id),
            service::epoch(&headers)?,
            Change::Delete { name: input.name },
            operation,
        )
        .await?,
    )
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/invitations",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=Invite,example=json!({"username":"sample-guest"})),responses((status=201,body=Invitation,description="Invitation created",example=json!({"id":"019a0000-0000-7000-8000-000000000002","space_id":"019a0000-0000-7000-8000-000000000001","invitee_user_id":"019a0000-0000-7000-8000-000000000003","invited_by_member_id":"019a0000-0000-7000-8000-000000000004","status":"pending","created_at":"2026-01-01T00:00:00Z","decided_at":null})),(status=200,body=Invitation,description="Current result",example=json!({"id":"019a0000-0000-7000-8000-000000000002","space_id":"019a0000-0000-7000-8000-000000000001","invitee_user_id":"019a0000-0000-7000-8000-000000000003","invited_by_member_id":"019a0000-0000-7000-8000-000000000004","status":"pending","created_at":"2026-01-01T00:00:00Z","decided_at":null})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn invite(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<Invite>, JsonRejection>,
) -> Result<(StatusCode, Json<Invitation>), ApiError> {
    let input = super::input(body)?;
    let path = format!("/v1/spaces/{space_id}/invitations");
    let operation = service::operation(&headers, "POST", &path, value(&input)?)?;
    response(
        service::change(
            &state,
            &principal,
            SpaceId(space_id),
            service::epoch(&headers)?,
            Change::Invite {
                username: input.username,
            },
            operation,
        )
        .await?,
    )
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/invitations/{inv_id}/cancel",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header), ("inv_id"=Uuid,Path)),responses((status=200,body=StateResponse,description="Current result",example=json!({"status":"cancelled"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn cancel(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path((space_id, inv_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<(StatusCode, Json<StateResponse>), ApiError> {
    let path = format!("/v1/spaces/{space_id}/invitations/{inv_id}/cancel");
    let operation = service::operation(&headers, "POST", &path, Value::Null)?;
    response(
        service::change(
            &state,
            &principal,
            SpaceId(space_id),
            service::epoch(&headers)?,
            Change::Cancel { invitation: inv_id },
            operation,
        )
        .await?,
    )
}

#[utoipa::path(delete,path="/v1/spaces/{space_id}/members/{member_id}",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header), ("member_id"=Uuid,Path)),responses((status=200,body=StateResponse,description="Current result",example=json!({"status":"left"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn remove(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path((space_id, member_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<(StatusCode, Json<StateResponse>), ApiError> {
    let path = format!("/v1/spaces/{space_id}/members/{member_id}");
    let operation = service::operation(&headers, "DELETE", &path, Value::Null)?;
    response(
        service::change(
            &state,
            &principal,
            SpaceId(space_id),
            service::epoch(&headers)?,
            Change::Remove { member: member_id },
            operation,
        )
        .await?,
    )
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/leave",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),responses((status=200,body=StateResponse,description="Current result",example=json!({"status":"left"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn leave(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<(StatusCode, Json<StateResponse>), ApiError> {
    let path = format!("/v1/spaces/{space_id}/leave");
    let operation = service::operation(&headers, "POST", &path, Value::Null)?;
    response(
        service::change(
            &state,
            &principal,
            SpaceId(space_id),
            service::epoch(&headers)?,
            Change::Leave,
            operation,
        )
        .await?,
    )
}

#[utoipa::path(post,path="/v1/spaces/{space_id}/transfer-ownership",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=Transfer,example=json!({"member_id":"019a0000-0000-7000-8000-000000000002"})),responses((status=200,body=Ownership,description="Current result",example=json!({"owner_member_id":"019a0000-0000-7000-8000-000000000002"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn transfer(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<Transfer>, JsonRejection>,
) -> Result<(StatusCode, Json<Ownership>), ApiError> {
    let input = super::input(body)?;
    let path = format!("/v1/spaces/{space_id}/transfer-ownership");
    let operation = service::operation(&headers, "POST", &path, value(&input)?)?;
    response(
        service::change(
            &state,
            &principal,
            SpaceId(space_id),
            service::epoch(&headers)?,
            Change::Transfer {
                member: input.member_id,
            },
            operation,
        )
        .await?,
    )
}

#[utoipa::path(patch,path="/v1/spaces/{space_id}/members/me",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=DisplayName,example=json!({"display_name":"示例成员","expected_version":1})),responses((status=200,body=Member,description="Current result",example=json!({"id":"019a0000-0000-7000-8000-000000000002","display_name":"示例成员","role":"member","status":"active","join_epoch":1,"joined_at":"2026-01-01T00:00:00Z","left_at":null,"left_reason":null,"version":2,"change_seq":101})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn display_name(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<DisplayName>, JsonRejection>,
) -> Result<(StatusCode, Json<Member>), ApiError> {
    let input = super::input(body)?;
    let path = format!("/v1/spaces/{space_id}/members/me");
    let operation = service::operation(&headers, "PATCH", &path, value(&input)?)?;
    response(
        service::change(
            &state,
            &principal,
            SpaceId(space_id),
            service::epoch(&headers)?,
            Change::DisplayName {
                display_name: input.display_name,
                expected_version: input.expected_version,
            },
            operation,
        )
        .await?,
    )
}

#[utoipa::path(get,path="/v1/spaces/{space_id}/invitations",security(("bearer"=[])),params(("space_id"=Uuid,Path)),responses((status=200,body=Invitations,description="Space invitation states",example=json!({"invitations":[]})),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found")))]
pub(crate) async fn invitations(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(space_id): Path<Uuid>,
) -> Result<Json<Invitations>, ApiError> {
    let space = SpaceId(space_id);
    let tx = SpaceTx::begin(&state.db, principal.user_id, &[(space, None)], Mode::Read).await?;
    let body = tx.invitations(space).await?;
    tx.commit().await?;
    Ok(Json(data(body)?))
}
