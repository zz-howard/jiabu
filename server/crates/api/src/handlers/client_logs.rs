use crate::{AccountSession, ApiError, AppState};
use axum::{
    Json,
    extract::{State, rejection::JsonRejection},
    http::StatusCode,
    response::{IntoResponse, Response},
};
use chrono::{DateTime, Utc};
use serde::Deserialize;
use utoipa::ToSchema;
use uuid::Uuid;
#[derive(Clone, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct Entry {
    ts: DateTime<Utc>,
    level: String,
    logger: String,
    message: String,
    error_type: Option<String>,
    stack: Option<String>,
    request_id: Option<Uuid>,
}
#[derive(Clone, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct ClientLogs {
    entries: Vec<Entry>,
    app_version: String,
    build: i32,
    device_model: String,
    os_version: String,
}
#[utoipa::path(post,path="/v1/client-logs",security(("bearer"=[])),request_body(content=ClientLogs,example=json!({"entries":[{"ts":"2026-01-01T00:00:00Z","level":"ERROR","logger":"example","message":"example crash","error_type":"ExampleError","stack":"example frame"}],"app_version":"0.1.0","build":1,"device_model":"example-device","os_version":"example-os"})),responses((status=204,description="Logs accepted"),(status=413,body=crate::Problem,description="Batch too large"),(status=422,body=crate::Problem,description="Entry too large"),(status=429,body=crate::Problem,description="Upload quota exceeded")))]
pub(crate) async fn upload(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    body: Result<Json<ClientLogs>, JsonRejection>,
) -> Result<Response, ApiError> {
    // Quota first: every authenticated upload counts, valid or not.
    if let Err(seconds) = state
        .client_logs
        .hit(&[format!("user:{}", principal.user_id)])
    {
        let mut error = ApiError::new(StatusCode::TOO_MANY_REQUESTS, "rate_limited");
        error.retry_after = Some(seconds);
        return Err(error);
    }
    let request = super::input(body)?;
    if request.entries.len() > MAX_ENTRIES {
        return Err(ApiError::new(
            StatusCode::PAYLOAD_TOO_LARGE,
            "payload_too_large",
        ));
    }
    if !request.is_within_limits() {
        return Err(ApiError::invalid());
    }
    // Emit after middleware knows the response status and elapsed time.
    let mut response = StatusCode::NO_CONTENT.into_response();
    response.extensions_mut().insert(AcceptedLogs {
        user_id: principal.user_id,
        batch: request,
    });
    Ok(response)
}
pub(crate) const MAX_ENTRIES: usize = 100;
/// UTF-8 byte limits. Short metadata is capped tightly so a batch cannot be
/// inflated by large repeated fields; only message and stack carry real text.
pub(crate) const MAX_MESSAGE: usize = 2048;
pub(crate) const MAX_STACK: usize = 8192;
pub(crate) const MAX_LEVEL: usize = 16;
pub(crate) const MAX_NAME: usize = 128;
pub(crate) const MAX_ERROR_TYPE: usize = 256;
pub(crate) const MAX_APP_VERSION: usize = 64;
fn fits(value: &str, limit: usize) -> bool {
    value.len() <= limit
}
impl ClientLogs {
    fn is_within_limits(&self) -> bool {
        fits(&self.app_version, MAX_APP_VERSION)
            && fits(&self.device_model, MAX_NAME)
            && fits(&self.os_version, MAX_NAME)
            && self.entries.iter().all(|e| {
                !e.level.is_empty()
                    && fits(&e.level, MAX_LEVEL)
                    && e.level.bytes().all(|b| b.is_ascii_alphabetic())
                    && fits(&e.logger, MAX_NAME)
                    && fits(&e.message, MAX_MESSAGE)
                    && e.error_type
                        .as_deref()
                        .is_none_or(|v| fits(v, MAX_ERROR_TYPE))
                    && e.stack.as_deref().is_none_or(|v| fits(v, MAX_STACK))
            })
    }
}
#[derive(Clone)]
pub(crate) struct AcceptedLogs {
    user_id: jiabu_domain::UserId,
    batch: ClientLogs,
}
impl AcceptedLogs {
    /// One `client_batch` line carries the device context; each `client` entry line
    /// joins it through the shared upload request_id instead of repeating it.
    pub(crate) fn emit(self) {
        let request_id = crate::middleware::request_id();
        tracing::info!(target:"client_batch",request_id=%request_id,user_id=%self.user_id,
            entries=self.batch.entries.len(),app_version=%self.batch.app_version,build=self.batch.build,
            device_model=%self.batch.device_model,os_version=%self.batch.os_version);
        for entry in self.batch.entries {
            let client_request_id = entry
                .request_id
                .map(|id| id.to_string())
                .unwrap_or_default();
            tracing::info!(target:"client",request_id=%request_id,user_id=%self.user_id,
                client_request_id=%client_request_id,ts=%entry.ts,client_level=%entry.level,logger=%entry.logger,
                message=%entry.message,error_type=%entry.error_type.as_deref().unwrap_or(""),stack=%entry.stack.as_deref().unwrap_or(""));
        }
    }
}
