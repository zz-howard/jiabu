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
/// Unavailable is reserved for temporary storage failures; Auth means corrupt/missing credentials.
pub enum TokenRead {
    Present {
        revision: i64,
        credentials: OAuthCredentials,
    },
    Cleared {
        revision: i64,
    },
    Unavailable,
}
impl From<VersionedToken> for TokenRead {
    fn from(token: VersionedToken) -> Self {
        if token.usable {
            Self::Present {
                revision: token.revision,
                credentials: token.credentials,
            }
        } else {
            Self::Cleared {
                revision: token.revision,
            }
        }
    }
}
#[async_trait]
pub trait TokenStore: Send + Sync {
    /// Temporary IO failures must be Unavailable; errors describe unusable credentials.
    async fn load(&self) -> Result<TokenRead, ProviderError>;
    async fn compare_exchange(
        &self,
        expected: i64,
        next: &OAuthCredentials,
    ) -> Result<bool, ProviderError>;
    async fn invalidate(&self, expected: i64) -> Result<bool, ProviderError>;
}
/// Shared by provider/source across configuration generations.
pub struct RefreshGate {
    lock: Mutex<()>,
    usable: AtomicBool,
    /// A rotation the store did not accept. Upstream may already have invalidated the
    /// stored refresh token, so this copy wins while the store still holds exactly the
    /// revision and refresh token it replaced. Lives here so configuration reloads that
    /// rebuild managers keep it. It is cleared only once stored, so a cancelled request
    /// cannot drop it.
    unpersisted: std::sync::Mutex<Option<Unpersisted>>,
}
#[derive(Clone)]
struct Unpersisted {
    revision: i64,
    replaced: Zeroizing<String>,
    rotated: OAuthCredentials,
}
/// Usable until a tombstone, corrupt credential or definite rejection is seen.
impl Default for RefreshGate {
    fn default() -> Self {
        Self {
            lock: Mutex::new(()),
            usable: AtomicBool::new(true),
            unpersisted: std::sync::Mutex::new(None),
        }
    }
}
#[derive(Clone)]
pub struct CredentialManager {
    store: Arc<dyn TokenStore>,
    oauth: OAuthClient,
    refresh: Arc<RefreshGate>,
}
impl CredentialManager {
    pub async fn new(store: Arc<dyn TokenStore>, oauth: OAuthClient) -> Self {
        Self::with_gate(store, oauth, Arc::new(RefreshGate::default())).await
    }
    /// The composition root shares a gate by provider/source across configurations.
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
            let _ = manager.load().await;
        }
        manager
    }
    pub fn available(&self) -> bool {
        self.refresh.usable.load(Ordering::Acquire)
    }
    pub async fn access(&self) -> Result<OAuthCredentials, ProviderError> {
        self.access_inner(None).await
    }
    /// Another request may already have rotated the rejected token.
    pub async fn refresh_after_rejection(
        &self,
        access_token: &str,
    ) -> Result<OAuthCredentials, ProviderError> {
        self.access_inner(Some(access_token)).await
    }
    async fn load(&self) -> Result<(i64, OAuthCredentials), ProviderError> {
        match self.store.load().await {
            Ok(TokenRead::Present {
                revision,
                credentials,
            }) => {
                self.refresh.usable.store(true, Ordering::Release);
                Ok((revision, credentials))
            }
            Ok(TokenRead::Unavailable) => Err(ProviderError::Transport),
            Ok(TokenRead::Cleared { .. }) | Err(_) => {
                self.refresh.usable.store(false, Ordering::Release);
                Err(ProviderError::Auth)
            }
        }
    }
    fn unpersisted(&self) -> Option<Unpersisted> {
        self.refresh
            .unpersisted
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .clone()
    }
    fn set_unpersisted(&self, pending: Option<Unpersisted>) {
        *self
            .refresh
            .unpersisted
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner) = pending;
    }
    /// Retries transient storage failures; false when the rotation is not stored.
    /// Each write is bounded, since the detached refresh holds the lock meanwhile.
    async fn persist(&self, revision: i64, next: &OAuthCredentials) -> bool {
        for attempt in 0..3u32 {
            let write = self.store.compare_exchange(revision, next);
            match tokio::time::timeout(std::time::Duration::from_secs(10), write).await {
                Ok(Ok(true)) => return true,
                Ok(Ok(false)) => return false,
                _ if attempt < 2 => {
                    tokio::time::sleep(std::time::Duration::from_millis(200 << attempt)).await;
                }
                _ => {}
            }
        }
        false
    }
    /// Detached so a caller cancelled by its deadline cannot drop a rotation upstream
    /// has already made; the task still records it in the gate.
    async fn access_inner(
        &self,
        rejected: Option<&str>,
    ) -> Result<OAuthCredentials, ProviderError> {
        let manager = self.clone();
        let rejected = rejected.map(str::to_owned);
        tokio::spawn(async move { manager.access_locked(rejected.as_deref()).await })
            .await
            .unwrap_or(Err(ProviderError::Transport))
    }
    async fn access_locked(
        &self,
        rejected: Option<&str>,
    ) -> Result<OAuthCredentials, ProviderError> {
        let _guard = self.refresh.lock.lock().await;
        let (mut revision, mut current) = self.load().await?;
        // The token the store holds, which a later pending rotation must still match.
        let mut stored = Zeroizing::new(current.refresh_token.clone());
        if let Some(pending) = self.unpersisted() {
            if pending.revision == revision && *pending.replaced == current.refresh_token {
                if self.persist(revision, &pending.rotated).await {
                    revision += 1;
                    current = pending.rotated;
                    stored = Zeroizing::new(current.refresh_token.clone());
                    self.set_unpersisted(None);
                } else {
                    // False is either a source that never stores (env:) or a lost race.
                    // Only an unchanged store still needs the pending copy.
                    let (latest, credentials) = self.load().await?;
                    if latest == revision && credentials.refresh_token == *stored {
                        current = pending.rotated;
                    } else {
                        self.set_unpersisted(None);
                        revision = latest;
                        stored = Zeroizing::new(credentials.refresh_token.clone());
                        current = credentials;
                    }
                }
            } else {
                self.set_unpersisted(None);
            }
        }
        if rejected.is_some_and(|token| token != current.access_token) {
            return Ok(current);
        }
        let now = chrono::Utc::now().timestamp();
        if (rejected.is_some() || current.expires_at <= now + 60)
            && !current.refresh_token.is_empty()
        {
            match self.oauth.refresh(&current).await {
                Ok(next) => {
                    // The old refresh token may already be dead upstream, so the rotation
                    // is held in memory before persisting and retried later if not stored.
                    self.set_unpersisted(Some(Unpersisted {
                        revision,
                        replaced: stored.clone(),
                        rotated: next.clone(),
                    }));
                    if self.persist(revision, &next).await {
                        self.set_unpersisted(None);
                    } else {
                        eprintln!("SIWC credential rotation not persisted; kept in memory");
                    }
                    return Ok(next);
                }
                Err(ProviderError::Auth) => {
                    self.refresh.usable.store(false, Ordering::Release);
                    if self.store.invalidate(revision).await.is_err() {
                        eprintln!("SIWC credential invalidation failed: storage failure");
                    }
                    return Err(ProviderError::Auth);
                }
                Err(_) => {
                    return if current.expires_at > chrono::Utc::now().timestamp() {
                        Ok(current)
                    } else {
                        Err(ProviderError::Transport)
                    };
                }
            }
        }
        Ok(current)
    }
}
/// Compatibility source, atomically replaced on the same filesystem. A sidecar
/// lock serializes read/CAS/rename across CLI and server processes on this host.
pub struct FileTokenStore {
    pub path: PathBuf,
}
impl FileTokenStore {
    fn read_result(
        result: Result<VersionedToken, ProviderError>,
    ) -> Result<TokenRead, ProviderError> {
        match result {
            Err(ProviderError::Transport) => Ok(TokenRead::Unavailable),
            result => result.map(TokenRead::from),
        }
    }
    fn read_error(error: std::io::Error) -> ProviderError {
        match error.kind() {
            std::io::ErrorKind::NotFound | std::io::ErrorKind::PermissionDenied => {
                ProviderError::Auth
            }
            _ => ProviderError::Transport,
        }
    }
    fn read(&self) -> Result<VersionedToken, ProviderError> {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let metadata = std::fs::metadata(&self.path).map_err(Self::read_error)?;
            if metadata.permissions().mode() & 0o777 != 0o600 {
                return Err(ProviderError::Auth);
            }
        }
        let raw = Zeroizing::new(std::fs::read(&self.path).map_err(Self::read_error)?);
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
    async fn load(&self) -> Result<TokenRead, ProviderError> {
        Self::read_result(self.read())
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn file_read_io_errors_keep_authoritative_failures_distinct() {
        use std::io::{Error, ErrorKind};
        for kind in [ErrorKind::NotFound, ErrorKind::PermissionDenied] {
            assert_eq!(
                FileTokenStore::read_error(Error::from(kind)),
                ProviderError::Auth
            );
        }
        for error in [
            Error::from_raw_os_error(5),
            Error::from_raw_os_error(24),
            Error::from(ErrorKind::Interrupted),
        ] {
            assert!(matches!(
                FileTokenStore::read_result(Err(FileTokenStore::read_error(error))),
                Ok(TokenRead::Unavailable)
            ));
        }
        assert!(matches!(
            FileTokenStore::read_result(Err(ProviderError::Auth)),
            Err(ProviderError::Auth)
        ));
    }
}
