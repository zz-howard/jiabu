use super::{AppDb, Mode, SpaceTx, support};
use crate::SystemTx;
use anyhow::Result;
use chrono::{DateTime, Duration, Utc};
use sea_orm::{ConnectionTrait, DbBackend, Statement};
fn instant() -> DateTime<Utc> {
    DateTime::parse_from_rfc3339("2026-10-28T00:00:00Z")
        .unwrap()
        .with_timezone(&Utc)
}
#[tokio::test]
async fn blob_retention_tracks_last_global_reference_and_resets_after_reuse() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let a = fixture.seed("first", "unused").await?;
    let b = fixture.seed("second", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let owner = fixture.owner().await?;
    let hash = [7_u8; 32];
    let now = instant();
    for plan in [&a, &b] {
        let tx = SpaceTx::begin(&db, plan.user_id, &[(plan.space_id, None)], Mode::Write).await?;
        tx.save_blob(plan.space_id, &hash, 100, (10, 10), now)
            .await?;
        tx.add_blob_ref(plan.space_id, "chat", &hash, now).await?;
        tx.commit().await?;
    }
    let unreferenced: Option<DateTime<Utc>> =
        sqlx::query_scalar("select unreferenced_at from blobs where sha256=$1")
            .bind(hash.to_vec())
            .fetch_one(&owner)
            .await?;
    assert_eq!(unreferenced, None);
    for (index, space) in [a.space_id, b.space_id].into_iter().enumerate() {
        let mut tx = SystemTx::begin(&db).await?;
        tx.lock_space(space).await?;
        tx.set_now(now + Duration::hours(index as i64)).await?;
        tx.tx
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "delete from blob_refs where space_id=$1",
                [space.0.into()],
            ))
            .await?;
        tx.commit().await?;
        let unreferenced: Option<DateTime<Utc>> =
            sqlx::query_scalar("select unreferenced_at from blobs where sha256=$1")
                .bind(hash.to_vec())
                .fetch_one(&owner)
                .await?;
        assert_eq!(
            unreferenced,
            if index == 0 {
                None
            } else {
                Some(now + Duration::hours(1))
            }
        );
    }
    let tx = SpaceTx::begin(&db, a.user_id, &[(a.space_id, None)], Mode::Write).await?;
    tx.add_blob_ref(a.space_id, "chat", &hash, now + Duration::hours(2))
        .await?;
    tx.commit().await?;
    let unreferenced: Option<DateTime<Utc>> =
        sqlx::query_scalar("select unreferenced_at from blobs where sha256=$1")
            .bind(hash.to_vec())
            .fetch_one(&owner)
            .await?;
    assert_eq!(unreferenced, None);
    let mut tx = SystemTx::begin(&db).await?;
    tx.lock_space(a.space_id).await?;
    tx.set_now(now + Duration::hours(3)).await?;
    tx.tx
        .execute_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            "delete from blob_refs where space_id=$1",
            [a.space_id.0.into()],
        ))
        .await?;
    tx.commit().await?;
    let unreferenced: Option<DateTime<Utc>> =
        sqlx::query_scalar("select unreferenced_at from blobs where sha256=$1")
            .bind(hash.to_vec())
            .fetch_one(&owner)
            .await?;
    assert_eq!(unreferenced, Some(now + Duration::hours(3)));
    owner.close().await;
    db.close().await?;
    Ok(())
}
#[tokio::test]
async fn blob_trigger_owner_search_path_and_execute_privileges_are_restricted() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let owner = fixture.owner().await?;
    for function in ["jiabu_blob_refs_lock()", "jiabu_blob_refs_retention()"] {
        let (role,definer,settings):(String,bool,Vec<String>)=sqlx::query_as("select r.rolname,p.prosecdef,p.proconfig from pg_proc p join pg_roles r on r.oid=p.proowner where p.oid=$1::regprocedure").bind(function).fetch_one(&owner).await?;
        assert_eq!(role, "jiabu_owner");
        assert!(definer);
        assert!(
            settings
                .iter()
                .any(|s| s == "search_path=pg_catalog, public, pg_temp")
        );
        for role in ["jiabu_app", "jiabu_admin"] {
            let executable: bool =
                sqlx::query_scalar("select has_function_privilege($1,$2,'EXECUTE')")
                    .bind(role)
                    .bind(function)
                    .fetch_one(&owner)
                    .await?;
            assert!(!executable);
        }
    }
    for table in ["blobs", "blob_refs", "records", "documents", "chat_entries"] {
        let readable: bool =
            sqlx::query_scalar("select has_table_privilege('jiabu_admin',$1,'SELECT')")
                .bind(table)
                .fetch_one(&owner)
                .await?;
        assert!(!readable);
    }
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn filesystem_candidate_filter_excludes_all_metadata_before_lifecycle_locks() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let seed = fixture.seed("sample", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let tx = SpaceTx::begin(&db, seed.user_id, &[(seed.space_id, None)], Mode::Write).await?;
    for byte in [0x11_u8, 0x22] {
        tx.save_blob(seed.space_id, &[byte; 32], 100, (10, 10), instant())
            .await?;
    }
    tx.add_blob_ref(seed.space_id, "ledger", &[0x22; 32], instant())
        .await?;
    tx.commit().await?;
    let filter = SystemTx::begin(&db).await?;
    assert!(!filter.blobs_locked);
    assert!(filter.untracked_blob_hashes(&[]).await?.is_empty());
    let result = filter
        .untracked_blob_hashes(&["11".repeat(32), "22".repeat(32), "33".repeat(32)])
        .await?;
    assert_eq!(result, vec![vec![0x33_u8; 32]]);
    filter.commit().await?;
    db.close().await?;
    Ok(())
}
