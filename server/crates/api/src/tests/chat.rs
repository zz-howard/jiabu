//! Synthetic HTTP conversations against real PostgreSQL; no live providers.
use super::*;
use anyhow::Context;
use futures_util::StreamExt;
use jiabu_ai::{
    mock::{MockProvider, MockStep, TurnScript},
    *,
};
use std::sync::Arc;

async fn submit(app: &TestApp, token: &str, space: Uuid, id: Uuid) -> Result<Reply> {
    app.request(
        "POST",
        &format!("/v1/spaces/{space}/chat/messages"),
        json!({"id":id,"text":"虚构午饭 50"}),
        Some(token),
        &headers(&id.to_string(), 1),
    )
    .await
}
fn message_id(reply: &Reply) -> Result<Uuid> {
    ensure!(
        reply.status == StatusCode::OK,
        "chat response: {} {}",
        reply.status,
        reply.json()
    );
    Ok(reply.json()["messageId"]
        .as_str()
        .context("messageId")?
        .parse()?)
}
async fn checkpoint(app: &TestApp, message: Uuid) -> Result<Value> {
    let owner = app.fixture.owner().await?;
    let value = sqlx::query_scalar("select message from chat_entries where id=$1")
        .bind(message)
        .fetch_one(&owner)
        .await?;
    owner.close().await;
    Ok(value)
}
async fn counts(app: &TestApp) -> Result<(i64, i64, i64)> {
    let owner = app.fixture.owner().await?;
    let value = sqlx::query_as("select (select count(*) from agent_runs), (select count(*) from chat_entries), (select count(*) from ai_calls)")
        .fetch_one(&owner).await?;
    owner.close().await;
    Ok(value)
}

