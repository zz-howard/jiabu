use super::*;
use crate::tasks::test_support as support;
use anyhow::Result;
use bytes::Bytes;
use chrono::{DateTime, Duration as Days, Utc};
use jiabu_db::{Mode, SpaceTx};
use jiabu_domain::{
    SpaceId,
    spaces::{Change, CreateSpace},
};
use jiabu_storage::{ImageLimits, PreparedJpeg, Variant, prepare_jpeg, prepare_pdf};
use sha2::{Digest, Sha256};
use tokio::sync::Notify;
use uuid::Uuid;
struct Fixed(DateTime<Utc>);
impl Clock for Fixed {
    fn now(&self) -> DateTime<Utc> {
        self.0
    }
}
fn image() -> PreparedJpeg {
    let image = image::RgbImage::from_pixel(12, 8, image::Rgb([80, 40, 20]));
    let mut bytes = Vec::new();
    image::codecs::jpeg::JpegEncoder::new(&mut bytes)
        .encode_image(&image)
        .unwrap();
    let hash = BlobHash::from_bytes(Sha256::digest(&bytes).into());
    prepare_jpeg(Bytes::from(bytes), hash, &ImageLimits::default()).unwrap()
}
#[tokio::test]
async fn idempotency_expires_at_ninety_days_using_injected_clock() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let seed = fixture.seed("sample", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let store = BlobStore::local(fixture.data_dir())?;
    let owner = fixture.owner().await?;
    let now = Utc::now();
    for (key, date) in [
        ("old", now - Days::days(91)),
        ("boundary", now - Days::days(90)),
        ("recent", now - Days::days(90) + Days::seconds(1)),
    ] {
        sqlx::query("insert into idempotency(user_id,key,request_hash,created_at) values($1,$2,decode('00','hex'),$3)").bind(seed.user_id.0).bind(key).bind(date).execute(&owner).await?;
    }
    assert_eq!(cleanup_once(&db, &store, &Fixed(now)).await?.idempotency, 2);
    assert_eq!(cleanup_once(&db, &store, &Fixed(now)).await?.idempotency, 0);
    assert_eq!(
        cleanup_once(&db, &store, &Fixed(now + Days::seconds(1)))
            .await?
            .idempotency,
        1
    );
    owner.close().await;
    db.close().await?;
    Ok(())
}
#[tokio::test]
async fn referenced_blob_survives_and_purge_starts_a_fresh_one_day_grace() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let seed = fixture.seed("sample", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let store = BlobStore::local(fixture.data_dir())?;
    let image = image();
    let file_bytes = Bytes::from_static(b"%PDF-1.7\nsynthetic retained file\n%%EOF\n");
    let file_hash = BlobHash::from_bytes(Sha256::digest(&file_bytes).into());
    let file = prepare_pdf(file_bytes, file_hash)?;
    let now = Utc::now();
    let space = SpaceId(Uuid::now_v7());
    db.create_space(
        seed.user_id,
        "sample",
        CreateSpace {
            id: space.0,
            name: "示例待删除".into(),
            accent_color: "pine".into(),
            currency: "CNY".into(),
            timezone: "UTC".into(),
        },
        &jiabu_db::Idempotency {
            key: Uuid::now_v7().to_string(),
            hash: vec![1],
        },
        Uuid::now_v7(),
    )
    .await?;
    let tx = SpaceTx::begin(&db, seed.user_id, &[(space, None)], Mode::Write).await?;
    tx.lock_blobs().await?;
    tx.save_blob(
        space,
        &image.hash.bytes(),
        image.original.len() as i64,
        (12, 8),
        now - Days::days(30),
    )
    .await?;
    store.put_if_absent(&image).await?;
    tx.save_file(
        space,
        &file.hash.bytes(),
        file.bytes.len() as i64,
        now - Days::days(30),
    )
    .await?;
    store.put_file_if_absent(&file).await?;
    tx.add_blob_ref(space, "ledger", &image.hash.bytes(), now)
        .await?;
    tx.add_blob_ref(space, "chat_file", &file.hash.bytes(), now)
        .await?;
    tx.commit().await?;
    assert_eq!(cleanup_once(&db, &store, &Fixed(now)).await?.blobs, 0);
    assert!(
        store
            .get_stream(image.hash, Variant::Original)
            .await
            .is_ok()
    );
    assert!(store.get_file_stream(file.hash).await.is_ok());
    let tx = SpaceTx::begin(&db, seed.user_id, &[(space, None)], Mode::Write).await?;
    tx.apply_change(
        space,
        Change::Delete {
            name: "示例待删除".into(),
        },
        Uuid::now_v7(),
    )
    .await?;
    tx.commit().await?;
    super::super::purge_spaces::purge_deleted_spaces_with_clock(&db, &Fixed(now)).await?;
    assert_eq!(
        cleanup_once(&db, &store, &Fixed(now + Days::days(1) - Days::seconds(1)))
            .await?
            .blobs,
        0
    );
    assert_eq!(
        cleanup_once(&db, &store, &Fixed(now + Days::days(1)))
            .await?
            .blobs,
        2
    );
    for variant in [Variant::Original, Variant::Display, Variant::Thumb] {
        assert!(store.get_stream(image.hash, variant).await.is_err());
    }
    assert!(store.get_file_stream(file.hash).await.is_err());
    db.close().await?;
    Ok(())
}
#[tokio::test]
async fn filesystem_orphan_and_partial_delete_failure_are_retryable() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let seed = fixture.seed("sample", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let store = BlobStore::local(fixture.data_dir())?;
    let image = image();
    // Simulate file writes followed by a transaction rollback: no metadata row.
    store.put_if_absent(&image).await?;
    let created = store.candidates().await?[0].newest;
    assert_eq!(
        cleanup_once(
            &db,
            &store,
            &Fixed(created + Days::days(1) - Days::seconds(1))
        )
        .await?
        .blobs,
        0
    );
    assert_eq!(
        cleanup_once(&db, &store, &Fixed(created + Days::days(1)))
            .await?
            .blobs,
        1
    );
    // A directory where a file should be makes LocalFileSystem's unlink fail,
    // even when tests run as root. Metadata must remain retryable after failure.
    let now = Utc::now();
    let tx = SpaceTx::begin(&db, seed.user_id, &[(seed.space_id, None)], Mode::Write).await?;
    tx.save_blob(
        seed.space_id,
        &image.hash.bytes(),
        image.original.len() as i64,
        (12, 8),
        now - Days::days(2),
    )
    .await?;
    store.put_if_absent(&image).await?;
    tx.commit().await?;
    let hash = image.hash.to_string();
    let thumb = fixture
        .data_dir()
        .join(format!("blobs/{}/{hash}.512.jpg", &hash[..2]));
    std::fs::remove_file(&thumb)?;
    std::fs::create_dir(&thumb)?;
    std::fs::write(thumb.join("test-only"), b"test")?;
    assert_eq!(cleanup_once(&db, &store, &Fixed(now)).await?.failures, 1);
    let owner = fixture.owner().await?;
    let count: i64 = sqlx::query_scalar("select count(*) from blobs")
        .fetch_one(&owner)
        .await?;
    assert_eq!(count, 1);
    std::fs::remove_dir_all(thumb)?;
    assert_eq!(cleanup_once(&db, &store, &Fixed(now)).await?.blobs, 1);
    owner.close().await;
    db.close().await?;
    Ok(())
}
#[tokio::test]
async fn blob_cleanup_rechecks_reference_after_candidate_barrier() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20), async {
        let fixture = support::TestDb::new().await?;
        let seed = fixture.seed("sample", "unused").await?;
        let db = AppDb::connect(&fixture.app_url).await?;
        let store = Arc::new(BlobStore::local(fixture.data_dir())?);
        let image = image();
        let now = Utc::now();
        let tx = SpaceTx::begin(&db, seed.user_id, &[(seed.space_id, None)], Mode::Write).await?;
        tx.save_blob(
            seed.space_id,
            &image.hash.bytes(),
            image.original.len() as i64,
            (12, 8),
            now - Days::days(2),
        )
        .await?;
        store.put_if_absent(&image).await?;
        tx.commit().await?;
        let entered = Arc::new(Notify::new());
        let release = Arc::new(Notify::new());
        let collector_db = db.clone();
        let collector_store = store.clone();
        let gate = (entered.clone(), release.clone());
        let collector = tokio::spawn(async move {
            collect(&collector_db, &collector_store, &Fixed(now), Some(gate)).await
        });
        entered.notified().await;
        let tx = SpaceTx::begin(&db, seed.user_id, &[(seed.space_id, None)], Mode::Write).await?;
        tx.add_blob_ref(seed.space_id, "chat", &image.hash.bytes(), now)
            .await?;
        tx.commit().await?;
        release.notify_one();
        let report = collector.await??;
        assert_eq!(report.blobs, 0);
        assert!(
            store
                .get_stream(image.hash, Variant::Original)
                .await
                .is_ok()
        );
        db.close().await?;
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}

