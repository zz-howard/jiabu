use super::*;
use bytes::Bytes;
use futures_util::TryStreamExt;
use image::GenericImageView;
use sha2::{Digest, Sha256};
use uuid::Uuid;
fn jpeg(width: u32, height: u32) -> Bytes {
    let image = image::RgbImage::from_fn(width, height, |x, y| {
        image::Rgb([(x % 251) as u8, (y % 251) as u8, 90])
    });
    let mut bytes = Vec::new();
    image::codecs::jpeg::JpegEncoder::new(&mut bytes)
        .encode_image(&image)
        .unwrap();
    bytes.into()
}
fn hash(bytes: &[u8]) -> BlobHash {
    BlobHash::from_bytes(Sha256::digest(bytes).into())
}
fn pdf(size: usize) -> Bytes {
    let prefix = b"%PDF-1.7\n";
    let suffix = b"\n%%EOF\n";
    assert!(size >= prefix.len() + suffix.len());
    let mut bytes = Vec::with_capacity(size);
    bytes.extend_from_slice(prefix);
    bytes.resize(size - suffix.len(), b'x');
    bytes.extend_from_slice(suffix);
    bytes.into()
}
fn with_exif(bytes: &[u8], orientation: u16) -> Bytes {
    let description = b"sample camera\0";
    let description_at = 50_u32;
    let gps_at = description_at + description.len() as u32;
    let coordinates_at = gps_at + 54;
    let mut tiff = b"II\x2a\0\x08\0\0\0".to_vec();
    tiff.extend_from_slice(&3_u16.to_le_bytes());
    for (tag, kind, count, value) in [
        (0x010e_u16, 2_u16, description.len() as u32, description_at),
        (0x0112, 3, 1, u32::from(orientation)),
        (0x8825, 4, 1, gps_at),
    ] {
        tiff.extend_from_slice(&tag.to_le_bytes());
        tiff.extend_from_slice(&kind.to_le_bytes());
        tiff.extend_from_slice(&count.to_le_bytes());
        tiff.extend_from_slice(&value.to_le_bytes());
    }
    tiff.extend_from_slice(&0_u32.to_le_bytes());
    tiff.extend_from_slice(description);
    assert_eq!(tiff.len(), gps_at as usize);
    tiff.extend_from_slice(&4_u16.to_le_bytes());
    for (tag, kind, count, value) in [
        (1_u16, 2_u16, 2_u32, 78_u32),
        (2, 5, 3, coordinates_at),
        (3, 2, 2, 69),
        (4, 5, 3, coordinates_at + 24),
    ] {
        tiff.extend_from_slice(&tag.to_le_bytes());
        tiff.extend_from_slice(&kind.to_le_bytes());
        tiff.extend_from_slice(&count.to_le_bytes());
        tiff.extend_from_slice(&value.to_le_bytes());
    }
    tiff.extend_from_slice(&0_u32.to_le_bytes());
    for value in [1_u32, 1, 2, 1, 3, 1, 4, 1, 5, 1, 6, 1] {
        tiff.extend_from_slice(&value.to_le_bytes());
    }
    let mut payload = b"Exif\0\0".to_vec();
    payload.extend(tiff);
    let mut out = bytes[..2].to_vec();
    out.extend_from_slice(&[0xff, 0xe1]);
    out.extend_from_slice(&((payload.len() + 2) as u16).to_be_bytes());
    out.extend(payload);
    out.extend_from_slice(&bytes[2..]);
    out.into()
}
#[test]
fn jpeg_variants_resize_strip_exif_and_original_preserves_pixels_without_gps() -> anyhow::Result<()>
{
    let original = with_exif(&jpeg(2000, 1000), 6);
    let prepared = prepare_jpeg(original.clone(), hash(&original), &ImageLimits::default())?;
    assert_ne!(prepared.original, original);
    assert_eq!((prepared.width, prepared.height), (2000, 1000));
    assert_eq!(prepared.hash, hash(&original));
    assert_eq!(
        image::load_from_memory(&prepared.original)?.to_rgb8(),
        image::load_from_memory(&original)?.to_rgb8()
    );
    // Pixel entropy is copied verbatim, rather than decoded and re-encoded.
    let scan = |bytes: &[u8]| bytes.windows(2).position(|v| v == [0xff, 0xda]).unwrap();
    assert_eq!(
        &prepared.original[scan(&prepared.original)..],
        &original[scan(&original)..]
    );
    let exif = exif::Reader::new()
        .read_from_container(&mut std::io::Cursor::new(prepared.original.as_ref()))?;
    assert_eq!(
        exif.get_field(exif::Tag::Orientation, exif::In::PRIMARY)
            .unwrap()
            .value
            .get_uint(0),
        Some(6)
    );
    let description = &exif
        .get_field(exif::Tag::ImageDescription, exif::In::PRIMARY)
        .unwrap()
        .value;
    assert!(
        matches!(description,exif::Value::Ascii(values) if values.len()==1 && values[0].as_slice()==b"sample camera")
    );
    assert!(
        exif.fields()
            .all(|field| field.tag.context() != exif::Context::Gps && field.tag.number() != 0x8825)
    );
    let gps_bytes = [1_u32, 1, 2, 1, 3, 1, 4, 1, 5, 1, 6, 1]
        .into_iter()
        .flat_map(u32::to_le_bytes)
        .collect::<Vec<_>>();
    assert!(
        original
            .windows(gps_bytes.len())
            .any(|bytes| bytes == gps_bytes.as_slice())
    );
    assert!(
        !prepared
            .original
            .windows(gps_bytes.len())
            .any(|bytes| bytes == gps_bytes.as_slice()),
        "unlinked GPS bytes survived"
    );
    // Inspect the primary TIFF directory as well: absence of parsed GPS values
    // alone would not catch a leftover pointer to an empty/unlinked GPS IFD.
    let tiff = &prepared.original[12..];
    assert_eq!(&tiff[..2], b"II");
    let root = u32::from_le_bytes(tiff[4..8].try_into()?) as usize;
    let count = usize::from(u16::from_le_bytes(tiff[root..root + 2].try_into()?));
    for entry in tiff[root + 2..root + 2 + count * 12].as_chunks::<12>().0 {
        assert_ne!(u16::from_le_bytes(entry[..2].try_into()?), 0x8825);
    }
    for (bytes, dimensions) in [
        (&prepared.display, (800, 1600)),
        (&prepared.thumb, (256, 512)),
    ] {
        let image = image::load_from_memory(bytes)?;
        assert_eq!(image.dimensions(), dimensions);
        assert!(matches!(
            exif::Reader::new().read_from_container(&mut std::io::Cursor::new(bytes.as_ref())),
            Err(exif::Error::NotFound(_))
        ));
        assert!(!bytes.windows(6).any(|v| v == b"Exif\0\0"));
    }
    let small = jpeg(17, 9);
    let prepared = prepare_jpeg(small.clone(), hash(&small), &ImageLimits::default())?;
    assert_eq!(prepared.original, small);
    assert_eq!(
        image::load_from_memory(&prepared.thumb)?.dimensions(),
        (17, 9)
    );
    Ok(())
}
#[test]
fn all_eight_exif_orientations_include_mirrors() -> anyhow::Result<()> {
    let input = image::DynamicImage::ImageRgb8(image::RgbImage::from_fn(2, 3, |x, y| {
        image::Rgb([(y * 2 + x + 1) as u8, 0, 0])
    }));
    for (orientation, expected) in [
        (1, vec![1, 2, 3, 4, 5, 6]),
        (2, vec![2, 1, 4, 3, 6, 5]),
        (3, vec![6, 5, 4, 3, 2, 1]),
        (4, vec![5, 6, 3, 4, 1, 2]),
        (5, vec![1, 3, 5, 2, 4, 6]),
        (6, vec![5, 3, 1, 6, 4, 2]),
        (7, vec![6, 4, 2, 5, 3, 1]),
        (8, vec![2, 4, 6, 1, 3, 5]),
    ] {
        let actual = crate::images::orient(input.clone(), orientation)?.to_rgb8();
        assert_eq!(actual.pixels().map(|p| p[0]).collect::<Vec<_>>(), expected);
        let jpeg = with_exif(&jpeg(31, 17), orientation as u16);
        let prepared = prepare_jpeg(jpeg.clone(), hash(&jpeg), &ImageLimits::default())?;
        assert_eq!(
            image::load_from_memory(&prepared.display)?.dimensions(),
            if orientation >= 5 { (17, 31) } else { (31, 17) }
        );
    }
    Ok(())
}
#[test]
fn jpeg_sniff_hash_body_pixels_edge_and_decode_budget_are_enforced() -> anyhow::Result<()> {
    let bytes = jpeg(16, 12);
    let limits = ImageLimits::default();
    assert!(matches!(
        prepare_jpeg(
            Bytes::from_static(b"not a jpeg"),
            hash(b"not a jpeg"),
            &limits
        ),
        Err(StorageError::NotJpeg)
    ));
    assert!(matches!(
        prepare_jpeg(bytes.clone(), BlobHash::from_bytes([0; 32]), &limits),
        Err(StorageError::Invalid)
    ));
    let mut limited = limits.clone();
    limited.max_upload_bytes = bytes.len() - 1;
    assert!(matches!(
        prepare_jpeg(bytes.clone(), hash(&bytes), &limited),
        Err(StorageError::TooLarge)
    ));
    limited = limits.clone();
    limited.max_decode_bytes = 1;
    assert!(matches!(
        prepare_jpeg(bytes.clone(), hash(&bytes), &limited),
        Err(StorageError::TooLarge)
    ));
    // Patch a generated JPEG's SOF, no allocation of a bomb-sized fixture.
    for (width, height) in [(6000_u16, 5000_u16), (12001, 1)] {
        let mut bomb = bytes.to_vec();
        let position = bomb.windows(2).position(|v| v == [0xff, 0xc0]).unwrap();
        bomb[position + 5..position + 7].copy_from_slice(&height.to_be_bytes());
        bomb[position + 7..position + 9].copy_from_slice(&width.to_be_bytes());
        assert!(matches!(
            prepare_jpeg(bomb.clone().into(), hash(&bomb), &limits),
            Err(StorageError::TooLarge)
        ));
    }
    let mut corrupt = bytes.to_vec();
    corrupt.truncate(16);
    assert!(prepare_jpeg(corrupt.clone().into(), hash(&corrupt), &limits).is_err());
    assert!(BlobHash::parse(&"A".repeat(64)).is_err());
    assert!(BlobHash::parse("../orig.jpg").is_err());
    Ok(())
}

