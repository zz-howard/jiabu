use jiabu_db::{AppDb, SystemTx, ledger::Clock};
use jiabu_storage::{BlobHash, BlobStore};
use std::{collections::BTreeSet, sync::Arc, time::Duration};
#[derive(Debug, Default)]
pub(crate) struct CleanupReport {
    pub idempotency: u64,
    pub blobs: u64,
    pub staging: u64,
    pub failures: u64,
}
/// One injected instant per pass. The listing/scan happens outside the lifecycle
/// lock; each short collection transaction rechecks before touching any file.
pub(crate) async fn cleanup_once(
    db: &AppDb,
    store: &BlobStore,
    clock: &dyn Clock,
) -> anyhow::Result<CleanupReport> {
    #[cfg(test)]
    let result = collect(db, store, clock, None).await;
    #[cfg(not(test))]
    let result = collect(db, store, clock).await;
    result
}
async fn collect(
    db: &AppDb,
    store: &BlobStore,
    clock: &dyn Clock,
    #[cfg(test)] gate: Option<(Arc<tokio::sync::Notify>, Arc<tokio::sync::Notify>)>,
) -> anyhow::Result<CleanupReport> {
    let now = clock.now();
    let tx = SystemTx::begin(db).await?;
    tx.set_now(now).await?;
    let mut report = CleanupReport {
        idempotency: tx.cleanup_idempotency(now).await?,
        ..Default::default()
    };
    let mut hashes = BTreeSet::new();
    for sha in tx.orphan_blobs(now).await? {
        let bytes: [u8; 32] = sha
            .try_into()
            .map_err(|_| anyhow::anyhow!("invalid blob digest"))?;
        hashes.insert(BlobHash::from_bytes(bytes));
    }
    tx.commit().await?;
    let staging_store = BlobStore::clone(store);
    report.staging = tokio::task::spawn_blocking(move || {
        staging_store.cleanup_staging(now - chrono::Duration::days(1))
    })
    .await??;
    let filesystem_candidates = store
        .candidates()
        .await?
        .into_iter()
        .filter(|object| object.newest <= now - chrono::Duration::days(1))
        .map(|object| object.hash.to_string())
        .collect::<Vec<_>>();
    // Filter the file scan in bulk outside the global lock. Known blobs follow
    // the DB last-reference clock above, never the age of their physical files.
    let tx = SystemTx::begin(db).await?;
    for sha in tx.untracked_blob_hashes(&filesystem_candidates).await? {
        let bytes: [u8; 32] = sha
            .try_into()
            .map_err(|_| anyhow::anyhow!("invalid blob digest"))?;
        hashes.insert(BlobHash::from_bytes(bytes));
    }
    tx.commit().await?;
    #[cfg(test)]
    if let Some((entered, release)) = gate {
        entered.notify_one();
        release.notified().await;
    }
    for hash in hashes {
        let result = async {
            let mut tx = SystemTx::begin(db).await?;
            tx.lock_blobs().await?;
            if !tx.blob_collectible(&hash.bytes(), now).await? {
                tx.commit().await?;
                return anyhow::Ok(false);
            }
            // A failed upload may have created another variant after the
            // outside-lock listing. Recheck filesystem-only orphan age here.
            if !tx.blob_has_metadata(&hash.bytes()).await?
                && store
                    .newest(hash)
                    .await?
                    .is_some_and(|time| time > now - chrono::Duration::days(1))
            {
                tx.commit().await?;
                return anyhow::Ok(false);
            }
            // No space lock is ever acquired here: fixed ordering is space ->
            // lifecycle for writers, lifecycle alone for collectors.
            store.delete(hash).await?;
            tx.delete_blob_metadata(&hash.bytes()).await?;
            tx.commit().await?;
            anyhow::Ok(true)
        }
        .await;
        match result {
            Ok(true) => report.blobs += 1,
            Ok(false) => {}
            Err(_) => {
                report.failures += 1;
                tracing::error!(code = "internal", "Blob cleanup failed; retry scheduled");
            }
        }
    }
    Ok(report)
}
pub(crate) async fn run(db: AppDb, store: Arc<BlobStore>, clock: Arc<dyn Clock>) {
    loop {
        match cleanup_once(&db, &store, clock.as_ref()).await {
            Ok(report) => tracing::info!(
                idempotency_deleted = report.idempotency,
                blobs_deleted = report.blobs,
                staging_deleted = report.staging,
                failures = report.failures,
                "Cleanup pass completed"
            ),
            Err(_) => tracing::error!(code = "internal", "Cleanup pass failed; retry scheduled"),
        }
        tokio::time::sleep(Duration::from_secs(24 * 60 * 60)).await;
    }
}
#[cfg(test)]
#[path = "cleanup_tests.rs"]
mod tests;