#[tokio::test]
async fn staging_orphans_expire_after_one_day_without_touching_committed_or_unrelated_files()
-> Result<()> {
    let fixture = support::TestDb::new().await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let store = BlobStore::local(fixture.data_dir())?;
    let image = image();
    store.put_if_absent(&image).await?;
    let hash = image.hash.to_string();
    let directory = fixture.data_dir().join(format!("blobs/{}", &hash[..2]));
    let now = Utc::now();
    let old = now - Days::days(1);
    let staging = directory.join(format!("{hash}.orig.jpg#1"));
    let recent = directory.join(format!("{hash}.512.jpg#2"));
    let unrelated = directory.join("unrelated#3");
    let invalid = directory.join(format!("{hash}.orig.jpg#abc"));
    for (path, modified) in [
        (&staging, old),
        (&recent, now),
        (&unrelated, old),
        (&invalid, old),
    ] {
        std::fs::write(path, b"fake staging data")?;
        std::fs::File::options()
            .write(true)
            .open(path)?
            .set_times(std::fs::FileTimes::new().set_modified(modified.into()))?;
    }
    assert_eq!(
        cleanup_once(&db, &store, &Fixed(now - Days::seconds(1)))
            .await?
            .staging,
        0
    );
    assert_eq!(cleanup_once(&db, &store, &Fixed(now)).await?.staging, 1);
    assert!(!staging.exists());
    assert!(recent.exists());
    assert!(unrelated.exists());
    assert!(invalid.exists());
    assert!(
        store
            .get_stream(image.hash, Variant::Original)
            .await
            .is_ok()
    );
    assert_eq!(cleanup_once(&db, &store, &Fixed(now)).await?.staging, 0);
    db.close().await?;
    Ok(())
}

