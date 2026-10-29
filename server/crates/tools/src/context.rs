use crate::{Effect, ToolError};
use chrono::{DateTime, Utc};
use jiabu_db::{ActiveMember, AppDb, Mode, Principal, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};
use tokio::sync::Mutex;
use uuid::Uuid;

pub struct Invocation {
    pub idempotency_key: Option<Uuid>,
    pub replay_key: Option<String>,
    pub run_id: Option<Uuid>,
    pub request_id: Uuid,
    pub now: DateTime<Utc>,
}
/// Construction checks membership/epoch in a read transaction without a write lock.
/// After parameter validation, invoke opens the write transaction and rechecks the
/// live member/epoch under its space lock. No arbitrary member can be supplied.
pub struct ToolCtx {
    pub(crate) run_lease: Option<jiabu_db::chat_runtime::RunLease>,
    pub space_id: SpaceId,
    pub member: ActiveMember,
    pub(crate) bound_space: SpaceId,
    pub(crate) bound_effect: Effect,
    pub(crate) db: AppDb,
    pub(crate) epoch: Option<JoinEpoch>,
    pub principal: Principal,
    pub idempotency_key: Option<Uuid>,
    pub run_id: Option<Uuid>,
    pub request_id: Uuid,
    pub via_api_key_id: Option<Uuid>,
    pub via_api_key_name: Option<String>,
    pub now: DateTime<Utc>,
    pub(crate) replay_key: Option<String>,
    pub(crate) tx: Mutex<Option<SpaceTx>>,
    pub audit_completed: Arc<AtomicBool>,
    /// Trusted entry-point operation (e.g. push:create_tag), never tool arguments.
    pub api_key_operation: Option<String>,
}
impl ToolCtx {
    pub async fn begin(
        db: &AppDb,
        principal: Principal,
        space_id: SpaceId,
        epoch: Option<JoinEpoch>,
        effect: Effect,
        invocation: Invocation,
    ) -> Result<Self, ToolError> {
        let tx = SpaceTx::begin(db, principal.user_id, &[(space_id, epoch)], Mode::Read).await?;
        if effect == Effect::LocalWrite
            && epoch.is_none()
            && matches!(principal.via, jiabu_db::Via::Session { .. })
        {
            return Err(ToolError::new(400, "bad_request"));
        }
        let member = tx.member(space_id).clone();
        let (via_api_key_id, via_api_key_name) = match &principal.via {
            jiabu_db::Via::ApiKey { id, name, .. } => (Some(*id), Some(name.clone())),
            _ => (None, None),
        };
        Ok(Self {
            run_lease: None,
            space_id,
            member,
            bound_space: space_id,
            bound_effect: effect,
            db: db.clone(),
            epoch,
            principal,
            idempotency_key: invocation.idempotency_key,
            run_id: invocation.run_id,
            request_id: invocation.request_id,
            via_api_key_id,
            via_api_key_name,
            now: invocation.now,
            replay_key: invocation.replay_key,
            tx: Mutex::new(Some(tx)),
            audit_completed: Arc::new(AtomicBool::new(false)),
            api_key_operation: None,
        })
    }
    /// Agent callers first prepare arguments outside the write lock, then build
    /// context from their guarded transaction. This context owns no transaction.
    pub fn for_transaction(
        db: &AppDb,
        principal: Principal,
        tx: &SpaceTx,
        space_id: SpaceId,
        epoch: JoinEpoch,
        effect: Effect,
        invocation: Invocation,
    ) -> Result<Self, ToolError> {
        principal.require_ai_session()?;
        let member = tx
            .tool_member(
                space_id,
                principal.user_id,
                Some(epoch),
                effect == Effect::LocalWrite,
            )?
            .clone();
        Ok(Self {
            run_lease: None,
            space_id,
            member,
            bound_space: space_id,
            bound_effect: effect,
            db: db.clone(),
            epoch: Some(epoch),
            principal,
            idempotency_key: invocation.idempotency_key,
            run_id: invocation.run_id,
            request_id: invocation.request_id,
            via_api_key_id: None,
            via_api_key_name: None,
            now: invocation.now,
            replay_key: invocation.replay_key,
            tx: Mutex::new(None),
            audit_completed: Arc::new(AtomicBool::new(false)),
            api_key_operation: None,
        })
    }
    pub fn bind_run_lease(
        mut self,
        lease: jiabu_db::chat_runtime::RunLease,
    ) -> Result<Self, ToolError> {
        if self.run_id != Some(lease.run_id) {
            return Err(ToolError::not_found());
        }
        self.run_lease = Some(lease);
        Ok(self)
    }
    pub(crate) fn key_audit(
        &self,
        name: &str,
        outcome: &'static str,
    ) -> Option<jiabu_db::api_key_audit::ApiKeyAudit> {
        let jiabu_db::Via::ApiKey { id, .. } = &self.principal.via else {
            return None;
        };
        Some(jiabu_db::api_key_audit::ApiKeyAudit {
            key_id: *id,
            user_id: self.principal.user_id.0,
            space_id: Some(self.bound_space.0),
            operation: self
                .api_key_operation
                .clone()
                .unwrap_or_else(|| format!("tool:{name}")),
            effect: if self.bound_effect == Effect::Read {
                "read"
            } else {
                "local_write"
            },
            outcome,
            request_id: self.request_id,
            idempotency_key: self.replay_key.clone(),
        })
    }
    pub(crate) fn audit_done(&self) {
        self.audit_completed.store(true, Ordering::Release);
    }
    pub fn audit(&self, member: &ActiveMember) -> jiabu_db::ledger::AuditCtx {
        jiabu_db::ledger::AuditCtx {
            actor_member_id: Some(member.id().0),
            run_id: self.run_id,
            request_id: Some(self.request_id),
            via_api_key_id: self.via_api_key_id,
            via_api_key_name: self.via_api_key_name.clone(),
            now: self.now,
            origin: if self.run_id.is_some() { "chat" } else { "api" },
        }
    }
    pub fn new_id(&self, supplied: Option<Uuid>) -> Result<Uuid, ToolError> {
        // Agent-created entities use the durable call identity, even when a
        // model supplies an unrelated ID. Retry copies that identity verbatim.
        (if self.run_id.is_some() {
            self.idempotency_key
        } else {
            supplied.or(self.idempotency_key)
        })
        .ok_or_else(|| ToolError::new(400, "idempotency_key_required"))
    }
}
