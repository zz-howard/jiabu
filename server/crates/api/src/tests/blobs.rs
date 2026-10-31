use super::{s4::*, *};
use jiabu_domain::{SpaceId, spaces::Change};
use jiabu_storage::{BlobHash, ImageLimits};
use std::{future::Future, sync::Arc, task::Poll, time::Duration};
use tokio::sync::Notify;

fn fake_pdf() -> Vec<u8> {
    b"%PDF-1.7\nsynthetic attachment\n%%EOF\n".to_vec()
}
async fn put_file(
    h: &S4App,
    space: Uuid,
    bytes: Vec<u8>,
    token: &str,
    content_type: &str,
) -> Result<Reply> {
    let sha = hash(&bytes);
    h.app
        .raw_request(
            "PUT",
            &format!("/v1/spaces/{space}/files/{sha}"),
            bytes,
            content_type,
            Some(token),
            &[("x-jiabu-join-epoch", "1".into())],
        )
        .await
}
async fn get_file(h: &S4App, space: Uuid, sha: BlobHash, token: &str) -> Result<Reply> {
    h.app
        .raw_request(
            "GET",
            &format!("/v1/spaces/{space}/files/{sha}"),
            vec![],
            "application/pdf",
            Some(token),
            &[],
        )
        .await
}