#[test]
fn pdf_envelope_size_and_hash_are_enforced() {
    let valid = pdf(128);
    let expected = hash(&valid);
    let prepared = prepare_pdf(valid.clone(), expected).unwrap();
    assert_eq!(prepared.hash, expected);
    assert_eq!(prepared.bytes, valid);

    for invalid in [
        Bytes::new(),
        Bytes::from_static(b"garbage%PDF-1.7\n%%EOF\n"),
        Bytes::from_static(b"%PDF-a.7\n%%EOF\n"),
        Bytes::from_static(b"%PDF-1.7\nno trailer"),
        Bytes::from_static(b"%PDF-1.7\n%%EOF\nnot whitespace"),
    ] {
        assert!(matches!(
            prepare_pdf(invalid.clone(), hash(&invalid)),
            Err(StorageError::NotPdf)
        ));
    }
    let mut distant_trailer = b"%PDF-1.7\n%%EOF".to_vec();
    distant_trailer.resize(distant_trailer.len() + 1025, b' ');
    assert!(matches!(
        prepare_pdf(distant_trailer.clone().into(), hash(&distant_trailer)),
        Err(StorageError::NotPdf)
    ));
    assert!(matches!(
        prepare_pdf(valid.clone(), BlobHash::from_bytes([7; 32])),
        Err(StorageError::Invalid)
    ));
    let maximum = pdf(MAX_PDF_BYTES);
    assert!(prepare_pdf(maximum.clone(), hash(&maximum)).is_ok());
    let over = pdf(MAX_PDF_BYTES + 1);
    assert!(matches!(
        prepare_pdf(over.clone(), hash(&over)),
        Err(StorageError::TooLarge)
    ));
}
struct Directory(std::path::PathBuf);
impl Drop for Directory {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}
#[tokio::test]
async fn local_layout_conditional_create_stream_and_recovery_listing() -> anyhow::Result<()> {
    let root = Directory(std::env::temp_dir().join(format!("jiabu_storage_{}", Uuid::now_v7())));
    let store = BlobStore::local(&root.0)?;
    let bytes = jpeg(30, 20);
    let image = prepare_jpeg(bytes.clone(), hash(&bytes), &ImageLimits::default())?;
    store.put_if_absent(&image).await?;
    let old = store.candidates().await?;
    store.put_if_absent(&image).await?;
    assert_eq!(old[0].newest, store.candidates().await?[0].newest);
    for suffix in ["orig", "1600", "512"] {
        let sha = image.hash.to_string();
        assert!(
            root.0
                .join(format!("blobs/{}/{sha}.{suffix}.jpg", &sha[..2]))
                .is_file()
        );
    }
    let object = store.get_stream(image.hash, Variant::Original).await?;
    let actual = object
        .stream
        .try_fold(Vec::new(), |mut out, bytes| async move {
            out.extend(bytes);
            Ok(out)
        })
        .await?;
    assert_eq!(actual, bytes.as_ref());
    let file_bytes = pdf(256);
    let file = prepare_pdf(file_bytes.clone(), hash(&file_bytes))?;
    store.put_file_if_absent(&file).await?;
    let file_sha = file.hash.to_string();
    assert!(
        root.0
            .join(format!("blobs/{}/{file_sha}.file.pdf", &file_sha[..2]))
            .is_file()
    );
    let object = store.get_file_stream(file.hash).await?;
    let actual = object
        .stream
        .try_fold(Vec::new(), |mut out, bytes| async move {
            out.extend(bytes);
            Ok(out)
        })
        .await?;
    assert_eq!(actual, file_bytes.as_ref());
    assert_eq!(store.candidates().await?.len(), 2);
    store.delete(image.hash).await?;
    store.delete(file.hash).await?;
    store.delete(image.hash).await?;
    assert!(matches!(
        store.get_stream(image.hash, Variant::Original).await,
        Err(StorageError::NotFound)
    ));
    assert!(matches!(
        store.get_file_stream(file.hash).await,
        Err(StorageError::NotFound)
    ));
    assert!(store.candidates().await?.is_empty());
    Ok(())
}

