use super::{s4::*, *};
use jiabu_domain::{SpaceId, spaces::Change};
use serde_json::Value;

#[tokio::test]
async fn push_commits_each_operation_and_stops_only_on_internal_error() -> Result<()> {
    let h = S4App::new().await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::raw_sql("create function s4_fail_tag() returns trigger language plpgsql as $$ begin if NEW.name='示例故障' then raise exception 'private database detail'; end if; return NEW; end $$; create trigger s4_fail before insert on tags for each row execute function s4_fail_tag();").execute(&owner).await?;
    let ops = vec![
        op(h.space, "create_tag", json!({"name":"示例成功"})),
        op(h.space, "list_tags", json!({})),
        op(h.space, "ask_user", json!({})),
        op(h.space, "create_tag", json!({"name":"示例故障"})),
        op(h.space, "create_tag", json!({"name":"示例未执行"})),
    ];
    let result = h.push(ops.clone(), &h.token).await?;
    let rows = result["results"].as_array().unwrap();
    assert_eq!(
        rows.iter()
            .map(|r| r["status"].as_str().unwrap())
            .collect::<Vec<_>>(),
        [
            "ok",
            "rejected",
            "rejected",
            "not_processed",
            "not_processed"
        ]
    );
    for (index, row) in rows.iter().enumerate() {
        assert_eq!(row["op_id"], ops[index]["op_id"]);
    }
    assert_eq!(rows[1]["problem"]["code"], "tool_not_syncable");
    assert_eq!(rows[2]["problem"]["code"], "tool_not_syncable");
    assert_eq!(
        rows[3]["problem"],
        json!({"code":"internal","request_id":ops[3]["request_id"]})
    );
    assert!(rows[4].get("problem").is_none());
    assert!(!result.to_string().contains("private database detail"));
    let count: i64 =
        sqlx::query_scalar("select count(*) from tags where space_id=$1 and preset_key is null")
            .bind(h.space)
            .fetch_one(&owner)
            .await?;
    assert_eq!(count, 1);
    for index in [3, 4] {
        let saved: i64 =
            sqlx::query_scalar("select count(*) from idempotency where user_id=$1 and key=$2")
                .bind(h.app.plan.user_id.0)
                .bind(ops[index]["op_id"].as_str().unwrap())
                .fetch_one(&owner)
                .await?;
        assert_eq!(saved, 0);
    }
    sqlx::raw_sql("drop trigger s4_fail on tags; drop function s4_fail_tag();")
        .execute(&owner)
        .await?;
    let retried = h.push(ops.clone(), &h.token).await?;
    assert_eq!(retried["results"][0], rows[0]);
    assert_eq!(retried["results"][3]["status"], "ok");
    assert_eq!(retried["results"][4]["status"], "ok");
    let events: i64 = sqlx::query_scalar(
        "select count(*) from entity_events where space_id=$1 and entity_kind='tag'",
    )
    .bind(h.space)
    .fetch_one(&owner)
    .await?;
    assert_eq!(events, 3);
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn push_preserves_input_order_across_spaces_and_dependent_writes() -> Result<()> {
    let h = S4App::new().await?;
    let other = h.new_space().await?;
    let id = Uuid::now_v7();
    let ops = vec![
        op(h.space, "create_tag", json!({"id":id,"name":"示例初名"})),
        op(other, "create_tag", json!({"name":"示例另一空间"})),
        op(
            h.space,
            "rename_tag",
            json!({"id":id,"expected_version":1,"name":"示例改名"}),
        ),
    ];
    let result = h.push(ops.clone(), &h.token).await?;
    for (index, row) in result["results"].as_array().unwrap().iter().enumerate() {
        assert_eq!(row["op_id"], ops[index]["op_id"]);
        assert_eq!(row["status"], "ok");
    }
    let sequences = result["results"]
        .as_array()
        .unwrap()
        .iter()
        .map(|r| r["result"]["change_seq"].as_i64().unwrap())
        .collect::<Vec<_>>();
    assert!(sequences.windows(2).all(|w| w[0] < w[1]));
    assert_eq!(result["results"][2]["result"]["version"], 2);
    Ok(())
}
#[tokio::test]
async fn push_limits_count_and_actual_bytes_before_any_write() -> Result<()> {
    let h = S4App::new().await?;
    for (count, expected) in [(50, StatusCode::OK), (51, StatusCode::PAYLOAD_TOO_LARGE)] {
        let ops = (0..count)
            .map(|_| op(h.space, "list_tags", json!({})))
            .collect::<Vec<_>>();
        let reply = h
            .app
            .request(
                "POST",
                "/v1/sync/push",
                json!({"ops":ops}),
                Some(&h.token),
                &[],
            )
            .await?;
        assert_eq!(reply.status, expected);
    }
    for extra in [0, 1] {
        let mut bytes = br#"{"ops":[]}"#.to_vec();
        bytes.resize(2 * 1024 * 1024 + extra, b' ');
        let reply = h
            .app
            .raw_request(
                "POST",
                "/v1/sync/push",
                bytes,
                "application/json",
                Some(&h.token),
                &[],
            )
            .await?;
        assert_eq!(
            reply.status,
            if extra == 0 {
                StatusCode::OK
            } else {
                StatusCode::PAYLOAD_TOO_LARGE
            }
        );
    }
    let owner = h.app.fixture.owner().await?;
    let count: i64 = sqlx::query_scalar("select count(*) from entity_events")
        .fetch_one(&owner)
        .await?;
    assert_eq!(count, 0);
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn every_modifying_tool_checks_versions_and_void_requires_explicit_restore() -> Result<()> {
    let h = S4App::new().await?;
    let (real, purpose) = h.accounts(h.space).await?;
    let empty = h
        .call(
            h.space,
            "create_account",
            json!({"kind":"real","name":"示例空账户","opening_on":"2026-10-01"}),
        )
        .await?;
    let record=h.call(h.space,"create_record",json!({"kind":"expense","amount_minor":100,"occurred_on":"2026-10-01","account_id":real,"purpose_id":purpose})).await?;
    let tag = h
        .call(h.space, "create_tag", json!({"name":"示例标签"}))
        .await?;
    let plan = h
        .call(
            h.space,
            "set_allocation_plan",
            json!({"account_id":purpose,"amount_minor":100,"day_of_month":1,"enabled":true}),
        )
        .await?;
    let cases = vec![
        (
            "update_record",
            json!({"id":record["id"],"changes":{"amount_minor":200}}),
        ),
        ("void_record", json!({"id":record["id"]})),
        ("restore_record", json!({"id":record["id"]})),
        (
            "update_account",
            json!({"id":empty["id"],"name":"示例新账户名"}),
        ),
        ("archive_account", json!({"id":empty["id"]})),
        ("rename_tag", json!({"id":tag["id"],"name":"示例新标签名"})),
        ("delete_tag", json!({"id":tag["id"]})),
        (
            "set_allocation_plan",
            json!({"account_id":purpose,"amount_minor":200,"day_of_month":2,"enabled":true}),
        ),
    ];
    for (tool, mut args) in cases {
        let missing = h
            .push(vec![op(h.space, tool, args.clone())], &h.token)
            .await?;
        assert_ne!(missing["results"][0]["status"], "ok", "{tool}");
        args["expected_version"] = json!(999);
        let stale = h.push(vec![op(h.space, tool, args)], &h.token).await?;
        assert_eq!(stale["results"][0]["status"], "conflict", "{tool}: {stale}");
        assert_eq!(stale["results"][0]["problem"]["code"], "version_conflict");
        let expected = match tool {
            "update_record" | "void_record" | "restore_record" => &record,
            "update_account" | "archive_account" => &empty,
            "rename_tag" | "delete_tag" => &tag,
            "set_allocation_plan" => &plan,
            _ => unreachable!(),
        };
        assert_eq!(
            &stale["results"][0]["problem"]["current"], expected,
            "{tool}"
        );
        if tool == "set_allocation_plan" {
            assert_eq!(&missing["results"][0]["problem"]["current"], expected);
        }
    }
    let id = record["id"].clone();
    let voided = h
        .call(
            h.space,
            "void_record",
            json!({"id":id,"expected_version":1}),
        )
        .await?;
    let stale = h
        .push(
            vec![op(
                h.space,
                "update_record",
                json!({"id":id,"expected_version":1,"changes":{"amount_minor":200}}),
            )],
            &h.token,
        )
        .await?;
    assert_eq!(stale["results"][0]["problem"]["current"], voided);
    let denied = h
        .push(
            vec![op(
                h.space,
                "update_record",
                json!({"id":id,"expected_version":2,"changes":{"amount_minor":200}}),
            )],
            &h.token,
        )
        .await?;
    assert_eq!(denied["results"][0]["status"], "rejected");
    let balance = h
        .app
        .request(
            "POST",
            &format!("/v1/spaces/{}/tools/query_balance", h.space),
            json!({"account_id":real}),
            Some(&h.token),
            &[],
        )
        .await?
        .json();
    assert_eq!(balance["balances"][0]["balance_minor"], 0);
    let restored = h
        .call(
            h.space,
            "restore_record",
            json!({"id":id,"expected_version":2}),
        )
        .await?;
    let updated = h
        .call(
            h.space,
            "update_record",
            json!({"id":id,"expected_version":restored["version"],"changes":{"amount_minor":200}}),
        )
        .await?;
    assert_eq!(updated["status"], "active");
    assert_eq!(updated["version"], 4);
    let conflict = h
        .push(
            vec![op(
                h.space,
                "update_record",
                json!({"id":id,"expected_version":3,"changes":{"amount_minor":300}}),
            )],
            &h.token,
        )
        .await?;
    assert_eq!(conflict["results"][0]["problem"]["current"], updated);
    // New IDs retry without a version conflict or a second create event.
    let create = op(
        h.space,
        "create_tag",
        json!({"id":Uuid::now_v7(),"name":"示例幂等新增"}),
    );
    let first = h.push(vec![create.clone()], &h.token).await?;
    assert_eq!(h.push(vec![create.clone()], &h.token).await?, first);
    let mut second = create;
    second["op_id"] = json!(Uuid::now_v7());
    assert_eq!(
        h.push(vec![second], &h.token).await?["results"][0]["result"],
        first["results"][0]["result"]
    );
    Ok(())
}
#[tokio::test]
async fn old_op_cannot_replay_after_exit_rejoin_or_grant_revocation() -> Result<()> {
    let h = S4App::new().await?;
    let space = h.new_space().await?;
    let guest = h.actor("guest", space).await?;
    for removed in [false, true] {
        let epoch = if removed { 2 } else { 1 };
        let mut old = op(space, "create_tag", json!({"name":"示例历史标签"}));
        old["join_epoch"] = json!(epoch);
        assert_eq!(
            h.push(vec![old.clone()], &guest.token).await?["results"][0]["status"],
            "ok"
        );
        let tx = SpaceTx::begin(
            &h.state.db,
            if removed {
                h.app.plan.user_id
            } else {
                guest.user
            },
            &[(SpaceId(space), None)],
            Mode::Write,
        )
        .await?;
        tx.apply_change(
            SpaceId(space),
            if removed {
                Change::Remove {
                    member: guest.member,
                }
            } else {
                Change::Leave
            },
            Uuid::now_v7(),
        )
        .await?;
        tx.commit().await?;
        assert_eq!(
            h.push(vec![old.clone()], &guest.token).await?["results"][0]["status"],
            "space_unavailable"
        );
        assert_eq!(
            h.pull(space, 0, 500, &guest.token).await?["unavailable"],
            json!([space])
        );
        assert_eq!(
            h.join(guest.user, &guest.username, space).await?,
            guest.member
        );
        assert_eq!(
            h.push(vec![old], &guest.token).await?["results"][0]["status"],
            "membership_changed"
        );
        let all = h.pull(space, 0, 500, &guest.token).await?;
        assert!(
            all["spaces"][0]["changes"]
                .as_array()
                .unwrap()
                .iter()
                .any(|r| r["entity"] == "tag"
                    && r["data"]["created_by_member_id"] == json!(guest.member))
        );
    }
    let old = op(h.space, "create_tag", json!({"name":"示例授权回放"}));
    h.push(vec![old.clone()], &h.token).await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='ledger'",
    )
    .bind(h.member)
    .execute(&owner)
    .await?;
    let replay = h.push(vec![old], &h.token).await?;
    assert_eq!(replay["results"][0]["status"], "rejected");
    assert_eq!(replay["results"][0]["problem"]["code"], "not_found");
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn sync_isolation_four_unavailable_cases_have_identical_shapes() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    let other = h.app.fixture.seed("foreign", "unused").await?;
    let second = h.app.fixture.seed("second_foreign", "unused").await?;
    let exited = h.new_space().await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::query("update space_members set status='left',left_at=now(),left_reason='left' where space_id=$1 and user_id=$2").bind(exited).bind(h.app.plan.user_id.0).execute(&owner).await?;
    owner.close().await;
    let template = op(other.space_id.0, "create_tag", json!({"name":"示例隔离"}));
    for caller in h.key_callers().await? {
        let mut expected_push = None;
        let mut expected_pull = None;
        for id in [other.space_id.0, exited, second.space_id.0, Uuid::now_v7()] {
            let mut call = template.clone();
            call["space_id"] = json!(id);
            let reply = h
                .app
                .request(
                    "POST",
                    "/v1/sync/push",
                    json!({"ops":[call]}),
                    Some(&caller),
                    &[],
                )
                .await?;
            assert_eq!(reply.json()["results"][0]["status"], "space_unavailable");
            if let Some(expected) = &expected_push {
                assert_eq!(&reply.bytes, expected);
            } else {
                expected_push = Some(reply.bytes);
            }
            let reply = h.pull(id, 0, 2, &caller).await?;
            assert_eq!(reply, json!({"spaces":[],"unavailable":[id]}));
            let bytes = serde_json::to_vec(&reply)?;
            let normalized = String::from_utf8(bytes)?.replace(&id.to_string(), "SPACE");
            if let Some(expected) = &expected_pull {
                assert_eq!(&normalized, expected);
            } else {
                expected_pull = Some(normalized);
            }
        }
        // An authorized space with a missing entity is rejected, not space_unavailable.
        let missing = h
            .push(
                vec![op(
                    h.space,
                    "delete_tag",
                    json!({"id":Uuid::now_v7(),"expected_version":1}),
                )],
                &caller,
            )
            .await?;
        assert_eq!(missing["results"][0]["status"], "rejected");
    }
    Ok(())
}
fn assert_canonical_timestamps(row: &Value) -> Result<()> {
    for key in [
        "created_at",
        "updated_at",
        "archived_at",
        "deleted_at",
        "joined_at",
        "left_at",
        "at",
    ] {
        if let Some(value) = row.get(key).filter(|v| !v.is_null()) {
            let instant: chrono::DateTime<chrono::Utc> = serde_json::from_value(value.clone())?;
            assert_eq!(*value, json!(instant), "noncanonical {key}");
        }
    }
    Ok(())
}
#[tokio::test]
async fn pull_rows_match_tool_results_and_get_record_timestamps() -> Result<()> {
    let h = S4App::new().await?;
    let account = h
        .call(
            h.space,
            "create_account",
            json!({"kind":"real","name":"示例时间账户","opening_on":"2026-10-01"}),
        )
        .await?;
    let record=h.call(h.space,"create_record",json!({"kind":"income","amount_minor":100,"occurred_on":"2026-10-01","account_id":account["id"]})).await?;
    let tag = h
        .call(h.space, "create_tag", json!({"name":"示例时间标签"}))
        .await?;
    let deleted = h
        .call(
            h.space,
            "delete_tag",
            json!({"id":tag["id"],"expected_version":1}),
        )
        .await?;
    let (_, purpose) = h.accounts(h.space).await?;
    let plan = h
        .call(
            h.space,
            "set_allocation_plan",
            json!({"account_id":purpose,"amount_minor":10,"day_of_month":1,"enabled":true}),
        )
        .await?;
    let get = h
        .app
        .request(
            "POST",
            &format!("/v1/spaces/{}/tools/get_record", h.space),
            json!({"id":record["id"]}),
            Some(&h.token),
            &[],
        )
        .await?;
    assert_eq!(get.status, StatusCode::OK);
    let current = get.json();
    assert_eq!(current, record);
    let all = pull_all(&h, h.space, 2, &h.token).await?;
    for (entity, key, expected) in [
        ("account", "id", &account),
        ("record", "id", &current),
        ("tag", "id", &deleted),
        ("allocation_plan", "account_id", &plan),
    ] {
        let pulled = all
            .iter()
            .find(|r| r["entity"] == entity && r["data"][key] == expected[key])
            .unwrap();
        assert_eq!(&pulled["data"], expected, "{entity}");
    }
    for event in all
        .iter()
        .filter(|r| r["entity"] == "entity_event" && r["data"]["entity_id"] == record["id"])
    {
        assert_eq!(event["data"]["after"], current);
    }
    Ok(())
}
async fn pull_all(h: &S4App, space: Uuid, limit: u32, token: &str) -> Result<Vec<Value>> {
    let mut cursor = 0;
    let mut changes = Vec::new();
    for _ in 0..500 {
        let response = h.pull(space, cursor, limit, token).await?;
        let page = &response["spaces"][0];
        let rows = page["changes"].as_array().unwrap();
        if rows.is_empty() {
            assert_eq!(page["cursor"], cursor);
        } else {
            assert!(page["cursor"].as_i64().unwrap() > cursor);
        }
        changes.extend(rows.iter().cloned());
        cursor = page["cursor"].as_i64().unwrap();
        if page["has_more"] == false {
            return Ok(changes);
        }
    }
    anyhow::bail!("pagination did not terminate")
}
#[tokio::test]
async fn pull_all_tables_small_pages_filters_and_tombstones() -> Result<()> {
    let h = S4App::new().await?;
    // Future module/chat tables must also work when currently empty.
    let initial = pull_all(&h, h.space, 1, &h.token).await?;
    assert!(initial.iter().all(|r| !matches!(
        r["entity"].as_str(),
        Some("subject" | "document" | "conversation" | "chat_entry")
    )));
    let space = h.new_space().await?;
    let guest = h.actor("guest", space).await?;
    let (real, purpose) = h.accounts(space).await?;
    h.call(
        space,
        "set_allocation_plan",
        json!({"account_id":purpose,"amount_minor":10,"day_of_month":1,"enabled":true}),
    )
    .await?;
    let tag = h
        .call(space, "create_tag", json!({"name":"示例将删除标签"}))
        .await?;
    h.call(
        space,
        "delete_tag",
        json!({"id":tag["id"],"expected_version":1}),
    )
    .await?;
    let record = h
        .call(
            space,
            "create_record",
            json!({"kind":"income","amount_minor":10,"occurred_on":"2026-10-01","account_id":real}),
        )
        .await?;
    h.call(
        space,
        "void_record",
        json!({"id":record["id"],"expected_version":1}),
    )
    .await?;
    let archived = h
        .call(
            space,
            "create_account",
            json!({"kind":"real","name":"示例已归档账户","opening_on":"2026-10-01"}),
        )
        .await?;
    h.call(
        space,
        "archive_account",
        json!({"id":archived["id"],"expected_version":1}),
    )
    .await?;
    let owner = h.app.fixture.owner().await?;
    let member: Uuid =
        sqlx::query_scalar("select id from space_members where space_id=$1 and user_id=$2")
            .bind(space)
            .bind(h.app.plan.user_id.0)
            .fetch_one(&owner)
            .await?;
    let subject = Uuid::now_v7();
    let document = Uuid::now_v7();
    sqlx::query("insert into subjects(id,space_id,kind,name,created_by_member_id,archived_at,deleted_at,change_seq,created_at,updated_at) values($1,$2,'other','示例已删除对象',$3,now(),now(),nextval('change_seq'),now(),now())").bind(subject).bind(space).bind(member).execute(&owner).await?;
    sqlx::query("insert into documents(id,space_id,title,event_date,content,status,origin,created_by_member_id,updated_by_member_id,change_seq,created_at,updated_at) values($1,$2,'示例已撤销资料',current_date,'{}','voided','manual',$3,$3,nextval('change_seq'),now(),now())").bind(document).bind(space).bind(member).execute(&owner).await?;
    for (kind, id, event) in [
        ("subject", subject, "delete"),
        ("document", document, "void"),
    ] {
        sqlx::query("insert into entity_events(space_id,entity_kind,entity_id,kind,after,actor_member_id,change_seq) values($1,$2,$3,$4,'{}',$5,nextval('change_seq'))").bind(space).bind(kind).bind(id).bind(event).bind(member).execute(&owner).await?;
    }
    for who in [guest.member, member] {
        let conversation = Uuid::now_v7();
        sqlx::query("insert into conversations(id,space_id,member_id,change_seq) values($1,$2,$3,nextval('change_seq'))").bind(conversation).bind(space).bind(who).execute(&owner).await?;
        for status in ["complete", "streaming", "paused"] {
            sqlx::query("insert into chat_entries(id,space_id,member_id,conversation_id,role,protocol_version,message,fallback_text,stream_status,change_seq,created_at,updated_at) values(uuidv7(),$1,$2,$3,'assistant','test-only','{}','示例消息',$4,nextval('change_seq'),now(),now())").bind(space).bind(who).bind(conversation).bind(status).execute(&owner).await?;
        }
    }
    let all = pull_all(&h, space, 500, &h.token).await?;
    let entities = all
        .iter()
        .map(|r| r["entity"].as_str().unwrap())
        .collect::<std::collections::BTreeSet<_>>();
    assert_eq!(entities.len(), 12);
    for row in &all {
        assert_canonical_timestamps(&row["data"])?;
        if row["entity"] == "entity_event" {
            for key in ["before", "after"] {
                assert_canonical_timestamps(&row["data"][key])?;
            }
        }
    }
    for limit in [1, 2, 3] {
        assert_eq!(pull_all(&h, space, limit, &h.token).await?, all);
    }
    let seqs = all
        .iter()
        .map(|r| r["data"]["change_seq"].as_i64().unwrap())
        .collect::<Vec<_>>();
    assert!(
        seqs.windows(2).all(|w| w[0] < w[1]),
        "each row needs a unique sequence"
    );
    assert!(
        all.iter()
            .any(|r| r["entity"] == "account" && !r["data"]["archived_at"].is_null())
    );
    assert!(
        all.iter()
            .any(|r| r["entity"] == "record" && r["data"]["status"] == "voided")
    );
    assert!(
        all.iter()
            .any(|r| r["entity"] == "tag" && !r["data"]["deleted_at"].is_null())
    );
    assert!(
        all.iter()
            .any(|r| r["entity"] == "subject" && !r["data"]["deleted_at"].is_null())
    );
    for row in all
        .iter()
        .filter(|r| r["entity"] == "chat_entry" || r["entity"] == "conversation")
    {
        assert_eq!(row["data"]["member_id"], json!(member));
        assert_ne!(row["data"]["stream_status"], "streaming");
    }
    let page = h.pull(space, *seqs.last().unwrap(), 2, &h.token).await?;
    assert_eq!(page["spaces"][0]["cursor"], *seqs.last().unwrap());
    assert_eq!(page["spaces"][0]["has_more"], false);
    // Revoking SELECT makes accidental module queries fail, proving none skips
    // those tables completely rather than merely discarding rows afterwards.
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='documents'",
    )
    .bind(member)
    .execute(&owner)
    .await?;
    sqlx::raw_sql("revoke select on documents,subjects from jiabu_app")
        .execute(&owner)
        .await?;
    let ledger = pull_all(&h, space, 1, &h.token).await?;
    let mut expected = all
        .iter()
        .filter(|r| {
            r["entity"] != "document"
                && r["entity"] != "subject"
                && !(r["entity"] == "entity_event"
                    && matches!(
                        r["data"]["entity_kind"].as_str(),
                        Some("document" | "subject")
                    ))
        })
        .cloned()
        .collect::<Vec<_>>();
    let changed_grant = expected
        .iter_mut()
        .find(|r| {
            r["entity"] == "space_member_grant"
                && r["data"]["member_id"] == json!(member)
                && r["data"]["module"] == "documents"
        })
        .unwrap();
    assert_eq!(changed_grant["data"]["level"], "manage");
    changed_grant["data"]["level"] = json!("none");
    assert_eq!(ledger, expected);
    sqlx::raw_sql("grant select on documents,subjects to jiabu_app")
        .execute(&owner)
        .await?;
    sqlx::query("update space_member_grants set level=case when module='documents' then 'read' else 'none' end where member_id=$1").bind(member).execute(&owner).await?;
    sqlx::raw_sql("revoke select on accounts,allocation_plans,tags,records from jiabu_app")
        .execute(&owner)
        .await?;
    let documents = pull_all(&h, space, 2, &h.token).await?;
    assert!(documents.iter().all(|r| !matches!(
        r["entity"].as_str(),
        Some("record" | "account" | "allocation_plan" | "tag")
    )));
    assert!(
        documents
            .iter()
            .filter(|r| r["entity"] == "entity_event")
            .all(|r| matches!(
                r["data"]["entity_kind"].as_str(),
                Some("document" | "subject")
            ))
    );
    owner.close().await;
    Ok(())
}
#[test]
fn sync_openapi_envelope_reuses_registry_oneof_and_has_examples() -> Result<()> {
    let doc = serde_json::to_value(crate::openapi())?;
    let schemas = &doc["components"]["schemas"];
    assert_eq!(
        schemas["SyncPushOperation"]["oneOf"]
            .as_array()
            .unwrap()
            .len(),
        schemas["ToolCall"]["oneOf"].as_array().unwrap().len()
    );
    assert_eq!(schemas["PushOpEnvelope"]["type"], "object");
    assert!(schemas["PushOpEnvelope"].get("oneOf").is_none());
    assert_eq!(
        schemas["PushRequest"]["properties"]["ops"]["items"]["$ref"],
        "#/components/schemas/SyncPushOperation"
    );
    assert_eq!(schemas["PushRequest"]["properties"]["ops"]["maxItems"], 50);
    assert_eq!(schemas["PullRequest"]["properties"]["limit"]["minimum"], 1);
    assert_eq!(
        schemas["PullRequest"]["properties"]["limit"]["maximum"],
        500
    );
    assert_eq!(
        schemas["PullRequest"]["properties"]["spaces"]["maxProperties"],
        50
    );
    let validation =
        json!({"$ref":"#/components/schemas/PushRequest","components":doc["components"]});
    let validator = jsonschema::validator_for(&validation)
        .map_err(|_| anyhow::anyhow!("invalid push schema"))?;
    let request=doc["paths"]["/v1/sync/push"]["post"]["requestBody"]["content"]["application/json"]["example"].clone();
    assert!(validator.is_valid(&request));
    for path in ["/v1/sync/push", "/v1/sync/pull"] {
        assert!(doc["paths"][path]["post"]["responses"]["200"]["content"]["application/json"]["example"].is_object());
    }
    Ok(())
}
#[tokio::test]
async fn invocation_preserves_membership_failure_provenance_after_preflight() -> Result<()> {
    let h = S4App::new().await?;
    let space = h.new_space().await?;
    let guest = h.actor("guest", space).await?;
    let call = op(space, "create_tag", json!({"name":"示例世代预检"}));
    h.push(vec![call.clone()], &guest.token).await?;
    let op_id: Uuid = serde_json::from_value(call["op_id"].clone())?;
    let ctx = jiabu_tools::ToolCtx::begin(
        &h.state.db,
        h.principal(&guest.token).await?,
        SpaceId(space),
        Some(jiabu_domain::JoinEpoch(1)),
        jiabu_tools::Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(op_id),
            replay_key: Some(op_id.to_string()),
            run_id: None,
            request_id: Uuid::now_v7(),
            now: now(),
        },
    )
    .await?;
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
    let error = h
        .state
        .tools
        .invoke("create_tag", call["args"].clone(), &ctx)
        .await
        .err()
        .ok_or_else(|| anyhow::anyhow!("old result leaked"))?;
    assert_eq!(error.code, "not_found");
    assert!(error.space_unavailable);
    Ok(())
}
#[tokio::test]
async fn push_idempotency_binds_space_tool_and_original_arguments() -> Result<()> {
    let h = S4App::new().await?;
    let other = h.new_space().await?;
    let original = op(h.space, "create_tag", json!({"name":"示例原始参数"}));
    let first = h.push(vec![original.clone()], &h.token).await?;
    let mut altered = original.clone();
    altered["args"] = json!({"name":"示例改变参数"});
    assert_eq!(
        h.push(vec![altered], &h.token).await?["results"][0]["problem"]["code"],
        "idempotency_key_reused"
    );
    let mut moved = original.clone();
    moved["space_id"] = json!(other);
    let result = h.push(vec![moved], &h.token).await?;
    assert_eq!(
        result["results"][0]["problem"]["code"],
        "idempotency_key_reused"
    );
    assert!(result["results"][0].get("result").is_none());
    let mut tool = original.clone();
    tool["tool"] = json!("create_account");
    tool["args"] = json!({"kind":"real","name":"示例账户","opening_on":"2026-10-01"});
    assert_eq!(
        h.push(vec![tool], &h.token).await?["results"][0]["problem"]["code"],
        "idempotency_key_reused"
    );
    assert_eq!(h.push(vec![original], &h.token).await?, first);
    Ok(())
}
#[tokio::test]
async fn pull_limit_and_cursor_validation_and_empty_requests() -> Result<()> {
    let h = S4App::new().await?;
    for (limit, cursor) in [(0, 0_i64), (501, 0), (1, -1)] {
        let reply = h
            .app
            .request(
                "POST",
                "/v1/sync/pull",
                json!({"spaces":{(h.space.to_string()):cursor},"limit":limit}),
                Some(&h.token),
                &[],
            )
            .await?;
        assert_eq!(reply.status, StatusCode::BAD_REQUEST);
        assert_eq!(reply.json()["code"], "bad_request");
    }
    let reply = h
        .app
        .request(
            "POST",
            "/v1/sync/pull",
            json!({"spaces":{}}),
            Some(&h.token),
            &[],
        )
        .await?;
    assert_eq!(reply.status, StatusCode::OK);
    assert_eq!(reply.json(), json!({"spaces":[],"unavailable":[]}));
    let page = h.pull(h.space, i64::MAX, 1, &h.token).await?;
    assert_eq!(page["spaces"][0]["cursor"], i64::MAX);
    assert_eq!(page["spaces"][0]["has_more"], false);
    Ok(())
}

