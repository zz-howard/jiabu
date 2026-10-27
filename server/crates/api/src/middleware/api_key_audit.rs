use crate::{ApiError, AppState, Principal, Via};
use axum::http::{Method, request::Parts};
use jiabu_db::api_key_audit::ApiKeyAudit;
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
};

/// Installed before extraction, populated only after successful authentication.
#[derive(Clone, Default)]
pub(crate) struct RequestAudit {
    pub completed: Arc<AtomicBool>,
    record: Arc<Mutex<Option<ApiKeyAudit>>>,
}
#[derive(Clone, Copy)]
pub(crate) struct ErrorCode(pub &'static str);
impl RequestAudit {
    pub(crate) fn identify(
        &self,
        principal: &Principal,
        parts: &Parts,
        state: &AppState,
        secret_in_key: bool,
    ) -> Result<(), ApiError> {
        let Via::ApiKey { id, .. } = &principal.via else {
            return Ok(());
        };
        let path = parts.uri.path();
        let tool = path
            .rsplit_once("/tools/")
            .and_then(|(_, name)| state.tools.get(name).ok());
        let writing = !matches!(parts.method, Method::GET | Method::HEAD | Method::OPTIONS);
        if !writing && tool.is_none() {
            return Ok(());
        }
        let operation = tool.map_or_else(
            || {
                let route = parts
                    .extensions
                    .get::<axum::extract::MatchedPath>()
                    .map_or("unmatched", axum::extract::MatchedPath::as_str);
                format!("{}:{route}", parts.method)
            },
            |tool| format!("tool:{}", tool.name()),
        );
        let space_id = path
            .strip_prefix("/v1/spaces/")
            .and_then(|p| p.split('/').next())
            .and_then(|id| uuid::Uuid::parse_str(id).ok());
        let effect = if tool.is_some_and(|t| t.effect() == jiabu_tools::Effect::Read) {
            "read"
        } else {
            "local_write"
        };
        let idempotency_key = if secret_in_key {
            None
        } else {
            parts
                .headers
                .get("idempotency-key")
                .and_then(|v| v.to_str().ok())
                .filter(|v| v.len() <= 200)
                .map(str::to_owned)
        };
        *self.record.lock().map_err(|_| ApiError::internal())? = Some(ApiKeyAudit {
            key_id: *id,
            user_id: principal.user_id.0,
            space_id,
            operation,
            effect,
            outcome: "internal",
            request_id: super::request_id(),
            idempotency_key,
        });
        Ok(())
    }
    pub(crate) async fn finish(
        &self,
        state: &AppState,
        outcome: &'static str,
    ) -> Result<(), ApiError> {
        if self.completed.load(Ordering::Acquire) {
            return Ok(());
        }
        let record = self
            .record
            .lock()
            .map_err(|_| ApiError::internal())?
            .clone();
        if let Some(mut record) = record {
            record.outcome = outcome;
            if state.db.append_api_key_audit(&record).await.is_err() {
                tracing::error!(
                    code = "api_key_audit_unavailable",
                    "Credential audit unavailable"
                );
                return Err(ApiError::new(
                    axum::http::StatusCode::SERVICE_UNAVAILABLE,
                    "unavailable",
                ));
            }
        }
        Ok(())
    }
}
