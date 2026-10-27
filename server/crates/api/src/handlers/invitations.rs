use super::space_models::{ReceivedSpaceInvitationsResponse, SpaceActionResponse};
use crate::{ApiError, AppState, SessionOnly, middleware, services::spaces as service};
use axum::{
    Json,
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
};
use jiabu_domain::spaces::Decision;
use serde_json::Value;
use uuid::Uuid;

#[utoipa::path(get,path="/v1/me/invitations",security(("bearer"=[])),responses((status=200,body=ReceivedSpaceInvitationsResponse,description="Received pending invitations; only space and inviter labels",example=json!({"invitations":[]})),(status=403,body=crate::Problem,description="Session required")))]
pub(crate) async fn list(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
) -> Result<Json<ReceivedSpaceInvitationsResponse>, ApiError> {
    Ok(Json(super::spaces::data(
        state.db.received_invitations(principal.user_id).await?,
    )?))
}

#[utoipa::path(post,path="/v1/me/invitations/{inv_id}/accept",security(("bearer"=[])),params(("inv_id"=Uuid,Path),("Idempotency-Key"=String,Header)),responses((status=200,body=SpaceActionResponse,description="Current invitation state",example=json!({"status":"accepted","member_id":"019a0000-0000-7000-8000-000000000004","join_epoch":1})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn accept(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(inv_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<(StatusCode, Json<SpaceActionResponse>), ApiError> {
    let operation = service::operation(
        &headers,
        "POST",
        &format!("/v1/me/invitations/{inv_id}/accept"),
        Value::Null,
    )?;
    super::spaces::response(
        state
            .db
            .decide_invitation(
                principal.user_id,
                inv_id,
                Decision::Accept,
                &operation,
                middleware::request_id(),
            )
            .await?,
    )
}

#[utoipa::path(post,path="/v1/me/invitations/{inv_id}/decline",security(("bearer"=[])),params(("inv_id"=Uuid,Path),("Idempotency-Key"=String,Header)),responses((status=200,body=SpaceActionResponse,description="Current invitation state",example=json!({"status":"declined"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key/epoch"),(status=403,body=crate::Problem,description="Session required"),(status=404,body=crate::Problem,description="Not found"),(status=409,body=crate::Problem,description="State, epoch or version conflict"),(status=422,body=crate::Problem,description="Validation failed")))]
pub(crate) async fn decline(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    Path(inv_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<(StatusCode, Json<SpaceActionResponse>), ApiError> {
    let operation = service::operation(
        &headers,
        "POST",
        &format!("/v1/me/invitations/{inv_id}/decline"),
        Value::Null,
    )?;
    super::spaces::response(
        state
            .db
            .decide_invitation(
                principal.user_id,
                inv_id,
                Decision::Decline,
                &operation,
                middleware::request_id(),
            )
            .await?,
    )
}
