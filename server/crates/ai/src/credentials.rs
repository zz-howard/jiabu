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
/// Shared by provider/source across configuration generations, including cancellation.
#[derive(Default)]
pub struct RefreshGate {
    lock: Mutex<()>,
    // Rotated credentials awaiting persistence, with the original CAS revision.
    pending: Mutex<Option<VersionedToken>>,
    retry: std::sync::Mutex<Option<(i64, std::time::Instant, i64)>>,
}
pub struct CredentialManager {
    store: Arc<dyn TokenStore>,
    oauth: OAuthClient,
    refresh: Arc<RefreshGate>,
    available: AtomicBool,
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
        let guard = refresh.lock.lock().await;
        let initial = store.load().await;
        let available = initial
            .as_ref()
            .is_ok_and(|v| v.usable && v.credentials.refreshable());
        let retry = match initial {
            Err(error) if error != ProviderError::Auth => Some((
                -1,
                std::time::Instant::now() + std::time::Duration::from_secs(5),
                0,
            )),
            _ => None,
        };
        let pending = refresh.pending.lock().await;
        let mut shared_retry = refresh
            .retry
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let available = pending.as_ref().map_or(available, |v| {
            v.credentials.expires_at > chrono::Utc::now().timestamp()
        });
        if shared_retry.is_none() && pending.is_none() {
            *shared_retry = retry;
        }
        drop(pending);
        drop(shared_retry);
        drop(guard);
        Self {
            store,
            oauth,
            refresh,
            available: AtomicBool::new(available),
        }
    }
    pub fn available(&self) -> bool {
        if let Ok(retry) = self.refresh.retry.lock()
            && let Some((_, at, expires_at)) = *retry
        {
            return chrono::Utc::now().timestamp() < expires_at || std::time::Instant::now() >= at;
        }
        self.available.load(Ordering::Acquire)
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
    async fn load(&self) -> Result<VersionedToken, ProviderError> {
        match self.store.load().await {
            Ok(v) => Ok(v),
            Err(e) => {
                let retry = if e == ProviderError::Auth {
                    None
                } else {
                    Some((
                        -1,
                        std::time::Instant::now() + std::time::Duration::from_secs(5),
                        0,
                    ))
                };
                *self
                    .refresh
                    .retry
                    .lock()
                    .map_err(|_| ProviderError::Transport)? = retry;
                self.available.store(false, Ordering::Release);
                Err(e)
            }
        }
    }
    async fn access_inner(
        &self,
        rejected: Option<&str>,
    ) -> Result<OAuthCredentials, ProviderError> {
        let _guard = self.refresh.lock.lock().await;
        let mut pending = self.refresh.pending.lock().await;
        if let Some(next) = pending.as_ref() {
            let waiting = self
                .refresh
                .retry
                .lock()
                .map_err(|_| ProviderError::Transport)?
                .as_ref()
                .is_some_and(|(_, at, _)| std::time::Instant::now() < *at);
            if waiting {
                return if rejected != Some(next.credentials.access_token.as_str())
                    && next.credentials.expires_at > chrono::Utc::now().timestamp()
                {
                    Ok(next.credentials.clone())
                } else {
                    Err(ProviderError::Transport)
                };
            }
            match self
                .store
                .compare_exchange(next.revision, &next.credentials)
                .await
            {
                Ok(true) => {
                    let credentials = next.credentials.clone();
                    *pending = None;
                    *self
                        .refresh
                        .retry
                        .lock()
                        .map_err(|_| ProviderError::Transport)? = None;
                    self.available.store(true, Ordering::Release);
                    if rejected != Some(credentials.access_token.as_str())
                        && credentials.expires_at > chrono::Utc::now().timestamp() + 60
                    {
                        return Ok(credentials);
                    }
                }
                Ok(false) => {
                    // Keep pending until the authoritative winner can be read.
                    let winner = self.load().await?;
                    *pending = None;
                    *self
                        .refresh
                        .retry
                        .lock()
                        .map_err(|_| ProviderError::Transport)? = None;
                    let usable = winner.usable
                        && winner.credentials.expires_at > chrono::Utc::now().timestamp();
                    self.available.store(usable, Ordering::Release);
                    return if usable {
                        Ok(winner.credentials)
                    } else {
                        Err(ProviderError::Auth)
                    };
                }
                Err(_) => {
                    self.defer(next.revision, next.credentials.expires_at)?;
                    return if rejected != Some(next.credentials.access_token.as_str())
                        && next.credentials.expires_at > chrono::Utc::now().timestamp()
                    {
                        Ok(next.credentials.clone())
                    } else {
                        Err(ProviderError::Transport)
                    };
                }
            }
        }
        // Revision -1 marks a failed read: there is no known token to reuse yet.
        if self
            .refresh
            .retry
            .lock()
            .map_err(|_| ProviderError::Transport)?
            .as_ref()
            .is_some_and(|(revision, at, _)| *revision == -1 && std::time::Instant::now() < *at)
        {
            return Err(ProviderError::Transport);
        }
        let current = self.load().await?;
        let force = rejected == Some(current.credentials.access_token.as_str());
        if !current.usable || !current.credentials.refreshable() {
            *self
                .refresh
                .retry
                .lock()
                .map_err(|_| ProviderError::Transport)? = None;
            self.available.store(false, Ordering::Release);
            return Err(ProviderError::Auth);
        }
        let now = chrono::Utc::now().timestamp();
        {
            let mut retry = self
                .refresh
                .retry
                .lock()
                .map_err(|_| ProviderError::Transport)?;
            if retry.as_ref().is_some_and(|(revision, at, _)| {
                *revision == current.revision && std::time::Instant::now() < *at
            }) {
                return if !force && current.credentials.expires_at > now {
                    Ok(current.credentials)
                } else {
                    self.available.store(false, Ordering::Release);
                    Err(ProviderError::Transport)
                };
            }
            *retry = None;
        }
        if !force && current.credentials.expires_at > now + 60 {
            self.available.store(true, Ordering::Release);
            return Ok(current.credentials);
        }
        match self.oauth.refresh(&current.credentials).await {
            Ok(next) => {
                // Save the only rotated copy before CAS can suspend or be cancelled.
                *pending = Some(VersionedToken {
                    revision: current.revision,
                    credentials: next.clone(),
                    usable: true,
                });
                let changed = match self.store.compare_exchange(current.revision, &next).await {
                    Ok(changed) => changed,
                    Err(_) => {
                        self.defer(current.revision, next.expires_at)?;
                        return Ok(next);
                    }
                };
                if changed {
                    *pending = None;
                    self.available.store(true, Ordering::Release);
                    Ok(next)
                } else {
                    let winner = self.load().await?;
                    *pending = None;
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
            Err(error) if error != ProviderError::Auth => {
                *self
                    .refresh
                    .retry
                    .lock()
                    .map_err(|_| ProviderError::Transport)? = Some((
                    current.revision,
                    std::time::Instant::now() + std::time::Duration::from_secs(5),
                    current.credentials.expires_at,
                ));
                let usable = current.credentials.expires_at > chrono::Utc::now().timestamp();
                self.available.store(usable, Ordering::Release);
                if usable && !force {
                    Ok(current.credentials)
                } else {
                    Err(error)
                }
            }
            Err(_) => self.reject(&current).await,
        }
    }
    fn defer(&self, revision: i64, expires_at: i64) -> Result<(), ProviderError> {
        *self
            .refresh
            .retry
            .lock()
            .map_err(|_| ProviderError::Transport)? = Some((
            revision,
            std::time::Instant::now() + std::time::Duration::from_secs(5),
            expires_at,
        ));
        self.available.store(
            expires_at > chrono::Utc::now().timestamp(),
            Ordering::Release,
        );
        Ok(())
    }
    /// Only called for a definite rejection from the OAuth token endpoint.
    async fn reject(&self, current: &VersionedToken) -> Result<OAuthCredentials, ProviderError> {
        *self
            .refresh
            .retry
            .lock()
            .map_err(|_| ProviderError::Transport)? = None;
        self.available.store(false, Ordering::Release);
        // A competing successful rotation must not be invalidated by this loser.
        if !self.store.invalidate(current.revision).await? {
            let winner = self.load().await?;
            if winner.usable && winner.credentials.expires_at > chrono::Utc::now().timestamp() {
                self.available.store(true, Ordering::Release);
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
