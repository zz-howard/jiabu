use super::space_models::*;
use crate::{AccountSession, ApiError, AppState, middleware, services::spaces as service};
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
pub(crate) struct CreateSpaceRequest {
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
pub(crate) struct RenameSpaceRequest {
    name: Option<String>,
    accent_color: Option<String>,
    expected_version: i32,
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct DeleteSpaceRequest {
    name: String,
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct InviteRequest {
    username: String,
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct TransferOwnershipRequest {
    member_id: Uuid,
}
#[derive(Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct UpdateDisplayNameRequest {
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

#[utoipa::path(get,path="/v1/spaces",security(("bearer"=[])),responses((status=200,body=SpacesResponse,description="Active spaces, caller grants and member lists",example=json!({"spaces":[]})),(status=429,body=crate::Problem,description="API key rate limited")))]
pub(crate) async fn list(
    State(state): State<AppState>,
    principal: crate::Principal,
) -> Result<Json<SpacesResponse>, ApiError> {
    Ok(Json(data(state.db.list_spaces(principal.user_id).await?)?))
}

#[utoipa::path(post,path="/v1/spaces",security(("bearer"=[])),params(("Idempotency-Key"=String,Header)),request_body(content=CreateSpaceRequest,example=json!({"id":"019a0000-0000-7000-8000-000000000001","name":"示例空间","accent_color":"pine","currency":"CNY","timezone":"Asia/Shanghai"})),responses((status=201,body=SpaceMetadata,description="Space initialized",example=json!({"id":"019a0000-0000-7000-8000-000000000001","name":"示例空间","accent_color":"pine","currency":"CNY","timezone":"Asia/Shanghai","is_default":false,"version":1,"change_seq":100})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn create(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    headers: HeaderMap,
    body: Result<Json<CreateSpaceRequest>, JsonRejection>,
) -> Result<(StatusCode, Json<SpaceMetadata>), ApiError> {
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

#[utoipa::path(patch,path="/v1/spaces/{space_id}",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=RenameSpaceRequest,example=json!({"name":"示例新名","expected_version":1})),responses((status=200,body=SpaceMetadata,description="Current result",example=json!({"id":"019a0000-0000-7000-8000-000000000001","name":"示例新名","accent_color":"indigo","currency":"JPY","timezone":"Asia/Tokyo","is_default":false,"version":2,"change_seq":100})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn rename(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<RenameSpaceRequest>, JsonRejection>,
) -> Result<(StatusCode, Json<SpaceMetadata>), ApiError> {
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

#[utoipa::path(delete,path="/v1/spaces/{space_id}",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=DeleteSpaceRequest,example=json!({"name":"示例空间"})),responses((status=200,body=SpaceActionResponse,description="Current result",example=json!({"status":"deleted"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn delete(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<DeleteSpaceRequest>, JsonRejection>,
) -> Result<(StatusCode, Json<SpaceActionResponse>), ApiError> {
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

#[utoipa::path(post,path="/v1/spaces/{space_id}/invitations",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=InviteRequest,example=json!({"username":"sample-guest"})),responses((status=201,body=SpaceInvitationResponse,description="Invitation created",example=json!({"id":"019a0000-0000-7000-8000-000000000002","space_id":"019a0000-0000-7000-8000-000000000001","invitee_user_id":"019a0000-0000-7000-8000-000000000003","invited_by_member_id":"019a0000-0000-7000-8000-000000000004","status":"pending","created_at":"2026-01-01T00:00:00Z","decided_at":null})),(status=200,body=SpaceInvitationResponse,description="Current result",example=json!({"id":"019a0000-0000-7000-8000-000000000002","space_id":"019a0000-0000-7000-8000-000000000001","invitee_user_id":"019a0000-0000-7000-8000-000000000003","invited_by_member_id":"019a0000-0000-7000-8000-000000000004","status":"pending","created_at":"2026-01-01T00:00:00Z","decided_at":null})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn invite(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<InviteRequest>, JsonRejection>,
) -> Result<(StatusCode, Json<SpaceInvitationResponse>), ApiError> {
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

#[utoipa::path(post,path="/v1/spaces/{space_id}/invitations/{inv_id}/cancel",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header), ("inv_id"=Uuid,Path)),responses((status=200,body=SpaceActionResponse,description="Current result",example=json!({"status":"cancelled"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn cancel(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path((space_id, inv_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<(StatusCode, Json<SpaceActionResponse>), ApiError> {
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

#[utoipa::path(delete,path="/v1/spaces/{space_id}/members/{member_id}",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header), ("member_id"=Uuid,Path)),responses((status=200,body=SpaceActionResponse,description="Current result",example=json!({"status":"left"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn remove(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path((space_id, member_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<(StatusCode, Json<SpaceActionResponse>), ApiError> {
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

#[utoipa::path(post,path="/v1/spaces/{space_id}/leave",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),responses((status=200,body=SpaceActionResponse,description="Current result",example=json!({"status":"left"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn leave(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<(StatusCode, Json<SpaceActionResponse>), ApiError> {
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

#[utoipa::path(post,path="/v1/spaces/{space_id}/transfer-ownership",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=TransferOwnershipRequest,example=json!({"member_id":"019a0000-0000-7000-8000-000000000002"})),responses((status=200,body=TransferOwnershipResponse,description="Current result",example=json!({"owner_member_id":"019a0000-0000-7000-8000-000000000002"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn transfer(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<TransferOwnershipRequest>, JsonRejection>,
) -> Result<(StatusCode, Json<TransferOwnershipResponse>), ApiError> {
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

#[utoipa::path(patch,path="/v1/spaces/{space_id}/members/me",security(("bearer"=[])),params(("space_id"=Uuid,Path), ("X-Jiabu-Join-Epoch"=i32,Header), ("Idempotency-Key"=String,Header)),request_body(content=UpdateDisplayNameRequest,example=json!({"display_name":"示例成员","expected_version":1})),responses((status=200,body=SpaceMember,description="Current result",example=json!({"id":"019a0000-0000-7000-8000-000000000002","display_name":"示例成员","role":"member","status":"active","join_epoch":1,"joined_at":"2026-01-01T00:00:00Z","left_at":null,"left_reason":null,"version":2,"change_seq":101})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn display_name(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(space_id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<UpdateDisplayNameRequest>, JsonRejection>,
) -> Result<(StatusCode, Json<SpaceMember>), ApiError> {
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

#[utoipa::path(get,path="/v1/spaces/{space_id}/invitations",security(("bearer"=[])),params(("space_id"=Uuid,Path)),responses((status=200,body=SpaceInvitationsResponse,description="Space invitation states",example=json!({"invitations":[{"id":"019a0000-0000-7000-8000-000000000002","status":"declined","invitee_username":"sample-guest","invited_by_member_id":"019a0000-0000-7000-8000-000000000004","created_at":"2026-01-01T00:00:00Z","decided_at":"2026-01-02T00:00:00Z"}]})),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found")))]
pub(crate) async fn invitations(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(space_id): Path<Uuid>,
) -> Result<Json<SpaceInvitationsResponse>, ApiError> {
    let space = SpaceId(space_id);
    let tx = SpaceTx::begin(&state.db, principal.user_id, &[(space, None)], Mode::Read).await?;
    let body = tx.invitations(space).await?;
    tx.commit().await?;
    Ok(Json(data(body)?))
}
