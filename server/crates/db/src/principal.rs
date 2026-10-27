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
    /// Personal key scope never contains a list of spaces: membership is live.
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
impl Principal {
    pub fn require_account_session(&self) -> Result<(), crate::OperationError> {
        if matches!(self.via, Via::ApiKey { .. }) {
            return Err(crate::OperationError::new(403, "api_key_not_allowed"));
        }
        Ok(())
    }
    /// Shared guard for future RunService::start/retry as well as SessionOnly.
    pub fn require_ai_session(&self) -> Result<(), crate::OperationError> {
        if matches!(self.via, Via::ApiKey { .. }) {
            return Err(crate::OperationError::new(403, "api_key_ai_not_allowed"));
        }
        Ok(())
    }
    /// Call after checking live space membership and before module authorization.
    pub fn require_read_write(&self) -> Result<(), crate::OperationError> {
        if let Via::ApiKey { scope, .. } = &self.via
            && scope != "read_write"
        {
            return Err(crate::OperationError::new(403, "api_key_read_only"));
        }
        Ok(())
    }
}
