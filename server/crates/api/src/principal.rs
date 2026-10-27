use crate::{ApiError, AppState};
use axum::{
    extract::FromRequestParts,
    http::{Method, StatusCode, request::Parts},
};
use jiabu_db::auth::{SessionKind, User};
use jiabu_domain::{SessionId, UserId};
use uuid::Uuid;
#[derive(Clone)]
pub enum Via {
    Session {
        session_id: SessionId,
        kind: SessionKind,
    },
    ApiKey {
        id: Uuid,
        name: String,
        scope: String,
    },
}
#[derive(Clone)]
pub struct Principal {
    pub user_id: UserId,
    pub via: Via,
    pub user: User,
}
impl FromRequestParts<AppState> for Principal {
    type Rejection = ApiError;
    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, ApiError> {
        let authorization = parts
            .headers
            .get("authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(ApiError::unauthorized)?;
        let token = authorization
            .strip_prefix("Bearer ")
            .ok_or_else(ApiError::unauthorized)?;
        // Session tokens encode 32 random bytes as 64 lowercase hexadecimal characters.
        if token.len() != 64
            || !token
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err(ApiError::unauthorized());
        }
        let auth = state
            .db
            .authenticate(crate::credentials::token_hash(token))
            .await?;
        tracing::Span::current().record("user_id", auth.user.id.to_string());
        tracing::Span::current().record("auth_kind", "session");
        if auth.kind == SessionKind::PasswordChange
            && !(parts.method == Method::POST && parts.uri.path() == "/v1/me/password")
        {
            return Err(ApiError::new(
                StatusCode::FORBIDDEN,
                "password_change_required",
            ));
        }
        Ok(Self {
            user_id: UserId(auth.user.id),
            via: Via::Session {
                session_id: auth.session_id,
                kind: auth.kind,
            },
            user: auth.user,
        })
    }
}
pub struct SessionOnly(pub Principal);
impl FromRequestParts<AppState> for SessionOnly {
    type Rejection = ApiError;
    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, ApiError> {
        let principal = Principal::from_request_parts(parts, state).await?;
        if matches!(principal.via, Via::ApiKey { .. }) {
            return Err(ApiError::new(StatusCode::FORBIDDEN, "api_key_not_allowed"));
        }
        Ok(Self(principal))
    }
}
