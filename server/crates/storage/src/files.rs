use crate::{BlobHash, StorageError};
use bytes::Bytes;
use sha2::{Digest, Sha256};

pub const MAX_PDF_BYTES: usize = 10 * 1024 * 1024;

pub struct PreparedFile {
    pub hash: BlobHash,
    pub bytes: Bytes,
}

pub fn prepare_pdf(bytes: Bytes, expected: BlobHash) -> Result<PreparedFile, StorageError> {
    if bytes.len() > MAX_PDF_BYTES {
        return Err(StorageError::TooLarge);
    }
    if bytes.len() < 8
        || &bytes[..5] != b"%PDF-"
        || !bytes[5].is_ascii_digit()
        || bytes[6] != b'.'
        || !bytes[7].is_ascii_digit()
    {
        return Err(StorageError::NotPdf);
    }
    let tail = &bytes[bytes.len().saturating_sub(1024)..];
    let eof = tail
        .windows(5)
        .rposition(|window| window == b"%%EOF")
        .ok_or(StorageError::NotPdf)?;
    if tail[eof + 5..]
        .iter()
        .any(|byte| *byte != 0 && !byte.is_ascii_whitespace())
    {
        return Err(StorageError::NotPdf);
    }
    let digest: [u8; 32] = Sha256::digest(&bytes).into();
    if digest != expected.bytes() {
        return Err(StorageError::Invalid);
    }
    Ok(PreparedFile {
        hash: expected,
        bytes,
    })
}
