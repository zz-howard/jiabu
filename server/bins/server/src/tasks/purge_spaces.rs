use jiabu_db::{AppDb, DbErr, SystemTx};
use std::{sync::Arc, time::Duration};
use tokio::sync::Notify;

/// Direct test entry point, also used by startup recovery and the notification loop.
pub(crate) async fn purge_deleted_spaces_once(db: &AppDb) -> Result<(), DbErr> {
    let scan = SystemTx::begin(db).await?;
    let spaces = scan.spaces_to_purge().await?;
    scan.commit().await?;
    let mut failure = None;
    for space in spaces {
        let result = async {
            let mut tx = SystemTx::begin(db).await?;
            tx.purge_space(space).await?;
            tx.commit().await
        }
        .await;
        if let Err(error) = result {
            // Never log SQL errors, labels, or content. A failed space must not block others.
            tracing::error!(space_id=%space, "Space purge failed; retry scheduled");
            failure = Some(error);
        }
    }
    match failure {
        Some(error) => Err(error),
        None => Ok(()),
    }
}
pub(crate) async fn run(db: AppDb, signal: Arc<Notify>) {
    loop {
        if purge_deleted_spaces_once(&db).await.is_err() {
            tracing::error!("Space purge scan failed; retry scheduled");
        }
        tokio::select! {
            _ = signal.notified() => {},
            _ = tokio::time::sleep(Duration::from_secs(30)) => {},
        }
    }
}
#[cfg(test)]
#[path = "purge_spaces_tests.rs"]
mod tests;
