//! Content addressed JPEG objects. No database or authorization decisions live here.
mod images;
mod jpeg_exif;
mod objects;
pub use images::{ImageLimits, PreparedJpeg, prepare_jpeg};
pub use objects::{BlobHash, BlobStore, ObjectCandidate, StoredBlob, Variant};

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("unsupported_media_type")]
    NotJpeg,
    #[error("payload_too_large")]
    TooLarge,
    #[error("validation_failed")]
    Invalid,
    #[error("not_found")]
    NotFound,
    #[error("internal")]
    Internal,
}
impl From<object_store::Error> for StorageError {
    fn from(error: object_store::Error) -> Self {
        match error {
            object_store::Error::NotFound { .. } => Self::NotFound,
            _ => Self::Internal,
        }
    }
}
#[cfg(test)]
mod tests;