#[test]
fn blob_retention_migration_has_no_generation_placeholder() {
    assert!(!include_str!("../../../../migrations/0007_blob_retention.sql").contains("TODO(luna)"));
}

#[tokio::test]
async fn old_referenced_files_do_not_acquire_the_global_lifecycle_lock() -> Result<()> {
    tokio::time::timeout(std::time::Duration::from_secs(20), async {
        let fixture = support::TestDb::new().await?;
        let seed = fixture.seed("sample", "unused").await?;
        let db = AppDb::connect(&fixture.app_url).await?;
        let store = BlobStore::local(fixture.data_dir())?;
        let image = image();
        let tx = SpaceTx::begin(&db, seed.user_id, &[(seed.space_id, None)], Mode::Write).await?;
        tx.save_blob(
            seed.space_id,
            &image.hash.bytes(),
            image.original.len() as i64,
            (12, 8),
            Utc::now(),
        )
        .await?;
        tx.add_blob_ref(seed.space_id, "ledger", &image.hash.bytes(), Utc::now())
            .await?;
        store.put_if_absent(&image).await?;
        tx.commit().await?;
        let now = store.candidates().await?[0].newest + Days::days(2);
        // A real lock barrier: cleanup must finish while this lock is held.
        // Reintroducing per-file locking for known rows deterministically stalls.
        let mut blocked = SystemTx::begin(&db).await?;
        blocked.lock_blobs().await?;
        let report = cleanup_once(&db, &store, &Fixed(now)).await?;
        assert_eq!(report.blobs, 0);
        assert_eq!(report.failures, 0);
        blocked.rollback().await?;
        assert!(
            store
                .get_stream(image.hash, Variant::Original)
                .await
                .is_ok()
        );
        db.close().await?;
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}

#[tokio::test]
async fn filesystem_orphan_filter_rechecks_metadata_created_after_filter_barrier() -> Result<()> {
    tokio::time::timeout(std::time::Duration::from_secs(20), async {
        let fixture = support::TestDb::new().await?;
        let seed = fixture.seed("sample", "unused").await?;
        let db = AppDb::connect(&fixture.app_url).await?;
        let store = Arc::new(BlobStore::local(fixture.data_dir())?);
        let image = image();
        store.put_if_absent(&image).await?;
        let now = store.candidates().await?[0].newest + Days::days(2);
        let entered = Arc::new(Notify::new());
        let release = Arc::new(Notify::new());
        let collector_db = db.clone();
        let collector_store = store.clone();
        let gate = (entered.clone(), release.clone());
        let collector = tokio::spawn(async move {
            collect(&collector_db, &collector_store, &Fixed(now), Some(gate)).await
        });
        entered.notified().await;
        let tx = SpaceTx::begin(&db, seed.user_id, &[(seed.space_id, None)], Mode::Write).await?;
        tx.save_blob(
            seed.space_id,
            &image.hash.bytes(),
            image.original.len() as i64,
            (12, 8),
            now,
        )
        .await?;
        tx.add_blob_ref(seed.space_id, "chat", &image.hash.bytes(), now)
            .await?;
        tx.commit().await?;
        release.notify_one();
        let report = collector.await??;
        assert_eq!(report.blobs, 0);
        assert!(
            store
                .get_stream(image.hash, Variant::Original)
                .await
                .is_ok()
        );
        db.close().await?;
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}
