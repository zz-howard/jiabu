//! Shared authenticated identity. Token extraction remains in the API crate.
use crate::auth::{SessionKind, User};
use jiabu_domain::{SessionId, UserId};
use uuid::Uuid;
#[derive(Clone)]
pub enum Via {
    Session {
        session_id: SessionId,
        kind: SessionKind,
    },
    /// S5: reserved contract only; S3 does not authenticate or execute API keys.
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
