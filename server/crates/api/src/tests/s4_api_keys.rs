//! S4/S5 integration through the mounted HTTP routes and real PostgreSQL.
use super::{s4::*, *};
use jiabu_domain::{SpaceId, spaces::Change};

async fn audits(owner: &sqlx::PgPool, id: Uuid) -> Result<Vec<Value>> {
    Ok(sqlx::query_scalar(
        "select to_jsonb(a) from api_key_audit a where api_key_id=$1 order by id",
    )
    .bind(id)
    .fetch_all(owner)
    .await?)
}
fn statuses(reply: &Value) -> Vec<&str> {
    reply["results"]
        .as_array()
        .unwrap()
        .iter()
        .map(|row| row["status"].as_str().unwrap())
        .collect()
}

#[tokio::test]
async fn read_write_key_sync_blobs_and_replay_have_exactly_one_audit_per_operation() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    let (id, token) = api_keys::issue(&h.app, &h.token, "read_write").await?;
    let tag = Uuid::now_v7();
    let ops = vec![
        op(
            h.space,
            "create_tag",
            json!({"id":tag,"name":"示例 key 新增"}),
        ),
        op(
            h.space,
            "rename_tag",
            json!({"id":tag,"expected_version":1,"name":"示例 key 改名"}),
        ),
    ];
    let first = h.push(ops.clone(), &token).await?;
    assert_eq!(statuses(&first), ["ok", "ok"]);
    let replay = h.push(vec![ops[0].clone()], &token).await?;
    assert_eq!(replay["results"][0], first["results"][0]);
    let page = h.pull(h.space, 0, 500, &token).await?;
    let events = page["spaces"][0]["changes"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|row| row["entity"] == "entity_event")
        .collect::<Vec<_>>();
    assert_eq!(events.len(), 2);
    for row in events {
        assert_eq!(row["data"]["via_api_key_id"], json!(id));
        assert_eq!(row["data"]["via_api_key_name"], "示例脚本");
    }
    let bytes = jpeg(17, 11);
    assert_eq!(
        h.upload(h.space, "ledger", bytes.clone(), &token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    let download = h.get(h.space, hash(&bytes), "original", &token).await?;
    assert_eq!(download.status, StatusCode::OK);
    assert_eq!(download.bytes, bytes);
    let owner = h.app.fixture.owner().await?;
    let rows = audits(&owner, id).await?;
    assert_eq!(rows.len(), 6);
    let operations = rows
        .iter()
        .map(|row| row["operation"].as_str().unwrap())
        .collect::<Vec<_>>();
    assert_eq!(
        operations,
        [
            "push:create_tag",
            "push:rename_tag",
            "push:create_tag",
            "POST:/v1/sync/pull",
            "PUT:/v1/spaces/{space_id}/blobs/{sha256}",
            "GET:/v1/spaces/{space_id}/blobs/{sha256}"
        ]
    );
    assert!(rows.iter().all(|row| row["outcome"] == "ok"));
    assert_eq!(rows[0]["request_id"], ops[0]["request_id"]);
    assert_eq!(rows[1]["request_id"], ops[1]["request_id"]);
    assert_eq!(rows[2]["request_id"], ops[0]["request_id"]);
    assert_eq!(rows[0]["idempotency_key"], ops[0]["op_id"]);
    assert_eq!(rows[1]["idempotency_key"], ops[1]["op_id"]);
    for (row, effect) in rows.iter().zip([
        "local_write",
        "local_write",
        "local_write",
        "read",
        "local_write",
        "read",
    ]) {
        assert_eq!(row["effect"], effect);
    }
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from entity_events where space_id=$1")
            .bind(h.space)
            .fetch_one(&owner)
            .await?,
        2
    );
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn readonly_key_push_checks_every_mixed_item_before_replay_or_tool_filtering() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    let (id, token) = api_keys::issue(&h.app, &h.token, "read").await?;
    let a = Uuid::now_v7();
    let b = Uuid::now_v7();
    let writes = vec![
        op(h.space, "create_tag", json!({"id":a,"name":"示例只读 A"})),
        op(h.space, "create_tag", json!({"id":b,"name":"示例只读 B"})),
    ];
    let denied = h.push(writes.clone(), &token).await?;
    for row in denied["results"].as_array().unwrap() {
        assert_eq!(row["status"], "rejected");
        assert_eq!(row["problem"]["code"], "api_key_read_only");
    }
    let owner = h.app.fixture.owner().await?;
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from tags where id in ($1,$2)")
            .bind(a)
            .bind(b)
            .fetch_one(&owner)
            .await?,
        0
    );
    assert_eq!(
        statuses(&h.push(writes.clone(), &h.token).await?),
        ["ok", "ok"]
    );
    let replay = h.push(writes, &token).await?;
    assert!(replay["results"].as_array().unwrap().iter().all(|row| row["problem"]["code"] == "api_key_read_only" && row.get("result").is_none()));
    // The first item is a read tool, so checking scope only once per batch or
    // relying on invoke's write guard cannot protect later non-syncable items.
    let mixed = h
        .push(
            vec![
                op(h.space, "list_tags", json!({})),
                op(
                    Uuid::now_v7(),
                    "create_tag",
                    json!({"name":"示例不可达空间"}),
                ),
                op(h.space, "ask_user", json!({})),
                op(h.space, "create_tag", json!({"name":"示例禁止写入"})),
                op(
                    h.space,
                    "rename_tag",
                    json!({"id":a,"expected_version":1,"name":"示例禁止改名"}),
                ),
            ],
            &token,
        )
        .await?;
    assert_eq!(
        statuses(&mixed),
        [
            "rejected",
            "space_unavailable",
            "rejected",
            "rejected",
            "rejected"
        ]
    );
    for (index, row) in mixed["results"].as_array().unwrap().iter().enumerate() {
        if index == 1 {
            assert!(row.get("problem").is_none());
        } else {
            assert_eq!(row["problem"]["status"], 403);
            assert_eq!(row["problem"]["code"], "api_key_read_only");
        }
    }
    let bytes = jpeg(17, 11);
    h.upload(h.space, "ledger", bytes.clone(), &h.token, 1)
        .await?;
    assert_eq!(
        h.pull(h.space, 0, 500, &token).await?["spaces"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert_eq!(
        h.get(h.space, hash(&bytes), "original", &token)
            .await?
            .bytes,
        bytes
    );
    for module in ["ledger", "documents", "chat"] {
        let denied = h.upload(h.space, module, bytes.clone(), &token, 1).await?;
        assert_eq!(denied.status, StatusCode::FORBIDDEN);
        assert_eq!(denied.json()["code"], "api_key_read_only");
    }
    let rows = audits(&owner, id).await?;
    assert_eq!(rows.len(), 14);
    assert_eq!(
        rows.iter()
            .filter(|row| row["outcome"] == "not_found")
            .count(),
        1
    );
    assert_eq!(
        rows.iter()
            .filter(|row| row["outcome"] == "api_key_read_only")
            .count(),
        11
    );
    assert_eq!(
        rows.iter()
            .filter(|row| row["outcome"] == "ok" && row["effect"] == "read")
            .count(),
        2
    );
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from entity_events where space_id=$1")
            .bind(h.space)
            .fetch_one(&owner)
            .await?,
        2
    );
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn key_push_finishes_early_errors_rollback_and_unprocessed_items_without_duplicate_audit()
-> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    let (id, token) = api_keys::issue(&h.app, &h.token, "read_write").await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::raw_sql("create function s4_key_fail() returns trigger language plpgsql as $$ begin if NEW.name='示例故障' then raise exception 'private failure'; end if; return NEW; end $$; create trigger s4_key_fail before insert on tags for each row execute function s4_key_fail();").execute(&owner).await?;
    let tag = Uuid::now_v7();
    let reply = h
        .push(
            vec![
                op(h.space, "create_tag", json!({"id":tag,"name":"示例成功"})),
                op(h.space, "list_tags", json!({})),
                op(Uuid::now_v7(), "create_tag", json!({"name":"示例不可达"})),
                json!({"op_id":token,"space_id":token,"tool":token}),
                op(h.space, "create_tag", json!({"unexpected":true})),
                op(
                    h.space,
                    "rename_tag",
                    json!({"id":tag,"expected_version":999,"name":"示例冲突"}),
                ),
                op(h.space, "create_tag", json!({"name":"示例故障"})),
                op(h.space, "create_tag", json!({"name":"示例不执行"})),
            ],
            &token,
        )
        .await?;
    assert_eq!(
        statuses(&reply),
        [
            "ok",
            "rejected",
            "space_unavailable",
            "rejected",
            "rejected",
            "conflict",
            "not_processed",
            "not_processed"
        ]
    );
    assert!(reply["results"][3]["op_id"].is_null());
    assert!(!reply.to_string().contains(&token));
    assert!(!reply.to_string().contains("private failure"));
    let rows = audits(&owner, id).await?;
    assert_eq!(rows.len(), 8);
    assert_eq!(
        rows.iter()
            .map(|row| row["outcome"].as_str().unwrap())
            .collect::<Vec<_>>(),
        [
            "ok",
            "tool_not_syncable",
            "not_found",
            "validation_failed",
            "validation_failed",
            "version_conflict",
            "internal",
            "not_processed"
        ]
    );
    assert_eq!(rows[3]["operation"], "push:unknown");
    assert!(rows[3]["space_id"].is_null());
    assert!(rows[3]["idempotency_key"].is_null());
    assert_ne!(rows[0]["request_id"], rows[1]["request_id"]);
    assert!(!serde_json::to_string(&rows)?.contains(&token));
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from entity_events where space_id=$1")
            .bind(h.space)
            .fetch_one(&owner)
            .await?,
        1
    );
    assert_eq!(h.push(vec![], &token).await?, json!({"results":[]}));
    assert_eq!(audits(&owner, id).await?.len(), 8);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn key_push_debits_n_tokens_and_returns_per_item_429_without_audit() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(2, 3)?;
    let bytes = jpeg(17, 11);
    h.upload(h.space, "chat", bytes.clone(), &h.token, 1)
        .await?;
    let (id, token) = api_keys::issue(&h.app, &h.token, "read_write").await?;
    let writes = (0..3)
        .map(|index| {
            op(
                h.space,
                "create_tag",
                json!({"name":format!("示例 N 次 {index}")}),
            )
        })
        .collect();
    assert_eq!(statuses(&h.push(writes, &token).await?), ["ok", "ok", "ok"]);
    let blocked = h
        .app
        .request(
            "POST",
            "/v1/sync/push",
            json!({"ops":[op(h.space,"list_tags",json!({}))]}),
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(blocked.status, StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(blocked.headers["retry-after"], "20");
    let limited = h.upload(h.space, "chat", bytes.clone(), &token, 1).await?;
    assert_eq!(limited.status, StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(limited.headers["retry-after"], "20");
    // Pull POST must use the independent read bucket, just like a GET download.
    assert_eq!(
        h.get(h.space, hash(&bytes), "original", &token)
            .await?
            .status,
        StatusCode::OK
    );
    assert_eq!(
        h.pull(h.space, 0, 1, &token).await?["spaces"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    let limited = h
        .app
        .request(
            "POST",
            "/v1/sync/pull",
            json!({"spaces":{}}),
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(limited.status, StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(limited.headers["retry-after"], "30");
    let owner = h.app.fixture.owner().await?;
    assert_eq!(audits(&owner, id).await?.len(), 5);
    let (overflow_id, overflow) = api_keys::issue(&h.app, &h.token, "read_write").await?;
    let reply = h
        .push(
            vec![
                op(h.space, "create_tag", json!({"name":"示例超额首条"})),
                op(h.space, "list_tags", json!({})),
                op(
                    Uuid::now_v7(),
                    "create_tag",
                    json!({"name":"示例不存在空间"}),
                ),
                json!({}),
                op(h.space, "create_tag", json!({"name":"示例超额末条"})),
            ],
            &overflow,
        )
        .await?;
    assert_eq!(
        statuses(&reply),
        [
            "ok",
            "rejected",
            "space_unavailable",
            "rejected",
            "rejected"
        ]
    );
    for index in [3, 4] {
        assert_eq!(reply["results"][index]["problem"]["status"], 429);
        assert_eq!(reply["results"][index]["problem"]["code"], "rate_limited");
        assert_eq!(reply["results"][index]["problem"]["retry_after"], 20);
    }
    let rows = audits(&owner, overflow_id).await?;
    assert_eq!(rows.len(), 3);
    assert!(rows.iter().all(|row| row["outcome"] != "rate_limited"));
    let (empty_id, empty) = api_keys::issue(&h.app, &h.token, "read_write").await?;
    h.push(vec![], &empty).await?;
    assert!(audits(&owner, empty_id).await?.is_empty());
    let after_empty = (0..3)
        .map(|index| {
            op(
                h.space,
                "create_tag",
                json!({"name":format!("示例空批次后 {index}")}),
            )
        })
        .collect();
    assert_eq!(
        statuses(&h.push(after_empty, &empty).await?),
        ["ok", "ok", "rejected"]
    );
    assert_eq!(audits(&owner, empty_id).await?.len(), 2);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn key_push_epoch_binding_rejects_old_and_relabelled_operations_after_rejoin() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    let space = h.new_space().await?;
    let guest = h.actor("guest", space).await?;
    let (id, token) = api_keys::issue(&h.app, &guest.token, "read_write").await?;
    let call = op(
        space,
        "create_tag",
        json!({"id":Uuid::now_v7(),"name":"示例旧世代"}),
    );
    let first = h.push(vec![call.clone()], &token).await?;
    assert_eq!(statuses(&first), ["ok"]);
    assert_eq!(h.push(vec![call.clone()], &guest.token).await?, first);
    let tx = SpaceTx::begin(
        &h.state.db,
        h.app.plan.user_id,
        &[(SpaceId(space), None)],
        Mode::Write,
    )
    .await?;
    tx.apply_change(
        SpaceId(space),
        Change::Remove {
            member: guest.member,
        },
        Uuid::now_v7(),
    )
    .await?;
    tx.commit().await?;
    let left = h.push(vec![call.clone()], &token).await?;
    assert_eq!(statuses(&left), ["space_unavailable"]);
    assert!(left["results"][0].get("result").is_none());
    assert_eq!(
        h.join(guest.user, &guest.username, space).await?,
        guest.member
    );
    let stale = h.push(vec![call.clone()], &token).await?;
    assert_eq!(statuses(&stale), ["membership_changed"]);
    assert!(stale["results"][0].get("result").is_none());
    let mut relabelled = call.clone();
    relabelled["join_epoch"] = json!(2);
    let changed = h.push(vec![relabelled], &token).await?;
    assert_eq!(statuses(&changed), ["membership_changed"]);
    assert!(changed["results"][0].get("result").is_none());
    let mut fresh = op(space, "create_tag", json!({"name":"示例新世代"}));
    fresh["join_epoch"] = json!(2);
    assert_eq!(statuses(&h.push(vec![fresh], &token).await?), ["ok"]);
    let bytes = jpeg(17, 11);
    assert_eq!(
        h.upload(space, "chat", bytes.clone(), &token, 1)
            .await?
            .status,
        StatusCode::CONFLICT
    );
    assert_eq!(
        h.upload(space, "chat", bytes.clone(), &token, 2)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        h.get(space, hash(&bytes), "original", &token).await?.bytes,
        bytes
    );
    let owner = h.app.fixture.owner().await?;
    let epoch: i32 =
        sqlx::query_scalar("select join_epoch from idempotency where user_id=$1 and key=$2")
            .bind(guest.user.0)
            .bind(call["op_id"].as_str().unwrap())
            .fetch_one(&owner)
            .await?;
    assert_eq!(epoch, 1);
    assert_eq!(audits(&owner, id).await?.len(), 8);
    owner.close().await;
    Ok(())
}

#[test]
fn key_sync_blob_openapi_keeps_typed_union_and_retry_after_headers() -> Result<()> {
    let document = serde_json::to_value(crate::openapi())?;
    for (path, method) in [
        ("/v1/sync/push", "post"),
        ("/v1/sync/pull", "post"),
        ("/v1/spaces/{space_id}/blobs/{sha256}", "put"),
        ("/v1/spaces/{space_id}/blobs/{sha256}", "get"),
    ] {
        assert_eq!(
            document["paths"][path][method]["responses"]["429"]["headers"]["Retry-After"]["schema"]
                ["type"],
            "integer"
        );
    }
    assert_eq!(
        document["components"]["schemas"]["PushRequest"]["properties"]["ops"]["items"]["$ref"],
        "#/components/schemas/SyncPushOperation"
    );
    Ok(())
}

#[tokio::test]
async fn key_push_internal_stop_preserves_not_processed_after_later_rate_limit() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(2, 2)?;
    let (id, token) = api_keys::issue(&h.app, &h.token, "read_write").await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::raw_sql("create function s4_key_stop() returns trigger language plpgsql as $$ begin raise exception 'test internal stop'; end $$; create trigger s4_key_stop before insert on tags for each row execute function s4_key_stop();").execute(&owner).await?;
    let reply = h
        .push(
            (0..3)
                .map(|index| {
                    op(
                        h.space,
                        "create_tag",
                        json!({"name":format!("示例停止 {index}")}),
                    )
                })
                .collect(),
            &token,
        )
        .await?;
    assert_eq!(
        statuses(&reply),
        ["not_processed", "not_processed", "not_processed"]
    );
    assert_eq!(reply["results"][0]["problem"]["code"], "internal");
    for index in [1, 2] {
        assert!(reply["results"][index].get("problem").is_none());
    }
    let rows = audits(&owner, id).await?;
    assert_eq!(rows.len(), 2);
    assert_eq!(rows[0]["outcome"], "internal");
    assert_eq!(rows[1]["outcome"], "not_processed");
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from entity_events where space_id=$1")
            .bind(h.space)
            .fetch_one(&owner)
            .await?,
        0
    );
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn push_audits_and_entity_events_keep_item_request_ids_with_http_fallback() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    let (id, token) = api_keys::issue(&h.app, &h.token, "read_write").await?;
    let http_id = Uuid::now_v7();
    let success = op(h.space, "create_tag", json!({"name":"示例条目追踪"}));
    let mut replay = success.clone();
    replay["request_id"] = json!(Uuid::now_v7());
    let unavailable = op(Uuid::now_v7(), "create_tag", json!({"name":"示例条目失败"}));
    let mut malformed = op(h.space, "create_tag", json!({"name":"示例坏请求号"}));
    malformed["request_id"] = json!("invalid");
    let reply = h
        .app
        .request(
            "POST",
            "/v1/sync/push",
            json!({"ops":[success,replay,unavailable,malformed]}),
            Some(&token),
            &[("x-request-id", http_id.to_string())],
        )
        .await?;
    assert_eq!(reply.status, StatusCode::OK);
    assert_eq!(
        statuses(&reply.json()),
        ["ok", "ok", "space_unavailable", "rejected"]
    );
    assert_eq!(
        reply.json()["results"][3]["problem"]["request_id"],
        json!(http_id)
    );
    let owner = h.app.fixture.owner().await?;
    let rows = audits(&owner, id).await?;
    assert_eq!(rows.len(), 4);
    assert_eq!(rows[0]["request_id"], success["request_id"]);
    assert_eq!(rows[1]["request_id"], replay["request_id"]);
    assert_eq!(rows[2]["request_id"], unavailable["request_id"]);
    assert_eq!(rows[3]["request_id"], json!(http_id));
    let event: Uuid = sqlx::query_scalar(
        "select request_id from entity_events where space_id=$1 and via_api_key_id=$2",
    )
    .bind(h.space)
    .bind(id)
    .fetch_one(&owner)
    .await?;
    assert_eq!(json!(event), success["request_id"]);
    owner.close().await;
    Ok(())
}
