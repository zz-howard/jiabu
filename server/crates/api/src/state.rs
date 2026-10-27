use crate::middleware::{LoginLimiter, WindowLimiter};
use jiabu_db::AppDb;
use std::{sync::Arc, time::Duration};
use tokio::sync::Semaphore;
/// Client log batches accepted per user per minute.
pub(crate) const CLIENT_LOG_BATCHES_PER_MINUTE: usize = 10;
#[derive(Clone)]
pub struct AppState {
    pub db: AppDb,
    pub(crate) limiter: Arc<LoginLimiter>,
    pub(crate) client_logs: Arc<WindowLimiter>,
    pub(crate) dummy_hash: Arc<String>,
    /// Bounds concurrent Argon2 work so a burst of logins cannot exhaust CPU and memory.
    password_work: Arc<Semaphore>,
}
impl AppState {
    pub async fn new(db: AppDb) -> Result<Self, String> {
        let permits = std::thread::available_parallelism().map_or(1, usize::from);
        let dummy_hash = tokio::task::spawn_blocking(|| {
            crate::credentials::hash_password(&crate::credentials::random_secret())
        })
        .await
        .map_err(|_| "password initialization failed".to_owned())??;
        Ok(Self {
            db,
            limiter: Arc::new(LoginLimiter::default()),
            client_logs: Arc::new(WindowLimiter::new(
                CLIENT_LOG_BATCHES_PER_MINUTE,
                Duration::from_secs(60),
            )),
            dummy_hash: Arc::new(dummy_hash),
            password_work: Arc::new(Semaphore::new(permits)),
        })
    }
    /// Runs password hashing or verification on the blocking pool, at most one job per CPU.
    pub(crate) async fn password_work<T: Send + 'static>(
        &self,
        work: impl FnOnce() -> T + Send + 'static,
    ) -> Result<T, crate::ApiError> {
        run_limited(&self.password_work, work).await
    }
}
pub(crate) async fn run_limited<T: Send + 'static>(
    semaphore: &Arc<Semaphore>,
    work: impl FnOnce() -> T + Send + 'static,
) -> Result<T, crate::ApiError> {
    let permit = semaphore
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| crate::ApiError::internal())?;
    tokio::task::spawn_blocking(move || {
        let _permit = permit;
        work()
    })
    .await
    .map_err(|_| crate::ApiError::internal())
}
#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
    async fn password_work_never_exceeds_its_permits() {
        let semaphore = Arc::new(Semaphore::new(2));
        let running = Arc::new(AtomicUsize::new(0));
        let peak = Arc::new(AtomicUsize::new(0));
        let mut jobs = tokio::task::JoinSet::new();
        for _ in 0..8 {
            let (semaphore, running, peak) = (semaphore.clone(), running.clone(), peak.clone());
            jobs.spawn(async move {
                run_limited(&semaphore, move || {
                    let now = running.fetch_add(1, Ordering::SeqCst) + 1;
                    peak.fetch_max(now, Ordering::SeqCst);
                    std::thread::sleep(Duration::from_millis(30));
                    running.fetch_sub(1, Ordering::SeqCst);
                })
                .await
            });
        }
        while let Some(result) = jobs.join_next().await {
            assert!(result.is_ok_and(|r| r.is_ok()));
        }
        assert_eq!(peak.load(Ordering::SeqCst), 2);
    }
}