#[tokio::test]
async fn chat_http_capabilities_are_canonical_and_frozen_before_claim() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let space = app.plan.space_id.0;
    let input = Uuid::now_v7();
    let first = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":input,"text":"虚构能力快照"}),
            Some(&token),
            &[
                ("idempotency-key", input.to_string()),
                ("x-jiabu-join-epoch", "1".into()),
                (
                    "chatweave-capabilities",
                    " features=stream.snapshot ; blocks=metric:2,markdown:1 ; v=0.1 ".into(),
                ),
            ],
        )
        .await?;
    let message = message_id(&first)?;
    let owner = app.fixture.owner().await?;
    let (status, origin, frozen): (String, Option<Uuid>, Option<Value>) = sqlx::query_as(
        "select status,origin_request_id,client_capabilities from agent_runs where assistant_message_id=$1",
    )
    .bind(message)
    .fetch_one(&owner)
    .await?;
    assert_eq!(status, "queued");
    assert_eq!(origin, Some(input));
    assert_eq!(
        frozen,
        Some(json!({
            "protocolVersions":["0.1"],
            "blocks":{"markdown":1,"metric":2},
            "features":["stream.snapshot"]
        }))
    );

    let replay = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":input,"text":"虚构能力快照"}),
            Some(&token),
            &[
                ("idempotency-key", input.to_string()),
                ("x-jiabu-join-epoch", "1".into()),
                (
                    "chatweave-capabilities",
                    "v=0.1; blocks=dataset:9; features=stream.activity".into(),
                ),
            ],
        )
        .await?;
    assert_eq!(replay.json(), first.json());
    let after_replay: Option<Value> = sqlx::query_scalar(
        "select client_capabilities from agent_runs where assistant_message_id=$1",
    )
    .bind(message)
    .fetch_one(&owner)
    .await?;
    assert_eq!(after_replay, frozen);

    let absent = Uuid::now_v7();
    let absent_reply = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":absent,"text":"虚构能力快照"}),
            Some(&token),
            &[
                ("idempotency-key", absent.to_string()),
                ("x-jiabu-join-epoch", "1".into()),
            ],
        )
        .await?;
    let absent_message = message_id(&absent_reply)?;
    let absent_frozen: Option<Value> = sqlx::query_scalar(
        "select client_capabilities from agent_runs where assistant_message_id=$1",
    )
    .bind(absent_message)
    .fetch_one(&owner)
    .await?;
    assert_eq!(
        absent_frozen,
        Some(json!({"protocolVersions":[],"blocks":{},"features":[]}))
    );

    let first_run: Uuid =
        sqlx::query_scalar("select id from agent_runs where assistant_message_id=$1")
            .bind(message)
            .fetch_one(&owner)
            .await?;
    let absent_run: Uuid =
        sqlx::query_scalar("select id from agent_runs where assistant_message_id=$1")
            .bind(absent_message)
            .fetch_one(&owner)
            .await?;
    let first_context: Value =
        sqlx::query_scalar("select payload from agent_run_items where run_id=$1 and idx=1")
            .bind(first_run)
            .fetch_one(&owner)
            .await?;
    let absent_context: Value =
        sqlx::query_scalar("select payload from agent_run_items where run_id=$1 and idx=1")
            .bind(absent_run)
            .fetch_one(&owner)
            .await?;
    assert_eq!(first_context, absent_context);

    let mut first_input: Value =
        sqlx::query_scalar("select payload from agent_run_items where run_id=$1 and idx=2")
            .bind(first_run)
            .fetch_one(&owner)
            .await?;
    let mut absent_input: Value =
        sqlx::query_scalar("select payload from agent_run_items where run_id=$1 and idx=2")
            .bind(absent_run)
            .fetch_one(&owner)
            .await?;
    first_input
        .as_object_mut()
        .context("first input object")?
        .remove("submitted_at");
    absent_input
        .as_object_mut()
        .context("absent input object")?
        .remove("submitted_at");
    assert_eq!(first_input, absent_input);
    owner.close().await;
    Ok(())
}
fn done() -> MockStep {
    MockStep::Emit(TurnEvent::Done {
        usage: Usage::default(),
    })
}
fn mock_runtime(
    app: &TestApp,
    scripts: Vec<TurnScript>,
) -> (jiabu_agent::Runtime, Arc<MockProvider>) {
    let model = Uuid::now_v7();
    let config = AiConfig {
        providers: vec![ProviderConfig {
            id: "synthetic".into(),
            kind: "mock".into(),
            base_url: None,
            billing: Billing::Local,
            secret_source: None,
            enabled: true,
            version: 1,
        }],
        models: vec![ModelConfig {
            id: model,
            provider_id: "synthetic".into(),
            model: "fake-model".into(),
            structured: StructuredMode::ToolCall,
            vision: true,
            context_tokens: Some(8192),
            enabled: true,
        }],
        routes: vec![RouteConfig {
            task_kind: TaskKind::Chat,
            position: 0,
            model_id: model,
        }],
        ..AiConfig::default()
    };
    let mock = Arc::new(MockProvider::scripted(
        "synthetic",
        Capabilities {
            structured: StructuredMode::ToolCall,
            vision: true,
            max_images: 8,
            files: false,
            max_files: 0,
            context_tokens: 8192,
        },
        scripts,
    ));
    app.state
        .ai
        .0
        .store(Arc::new(AiRouter::new(config, vec![mock.clone()])));
    (
        jiabu_agent::Runtime::new(
            app.state.db.clone(),
            app.state.ai.clone(),
            app.state.tools.clone(),
            app.state.templates.clone(),
            app.state.chat_hub.clone(),
            Arc::new(jiabu_agent::RuntimeMeter {
                db: app.state.db.clone(),
                token: Uuid::now_v7(),
            }),
        ),
        mock,
    )
}

