//! Rewrite EXIF metadata only; JPEG tables and entropy-coded pixels are copied.
use crate::StorageError;
use bytes::Bytes;
use std::io::Cursor;

/// The object key is computed from the upload before this privacy transformation.
/// Unreadable EXIF is discarded, so malformed metadata neither blocks an upload
/// nor leaves uninspectable location data in the stored original.
pub(crate) fn sanitize(bytes: Bytes) -> Result<(Bytes, u32), StorageError> {
    if !bytes.starts_with(&[0xff, 0xd8]) {
        return Err(StorageError::Invalid);
    }
    let mut out = Vec::with_capacity(bytes.len());
    out.extend_from_slice(&bytes[..2]);
    let mut at = 2;
    let mut scan = false;
    let mut orientation = None;
    while at < bytes.len() {
        if scan {
            let start = at;
            while at < bytes.len() {
                if bytes[at] == 0xff {
                    let mut next = at + 1;
                    while bytes.get(next) == Some(&0xff) {
                        next += 1;
                    }
                    match bytes.get(next) {
                        Some(0x00 | 0xd0..=0xd7) => at = next + 1,
                        Some(_) => break,
                        None => {
                            at = bytes.len();
                            break;
                        }
                    }
                } else {
                    at += 1;
                }
            }
            out.extend_from_slice(&bytes[start..at]);
            scan = false;
            if at == bytes.len() {
                break;
            }
        }
        let start = at;
        if bytes.get(at) != Some(&0xff) {
            return Err(StorageError::Invalid);
        }
        while bytes.get(at) == Some(&0xff) {
            at += 1;
        }
        let marker = *bytes.get(at).ok_or(StorageError::Invalid)?;
        at += 1;
        if marker == 0xd9 {
            // Store the static primary JPEG only; appended MPF/Motion Photo
            // payloads can carry their own uninspected location metadata.
            out.extend_from_slice(&bytes[start..at]);
            break;
        }
        if matches!(marker, 0x01 | 0xd0..=0xd7) {
            out.extend_from_slice(&bytes[start..at]);
            continue;
        }
        let length_bytes = bytes.get(at..at + 2).ok_or(StorageError::Invalid)?;
        let length = usize::from(u16::from_be_bytes([length_bytes[0], length_bytes[1]]));
        if length < 2 {
            return Err(StorageError::Invalid);
        }
        let end = at
            .checked_add(length)
            .filter(|end| *end <= bytes.len())
            .ok_or(StorageError::Invalid)?;
        let payload = &bytes[at + 2..end];
        let location_metadata = marker == 0xed
            || (marker == 0xe1
                && (payload.starts_with(b"http://ns.adobe.com/xap/1.0/\0")
                    || payload.starts_with(b"http://ns.adobe.com/xmp/extension/\0")));
        if location_metadata {
            // Drop complete XMP/extended-XMP and APP13/IPTC segments, including
            // fields whose names/encodings we cannot safely classify.
            at = end;
            continue;
        }
        if marker == 0xe1 && payload.starts_with(b"Exif\0\0") {
            if let Ok(exif) = exif::Reader::new().read_raw(payload[6..].to_vec()) {
                let direction = exif
                    .get_field(exif::Tag::Orientation, exif::In::PRIMARY)
                    .map(|field| field.value.get_uint(0).ok_or(StorageError::Invalid))
                    .transpose()?
                    .unwrap_or(1);
                if !(1..=8).contains(&direction) {
                    return Err(StorageError::Invalid);
                }
                orientation.get_or_insert(direction);
                let mut writer = exif::experimental::Writer::new();
                let mut retained = false;
                for field in exif.fields() {
                    // Rebuild from fields rather than unlinking a pointer in the
                    // old TIFF: unreferenced GPS bytes must not survive either.
                    if field.tag.context() == exif::Context::Gps || field.tag.number() == 0x8825 {
                        continue;
                    }
                    writer.push_field(field);
                    retained = true;
                }
                if retained {
                    let mut tiff = Cursor::new(Vec::new());
                    let rewritten = writer.write(&mut tiff, exif.little_endian()).is_ok();
                    // Unknown field types and empty primary IFDs can make the
                    // writer fail even when parsing succeeded. Drop the whole
                    // segment; the already-read direction still orients variants.
                    if rewritten {
                        let tiff = tiff.into_inner();
                        if let Ok(length) = u16::try_from(tiff.len() + 8) {
                            out.extend_from_slice(&[0xff, 0xe1]);
                            out.extend_from_slice(&length.to_be_bytes());
                            out.extend_from_slice(b"Exif\0\0");
                            out.extend_from_slice(&tiff);
                        }
                    }
                }
            }
        } else {
            out.extend_from_slice(&bytes[start..end]);
        }
        at = end;
        scan = marker == 0xda;
    }
    Ok((out.into(), orientation.unwrap_or(1)))
}
