//! S6 integration acceptance: every request persists against PostgreSQL 18.
use super::s4::{S4App, hash, jpeg, op};
use super::*;
use jiabu_domain::{JoinEpoch, SpaceId};
use jiabu_tools::{Effect, Invocation, Module, ToolCtx};
pub(super) async fn harness() -> Result<S4App> {
    let mut h = S4App::new().await?;
    h.key_limits(10000, 10000)?;
    Ok(h)
}
pub(super) async fn api(
    h: &S4App,
    token: &str,
    name: &str,
    args: Value,
    key: Option<&str>,
) -> Result<Reply> {
    let mut headers = vec![("x-jiabu-join-epoch", "1".into())];
    if let Some(key) = key {
        headers.push(("idempotency-key", key.into()));
    }
    h.app
        .request(
            "POST",
            &format!("/v1/spaces/{}/tools/{name}", h.space),
            args,
            Some(token),
            &headers,
        )
        .await
}
async fn read(h: &S4App, name: &str, args: Value) -> Result<Value> {
    let reply = api(h, &h.token, name, args, None).await?;
    ensure!(reply.status == StatusCode::OK, "{name}: {}", reply.json());
    Ok(reply.json())
}
async fn subject(h: &S4App, name: &str) -> Result<Value> {
    h.call(
        h.space,
        "create_subject",
        json!({"kind":"family_member","name":name}),
    )
    .await
}
fn raw_document(subject: Option<&Value>, date: &str) -> Value {
    json!({"title":"虚构资料","event_date":date,"subject_ids":subject.map(|s|vec![s["id"].clone()]).unwrap_or_default(),"content":{"v":1,"items":[{"key":"note","type":"text","label":"备注","value":"虚构资料内容"}]}})
}
fn typed_document(
    subject: &Value,
    template: &str,
    date_key: &str,
    date: &str,
    items: Vec<Value>,
) -> Value {
    let mut all = vec![json!({"key":date_key,"type":"date","label":"日期快照","value":date})];
    all.extend(items);
    json!({"template_id":template,"subject_ids":[subject["id"]],"content":{"v":1,"items":all}})
}
async fn error(h: &S4App, name: &str, args: Value, code: &str) -> Result<Reply> {
    let reply = api(h, &h.token, name, args, Some(&Uuid::now_v7().to_string())).await?;
    assert_eq!(
        reply.status,
        StatusCode::UNPROCESSABLE_ENTITY,
        "{name}: {}",
        reply.json()
    );
    assert_eq!(reply.json()["code"], code);
    Ok(reply)
}
#[tokio::test]
async fn official_four_fictional_examples_round_trip_with_titles_dates_versions() -> Result<()> {
    let h = harness().await?;
    let s = subject(&h, "虚构家人甲").await?;
    let cases = [
        (
            "jiabu.checkup",
            "exam_date",
            vec![
                json!({"key":"weight","type":"number","label":"体重旧标签","value":61.5}),
                json!({"key":"fasting","type":"single_select","label":"空腹","value":{"id":"yes","label":"是旧标签"}}),
            ],
        ),
        (
            "jiabu.vision",
            "exam_date",
            vec![
                json!({"key":"left_acuity","type":"number","label":"左眼","value":0.8,"unit":"decimal"}),
            ],
        ),
        (
            "jiabu.vaccination",
            "vaccination_date",
            vec![
                json!({"key":"vaccine_name","type":"text","label":"疫苗","value":"虚构示例疫苗"}),
                json!({"key":"dose_no","type":"number","label":"剂次","value":2}),
            ],
        ),
        (
            "jiabu.certificate",
            "issue_date",
            vec![
                json!({"key":"document_number","type":"text","label":"号码","value":"FAKE-000012"}),
                json!({"key":"category","type":"single_select","label":"类别","value":{"id":"other","label":"虚构其他证件"}}),
            ],
        ),
    ];
    for (id, date_key, items) in cases {
        let args = typed_document(&s, id, date_key, "2026-10-12", items);
        let created = h.call(h.space, "create_document", args.clone()).await?;
        let fetched = read(&h, "get_document", json!({"id":created["id"]})).await?;
        assert_eq!(fetched, created);
        assert_eq!(created["event_date"], "2026-10-12");
        assert_eq!(created["template_version"], 1);
        assert_eq!(created["origin"], "manual");
        let title = created["title"].as_str().unwrap();
        assert!(title.contains("虚构家人甲") && title.contains("2026-10-12"));
        for input in args["content"]["items"].as_array().unwrap() {
            let output = created["content"]["items"]
                .as_array()
                .unwrap()
                .iter()
                .find(|i| i["key"] == input["key"])
                .unwrap();
            assert_eq!(output["value"], input["value"]);
            assert_eq!(output["label"], input["label"]);
        }
    }
    let list = read(&h, "list_subjects", json!({})).await?;
    assert_eq!(list["subjects"].as_array().unwrap().len(), 1);
    let all = read(&h, "search_documents", json!({"page":{"limit":2}})).await?;
    assert_eq!(all["documents"].as_array().unwrap().len(), 2);
    assert_eq!(all["has_more"], true);
    let filtered=read(&h,"search_documents",json!({"filters":{"subject_id":s["id"],"template_id":"jiabu.vision","from":"2026-10-12","to":"2026-10-12","created_by_member_id":h.member}})).await?;
    assert_eq!(filtered["documents"].as_array().unwrap().len(), 1);
    assert!(
        read(
            &h,
            "search_documents",
            json!({"filters":{"unassociated":true}})
        )
        .await?["documents"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    Ok(())
}
#[tokio::test]
async fn association_correction_full_snapshots_archive_voided_delete_and_normalized_reuse()
-> Result<()> {
    let h = harness().await?;
    let a = subject(&h, "Alice").await?;
    let b = subject(&h, "Bob").await?;
    let d = h
        .call(
            h.space,
            "create_document",
            raw_document(Some(&a), "2026-10-12"),
        )
        .await?;
    let changed = h
        .call(
            h.space,
            "update_document",
            json!({"id":d["id"],"expected_version":1,"changes":{"subject_ids":[b["id"]]}}),
        )
        .await?;
    let owner = h.app.fixture.owner().await?;
    let snapshots:Value=sqlx::query_scalar("select jsonb_build_object('before',before,'after',after) from entity_events where entity_kind='document' and entity_id=$1 and kind='update'").bind(Uuid::parse_str(d["id"].as_str().unwrap())?).fetch_one(&owner).await?;
    assert_eq!(snapshots["before"], d);
    assert_eq!(snapshots["after"], changed);
    assert!(
        read(
            &h,
            "search_documents",
            json!({"filters":{"subject_id":a["id"]}})
        )
        .await?["documents"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    error(
        &h,
        "delete_subject",
        json!({"id":b["id"],"expected_version":1}),
        "subject_in_use",
    )
    .await?;
    h.call(
        h.space,
        "void_document",
        json!({"id":d["id"],"expected_version":2}),
    )
    .await?;
    error(
        &h,
        "delete_subject",
        json!({"id":b["id"],"expected_version":1}),
        "subject_in_use",
    )
    .await?;
    let archived = h
        .call(
            h.space,
            "archive_subject",
            json!({"id":b["id"],"expected_version":1}),
        )
        .await?;
    assert!(archived["archived_at"].is_string());
    let reused = subject(&h, "　ｂＯｂ　").await?;
    assert_eq!(reused["id"], b["id"]);
    assert_eq!(reused["version"], 3);
    assert!(reused["archived_at"].is_null());
    assert_eq!(subject(&h, " bob ").await?, reused);
    let timeline = read(
        &h,
        "search_documents",
        json!({"filters":{"subject_id":reused["id"],"status":"voided"}}),
    )
    .await?;
    assert_eq!(timeline["documents"][0]["id"], d["id"]);
    let count:i64=sqlx::query_scalar("select count(*) from subjects where space_id=$1 and kind='family_member' and lower(name)='bob'").bind(h.space).fetch_one(&owner).await?;
    assert_eq!(count, 1);
    let renamed = h
        .call(
            h.space,
            "update_subject",
            json!({"id":a["id"],"expected_version":1,"name":"虚构家人丙","member_id":h.member}),
        )
        .await?;
    assert_eq!(renamed["member_id"], json!(h.member));
    // ApiOnly is syncable: this is the actual C6 delete path.
    let deleted = h
        .call(
            h.space,
            "delete_subject",
            json!({"id":a["id"],"expected_version":2}),
        )
        .await?;
    assert!(deleted["deleted_at"].is_string());
    let events: i64 = sqlx::query_scalar(
        "select count(*) from entity_events where entity_kind='subject' and kind='unarchive'",
    )
    .fetch_one(&owner)
    .await?;
    assert_eq!(events, 1);
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn concurrent_normalized_subject_creation_has_one_identity_and_create_event() -> Result<()> {
    let h = harness().await?;
    let a = api(
        &h,
        &h.token,
        "create_subject",
        json!({"kind":"family_member","name":" Ａｌｉｃｅ "}),
        Some("concurrent-a"),
    );
    let b = api(
        &h,
        &h.token,
        "create_subject",
        json!({"kind":"family_member","name":"alice"}),
        Some("concurrent-b"),
    );
    let (a, b) = tokio::join!(a, b);
    let a = a?;
    let b = b?;
    assert_eq!(a.status, StatusCode::OK);
    assert_eq!(b.status, StatusCode::OK);
    assert_eq!(a.json()["id"], b.json()["id"]);
    let owner = h.app.fixture.owner().await?;
    let count: i64 = sqlx::query_scalar("select count(*) from subjects where space_id=$1")
        .bind(h.space)
        .fetch_one(&owner)
        .await?;
    assert_eq!(count, 1);
    let count: i64 = sqlx::query_scalar(
        "select count(*) from entity_events where entity_kind='subject' and kind='create'",
    )
    .fetch_one(&owner)
    .await?;
    assert_eq!(count, 1);
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn document_content_validation_and_failed_transactions_leave_no_rows() -> Result<()> {
    let h = harness().await?;
    let s = subject(&h, "虚构家人甲").await?;
    let base = typed_document(&s, "jiabu.checkup", "exam_date", "2026-10-12", vec![]);
    let mut cases = Vec::new();
    for item in [
        json!({"key":"unknown","type":"text","label":"未知","value":"x"}),
        json!({"key":"weight","type":"text","label":"错误","value":"61"}),
        json!({"key":"heart_rate","type":"number","label":"错误单位","value":70,"unit":"wrong"}),
        json!({"key":"fasting","type":"single_select","label":"错误选项","value":{"id":"missing","label":"未知"}}),
    ] {
        let mut args = base.clone();
        args["content"]["items"].as_array_mut().unwrap().push(item);
        cases.push(args);
    }
    let mut too_many = raw_document(None, "2026-10-12");
    too_many["content"]["items"] = json!(
        (0..201)
            .map(|n| json!({"key":format!("n{n}"),"type":"number","label":"值","value":n}))
            .collect::<Vec<_>>()
    );
    cases.push(too_many);
    let mut rows = raw_document(None, "2026-10-12");
    rows["content"]["items"] = json!([{"key":"table","type":"table","label":"表格","value":{"columns":[{"key":"n","type":"number","label":"值"}],"rows":vec![json!({"n":1});201]}}]);
    cases.push(rows);
    let mut large = raw_document(None, "2026-10-12");
    large["content"]["items"][0]["value"] = json!("字".repeat(100000));
    cases.push(large);
    for args in cases {
        error(&h, "create_document", args, "validation_failed").await?;
    }
    let mut no_subject = base.clone();
    no_subject["subject_ids"] = json!([]);
    error(&h, "create_document", no_subject, "subject_rule_violated").await?;
    let pet = h
        .call(
            h.space,
            "create_subject",
            json!({"kind":"pet","name":"虚构宠物"}),
        )
        .await?;
    for ids in [
        json!([pet["id"]]),
        json!([s["id"], pet["id"]]),
        json!([s["id"], s["id"]]),
        json!([Uuid::now_v7()]),
    ] {
        let mut args = base.clone();
        args["subject_ids"] = ids;
        error(&h, "create_document", args, "subject_rule_violated").await?;
    }
    let owner = h.app.fixture.owner().await?;
    let count: i64 = sqlx::query_scalar("select count(*) from documents")
        .fetch_one(&owner)
        .await?;
    assert_eq!(count, 0);
    let count: i64 =
        sqlx::query_scalar("select count(*) from entity_events where entity_kind='document'")
            .fetch_one(&owner)
            .await?;
    assert_eq!(count, 0);
    let saved=h.call(h.space,"create_document",json!({"template_id":"jiabu.checkup","subject_ids":[s["id"]],"content":{"v":1,"items":[]}})).await?;
    assert_eq!(saved["event_date"], "2026-10-28");
    let mut uncertain = base;
    uncertain["content"]["items"]
        .as_array_mut()
        .unwrap()
        .push(json!({"key":"weight","type":"number","label":"体重","value":999}));
    let saved = h.call(h.space, "create_document", uncertain).await?;
    assert_eq!(saved["content"]["items"][1]["uncertain"], true);
    // Update must apply the same validation, including unknown keys.
    error(&h,"update_document",json!({"id":saved["id"],"expected_version":1,"changes":{"content":{"v":1,"items":[{"key":"unknown","type":"text","label":"未知","value":"x"}]}}}),"validation_failed").await?;
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn image_reference_promotion_rejects_ledger_other_chat_and_other_space_identically()
-> Result<()> {
    let mut h = harness().await?;
    let other = h.space;
    // Invite the second member into a shared space; keep the default space as
    // the unrelated space used by the cross-space reference check.
    h.space = h.new_space().await?;
    let actor = h.actor("fictional-other", h.space).await?;
    let bytes = jpeg(12, 8);
    let sha = hash(&bytes).to_string();
    let mut args = raw_document(None, "2026-10-12");
    args["content"]["items"] = json!([{"key":"images","type":"image","label":"原图","value":[{"blob":sha,"caption":"虚构图片"}]}]);
    error(&h, "create_document", args.clone(), "blob_missing").await?;
    assert_eq!(
        h.upload(other, "documents", bytes.clone(), &h.token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    error(&h, "create_document", args.clone(), "blob_missing").await?;
    assert_eq!(
        h.upload(h.space, "ledger", bytes.clone(), &h.token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    error(&h, "create_document", args.clone(), "blob_missing").await?;
    assert_eq!(
        h.upload(h.space, "chat", bytes.clone(), &actor.token, 1)
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    error(&h, "create_document", args.clone(), "blob_missing").await?;
    let owner = h.app.fixture.owner().await?;
    let n: i64 = sqlx::query_scalar(
        "select count(*) from blob_refs where space_id=$1 and module='documents'",
    )
    .bind(h.space)
    .fetch_one(&owner)
    .await?;
    assert_eq!(n, 0);
    assert_eq!(
        h.upload(h.space, "chat", bytes, &h.token, 1).await?.status,
        StatusCode::NO_CONTENT
    );
    let saved = h.call(h.space, "create_document", args.clone()).await?;
    assert_eq!(saved["content"], args["content"]);
    let n: i64 = sqlx::query_scalar(
        "select count(*) from blob_refs where space_id=$1 and module='documents'",
    )
    .bind(h.space)
    .fetch_one(&owner)
    .await?;
    assert_eq!(n, 1);
    // Another authorized member can use the established documents ref, without owning chat.
    assert_eq!(
        api(
            &h,
            &actor.token,
            "create_document",
            args,
            Some("shared-document-image")
        )
        .await?
        .status,
        StatusCode::OK
    );
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn metrics_compare_only_subject_metric_active_template_and_exact_latest_unit() -> Result<()> {
    let h = harness().await?;
    let a = subject(&h, "虚构家人甲").await?;
    let b = subject(&h, "虚构家人乙").await?;
    let mut custom: Value = serde_json::from_str(jiabu_domain::templates::OFFICIAL[0].1)?;
    custom["id"] = json!("myhome.checkup");
    let mut files = jiabu_tools::templates::official_files();
    files.push(jiabu_tools::templates::TemplateFile {
        filename: "custom.json".into(),
        body: custom.to_string(),
        official: false,
        error: None,
    });
    h.state.templates.reload(&h.state.db, files).await?;
    let weight = |s: &Value, id: &str, date: &str, value: f64, unit: &str| {
        typed_document(
            s,
            id,
            "exam_date",
            date,
            vec![json!({"key":"weight","type":"number","label":"体重","value":value,"unit":unit})],
        )
    };
    let kg = h
        .call(
            h.space,
            "create_document",
            weight(&a, "jiabu.checkup", "2026-10-01", 60.0, "kg"),
        )
        .await?;
    let lb = h
        .call(
            h.space,
            "create_document",
            weight(&a, "jiabu.checkup", "2026-10-02", 130.0, "lb"),
        )
        .await?;
    let newest = h
        .call(
            h.space,
            "create_document",
            weight(&a, "myhome.checkup", "2026-10-03", 62.0, "kg"),
        )
        .await?;
    h.call(
        h.space,
        "create_document",
        weight(&b, "jiabu.checkup", "2026-10-09", 90.0, "kg"),
    )
    .await?;
    let voided = h
        .call(
            h.space,
            "create_document",
            weight(&a, "jiabu.checkup", "2026-10-10", 999.0, "lb"),
        )
        .await?;
    h.call(
        h.space,
        "void_document",
        json!({"id":voided["id"],"expected_version":1}),
    )
    .await?;
    let mut raw = raw_document(Some(&a), "2026-10-11");
    raw["content"]["items"] =
        json!([{"key":"weight","type":"number","label":"体重","value":999,"unit":"kg"}]);
    h.call(h.space, "create_document", raw).await?;
    h.call(
        h.space,
        "create_document",
        typed_document(
            &a,
            "jiabu.checkup",
            "exam_date",
            "2026-10-12",
            vec![
                json!({"key":"height","type":"number","label":"身高","value":170,"unit":"cm"}),
                json!({"key":"weight","type":"number","label":"体重","value":null,"unit":"lb"}),
            ],
        ),
    )
    .await?;
    let series = read(
        &h,
        "document_metric_series",
        json!({"subject_id":a["id"],"metric":"body.weight"}),
    )
    .await?;
    assert_eq!(series["unit"], "kg");
    assert_eq!(series["points"].as_array().unwrap().len(), 2);
    assert_eq!(series["points"][0]["document_id"], kg["id"]);
    assert_eq!(series["points"][1]["document_id"], newest["id"]);
    assert_eq!(
        series["excluded"],
        json!([{"document_id":lb["id"],"unit":"lb"}])
    );
    let ranged = read(
        &h,
        "document_metric_series",
        json!({"subject_id":a["id"],"metric":"body.weight","from":"2026-10-01","to":"2026-10-02"}),
    )
    .await?;
    assert_eq!(ranged["unit"], "lb");
    assert_eq!(ranged["points"].as_array().unwrap().len(), 1);
    let blood = |date: &str, unit: &str| {
        typed_document(
            &a,
            "jiabu.checkup",
            "exam_date",
            date,
            vec![
                json!({"key":"blood_routine","type":"table","label":"血常规","value":{"columns":[{"key":"item","type":"single_select","label":"项目"},{"key":"result","type":"number","label":"结果"},{"key":"unit","type":"text","label":"单位"}],"rows":[{"item":{"id":"hgb","label":"旧血红蛋白标签"},"result":130,"unit":unit},{"item":{"id":"wbc","label":"白细胞"},"result":6.0,"unit":"10^9/L"}]}}),
            ],
        )
    };
    let old = h
        .call(h.space, "create_document", blood("2026-10-01", "g/L"))
        .await?;
    let recent = h
        .call(h.space, "create_document", blood("2026-10-04", "g/dL"))
        .await?;
    let series = read(
        &h,
        "document_metric_series",
        json!({"subject_id":a["id"],"metric":"blood.cbc.hgb"}),
    )
    .await?;
    assert_eq!(series["unit"], "g/dL");
    assert_eq!(series["points"].as_array().unwrap().len(), 1);
    assert_eq!(series["points"][0]["document_id"], recent["id"]);
    assert_eq!(
        series["excluded"],
        json!([{"document_id":old["id"],"unit":"g/L"}])
    );
    let expected = series_for_weight(&h, &a).await?;
    h.state
        .templates
        .reload(&h.state.db, jiabu_tools::templates::official_files())
        .await?;
    let removed = read(
        &h,
        "document_metric_series",
        json!({"subject_id":a["id"],"metric":"body.weight"}),
    )
    .await?;
    assert_eq!(removed, expected);
    assert_eq!(removed["points"].as_array().unwrap().len(), 2);
    Ok(())
}
async fn series_for_weight(h: &S4App, a: &Value) -> Result<Value> {
    read(
        h,
        "document_metric_series",
        json!({"subject_id":a["id"],"metric":"body.weight"}),
    )
    .await
}
#[tokio::test]
async fn lifecycle_conflicts_idempotency_push_and_direct_invoke_share_one_path() -> Result<()> {
    let h = harness().await?;
    let (_, key) = super::api_keys::issue(&h.app, &h.token, "read_write").await?;
    let id = Uuid::now_v7();
    let operation = Uuid::now_v7();
    let args = json!({"id":id,"title":"虚构幂等资料","content":{"v":1,"items":[]}});
    let first = api(
        &h,
        &key,
        "create_document",
        args.clone(),
        Some(&operation.to_string()),
    )
    .await?;
    assert_eq!(first.status, StatusCode::OK);
    assert_eq!(first.json()["origin"], "api");
    let replay = api(
        &h,
        &key,
        "create_document",
        args.clone(),
        Some(&operation.to_string()),
    )
    .await?;
    assert_eq!(replay.bytes, first.bytes);
    let mut push = op(h.space, "create_document", args.clone());
    push["op_id"] = json!(operation);
    let reply = h.push(vec![push], &key).await?;
    assert_eq!(reply["results"][0]["result"], first.json());
    let principal = h
        .state
        .db
        .authenticate_api_key(crate::credentials::token_hash(&key))
        .await?;
    let ctx = ToolCtx::begin(
        &h.state.db,
        principal.clone(),
        SpaceId(h.space),
        Some(JoinEpoch(1)),
        Effect::LocalWrite,
        Invocation {
            idempotency_key: Some(Uuid::new_v5(
                &principal.user_id.0,
                operation.to_string().as_bytes(),
            )),
            replay_key: Some(operation.to_string()),
            run_id: None,
            request_id: Uuid::now_v7(),
            now: h.state.clock.now(),
        },
    )
    .await?;
    assert_eq!(
        h.state
            .tools
            .invoke("create_document", args.clone(), &ctx)
            .await?,
        first.json()
    );
    let mut different = args.clone();
    different["title"] = json!("变了");
    let mismatch = api(
        &h,
        &key,
        "create_document",
        different,
        Some(&operation.to_string()),
    )
    .await?;
    assert_eq!(mismatch.status, StatusCode::UNPROCESSABLE_ENTITY);
    let owner = h.app.fixture.owner().await?;
    let n: i64 = sqlx::query_scalar(
        "select count(*) from entity_events where entity_kind='document' and kind='create'",
    )
    .fetch_one(&owner)
    .await?;
    assert_eq!(n, 1);
    for tool in ["update_document", "void_document", "restore_document"] {
        let mut args = json!({"id":id,"expected_version":999});
        if tool == "update_document" {
            args["changes"] = json!({"title":"虚构更正"});
        }
        let conflict = api(&h, &key, tool, args, Some(&Uuid::now_v7().to_string())).await?;
        assert_eq!(conflict.status, StatusCode::CONFLICT);
        assert_eq!(conflict.json()["code"], "version_conflict");
        assert_eq!(conflict.json()["current"], first.json());
    }
    let voided = h
        .call(
            h.space,
            "void_document",
            json!({"id":id,"expected_version":1}),
        )
        .await?;
    assert_eq!(voided["status"], "voided");
    let restored = h
        .call(
            h.space,
            "restore_document",
            json!({"id":id,"expected_version":2}),
        )
        .await?;
    assert_eq!(restored["status"], "active");
    assert_eq!(restored["version"], 3);
    let marked:Value=sqlx::query_scalar("select jsonb_build_object('id',via_api_key_id,'name',via_api_key_name,'after',after) from entity_events where entity_kind='document' and kind='create'").fetch_one(&owner).await?;
    assert!(marked["id"].is_string());
    assert_eq!(marked["name"], "示例脚本");
    assert_eq!(marked["after"], first.json());
    let n:i64=sqlx::query_scalar("select count(*) from api_key_audit where operation in ('tool:create_document','push:create_document') and outcome='ok'").fetch_one(&owner).await?;
    assert_eq!(n, 4);
    let refused = h
        .push(
            vec![
                op(h.space, "ask_user", json!({})),
                op(h.space, "list_subjects", json!({})),
            ],
            &key,
        )
        .await?;
    for item in refused["results"].as_array().unwrap() {
        assert_eq!(item["status"], "rejected");
        assert_eq!(item["problem"]["code"], "tool_not_syncable");
    }
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn readonly_keys_and_current_grants_precede_document_replay() -> Result<()> {
    let h = harness().await?;
    let (_, read_key) = super::api_keys::issue(&h.app, &h.token, "read").await?;
    let (write_id, write_key) = super::api_keys::issue(&h.app, &h.token, "read_write").await?;
    for name in [
        "create_document",
        "update_document",
        "void_document",
        "restore_document",
        "create_subject",
        "update_subject",
        "archive_subject",
        "delete_subject",
    ] {
        let tool = h.state.tools.get(name)?;
        let reply = api(&h, &read_key, name, tool.example_args(), Some("read-only")).await?;
        assert_eq!(reply.status, StatusCode::FORBIDDEN, "{name}");
        assert_eq!(reply.json()["code"], "api_key_read_only");
    }
    let readable_subject = subject(&h, "虚构只读家人").await?;
    let readable_document = h
        .call(
            h.space,
            "create_document",
            raw_document(Some(&readable_subject), "2026-10-12"),
        )
        .await?;
    for (name, args) in [
        ("list_subjects", json!({})),
        ("search_documents", json!({})),
        ("get_document", json!({"id":readable_document["id"]})),
        (
            "document_metric_series",
            json!({"subject_id":readable_subject["id"],"metric":"body.weight"}),
        ),
    ] {
        assert_eq!(
            api(&h, &read_key, name, args, None).await?.status,
            StatusCode::OK,
            "{name}"
        );
    }
    let directory = h
        .app
        .request(
            "GET",
            &format!("/v1/spaces/{}/tools", h.space),
            Value::Null,
            Some(&read_key),
            &[],
        )
        .await?;
    assert!(
        directory.json()["tools"]
            .as_array()
            .unwrap()
            .iter()
            .all(|t| t["effect"] == "read")
    );
    let args = json!({"kind":"family_member","name":"虚构重放对象"});
    let first = api(
        &h,
        &write_key,
        "create_subject",
        args.clone(),
        Some("replay-after-revoke"),
    )
    .await?;
    assert_eq!(first.status, StatusCode::OK);
    let owner = h.app.fixture.owner().await?;
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='documents'",
    )
    .bind(h.member)
    .execute(&owner)
    .await?;
    let denied = api(
        &h,
        &write_key,
        "create_subject",
        args.clone(),
        Some("replay-after-revoke"),
    )
    .await?;
    assert_eq!(denied.status, StatusCode::NOT_FOUND);
    sqlx::query(
        "update space_member_grants set level='manage' where member_id=$1 and module='documents'",
    )
    .bind(h.member)
    .execute(&owner)
    .await?;
    sqlx::query("update api_keys set scope='read' where id=$1")
        .bind(write_id)
        .execute(&owner)
        .await?;
    let denied = api(
        &h,
        &write_key,
        "create_subject",
        args,
        Some("replay-after-revoke"),
    )
    .await?;
    assert_eq!(denied.status, StatusCode::FORBIDDEN);
    assert_eq!(denied.json()["code"], "api_key_read_only");
    let n:i64=sqlx::query_scalar("select count(*) from entity_events where entity_kind='subject' and after->>'name'='虚构重放对象'").fetch_one(&owner).await?;
    assert_eq!(n, 1);
    // An old epoch must never obtain its saved result after rejoining.
    let args = json!({"title":"虚构世代资料","content":{"v":1,"items":[]}});
    let item = op(h.space, "create_document", args.clone());
    assert_eq!(
        h.push(vec![item.clone()], &h.token).await?["results"][0]["status"],
        "ok"
    );
    sqlx::query(
        "update space_members set status='left',left_at=now(),left_reason='left' where id=$1",
    )
    .bind(h.member)
    .execute(&owner)
    .await?;
    assert_eq!(
        h.push(vec![item.clone()], &h.token).await?["results"][0]["status"],
        "space_unavailable"
    );
    sqlx::query("update space_members set status='active',left_at=null,left_reason=null,join_epoch=join_epoch+1 where id=$1").bind(h.member).execute(&owner).await?;
    assert_eq!(
        h.push(vec![item], &h.token).await?["results"][0]["status"],
        "membership_changed"
    );
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn new_document_subject_and_audit_rows_pull_with_pagination_and_module_filter() -> Result<()>
{
    let h = harness().await?;
    let s = subject(&h, "虚构同步家人").await?;
    let d = h
        .call(
            h.space,
            "create_document",
            raw_document(Some(&s), "2026-10-12"),
        )
        .await?;
    h.call(
        h.space,
        "void_document",
        json!({"id":d["id"],"expected_version":1}),
    )
    .await?;
    h.call(
        h.space,
        "archive_subject",
        json!({"id":s["id"],"expected_version":1}),
    )
    .await?;
    let mut cursor = 0;
    let mut changes = Vec::new();
    loop {
        let page = h.pull(h.space, cursor, 1, &h.token).await?;
        let page = &page["spaces"][0];
        changes.extend(page["changes"].as_array().unwrap().iter().cloned());
        let next = page["cursor"].as_i64().unwrap();
        if page["has_more"] == false {
            break;
        }
        assert!(next > cursor);
        cursor = next;
    }
    assert!(changes.iter().any(|c| c["entity"] == "document"
        && c["data"]["id"] == d["id"]
        && c["data"]["status"] == "voided"));
    assert!(
        changes
            .iter()
            .any(|c| c["entity"] == "subject" && c["data"]["archived_at"].is_string())
    );
    let seqs = changes
        .iter()
        .map(|c| c["data"]["change_seq"].as_i64().unwrap())
        .collect::<std::collections::BTreeSet<_>>();
    assert_eq!(seqs.len(), changes.len());
    let owner = h.app.fixture.owner().await?;
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='documents'",
    )
    .bind(h.member)
    .execute(&owner)
    .await?;
    let page = h.pull(h.space, 0, 500, &h.token).await?;
    for change in page["spaces"][0]["changes"].as_array().unwrap() {
        assert!(!matches!(
            change["entity"].as_str(),
            Some("document" | "subject")
        ));
        assert!(!matches!(
            change["data"]["entity_kind"].as_str(),
            Some("document" | "subject")
        ));
    }
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn document_routes_reject_other_accessible_space_entities_and_none_grants() -> Result<()> {
    let h = harness().await?;
    let foreign = h.new_space().await?;
    let fs = h
        .call(
            foreign,
            "create_subject",
            json!({"kind":"family_member","name":"虚构外部家人"}),
        )
        .await?;
    let fd = h
        .call(
            foreign,
            "create_document",
            raw_document(Some(&fs), "2026-10-12"),
        )
        .await?;
    for (tool, args) in [
        ("get_document", json!({"id":fd["id"]})),
        (
            "search_documents",
            json!({"filters":{"subject_id":fs["id"]}}),
        ),
        (
            "document_metric_series",
            json!({"subject_id":fs["id"],"metric":"body.weight"}),
        ),
        (
            "update_subject",
            json!({"id":fs["id"],"expected_version":1,"name":"错误"}),
        ),
        ("void_document", json!({"id":fd["id"],"expected_version":1})),
    ] {
        let reply = api(&h, &h.token, tool, args, Some(&Uuid::now_v7().to_string())).await?;
        assert_eq!(reply.status, StatusCode::NOT_FOUND, "{tool}");
    }
    error(
        &h,
        "create_document",
        typed_document(&fs, "jiabu.vision", "exam_date", "2026-10-12", vec![]),
        "subject_rule_violated",
    )
    .await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='documents'",
    )
    .bind(h.member)
    .execute(&owner)
    .await?;
    let (_, rk) = super::api_keys::issue(&h.app, &h.token, "read").await?;
    let (_, wk) = super::api_keys::issue(&h.app, &h.token, "read_write").await?;
    for token in [&h.token, &rk, &wk] {
        for tool in h
            .state
            .tools
            .tools()
            .filter(|t| matches!(t.module(), Module::Documents))
        {
            let reply = api(
                &h,
                token,
                tool.name(),
                tool.example_args(),
                Some(&Uuid::now_v7().to_string()),
            )
            .await?;
            let expected = if token == &rk && tool.effect() != Effect::Read {
                StatusCode::FORBIDDEN
            } else {
                StatusCode::NOT_FOUND
            };
            assert_eq!(reply.status, expected, "{}", tool.name());
        }
    }
    owner.close().await;
    Ok(())
}
#[test]
fn all_document_openapi_operations_have_examples_and_sync_branches() -> Result<()> {
    let doc = serde_json::to_value(crate::openapi())?;
    let registry = jiabu_tools::builtin_registry();
    for tool in registry
        .tools()
        .filter(|t| matches!(t.module(), Module::Documents))
    {
        let op = &doc["paths"][tool.api_path()]["post"];
        assert_eq!(op["operationId"], format!("tool_{}", tool.name()));
        assert!(op["requestBody"]["content"]["application/json"]["example"].is_object());
        assert!(op["responses"]["200"]["content"]["application/json"]["example"].is_object());
        assert!(
            doc["components"]["schemas"][format!("SyncPushOperation_{}", tool.name())].is_object()
        );
    }
    assert!(doc["paths"]["/v1/templates"]["get"]["responses"]["304"].is_object());
    assert!(doc["components"]["schemas"]["DocumentTemplate"].is_object());
    assert!(!doc.to_string().contains("ask_user"));
    Ok(())
}
#[tokio::test]
async fn event_dates_follow_space_timezone_explicit_overrides_and_never_drift_on_unrelated_edit()
-> Result<()> {
    let mut h = harness().await?;
    h.state.clock = std::sync::Arc::new(s4::Fixed(
        chrono::DateTime::parse_from_rfc3339("2026-10-27T17:00:00Z")?.with_timezone(&chrono::Utc),
    ));
    h.app.router = crate::router(h.state.clone());
    let saved = h
        .call(
            h.space,
            "create_document",
            json!({"title":"虚构默认日期","content":{"v":1,"items":[]}}),
        )
        .await?;
    assert_eq!(saved["event_date"], "2026-10-28");
    let s = subject(&h, "虚构日期家人").await?;
    let mut args = typed_document(&s, "jiabu.vision", "exam_date", "2026-10-12", vec![]);
    args["event_date"] = json!("2026-10-13");
    error(&h, "create_document", args, "validation_failed").await?;
    let mut args = typed_document(&s, "jiabu.vision", "exam_date", "2026-10-12", vec![]);
    args["content"]["items"][0]["value"] = Value::Null;
    args["event_date"] = json!("2026-10-11");
    let empty = h.call(h.space, "create_document", args).await?;
    assert_eq!(empty["event_date"], "2026-10-11");
    h.state.clock = std::sync::Arc::new(s4::Fixed(
        chrono::DateTime::parse_from_rfc3339("2026-11-02T00:00:00Z")?.with_timezone(&chrono::Utc),
    ));
    h.app.router = crate::router(h.state.clone());
    let changed = h
        .call(
            h.space,
            "update_document",
            json!({"id":saved["id"],"expected_version":1,"changes":{"title":"虚构改标题"}}),
        )
        .await?;
    assert_eq!(changed["event_date"], "2026-10-28");
    let changed = h
        .call(
            h.space,
            "update_document",
            json!({"id":saved["id"],"expected_version":2,"changes":{"event_date":"2026-10-01"}}),
        )
        .await?;
    assert_eq!(changed["event_date"], "2026-10-01");
    let (_, key) = super::api_keys::issue(&h.app, &h.token, "read_write").await?;
    let en = h
        .app
        .request(
            "PATCH",
            "/v1/me",
            json!({"locale":"en"}),
            Some(&h.token),
            &[],
        )
        .await?;
    assert_eq!(en.status, StatusCode::OK);
    let created = api(
        &h,
        &key,
        "create_document",
        typed_document(&s, "jiabu.vision", "exam_date", "2026-10-12", vec![]),
        Some("english-title"),
    )
    .await?;
    assert_eq!(created.status, StatusCode::OK);
    assert_eq!(
        created.json()["title"],
        "虚构日期家人 Vision exam 2026-10-12"
    );
    Ok(())
}
#[tokio::test]
async fn subject_conflicts_bindings_rename_collision_and_unassociated_filter_are_checked()
-> Result<()> {
    let h = harness().await?;
    let a = subject(&h, "虚构家人甲").await?;
    let b = subject(&h, "虚构家人乙").await?;
    for name in ["update_subject", "archive_subject", "delete_subject"] {
        let mut args = json!({"id":a["id"],"expected_version":9});
        if name == "update_subject" {
            args["name"] = json!("虚构新名");
        }
        let reply = api(&h, &h.token, name, args, Some(&Uuid::now_v7().to_string())).await?;
        assert_eq!(reply.status, StatusCode::CONFLICT);
        assert_eq!(reply.json()["code"], "version_conflict");
        assert_eq!(reply.json()["current"], a);
    }
    error(
        &h,
        "update_subject",
        json!({"id":a["id"],"expected_version":1,"name":b["name"]}),
        "name_taken",
    )
    .await?;
    let other = h.new_space().await?;
    let actor = h.actor("fictional-binding", other).await?;
    let bound = api(
        &h,
        &h.token,
        "update_subject",
        json!({"id":a["id"],"expected_version":1,"member_id":actor.member}),
        Some("foreign-binding"),
    )
    .await?;
    assert_eq!(bound.status, StatusCode::NOT_FOUND);
    let unassociated = h
        .call(h.space, "create_document", raw_document(None, "2026-10-12"))
        .await?;
    h.call(
        h.space,
        "create_document",
        raw_document(Some(&a), "2026-10-11"),
    )
    .await?;
    let found = read(
        &h,
        "search_documents",
        json!({"filters":{"unassociated":true}}),
    )
    .await?;
    assert_eq!(found["documents"].as_array().unwrap().len(), 1);
    assert_eq!(found["documents"][0]["id"], unassociated["id"]);
    error(
        &h,
        "search_documents",
        json!({"filters":{"unassociated":true,"subject_id":a["id"]}}),
        "validation_failed",
    )
    .await?;
    error(
        &h,
        "document_metric_series",
        json!({"subject_id":a["id"],"metric":"body.weight","from":"2026-10-12","to":"2026-10-11"}),
        "validation_failed",
    )
    .await?;
    Ok(())
}
async fn api_and_direct(h: &S4App, name: &str, args: Value) -> Result<Value> {
    let key = Uuid::now_v7().to_string();
    let reply = api(h, &h.token, name, args.clone(), Some(&key)).await?;
    ensure!(reply.status == StatusCode::OK, "{name}: {}", reply.json());
    let owner = h.app.fixture.owner().await?;
    let before: i64 = sqlx::query_scalar("select count(*) from entity_events")
        .fetch_one(&owner)
        .await?;
    let principal = h.principal(&h.token).await?;
    let effect = h.state.tools.get(name)?.effect();
    let ctx = ToolCtx::begin(
        &h.state.db,
        principal.clone(),
        SpaceId(h.space),
        Some(JoinEpoch(1)),
        effect,
        Invocation {
            idempotency_key: Some(Uuid::new_v5(&principal.user_id.0, key.as_bytes())),
            replay_key: Some(key),
            run_id: None,
            request_id: Uuid::now_v7(),
            now: h.state.clock.now(),
        },
    )
    .await?;
    assert_eq!(
        h.state.tools.invoke(name, args, &ctx).await?,
        reply.json(),
        "{name}"
    );
    let after: i64 = sqlx::query_scalar("select count(*) from entity_events")
        .fetch_one(&owner)
        .await?;
    assert_eq!(before, after);
    owner.close().await;
    Ok(reply.json())
}
#[tokio::test]
async fn every_document_api_tool_succeeds_and_matches_direct_registry_invoke() -> Result<()> {
    let h = harness().await?;
    let s = api_and_direct(
        &h,
        "create_subject",
        json!({"kind":"family_member","name":"虚构入口一致家人"}),
    )
    .await?;
    api_and_direct(
        &h,
        "update_subject",
        json!({"id":s["id"],"expected_version":1,"name":"虚构改名家人"}),
    )
    .await?;
    api_and_direct(
        &h,
        "archive_subject",
        json!({"id":s["id"],"expected_version":2}),
    )
    .await?;
    api_and_direct(&h, "list_subjects", json!({"include_archived":true})).await?;
    let d = api_and_direct(&h, "create_document", raw_document(None, "2026-10-12")).await?;
    api_and_direct(
        &h,
        "update_document",
        json!({"id":d["id"],"expected_version":1,"changes":{"title":"虚构入口一致资料"}}),
    )
    .await?;
    api_and_direct(&h, "get_document", json!({"id":d["id"]})).await?;
    api_and_direct(
        &h,
        "search_documents",
        json!({"filters":{"unassociated":true}}),
    )
    .await?;
    api_and_direct(
        &h,
        "document_metric_series",
        json!({"subject_id":s["id"],"metric":"body.weight"}),
    )
    .await?;
    api_and_direct(
        &h,
        "void_document",
        json!({"id":d["id"],"expected_version":2}),
    )
    .await?;
    api_and_direct(
        &h,
        "restore_document",
        json!({"id":d["id"],"expected_version":3}),
    )
    .await?;
    api_and_direct(
        &h,
        "delete_subject",
        json!({"id":s["id"],"expected_version":3}),
    )
    .await?;
    Ok(())
}

#[tokio::test]
async fn title_only_update_preserves_unitless_number_and_table_after_template_default_added()
-> Result<()> {
    let h = harness().await?;
    let s = subject(&h, "虚构单位家人").await?;
    let mut template = json!({
        "protocol": "jiabu.template/1",
        "id": "myhome.unit_snapshot",
        "version": 1,
        "name": {"zh-Hans": "单位快照", "en": "Unit snapshot"},
        "subjects": [{"kind": "family_member", "min": 1, "max": 1}],
        "fields": [
            {
                "key": "weight",
                "type": "number",
                "label": {"zh-Hans": "体重", "en": "Weight"},
                "metric": "body.weight"
            },
            {
                "key": "measurements",
                "type": "table",
                "label": {"zh-Hans": "测量", "en": "Measurements"},
                "metric": "test.mass",
                "metric_columns": {"item": "item", "value": "value"},
                "columns": [
                    {
                        "key": "item",
                        "type": "single_select",
                        "label": {"zh-Hans": "项目", "en": "Item"},
                        "options": [{
                            "id": "mass",
                            "label": {"zh-Hans": "质量", "en": "Mass"}
                        }]
                    },
                    {
                        "key": "value",
                        "type": "number",
                        "label": {"zh-Hans": "数值", "en": "Value"}
                    }
                ]
            }
        ]
    });
    let mut files = jiabu_tools::templates::official_files();
    files.push(jiabu_tools::templates::TemplateFile {
        filename: "unit_snapshot.json".into(),
        body: template.to_string(),
        official: false,
        error: None,
    });
    let report = h.state.templates.reload(&h.state.db, files).await?;
    assert!(report.rejected.is_empty());
    let args = json!({
        "title": "虚构无单位历史资料",
        "template_id": "myhome.unit_snapshot",
        "subject_ids": [s["id"]],
        "event_date": "2026-10-01",
        "content": {
            "v": 1,
            "items": [
                {
                    "key": "weight",
                    "type": "number",
                    "label": "体重快照",
                    "value": 60,
                    "unit": null
                },
                {
                    "key": "measurements",
                    "type": "table",
                    "label": "测量快照",
                    "value": {
                        "columns": [
                            {"key": "item", "type": "single_select", "label": "项目"},
                            {"key": "value", "type": "number", "label": "数值", "unit": null}
                        ],
                        "rows": [{"item": {"id": "mass", "label": "质量"}, "value": 20}]
                    }
                }
            ]
        }
    });
    let historical = h.call(h.space, "create_document", args.clone()).await?;
    assert!(historical["content"]["items"][0]["unit"].is_null());
    assert!(historical["content"]["items"][1]["value"]["columns"][1]["unit"].is_null());

    template["version"] = json!(2);
    template["fields"][0]["unit"] = json!("kg");
    template["fields"][1]["columns"][1]["unit"] = json!("kg");
    let mut files = jiabu_tools::templates::official_files();
    files.push(jiabu_tools::templates::TemplateFile {
        filename: "unit_snapshot.json".into(),
        body: template.to_string(),
        official: false,
        error: None,
    });
    let report = h.state.templates.reload(&h.state.db, files).await?;
    assert!(report.rejected.is_empty());
    let mut recent_args = args;
    recent_args["title"] = json!("虚构新单位资料");
    recent_args["event_date"] = json!("2026-10-02");
    let recent = h.call(h.space, "create_document", recent_args).await?;
    assert_eq!(recent["content"]["items"][0]["unit"], "kg");
    assert_eq!(
        recent["content"]["items"][1]["value"]["columns"][1]["unit"],
        "kg"
    );
    let mut before = Vec::new();
    for metric in ["body.weight", "test.mass.mass"] {
        let series = read(
            &h,
            "document_metric_series",
            json!({"subject_id": s["id"], "metric": metric}),
        )
        .await?;
        assert_eq!(series["unit"], "kg");
        assert_eq!(series["points"].as_array().unwrap().len(), 1);
        assert_eq!(series["points"][0]["document_id"], recent["id"]);
        assert_eq!(
            series["excluded"],
            json!([{"document_id": historical["id"], "unit": null}])
        );
        before.push(series);
    }

    let updated = h
        .call(
            h.space,
            "update_document",
            json!({
                "id": historical["id"],
                "expected_version": 1,
                "changes": {"title": "虚构只改标题"}
            }),
        )
        .await?;
    assert_eq!(updated["content"], historical["content"]);
    assert!(updated["content"]["items"][0]["unit"].is_null());
    assert!(updated["content"]["items"][1]["value"]["columns"][1]["unit"].is_null());
    let fetched = read(&h, "get_document", json!({"id": historical["id"]})).await?;
    assert_eq!(fetched["content"], historical["content"]);
    for series in before {
        let after = read(
            &h,
            "document_metric_series",
            json!({"subject_id": s["id"], "metric": series["metric"]}),
        )
        .await?;
        assert_eq!(after, series);
    }

    // Explicitly resubmitting content applies the current defaults to those items.
    let resubmitted = h
        .call(
            h.space,
            "update_document",
            json!({
                "id": historical["id"],
                "expected_version": 2,
                "changes": {
                    "content": historical["content"],
                    "event_date": historical["event_date"]
                }
            }),
        )
        .await?;
    assert_eq!(resubmitted["content"]["items"][0]["unit"], "kg");
    assert_eq!(
        resubmitted["content"]["items"][1]["value"]["columns"][1]["unit"],
        "kg"
    );
    for metric in ["body.weight", "test.mass.mass"] {
        let series = read(
            &h,
            "document_metric_series",
            json!({"subject_id": s["id"], "metric": metric}),
        )
        .await?;
        assert_eq!(series["points"].as_array().unwrap().len(), 2);
        assert!(series["excluded"].as_array().unwrap().is_empty());
    }
    Ok(())
}

#[tokio::test]
async fn unknown_templates_return_template_unknown_on_create_and_template_change() -> Result<()> {
    let h = harness().await?;
    error(
        &h,
        "create_document",
        json!({
            "template_id": "myhome.missing",
            "title": "虚构未知模板资料",
            "content": {"v": 1, "items": []}
        }),
        "template_unknown",
    )
    .await?;
    let original = h
        .call(h.space, "create_document", raw_document(None, "2026-10-12"))
        .await?;
    error(
        &h,
        "update_document",
        json!({
            "id": original["id"],
            "expected_version": 1,
            "changes": {"template_id": "myhome.missing"}
        }),
        "template_unknown",
    )
    .await?;
    assert_eq!(
        read(&h, "get_document", json!({"id": original["id"]})).await?,
        original
    );
    Ok(())
}

#[tokio::test]
async fn no_template_content_edit_preserves_explicit_event_date() -> Result<()> {
    let h = harness().await?;
    let original = h
        .call(h.space, "create_document", raw_document(None, "2026-10-01"))
        .await?;
    let mut content = original["content"].clone();
    content["items"][0]["value"] = json!("虚构备注更正");
    let updated = h
        .call(
            h.space,
            "update_document",
            json!({
                "id": original["id"],
                "expected_version": 1,
                "changes": {"content": content}
            }),
        )
        .await?;
    assert_eq!(updated["content"], content);
    assert_eq!(updated["event_date"], "2026-10-01");
    assert_eq!(
        read(&h, "get_document", json!({"id": original["id"]})).await?,
        updated
    );
    Ok(())
}

#[tokio::test]
async fn templated_non_date_content_edit_preserves_explicit_event_date() -> Result<()> {
    let h = harness().await?;
    let template = json!({
        "protocol": "jiabu.template/1",
        "id": "myhome.notes",
        "version": 1,
        "name": {"zh-Hans": "备注", "en": "Notes"},
        "subjects": [],
        "fields": [{
            "key": "note",
            "type": "text",
            "label": {"zh-Hans": "备注", "en": "Notes"}
        }]
    });
    let mut files = jiabu_tools::templates::official_files();
    files.push(jiabu_tools::templates::TemplateFile {
        filename: "notes.json".into(),
        body: template.to_string(),
        official: false,
        error: None,
    });
    let report = h.state.templates.reload(&h.state.db, files).await?;
    assert!(report.rejected.is_empty());
    let mut notes = raw_document(None, "2026-10-01");
    notes["template_id"] = json!("myhome.notes");
    let s = subject(&h, "虚构日期家人").await?;
    let mut vision = typed_document(
        &s,
        "jiabu.vision",
        "exam_date",
        "2026-10-01",
        vec![json!({"key": "note", "type": "text", "label": "备注", "value": "虚构备注"})],
    );
    vision["content"]["items"][0]["value"] = Value::Null;
    vision["event_date"] = json!("2026-10-01");

    // Cover both an undeclared event-date field and a declared but empty one.
    for args in [notes, vision] {
        let original = h.call(h.space, "create_document", args).await?;
        let mut content = original["content"].clone();
        let note = content["items"]
            .as_array_mut()
            .unwrap()
            .iter_mut()
            .find(|item| item["key"] == "note")
            .unwrap();
        note["value"] = json!("虚构备注更正");
        let updated = h
            .call(
                h.space,
                "update_document",
                json!({
                    "id": original["id"],
                    "expected_version": 1,
                    "changes": {
                        "template_id": original["template_id"],
                        "content": content
                    }
                }),
            )
            .await?;
        assert_eq!(updated["content"], content);
        assert_eq!(updated["event_date"], "2026-10-01");
        assert_eq!(
            read(&h, "get_document", json!({"id": original["id"]})).await?,
            updated
        );
    }
    Ok(())
}

#[tokio::test]
async fn changed_template_date_field_updates_event_date() -> Result<()> {
    let h = harness().await?;
    let s = subject(&h, "虚构日期家人").await?;
    let original = h
        .call(
            h.space,
            "create_document",
            typed_document(&s, "jiabu.vision", "exam_date", "2026-10-01", vec![]),
        )
        .await?;
    let mut content = original["content"].clone();
    content["items"][0]["value"] = json!("2026-10-12");
    let updated = h
        .call(
            h.space,
            "update_document",
            json!({
                "id": original["id"],
                "expected_version": 1,
                "changes": {"content": content}
            }),
        )
        .await?;
    assert_eq!(updated["event_date"], "2026-10-12");
    assert_eq!(
        read(&h, "get_document", json!({"id": original["id"]})).await?,
        updated
    );
    Ok(())
}

#[tokio::test]
async fn cleared_template_date_field_falls_back_to_original_recording_date() -> Result<()> {
    let mut h = harness().await?;
    let s = subject(&h, "虚构日期家人").await?;
    let original = h
        .call(
            h.space,
            "create_document",
            typed_document(&s, "jiabu.vision", "exam_date", "2026-10-01", vec![]),
        )
        .await?;
    h.state.clock = std::sync::Arc::new(s4::Fixed(
        chrono::DateTime::parse_from_rfc3339("2026-11-02T00:00:00Z")?.with_timezone(&chrono::Utc),
    ));
    h.app.router = crate::router(h.state.clone());
    let mut content = original["content"].clone();
    content["items"][0]["value"] = Value::Null;
    let cleared = h
        .call(
            h.space,
            "update_document",
            json!({
                "id": original["id"],
                "expected_version": 1,
                "changes": {"content": content}
            }),
        )
        .await?;
    assert_eq!(cleared["event_date"], "2026-10-28");
    assert_eq!(
        read(&h, "get_document", json!({"id": original["id"]})).await?,
        cleared
    );
    let restored = h
        .call(
            h.space,
            "update_document",
            json!({
                "id": original["id"],
                "expected_version": 2,
                "changes": {"content": original["content"]}
            }),
        )
        .await?;
    assert_eq!(restored["event_date"], "2026-10-01");
    content["items"] = json!([]);
    let removed = h
        .call(
            h.space,
            "update_document",
            json!({
                "id": original["id"],
                "expected_version": 3,
                "changes": {"content": content}
            }),
        )
        .await?;
    assert_eq!(removed["event_date"], "2026-10-28");
    let explicit = h
        .call(
            h.space,
            "update_document",
            json!({
                "id": original["id"],
                "expected_version": 4,
                "changes": {"event_date": "2026-10-05"}
            }),
        )
        .await?;
    assert_eq!(explicit["event_date"], "2026-10-05");
    Ok(())
}