#[tokio::test]
async fn chat_file_input_resolves_canonical_metadata_and_replay_is_exact() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let space = app.plan.space_id.0;
    let bytes = b"%PDF-1.7\nsynthetic chat file\n%%EOF\n".to_vec();
    let sha = super::s4::hash(&bytes).to_string();
    let uploaded = app
        .raw_request(
            "PUT",
            &format!("/v1/spaces/{space}/files/{sha}"),
            bytes.clone(),
            "application/pdf",
            Some(&token),
            &[("x-jiabu-join-epoch", "1".into())],
        )
        .await?;
    assert_eq!(uploaded.status, StatusCode::NO_CONTENT);

    let id = Uuid::now_v7();
    let body = json!({"id":id,"text":null,"files":[{"sha256":sha.clone(),"name":"账单.pdf"}]});
    let first = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            body.clone(),
            Some(&token),
            &headers(&id.to_string(), 1),
        )
        .await?;
    assert_eq!(first.status, StatusCode::OK);
    let replay = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            body,
            Some(&token),
            &headers(&id.to_string(), 1),
        )
        .await?;
    assert_eq!(first.json(), replay.json());

    let owner = app.fixture.owner().await?;
    let stored: Value = sqlx::query_scalar("select message from chat_entries where id=$1")
        .bind(id)
        .fetch_one(&owner)
        .await?;
    let metadata = &stored["metadata"]["input"]["files"][0];
    assert_eq!(metadata["sha256"], sha);
    assert_eq!(metadata["name"], "账单.pdf");
    assert_eq!(metadata["mime"], "application/pdf");
    assert_eq!(metadata["bytes"], i64::try_from(bytes.len())?);
    assert!(!stored.to_string().contains("JVBER"));
    let member: Uuid =
        sqlx::query_scalar("select id from space_members where space_id=$1 and user_id=$2")
            .bind(space)
            .bind(app.plan.user_id.0)
            .fetch_one(&owner)
            .await?;
    let mut oversized_files = Vec::new();
    for index in 1..=4 {
        let sha = format!("{index:064x}");
        sqlx::query(
            "insert into blobs(sha256,mime,bytes) values(decode($1,'hex'),'application/pdf',$2)",
        )
        .bind(&sha)
        .bind(5 * 1024 * 1024 + 1_i64)
        .execute(&owner)
        .await?;
        sqlx::query("insert into blob_refs(space_id,module,sha256,uploaded_by_member_id) values($1,'chat_file',decode($2,'hex'),$3)")
            .bind(space)
            .bind(&sha)
            .bind(member)
            .execute(&owner)
            .await?;
        oversized_files.push(json!({"sha256":sha,"name":format!("part-{index}.pdf")}));
    }
    owner.close().await;

    let oversized_id = Uuid::now_v7();
    let oversized = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":oversized_id,"text":null,"files":oversized_files}),
            Some(&token),
            &headers(&oversized_id.to_string(), 1),
        )
        .await?;
    assert_eq!(oversized.status, StatusCode::UNPROCESSABLE_ENTITY);

    let owner = app.fixture.owner().await?;
    sqlx::query("update blobs set bytes=5 * 1024 * 1024 where mime='application/pdf' and sha256 in (select sha256 from blob_refs where space_id=$1 and module='chat_file')")
        .bind(space)
        .execute(&owner)
        .await?;
    owner.close().await;
    let boundary_id = Uuid::now_v7();
    let boundary = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":boundary_id,"text":null,"files":oversized_files.clone()}),
            Some(&token),
            &headers(&boundary_id.to_string(), 1),
        )
        .await?;
    assert_eq!(boundary.status, StatusCode::OK);

    let mut reversed_files = oversized_files.clone();
    reversed_files.reverse();
    let reordered = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":boundary_id,"text":null,"files":reversed_files}),
            Some(&token),
            &headers(&boundary_id.to_string(), 1),
        )
        .await?;
    assert_eq!(reordered.json()["code"], "idempotency_conflict");

    let changed_hash = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":id,"text":null,"files":[{"sha256":oversized_files[0]["sha256"],"name":"账单.pdf"}]}),
            Some(&token),
            &headers(&id.to_string(), 1),
        )
        .await?;
    assert_eq!(changed_hash.json()["code"], "idempotency_conflict");

    let owner = app.fixture.owner().await?;
    let fifth_sha = format!("{:064x}", 5);
    sqlx::query(
        "insert into blobs(sha256,mime,bytes) values(decode($1,'hex'),'application/pdf',1)",
    )
    .bind(&fifth_sha)
    .execute(&owner)
    .await?;
    sqlx::query("insert into blob_refs(space_id,module,sha256,uploaded_by_member_id) values($1,'chat_file',decode($2,'hex'),$3)")
        .bind(space)
        .bind(&fifth_sha)
        .bind(member)
        .execute(&owner)
        .await?;
    owner.close().await;
    oversized_files.push(json!({"sha256":fifth_sha,"name":"part-5.pdf"}));
    let too_many_id = Uuid::now_v7();
    let too_many = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":too_many_id,"text":null,"files":oversized_files}),
            Some(&token),
            &headers(&too_many_id.to_string(), 1),
        )
        .await?;
    assert_eq!(too_many.status, StatusCode::UNPROCESSABLE_ENTITY);

    let changed = app
        .request(
            "POST",
            &format!("/v1/spaces/{space}/chat/messages"),
            json!({"id":id,"text":null,"files":[{"sha256":sha.clone(),"name":"other.pdf"}]}),
            Some(&token),
            &headers(&id.to_string(), 1),
        )
        .await?;
    assert_eq!(changed.json()["code"], "idempotency_conflict");
    for files in [
        json!([{"sha256":sha.clone(),"name":"../bad.pdf"}]),
        json!([{"sha256":sha.clone(),"name":"same.pdf"},{"sha256":sha.clone(),"name":"same-again.pdf"}]),
    ] {
        let id = Uuid::now_v7();
        let invalid = app
            .request(
                "POST",
                &format!("/v1/spaces/{space}/chat/messages"),
                json!({"id":id,"text":null,"files":files}),
                Some(&token),
                &headers(&id.to_string(), 1),
            )
            .await?;
        assert_eq!(invalid.status, StatusCode::UNPROCESSABLE_ENTITY);
    }
    Ok(())
}

