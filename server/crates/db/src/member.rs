use jiabu_domain::{JoinEpoch, MemberId, SpaceId, UserId};
#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub enum GrantLevel {
    None,
    Read,
    Write,
    Manage,
}
impl GrantLevel {
    pub(crate) fn from_db(value: &str) -> Self {
        match value {
            "read" => Self::Read,
            "write" => Self::Write,
            "manage" => Self::Manage,
            _ => Self::None,
        }
    }
}
/// Only SpaceTx can instantiate an active membership.
#[derive(Debug)]
pub struct ActiveMember {
    pub(super) id: MemberId,
    pub(super) space: SpaceId,
    pub(super) user: UserId,
    pub(super) epoch: JoinEpoch,
    pub(super) owner: bool,
    pub(super) ledger: GrantLevel,
    pub(super) documents: GrantLevel,
}
impl ActiveMember {
    pub fn id(&self) -> MemberId {
        self.id
    }
    pub fn space_id(&self) -> SpaceId {
        self.space
    }
    pub fn user_id(&self) -> UserId {
        self.user
    }
    pub fn join_epoch(&self) -> JoinEpoch {
        self.epoch
    }
    pub fn is_owner(&self) -> bool {
        self.owner
    }
    pub fn ledger_grant(&self) -> GrantLevel {
        self.ledger
    }
    pub fn documents_grant(&self) -> GrantLevel {
        self.documents
    }
}
