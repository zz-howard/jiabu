use crate::{ActiveMember, AppDb, GrantLevel};
use jiabu_domain::{JoinEpoch, MemberId, SpaceId, UserId};
use sea_orm::{
    ConnectionTrait, DatabaseTransaction, DbBackend, DbErr, Statement, TransactionTrait,
};
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Mode {
    Read,
    Write,
}
#[derive(Debug, thiserror::Error)]
pub enum BeginError {
    #[error("not_found")]
    NotFound,
    #[error("membership_changed")]
    MembershipChanged,
    #[error("bad_request")]
    InvalidScope,
    #[error(transparent)]
    Database(#[from] DbErr),
}
pub struct SpaceTx {
    pub(crate) tx: DatabaseTransaction,
    members: Vec<ActiveMember>,
    locked: bool,
    #[cfg(test)]
    pub(crate) refund_gate: Option<(
        std::sync::Arc<tokio::sync::Notify>,
        std::sync::Arc<tokio::sync::Notify>,
    )>,
}
impl SpaceTx {
    pub async fn begin(
        db: &AppDb,
        user: UserId,
        spaces: &[(SpaceId, Option<JoinEpoch>)],
        mode: Mode,
    ) -> Result<Self, BeginError> {
        if spaces.is_empty() || (mode == Mode::Write && spaces.len() != 1) {
            return Err(BeginError::InvalidScope);
        }
        let mut unique = std::collections::HashSet::new();
        if spaces.iter().any(|(id, _)| !unique.insert(*id)) {
            return Err(BeginError::InvalidScope);
        }
        let tx = db.connection.begin().await?;
        if mode == Mode::Write {
            tx.execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select pg_advisory_xact_lock(hashtextextended($1::text, 0))",
                [spaces[0].0.to_string().into()],
            ))
            .await?;
        }
        let mut members = Vec::with_capacity(spaces.len());
        for (space, _) in spaces {
            let row = tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
                "select m.id, m.join_epoch, m.role, \
                 coalesce((select level from space_member_grants where member_id=m.id and module='ledger'),'none') ledger, \
                 coalesce((select level from space_member_grants where member_id=m.id and module='documents'),'none') documents \
                 from space_members m join spaces s on s.id=m.space_id \
                 where m.space_id=$1 and m.user_id=$2 and m.status='active' and s.deleted_at is null",
                [space.0.into(), user.0.into()])).await?.ok_or(BeginError::NotFound)?;
            let epoch = JoinEpoch(row.try_get("", "join_epoch")?);
            members.push(ActiveMember {
                id: MemberId(row.try_get("", "id")?),
                space: *space,
                user,
                epoch,
                owner: row.try_get::<String>("", "role")? == "owner",
                ledger: GrantLevel::from_db(&row.try_get::<String>("", "ledger")?),
                documents: GrantLevel::from_db(&row.try_get::<String>("", "documents")?),
            });
        }
        // Confirm every membership before exposing any epoch mismatch.
        for ((_, expected), member) in spaces.iter().zip(&members) {
            if expected.is_some_and(|epoch| epoch != member.join_epoch()) {
                return Err(BeginError::MembershipChanged);
            }
        }
        let ids = format!(
            "{{{}}}",
            spaces
                .iter()
                .map(|(id, _)| id.to_string())
                .collect::<Vec<_>>()
                .join(",")
        );
        tx.execute_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            "select set_config('jiabu.space_ids', $1, true)",
            [ids.into()],
        ))
        .await?;
        Ok(Self {
            tx,
            members,
            locked: mode == Mode::Write,
            #[cfg(test)]
            refund_gate: None,
        })
    }
    /// Private bootstrap context: only the checked creation/invitation services use it.
    /// No ActiveMember is manufactured for an invitee who has not joined yet.
    pub(crate) async fn bootstrap(db: &AppDb, space: SpaceId) -> Result<Self, DbErr> {
        let tx = db.connection.begin().await?;
        tx.execute_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            "select pg_advisory_xact_lock(hashtextextended($1::text, 0))",
            [space.to_string().into()],
        ))
        .await?;
        Ok(Self {
            tx,
            members: Vec::new(),
            locked: true,
            #[cfg(test)]
            refund_gate: None,
        })
    }
    pub(crate) async fn allow_bootstrap_space(&self, space: SpaceId) -> Result<(), DbErr> {
        self.tx
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select set_config('jiabu.space_ids', $1, true)",
                [format!("{{{space}}}").into()],
            ))
            .await?;
        Ok(())
    }
    pub fn member(&self, space: SpaceId) -> &ActiveMember {
        // Programming invariant: callers can only request a space passed to begin.
        match self.members.iter().find(|m| m.space_id() == space) {
            Some(member) => member,
            None => panic!("space must be in transaction scope"),
        }
    }
    pub(crate) fn assert_write(&self) {
        assert!(self.locked, "space mutation requires a write lock");
    }
    pub async fn next_seq(&self) -> Result<i64, DbErr> {
        assert!(self.locked, "change_seq requires a space write lock");
        let row = self
            .tx
            .query_one_raw(Statement::from_string(
                DbBackend::Postgres,
                "select nextval('change_seq') as seq".to_owned(),
            ))
            .await?
            .ok_or_else(|| DbErr::Custom("sequence returned no row".into()))?;
        row.try_get("", "seq")
    }
    pub async fn commit(self) -> Result<(), DbErr> {
        self.tx.commit().await
    }
    pub async fn rollback(self) -> Result<(), DbErr> {
        self.tx.rollback().await
    }
}
