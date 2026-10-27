pub(crate) mod auth;
pub(crate) mod client_logs;
pub(crate) mod me;
pub(crate) mod meta;
use crate::ApiError;
use axum::{Json, extract::rejection::JsonRejection, http::StatusCode};
pub(crate) fn input<T>(value: Result<Json<T>, JsonRejection>) -> Result<T, ApiError> {
    value.map(|Json(value)| value).map_err(|e| {
        let status = e.status();
        match status {
            StatusCode::PAYLOAD_TOO_LARGE => ApiError::new(status, "payload_too_large"),
            StatusCode::UNSUPPORTED_MEDIA_TYPE => ApiError::new(status, "unsupported_media_type"),
            _ => ApiError::bad_request(),
        }
    })
}
