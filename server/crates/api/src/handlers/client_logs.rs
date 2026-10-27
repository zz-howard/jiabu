use crate::{ApiError, SessionOnly};
use axum::{
    Json,
    extract::rejection::JsonRejection,
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
#[utoipa::path(post,path="/v1/client-logs",security(("bearer"=[])),request_body(content=ClientLogs,example=json!({"entries":[{"ts":"2026-01-01T00:00:00Z","level":"ERROR","logger":"example","message":"example crash","error_type":"ExampleError","stack":"example frame"}],"app_version":"0.1.0","build":1,"device_model":"example-device","os_version":"example-os"})),responses((status=204,description="Logs accepted"),(status=413,body=crate::Problem,description="Batch too large"),(status=422,body=crate::Problem,description="Entry too large")))]
pub(crate) async fn upload(
    SessionOnly(principal): SessionOnly,
    body: Result<Json<ClientLogs>, JsonRejection>,
) -> Result<Response, ApiError> {
    let request = super::input(body)?;
    if request.entries.len() > 100 {
        return Err(ApiError::new(
            StatusCode::PAYLOAD_TOO_LARGE,
            "payload_too_large",
        ));
    }
    if request
        .entries
        .iter()
        .any(|e| e.message.len() > 2048 || e.stack.as_ref().is_some_and(|s| s.len() > 8192))
    {
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
#[derive(Clone)]
pub(crate) struct AcceptedLogs {
    user_id: jiabu_domain::UserId,
    batch: ClientLogs,
}
impl AcceptedLogs {
    pub(crate) fn emit(self) {
        for entry in self.batch.entries {
            let client_request_id = entry
                .request_id
                .map(|id| id.to_string())
                .unwrap_or_default();
            tracing::info!(target:"client",request_id=%crate::middleware::request_id(),user_id=%self.user_id,
                client_request_id=%client_request_id,ts=%entry.ts,client_level=%entry.level,logger=%entry.logger,
                message=%entry.message,error_type=%entry.error_type.as_deref().unwrap_or(""),stack=%entry.stack.as_deref().unwrap_or(""),
                app_version=%self.batch.app_version,build=self.batch.build,device_model=%self.batch.device_model,os_version=%self.batch.os_version);
        }
    }
}
