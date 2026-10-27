use crate::{Effect, ToolError};
use chrono::{DateTime, Utc};
use jiabu_db::{ActiveMember, AppDb, Mode, Principal, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
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
        if effect == Effect::LocalWrite && epoch.is_none() {
            return Err(ToolError::new(400, "bad_request"));
        }
        let tx = SpaceTx::begin(db, principal.user_id, &[(space_id, epoch)], Mode::Read).await?;
        let member = tx.member(space_id).clone();
        Ok(Self {
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
            via_api_key_id: None,
            via_api_key_name: None,
            now: invocation.now,
            replay_key: invocation.replay_key,
            tx: Mutex::new(Some(tx)),
        })
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
        supplied
            .or(self.idempotency_key)
            .ok_or_else(|| ToolError::new(400, "idempotency_key_required"))
    }
}