#[tokio::test]
async fn chat_http_submit_stop_retry_active_and_sse_resume() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let space = app.plan.space_id.0;
    let input = Uuid::now_v7();
    let first = submit(&app, &token, space, input).await?;
    let message = message_id(&first)?;
    let replay = submit(&app, &token, space, input).await?;
    assert_eq!(first.json(), replay.json());
    let base = format!("/v1/spaces/{space}/chat");
    let active = app
        .request(
            "GET",
            &format!("{base}/active-messages"),
            Value::Null,
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(active.status, StatusCode::OK);
    assert_eq!(
        active.json()["messages"][0]["messageId"],
        message.to_string()
    );
    assert_eq!(active.json()["messages"][0]["lastSeq"], 1);
    assert_eq!(active.json()["messages"][0]["replyTo"], input.to_string());
    let changed = app
        .request(
            "POST",
            &format!("{base}/messages"),
            json!({"id":input,"text":"另一个虚构输入"}),
            Some(&token),
            &headers(&input.to_string(), 1),
        )
        .await?;
    assert_eq!(changed.json()["code"], "idempotency_conflict");
    let mismatch = app
        .request(
            "POST",
            &format!("{base}/messages"),
            json!({"id":Uuid::now_v7(),"text":"虚构"}),
            Some(&token),
            &headers(&input.to_string(), 1),
        )
        .await?;
    assert_eq!(mismatch.json()["code"], "idempotency_key_mismatch");
    let stale = app
        .request(
            "POST",
            &format!("{base}/messages"),
            json!({"id":input,"text":"虚构午饭 50"}),
            Some(&token),
            &headers(&input.to_string(), 2),
        )
        .await?;
    assert_eq!(stale.json()["code"], "membership_changed");
    // Open SSE before stopping: this must observe the same hub as the service.
    let response = app
        .router
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("{base}/messages/{message}/stream"))
                .header("authorization", format!("Bearer {token}"))
                .body(Body::empty())?,
        )
        .await?;
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(response.headers()["content-type"], "text/event-stream");
    assert_eq!(response.headers()["cache-control"], "no-store");
    assert_eq!(response.headers()["x-accel-buffering"], "no");
    let mut stream = response.into_body().into_data_stream();
    let mut bytes = stream.next().await.context("message.start")??.to_vec();
    // The ordinary 30-second response deadline must not cut off an SSE body.
    tokio::time::pause();
    tokio::time::advance(std::time::Duration::from_secs(31)).await;
    tokio::time::resume();
    let stopped = write(
        &app,
        &token,
        "POST",
        &format!("{base}/messages/{message}/stop"),
        Value::Null,
        1,
    )
    .await?;
    assert_eq!(stopped.json(), json!({"status":"accepted"}));
    tokio::time::timeout(std::time::Duration::from_secs(5), async {
        while let Some(chunk) = stream.next().await {
            bytes.extend_from_slice(&chunk?);
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    let text = std::str::from_utf8(&bytes)?;
    assert_eq!(text.matches("event: message.end").count(), 1);
    let mut fold = jiabu_chat::FoldState::new();
    for line in text.lines().filter_map(|line| line.strip_prefix("data: ")) {
        fold.apply(jiabu_chat::StreamEvent(serde_json::from_str(line)?))?;
    }
    assert_eq!(fold.message()?.0, checkpoint(&app, message).await?);
    let resumed = app
        .request(
            "GET",
            &format!("{base}/messages/{message}/stream?after=invalid"),
            Value::Null,
            Some(&token),
            &[("last-event-id", "1".into())],
        )
        .await?;
    assert_eq!(resumed.status, StatusCode::OK);
    assert!(!std::str::from_utf8(&resumed.bytes)?.contains("event: message.start"));
    let bad = app
        .request(
            "GET",
            &format!("{base}/messages/{message}/stream?after=-1"),
            Value::Null,
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(bad.status, StatusCode::BAD_REQUEST);
    let active = app
        .request(
            "GET",
            &format!("{base}/active-messages"),
            Value::Null,
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(active.json(), json!({"messages":[]}));
    // Once reliable events are gone, only clients declaring snapshot support get a snapshot.
    let owner = app.fixture.owner().await?;
    sqlx::query("delete from chat_stream_events where message_id=$1")
        .bind(message)
        .execute(&owner)
        .await?;
    owner.close().await;
    let missing_log = app
        .request(
            "GET",
            &format!("{base}/messages/{message}/stream"),
            Value::Null,
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(missing_log.status, StatusCode::OK);
    assert!(std::str::from_utf8(&missing_log.bytes)?.contains("resume_unavailable"));
    let future_protocol = app
        .request(
            "GET",
            &format!("{base}/messages/{message}/stream"),
            Value::Null,
            Some(&token),
            &[(
                "chatweave-capabilities",
                "v=0.2; features=stream.resume,stream.snapshot,stream.activity".into(),
            )],
        )
        .await?;
    assert_eq!(future_protocol.status, StatusCode::OK);
    assert!(std::str::from_utf8(&future_protocol.bytes)?.contains("resume_unavailable"));
    let snapshot = app
        .request(
            "GET",
            &format!("{base}/messages/{message}/stream"),
            Value::Null,
            Some(&token),
            &[(
                "chatweave-capabilities",
                "v=0.1; features=stream.resume,stream.snapshot".into(),
            )],
        )
        .await?;
    assert_eq!(snapshot.status, StatusCode::OK);
    let text = std::str::from_utf8(&snapshot.bytes)?;
    let data = text
        .lines()
        .find_map(|line| line.strip_prefix("data: "))
        .context("snapshot")?;
    let snapshot: Value = serde_json::from_str(data)?;
    assert_eq!(snapshot["type"], "message.snapshot");
    assert_eq!(snapshot["message"], checkpoint(&app, message).await?);
    let path = format!("{base}/messages/{message}/retry");
    let retry_key = Uuid::now_v7();
    let retry_headers = [
        ("idempotency-key", retry_key.to_string()),
        ("x-jiabu-join-epoch", "1".into()),
        (
            "chatweave-capabilities",
            "v=0.1; blocks=markdown:1,metric:1; features=".into(),
        ),
    ];
    let a = app
        .request("POST", &path, Value::Null, Some(&token), &retry_headers)
        .await?;
    // The first response may have been lost: replaying the exact operation key
    // returns the already accepted child and never replaces its snapshot.
    let b = app
        .request("POST", &path, Value::Null, Some(&token), &retry_headers)
        .await?;
    assert_eq!(message_id(&a)?, message_id(&b)?);
    assert_ne!(message_id(&a)?, message);

    let second_input = Uuid::now_v7();
    let second = message_id(&submit(&app, &token, space, second_input).await?)?;
    write(
        &app,
        &token,
        "POST",
        &format!("{base}/messages/{second}/stop"),
        Value::Null,
        1,
    )
    .await?;
    let second_path = format!("{base}/messages/{second}/retry");
    let key_a = Uuid::now_v7();
    let key_b = Uuid::now_v7();
    let headers_a = [
        ("idempotency-key", key_a.to_string()),
        ("x-jiabu-join-epoch", "1".into()),
        (
            "chatweave-capabilities",
            "v=0.1; blocks=metric:1; features=".into(),
        ),
    ];
    let headers_b = [
        ("idempotency-key", key_b.to_string()),
        ("x-jiabu-join-epoch", "1".into()),
        (
            "chatweave-capabilities",
            "v=0.1; blocks=dataset:1; features=".into(),
        ),
    ];
    let (different_a, different_b) = tokio::join!(
        app.request("POST", &second_path, Value::Null, Some(&token), &headers_a,),
        app.request("POST", &second_path, Value::Null, Some(&token), &headers_b,)
    );
    let (different_a, different_b) = (different_a?, different_b?);
    let (winner, loser, winning_key, winning_block) = if different_a.status == StatusCode::OK {
        (different_a, different_b, key_a, "metric")
    } else {
        (different_b, different_a, key_b, "dataset")
    };
    assert_eq!(loser.status, StatusCode::CONFLICT);
    assert_eq!(loser.json()["code"], "retry_already_accepted");
    let winning_message = message_id(&winner)?;
    let owner = app.fixture.owner().await?;
    let (stored_key, stored_capabilities): (Option<Uuid>, Option<Value>) = sqlx::query_as(
        "select origin_request_id,client_capabilities from agent_runs where assistant_message_id=$1",
    )
    .bind(winning_message)
    .fetch_one(&owner)
    .await?;
    owner.close().await;
    assert_eq!(stored_key, Some(winning_key));
    assert_eq!(
        stored_capabilities,
        Some(json!({
            "protocolVersions":["0.1"],
            "blocks":{(winning_block):1},
            "features":[]
        }))
    );
    assert_eq!(counts(&app).await?, (4, 6, 0));
    Ok(())
}

#[tokio::test]
async fn chat_http_action_answers_from_second_session_and_replays_bound_receipt() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let second = app.token().await?;
    let space = app.plan.space_id.0;
    let (runtime, mock) = mock_runtime(&app, vec![vec![MockStep::Emit(TurnEvent::ToolCall {
        call_id: "question".into(), name: "ask_user".into(),
        args_raw: json!({"prompt":"虚构用途","options":[{"id":"dining","label":"餐饮"},{"id":"transport","label":"交通"}]}).to_string(),
    }), done()], vec![MockStep::Emit(TurnEvent::TextDelta("已回答 / Answered".into())), done()]]);
    let message = message_id(&submit(&app, &token, space, Uuid::now_v7()).await?)?;
    assert!(runtime.work_once(Uuid::now_v7()).await?);
    let cp = checkpoint(&app, message).await?;
    assert_eq!(cp["status"], "paused");
    let active = app
        .request(
            "GET",
            &format!("/v1/spaces/{space}/chat/active-messages"),
            Value::Null,
            Some(&second),
            &[],
        )
        .await?;
    assert_eq!(
        active.json()["messages"][0]["messageId"],
        message.to_string()
    );
    assert_eq!(active.json()["messages"][0]["status"], "paused");
    let id = Uuid::now_v7();
    let action = json!({"protocolVersion":"0.1","id":id,"context":{"conversationId":cp["conversationId"],"messageId":message,"blockId":cp["interrupt"]["blockId"]},"type":"choice.select","target":"clarification.answer","payload":{"selected":["dining"]}});
    let path = format!("/v1/spaces/{space}/chat/actions");
    let mismatch = app
        .request(
            "POST",
            &path,
            action.clone(),
            Some(&second),
            &headers(&Uuid::now_v7().to_string(), 1),
        )
        .await?;
    assert_eq!(mismatch.json()["code"], "idempotency_key_mismatch");
    let mut invalid = action.clone();
    invalid["payload"]["selected"] = json!(["not-a-stored-option"]);
    let rejected = app
        .request(
            "POST",
            &path,
            invalid,
            Some(&second),
            &headers(&id.to_string(), 1),
        )
        .await?;
    assert_eq!(rejected.status, StatusCode::UNPROCESSABLE_ENTITY);
    let accepted = app
        .request(
            "POST",
            &path,
            action.clone(),
            Some(&second),
            &headers(&id.to_string(), 1),
        )
        .await?;
    assert_eq!(accepted.status, StatusCode::OK);
    assert_eq!(
        accepted.json(),
        json!({"status":"accepted","resume":{"messageId":message}})
    );
    let replay = app
        .request(
            "POST",
            &path,
            action.clone(),
            Some(&token),
            &headers(&id.to_string(), 1),
        )
        .await?;
    assert_eq!(accepted.json(), replay.json());
    let mut changed = action;
    changed["payload"]["selected"] = json!(["transport"]);
    let conflict = app
        .request(
            "POST",
            &path,
            changed,
            Some(&token),
            &headers(&id.to_string(), 1),
        )
        .await?;
    assert_eq!(conflict.json()["code"], "idempotency_conflict");
    assert!(runtime.work_once(Uuid::now_v7()).await?);
    assert_eq!(checkpoint(&app, message).await?["status"], "complete");
    assert_eq!(mock.requests().len(), 2);
    Ok(())
}

#[tokio::test]
async fn chat_http_other_member_and_foreign_space_are_identical_404s() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let guest = actor(&app, "chat-guest").await?;
    let space = create(&app, &token).await?;
    accept(
        &app,
        &guest,
        invite(&app, &token, space, "chat-guest", 1).await?,
    )
    .await?;
    let message = message_id(&submit(&app, &token, space, Uuid::now_v7()).await?)?;
    let cp = checkpoint(&app, message).await?;
    let action = Uuid::now_v7();
    for (method, suffix, body) in [
        ("GET", format!("messages/{message}/stream"), Value::Null),
        ("POST", format!("messages/{message}/stop"), Value::Null),
        ("POST", format!("messages/{message}/retry"), Value::Null),
        (
            "POST",
            "actions".into(),
            json!({"protocolVersion":"0.1","id":action,"context":{"conversationId":cp["conversationId"],"messageId":message,"blockId":"question"},"type":"choice.select","target":"clarification.answer","payload":{"selected":["dining"]}}),
        ),
    ] {
        let denied = app
            .request(
                method,
                &format!("/v1/spaces/{space}/chat/{suffix}"),
                body.clone(),
                Some(&guest.token),
                &headers(&action.to_string(), 1),
            )
            .await?;
        assert_eq!(denied.status, StatusCode::NOT_FOUND);
        let foreign = app
            .request(
                method,
                &format!("/v1/spaces/{}/chat/{suffix}", guest.default),
                body,
                Some(&guest.token),
                &headers(&action.to_string(), 1),
            )
            .await?;
        assert_eq!(
            normalize_request_id(&denied)?,
            normalize_request_id(&foreign)?
        );
    }
    let active = app
        .request(
            "GET",
            &format!("/v1/spaces/{space}/chat/active-messages"),
            Value::Null,
            Some(&guest.token),
            &[],
        )
        .await?;
    assert_eq!(active.json(), json!({"messages":[]}));
    assert_eq!(checkpoint(&app, message).await?["status"], "streaming");
    Ok(())
}

#[tokio::test]
async fn api_key_rejected_by_every_chat_route_without_runs_or_ai_calls() -> Result<()> {
    let mut app = TestApp::new(false).await?;
    super::super::api_keys::high_limits(&mut app).await?;
    let session = app.token().await?;
    for scope in ["read", "read_write"] {
        let (_, key) = super::super::api_keys::issue(&app, &session, scope).await?;
        for (method, pattern) in ISOLATION_MATRIX
            .iter()
            .filter(|(_, path)| path.contains("/chat/"))
        {
            let path = pattern
                .replace("{space_id}", &app.plan.space_id.to_string())
                .replace("{message_id}", &Uuid::now_v7().to_string());
            let reply = app
                .request(
                    method,
                    &path,
                    json!({"id":Uuid::now_v7(),"text":"虚构"}),
                    Some(&key),
                    &[],
                )
                .await?;
            assert_eq!(reply.status, StatusCode::FORBIDDEN);
            assert_eq!(reply.json()["code"], "api_key_ai_not_allowed");
        }
    }
    assert_eq!(counts(&app).await?, (0, 0, 0));
    Ok(())
}

#[tokio::test]
async fn sync_push_disguised_ai_submission_never_creates_runs_or_messages() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let space = app.plan.space_id;
    for fields in [
        json!({"kind":"chat_send","text":"虚构"}),
        json!({"tool":"chat_send","args":{"text":"虚构"}}),
        json!({"tool":"ask_user","args":{"prompt":"虚构"}}),
    ] {
        let mut op = json!({"op_id":Uuid::now_v7(),"space_id":space,"join_epoch":1,"request_id":Uuid::now_v7()});
        op.as_object_mut()
            .context("envelope")?
            .extend(fields.as_object().context("fields")?.clone());
        let reply = app
            .request(
                "POST",
                "/v1/sync/push",
                json!({"ops":[op]}),
                Some(&token),
                &[],
            )
            .await?;
        assert_eq!(reply.status, StatusCode::OK);
        assert_eq!(reply.json()["results"][0]["status"], "rejected");
    }
    assert_eq!(counts(&app).await?, (0, 0, 0));
    Ok(())
}

#[test]
fn chat_openapi_describes_session_headers_cursor_and_active_reply_contract() -> Result<()> {
    let doc = serde_json::to_value(crate::openapi())?;
    for (method, path) in ISOLATION_MATRIX
        .iter()
        .filter(|(_, path)| path.contains("/chat/"))
    {
        let operation = &doc["paths"][*path][method.to_ascii_lowercase()];
        assert!(operation.is_object(), "{method} {path}");
        assert!(operation["responses"]["200"].is_object());
        assert!(operation["responses"]["403"].is_object());
        assert!(operation["responses"]["404"].is_object());
        assert!(!operation.to_string().contains("Step 1"));
        if *method == "POST" {
            let parameters = operation["parameters"]
                .as_array()
                .context("write headers")?;
            for name in ["X-Jiabu-Join-Epoch", "Idempotency-Key"] {
                assert!(
                    parameters
                        .iter()
                        .any(|p| p["name"] == name && p["in"] == "header" && p["required"] == true)
                );
            }
        }
    }
    let parameters = doc["paths"]["/v1/spaces/{space_id}/chat/messages/{message_id}/stream"]["get"]
        ["parameters"]
        .as_array()
        .context("stream headers")?;
    for name in ["Last-Event-ID", "after", "ChatWeave-Capabilities"] {
        assert!(parameters.iter().any(|p| p["name"] == name));
    }
    let active = &doc["components"]["schemas"]["ActiveMessage"]["properties"];
    for field in [
        "messageId",
        "conversationId",
        "lastSeq",
        "replyTo",
        "status",
    ] {
        assert!(active[field].is_object());
    }
    Ok(())
}

#[tokio::test]
async fn chat_http_waiting_ai_remains_active_and_stop_never_calls_provider() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let space = app.plan.space_id.0;
    let runtime = jiabu_agent::Runtime::new(
        app.state.db.clone(),
        app.state.ai.clone(),
        app.state.tools.clone(),
        app.state.templates.clone(),
        app.state.chat_hub.clone(),
        Arc::new(jiabu_agent::RuntimeMeter {
            db: app.state.db.clone(),
            token: Uuid::now_v7(),
        }),
    );
    let message = message_id(&submit(&app, &token, space, Uuid::now_v7()).await?)?;
    assert!(runtime.work_once(Uuid::now_v7()).await?);
    let owner = app.fixture.owner().await?;
    let status: String =
        sqlx::query_scalar("select status from agent_runs where assistant_message_id=$1")
            .bind(message)
            .fetch_one(&owner)
            .await?;
    assert_eq!(status, "waiting_ai");
    owner.close().await;
    let active = app
        .request(
            "GET",
            &format!("/v1/spaces/{space}/chat/active-messages"),
            Value::Null,
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(
        active.json()["messages"][0]["messageId"],
        message.to_string()
    );
    let stop = write(
        &app,
        &token,
        "POST",
        &format!("/v1/spaces/{space}/chat/messages/{message}/stop"),
        Value::Null,
        1,
    )
    .await?;
    assert_eq!(stop.status, StatusCode::OK);
    assert!(!runtime.work_once(Uuid::now_v7()).await?);
    assert_eq!(counts(&app).await?, (1, 2, 0));
    Ok(())
}

#[tokio::test]
async fn chat_http_stop_running_text_preserves_output_and_closes_open_markdown() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let space = app.plan.space_id.0;
    let barrier = Arc::new(tokio::sync::Barrier::new(2));
    let (runtime, mock) = mock_runtime(
        &app,
        vec![vec![
            MockStep::Emit(TurnEvent::TextDelta(
                "虚构已持久化的模型输出 / Synthetic persisted model output".into(),
            )),
            MockStep::Barrier(barrier.clone()),
            MockStep::Delay(std::time::Duration::from_secs(30)),
            done(),
        ]],
    );
    let message = message_id(&submit(&app, &token, space, Uuid::now_v7()).await?)?;
    let work = tokio::spawn(async move { runtime.work_once(Uuid::now_v7()).await });
    barrier.wait().await;
    let owner = app.fixture.owner().await?;
    let status: String =
        sqlx::query_scalar("select status from agent_runs where assistant_message_id=$1")
            .bind(message)
            .fetch_one(&owner)
            .await?;
    assert_eq!(status, "running");
    owner.close().await;
    let active = app
        .request(
            "GET",
            &format!("/v1/spaces/{space}/chat/active-messages"),
            Value::Null,
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(
        active.json()["messages"][0]["messageId"],
        message.to_string()
    );
    let stopped = write(
        &app,
        &token,
        "POST",
        &format!("/v1/spaces/{space}/chat/messages/{message}/stop"),
        Value::Null,
        1,
    )
    .await?;
    assert_eq!(stopped.status, StatusCode::OK);
    tokio::time::timeout(std::time::Duration::from_secs(5), work).await???;
    let cp = checkpoint(&app, message).await?;
    assert_eq!(cp["status"], "interrupted");
    let text = cp["fallbackText"].as_str().context("terminal text")?;
    assert!(text.contains("虚构已持久化的模型输出"));
    assert!(text.contains("已保存 0 项"));
    assert_eq!(mock.requests().len(), 1);
    Ok(())
}
