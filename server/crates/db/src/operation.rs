//! Shared transactional operation errors and stored replies.
use crate::{BeginError, DbErr};
use serde_json::Value;
#[derive(Clone, Debug, serde::Serialize)]
pub struct ValidationIssue {
    pub pointer: String,
    pub rule: String,
}
#[derive(Debug, thiserror::Error)]
#[error("{code}")]
pub struct Error {
    pub status: u16,
    pub code: &'static str,
    pub current: Option<Value>,
    pub errors: Option<Vec<ValidationIssue>>,
    pub retry_after: Option<u64>,
    /// Internal provenance only; never serialized into an HTTP problem.
    pub space_unavailable: bool,
}
impl Error {
    pub fn new(status: u16, code: &'static str) -> Self {
        Self {
            status,
            code,
            current: None,
            errors: None,
            retry_after: None,
            space_unavailable: false,
        }
    }
    pub fn not_found() -> Self {
        Self::new(404, "not_found")
    }
    pub fn invalid() -> Self {
        Self::new(422, "validation_failed")
    }
    /// `validation_failed` naming the offending field (JSON pointer) and rule.
    pub fn invalid_at(pointer: &str, rule: &str) -> Self {
        let mut error = Self::invalid();
        error.errors = Some(vec![ValidationIssue {
            pointer: pointer.into(),
            rule: rule.into(),
        }]);
        error
    }
    pub fn internal() -> Self {
        Self::new(500, "internal")
    }
    pub(crate) fn conflict(current: Value) -> Self {
        Self {
            status: 409,
            code: "conflict",
            current: Some(current),
            errors: None,
            retry_after: None,
            space_unavailable: false,
        }
    }
}
impl From<DbErr> for Error {
    fn from(_: DbErr) -> Self {
        Self::internal()
    }
}
impl From<BeginError> for Error {
    fn from(error: BeginError) -> Self {
        match error {
            BeginError::NotFound => {
                let mut error = Self::not_found();
                error.space_unavailable = true;
                error
            }
            BeginError::MembershipChanged => Self::new(409, "membership_changed"),
            BeginError::InvalidScope => Self::new(400, "bad_request"),
            BeginError::Database(_) => Self::internal(),
        }
    }
}
#[derive(Debug)]
pub struct Reply {
    pub status: u16,
    pub body: Value,
}
impl Reply {
    pub fn ok(body: Value) -> Self {
        Self { status: 200, body }
    }
}