#[tokio::test]
async fn pdf_files_are_member_owned_and_download_with_safe_headers() -> Result<()> {
    let h = S4App::new().await?;
    let space = h.new_space().await?;
    let guest = h.actor("pdf-guest", space).await?;
    let bytes = fake_pdf();
    let sha = hash(&bytes);
    let first = put_file(&h, space, bytes.clone(), &guest.token, "application/pdf").await?;
    assert_eq!(first.status, StatusCode::NO_CONTENT);
    let repeated = put_file(&h, space, bytes.clone(), &guest.token, "application/pdf").await?;
    assert_eq!(repeated.status, first.status);
    let mut first_headers = first.headers.clone();
    let mut repeated_headers = repeated.headers.clone();
    first_headers.remove("x-request-id");
    repeated_headers.remove("x-request-id");
    assert_eq!(repeated_headers, first_headers);
    assert_eq!(repeated.bytes, first.bytes);
    assert_eq!(
        get_file(&h, space, sha, &h.token).await?.status,
        StatusCode::NOT_FOUND
    );
    let guest_download = get_file(&h, space, sha, &guest.token).await?;
    assert_eq!(guest_download.status, StatusCode::OK);
    assert_eq!(guest_download.bytes, bytes);
    assert_eq!(guest_download.headers["content-type"], "application/pdf");
    assert_eq!(guest_download.headers["content-disposition"], "attachment");
    assert_eq!(guest_download.headers["x-content-type-options"], "nosniff");

    assert_eq!(
        put_file(
            &h,
            space,
            bytes.clone(),
            &h.token,
            "application/pdf; charset=binary"
        )
        .await?
        .status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        get_file(&h, space, sha, &h.token).await?.status,
        StatusCode::OK
    );
    assert_eq!(
        h.get(space, sha, "original", &guest.token).await?.status,
        StatusCode::NOT_FOUND,
        "legacy JPEG endpoint must reject chat_file refs"
    );
    let owner = h.app.fixture.owner().await?;
    let refs: i64 = sqlx::query_scalar(
        "select count(*) from blob_refs where space_id=$1 and module='chat_file'",
    )
    .bind(space)
    .fetch_one(&owner)
    .await?;
    assert_eq!(refs, 2);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn pdf_upload_validates_complete_body_type_hash_and_size() -> Result<()> {
    let h = S4App::new().await?;
    let bytes = fake_pdf();
    let sha = hash(&bytes);
    let path = format!("/v1/spaces/{}/files/{sha}", h.space);
    for (body, content_type, expected) in [
        (
            vec![],
            "application/pdf",
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
        ),
        (
            b"not a pdf".to_vec(),
            "application/pdf",
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
        ),
        (
            bytes.clone(),
            "text/plain",
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
        ),
    ] {
        let reply = h
            .app
            .raw_request(
                "PUT",
                &path,
                body,
                content_type,
                Some(&h.token),
                &[("x-jiabu-join-epoch", "1".into())],
            )
            .await?;
        assert_eq!(reply.status, expected);
    }
    let request = Request::builder()
        .method("PUT")
        .uri(&path)
        .header("authorization", format!("Bearer {}", h.token))
        .header("x-jiabu-join-epoch", "1")
        .body(Body::from(bytes.clone()))?;
    assert_eq!(
        h.app.router.clone().oneshot(request).await?.status(),
        StatusCode::NO_CONTENT,
        "an absent Content-Type is accepted because the PDF envelope is authoritative"
    );
    assert_eq!(
        h.app
            .raw_request(
                "PUT",
                &path,
                b"%PDF-1.7\nmissing trailer".to_vec(),
                "application/pdf",
                Some(&h.token),
                &[("x-jiabu-join-epoch", "1".into())],
            )
            .await?
            .status,
        StatusCode::UNSUPPORTED_MEDIA_TYPE,
        "an existing hash must not bypass complete-body validation"
    );
    let wrong_hash = format!("/v1/spaces/{}/files/{}", h.space, "00".repeat(32));
    assert_eq!(
        h.app
            .raw_request(
                "PUT",
                &wrong_hash,
                bytes,
                "application/pdf",
                Some(&h.token),
                &[("x-jiabu-join-epoch", "1".into())],
            )
            .await?
            .status,
        StatusCode::UNPROCESSABLE_ENTITY
    );
    let mut over = b"%PDF-1.7\n".to_vec();
    over.resize(10 * 1024 * 1024 + 1, b'x');
    assert_eq!(
        put_file(&h, h.space, over, &h.token, "application/pdf")
            .await?
            .status,
        StatusCode::PAYLOAD_TOO_LARGE
    );
    Ok(())
}

#[tokio::test]
async fn blob_upload_responses_identical_for_repeat_cross_space_and_second_chat_member()
-> Result<()> {
    let h = S4App::new().await?;
    let space = h.new_space().await?;
    let guest = h.actor("guest", space).await?;
    let bytes = jpeg(40, 24);
    let mut previous: Option<Reply> = None;
    for (space, module, token) in [
        (h.space, "ledger", &h.token),
        (h.space, "ledger", &h.token),
        (space, "chat", &h.token),
        (space, "chat", &guest.token),
    ] {
        let reply = h.upload(space, module, bytes.clone(), token, 1).await?;
        assert_eq!(reply.status, StatusCode::NO_CONTENT);
        assert!(reply.bytes.is_empty());
        if let Some(old) = &previous {
            assert_eq!(reply.headers, old.headers);
            assert_eq!(reply.bytes, old.bytes);
        }
        previous = Some(reply);
    }
    let third = h.actor("third", space).await?;
    assert_eq!(
        h.get(space, hash(&bytes), "original", &third.token)
            .await?
            .status,
        StatusCode::NOT_FOUND
    );
    let blank = h.new_space().await?;
    assert_eq!(
        h.get(blank, hash(&bytes), "original", &h.token)
            .await?
            .status,
        StatusCode::NOT_FOUND
    );
    let owner = h.app.fixture.owner().await?;
    let blobs: i64 = sqlx::query_scalar("select count(*) from blobs")
        .fetch_one(&owner)
        .await?;
    assert_eq!(blobs, 1);
    let refs: i64 =
        sqlx::query_scalar("select count(*) from blob_refs where space_id=$1 and module='chat'")
            .bind(space)
            .fetch_one(&owner)
            .await?;
    assert_eq!(refs, 2);
    for token in [&h.token, &guest.token] {
        let response = h.get(space, hash(&bytes), "original", token).await?;
        assert_eq!(response.status, StatusCode::OK);
        assert_eq!(response.bytes, bytes);
        for variant in ["display", "thumb"] {
            let response = h.get(space, hash(&bytes), variant, token).await?;
            assert_eq!(response.status, StatusCode::OK);
            assert!(!response.bytes.windows(6).any(|v| v == b"Exif\0\0"));
        }
    }
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn blob_chat_ownership_module_permissions_and_own_attachment_promotion() -> Result<()> {
    let h = S4App::new().await?;
    let space = h.new_space().await?;
    let guest = h.actor("guest", space).await?;
    let third = h.actor("third", space).await?;
    let bytes = jpeg(20, 12);
    let sha = hash(&bytes);
    assert_eq!(
        h.upload(space, "chat", bytes.clone(), &guest.token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        h.get(space, sha, "original", &guest.token).await?.status,
        StatusCode::OK
    );
    for token in [&h.token, &third.token] {
        assert_eq!(
            h.get(space, sha, "original", token).await?.status,
            StatusCode::NOT_FOUND
        );
    }
    // A second space membership does not confer any reference to this object.
    assert_eq!(
        h.get(h.space, sha, "original", &h.token).await?.status,
        StatusCode::NOT_FOUND
    );
    let (real, purpose) = h.accounts(space).await?;
    let args = json!({"kind":"expense","amount_minor":10,"occurred_on":"2026-10-01","account_id":real,"purpose_id":purpose,"attachments":[sha.to_string()]});
    let denied = h
        .push(vec![op(space, "create_record", args.clone())], &h.token)
        .await?;
    assert_eq!(denied["results"][0]["problem"]["code"], "blob_missing");
    let owner = h.app.fixture.owner().await?;
    let refs: i64 =
        sqlx::query_scalar("select count(*) from blob_refs where space_id=$1 and module='ledger'")
            .bind(space)
            .fetch_one(&owner)
            .await?;
    assert_eq!(refs, 0);
    let saved = h
        .push(vec![op(space, "create_record", args)], &guest.token)
        .await?;
    assert_eq!(saved["results"][0]["status"], "ok");
    let uploader: Uuid = sqlx::query_scalar(
        "select uploaded_by_member_id from blob_refs where space_id=$1 and module='ledger'",
    )
    .bind(space)
    .fetch_one(&owner)
    .await?;
    assert_eq!(uploader, guest.member);
    assert_eq!(
        h.get(space, sha, "original", &third.token).await?.status,
        StatusCode::OK
    );
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='ledger'",
    )
    .bind(third.member)
    .execute(&owner)
    .await?;
    assert_eq!(
        h.get(space, sha, "original", &third.token).await?.status,
        StatusCode::NOT_FOUND
    );
    assert_eq!(
        h.upload(space, "ledger", bytes.clone(), &third.token, 1)
            .await?
            .status,
        StatusCode::NOT_FOUND
    );
    sqlx::query(
        "update space_member_grants set level='read' where member_id=$1 and module='ledger'",
    )
    .bind(third.member)
    .execute(&owner)
    .await?;
    assert_eq!(
        h.get(space, sha, "original", &third.token).await?.status,
        StatusCode::OK
    );
    assert_eq!(
        h.upload(space, "ledger", bytes.clone(), &third.token, 1)
            .await?
            .status,
        StatusCode::NOT_FOUND
    );
    // Documents has its own read grant; ledger permissions cannot stand in for it.
    let second = jpeg(22, 14);
    let sha2 = hash(&second);
    assert_eq!(
        h.upload(space, "documents", second, &h.token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='documents'",
    )
    .bind(third.member)
    .execute(&owner)
    .await?;
    assert_eq!(
        h.get(space, sha2, "thumb", &third.token).await?.status,
        StatusCode::NOT_FOUND
    );
    sqlx::query(
        "update space_member_grants set level='read' where member_id=$1 and module='documents'",
    )
    .bind(third.member)
    .execute(&owner)
    .await?;
    assert_eq!(
        h.get(space, sha2, "thumb", &third.token).await?.status,
        StatusCode::OK
    );
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn blob_unavailable_upload_and_download_are_byte_identical_before_content_checks()
-> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    let a = h.app.fixture.seed("foreign", "unused").await?;
    let b = h.app.fixture.seed("another", "unused").await?;
    let exited = h.new_space().await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::query(
        "update space_members set status='left',left_reason='left',left_at=now() where space_id=$1",
    )
    .bind(exited)
    .execute(&owner)
    .await?;
    owner.close().await;
    let image = jpeg(10, 10);
    let sha = hash(&image);
    for caller in h.key_callers().await? {
        let mut expected: Option<Reply> = None;
        for space in [a.space_id.0, exited, b.space_id.0, Uuid::now_v7()] {
            for method in ["PUT", "GET"] {
                let query = if method == "PUT" {
                    "module=ledger"
                } else {
                    "variant=original"
                };
                // Even invalid image bytes must be hidden behind membership validation.
                let response = h
                    .app
                    .raw_request(
                        method,
                        &format!("/v1/spaces/{space}/blobs/{sha}?{query}"),
                        b"not JPEG".to_vec(),
                        "image/jpeg",
                        Some(&caller),
                        &[
                            ("x-jiabu-join-epoch", "1".into()),
                            (
                                "x-request-id",
                                "00000000-0000-7000-8000-000000000001".into(),
                            ),
                        ],
                    )
                    .await?;
                assert_eq!(response.status, StatusCode::NOT_FOUND);
                if let Some(old) = &expected {
                    assert_eq!(response.bytes, old.bytes);
                    assert_eq!(response.headers, old.headers);
                }
                expected = Some(response);
            }
        }
    }
    Ok(())
}
#[tokio::test]
async fn blob_upload_always_requires_complete_valid_content_even_if_hash_exists() -> Result<()> {
    let h = S4App::new().await?;
    let bytes = jpeg(32, 20);
    let sha = hash(&bytes);
    h.upload(h.space, "ledger", bytes.clone(), &h.token, 1)
        .await?;
    let path = format!("/v1/spaces/{}/blobs/{sha}?module=ledger", h.space);
    for (bad, status) in [
        (vec![], StatusCode::UNSUPPORTED_MEDIA_TYPE),
        (b"not jpeg".to_vec(), StatusCode::UNSUPPORTED_MEDIA_TYPE),
        (jpeg(12, 12), StatusCode::UNPROCESSABLE_ENTITY),
    ] {
        let response = h
            .app
            .raw_request(
                "PUT",
                &path,
                bad,
                "image/jpeg",
                Some(&h.token),
                &[("x-jiabu-join-epoch", "1".into())],
            )
            .await?;
        assert_eq!(response.status, status);
    }
    let mut huge = bytes.clone();
    huge.resize(20 * 1024 * 1024 + 1, 0);
    assert_eq!(
        h.app
            .raw_request(
                "PUT",
                &path,
                huge,
                "image/jpeg",
                Some(&h.token),
                &[("x-jiabu-join-epoch", "1".into())]
            )
            .await?
            .status,
        StatusCode::PAYLOAD_TOO_LARGE
    );
    // Content-Type is not a substitute for infer's byte sniffing.
    assert_eq!(
        h.app
            .raw_request(
                "PUT",
                &path,
                bytes,
                "image/png",
                Some(&h.token),
                &[("x-jiabu-join-epoch", "1".into())]
            )
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    let mut bomb = jpeg(8, 8);
    let pos = bomb.windows(2).position(|v| v == [0xff, 0xc0]).unwrap();
    bomb[pos + 5..pos + 7].copy_from_slice(&5000_u16.to_be_bytes());
    bomb[pos + 7..pos + 9].copy_from_slice(&6000_u16.to_be_bytes());
    assert_eq!(
        h.upload(h.space, "chat", bomb, &h.token, 1).await?.status,
        StatusCode::PAYLOAD_TOO_LARGE
    );
    Ok(())
}
#[tokio::test]
async fn blob_configured_limits_and_concurrency_bound_buffered_work() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20), async {
        let limits = ImageLimits {
            max_upload_bytes: 2048,
            max_pixels: 100,
            max_dimension: 20,
            max_decode_bytes: 1024 * 1024,
            concurrency: 2,
            ..ImageLimits::default()
        };
        let h = S4App::with_limits(limits).await?;
        let first = h.state.image_work.clone().acquire_owned().await?;
        let second = h.state.image_work.clone().acquire_owned().await?;
        let mut upload = Box::pin(h.upload(h.space, "chat", jpeg(8, 8), &h.token, 1));
        // Poll until preflight is done and both permits are still held. A task
        // signal from a pending future is unnecessary: the explicit permit
        // count is the semaphore barrier; no wall-clock sleep is used.
        assert_eq!(h.state.image_work.available_permits(), 0);
        std::future::poll_fn(|cx| {
            assert!(upload.as_mut().poll(cx).is_pending());
            Poll::Ready(())
        })
        .await;
        drop(first);
        assert_eq!(upload.await?.status, StatusCode::NO_CONTENT);
        drop(second);
        assert_eq!(
            h.upload(h.space, "chat", jpeg(11, 10), &h.token, 1)
                .await?
                .status,
            StatusCode::PAYLOAD_TOO_LARGE
        );
        assert_eq!(
            h.upload(h.space, "chat", jpeg(21, 1), &h.token, 1)
                .await?
                .status,
            StatusCode::PAYLOAD_TOO_LARGE
        );
        let mut too_large = jpeg(8, 8);
        too_large.resize(2049, 0);
        assert_eq!(
            h.upload(h.space, "chat", too_large, &h.token, 1)
                .await?
                .status,
            StatusCode::PAYLOAD_TOO_LARGE
        );
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}
#[tokio::test]
async fn blob_finish_rechecks_epoch_and_grants_after_processing_barrier() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20),async {
        let mut h=S4App::new().await?;let space=h.new_space().await?;let guest=h.actor("guest",space).await?;
        let image=jpeg(10,8);let sha=hash(&image);
        // The global file already exists: the final check cannot be skipped for dedup.
        h.upload(h.space,"ledger",image.clone(),&h.token,1).await?;
        for change_epoch in [true,false] {
            let entered=Arc::new(Notify::new());let release=Arc::new(Notify::new());
            h.state.upload_gate=Some((entered.clone(),release.clone()));h.app.router=crate::router(h.state.clone());
            let router=h.app.router.clone();let token=guest.token.clone();let bytes=image.clone();
            let epoch=if change_epoch {1} else {2};
            let pending=tokio::spawn(async move {
                let request=Request::builder().method("PUT").uri(format!("/v1/spaces/{space}/blobs/{sha}?module=ledger")).header("authorization",format!("Bearer {token}")).header("x-jiabu-join-epoch",epoch.to_string()).body(Body::from(bytes))?;
                Ok::<_,anyhow::Error>(router.oneshot(request).await?)
            });
            entered.notified().await;
            if change_epoch {
                let tx=SpaceTx::begin(&h.state.db,guest.user,&[(SpaceId(space),None)],Mode::Write).await?;
                tx.apply_change(SpaceId(space),Change::Leave,Uuid::now_v7()).await?;tx.commit().await?;
                assert_eq!(h.join(guest.user,&guest.username,space).await?,guest.member);
            } else {
                let owner=h.app.fixture.owner().await?;
                sqlx::query("update space_member_grants set level='read' where member_id=$1 and module='ledger'").bind(guest.member).execute(&owner).await?;owner.close().await;
            }
            release.notify_one();let response=pending.await??;
            assert_eq!(response.status(),if change_epoch { StatusCode::CONFLICT } else { StatusCode::NOT_FOUND });
            let problem:Value=serde_json::from_slice(&to_bytes(response.into_body(),4096).await?)?;
            assert_eq!(problem["code"],if change_epoch {"membership_changed"} else {"not_found"});
        }
        Ok::<_,anyhow::Error>(())
    }).await??;
    Ok(())
}

