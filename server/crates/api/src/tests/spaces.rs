use super::*;
use jiabu_domain::{SpaceId, UserId};
use sqlx::Row;

struct Actor {
    token: String,
    user: UserId,
    default: Uuid,
}
async fn actor(app: &TestApp, username: &str) -> Result<Actor> {
    let plan = app.fixture.seed(username, "unused-test-hash").await?;
    let token = format!("{}{}", Uuid::now_v7().simple(), Uuid::now_v7().simple());
    let owner = app.fixture.owner().await?;
    sqlx::query("update users set must_change_password=false where id=$1")
        .bind(plan.user_id.0)
        .execute(&owner)
        .await?;
    sqlx::query("insert into sessions(user_id,token_hash,kind,expires_at) values($1,$2,'full',now()+interval '1 day')")
        .bind(plan.user_id.0).bind(crate::credentials::token_hash(&token)).execute(&owner).await?;
    owner.close().await;
    Ok(Actor {
        token,
        user: plan.user_id,
        default: plan.space_id.0,
    })
}
fn headers(key: &str, epoch: i32) -> Vec<(&'static str, String)> {
    vec![
        ("idempotency-key", key.into()),
        ("x-jiabu-join-epoch", epoch.to_string()),
    ]
}
async fn write(
    app: &TestApp,
    token: &str,
    method: &str,
    path: &str,
    body: Value,
    epoch: i32,
) -> Result<Reply> {
    app.request(
        method,
        path,
        body,
        Some(token),
        &headers(&Uuid::now_v7().to_string(), epoch),
    )
    .await
}
async fn create(app: &TestApp, token: &str) -> Result<Uuid> {
    let id = Uuid::now_v7();
    let reply = write(app, token, "POST", "/v1/spaces", json!({"id":id,"name":"示例共享空间","accent_color":"pine","currency":"JPY","timezone":"Asia/Tokyo"}), 1).await?;
    ensure!(
        reply.status == StatusCode::CREATED,
        "create failed: {} {}",
        reply.status,
        reply.json()
    );
    Ok(id)
}
async fn invite(
    app: &TestApp,
    token: &str,
    space: Uuid,
    username: &str,
    epoch: i32,
) -> Result<Uuid> {
    let reply = write(
        app,
        token,
        "POST",
        &format!("/v1/spaces/{space}/invitations"),
        json!({"username":username}),
        epoch,
    )
    .await?;
    ensure!(
        reply.status.is_success(),
        "invite failed: {} {}",
        reply.status,
        reply.json()
    );
    Ok(Uuid::parse_str(
        reply.json()["id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("no invitation ID"))?,
    )?)
}
async fn accept(app: &TestApp, guest: &Actor, invitation: Uuid) -> Result<Value> {
    let reply = write(
        app,
        &guest.token,
        "POST",
        &format!("/v1/me/invitations/{invitation}/accept"),
        Value::Null,
        1,
    )
    .await?;
    ensure!(
        reply.status == StatusCode::OK,
        "accept failed: {} {}",
        reply.status,
        reply.json()
    );
    Ok(reply.json())
}
fn space_entry(body: &Value, id: Uuid) -> Result<&Value> {
    body["spaces"]
        .as_array()
        .and_then(|a| a.iter().find(|s| s["id"] == id.to_string()))
        .ok_or_else(|| anyhow::anyhow!("space absent"))
}
pub(super) fn matrix_body(method: &str, pattern: &str, target: Uuid) -> Value {
    if pattern.ends_with("/transfer-ownership") {
        json!({"member_id":target})
    } else if pattern.ends_with("/members/me") {
        json!({"display_name":"示例成员","expected_version":1})
    } else if pattern.ends_with("/invitations") && method == "POST" {
        json!({"username":"sample"})
    } else if pattern.ends_with("{space_id}") && method == "PATCH" {
        json!({"name":"示例新名","expected_version":1})
    } else if pattern.ends_with("{space_id}") && method == "DELETE" {
        json!({"name":"示例共享空间"})
    } else {
        Value::Null
    }
}

#[tokio::test]
async fn initialization_list_versions_and_idempotency() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let stranger = actor(&app, "stranger").await?;
    let id = Uuid::now_v7();
    let key = Uuid::now_v7().to_string();
    let body = json!({"id":id,"name":"示例共享空间","accent_color":"pine","currency":"USD","timezone":"America/New_York"});
    let first = app
        .request(
            "POST",
            "/v1/spaces",
            body.clone(),
            Some(&token),
            &headers(&key, 1),
        )
        .await?;
    assert_eq!(first.status, StatusCode::CREATED);
    let retry = app
        .request(
            "POST",
            "/v1/spaces",
            body.clone(),
            Some(&token),
            &headers(&key, 1),
        )
        .await?;
    assert_eq!(retry.json(), first.json());
    let changed = app.request("POST","/v1/spaces",json!({"id":id,"name":"另一个名称","accent_color":"pine","currency":"USD","timezone":"America/New_York"}),Some(&token),&headers(&key,1)).await?;
    assert_eq!(changed.json()["code"], "idempotency_key_reused");
    assert_eq!(first.json()["is_default"], false);
    let owner = app.fixture.owner().await?;
    let n: i64 = sqlx::query_scalar("select count(*) from tags where space_id=$1")
        .bind(id)
        .fetch_one(&owner)
        .await?;
    assert_eq!(n, 11);
    let n: i64 =
        sqlx::query_scalar("select count(*) from space_events where space_id=$1 and kind='create'")
            .bind(id)
            .fetch_one(&owner)
            .await?;
    assert_eq!(n, 1);
    let list = app
        .request("GET", "/v1/spaces", Value::Null, Some(&token), &[])
        .await?
        .json();
    assert_eq!(list["spaces"].as_array().map(Vec::len), Some(2));
    let entry = space_entry(&list, id)?;
    assert_eq!(entry["currency"], "USD");
    assert_eq!(entry["timezone"], "America/New_York");
    assert_eq!(entry["role"], "owner");
    assert_eq!(entry["join_epoch"], 1);
    assert_eq!(
        entry["modules"],
        json!({"ledger":"manage","documents":"manage"})
    );
    assert!(space_entry(&list, stranger.default).is_err());
    let rename_key = Uuid::now_v7().to_string();
    let path = format!("/v1/spaces/{id}");
    let before_seq = first.json()["change_seq"]
        .as_i64()
        .ok_or_else(|| anyhow::anyhow!("missing seq"))?;
    let renamed = app
        .request(
            "PATCH",
            &path,
            json!({"name":"示例新名","accent_color":"indigo","expected_version":1}),
            Some(&token),
            &headers(&rename_key, 1),
        )
        .await?;
    assert_eq!(renamed.status, StatusCode::OK);
    assert_eq!(renamed.json()["version"], 2);
    assert!(
        renamed.json()["change_seq"]
            .as_i64()
            .is_some_and(|n| n > before_seq)
    );
    let retry = app
        .request(
            "PATCH",
            &path,
            json!({"expected_version":1,"accent_color":"indigo","name":"示例新名"}),
            Some(&token),
            &headers(&rename_key, 1),
        )
        .await?;
    assert_eq!(retry.json(), renamed.json()); // Version check is after response replay.
    let stale = write(
        &app,
        &token,
        "PATCH",
        &path,
        json!({"name":"旧版本","expected_version":1}),
        1,
    )
    .await?;
    assert_eq!(stale.json()["code"], "version_conflict");
    assert_eq!(stale.json()["current"]["version"], 2);
    let immutable = write(
        &app,
        &token,
        "PATCH",
        &path,
        json!({"currency":"CNY","expected_version":2}),
        1,
    )
    .await?;
    assert_eq!(immutable.status, StatusCode::BAD_REQUEST);
    assert_eq!(
        write(
            &app,
            &token,
            "PATCH",
            &path,
            json!({"name":"新名","expected_version":2}),
            2
        )
        .await?
        .json()["code"],
        "membership_changed"
    );
    assert_eq!(
        app.request(
            "PATCH",
            &path,
            json!({"name":"新名","expected_version":2}),
            Some(&token),
            &[("idempotency-key", Uuid::now_v7().to_string())]
        )
        .await?
        .status,
        StatusCode::BAD_REQUEST
    );
    assert_eq!(
        app.request(
            "PATCH",
            &path,
            json!({"name":"新名","expected_version":2}),
            Some(&token),
            &[("x-jiabu-join-epoch", "1".into())]
        )
        .await?
        .json()["code"],
        "idempotency_key_required"
    );
    for (currency, timezone, accent) in [
        ("BAD", "UTC", "pine"),
        ("CNY", "Invalid/Timezone", "pine"),
        ("CNY", "UTC", "bad"),
    ] {
        let invalid=write(&app,&token,"POST","/v1/spaces",json!({"id":Uuid::now_v7(),"name":"示例","accent_color":accent,"currency":currency,"timezone":timezone}),1).await?;
        assert_eq!(invalid.status, StatusCode::UNPROCESSABLE_ENTITY);
    }
    let seqs: Vec<i64> = sqlx::query_scalar("select change_seq from spaces where id=$1 union all select change_seq from space_members where space_id=$1 union all select g.change_seq from space_member_grants g join space_members m on m.id=g.member_id where m.space_id=$1 union all select change_seq from tags where space_id=$1").bind(id).fetch_all(&owner).await?;
    assert_eq!(
        seqs.len(),
        seqs.iter().collect::<std::collections::HashSet<_>>().len()
    );
    assert_eq!(seqs.len(), 15);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn invitations_privacy_decline_cancel_and_member_permissions() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let guest = actor(&app, "guest").await?;
    let third = actor(&app, "third").await?;
    let disabled = actor(&app, "disabled").await?;
    let owner = app.fixture.owner().await?;
    sqlx::query("update users set disabled_at=now() where id=$1")
        .bind(disabled.user.0)
        .execute(&owner)
        .await?;
    let space = create(&app, &token).await?;
    let invitation = invite(&app, &token, space, "GUEST", 1).await?;
    assert_eq!(invite(&app, &token, space, "guest", 1).await?, invitation);
    let received = app
        .request(
            "GET",
            "/v1/me/invitations",
            Value::Null,
            Some(&guest.token),
            &[],
        )
        .await?
        .json();
    assert_eq!(received["invitations"].as_array().map(Vec::len), Some(1));
    let fields = received["invitations"][0]
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("bad invitation"))?;
    assert_eq!(fields.len(), 3);
    assert_eq!(received["invitations"][0]["space_name"], "示例共享空间");
    assert_eq!(received["invitations"][0]["inviter_display_name"], "sample");
    assert!(
        space_entry(
            &app.request("GET", "/v1/spaces", Value::Null, Some(&guest.token), &[])
                .await?
                .json(),
            space
        )
        .is_err()
    );
    let route = format!("/v1/spaces/{space}/invitations");
    assert_eq!(
        app.request("GET", &route, Value::Null, Some(&guest.token), &[])
            .await?
            .status,
        StatusCode::NOT_FOUND
    );
    assert_eq!(
        write(
            &app,
            &third.token,
            "POST",
            &format!("/v1/me/invitations/{invitation}/accept"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    for _ in 0..2 {
        assert_eq!(
            write(
                &app,
                &guest.token,
                "POST",
                &format!("/v1/me/invitations/{invitation}/decline"),
                Value::Null,
                1
            )
            .await?
            .json()["status"],
            "declined"
        );
    }
    assert_eq!(
        write(
            &app,
            &guest.token,
            "POST",
            &format!("/v1/me/invitations/{invitation}/accept"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    let cancel = write(
        &app,
        &token,
        "POST",
        &format!("/v1/spaces/{space}/invitations/{invitation}/cancel"),
        Value::Null,
        1,
    )
    .await?;
    assert_eq!(cancel.status, StatusCode::CONFLICT);
    assert_eq!(cancel.json()["code"], "conflict");
    assert_eq!(cancel.json()["current"]["status"], "declined");
    let invitation = invite(&app, &token, space, "guest", 1).await?;
    for _ in 0..2 {
        assert_eq!(
            write(
                &app,
                &token,
                "POST",
                &format!("/v1/spaces/{space}/invitations/{invitation}/cancel"),
                Value::Null,
                1
            )
            .await?
            .json()["status"],
            "cancelled"
        );
    }
    assert_eq!(
        write(
            &app,
            &guest.token,
            "POST",
            &format!("/v1/me/invitations/{invitation}/accept"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    let invitation = invite(&app, &token, space, "guest", 1).await?;
    let joined = accept(&app, &guest, invitation).await?;
    assert_eq!(accept(&app, &guest, invitation).await?, joined);
    let guest_member = Uuid::parse_str(
        joined["member_id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("no member"))?,
    )?;
    let mut expected = None;
    for username in ["no-such-user", "disabled", "sample", "guest"] {
        let reply = write(
            &app,
            &token,
            "POST",
            &route,
            json!({"username":username}),
            1,
        )
        .await?;
        assert_eq!(reply.status, StatusCode::UNPROCESSABLE_ENTITY);
        let bytes = normalize_request_id(&reply)?;
        if let Some(previous) = &expected {
            assert_eq!(previous, &bytes);
        }
        expected = Some(bytes);
    }
    assert_eq!(
        app.request("GET", &route, Value::Null, Some(&guest.token), &[])
            .await?
            .status,
        StatusCode::OK
    );
    let third_invitation = invite(&app, &guest.token, space, "third", 1).await?;
    assert_eq!(
        write(
            &app,
            &token,
            "POST",
            &format!("/v1/spaces/{space}/invitations/{third_invitation}/cancel"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    for (method, path, body) in [
        (
            "PATCH",
            format!("/v1/spaces/{space}"),
            json!({"name":"越权","expected_version":1}),
        ),
        (
            "DELETE",
            format!("/v1/spaces/{space}"),
            json!({"name":"示例共享空间"}),
        ),
        (
            "DELETE",
            format!("/v1/spaces/{space}/members/{guest_member}"),
            Value::Null,
        ),
        (
            "POST",
            format!("/v1/spaces/{space}/transfer-ownership"),
            json!({"member_id":guest_member}),
        ),
    ] {
        assert_eq!(
            write(&app, &guest.token, method, &path, body, 1)
                .await?
                .status,
            StatusCode::NOT_FOUND
        );
    }
    let name_key = Uuid::now_v7().to_string();
    let name_path = format!("/v1/spaces/{space}/members/me");
    let name_body = json!({"display_name":"示例来宾","expected_version":1});
    let renamed = app
        .request(
            "PATCH",
            &name_path,
            name_body.clone(),
            Some(&guest.token),
            &headers(&name_key, 1),
        )
        .await?;
    assert_eq!(renamed.json()["version"], 2);
    assert_eq!(
        app.request(
            "PATCH",
            &name_path,
            name_body,
            Some(&guest.token),
            &headers(&name_key, 1)
        )
        .await?
        .json(),
        renamed.json()
    );
    assert_eq!(
        write(
            &app,
            &guest.token,
            "PATCH",
            &name_path,
            json!({"display_name":"旧名","expected_version":1}),
            1
        )
        .await?
        .json()["code"],
        "version_conflict"
    );
    let list = app
        .request("GET", "/v1/spaces", Value::Null, Some(&guest.token), &[])
        .await?
        .json();
    assert_eq!(
        space_entry(&list, space)?["modules"],
        json!({"ledger":"write","documents":"write"})
    );
    let declining = format!("/v1/me/invitations/{third_invitation}/decline");
    assert_eq!(
        write(&app, &third.token, "POST", &declining, Value::Null, 1)
            .await?
            .json()["status"],
        "declined"
    );
    assert_eq!(
        write(
            &app,
            &guest.token,
            "POST",
            &format!("/v1/spaces/{space}/leave"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_eq!(
        write(&app, &third.token, "POST", &declining, Value::Null, 1)
            .await?
            .json()["status"],
        "declined"
    );
    owner.close().await;
    Ok(())
}

async fn seed_runs(owner: &sqlx::PgPool, space: Uuid, member: Uuid) -> Result<Vec<(Uuid, Value)>> {
    let mut result = Vec::new();
    for status in [
        "queued",
        "running",
        "paused",
        "waiting_ai",
        "completed",
        "cancelled",
        "expired",
        "failed",
    ] {
        let row=sqlx::query("insert into agent_runs(space_id,member_id,conversation_id,assistant_message_id,input_entry_id,join_epoch,kind,status,agent_def_version,prompt_snapshot,last_error) values($1,$2,uuidv7(),uuidv7(),uuidv7(),1,'chat',$3,'test-only',decode('00','hex'),'test-original') returning id,to_jsonb(agent_runs) value")
            .bind(space).bind(member).bind(status).fetch_one(owner).await?;
        result.push((row.try_get("id")?, row.try_get("value")?));
    }
    Ok(result)
}
async fn assert_runs(owner: &sqlx::PgPool, runs: &[(Uuid, Value)], cancelled: bool) -> Result<()> {
    for (id, before) in runs {
        let mut expected = before.clone();
        if cancelled
            && ["queued", "running", "paused", "waiting_ai"]
                .contains(&before["status"].as_str().unwrap_or_default())
        {
            expected["status"] = json!("cancelled");
            expected["last_error"] = json!("space_unavailable");
        }
        let after: Value = sqlx::query_scalar("select to_jsonb(r) from agent_runs r where id=$1")
            .bind(id)
            .fetch_one(owner)
            .await?;
        assert_eq!(after, expected); // In S2 even timestamps/leases remain untouched.
    }
    Ok(())
}
async fn assert_routes_gone(
    app: &TestApp,
    token: &str,
    space: Uuid,
    epoch: i32,
    member: Uuid,
) -> Result<()> {
    for (method, pattern) in ISOLATION_MATRIX {
        let path = pattern
            .replace("{space_id}", &space.to_string())
            .replace("{inv_id}", &Uuid::now_v7().to_string())
            .replace("{member_id}", &member.to_string());
        assert_eq!(
            write(
                app,
                token,
                method,
                &path,
                matrix_body(method, pattern, member),
                epoch
            )
            .await?
            .status,
            StatusCode::NOT_FOUND,
            "{method} {pattern}"
        );
    }
    let list = app
        .request("GET", "/v1/spaces", Value::Null, Some(token), &[])
        .await?
        .json();
    assert!(space_entry(&list, space).is_err());
    Ok(())
}

#[tokio::test]
async fn leave_remove_invalidate_invitations_cancel_runs_and_rejoin_reuses_member() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let guest = actor(&app, "guest").await?;
    let waiting = actor(&app, "waiting").await?;
    let space = create(&app, &token).await?;
    let joined = accept(&app, &guest, invite(&app, &token, space, "guest", 1).await?).await?;
    let member = Uuid::parse_str(
        joined["member_id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("missing member"))?,
    )?;
    let owner = app.fixture.owner().await?;
    let owner_member: Uuid =
        sqlx::query_scalar("select id from space_members where space_id=$1 and user_id=$2")
            .bind(space)
            .bind(app.plan.user_id.0)
            .fetch_one(&owner)
            .await?;
    let runs = seed_runs(&owner, space, member).await?;
    let other_member_runs = seed_runs(&owner, space, owner_member).await?;
    let other_space_member: Uuid =
        sqlx::query_scalar("select id from space_members where space_id=$1")
            .bind(guest.default)
            .fetch_one(&owner)
            .await?;
    let other_space_runs = seed_runs(&owner, guest.default, other_space_member).await?;
    let path = format!("/v1/spaces/{space}/members/me");
    let key = Uuid::now_v7().to_string();
    let body = json!({"display_name":"保留的显示名","expected_version":1});
    assert_eq!(
        app.request(
            "PATCH",
            &path,
            body.clone(),
            Some(&guest.token),
            &headers(&key, 1)
        )
        .await?
        .status,
        StatusCode::OK
    );
    let before: Value = sqlx::query_scalar("select to_jsonb(m) from space_members m where id=$1")
        .bind(member)
        .fetch_one(&owner)
        .await?;
    let pending = invite(&app, &guest.token, space, "waiting", 1).await?;
    let grants_before: Vec<i64> = sqlx::query_scalar(
        "select change_seq from space_member_grants where member_id=$1 order by module",
    )
    .bind(member)
    .fetch_all(&owner)
    .await?;
    assert_eq!(
        write(
            &app,
            &guest.token,
            "POST",
            &format!("/v1/spaces/{space}/leave"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_routes_gone(&app, &guest.token, space, 1, member).await?;
    let replay = app
        .request(
            "PATCH",
            &path,
            body.clone(),
            Some(&guest.token),
            &headers(&key, 1),
        )
        .await?;
    assert_eq!(replay.status, StatusCode::NOT_FOUND);
    let state: String = sqlx::query_scalar("select status from space_invitations where id=$1")
        .bind(pending)
        .fetch_one(&owner)
        .await?;
    assert_eq!(state, "cancelled"); // Must already be invalid before the invitee tries acceptance.
    assert_eq!(
        write(
            &app,
            &waiting.token,
            "POST",
            &format!("/v1/me/invitations/{pending}/accept"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    assert_runs(&owner, &runs, true).await?;
    assert_runs(&owner, &other_member_runs, false).await?;
    assert_runs(&owner, &other_space_runs, false).await?;
    let left: Value = sqlx::query_scalar("select to_jsonb(m) from space_members m where id=$1")
        .bind(member)
        .fetch_one(&owner)
        .await?;
    assert_eq!(left["left_reason"], "left");
    assert!(!left["left_at"].is_null());
    assert_eq!(
        left["version"].as_i64(),
        before["version"].as_i64().map(|n| n + 1)
    );
    let grants_left: Vec<i64> = sqlx::query_scalar(
        "select change_seq from space_member_grants where member_id=$1 order by module",
    )
    .bind(member)
    .fetch_all(&owner)
    .await?;
    assert_eq!(grants_before, grants_left);
    let back = accept(&app, &guest, invite(&app, &token, space, "guest", 1).await?).await?;
    assert_eq!(back["member_id"], member.to_string());
    assert_eq!(back["join_epoch"], 2);
    let current: Value = sqlx::query_scalar("select to_jsonb(m) from space_members m where id=$1")
        .bind(member)
        .fetch_one(&owner)
        .await?;
    assert_eq!(current["display_name"], "保留的显示名");
    assert_eq!(current["role"], "member");
    assert_eq!(
        current["version"].as_i64(),
        left["version"].as_i64().map(|n| n + 1)
    );
    assert!(current["change_seq"].as_i64() > left["change_seq"].as_i64());
    let levels: Vec<String> =
        sqlx::query_scalar("select level from space_member_grants where member_id=$1")
            .bind(member)
            .fetch_all(&owner)
            .await?;
    assert_eq!(levels, vec!["write", "write"]);
    assert!(current["left_at"].is_null() && current["left_reason"].is_null());
    assert!(current["joined_at"].as_str() > before["joined_at"].as_str());
    let grants: Vec<i64> = sqlx::query_scalar(
        "select change_seq from space_member_grants where member_id=$1 order by module",
    )
    .bind(member)
    .fetch_all(&owner)
    .await?;
    assert!(
        grants
            .iter()
            .zip(&grants_before)
            .all(|(after, before)| after > before)
    );
    let replay = app
        .request("PATCH", &path, body, Some(&guest.token), &headers(&key, 1))
        .await?;
    assert_eq!(replay.json()["code"], "membership_changed");
    let db = AppDb::connect(&app.fixture.app_url).await?;
    assert!(matches!(
        SpaceTx::begin(
            &db,
            guest.user,
            &[(SpaceId(space), Some(jiabu_domain::JoinEpoch(1)))],
            Mode::Write
        )
        .await,
        Err(jiabu_db::BeginError::MembershipChanged)
    ));
    db.close().await?;
    let pending = invite(&app, &guest.token, space, "waiting", 2).await?;
    let removed_runs = seed_runs(&owner, space, member).await?;
    assert_eq!(
        write(
            &app,
            &token,
            "DELETE",
            &format!("/v1/spaces/{space}/members/{member}"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_routes_gone(&app, &guest.token, space, 2, member).await?;
    assert_runs(&owner, &removed_runs, true).await?;
    let cancelled: String = sqlx::query_scalar("select status from space_invitations where id=$1")
        .bind(pending)
        .fetch_one(&owner)
        .await?;
    assert_eq!(cancelled, "cancelled");
    assert_eq!(
        write(
            &app,
            &waiting.token,
            "POST",
            &format!("/v1/me/invitations/{pending}/accept"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    let reason: String = sqlx::query_scalar("select left_reason from space_members where id=$1")
        .bind(member)
        .fetch_one(&owner)
        .await?;
    assert_eq!(reason, "removed");
    let count: i64 =
        sqlx::query_scalar("select count(*) from space_members where space_id=$1 and user_id=$2")
            .bind(space)
            .bind(guest.user.0)
            .fetch_one(&owner)
            .await?;
    assert_eq!(count, 1);
    let kinds: Vec<String> =
        sqlx::query_scalar("select kind from space_events where space_id=$1 order by id")
            .bind(space)
            .fetch_all(&owner)
            .await?;
    for kind in ["create", "invite", "join", "leave", "rejoin", "remove"] {
        assert!(kinds.iter().any(|k| k == kind), "{kind}");
    }
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn transfer_delete_and_default_space_rules() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let guest = actor(&app, "guest").await?;
    let pending_guest = actor(&app, "pending-guest").await?;
    let space = create(&app, &token).await?;
    let joined = accept(&app, &guest, invite(&app, &token, space, "guest", 1).await?).await?;
    let target = Uuid::parse_str(
        joined["member_id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("missing member"))?,
    )?;
    let owner = app.fixture.owner().await?;
    let source: Uuid =
        sqlx::query_scalar("select id from space_members where space_id=$1 and user_id=$2")
            .bind(space)
            .bind(app.plan.user_id.0)
            .fetch_one(&owner)
            .await?;
    let base = format!("/v1/spaces/{space}");
    assert_eq!(
        write(
            &app,
            &token,
            "POST",
            &format!("{base}/leave"),
            Value::Null,
            1
        )
        .await?
        .json()["code"],
        "space_last_owner"
    );
    assert_eq!(
        write(
            &app,
            &token,
            "DELETE",
            &base,
            json!({"name":"示例共享空间"}),
            1
        )
        .await?
        .json()["code"],
        "space_not_empty"
    );
    assert_eq!(
        write(
            &app,
            &token,
            "POST",
            &format!("{base}/transfer-ownership"),
            json!({"member_id":source}),
            1
        )
        .await?
        .status,
        StatusCode::UNPROCESSABLE_ENTITY
    );
    assert_eq!(
        write(
            &app,
            &token,
            "DELETE",
            &format!("{base}/members/{source}"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::UNPROCESSABLE_ENTITY
    );
    let rename_key = Uuid::now_v7().to_string();
    let rename = json!({"accent_color":"indigo","expected_version":1});
    assert_eq!(
        app.request(
            "PATCH",
            &base,
            rename.clone(),
            Some(&token),
            &headers(&rename_key, 1)
        )
        .await?
        .status,
        StatusCode::OK
    );
    let grants_before: Vec<i64>=sqlx::query_scalar("select g.change_seq from space_member_grants g join space_members m on m.id=g.member_id where m.space_id=$1 order by g.member_id,g.module").bind(space).fetch_all(&owner).await?;
    let before: Vec<(Uuid, i64)> =
        sqlx::query_as("select id,change_seq from space_members where space_id=$1 order by id")
            .bind(space)
            .fetch_all(&owner)
            .await?;
    assert_eq!(
        write(
            &app,
            &token,
            "POST",
            &format!("{base}/transfer-ownership"),
            json!({"member_id":target}),
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_eq!(
        app.request(
            "PATCH",
            &base,
            rename,
            Some(&token),
            &headers(&rename_key, 1)
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    ); // Owner authorization before cached success.
    for (id, seq) in before {
        let row = sqlx::query("select role,version,change_seq from space_members where id=$1")
            .bind(id)
            .fetch_one(&owner)
            .await?;
        assert_eq!(
            row.try_get::<String, _>("role")?,
            if id == target { "owner" } else { "member" }
        );
        assert_eq!(row.try_get::<i32, _>("version")?, 2);
        assert!(row.try_get::<i64, _>("change_seq")? > seq);
        let levels: Vec<String> =
            sqlx::query_scalar("select level from space_member_grants where member_id=$1")
                .bind(id)
                .fetch_all(&owner)
                .await?;
        assert_eq!(levels.len(), 2);
        assert!(
            levels
                .iter()
                .all(|l| l == if id == target { "manage" } else { "write" })
        );
    }
    let grants_after: Vec<i64>=sqlx::query_scalar("select g.change_seq from space_member_grants g join space_members m on m.id=g.member_id where m.space_id=$1 order by g.member_id,g.module").bind(space).fetch_all(&owner).await?;
    assert!(
        grants_after
            .iter()
            .zip(&grants_before)
            .all(|(after, before)| after > before)
    );
    let seqs: Vec<i64>=sqlx::query_scalar("select change_seq from space_members where space_id=$1 union all select g.change_seq from space_member_grants g join space_members m on m.id=g.member_id where m.space_id=$1").bind(space).fetch_all(&owner).await?;
    assert_eq!(seqs.len(), 6);
    assert_eq!(
        seqs.iter().collect::<std::collections::HashSet<_>>().len(),
        6
    );
    assert_eq!(
        write(
            &app,
            &token,
            "POST",
            &format!("{base}/leave"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_routes_gone(&app, &token, space, 1, source).await?;
    let list = app
        .request("GET", "/v1/spaces", Value::Null, Some(&guest.token), &[])
        .await?
        .json();
    assert!(
        space_entry(&list, space)?["members"]
            .as_array()
            .is_some_and(|m| m
                .iter()
                .any(|v| v["id"] == source.to_string() && v["status"] == "left"))
    );
    assert_eq!(
        write(
            &app,
            &guest.token,
            "DELETE",
            &base,
            json!({"name":"错误名称"}),
            1
        )
        .await?
        .json()["code"],
        "space_name_mismatch"
    );
    let pending = invite(&app, &guest.token, space, "pending-guest", 1).await?;
    let runs = seed_runs(&owner, space, target).await?;
    assert_eq!(
        write(
            &app,
            &guest.token,
            "DELETE",
            &base,
            json!({"name":"示例共享空间"}),
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    tokio::time::timeout(std::time::Duration::from_millis(100), app.purge.notified()).await?;
    assert_runs(&owner, &runs, true).await?;
    assert_routes_gone(&app, &guest.token, space, 1, target).await?;
    assert_eq!(
        write(
            &app,
            &pending_guest.token,
            "POST",
            &format!("/v1/me/invitations/{pending}/accept"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    let deleted: bool = sqlx::query_scalar("select deleted_at is not null from spaces where id=$1")
        .bind(space)
        .fetch_one(&owner)
        .await?;
    assert!(deleted);
    let reason: String = sqlx::query_scalar("select left_reason from space_members where id=$1")
        .bind(target)
        .fetch_one(&owner)
        .await?;
    assert_eq!(reason, "space_deleted");
    let kinds: Vec<String> =
        sqlx::query_scalar("select kind from space_events where space_id=$1 order by id")
            .bind(space)
            .fetch_all(&owner)
            .await?;
    assert_eq!(kinds.iter().filter(|k| *k == "transfer").count(), 1);
    assert_eq!(kinds.iter().filter(|k| *k == "delete").count(), 1);
    for (method, suffix, body) in [
        ("DELETE", "", json!({"name":"示例空间"})),
        ("POST", "/leave", Value::Null),
        ("POST", "/invitations", json!({"username":"guest"})),
    ] {
        let reply = write(
            &app,
            &token,
            method,
            &format!("/v1/spaces/{}{suffix}", app.plan.space_id),
            body,
            1,
        )
        .await?;
        assert_eq!(reply.status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(reply.json()["code"], "default_space_forbidden");
    }
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn cross_space_child_ids_and_session_only_routes() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let guest = actor(&app, "guest").await?;
    let space = create(&app, &token).await?;
    let other = create(&app, &token).await?;
    let invitation = invite(&app, &token, other, "guest", 1).await?;
    let foreign = accept(&app, &guest, invitation).await?;
    let member = Uuid::parse_str(
        foreign["member_id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("no member"))?,
    )?;
    let waiting = actor(&app, "waiting").await?;
    let foreign_invitation = invite(&app, &token, other, "waiting", 1).await?;
    for (method, path, body) in [
        (
            "DELETE",
            format!("/v1/spaces/{space}/members/{member}"),
            Value::Null,
        ),
        (
            "POST",
            format!("/v1/spaces/{space}/transfer-ownership"),
            json!({"member_id":member}),
        ),
        (
            "POST",
            format!("/v1/spaces/{space}/invitations/{foreign_invitation}/cancel"),
            Value::Null,
        ),
    ] {
        let foreign = write(&app, &token, method, &path, body, 1).await?;
        assert_eq!(foreign.status, StatusCode::NOT_FOUND);
        let missing = app
            .request(
                "GET",
                &format!("/v1/spaces/{}/invitations", Uuid::now_v7()),
                Value::Null,
                Some(&token),
                &[],
            )
            .await?;
        assert_eq!(
            normalize_request_id(&foreign)?,
            normalize_request_id(&missing)?
        );
    }
    // An actual persisted key is still rejected at the session-only boundary in S2.
    let owner = app.fixture.owner().await?;
    let api_token = "jiabu_pat_sample_test_only";
    sqlx::query("insert into api_keys(user_id,name,token_hash,display_prefix,scope) values($1,'示例密钥',$2,'jiabu_pat_sample','read_write')")
        .bind(app.plan.user_id.0).bind(crate::credentials::token_hash(api_token)).execute(&owner).await?;
    for route in crate::route_catalog()
        .into_iter()
        .filter(|r| r.path.starts_with("/v1/spaces") || r.path.starts_with("/v1/me/invitations"))
    {
        let path = route
            .path
            .replace("{space_id}", &space.to_string())
            .replace("{inv_id}", &foreign_invitation.to_string())
            .replace("{member_id}", &member.to_string());
        let mut body = matrix_body(route.method, route.path, member);
        if route.method == "POST" && route.path == "/v1/spaces" {
            body =
                json!({"id":Uuid::now_v7(),"name":"示例","accent_color":"pine","timezone":"UTC"});
        }
        if route.method != "GET" {
            let missing = app
                .request(
                    route.method,
                    &path,
                    body.clone(),
                    Some(&token),
                    &[("x-jiabu-join-epoch", "1".into())],
                )
                .await?;
            assert_eq!(
                missing.json()["code"],
                "idempotency_key_required",
                "{} {}",
                route.method,
                route.path
            );
        }
        for auth in [None, Some(api_token)] {
            let reply = app
                .request(
                    route.method,
                    &path,
                    body.clone(),
                    auth,
                    &headers(&Uuid::now_v7().to_string(), 1),
                )
                .await?;
            assert!(
                matches!(
                    reply.status,
                    StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN
                ),
                "{} {}",
                route.method,
                route.path
            );
        }
    }
    let live: i64 = sqlx::query_scalar(
        "select count(*) from space_members where space_id=$1 and status='active'",
    )
    .bind(space)
    .fetch_one(&owner)
    .await?;
    assert_eq!(live, 1);
    assert_eq!(
        app.request(
            "GET",
            "/v1/me/invitations",
            Value::Null,
            Some(&waiting.token),
            &[]
        )
        .await?
        .json()["invitations"]
            .as_array()
            .map(Vec::len),
        Some(1)
    );
    owner.close().await;
    Ok(())
}
