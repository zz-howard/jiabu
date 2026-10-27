use super::me::UserResponse;
use crate::{ApiError, AppState, SessionOnly, Via, credentials, middleware};
use axum::{
    Json,
    extract::{ConnectInfo, State, rejection::JsonRejection},
    http::{HeaderMap, StatusCode},
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
#[derive(Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct LoginRequest {
    username: String,
    password: String,
    device_name: Option<String>,
}
#[derive(Serialize, ToSchema)]
pub(crate) struct LoginResponse {
    token: String,
    session_kind: String,
    user: UserResponse,
    #[serde(skip_serializing_if = "Option::is_none")]
    admin_reset_at: Option<DateTime<Utc>>,
}
#[utoipa::path(post,path="/v1/auth/login",request_body(content=LoginRequest,example=json!({"username":"sample","password":"example-password","device_name":"example-device"})),
    responses((status=200,body=LoginResponse,description="Session created",example=json!({"token":"<opaque-session-token>","session_kind":"password_change","user":{"id":"019a0000-0000-7000-8000-000000000001","username":"sample","locale":"system"}})),
    (status=401,body=crate::Problem,description="Invalid credentials"),(status=429,body=crate::Problem,description="Rate limited")))]
pub(crate) async fn login(
    State(state): State<AppState>,
    peer: ConnectInfo<std::net::SocketAddr>,
    headers: HeaderMap,
    body: Result<Json<LoginRequest>, JsonRejection>,
) -> Result<Json<LoginResponse>, ApiError> {
    let request = super::input(body)?;
    if request.username.trim().is_empty()
        || request.username.chars().count() > 20
        || request.password.len() > 1024
        || request.device_name.as_ref().is_some_and(|s| s.len() > 200)
    {
        return Err(ApiError::invalid());
    }
    let ip = middleware::source_ip(Some(peer), &headers);
    if let Err(seconds) = state.limiter.check(ip, &request.username) {
        let mut error = ApiError::new(StatusCode::TOO_MANY_REQUESTS, "rate_limited");
        error.retry_after = Some(seconds);
        return Err(error);
    }
    let candidate = state.db.login_candidate(request.username.trim()).await?;
    let hash = candidate
        .as_ref()
        .map(|c| c.password_hash.clone())
        .unwrap_or_else(|| state.dummy_hash.as_ref().clone());
    let valid = state
        .password_work(move || credentials::verify_password(&request.password, &hash))
        .await?;
    if !valid {
        return Err(ApiError::unauthorized());
    }
    let candidate = candidate.ok_or_else(ApiError::unauthorized)?;
    let token = credentials::random_secret();
    let result = state
        .db
        .finish_login(
            &candidate,
            credentials::token_hash(&token),
            request.device_name,
        )
        .await?;
    tracing::Span::current().record("user_id", result.user.id.to_string());
    Ok(Json(LoginResponse {
        token,
        session_kind: result.kind.as_str().into(),
        user: result.user.into(),
        admin_reset_at: result.admin_reset_at,
    }))
}
#[utoipa::path(post,path="/v1/auth/logout",security(("bearer"=[])),responses((status=204,description="Current session removed")))]
pub(crate) async fn logout(
    State(state): State<AppState>,
    SessionOnly(principal): SessionOnly,
) -> Result<StatusCode, ApiError> {
    let Via::Session { session_id, .. } = principal.via else {
        return Err(ApiError::unauthorized());
    };
    state.db.logout(session_id).await?;
    Ok(StatusCode::NO_CONTENT)
}