#[test]
fn unreadable_exif_is_removed_with_orientation_one_but_invalid_orientation_is_rejected()
-> anyhow::Result<()> {
    let plain = jpeg(31, 17);
    let mut broken = with_exif(&plain, 6).to_vec();
    broken[12..14].copy_from_slice(b"XX");
    let prepared = prepare_jpeg(
        broken.clone().into(),
        hash(&broken),
        &ImageLimits::default(),
    )?;
    assert_eq!(prepared.original, plain);
    assert_eq!(
        image::load_from_memory(&prepared.display)?.dimensions(),
        (31, 17)
    );
    for orientation in [0, 9, u16::MAX] {
        let bytes = with_exif(&plain, orientation);
        assert!(matches!(
            prepare_jpeg(bytes.clone(), hash(&bytes), &ImageLimits::default()),
            Err(StorageError::Invalid)
        ));
    }
    Ok(())
}

#[test]
fn gps_is_removed_from_every_exif_segment_and_big_endian_tiff() -> anyhow::Result<()> {
    let plain = jpeg(31, 17);
    let little = with_exif(&plain, 6);
    let parsed =
        exif::Reader::new().read_from_container(&mut std::io::Cursor::new(little.as_ref()))?;
    let mut writer = exif::experimental::Writer::new();
    for field in parsed.fields() {
        writer.push_field(field);
    }
    let mut tiff = std::io::Cursor::new(Vec::new());
    writer.write(&mut tiff, false)?;
    let tiff = tiff.into_inner();
    assert_eq!(&tiff[..2], b"MM");
    let mut big = plain[..2].to_vec();
    big.extend_from_slice(&[0xff, 0xe1]);
    big.extend_from_slice(&((tiff.len() + 8) as u16).to_be_bytes());
    big.extend_from_slice(b"Exif\0\0");
    big.extend(tiff);
    big.extend_from_slice(&plain[2..]);
    let mixed = with_exif(&big, 6);
    let prepared = prepare_jpeg(mixed.clone(), hash(&mixed), &ImageLimits::default())?;
    let mut at = 2;
    let mut count = 0;
    // These fixtures put all metadata before the first scan.
    while prepared.original[at + 1] != 0xda {
        let marker = prepared.original[at + 1];
        let size = usize::from(u16::from_be_bytes(
            prepared.original[at + 2..at + 4].try_into()?,
        ));
        let payload = &prepared.original[at + 4..at + 2 + size];
        if marker == 0xe1 && payload.starts_with(b"Exif\0\0") {
            let exif = exif::Reader::new().read_raw(payload[6..].to_vec())?;
            assert!(
                exif.fields()
                    .all(|field| field.tag.context() != exif::Context::Gps
                        && field.tag.number() != 0x8825)
            );
            assert_eq!(
                exif.get_field(exif::Tag::Orientation, exif::In::PRIMARY)
                    .unwrap()
                    .value
                    .get_uint(0),
                Some(6)
            );
            count += 1;
        }
        at += 2 + size;
    }
    assert_eq!(count, 2);
    assert_eq!(
        image::load_from_memory(&prepared.original)?.to_rgb8(),
        image::load_from_memory(&mixed)?.to_rgb8()
    );
    Ok(())
}

