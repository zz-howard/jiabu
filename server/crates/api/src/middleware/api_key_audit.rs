use crate::{ApiError, AppState, Principal, Via};
use axum::http::{Method, request::Parts};
use jiabu_db::api_key_audit::ApiKeyAudit;
use jiabu_tools::{ToolCtx, api_key::KeyRequestBudget};
use std::sync::{
    Arc, Mutex, OnceLock,
    atomic::{AtomicBool, Ordering},
};

/// Installed before extraction, populated only after successful authentication.
#[derive(Clone, Default)]
pub struct RequestAudit {
    pub completed: Arc<AtomicBool>,
    record: Arc<Mutex<Option<ApiKeyAudit>>>,
    budget: Arc<Mutex<Option<KeyRequestBudget>>>,
    request_id: Arc<OnceLock<uuid::Uuid>>,
}
#[derive(Clone, Copy)]
pub(crate) struct ErrorCode(pub &'static str);
impl RequestAudit {
    pub(crate) fn set_budget(&self, budget: KeyRequestBudget) -> Result<(), ApiError> {
        *self.budget.lock().map_err(|_| ApiError::internal())? = Some(budget);
        Ok(())
    }
    /// Shared S4 batch entry. Call once per item, before member lookup or other
    /// item work; rejected admission has no audit. op_id is typed to prevent a
    /// plaintext credential being smuggled into the stored idempotency key.
    /// Preserve each item's request_id; None falls back to the HTTP request ID.
    /// attach shares the receipt/operation without changing ToolCtx's item ID.
    pub fn begin_push_item(
        &self,
        state: &AppState,
        principal: &Principal,
        space_id: Option<uuid::Uuid>,
        tool_name: Option<&str>,
        op_id: Option<uuid::Uuid>,
        request_id: Option<uuid::Uuid>,
    ) -> Result<PushItemAudit, ApiError> {
        self.suppress_push_batch()?;
        let record = if let Via::ApiKey { id, .. } = &principal.via {
            let mut budget = self.budget.lock().map_err(|_| ApiError::internal())?;
            budget
                .as_mut()
                .ok_or_else(ApiError::internal)?
                .admit_item(*id)?;
            let tool = tool_name.and_then(|name| state.tools.get(name).ok());
            Some(ApiKeyAudit {
                key_id: *id,
                user_id: principal.user_id.0,
                space_id,
                operation: format!("push:{}", tool.map_or("unknown", |tool| tool.name())),
                effect: if tool.is_some_and(|tool| tool.effect() == jiabu_tools::Effect::Read) {
                    "read"
                } else {
                    "local_write"
                },
                outcome: "internal",
                request_id: request_id
                    .unwrap_or_else(|| *self.request_id.get_or_init(super::request_id)),
                idempotency_key: op_id.map(|id| id.to_string()),
            })
        } else {
            None
        };
        Ok(PushItemAudit {
            record,
            completed: Arc::new(AtomicBool::new(false)),
        })
    }
    /// A valid empty batch has no items and must not create a batch audit row.
    pub(crate) fn suppress_push_batch(&self) -> Result<(), ApiError> {
        *self.record.lock().map_err(|_| ApiError::internal())? = None;
        Ok(())
    }
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
        let tool = crate::principal::request_tool(parts, state);
        let route = parts
            .extensions
            .get::<axum::extract::MatchedPath>()
            .map(axum::extract::MatchedPath::as_str);
        let sync_read = parts.method == Method::POST && route == Some("/v1/sync/pull");
        let blob_read = matches!(parts.method, Method::GET | Method::HEAD)
            && route == Some("/v1/spaces/{space_id}/blobs/{sha256}");
        let writing = !matches!(parts.method, Method::GET | Method::HEAD) && !sync_read;
        if !writing && tool.is_none() && !sync_read && !blob_read {
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
        let effect = if sync_read
            || blob_read
            || tool.is_some_and(|t| t.effect() == jiabu_tools::Effect::Read)
        {
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
            request_id: *self.request_id.get_or_init(super::request_id),
            idempotency_key,
        });
        Ok(())
    }
    pub(crate) async fn finish(
        &self,
        state: &AppState,
        outcome: &'static str,
    ) -> Result<(), ApiError> {
        let record = self
            .record
            .lock()
            .map_err(|_| ApiError::internal())?
            .clone();
        finish_record(state, record, &self.completed, outcome).await
    }
}

/// S4 can use this without a batch HTTP implementation in S5. Attach before
/// invoking a tool; finish also handles admitted errors before context creation.
pub struct PushItemAudit {
    record: Option<ApiKeyAudit>,
    completed: Arc<AtomicBool>,
}
impl PushItemAudit {
    pub fn attach(&self, ctx: &mut ToolCtx) -> Result<(), ApiError> {
        ctx.audit_completed = self.completed.clone();
        ctx.api_key_operation = self.record.as_ref().map(|record| record.operation.clone());
        // ToolCtx::begin has already checked live membership. Push requires a
        // read/write key even for a tool whose own effect is read.
        ctx.principal.require_read_write()?;
        Ok(())
    }
    pub async fn finish(&self, state: &AppState, outcome: &'static str) -> Result<(), ApiError> {
        finish_record(state, self.record.clone(), &self.completed, outcome).await
    }
}

async fn finish_record(
    state: &AppState,
    record: Option<ApiKeyAudit>,
    completed: &AtomicBool,
    outcome: &'static str,
) -> Result<(), ApiError> {
    // A denied token is never an admitted operation, including batch items.
    if outcome == "rate_limited" || completed.load(Ordering::Acquire) {
        return Ok(());
    }
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
        completed.store(true, Ordering::Release);
    }
    Ok(())
}
