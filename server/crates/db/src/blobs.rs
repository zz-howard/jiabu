//! Scoped logical references; physical storage remains in jiabu-storage.
use crate::{DbErr, OperationError as Error, SpaceTx};
use chrono::{DateTime, Utc};
use jiabu_domain::SpaceId;
use sea_orm::{ConnectionTrait, DatabaseTransaction, DbBackend, Statement};

/// Always acquire after the space write lock. No image decode/hash/resize here.
/// The two-int namespace cannot collide with the one-bigint space advisory locks.
pub(crate) async fn lock_lifecycle(tx: &DatabaseTransaction) -> Result<(), DbErr> {
    tx.execute_raw(Statement::from_string(
        DbBackend::Postgres,
        "select pg_advisory_xact_lock(726401, 4)".to_owned(),
    ))
    .await?;
    Ok(())
}
impl SpaceTx {
    pub async fn lock_blobs(&self) -> Result<(), DbErr> {
        self.assert_write();
        lock_lifecycle(&self.tx).await
    }
    pub async fn save_blob(
        &self,
        space: SpaceId,
        sha: &[u8],
        bytes: i64,
        dimensions: (i32, i32),
        now: DateTime<Utc>,
    ) -> Result<(), Error> {
        self.assert_write();
        self.member(space);
        self.lock_blobs().await?;
        self.tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into blobs(sha256,mime,bytes,width,height,created_at,unreferenced_at) values($1,'image/jpeg',$2,$3,$4,$5,$5) on conflict do nothing",
            vec![sha.to_vec().into(),bytes.into(),dimensions.0.into(),dimensions.1.into(),now.into()])).await?;
        Ok(())
    }
    pub async fn add_blob_ref(
        &self,
        space: SpaceId,
        module: &str,
        sha: &[u8],
        now: DateTime<Utc>,
    ) -> Result<(), Error> {
        self.assert_write();
        let member = self.member(space);
        if !matches!(module, "ledger" | "documents" | "chat") {
            return Err(Error::invalid());
        }
        self.lock_blobs().await?;
        self.tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into blob_refs(space_id,module,sha256,uploaded_by_member_id,created_at) values($1,$2,$3,$4,$5) on conflict do nothing",
            vec![space.0.into(),module.into(),sha.to_vec().into(),member.id().0.into(),now.into()])).await?;
        Ok(())
    }
    /// This method returns only modules of THIS space and THIS member's chat ref.
    /// The service still makes the single authorize(module, Read) decision.
    pub async fn blob_ref_modules(&self, space: SpaceId, sha: &[u8]) -> Result<Vec<String>, DbErr> {
        let member = self.member(space);
        let rows=self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select module from blob_refs where space_id=$1 and sha256=$2 and (module<>'chat' or uploaded_by_member_id=$3)",
            vec![space.0.into(),sha.to_vec().into(),member.id().0.into()])).await?;
        rows.into_iter()
            .map(|row| row.try_get("", "module"))
            .collect()
    }
    /// Called only by an authorized ledger write. The source must be an existing
    /// ledger reference or the current caller's chat reference, never another's.
    pub(crate) async fn ledger_blob_ref(&self, space: SpaceId, sha: &str) -> Result<(), Error> {
        self.assert_write();
        let member = self.member(space);
        self.lock_blobs().await?;
        let row=self.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into blob_refs(space_id,module,sha256,uploaded_by_member_id) select $1,'ledger',decode($2,'hex'),$3 where exists(select 1 from blob_refs where space_id=$1 and sha256=decode($2,'hex') and (module='ledger' or (module='chat' and uploaded_by_member_id=$3))) on conflict do nothing returning id",
            vec![space.0.into(),sha.into(),member.id().0.into()])).await?;
        if row.is_some() {
            return Ok(());
        }
        // ON CONFLICT may mean the ledger ref already exists. Distinguish that
        // from a hidden/missing source without consulting another space.
        let exists=self.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select id from blob_refs where space_id=$1 and module='ledger' and sha256=decode($2,'hex')",
            vec![space.0.into(),sha.into()])).await?;
        if exists.is_none() {
            return Err(Error::new(422, "blob_missing"));
        }
        Ok(())
    }
}

impl SpaceTx {
    /// S6 counterpart of ledger_blob_ref above. Keep the same lock order and
    /// indistinguishable blob_missing response; ledger refs alone are not sources.
    pub(crate) async fn documents_blob_ref(&self, space: SpaceId, sha: &str) -> Result<(), Error> {
        self.assert_write();
        let member = self.member(space);
        self.lock_blobs().await?;
        let row=self.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into blob_refs(space_id,module,sha256,uploaded_by_member_id) select $1,'documents',decode($2,'hex'),$3 where exists(select 1 from blob_refs where space_id=$1 and sha256=decode($2,'hex') and (module='documents' or (module='chat' and uploaded_by_member_id=$3))) on conflict do nothing returning id",
            vec![space.0.into(),sha.into(),member.id().0.into()])).await?;
        if row.is_some() {
            return Ok(());
        }
        let exists=self.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select id from blob_refs where space_id=$1 and module='documents' and sha256=decode($2,'hex')",vec![space.0.into(),sha.into()])).await?;
        if exists.is_none() {
            return Err(Error::new(422, "blob_missing"));
        }
        Ok(())
    }
}
