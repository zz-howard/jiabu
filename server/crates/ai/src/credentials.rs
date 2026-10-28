use crate::{
    ProviderError,
    siwc::oauth::{OAuthClient, OAuthCredentials},
};
use async_trait::async_trait;
use std::{
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicI64, Ordering},
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
/// Shared by provider/source across configuration generations, including cancellation.
#[derive(Default)]
pub struct RefreshGate {
    lock: Mutex<()>,
    // Rotated credentials awaiting persistence, with the original CAS revision.
    pending: Mutex<Option<VersionedToken>>,
    retry: std::sync::Mutex<Option<(i64, std::time::Instant)>>,
    // Shared across reloads. MAX allows an initial refresh probe; zero is unavailable.
    available_until: AtomicI64,
}
pub struct CredentialManager {
    store: Arc<dyn TokenStore>,
    oauth: OAuthClient,
    refresh: Arc<RefreshGate>,
}
impl CredentialManager {
    pub async fn new(store: Arc<dyn TokenStore>, oauth: OAuthClient) -> Self {
        Self::with_gate(store, oauth, Arc::new(RefreshGate::default())).await
    }
    /// The composition root shares a gate by provider across configuration generations.
    pub async fn with_gate(
        store: Arc<dyn TokenStore>,
        oauth: OAuthClient,
        refresh: Arc<RefreshGate>,
    ) -> Self {
        let manager = Self {
            store,
            oauth,
            refresh,
        };
        {
            let _guard = manager.refresh.lock.lock().await;
            let mut pending = manager.refresh.pending.lock().await;
            if let Ok(current) = manager.load(&mut pending).await {
                manager.refresh.available_until.store(
                    if current.usable && current.credentials.refreshable() {
                        if pending.is_some()
                            || manager
                                .refresh
                                .retry
                                .lock()
                                .unwrap_or_else(std::sync::PoisonError::into_inner)
                                .is_some()
                        {
                            current.credentials.expires_at
                        } else {
                            i64::MAX
                        }
                    } else {
                        0
                    },
                    Ordering::Release,
                );
            }
        }
        manager
    }
    pub fn available(&self) -> bool {
        let until = self.refresh.available_until.load(Ordering::Acquire);
        if chrono::Utc::now().timestamp() < until {
            return true;
        }
        // A pending expired/rejected token remains unavailable until refreshed.
        // Only a source without pending may advertise a recovery probe.
        match self.refresh.pending.try_lock() {
            Ok(pending) if pending.is_none() => {}
            _ => return false,
        }
        self.refresh.retry.lock().is_ok_and(|retry| {
            retry
                .as_ref()
                .is_some_and(|(_, at)| std::time::Instant::now() >= *at)
        })
    }
    pub async fn access(&self) -> Result<OAuthCredentials, ProviderError> {
        self.access_inner(None).await
    }
    /// Re-read under the shared gate: another request may already have rotated the token.
    pub async fn refresh_after_rejection(
        &self,
        access_token: &str,
    ) -> Result<OAuthCredentials, ProviderError> {
        self.access_inner(Some(access_token)).await
    }
    /// A successful authoritative read always wins over an obsolete pending copy.
    async fn load(
        &self,
        pending: &mut Option<VersionedToken>,
    ) -> Result<VersionedToken, ProviderError> {
        match self.store.load().await {
            Ok(stored) => {
                if pending
                    .as_ref()
                    .is_some_and(|v| !stored.usable || v.revision != stored.revision)
                {
                    *pending = None;
                    *self
                        .refresh
                        .retry
                        .lock()
                        .map_err(|_| ProviderError::Transport)? = None;
                }
                Ok(pending.as_ref().unwrap_or(&stored).clone())
            }
            Err(_) if pending.is_some() => Ok(pending.as_ref().ok_or(ProviderError::Auth)?.clone()),
            Err(error) => {
                self.refresh.available_until.store(0, Ordering::Release);
                if error != ProviderError::Auth {
                    self.defer(-1, 0)?;
                } else {
                    *self
                        .refresh
                        .retry
                        .lock()
                        .map_err(|_| ProviderError::Transport)? = None;
                }
                Err(error)
            }
        }
    }
    async fn access_inner(
        &self,
        rejected: Option<&str>,
    ) -> Result<OAuthCredentials, ProviderError> {
        let _guard = self.refresh.lock.lock().await;
        let mut pending = self.refresh.pending.lock().await;
        // A failed read has no known token to reuse. Allow recovery after backoff.
        if pending.is_none() && self.waiting(-1)? {
            return Err(ProviderError::Transport);
        }
        let mut current = self.load(&mut pending).await?;
        let now = chrono::Utc::now().timestamp();
        if rejected == Some(current.credentials.access_token.as_str()) {
            current.credentials.expires_at = now;
            // Publish before OAuth/CAS can suspend: normal access must also refresh.
            *pending = Some(current.clone());
            self.refresh.available_until.store(now, Ordering::Release);
        }
        if !current.usable || !current.credentials.refreshable() {
            *self
                .refresh
                .retry
                .lock()
                .map_err(|_| ProviderError::Transport)? = None;
            self.refresh.available_until.store(0, Ordering::Release);
            return Err(ProviderError::Auth);
        }
        if self.waiting(current.revision)? {
            return if current.credentials.expires_at > now {
                Ok(current.credentials)
            } else {
                Err(ProviderError::Transport)
            };
        }
        *self
            .refresh
            .retry
            .lock()
            .map_err(|_| ProviderError::Transport)? = None;
        // Pending and stored credentials follow exactly the same refresh path.
        if current.credentials.expires_at <= now + 60 {
            match self.oauth.refresh(&current.credentials).await {
                Ok(next) => {
                    current.credentials = next;
                    // Preserve the original CAS base even through multiple rotations.
                    *pending = Some(current.clone());
                }
                Err(error) if error != ProviderError::Auth => {
                    self.defer(current.revision, current.credentials.expires_at)?;
                    return if current.credentials.expires_at > chrono::Utc::now().timestamp() {
                        Ok(current.credentials)
                    } else {
                        Err(error)
                    };
                }
                Err(_) => return self.reject(&current, &mut pending).await,
            }
        }
        self.refresh
            .available_until
            .store(current.credentials.expires_at, Ordering::Release);
        if pending.is_some() {
            // The rotated copy is already shared before this cancellable await.
            match self
                .store
                .compare_exchange(current.revision, &current.credentials)
                .await
            {
                Ok(true) => *pending = None,
                Ok(false) => {
                    // Preserve pending if the authoritative winner cannot yet be read.
                    let winner = self.load(&mut pending).await?;
                    self.refresh.available_until.store(
                        if winner.usable {
                            winner.credentials.expires_at
                        } else {
                            0
                        },
                        Ordering::Release,
                    );
                    return if winner.usable
                        && winner.credentials.expires_at > chrono::Utc::now().timestamp()
                    {
                        Ok(winner.credentials)
                    } else {
                        Err(ProviderError::Auth)
                    };
                }
                Err(_) => self.defer(current.revision, current.credentials.expires_at)?,
            }
        }
        Ok(current.credentials)
    }
    fn waiting(&self, revision: i64) -> Result<bool, ProviderError> {
        Ok(self
            .refresh
            .retry
            .lock()
            .map_err(|_| ProviderError::Transport)?
            .as_ref()
            .is_some_and(|(base, at)| *base == revision && std::time::Instant::now() < *at))
    }
    fn defer(&self, revision: i64, expires_at: i64) -> Result<(), ProviderError> {
        *self
            .refresh
            .retry
            .lock()
            .map_err(|_| ProviderError::Transport)? = Some((
            revision,
            std::time::Instant::now() + std::time::Duration::from_secs(5),
        ));
        self.refresh
            .available_until
            .store(expires_at, Ordering::Release);
        Ok(())
    }
    /// Only called for a definite rejection from the OAuth token endpoint.
    async fn reject(
        &self,
        current: &VersionedToken,
        pending: &mut Option<VersionedToken>,
    ) -> Result<OAuthCredentials, ProviderError> {
        *self
            .refresh
            .retry
            .lock()
            .map_err(|_| ProviderError::Transport)? = None;
        self.refresh.available_until.store(0, Ordering::Release);
        let mut invalid = current.clone();
        invalid.usable = false;
        *pending = Some(invalid);
        // A competing successful rotation must not be invalidated by this loser.
        if !self.store.invalidate(current.revision).await? {
            let winner = self.load(pending).await?;
            if winner.usable && winner.credentials.expires_at > chrono::Utc::now().timestamp() {
                self.refresh
                    .available_until
                    .store(winner.credentials.expires_at, Ordering::Release);
                return Ok(winner.credentials);
            }
        }
        Err(ProviderError::Auth)
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
