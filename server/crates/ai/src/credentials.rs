use crate::{
    ProviderError,
    siwc::oauth::{OAuthClient, OAuthCredentials},
};
use async_trait::async_trait;
use std::{
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicI64, Ordering},
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
/// Shared by provider/source across configuration generations, including cancellation.
#[derive(Default)]
pub struct RefreshGate {
    lock: Mutex<()>,
    // Rotated credentials awaiting persistence, with the original CAS revision.
    pending: Mutex<Option<VersionedToken>>,
    retry: std::sync::Mutex<Option<(i64, std::time::Instant)>>,
    // Observed access-token identity and rejection flag, shared across reloads.
    access_state: std::sync::Mutex<(Zeroizing<String>, bool)>,
    // Direct access deadline (-1 is definitively invalid), plus permission to refresh.
    // Zero is an initially unknown deadline.
    available_until: AtomicI64,
    refreshable: AtomicBool,
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
            let _ = manager.load(&mut pending).await;
        }
        manager
    }
    fn observe(&self, current: &mut VersionedToken) {
        let mut state = self
            .refresh
            .access_state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if state.0.as_str() != current.credentials.access_token {
            *state = (
                Zeroizing::new(current.credentials.access_token.clone()),
                false,
            );
        }
        if state.1 {
            current.credentials.expires_at = current
                .credentials
                .expires_at
                .min(chrono::Utc::now().timestamp());
        }
        self.refresh.available_until.store(
            if current.usable {
                current.credentials.expires_at
            } else {
                -1
            },
            Ordering::Release,
        );
        self.refresh.refreshable.store(
            current.usable && !current.credentials.refresh_token.is_empty(),
            Ordering::Release,
        );
    }
    pub fn available(&self) -> bool {
        let until = self.refresh.available_until.load(Ordering::Acquire);
        if until < 0 {
            return false;
        }
        if chrono::Utc::now().timestamp() < until {
            return true;
        }
        self.refresh
            .retry
            .lock()
            .is_ok_and(|retry| match retry.as_ref() {
                Some((base, at)) => {
                    std::time::Instant::now() >= *at
                        && (*base == -1 || self.refresh.refreshable.load(Ordering::Acquire))
                }
                None => self.refresh.refreshable.load(Ordering::Acquire),
            })
    }
    pub async fn access(&self) -> Result<OAuthCredentials, ProviderError> {
        self.access_inner(None).await
    }
    /// Record every model Auth, independently of whether this call may retry.
    pub fn mark_rejected(&self, access_token: &str) {
        let mut state = self
            .refresh
            .access_state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if state.0.as_str() == access_token {
            state.1 = true;
            self.refresh.available_until.fetch_min(0, Ordering::AcqRel);
        }
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
        let mut result = match self.store.load().await {
            Ok(TokenRead::Present {
                revision,
                credentials,
            }) => {
                if pending.as_ref().is_some_and(|v| revision > v.revision) {
                    *pending = None;
                    *self
                        .refresh
                        .retry
                        .lock()
                        .map_err(|_| ProviderError::Transport)? = None;
                }
                let stored = VersionedToken {
                    revision,
                    credentials,
                    usable: true,
                };
                Ok(pending.as_ref().unwrap_or(&stored).clone())
            }
            Ok(TokenRead::Unavailable) if pending.is_some() => {
                Ok(pending.as_ref().ok_or(ProviderError::Auth)?.clone())
            }
            Ok(TokenRead::Unavailable) => {
                self.refresh.refreshable.store(false, Ordering::Release);
                // A later outage must not reopen a source already known to be invalid.
                if self.refresh.available_until.load(Ordering::Acquire) >= 0 {
                    self.defer(-1, 0)?;
                }
                Err(ProviderError::Transport)
            }
            Ok(TokenRead::Cleared { .. }) | Err(_) => {
                // Tombstones and corrupt credentials are authoritative, never a fallback.
                *pending = None;
                *self
                    .refresh
                    .retry
                    .lock()
                    .map_err(|_| ProviderError::Transport)? = None;
                self.refresh.available_until.store(-1, Ordering::Release);
                self.refresh.refreshable.store(false, Ordering::Release);
                Err(ProviderError::Auth)
            }
        };
        if let Ok(current) = &mut result {
            self.observe(current);
        }
        result
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
        if !current.usable {
            *self
                .refresh
                .retry
                .lock()
                .map_err(|_| ProviderError::Transport)? = None;
            self.refresh.available_until.store(-1, Ordering::Release);
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
        if current.credentials.expires_at <= now + 60
            && !current.credentials.refresh_token.is_empty()
        {
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
        self.observe(&mut current);
        if current.credentials.expires_at <= chrono::Utc::now().timestamp() {
            return Err(ProviderError::Auth);
        }
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
        self.refresh.available_until.store(-1, Ordering::Release);
        self.refresh.refreshable.store(false, Ordering::Release);
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

    struct FileReadFault {
        fail_once: AtomicBool,
        stored: VersionedToken,
    }
    #[async_trait]
    impl TokenStore for FileReadFault {
        async fn load(&self) -> Result<TokenRead, ProviderError> {
            FileTokenStore::read_result(if self.fail_once.swap(false, Ordering::SeqCst) {
                // Inject EIO at the file-read error classification boundary.
                Err(FileTokenStore::read_error(
                    std::io::Error::from_raw_os_error(5),
                ))
            } else {
                Ok(self.stored.clone())
            })
        }
        async fn compare_exchange(
            &self,
            _: i64,
            _: &OAuthCredentials,
        ) -> Result<bool, ProviderError> {
            Err(ProviderError::Transport)
        }
        async fn invalidate(&self, _: i64) -> Result<bool, ProviderError> {
            Ok(false)
        }
    }
    #[tokio::test]
    async fn file_eio_preserves_pending_and_recovery_keeps_r1() {
        let mut token = VersionedToken {
            revision: 1,
            usable: true,
            credentials: OAuthCredentials {
                access_token: "synthetic-A0".into(),
                refresh_token: "synthetic-R0".into(),
                client_id: "synthetic-client".into(),
                account_id: "synthetic-account".into(),
                expires_at: chrono::Utc::now().timestamp() + 3600,
                host_id: uuid::Uuid::nil(),
            },
        };
        let store = Arc::new(FileReadFault {
            fail_once: AtomicBool::new(true),
            stored: token.clone(),
        });
        token.credentials.access_token = "synthetic-A1".into();
        token.credentials.refresh_token = "synthetic-R1".into();
        let gate = Arc::new(RefreshGate::default());
        *gate.pending.lock().await = Some(token);
        // Constructor encounters one EIO through the same classification as file load.
        let manager =
            CredentialManager::with_gate(store, OAuthClient::official().unwrap(), gate.clone())
                .await;
        assert_eq!(
            gate.pending
                .lock()
                .await
                .as_ref()
                .unwrap()
                .credentials
                .refresh_token,
            "synthetic-R1"
        );
        assert_eq!(
            manager.access().await.unwrap().refresh_token,
            "synthetic-R1"
        );
        assert!(gate.pending.lock().await.is_some());
    }
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
