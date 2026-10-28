use crate::{
    ProviderError,
    siwc::oauth::{OAuthClient, OAuthCredentials},
};
use async_trait::async_trait;
use std::{
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};
use tokio::sync::Mutex;
use zeroize::Zeroizing;
#[path = "../../../support/ai_secrets.rs"]
pub mod encryption;
pub use encryption::SecretKey;
#[derive(Clone)]
pub struct VersionedToken {
    pub revision: i64,
    pub credentials: OAuthCredentials,
    pub usable: bool,
}
#[async_trait]
pub trait TokenStore: Send + Sync {
    async fn load(&self) -> Result<VersionedToken, ProviderError>;
    async fn compare_exchange(
        &self,
        expected: i64,
        next: &OAuthCredentials,
    ) -> Result<bool, ProviderError>;
    async fn invalidate(&self, expected: i64) -> Result<bool, ProviderError>;
}
pub struct CredentialManager {
    store: Arc<dyn TokenStore>,
    oauth: OAuthClient,
    refresh: Arc<Mutex<()>>,
    available: AtomicBool,
}
impl CredentialManager {
    pub async fn new(store: Arc<dyn TokenStore>, oauth: OAuthClient) -> Self {
        Self::with_gate(store, oauth, Arc::new(Mutex::new(()))).await
    }
    /// The composition root shares a gate by provider across configuration generations.
    pub async fn with_gate(
        store: Arc<dyn TokenStore>,
        oauth: OAuthClient,
        refresh: Arc<Mutex<()>>,
    ) -> Self {
        let available = store
            .load()
            .await
            .is_ok_and(|v| v.usable && v.credentials.refreshable());
        Self {
            store,
            oauth,
            refresh,
            available: AtomicBool::new(available),
        }
    }
    pub fn available(&self) -> bool {
        self.available.load(Ordering::Acquire)
    }
    pub async fn access(&self) -> Result<OAuthCredentials, ProviderError> {
        let _guard = self.refresh.lock().await;
        let current = match self.store.load().await {
            Ok(v) => v,
            Err(e) => {
                self.available.store(false, Ordering::Release);
                return Err(e);
            }
        };
        if !current.usable || !current.credentials.refreshable() {
            self.available.store(false, Ordering::Release);
            return Err(ProviderError::Auth);
        }
        if current.credentials.expires_at > chrono::Utc::now().timestamp() + 60 {
            return Ok(current.credentials);
        }
        match self.oauth.refresh(&current.credentials).await {
            Ok(next) => {
                let changed = match self.store.compare_exchange(current.revision, &next).await {
                    Ok(changed) => changed,
                    Err(e) => {
                        self.available.store(false, Ordering::Release);
                        return Err(e);
                    }
                };
                if changed {
                    self.available.store(true, Ordering::Release);
                    Ok(next)
                } else {
                    let winner = self.store.load().await?;
                    let usable = winner.usable
                        && winner.credentials.expires_at > chrono::Utc::now().timestamp();
                    self.available.store(usable, Ordering::Release);
                    if usable {
                        Ok(winner.credentials)
                    } else {
                        Err(ProviderError::Auth)
                    }
                }
            }
            Err(_) => {
                self.available.store(false, Ordering::Release);
                // A competing successful rotation must not be invalidated by this loser.
                if self.store.invalidate(current.revision).await? {
                    self.available.store(false, Ordering::Release);
                } else {
                    let winner = self.store.load().await?;
                    if winner.usable
                        && winner.credentials.expires_at > chrono::Utc::now().timestamp()
                    {
                        self.available.store(true, Ordering::Release);
                        return Ok(winner.credentials);
                    }
                    self.available.store(false, Ordering::Release);
                }
                Err(ProviderError::Auth)
            }
        }
    }
    pub async fn reject(&self, access_token: &str) {
        if let Ok(current) = self.store.load().await {
            if current.credentials.access_token != access_token {
                return;
            }
            let _ = self.store.invalidate(current.revision).await;
        }
        self.available.store(false, Ordering::Release);
    }
}
/// Compatibility source, atomically replaced on the same filesystem. A sidecar
/// lock serializes read/CAS/rename across CLI and server processes on this host.
pub struct FileTokenStore {
    pub path: PathBuf,
}
impl FileTokenStore {
    fn read(&self) -> Result<VersionedToken, ProviderError> {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let metadata = std::fs::metadata(&self.path).map_err(|_| ProviderError::Auth)?;
            if metadata.permissions().mode() & 0o777 != 0o600 {
                return Err(ProviderError::Auth);
            }
        }
        let raw = Zeroizing::new(std::fs::read(&self.path).map_err(|_| ProviderError::Auth)?);
        if raw.len() > 1024 * 1024 {
            return Err(ProviderError::Auth);
        }
        let doc: FileDocument = serde_json::from_slice(&raw).map_err(|_| ProviderError::Auth)?;
        Ok(VersionedToken {
            revision: doc.revision,
            credentials: doc.credentials,
            usable: doc.usable,
        })
    }
    fn update(
        &self,
        expected: i64,
        next: Option<&OAuthCredentials>,
    ) -> Result<bool, ProviderError> {
        use std::io::Write;
        let lock_path = self.path.with_extension("lock");
        let lock = std::fs::OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .open(lock_path)
            .map_err(|_| ProviderError::Auth)?;
        lock.lock().map_err(|_| ProviderError::Auth)?;
        let old = self.read()?;
        if old.revision != expected {
            return Ok(false);
        }
        let doc = FileDocument {
            revision: expected + 1,
            usable: next.is_some(),
            credentials: next.cloned().unwrap_or(old.credentials),
        };
        let bytes = Zeroizing::new(serde_json::to_vec(&doc).map_err(|_| ProviderError::Auth)?);
        let tmp = self
            .path
            .with_extension(format!("{}.tmp", uuid::Uuid::now_v7()));
        let mut options = std::fs::OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        let mut file = options.open(&tmp).map_err(|_| ProviderError::Auth)?;
        let result = (|| {
            file.write_all(&bytes)?;
            file.sync_all()?;
            std::fs::rename(&tmp, &self.path)?;
            let parent = self
                .path
                .parent()
                .filter(|p| !p.as_os_str().is_empty())
                .unwrap_or_else(|| std::path::Path::new("."));
            std::fs::File::open(parent)?.sync_all()?;
            Ok::<_, std::io::Error>(())
        })();
        if result.is_err() {
            let _ = std::fs::remove_file(tmp);
            return Err(ProviderError::Auth);
        }
        Ok(true)
    }
}
#[derive(serde::Serialize, serde::Deserialize)]
pub struct FileDocument {
    pub revision: i64,
    pub usable: bool,
    pub credentials: OAuthCredentials,
}
#[async_trait]
impl TokenStore for FileTokenStore {
    async fn load(&self) -> Result<VersionedToken, ProviderError> {
        self.read()
    }
    async fn compare_exchange(
        &self,
        expected: i64,
        next: &OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        self.update(expected, Some(next))
    }
    async fn invalidate(&self, expected: i64) -> Result<bool, ProviderError> {
        self.update(expected, None)
    }
}
