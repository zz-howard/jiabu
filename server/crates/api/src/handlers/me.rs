use crate::{ApiError, AppState, Principal, SessionOnly, Via, credentials};
use axum::{
    Json,
    extract::{State, rejection::JsonRejection},
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;
#[derive(Serialize, ToSchema)]
pub(crate) struct UserResponse {
    id: Uuid,
    username: String,
    locale: String,
}
impl From<jiabu_db::auth::User> for UserResponse {
    fn from(u: jiabu_db::auth::User) -> Self {
        Self {
            id: u.id,
            username: u.username,
            locale: u.locale,
        }
    }
}
#[derive(Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct PatchMe {
    locale: String,
}
#[derive(Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct ChangePassword {
    current_password: String,
    new_password: String,
}
#[utoipa::path(get,path="/v1/me",security(("bearer"=[])),responses((status=200,body=UserResponse,description="Current user",example=json!({"id":"019a0000-0000-7000-8000-000000000001","username":"sample","locale":"en"}))))]
pub(crate) async fn get(principal: Principal) -> Json<UserResponse> {
    Json(principal.user.into())
}
#[utoipa::path(patch,path="/v1/me",security(("bearer"=[])),request_body(content=PatchMe,example=json!({"locale":"en"})),responses((status=200,body=UserResponse,description="Locale saved",example=json!({"id":"019a0000-0000-7000-8000-000000000001","username":"sample","locale":"zh-Hans"}))))]
pub(crate) async fn patch(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    body: Result<Json<PatchMe>, JsonRejection>,
) -> Result<Json<UserResponse>, ApiError> {
    let request = super::input(body)?;
    if !matches!(request.locale.as_str(), "system" | "zh-Hans" | "en") {
        return Err(ApiError::invalid());
    }
    Ok(Json(
        state
            .db
            .set_locale(principal.user_id, &request.locale)
            .await?
            .into(),
    ))
}
#[utoipa::path(post,path="/v1/me/password",security(("bearer"=[])),request_body(content=ChangePassword,example=json!({"current_password":"example-old-password","new_password":"example-new-password"})),responses((status=204,description="Password changed; current session is full"),(status=401,body=crate::Problem,description="Current password invalid")))]
pub(crate) async fn password(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
    body: Result<Json<ChangePassword>, JsonRejection>,
) -> Result<StatusCode, ApiError> {
    let request = super::input(body)?;
    if !(8..=1024).contains(&request.new_password.len()) || request.current_password.len() > 1024 {
        return Err(ApiError::invalid());
    }
    let candidate = state
        .db
        .login_candidate(&principal.user.username)
        .await?
        .ok_or_else(ApiError::unauthorized)?;
    let expected = candidate.password_hash.clone();
    let hashed = tokio::task::spawn_blocking(move || {
        if !credentials::verify_password(&request.current_password, &expected) {
            return None;
        }
        Some(credentials::hash_password(&request.new_password))
    })
    .await
    .map_err(|_| ApiError::internal())?
    .ok_or_else(ApiError::unauthorized)?
    .map_err(|_| ApiError::internal())?;
    let Via::Session { session_id, .. } = principal.via else {
        return Err(ApiError::unauthorized());
    };
    state
        .db
        .change_password(
            principal.user_id,
            session_id,
            &candidate.password_hash,
            hashed,
        )
        .await?;
    Ok(StatusCode::NO_CONTENT)
}