#[test]
fn transfer_timeout_has_safe_defaults_and_rejects_invalid_configuration() {
    let mut limits = ImageLimits::default();
    assert_eq!(limits.transfer_timeout_secs, 600);
    assert!(limits.validate().is_ok());
    for seconds in [0, 86401] {
        limits.transfer_timeout_secs = seconds;
        assert!(limits.validate().is_err());
    }
}

fn with_app_segment(bytes: &[u8], marker: u8, payload: &[u8]) -> Bytes {
    let mut out = bytes[..2].to_vec();
    out.extend_from_slice(&[0xff, marker]);
    out.extend_from_slice(&u16::try_from(payload.len() + 2).unwrap().to_be_bytes());
    out.extend_from_slice(payload);
    out.extend_from_slice(&bytes[2..]);
    out.into()
}

#[test]
fn original_stops_at_first_eoi_and_discards_appended_gps_jpeg() -> anyhow::Result<()> {
    let plain = jpeg(31, 17);
    assert!(plain.ends_with(&[0xff, 0xd9]));
    let appended = with_exif(&jpeg(8, 6), 6);
    let mut upload = plain.to_vec();
    upload.extend_from_slice(&appended);
    assert!(upload.windows(6).any(|bytes| bytes == b"Exif\0\0"));
    let prepared = prepare_jpeg(
        upload.clone().into(),
        hash(&upload),
        &ImageLimits::default(),
    )?;
    assert_eq!(prepared.original, plain);
    assert_eq!(prepared.hash, hash(&upload));
    assert!(
        !prepared
            .original
            .windows(6)
            .any(|bytes| bytes == b"Exif\0\0")
    );
    Ok(())
}

