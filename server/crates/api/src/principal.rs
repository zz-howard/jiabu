use crate::{ApiError, AppState};
use axum::{
    extract::FromRequestParts,
    http::{Method, StatusCode, request::Parts},
};
use jiabu_db::auth::SessionKind;
pub use jiabu_db::{Principal, Via};
use jiabu_domain::UserId;
pub(crate) fn valid_token_shape(token: &str) -> bool {
    if token.starts_with("jiabu_pat_") {
        return crate::api_key_token::valid(token);
    }
    token.len() == 64
        && token
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
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
        if !valid_token_shape(token) {
            return Err(ApiError::unauthorized());
        }
        if token.starts_with("jiabu_pat_") {
            let principal = match state
                .db
                .authenticate_api_key(crate::credentials::token_hash(token))
                .await
            {
                Ok(principal) => principal,
                Err(jiabu_db::auth::AuthError::Unauthenticated) => {
                    let ip = crate::middleware::source_ip(
                        parts
                            .extensions
                            .get::<axum::extract::ConnectInfo<std::net::SocketAddr>>()
                            .copied(),
                        &parts.headers,
                    );
                    state.api_keys.unknown(&crate::middleware::ip_key(ip))?;
                    return Err(ApiError::unauthorized());
                }
                Err(error) => return Err(error.into()),
            };
            tracing::Span::current().record("user_id", principal.user_id.to_string());
            tracing::Span::current().record("auth_kind", "api_key");
            if let Via::ApiKey { id, .. } = &principal.via {
                tracing::Span::current().record("api_key_id", id.to_string());
            }
            let secret_in_key = parts
                .headers
                .get("idempotency-key")
                .and_then(|v| v.to_str().ok())
                .is_some_and(|key| key.contains(token));
            if let Some(audit) = parts
                .extensions
                .get::<crate::middleware::api_key_audit::RequestAudit>()
            {
                audit.identify(&principal, parts, state, secret_in_key)?;
            }
            if secret_in_key {
                return Err(ApiError::bad_request());
            }
            if parts.method == Method::GET
                && matches!(parts.uri.path(), "/v1/me" | "/v1/status" | "/v1/spaces")
                && let Via::ApiKey { id, .. } = &principal.via
            {
                state.api_keys.check(*id, false)?;
            }
            return Ok(principal);
        }
        let auth = state
            .db
            .authenticate(crate::credentials::token_hash(token))
            .await?;
        tracing::Span::current().record("user_id", auth.user.id.to_string());
        tracing::Span::current().record("auth_kind", "session");
        if auth.kind == SessionKind::PasswordChange
            && !(parts.method == Method::POST
                && matches!(parts.uri.path(), "/v1/me/password" | "/v1/auth/logout"))
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
        principal.require_ai_session()?;
        Ok(Self(principal))
    }
}
/// Account/security/space administration always requires a session.
pub struct AccountSession(pub Principal);
impl FromRequestParts<AppState> for AccountSession {
    type Rejection = ApiError;
    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, ApiError> {
        let principal = Principal::from_request_parts(parts, state).await?;
        principal.require_account_session()?;
        Ok(Self(principal))
    }
}
