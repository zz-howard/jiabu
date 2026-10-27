use crate::middleware::LoginLimiter;
use jiabu_db::AppDb;
use std::sync::Arc;
#[derive(Clone)]
pub struct AppState {
    pub db: AppDb,
    pub(crate) limiter: Arc<LoginLimiter>,
    pub(crate) dummy_hash: Arc<String>,
}
impl AppState {
    pub async fn new(db: AppDb) -> Result<Self, String> {
        let dummy_hash = tokio::task::spawn_blocking(|| {
            crate::credentials::hash_password(&crate::credentials::random_secret())
        })
        .await
        .map_err(|_| "password initialization failed".to_owned())??;
        Ok(Self {
            db,
            limiter: Arc::new(LoginLimiter::default()),
            dummy_hash: Arc::new(dummy_hash),
        })
    }
}
