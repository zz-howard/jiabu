use crate::AppDb;
use jiabu_domain::SpaceId;
use sea_orm::{
    ConnectionTrait, DatabaseTransaction, DbBackend, DbErr, Statement, TransactionTrait,
};
pub struct SystemTx {
    pub(crate) tx: DatabaseTransaction,
    locked: Option<SpaceId>,
}
impl SystemTx {
    pub async fn begin(db: &AppDb) -> Result<Self, DbErr> {
        let tx = db.connection.begin().await?;
        tx.execute_raw(Statement::from_string(
            DbBackend::Postgres,
            "select set_config('jiabu.system', 'on', true)".to_owned(),
        ))
        .await?;
        Ok(Self { tx, locked: None })
    }
    pub async fn lock_space(&mut self, space: SpaceId) -> Result<(), DbErr> {
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
