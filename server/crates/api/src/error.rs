use axum::{
    Json,
    http::{StatusCode, header},
    response::{IntoResponse, Response},
};
use serde::Serialize;
use utoipa::ToSchema;
use uuid::Uuid;
#[derive(Serialize, ToSchema)]
pub struct ValidationIssue {
    pub pointer: String,
    pub rule: String,
}
#[derive(Serialize, ToSchema)]
pub struct Problem {
    pub r#type: String,
    pub title: String,
    pub status: u16,
    pub code: String,
    pub request_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub errors: Option<Vec<ValidationIssue>>,
}
pub struct ApiError {
    pub status: StatusCode,
    pub code: &'static str,
    pub retry_after: Option<u64>,
}
impl ApiError {
    pub fn new(status: StatusCode, code: &'static str) -> Self {
        Self {
            status,
            code,
            retry_after: None,
        }
    }
    pub fn bad_request() -> Self {
        Self::new(StatusCode::BAD_REQUEST, "bad_request")
    }
    pub fn invalid() -> Self {
        Self::new(StatusCode::UNPROCESSABLE_ENTITY, "validation_failed")
    }
    pub fn unauthorized() -> Self {
        Self::new(StatusCode::UNAUTHORIZED, "unauthenticated")
    }
    pub fn internal() -> Self {
        Self::new(StatusCode::INTERNAL_SERVER_ERROR, "internal")
    }
    pub fn not_found() -> Self {
        Self::new(StatusCode::NOT_FOUND, "not_found")
    }
}
impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let problem = Problem {
            r#type: format!("urn:jiabu:error:{}", self.code),
            title: self.code.into(),
            status: self.status.as_u16(),
            code: self.code.into(),
            request_id: crate::middleware::request_id(),
            errors: (self.code == "validation_failed").then(|| {
                vec![ValidationIssue {
                    pointer: "/".into(),
                    rule: "invalid".into(),
                }]
            }),
        };
        let mut response = (self.status, Json(problem)).into_response();
        response.headers_mut().insert(
            header::CONTENT_TYPE,
            header::HeaderValue::from_static("application/problem+json"),
        );
        if let Some(seconds) = self.retry_after
            && let Ok(value) = seconds.to_string().parse()
        {
            response.headers_mut().insert(header::RETRY_AFTER, value);
        }
        response
    }
}
impl From<jiabu_db::DbErr> for ApiError {
    fn from(_: jiabu_db::DbErr) -> Self {
        Self::internal()
    }
}
impl From<jiabu_db::auth::AuthError> for ApiError {
    fn from(error: jiabu_db::auth::AuthError) -> Self {
        match error {
            jiabu_db::auth::AuthError::Unauthenticated => Self::unauthorized(),
            jiabu_db::auth::AuthError::Disabled => {
                Self::new(StatusCode::UNAUTHORIZED, "account_disabled")
            }
            jiabu_db::auth::AuthError::Database(e) => e.into(),
        }
    }
}
impl From<jiabu_db::BeginError> for ApiError {
    fn from(error: jiabu_db::BeginError) -> Self {
        match error {
            jiabu_db::BeginError::NotFound => Self::not_found(),
            jiabu_db::BeginError::MembershipChanged => {
                Self::new(StatusCode::CONFLICT, "membership_changed")
            }
            jiabu_db::BeginError::InvalidScope => Self::bad_request(),
            jiabu_db::BeginError::Database(e) => e.into(),
        }
    }
}