#[test]
fn original_discards_standard_and_extended_xmp_location_segments() -> anyhow::Result<()> {
    let plain = jpeg(31, 17);
    let xml = br#"<rdf:Description exif:GPSLatitude="1,2,3N" exif:GPSLongitude="4,5,6E"/>"#;
    for extended in [false, true] {
        let mut payload = if extended {
            b"http://ns.adobe.com/xmp/extension/\0".to_vec()
        } else {
            b"http://ns.adobe.com/xap/1.0/\0".to_vec()
        };
        if extended {
            payload.extend_from_slice(b"00000000000000000000000000000000");
            payload.extend_from_slice(&(xml.len() as u32).to_be_bytes());
            payload.extend_from_slice(&0_u32.to_be_bytes());
        }
        payload.extend_from_slice(xml);
        let upload = with_app_segment(&plain, 0xe1, &payload);
        let prepared = prepare_jpeg(upload.clone(), hash(&upload), &ImageLimits::default())?;
        assert_eq!(prepared.original, plain, "extended={extended}");
    }
    Ok(())
}

#[test]
fn original_discards_entire_app13_iptc_location_segment() -> anyhow::Result<()> {
    let plain = jpeg(31, 17);
    let iptc = b"\x1c\x02\x5c\0\x10example location";
    let mut payload = b"Photoshop 3.0\0".to_vec();
    payload.extend_from_slice(b"8BIM\x04\x04\0\0");
    payload.extend_from_slice(&(iptc.len() as u32).to_be_bytes());
    payload.extend_from_slice(iptc);
    if !iptc.len().is_multiple_of(2) {
        payload.push(0);
    }
    let upload = with_app_segment(&plain, 0xed, &payload);
    let prepared = prepare_jpeg(upload.clone(), hash(&upload), &ImageLimits::default())?;
    assert_eq!(prepared.original, plain);
    Ok(())
}