#[tokio::test]
async fn pdf_finish_rechecks_epoch_after_processing_barrier() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20), async {
        let mut h = S4App::new().await?;
        let space = h.new_space().await?;
        let guest = h.actor("pdf-race-guest", space).await?;
        let bytes = fake_pdf();
        let sha = hash(&bytes);
        let entered = Arc::new(Notify::new());
        let release = Arc::new(Notify::new());
        h.state.upload_gate = Some((entered.clone(), release.clone()));
        h.app.router = crate::router(h.state.clone());
        let router = h.app.router.clone();
        let token = guest.token.clone();
        let pending = tokio::spawn(async move {
            let request = Request::builder()
                .method("PUT")
                .uri(format!("/v1/spaces/{space}/files/{sha}"))
                .header("authorization", format!("Bearer {token}"))
                .header("content-type", "application/pdf")
                .header("x-jiabu-join-epoch", "1")
                .body(Body::from(bytes))?;
            Ok::<_, anyhow::Error>(router.oneshot(request).await?)
        });
        entered.notified().await;
        let tx = SpaceTx::begin(
            &h.state.db,
            guest.user,
            &[(SpaceId(space), None)],
            Mode::Write,
        )
        .await?;
        tx.apply_change(SpaceId(space), Change::Leave, Uuid::now_v7())
            .await?;
        tx.commit().await?;
        assert_eq!(
            h.join(guest.user, &guest.username, space).await?,
            guest.member
        );
        release.notify_one();
        let response = pending.await??;
        assert_eq!(response.status(), StatusCode::CONFLICT);
        let problem: Value = serde_json::from_slice(&to_bytes(response.into_body(), 4096).await?)?;
        assert_eq!(problem["code"], "membership_changed");
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}

