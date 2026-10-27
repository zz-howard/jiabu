use crate::{PreparedJpeg, StorageError};
use bytes::Bytes;
use chrono::{DateTime, Utc};
use futures_util::{Stream, StreamExt, TryStreamExt};
use object_store::{ObjectStore, ObjectStoreExt, PutMode, PutOptions, path::Path};
use std::{collections::BTreeMap, path::Path as FsPath, pin::Pin, sync::Arc};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub struct BlobHash([u8; 32]);
impl BlobHash {
    pub fn parse(value: &str) -> Result<Self, StorageError> {
        if value.len() != 64 {
            return Err(StorageError::Invalid);
        }
        let mut hash = [0_u8; 32];
        for (i, pair) in value.as_bytes().as_chunks::<2>().0.iter().enumerate() {
            let nibble = |b| match b {
                b'0'..=b'9' => Ok(b - b'0'),
                b'a'..=b'f' => Ok(b - b'a' + 10),
                _ => Err(StorageError::Invalid),
            };
            hash[i] = (nibble(pair[0])? << 4) | nibble(pair[1])?;
        }
        Ok(Self(hash))
    }
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }
    pub fn bytes(self) -> [u8; 32] {
        self.0
    }
}
impl std::fmt::Display for BlobHash {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        for byte in self.0 {
            write!(f, "{byte:02x}")?;
        }
        Ok(())
    }
}
#[derive(Clone, Copy)]
pub enum Variant {
    Original,
    Display,
    Thumb,
}
impl Variant {
    fn suffix(self) -> &'static str {
        match self {
            Self::Original => "orig",
            Self::Display => "1600",
            Self::Thumb => "512",
        }
    }
}
pub struct StoredBlob {
    pub bytes: u64,
    pub stream: Pin<Box<dyn Stream<Item = Result<Bytes, StorageError>> + Send>>,
}
pub struct ObjectCandidate {
    pub hash: BlobHash,
    pub newest: DateTime<Utc>,
}
#[derive(Clone)]
pub struct BlobStore {
    store: Arc<dyn ObjectStore>,
    local_root: Option<std::path::PathBuf>,
}
impl BlobStore {
    pub fn new(store: Arc<dyn ObjectStore>) -> Self {
        Self {
            store,
            local_root: None,
        }
    }
    pub fn local(data_dir: impl AsRef<FsPath>) -> Result<Self, StorageError> {
        std::fs::create_dir_all(data_dir.as_ref()).map_err(|_| StorageError::Internal)?;
        let root = std::fs::canonicalize(data_dir.as_ref()).map_err(|_| StorageError::Internal)?;
        let store = object_store::local::LocalFileSystem::new_with_prefix(&root)
            .map_err(|_| StorageError::Internal)?;
        Ok(Self {
            store: Arc::new(store),
            local_root: Some(root),
        })
    }
    /// LocalFileSystem intentionally hides its `#N` staging files from list().
    /// Run this blocking filesystem scan outside database/lifecycle locks. The
    /// one-day grace is at least the maximum HTTP transfer lifetime.
    pub fn cleanup_staging(&self, cutoff: DateTime<Utc>) -> Result<u64, StorageError> {
        let Some(root) = &self.local_root else {
            return Ok(0);
        };
        let directory = root.join("blobs");
        match std::fs::symlink_metadata(&directory) {
            Ok(metadata) if metadata.is_dir() => {}
            Ok(_) => return Ok(0),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(0),
            Err(_) => return Err(StorageError::Internal),
        };
        let mut removed = 0;
        for shard in std::fs::read_dir(directory).map_err(|_| StorageError::Internal)? {
            let shard = shard.map_err(|_| StorageError::Internal)?;
            let name = shard.file_name();
            let Some(name) = name.to_str() else {
                continue;
            };
            if name.len() != 2
                || !name
                    .bytes()
                    .all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c))
                || !shard
                    .file_type()
                    .map_err(|_| StorageError::Internal)?
                    .is_dir()
            {
                continue;
            }
            for entry in std::fs::read_dir(shard.path()).map_err(|_| StorageError::Internal)? {
                let entry = entry.map_err(|_| StorageError::Internal)?;
                if !entry
                    .file_type()
                    .map_err(|_| StorageError::Internal)?
                    .is_file()
                {
                    continue;
                }
                let filename = entry.file_name();
                let Some(filename) = filename.to_str() else {
                    continue;
                };
                let Some((key, number)) = filename.rsplit_once('#') else {
                    continue;
                };
                if number.is_empty() || !number.bytes().all(|c| c.is_ascii_digit()) {
                    continue;
                }
                let Some((hash, suffix)) = key.split_once('.') else {
                    continue;
                };
                if !matches!(suffix, "orig.jpg" | "1600.jpg" | "512.jpg")
                    || BlobHash::parse(hash).is_err()
                    || &hash[..2] != name
                {
                    continue;
                }
                // Recheck the age immediately before unlinking. A fresh staging
                // object (including one next to an old committed object) survives.
                let metadata = match std::fs::symlink_metadata(entry.path()) {
                    Ok(metadata) => metadata,
                    Err(error) if error.kind() == std::io::ErrorKind::NotFound => continue,
                    Err(_) => return Err(StorageError::Internal),
                };
                let modified: DateTime<Utc> = metadata
                    .modified()
                    .map_err(|_| StorageError::Internal)?
                    .into();
                if !metadata.is_file() || modified > cutoff {
                    continue;
                }
                match std::fs::remove_file(entry.path()) {
                    Ok(()) => removed += 1,
                    Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
                    Err(_) => return Err(StorageError::Internal),
                }
            }
        }
        Ok(removed)
    }
    fn key(hash: BlobHash, variant: Variant) -> Path {
        let hash = hash.to_string();
        Path::from(format!(
            "blobs/{}/{}.{}.jpg",
            &hash[..2],
            hash,
            variant.suffix()
        ))
    }
    /// Called only inside the final lifecycle critical section. Conditional
    /// creation is atomic; no partial object is exposed by LocalFileSystem.
    pub async fn put_if_absent(&self, image: &PreparedJpeg) -> Result<(), StorageError> {
        for (variant, bytes) in [
            (Variant::Original, &image.original),
            (Variant::Display, &image.display),
            (Variant::Thumb, &image.thumb),
        ] {
            let path = Self::key(image.hash, variant);
            match self.store.head(&path).await {
                Ok(_) => continue,
                Err(object_store::Error::NotFound { .. }) => {}
                Err(error) => return Err(error.into()),
            }
            match self
                .store
                .put_opts(
                    &path,
                    bytes.clone().into(),
                    PutOptions {
                        mode: PutMode::Create,
                        ..Default::default()
                    },
                )
                .await
            {
                Ok(_) | Err(object_store::Error::AlreadyExists { .. }) => {}
                Err(error) => return Err(error.into()),
            }
        }
        Ok(())
    }
    pub async fn get_stream(
        &self,
        hash: BlobHash,
        variant: Variant,
    ) -> Result<StoredBlob, StorageError> {
        let object = self.store.get(&Self::key(hash, variant)).await?;
        // object_store releases expose usize or u64 here; normalize the wire length.
        #[allow(clippy::unnecessary_cast)]
        let bytes = object.meta.size as u64;
        Ok(StoredBlob {
            bytes,
            stream: Box::pin(object.into_stream().map_err(StorageError::from)),
        })
    }
    pub async fn newest(&self, hash: BlobHash) -> Result<Option<DateTime<Utc>>, StorageError> {
        let mut newest: Option<DateTime<Utc>> = None;
        for variant in [Variant::Original, Variant::Display, Variant::Thumb] {
            match self.store.head(&Self::key(hash, variant)).await {
                Ok(meta) => {
                    newest =
                        Some(newest.map_or(meta.last_modified, |old| old.max(meta.last_modified)))
                }
                Err(object_store::Error::NotFound { .. }) => {}
                Err(error) => return Err(error.into()),
            }
        }
        Ok(newest)
    }
    pub async fn delete(&self, hash: BlobHash) -> Result<(), StorageError> {
        for variant in [Variant::Original, Variant::Display, Variant::Thumb] {
            match self.store.delete(&Self::key(hash, variant)).await {
                Ok(()) | Err(object_store::Error::NotFound { .. }) => {}
                Err(error) => return Err(error.into()),
            }
        }
        Ok(())
    }
    /// Recovery for objects whose upload transaction never committed. Only our
    /// strict content-addressed keys qualify; use the newest of all three mtimes.
    pub async fn candidates(&self) -> Result<Vec<ObjectCandidate>, StorageError> {
        let prefix = Path::from("blobs");
        let mut objects = self.store.list(Some(&prefix));
        let mut hashes = BTreeMap::new();
        while let Some(meta) = objects.next().await {
            let meta = meta?;
            let path: &str = meta.location.as_ref();
            let parts = path.split('/').collect::<Vec<_>>();
            if parts.len() != 3 || parts[0] != "blobs" {
                continue;
            }
            let Some((hash, suffix)) = parts[2].split_once('.') else {
                continue;
            };
            if !matches!(suffix, "orig.jpg" | "1600.jpg" | "512.jpg")
                || hash.len() != 64
                || !hash.is_ascii()
                || parts[1] != &hash[..2]
            {
                continue;
            }
            let Ok(hash) = BlobHash::parse(hash) else {
                continue;
            };
            hashes
                .entry(hash)
                .and_modify(|time: &mut DateTime<Utc>| *time = (*time).max(meta.last_modified))
                .or_insert(meta.last_modified);
        }
        Ok(hashes
            .into_iter()
            .map(|(hash, newest)| ObjectCandidate { hash, newest })
            .collect())
    }
}