#[tokio::test]
async fn pull_accepts_fifty_spaces_and_rejects_fifty_one() -> Result<()> {
    let h = S4App::new().await?;
    for count in [50, 51] {
        let spaces = (0..count)
            .map(|_| (Uuid::now_v7().to_string(), json!(0)))
            .collect::<serde_json::Map<_, _>>();
        let response = h
            .app
            .request(
                "POST",
                "/v1/sync/pull",
                json!({"spaces": spaces, "limit": 1}),
                Some(&h.token),
                &[],
            )
            .await?;
        assert_eq!(
            response.status,
            if count == 50 {
                StatusCode::OK
            } else {
                StatusCode::BAD_REQUEST
            }
        );
        if count == 50 {
            assert_eq!(response.json()["unavailable"].as_array().unwrap().len(), 50);
        } else {
            assert_eq!(response.json()["code"], "bad_request");
        }
    }
    Ok(())
}

#[tokio::test]
async fn push_nonpositive_join_epoch_returns_400_before_membership_binding() -> Result<()> {
    let mut h = S4App::new().await?;
    h.key_limits(1000, 1000)?;
    for caller in h.key_callers().await? {
        for space in [h.space, Uuid::now_v7()] {
            for epoch in [0, -1] {
                let mut call = op(space, "create_tag", json!({"name":"示例非法世代"}));
                call["join_epoch"] = json!(epoch);
                let reply = h.push(vec![call], &caller).await?;
                assert_eq!(reply["results"][0]["status"], "rejected");
                assert_eq!(reply["results"][0]["problem"]["status"], 400);
                assert_eq!(reply["results"][0]["problem"]["code"], "bad_request");
            }
        }
    }
    let owner = h.app.fixture.owner().await?;
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from entity_events")
            .fetch_one(&owner)
            .await?,
        0
    );
    owner.close().await;
    Ok(())
}
