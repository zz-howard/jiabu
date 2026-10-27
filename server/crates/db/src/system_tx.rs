use crate::AppDb;
use jiabu_domain::SpaceId;
use sea_orm::{
    ConnectionTrait, DatabaseTransaction, DbBackend, DbErr, Statement, TransactionTrait,
};
pub struct SystemTx {
    pub(crate) tx: DatabaseTransaction,
    locked: Option<SpaceId>,
    pub(crate) blobs_locked: bool,
}
impl SystemTx {
    pub async fn begin(db: &AppDb) -> Result<Self, DbErr> {
        let tx = db.connection.begin().await?;
        tx.execute_raw(Statement::from_string(
            DbBackend::Postgres,
            "select set_config('jiabu.system', 'on', true)".to_owned(),
        ))
        .await?;
        Ok(Self {
            tx,
            locked: None,
            blobs_locked: false,
        })
    }
    pub async fn lock_space(&mut self, space: SpaceId) -> Result<(), DbErr> {
        // Fixed order: space -> blob lifecycle; collectors never acquire a space.
        assert!(
            !self.blobs_locked,
            "space lock must precede blob lifecycle lock"
        );
        assert!(
            self.locked.is_none_or(|id| id == space),
            "one space per write transaction"
        );
        self.tx
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select pg_advisory_xact_lock(hashtextextended($1::text, 0))",
                [space.to_string().into()],
            ))
            .await?;
        self.locked = Some(space);
        Ok(())
    }
    pub async fn next_seq(&self, space: SpaceId) -> Result<i64, DbErr> {
        assert_eq!(
            self.locked,
            Some(space),
            "change_seq requires this space lock"
        );
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
    pub async fn purge_space(&mut self, space: SpaceId) -> Result<(), DbErr> {
        self.lock_space(space).await?;
        self.tx
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select purge_space($1)",
                [space.0.into()],
            ))
            .await?;
        Ok(())
    }
    pub async fn rollback(self) -> Result<(), DbErr> {
        self.tx.rollback().await
    }
    pub async fn commit(self) -> Result<(), DbErr> {
        self.tx.commit().await
    }
}

impl SystemTx {
    /// Deleted spaces with any purgeable rows. No persistent queue/marker is needed:
    /// the tombstone and remaining rows are the durable retry state.
    pub async fn spaces_to_purge(&self) -> Result<Vec<SpaceId>, DbErr> {
        let rows = self.tx.query_all_raw(Statement::from_string(DbBackend::Postgres,
            "select s.id from spaces s where s.deleted_at is not null and (
             exists(select 1 from space_member_grants g join space_members m on m.id=g.member_id where m.space_id=s.id) or
             exists(select 1 from space_invitations where space_id=s.id) or
             exists(select 1 from space_events where space_id=s.id) or
             exists(select 1 from agent_runs where space_id=s.id) or
             exists(select 1 from conversations where space_id=s.id) or
             exists(select 1 from chat_entries where space_id=s.id) or
             exists(select 1 from chat_stream_events where space_id=s.id) or
             exists(select 1 from chat_actions where space_id=s.id) or
             exists(select 1 from entity_events where space_id=s.id) or
             exists(select 1 from blob_refs where space_id=s.id) or
             exists(select 1 from records where space_id=s.id) or
             exists(select 1 from allocation_plans where space_id=s.id) or
             exists(select 1 from accounts where space_id=s.id) or
             exists(select 1 from tags where space_id=s.id) or
             exists(select 1 from documents where space_id=s.id) or
             exists(select 1 from subjects where space_id=s.id) or
             exists(select 1 from api_key_audit where space_id=s.id)) order by s.id".to_owned())).await?;
        rows.into_iter()
            .map(|row| row.try_get("", "id").map(SpaceId))
            .collect()
    }
}