#[tokio::test]
async fn record_attachment_requires_blob_upload_before_tool_and_rejected_op_can_retry() -> Result<()>
{
    let h = S4App::new().await?;
    let (real, purpose) = h.accounts(h.space).await?;
    let image = jpeg(12, 8);
    let sha = hash(&image);
    let call = op(
        h.space,
        "create_record",
        json!({"kind":"expense","amount_minor":10,"occurred_on":"2026-10-01","account_id":real,"purpose_id":purpose,"attachments":[sha.to_string()]}),
    );
    let missing = h.push(vec![call.clone()], &h.token).await?;
    assert_eq!(missing["results"][0]["status"], "rejected");
    assert_eq!(missing["results"][0]["problem"]["code"], "blob_missing");
    assert_eq!(
        h.upload(h.space, "ledger", image, &h.token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    let retry = h.push(vec![call], &h.token).await?;
    assert_eq!(retry["results"][0]["status"], "ok");
    assert_eq!(retry["results"][0]["result"]["version"], 1);
    Ok(())
}
fn padded_jpeg(target: usize) -> Vec<u8> {
    let bytes = jpeg(12, 8);
    // Keep the encoder's APP0 prefix, insert standards-compliant COM segments.
    // This exercises large uploads without creating a large decompressed image.
    assert_eq!(&bytes[2..4], &[0xff, 0xe0]);
    let at = 4 + usize::from(u16::from_be_bytes([bytes[4], bytes[5]]));
    let mut out = bytes[..at].to_vec();
    let mut remaining = target - bytes.len();
    while remaining > 0 {
        let mut size = remaining.min(65537);
        if (1..=3).contains(&(remaining - size)) {
            size -= 4;
        }
        assert!(size >= 4);
        out.extend_from_slice(&[0xff, 0xfe]);
        out.extend_from_slice(&((size - 2) as u16).to_be_bytes());
        out.resize(out.len() + size - 4, 0);
        remaining -= size;
    }
    out.extend_from_slice(&bytes[at..]);
    assert_eq!(out.len(), target);
    out
}
#[tokio::test]
async fn blob_body_limit_overrides_json_limit_and_accepts_exact_twenty_mib() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20), async {
        let h = S4App::new().await?;
        for size in [2 * 1024 * 1024 + 1, 20 * 1024 * 1024] {
            let bytes = padded_jpeg(size);
            assert_eq!(
                h.upload(h.space, "ledger", bytes.clone(), &h.token, 1)
                    .await?
                    .status,
                StatusCode::NO_CONTENT
            );
            let downloaded = h.get(h.space, hash(&bytes), "original", &h.token).await?;
            assert_eq!(downloaded.bytes, bytes);
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}
#[tokio::test]
async fn blob_path_and_query_rejections_use_problem_json() -> Result<()> {
    let h = S4App::new().await?;
    let image = jpeg(12, 8);
    let sha = hash(&image);
    h.upload(h.space, "chat", image.clone(), &h.token, 1)
        .await?;
    for (method, path) in [
        (
            "GET",
            format!(
                "/v1/spaces/{}/blobs/{sha}?variant=thumb&unknown=true",
                h.space
            ),
        ),
        (
            "GET",
            format!("/v1/spaces/not-a-uuid/blobs/{sha}?variant=thumb"),
        ),
        (
            "PUT",
            format!("/v1/spaces/{}/blobs/{sha}?module=invalid", h.space),
        ),
    ] {
        let response = h
            .app
            .raw_request(
                method,
                &path,
                image.clone(),
                "image/jpeg",
                Some(&h.token),
                &[("x-jiabu-join-epoch", "1".into())],
            )
            .await?;
        assert_eq!(response.status, StatusCode::BAD_REQUEST);
        assert_eq!(response.json()["code"], "bad_request");
        assert_eq!(response.headers["content-type"], "application/problem+json");
    }
    Ok(())
}

// Independent TIFF fixture: orientation, a non-location description, and a real
// GPS directory with fake latitude data. No real photo or location is used.
fn jpeg_with_gps(bytes: &[u8], orientation: u16) -> Vec<u8> {
    let mut tiff = b"II\x2a\0\x08\0\0\0".to_vec();
    tiff.extend_from_slice(&3_u16.to_le_bytes());
    for (tag, kind, count, value) in [
        (0x010e_u16, 2_u16, 7_u32, 50_u32),
        (0x0112, 3, 1, u32::from(orientation)),
        (0x8825, 4, 1, 58),
    ] {
        tiff.extend_from_slice(&tag.to_le_bytes());
        tiff.extend_from_slice(&kind.to_le_bytes());
        tiff.extend_from_slice(&count.to_le_bytes());
        tiff.extend_from_slice(&value.to_le_bytes());
    }
    tiff.extend_from_slice(&0_u32.to_le_bytes());
    tiff.extend_from_slice(b"sample\0\0");
    tiff.extend_from_slice(&2_u16.to_le_bytes());
    for (tag, kind, count, value) in [(1_u16, 2_u16, 2_u32, 78_u32), (2, 5, 3, 88)] {
        tiff.extend_from_slice(&tag.to_le_bytes());
        tiff.extend_from_slice(&kind.to_le_bytes());
        tiff.extend_from_slice(&count.to_le_bytes());
        tiff.extend_from_slice(&value.to_le_bytes());
    }
    tiff.extend_from_slice(&0_u32.to_le_bytes());
    for value in [1_u32, 1, 2, 1, 3, 1] {
        tiff.extend_from_slice(&value.to_le_bytes());
    }
    let mut out = bytes[..2].to_vec();
    out.extend_from_slice(&[0xff, 0xe1]);
    out.extend_from_slice(&((tiff.len() + 8) as u16).to_be_bytes());
    out.extend_from_slice(b"Exif\0\0");
    out.extend(tiff);
    out.extend_from_slice(&bytes[2..]);
    out
}
#[tokio::test]
async fn uploaded_original_strips_gps_preserves_orientation_pixels_and_upload_hash() -> Result<()> {
    let h = S4App::new().await?;
    let plain = jpeg(31, 17);
    let bytes = jpeg_with_gps(&plain, 6);
    let sha = hash(&bytes);
    let source = exif::Reader::new().read_from_container(&mut std::io::Cursor::new(&bytes))?;
    assert!(
        source
            .fields()
            .any(|field| field.tag.context() == exif::Context::Gps)
    );
    assert_eq!(
        h.upload(h.space, "chat", bytes.clone(), &h.token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    let response = h.get(h.space, sha, "original", &h.token).await?;
    assert_eq!(response.status, StatusCode::OK);
    let stored =
        exif::Reader::new().read_from_container(&mut std::io::Cursor::new(&response.bytes))?;
    assert!(
        stored
            .fields()
            .all(|field| field.tag.context() != exif::Context::Gps && field.tag.number() != 0x8825)
    );
    assert_eq!(
        stored
            .get_field(exif::Tag::Orientation, exif::In::PRIMARY)
            .unwrap()
            .value
            .get_uint(0),
        Some(6)
    );
    let description = &stored
        .get_field(exif::Tag::ImageDescription, exif::In::PRIMARY)
        .unwrap()
        .value;
    assert!(
        matches!(description,exif::Value::Ascii(values) if values.len()==1 && values[0].as_slice()==b"sample")
    );
    assert_eq!(
        image::load_from_memory(&response.bytes)?.to_rgb8(),
        image::load_from_memory(&bytes)?.to_rgb8()
    );
    assert_ne!(hash(&response.bytes), sha);
    let tiff = &response.bytes[12..];
    let root = u32::from_le_bytes(tiff[4..8].try_into()?) as usize;
    let count = usize::from(u16::from_le_bytes(tiff[root..root + 2].try_into()?));
    for entry in tiff[root + 2..root + 2 + count * 12].as_chunks::<12>().0 {
        assert_ne!(u16::from_le_bytes(entry[..2].try_into()?), 0x8825);
    }
    assert_eq!(
        h.upload(h.space, "chat", bytes, &h.token, 1).await?.status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        h.get(h.space, sha, "original", &h.token).await?.bytes,
        response.bytes
    );
    assert_eq!(
        h.upload(h.space, "chat", plain.clone(), &h.token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        h.get(h.space, hash(&plain), "original", &h.token)
            .await?
            .bytes,
        plain
    );
    Ok(())
}
#[tokio::test]
async fn malformed_exif_upload_succeeds_but_readable_invalid_orientation_returns_422() -> Result<()>
{
    let h = S4App::new().await?;
    let plain = jpeg(31, 17);
    let mut broken = jpeg_with_gps(&plain, 6);
    broken[12..14].copy_from_slice(b"XX");
    let sha = hash(&broken);
    assert_eq!(
        h.upload(h.space, "chat", broken, &h.token, 1).await?.status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        h.get(h.space, sha, "original", &h.token).await?.bytes,
        plain
    );
    assert_eq!(
        h.upload(h.space, "chat", jpeg_with_gps(&plain, 9), &h.token, 1)
            .await?
            .status,
        StatusCode::UNPROCESSABLE_ENTITY
    );
    Ok(())
}

#[tokio::test]
async fn two_slow_upload_bodies_leave_both_processing_permits_available() -> Result<()> {
    let h = S4App::new().await?;
    let bytes = padded_jpeg(5 * 1024 * 1024);
    let mut releases = Vec::new();
    let mut requests = Vec::new();
    for _ in 0..2 {
        let (release, wait) = tokio::sync::oneshot::channel::<()>();
        let entered = Arc::new(Notify::new());
        let reading = entered.clone();
        let content = bytes.clone();
        let sha = hash(&content);
        let body = Body::from_stream(futures_util::stream::once(async move {
            reading.notify_one();
            wait.await.map_err(std::io::Error::other)?;
            Ok::<_, std::io::Error>(axum::body::Bytes::from(content))
        }));
        let request = Request::builder()
            .method("PUT")
            .uri(format!("/v1/spaces/{}/blobs/{sha}?module=chat", h.space))
            .header("authorization", format!("Bearer {}", h.token))
            .header("x-jiabu-join-epoch", "1")
            .body(body)?;
        let router = h.app.router.clone();
        requests.push(tokio::spawn(async move { router.oneshot(request).await }));
        releases.push(release);
        tokio::time::timeout(Duration::from_secs(20), entered.notified()).await?;
    }
    assert_eq!(
        h.state.image_work.available_permits(),
        2,
        "network reads occupied CPU permits"
    );
    // Freeze only after PostgreSQL preflight and the body-read barriers.
    // Virtual time proves the mounted route survives the old 30s deadline
    // without a real delay or auto-advancing while waiting for database IO.
    tokio::time::pause();
    tokio::time::advance(Duration::from_secs(45)).await;
    tokio::task::yield_now().await;
    tokio::time::resume();
    assert!(
        requests.iter().all(|request| !request.is_finished()),
        "slow body hit the global deadline"
    );
    // Do not keep a wall-time guard armed during the explicit virtual advance.
    tokio::time::timeout(Duration::from_secs(20), async {
        assert_eq!(
            h.upload(h.space, "chat", jpeg(12, 8), &h.token, 1)
                .await?
                .status,
            StatusCode::NO_CONTENT
        );
        for release in releases {
            release
                .send(())
                .map_err(|_| anyhow::anyhow!("upload stopped early"))?;
        }
        for request in requests {
            assert_eq!(request.await??.status(), StatusCode::NO_CONTENT);
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}

#[tokio::test]
async fn upload_slots_bound_buffered_queue_and_reject_before_body_read() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20), async {
        use std::sync::atomic::{AtomicUsize, Ordering};
        let limits = ImageLimits {
            max_in_flight_uploads: 2,
            ..ImageLimits::default()
        };
        let h = S4App::with_limits(limits).await?;
        let other = h.new_space().await?;
        let first_cpu = h.state.image_work.clone().acquire_owned().await?;
        let second_cpu = h.state.image_work.clone().acquire_owned().await?;
        let bytes = jpeg(17, 11);
        let mut requests = Vec::new();
        for _ in 0..2 {
            let entered = Arc::new(Notify::new());
            let reading = entered.clone();
            let content = bytes.clone();
            let body = Body::from_stream(futures_util::stream::once(async move {
                reading.notify_one();
                Ok::<_, std::io::Error>(axum::body::Bytes::from(content))
            }));
            let request = Request::builder()
                .method("PUT")
                .uri(format!(
                    "/v1/spaces/{}/blobs/{}?module=chat",
                    h.space,
                    hash(&bytes)
                ))
                .header("authorization", format!("Bearer {}", h.token))
                .header("x-jiabu-join-epoch", "1")
                .body(body)?;
            let router = h.app.router.clone();
            requests.push(tokio::spawn(async move { router.oneshot(request).await }));
            entered.notified().await;
        }
        assert_eq!(h.state.upload_slots.available_permits(), 0);
        let reads = Arc::new(AtomicUsize::new(0));
        let observed = reads.clone();
        let content = bytes.clone();
        let body = Body::from_stream(futures_util::stream::once(async move {
            observed.fetch_add(1, Ordering::SeqCst);
            Ok::<_, std::io::Error>(axum::body::Bytes::from(content))
        }));
        // The bound is global, including across spaces and while CPU work queues.
        let request = Request::builder()
            .method("PUT")
            .uri(format!(
                "/v1/spaces/{other}/blobs/{}?module=chat",
                hash(&bytes)
            ))
            .header("authorization", format!("Bearer {}", h.token))
            .header("x-jiabu-join-epoch", "1")
            .body(body)?;
        let response = h.app.router.clone().oneshot(request).await?;
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(response.headers()["retry-after"], "1");
        assert_eq!(
            response.headers()["content-type"],
            "application/problem+json"
        );
        let problem: Value = serde_json::from_slice(&to_bytes(response.into_body(), 4096).await?)?;
        assert_eq!(problem["code"], "upload_busy");
        assert_eq!(reads.load(Ordering::SeqCst), 0);
        drop(first_cpu);
        drop(second_cpu);
        for request in requests {
            assert_eq!(request.await??.status(), StatusCode::NO_CONTENT);
        }
        assert_eq!(h.state.upload_slots.available_permits(), 2);
        assert_eq!(
            h.upload(h.space, "chat", b"not JPEG".to_vec(), &h.token, 1)
                .await?
                .status,
            StatusCode::UNSUPPORTED_MEDIA_TYPE
        );
        assert_eq!(h.state.upload_slots.available_permits(), 2);
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}

#[tokio::test]
async fn full_upload_slots_keep_unavailable_spaces_byte_identical_for_all_callers() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    let a = h.app.fixture.seed("foreign", "unused").await?;
    let b = h.app.fixture.seed("another", "unused").await?;
    let exited = h.new_space().await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::query(
        "update space_members set status='left',left_reason='left',left_at=now() where space_id=$1",
    )
    .bind(exited)
    .execute(&owner)
    .await?;
    let _slots = h
        .state
        .upload_slots
        .clone()
        .acquire_many_owned(h.state.image_limits.max_in_flight_uploads as u32)
        .await?;
    let bytes = jpeg(17, 11);
    for (index, caller) in h.key_callers().await?.into_iter().enumerate() {
        let mut previous: Option<Reply> = None;
        for space in [a.space_id.0, exited, b.space_id.0, Uuid::now_v7()] {
            let response = h.upload(space, "ledger", bytes.clone(), &caller, 1).await?;
            assert_eq!(response.status, StatusCode::NOT_FOUND);
            if let Some(old) = &previous {
                assert_eq!(response.bytes, old.bytes);
                assert_eq!(response.headers, old.headers);
            }
            previous = Some(response);
        }
        let active = h.upload(h.space, "chat", bytes.clone(), &caller, 1).await?;
        if index == 1 {
            assert_eq!(active.status, StatusCode::FORBIDDEN);
            assert_eq!(active.json()["code"], "api_key_read_only");
        } else {
            assert_eq!(active.status, StatusCode::SERVICE_UNAVAILABLE);
            assert_eq!(active.json()["code"], "upload_busy");
            assert_eq!(active.headers["retry-after"], "1");
        }
    }
    owner.close().await;
    Ok(())
}
