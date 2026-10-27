use crate::{ApiError, AppState};
use axum::{
    extract::FromRequestParts,
    http::{Method, StatusCode, request::Parts},
};
use jiabu_db::auth::SessionKind;
pub use jiabu_db::{Principal, Via};
use jiabu_domain::UserId;
use jiabu_tools::api_key::KeyRequestBudget;

// Reused only within this HTTP request, never cached across requests.
#[derive(Clone)]
struct AuthenticatedApiKey(Principal);

pub(crate) fn request_tool<'a>(
    parts: &Parts,
    state: &'a AppState,
) -> Option<&'a dyn jiabu_tools::AgentTool> {
    if let Some(crate::handlers::tools::ToolName(name)) =
        parts.extensions.get::<crate::handlers::tools::ToolName>()
    {
        return state.tools.get(name).ok();
    }
    // The outer admission middleware precedes the route's ToolName layer. Use
    // only its registered MatchedPath here, never an arbitrary URI suffix.
    let path = parts
        .extensions
        .get::<axum::extract::MatchedPath>()?
        .as_str();
    let (_, name) = path.rsplit_once("/tools/")?;
    state
        .tools
        .get(name)
        .ok()
        .filter(|tool| tool.api_path() == path)
}

pub(crate) async fn prepare_api_key(parts: &mut Parts, state: &AppState) -> Result<(), ApiError> {
    if parts
        .headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .is_some_and(|token| token.starts_with("jiabu_pat_"))
    {
        let principal = Principal::from_request_parts(parts, state).await?;
        parts.extensions.insert(AuthenticatedApiKey(principal));
    }
    Ok(())
}
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
        if let Some(principal) = parts.extensions.get::<AuthenticatedApiKey>() {
            return Ok(principal.0.clone());
        }
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
            let ip = crate::middleware::source_ip(
                parts
                    .extensions
                    .get::<axum::extract::ConnectInfo<std::net::SocketAddr>>()
                    .copied(),
                &parts.headers,
            );
            let source = crate::middleware::ip_key(ip);
            state.api_keys.check_unknown(&source)?;
            let principal = match state
                .db
                .authenticate_api_key(crate::credentials::token_hash(token))
                .await
            {
                Ok(principal) => principal,
                Err(jiabu_db::auth::AuthError::Unauthenticated) => {
                    state.api_keys.unknown(&source)?;
                    return Err(ApiError::unauthorized());
                }
                Err(error) => return Err(error.into()),
            };
            tracing::Span::current().record("user_id", principal.user_id.to_string());
            tracing::Span::current().record("auth_kind", "api_key");
            if let Via::ApiKey { id, .. } = &principal.via {
                tracing::Span::current().record("api_key_id", id.to_string());
            }
            let pull = parts.method == Method::POST
                && parts
                    .extensions
                    .get::<axum::extract::MatchedPath>()
                    .is_some_and(|path| path.as_str() == "/v1/sync/pull");
            let writing = !matches!(parts.method, Method::GET | Method::HEAD)
                && !pull
                && !(parts.method == Method::POST
                    && request_tool(parts, state)
                        .is_some_and(|tool| tool.effect() == jiabu_tools::Effect::Read));
            let Via::ApiKey { id, .. } = &principal.via else {
                return Err(ApiError::internal());
            };
            // No business transaction, last-used update or audit precedes admission.
            let budget = KeyRequestBudget::admit(state.api_keys.clone(), *id, writing)?;
            let secret_in_key = parts
                .headers
                .get("idempotency-key")
                .and_then(|v| v.to_str().ok())
                .is_some_and(|key| key.contains(token));
            if let Some(audit) = parts
                .extensions
                .get::<crate::middleware::api_key_audit::RequestAudit>()
            {
                audit.set_budget(budget)?;
                audit.identify(&principal, parts, state, secret_in_key)?;
            }
            if secret_in_key {
                return Err(ApiError::bad_request());
            }
            state.db.touch_api_key(*id).await?;
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
/// AI routes only: API keys receive api_key_ai_not_allowed.
///
/// S4 sync/blob routes must extract Principal instead. HTTP admission runs in
/// prepare_api_key before handshake/transactions/audit; handlers reuse the
/// request identity and never debit ToolRegistry again. GET/HEAD use read tokens;
/// other methods use write tokens, except concrete read-tool POST routes.
/// For each /sync/push item, call RequestAudit::begin_push_item: the first item
/// uses the request token and each further item debits one write token. A 429
/// creates no item audit. Pass None for malformed item metadata so that even
/// validation failures are admitted and audited individually. After live member
/// binding, PushItemAudit::attach calls Principal::require_read_write() for
/// EVERY push item (also read tools), and shares its receipt/operation with ToolCtx;
/// invoke commits success audit with the write and appends error audit after
/// rollback. Always call PushItemAudit::finish for the result, including errors
/// before ToolCtx construction; it skips already recorded calls. Beginning item
/// accounting suppresses the generic batch audit, so there is no N+1 audit row.
/// Blob writes use Principal::require_read_write after membership binding and
/// the normal RequestAudit::identify/finish path; they charge only admission.
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
/// This is not for S4 sync/blob routes: see SessionOnly's integration contract.
pub struct AccountSession(pub Principal);
impl FromRequestParts<AppState> for AccountSession {
    type Rejection = ApiError;
    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, ApiError> {
        let principal = Principal::from_request_parts(parts, state).await?;
        principal.require_account_session()?;
        Ok(Self(principal))
    }
}
