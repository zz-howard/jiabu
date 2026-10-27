use crate::{BlobHash, StorageError};
use bytes::Bytes;
use image::{
    DynamicImage, ImageDecoder, Limits,
    codecs::jpeg::{JpegDecoder, JpegEncoder},
};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use std::io::Cursor;

#[derive(Clone, Debug, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ImageLimits {
    pub max_upload_bytes: usize,
    pub max_pixels: u64,
    pub max_dimension: u32,
    pub max_decode_bytes: u64,
    pub concurrency: usize,
    pub max_in_flight_uploads: usize,
    pub transfer_timeout_secs: u64,
}
impl Default for ImageLimits {
    fn default() -> Self {
        Self {
            max_upload_bytes: 20 * 1024 * 1024,
            max_pixels: 24_000_000,
            max_dimension: 12_000,
            max_decode_bytes: 128 * 1024 * 1024,
            concurrency: 2,
            max_in_flight_uploads: 8,
            transfer_timeout_secs: 600,
        }
    }
}
impl ImageLimits {
    pub fn validate(&self) -> Result<(), StorageError> {
        if self.max_upload_bytes == 0
            || self.max_pixels == 0
            || self.max_dimension == 0
            || self.transfer_timeout_secs == 0
            || self.transfer_timeout_secs > 86400
            || self.max_decode_bytes == 0
            || self.max_dimension > i32::MAX as u32
            || self.concurrency == 0
            || self.concurrency > 1024
            || self.max_in_flight_uploads == 0
            || self.max_in_flight_uploads > 1024
        {
            return Err(StorageError::Invalid);
        }
        Ok(())
    }
}
pub struct PreparedJpeg {
    pub hash: BlobHash,
    pub original: Bytes,
    pub display: Bytes,
    pub thumb: Bytes,
    /// Dimensions in the original JPEG SOF, before EXIF orientation.
    pub width: u32,
    pub height: u32,
}
/// CPU work: the caller MUST run this on spawn_blocking with a bounded permit.
/// No existence lookup is allowed before these checks, including for repeat uploads.
pub fn prepare_jpeg(
    bytes: Bytes,
    expected: BlobHash,
    limits: &ImageLimits,
) -> Result<PreparedJpeg, StorageError> {
    if bytes.len() > limits.max_upload_bytes {
        return Err(StorageError::TooLarge);
    }
    if infer::get(&bytes).is_none_or(|kind| kind.mime_type() != "image/jpeg") {
        return Err(StorageError::NotJpeg);
    }
    let digest: [u8; 32] = Sha256::digest(&bytes).into();
    if digest != expected.bytes() {
        return Err(StorageError::Invalid);
    }
    let (bytes, orientation) = crate::jpeg_exif::sanitize(bytes)?;
    let mut decoder =
        JpegDecoder::new(Cursor::new(bytes.as_ref())).map_err(|_| StorageError::Invalid)?;
    let (width, height) = decoder.dimensions();
    // Read dimensions before allocating the decompressed image (JPEG bomb guard).
    if width == 0
        || height == 0
        || width > limits.max_dimension
        || height > limits.max_dimension
        || u64::from(width) * u64::from(height) > limits.max_pixels
    {
        return Err(StorageError::TooLarge);
    }
    // Bound the output allocation independently of codec-specific limit support.
    if u64::from(width) * u64::from(height) * 4 > limits.max_decode_bytes {
        return Err(StorageError::TooLarge);
    }
    let mut decode_limits = Limits::default();
    decode_limits.max_image_width = Some(limits.max_dimension);
    decode_limits.max_image_height = Some(limits.max_dimension);
    decode_limits.max_alloc = Some(limits.max_decode_bytes);
    decoder
        .set_limits(decode_limits)
        .map_err(|_| StorageError::TooLarge)?;
    let decoded = DynamicImage::from_decoder(decoder).map_err(|error| match error {
        image::ImageError::Limits(_) => StorageError::TooLarge,
        _ => StorageError::Invalid,
    })?;
    let oriented = orient(decoded, orientation)?;
    Ok(PreparedJpeg {
        hash: expected,
        original: bytes,
        display: encode_variant(&oriented, 1600)?,
        thumb: encode_variant(&oriented, 512)?,
        width,
        height,
    })
}
pub(crate) fn orient(image: DynamicImage, orientation: u32) -> Result<DynamicImage, StorageError> {
    Ok(match orientation {
        1 => image,
        2 => image.fliph(),
        3 => image.rotate180(),
        4 => image.flipv(),
        5 => image.rotate90().fliph(),
        6 => image.rotate90(),
        7 => image.rotate90().flipv(),
        8 => image.rotate270(),
        _ => return Err(StorageError::Invalid),
    })
}
fn encode_variant(image: &DynamicImage, longest: u32) -> Result<Bytes, StorageError> {
    let resized;
    let image = if image.width() > longest || image.height() > longest {
        resized = image.thumbnail(longest, longest);
        &resized
    } else {
        image
    };
    let mut out = Vec::new();
    // A fresh encoder copies no EXIF/GPS/ICC metadata from the upload.
    JpegEncoder::new_with_quality(&mut out, 85)
        .encode_image(image)
        .map_err(|_| StorageError::Internal)?;
    Ok(out.into())
}
