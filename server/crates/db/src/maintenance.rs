//! Background-only persistence operations. API code never acquires this context.
use crate::{DbErr, SystemTx};
use chrono::{DateTime, Duration, Utc};
use sea_orm::{ConnectionTrait, DbBackend, Statement};
impl SystemTx {
    pub async fn set_now(&self, now: DateTime<Utc>) -> Result<(), DbErr> {
        self.tx
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select set_config('jiabu.task_now',$1,true)",
                [now.to_rfc3339_opts(chrono::SecondsFormat::Micros, true)
                    .into()],
            ))
            .await?;
        Ok(())
    }
    pub async fn lock_blobs(&mut self) -> Result<(), DbErr> {
        crate::blobs::lock_lifecycle(&self.tx).await?;
        self.blobs_locked = true;
        Ok(())
    }
    pub async fn cleanup_idempotency(&self, now: DateTime<Utc>) -> Result<u64, DbErr> {
        Ok(self
            .tx
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "delete from idempotency where created_at<=$1",
                [(now - Duration::days(90)).into()],
            ))
            .await?
            .rows_affected())
    }
    pub async fn orphan_blobs(&self, now: DateTime<Utc>) -> Result<Vec<Vec<u8>>, DbErr> {
        let rows=self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select sha256 from blobs where unreferenced_at<=$1 order by unreferenced_at,sha256",
            [(now-Duration::days(1)).into()])).await?;
        rows.into_iter()
            .map(|row| row.try_get("", "sha256"))
            .collect()
    }
    /// Filter filesystem candidates in ONE query before taking any lifecycle
    /// lock. Hex keys come from the storage layer's validated content addresses.
    /// Existing metadata is handled exclusively by orphan_blobs' retention clock.
    pub async fn untracked_blob_hashes(&self, hashes: &[String]) -> Result<Vec<Vec<u8>>, DbErr> {
        assert!(
            !self.blobs_locked,
            "candidate filtering must precede lifecycle locks"
        );
        let rows = self.tx.query_all_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            "select decode(c.value,'hex') sha256 from jsonb_array_elements_text($1::jsonb) c(value) where not exists(select 1 from blobs b where b.sha256=decode(c.value,'hex')) order by sha256",
            [serde_json::json!(hashes).into()],
        )).await?;
        rows.into_iter()
            .map(|row| row.try_get("", "sha256"))
            .collect()
    }
    /// Under the lifecycle lock, check global references again, never just RLS's
    /// current space. The background context is deliberately global.
    pub async fn blob_collectible(&self, sha: &[u8], now: DateTime<Utc>) -> Result<bool, DbErr> {
        assert!(self.blobs_locked, "blob cleanup requires lifecycle lock");
        let row=self.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select not exists(select 1 from blob_refs where sha256=$1) and not exists(select 1 from blobs where sha256=$1 and (unreferenced_at is null or unreferenced_at>$2)) collectible",
            vec![sha.to_vec().into(),(now-Duration::days(1)).into()])).await?.ok_or_else(||DbErr::Custom("missing collection decision".into()))?;
        row.try_get("", "collectible")
    }
    pub async fn blob_has_metadata(&self, sha: &[u8]) -> Result<bool, DbErr> {
        assert!(self.blobs_locked, "blob cleanup requires lifecycle lock");
        Ok(self
            .tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select 1 from blobs where sha256=$1",
                [sha.to_vec().into()],
            ))
            .await?
            .is_some())
    }
    pub async fn delete_blob_metadata(&self, sha: &[u8]) -> Result<(), DbErr> {
        assert!(self.blobs_locked, "blob cleanup requires lifecycle lock");
        self.tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "delete from blobs where sha256=$1 and not exists(select 1 from blob_refs where sha256=$1)",[sha.to_vec().into()])).await?;
        Ok(())
    }
}