fn assert_failed_rewrite_discards_exif(tiff: Vec<u8>, orientation: u32) -> anyhow::Result<()> {
    let parsed = exif::Reader::new().read_raw(tiff.clone())?;
    let mut writer = exif::experimental::Writer::new();
    for field in parsed.fields() {
        if field.tag.context() != exif::Context::Gps && field.tag.number() != 0x8825 {
            writer.push_field(field);
        }
    }
    // Prove the fixture reaches the writer failure rather than parse fallback.
    assert!(
        writer
            .write(&mut std::io::Cursor::new(Vec::new()), true)
            .is_err()
    );
    let plain = jpeg(31, 17);
    let mut payload = b"Exif\0\0".to_vec();
    payload.extend(tiff);
    let upload = with_app_segment(&plain, 0xe1, &payload);
    let prepared = prepare_jpeg(upload.clone(), hash(&upload), &ImageLimits::default())?;
    assert_eq!(prepared.original, plain);
    assert_eq!(
        image::load_from_memory(&prepared.display)?.dimensions(),
        if orientation >= 5 { (17, 31) } else { (31, 17) }
    );
    Ok(())
}

#[test]
fn unknown_exif_field_type_discards_segment_and_keeps_parsed_orientation() -> anyhow::Result<()> {
    let mut tiff = b"II\x2a\0\x08\0\0\0".to_vec();
    tiff.extend_from_slice(&2_u16.to_le_bytes());
    for (tag, kind, value) in [(0x0112_u16, 3_u16, 6_u32), (0xc7a1, 0xffff, 0)] {
        tiff.extend_from_slice(&tag.to_le_bytes());
        tiff.extend_from_slice(&kind.to_le_bytes());
        tiff.extend_from_slice(&1_u32.to_le_bytes());
        tiff.extend_from_slice(&value.to_le_bytes());
    }
    tiff.extend_from_slice(&0_u32.to_le_bytes());
    assert_failed_rewrite_discards_exif(tiff, 6)
}

#[test]
fn gps_only_primary_ifd_with_thumbnail_discards_unwritable_exif() -> anyhow::Result<()> {
    let mut tiff = b"II\x2a\0\x08\0\0\0".to_vec();
    tiff.extend_from_slice(&1_u16.to_le_bytes());
    // IFD0 contains only the GPS pointer; its next directory is IFD1.
    tiff.extend_from_slice(&0x8825_u16.to_le_bytes());
    tiff.extend_from_slice(&4_u16.to_le_bytes());
    tiff.extend_from_slice(&1_u32.to_le_bytes());
    tiff.extend_from_slice(&44_u32.to_le_bytes());
    tiff.extend_from_slice(&26_u32.to_le_bytes());
    tiff.extend_from_slice(&1_u16.to_le_bytes());
    tiff.extend_from_slice(&0x0112_u16.to_le_bytes());
    tiff.extend_from_slice(&3_u16.to_le_bytes());
    tiff.extend_from_slice(&1_u32.to_le_bytes());
    tiff.extend_from_slice(&6_u32.to_le_bytes());
    tiff.extend_from_slice(&0_u32.to_le_bytes());
    assert_eq!(tiff.len(), 44);
    tiff.extend_from_slice(&1_u16.to_le_bytes());
    tiff.extend_from_slice(&2_u16.to_le_bytes());
    tiff.extend_from_slice(&5_u16.to_le_bytes());
    tiff.extend_from_slice(&3_u32.to_le_bytes());
    tiff.extend_from_slice(&62_u32.to_le_bytes());
    tiff.extend_from_slice(&0_u32.to_le_bytes());
    for value in [1_u32, 1, 2, 1, 3, 1] {
        tiff.extend_from_slice(&value.to_le_bytes());
    }
    // IFD1's orientation is not the primary image's orientation: default to 1.
    assert_failed_rewrite_discards_exif(tiff, 1)
}

#[test]
fn in_flight_upload_limit_has_default_and_rejects_invalid_configuration() {
    let mut limits = ImageLimits::default();
    assert_eq!(limits.max_in_flight_uploads, 8);
    assert!(limits.validate().is_ok());
    for value in [0, 1025] {
        limits.max_in_flight_uploads = value;
        assert!(limits.validate().is_err());
    }
}
