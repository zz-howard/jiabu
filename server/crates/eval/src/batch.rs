//! Bounded case admission. Already started cases are always drained, never aborted.
use anyhow::{Result, ensure};
use std::{collections::BTreeMap, future::Future};
use tokio::task::JoinSet;

pub struct Batch<T> {
    pub rows: Vec<T>,
    pub infrastructure_failed: bool,
}

pub async fn run<E, T, Run, Work, Publish>(
    entries: Vec<E>,
    jobs: usize,
    evaluate: Run,
    mut publish: Publish,
) -> Result<Batch<T>>
where
    E: Send + 'static,
    T: Clone + Send + 'static,
    Run: Fn(E) -> Work,
    Work: Future<Output = Result<T>> + Send + 'static,
    Publish: FnMut(&[T]) -> Result<()>,
{
    ensure!((1..=2).contains(&jobs), "jobs must be 1 or 2");
    let mut pending = entries.into_iter().enumerate();
    let mut active = JoinSet::new();
    let mut completed = BTreeMap::new();
    let mut infrastructure_failed = false;
    for (index, entry) in pending.by_ref().take(jobs) {
        let work = evaluate(entry);
        active.spawn(async move { (index, work.await) });
    }
    while let Some(completion) = active.join_next().await {
        match completion {
            Ok((index, Ok(row))) => {
                completed.insert(index, row);
                let rows = completed.values().cloned().collect::<Vec<_>>();
                if let Err(error) = publish(&rows) {
                    eprintln!(
                        "evaluation_infrastructure_error stage=report-write class={}",
                        crate::diagnostic::class(&error)
                    );
                    infrastructure_failed = true;
                }
            }
            Ok((_, Err(_))) => infrastructure_failed = true,
            Err(_) => {
                // JoinError text can include a panic payload; never format it.
                eprintln!("evaluation_infrastructure_error stage=case-worker class=join");
                infrastructure_failed = true;
            }
        }
        if !infrastructure_failed && let Some((index, entry)) = pending.next() {
            let work = evaluate(entry);
            active.spawn(async move { (index, work.await) });
        }
    }
    Ok(Batch {
        rows: completed.into_values().collect(),
        infrastructure_failed,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{
        Arc, Mutex,
        atomic::{AtomicBool, AtomicUsize, Ordering},
    };
    use tokio::sync::Notify;

    #[tokio::test]
    async fn at_most_two_cases_overlap_and_rows_are_in_original_order() -> Result<()> {
        let active = Arc::new(AtomicUsize::new(0));
        let maximum = Arc::new(AtomicUsize::new(0));
        let second_finished = Arc::new(Notify::new());
        let finish_order = Arc::new(Mutex::new(Vec::new()));
        let snapshots = Arc::new(Mutex::new(Vec::new()));
        let result = tokio::time::timeout(
            std::time::Duration::from_secs(2),
            run(
                vec![0usize, 1, 2, 3],
                2,
                {
                    let (active, maximum, signal, finish_order) = (
                        active.clone(),
                        maximum.clone(),
                        second_finished.clone(),
                        finish_order.clone(),
                    );
                    move |index| {
                        let (active, maximum, signal, finish_order) = (
                            active.clone(),
                            maximum.clone(),
                            signal.clone(),
                            finish_order.clone(),
                        );
                        async move {
                            maximum.fetch_max(
                                active.fetch_add(1, Ordering::SeqCst) + 1,
                                Ordering::SeqCst,
                            );
                            if index == 0 {
                                signal.notified().await;
                            }
                            finish_order.lock().unwrap().push(index);
                            if index == 1 {
                                signal.notify_one();
                            }
                            active.fetch_sub(1, Ordering::SeqCst);
                            Ok(index)
                        }
                    }
                },
                {
                    let snapshots = snapshots.clone();
                    move |rows| {
                        snapshots.lock().unwrap().push(rows.to_vec());
                        Ok(())
                    }
                },
            ),
        )
        .await??;
        assert_eq!(maximum.load(Ordering::SeqCst), 2);
        assert_eq!(result.rows, vec![0, 1, 2, 3]);
        assert!(!result.infrastructure_failed);
        assert_eq!(finish_order.lock().unwrap()[0], 1);
        assert!(
            snapshots
                .lock()
                .unwrap()
                .iter()
                .all(|rows| rows.windows(2).all(|w| w[0] < w[1]))
        );
        Ok(())
    }

    #[derive(Debug)]
    struct ObservedFailure(Arc<Notify>);
    impl std::fmt::Display for ObservedFailure {
        fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            f.write_str("synthetic failure")
        }
    }
    impl std::error::Error for ObservedFailure {}
    impl Drop for ObservedFailure {
        fn drop(&mut self) {
            self.0.notify_one();
        }
    }

    async fn fails_and_drains(report_failure: bool, panic_worker: bool) -> Result<()> {
        let started = Arc::new(AtomicUsize::new(0));
        let drained = Arc::new(AtomicBool::new(false));
        let failed = Arc::new(Notify::new());
        let release = Arc::new(Notify::new());
        let handle = tokio::spawn({
            let (started, drained, failed, release) = (
                started.clone(),
                drained.clone(),
                failed.clone(),
                release.clone(),
            );
            async move {
                run(
                    vec![0usize, 1, 2, 3],
                    2,
                    {
                        let (started, drained, failed, release) = (
                            started.clone(),
                            drained.clone(),
                            failed.clone(),
                            release.clone(),
                        );
                        move |index| {
                            let (started, drained, failed, release) = (
                                started.clone(),
                                drained.clone(),
                                failed.clone(),
                                release.clone(),
                            );
                            async move {
                                started.fetch_add(1, Ordering::SeqCst);
                                if index == 0 {
                                    release.notified().await;
                                    drained.store(true, Ordering::SeqCst);
                                } else if index == 1 && !report_failure {
                                    // The latch fires only when the collector drops the observed error/panic.
                                    // This avoids racing the test's release against the worker's return.
                                    if panic_worker {
                                        std::panic::panic_any(ObservedFailure(failed));
                                    }
                                    return Err(anyhow::Error::new(ObservedFailure(failed)));
                                }
                                Ok(index)
                            }
                        }
                    },
                    move |_| {
                        if report_failure {
                            failed.notify_one();
                            anyhow::bail!("synthetic write failure");
                        }
                        Ok(())
                    },
                )
                .await
            }
        });
        tokio::time::timeout(std::time::Duration::from_secs(2), failed.notified()).await?;
        assert!(!drained.load(Ordering::SeqCst));
        release.notify_one();
        let result = tokio::time::timeout(std::time::Duration::from_secs(2), handle).await???;
        assert!(result.infrastructure_failed);
        assert_eq!(started.load(Ordering::SeqCst), 2);
        assert!(drained.load(Ordering::SeqCst));
        assert!(result.rows.contains(&0));
        Ok(())
    }

    #[tokio::test]
    async fn case_infrastructure_error_stops_admission_and_drains_started_cases() -> Result<()> {
        fails_and_drains(false, false).await
    }
    #[tokio::test]
    async fn report_failure_stops_admission_and_drains_started_cases() -> Result<()> {
        fails_and_drains(true, false).await
    }
    #[tokio::test]
    async fn worker_panic_stops_admission_and_drains_started_cases() -> Result<()> {
        fails_and_drains(false, true).await
    }
    #[tokio::test]
    async fn one_job_preserves_serial_execution_and_invalid_bounds_are_rejected() -> Result<()> {
        let result = run(
            vec![1, 2, 3],
            1,
            |value| async move { Ok(value) },
            |_| Ok(()),
        )
        .await?;
        assert_eq!(result.rows, vec![1, 2, 3]);
        for jobs in [0, 3] {
            assert!(
                run(vec![1], jobs, |value| async move { Ok(value) }, |_| Ok(()))
                    .await
                    .is_err()
            );
        }
        Ok(())
    }
}
