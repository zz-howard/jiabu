use jiabu_db::{
    AppDb,
    ledger::{SystemClock, run_allocations},
};
use std::time::Duration;
pub(crate) async fn run(db: AppDb) {
    let mut interval = tokio::time::interval(Duration::from_secs(60 * 60));
    interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        interval.tick().await; // First tick is immediate: recover after downtime.
        match run_allocations(&db, &SystemClock).await {
            Ok(report) if report.failed_spaces == 0 => (),
            _ => tracing::error!("Monthly allocation failed; retry scheduled"),
        }
    }
}
