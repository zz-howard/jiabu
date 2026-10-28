use super::*;
use chrono::{DateTime, Utc};
use jiabu_tools::{Effect, Exposure};
use sqlx::Row;
use std::{
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::Duration,
};

fn idem(value: &str) -> [(&str, String); 1] {
    [("idempotency-key", value.to_owned())]
}
pub(super) async fn issue(app: &TestApp, session: &str, scope: &str) -> Result<(Uuid, String)> {
    let reply = app
        .request(
            "POST",
            "/v1/me/api-keys",
            json!({"name":"示例脚本","scope":scope}),
            Some(session),
            &idem(&Uuid::now_v7().to_string()),
        )
        .await?;
    ensure!(
        reply.status == StatusCode::CREATED,
        "key creation failed: {}",
        reply.json()
    );
    Ok((
        Uuid::parse_str(
            reply.json()["id"]
                .as_str()
                .ok_or_else(|| anyhow::anyhow!("missing id"))?,
        )?,
        reply.json()["key"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("missing key"))?
            .to_owned(),
    ))
}
async fn configure_limits(
    app: &mut TestApp,
    limits: jiabu_tools::api_key::ApiKeyLimits,
    clock: Arc<Clock>,
) -> Result<AppState> {
    let state = AppState::new(AppDb::connect(&app.fixture.app_url).await?)
        .await
        .map_err(anyhow::Error::msg)?
        .with_api_key_limiter(Arc::new(jiabu_tools::api_key::ApiKeyLimiter::new(
            limits, clock,
        )))
        .map_err(anyhow::Error::msg)?;
    app.router = crate::router(state.clone());
    app.state = state.clone();
    Ok(state)
}
pub(super) async fn high_limits(app: &mut TestApp) -> Result<()> {
    configure_limits(
        app,
        jiabu_tools::api_key::ApiKeyLimits {
            read_per_minute: 1000,
            write_per_minute: 1000,
            unknown_per_minute: 60,
        },
        Arc::new(Clock::default()),
    )
    .await?;
    Ok(())
}
async fn tool(
    app: &TestApp,
    token: &str,
    space: Uuid,
    name: &str,
    args: Value,
    key: Option<&str>,
) -> Result<Reply> {
    let headers = key.map(idem).map(Vec::from).unwrap_or_default();
    app.request(
        "POST",
        &format!("/v1/spaces/{space}/tools/{name}"),
        args,
        Some(token),
        &headers,
    )
    .await
}
async fn write_tag(app: &TestApp, token: &str, key: &str) -> Result<Reply> {
    tool(
        app,
        token,
        app.plan.space_id.0,
        "create_tag",
        json!({"name":"示例自建标签"}),
        Some(key),
    )
    .await
}
async fn audit_count(owner: &sqlx::PgPool, id: Uuid) -> Result<i64> {
    Ok(
        sqlx::query_scalar("select count(*) from api_key_audit where api_key_id=$1")
            .bind(id)
            .fetch_one(owner)
            .await?,
    )
}
async fn assert_secret_absent(owner: &sqlx::PgPool, secret: &str) -> Result<()> {
    let tables: Vec<String> =
        sqlx::query_scalar("select tablename from pg_tables where schemaname='public'")
            .fetch_all(owner)
            .await?;
    let hex: String = secret
        .as_bytes()
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect();
    for table in tables {
        let identifier = table.replace('"', "\"\"");
        // Scan every column, including a bytea accidentally containing UTF-8
        // plaintext. Return only a boolean, never dump the matching row.
        let sql = format!(
            "select exists(select 1 from public.\"{identifier}\" t where strpos(to_jsonb(t)::text,$1)>0 or strpos(to_jsonb(t)::text,$2)>0)"
        );
        let found: bool = sqlx::query_scalar(sqlx::AssertSqlSafe(sql))
            .bind(secret)
            .bind(&hex)
            .fetch_one(owner)
            .await?;
        assert!(!found, "full PAT persisted in public.{table}");
    }
    Ok(())
}

#[tokio::test]
async fn management_once_only_hashes_and_safe_replay() -> Result<()> {
    use tracing::instrument::WithSubscriber;
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let buffer = Arc::new(std::sync::Mutex::new(Vec::new()));
    let subscriber = tracing_subscriber::fmt()
        .json()
        .with_max_level(tracing::Level::TRACE)
        .with_writer(LogWriter(buffer.clone()))
        .finish();
    let body = json!({"name":"  示例脚本  ","scope":"read_write"});
    let first = app
        .request(
            "POST",
            "/v1/me/api-keys",
            body.clone(),
            Some(&session),
            &idem("create-once"),
        )
        .with_subscriber(subscriber)
        .await?;
    assert_eq!(first.status, StatusCode::CREATED);
    let secret = first.json()["key"].as_str().unwrap().to_owned();
    let id = Uuid::parse_str(first.json()["id"].as_str().unwrap())?;
    assert!(crate::api_key_token::valid(&secret));
    let replay = app
        .request(
            "POST",
            "/v1/me/api-keys",
            body,
            Some(&session),
            &idem("create-once"),
        )
        .await?;
    assert_eq!(replay.status, StatusCode::OK);
    assert_eq!(
        replay.json(),
        json!({"id":id,"created":true,"plaintext_available":false})
    );
    let owner = app.fixture.owner().await?;
    let row=sqlx::query("select token_hash,display_prefix,name,extract(epoch from expires_at-created_at)::bigint lifetime from api_keys where id=$1").bind(id).fetch_one(&owner).await?;
    assert_eq!(
        row.try_get::<Vec<u8>, _>("token_hash")?,
        crate::credentials::token_hash(&secret)
    );
    assert_eq!(row.try_get::<String, _>("display_prefix")?, secret[..16]);
    assert_eq!(row.try_get::<String, _>("name")?, "示例脚本");
    assert!((row.try_get::<i64, _>("lifetime")? - 90 * 86400).abs() < 5);
    let stored: Value =
        sqlx::query_scalar("select response_body from idempotency where key='create-once'")
            .fetch_one(&owner)
            .await?;
    assert_eq!(stored, json!({"id":id}));
    let log = String::from_utf8(buffer.lock().unwrap().clone())?;
    assert!(!log.is_empty());
    assert!(!log.contains(&secret));
    let conflict = app
        .request(
            "POST",
            "/v1/me/api-keys",
            json!({"name":"另一示例","scope":"read"}),
            Some(&session),
            &idem("create-once"),
        )
        .await?;
    assert_eq!(conflict.json()["code"], "idempotency_key_reused");
    // Only a name is mutable. Repeated revocation preserves the first source/time.
    let renamed = app
        .request(
            "PATCH",
            &format!("/v1/me/api-keys/{id}"),
            json!({"name":"  改名示例  "}),
            Some(&session),
            &idem("rename"),
        )
        .await?;
    assert_eq!(renamed.json()["name"], "改名示例");
    for extra in [
        "scope",
        "expires_at",
        "user_id",
        "revoked_at",
        "display_prefix",
    ] {
        let mut body = json!({"name":"示例"});
        body[extra] = json!("forbidden");
        assert_eq!(
            app.request(
                "PATCH",
                &format!("/v1/me/api-keys/{id}"),
                body,
                Some(&session),
                &idem(&Uuid::now_v7().to_string())
            )
            .await?
            .status,
            StatusCode::BAD_REQUEST
        );
    }
    let revoke_path = format!("/v1/me/api-keys/{id}/revoke");
    let revoked = app
        .request(
            "POST",
            &revoke_path,
            Value::Null,
            Some(&session),
            &idem("revoke"),
        )
        .await?;
    assert_eq!(revoked.json()["revoked_by"], "user");
    let again = app
        .request(
            "POST",
            &revoke_path,
            Value::Null,
            Some(&session),
            &idem("revoke-again"),
        )
        .await?;
    assert_eq!(revoked.json(), again.json());
    let list = app
        .request("GET", "/v1/me/api-keys", Value::Null, Some(&session), &[])
        .await?;
    assert_eq!(list.json()["api_keys"].as_array().unwrap().len(), 1);
    assert!(!String::from_utf8(list.bytes)?.contains("token_hash"));
    for table in ["api_keys", "idempotency", "api_key_audit"] {
        let rows: Vec<Value> = sqlx::query_scalar(sqlx::AssertSqlSafe(format!(
            "select to_jsonb(t) from {table} t"
        )))
        .fetch_all(&owner)
        .await?;
        assert!(
            !serde_json::to_string(&rows)?.contains(&secret),
            "secret in {table}"
        );
    }
    assert_secret_absent(&owner, &secret).await?;
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn management_validation_expiry_ownership_and_limit() -> Result<()> {
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    for body in [
        json!({"name":" ","scope":"read"}),
        json!({"name":"字".repeat(41),"scope":"read"}),
        json!({"name":"示例","scope":"read","expires_at":"2000-01-01T00:00:00Z"}),
    ] {
        let reply = app
            .request(
                "POST",
                "/v1/me/api-keys",
                body,
                Some(&session),
                &idem(&Uuid::now_v7().to_string()),
            )
            .await?;
        assert_eq!(reply.status, StatusCode::UNPROCESSABLE_ENTITY);
    }
    for body in [
        json!({"name":"示例","scope":"owner"}),
        json!({"name":"示例","scope":"read","spaces":[]}),
    ] {
        assert_eq!(
            app.request(
                "POST",
                "/v1/me/api-keys",
                body,
                Some(&session),
                &idem(&Uuid::now_v7().to_string())
            )
            .await?
            .status,
            StatusCode::BAD_REQUEST
        );
    }
    assert_eq!(
        app.request(
            "POST",
            "/v1/me/api-keys",
            json!({"name":"示例","scope":"read"}),
            Some(&session),
            &[]
        )
        .await?
        .json()["code"],
        "idempotency_key_required"
    );
    let owner = app.fixture.owner().await?;
    let foreign = app.fixture.seed("foreign-key-owner", "unused").await?;
    let foreign_id:Uuid=sqlx::query_scalar("insert into api_keys(user_id,name,token_hash,display_prefix,scope) values($1,'示例',decode(repeat('01',32),'hex'),'jiabu_pat_000000','read') returning id").bind(foreign.user_id.0).fetch_one(&owner).await?;
    for method in ["PATCH", "POST"] {
        let mut previous = None;
        for id in [foreign_id, Uuid::now_v7()] {
            let path = if method == "PATCH" {
                format!("/v1/me/api-keys/{id}")
            } else {
                format!("/v1/me/api-keys/{id}/revoke")
            };
            let reply = app
                .request(
                    method,
                    &path,
                    json!({"name":"示例"}),
                    Some(&session),
                    &idem(&Uuid::now_v7().to_string()),
                )
                .await?;
            assert_eq!(reply.status, StatusCode::NOT_FOUND);
            let bytes = normalize_request_id(&reply)?;
            if let Some(previous) = previous {
                assert_eq!(bytes, previous);
            }
            previous = Some(bytes);
        }
    }
    let body = json!({"name":"可重复名称","scope":"read","expires_at":null});
    let mut ids = Vec::new();
    for index in 0..20 {
        let reply = app
            .request(
                "POST",
                "/v1/me/api-keys",
                body.clone(),
                Some(&session),
                &idem(&format!("limit-{index}")),
            )
            .await?;
        assert_eq!(reply.status, StatusCode::CREATED);
        ids.push(Uuid::parse_str(reply.json()["id"].as_str().unwrap())?);
    }
    let replay = app
        .request(
            "POST",
            "/v1/me/api-keys",
            body.clone(),
            Some(&session),
            &idem("limit-19"),
        )
        .await?;
    assert_eq!(replay.status, StatusCode::OK);
    assert_eq!(
        app.request(
            "POST",
            "/v1/me/api-keys",
            body.clone(),
            Some(&session),
            &idem("limit-over")
        )
        .await?
        .json()["code"],
        "api_key_limit_reached"
    );
    sqlx::query("update api_keys set expires_at=now()-interval '1 second' where id=$1")
        .bind(ids[0])
        .execute(&owner)
        .await?;
    assert_eq!(
        app.request(
            "POST",
            "/v1/me/api-keys",
            body.clone(),
            Some(&session),
            &idem("after-expiry")
        )
        .await?
        .status,
        StatusCode::CREATED
    );
    app.request(
        "POST",
        &format!("/v1/me/api-keys/{}/revoke", ids[1]),
        Value::Null,
        Some(&session),
        &idem("free-slot"),
    )
    .await?;
    assert_eq!(
        app.request(
            "POST",
            "/v1/me/api-keys",
            body,
            Some(&session),
            &idem("after-revoke")
        )
        .await?
        .status,
        StatusCode::CREATED
    );
    let count: i64 =
        sqlx::query_scalar("select count(*) from api_keys where user_id=$1 and expires_at is null")
            .bind(app.plan.user_id.0)
            .fetch_one(&owner)
            .await?;
    assert_eq!(count, 21);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn explicit_expiry_and_rename_validation() -> Result<()> {
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let at = Utc::now() + chrono::Duration::days(7);
    let body = json!({"name":"示例","scope":"read","expires_at":at});
    let reply = app
        .request(
            "POST",
            "/v1/me/api-keys",
            body.clone(),
            Some(&session),
            &idem("explicit-expiry"),
        )
        .await?;
    assert_eq!(reply.status, StatusCode::CREATED);
    let id = Uuid::parse_str(reply.json()["id"].as_str().unwrap())?;
    let owner = app.fixture.owner().await?;
    let stored: DateTime<Utc> = sqlx::query_scalar("select expires_at from api_keys where id=$1")
        .bind(id)
        .fetch_one(&owner)
        .await?;
    assert!((stored - at).num_microseconds().unwrap().abs() < 2);
    for name in [" ".to_owned(), "字".repeat(41)] {
        assert_eq!(
            app.request(
                "PATCH",
                &format!("/v1/me/api-keys/{id}"),
                json!({"name":name}),
                Some(&session),
                &idem(&Uuid::now_v7().to_string())
            )
            .await?
            .status,
            StatusCode::UNPROCESSABLE_ENTITY
        );
    }
    // A successful creation replay still works after the original expiry.
    sqlx::query("update api_keys set expires_at=now()-interval '1 second' where id=$1")
        .bind(id)
        .execute(&owner)
        .await?;
    let replay = app
        .request(
            "POST",
            "/v1/me/api-keys",
            body,
            Some(&session),
            &idem("explicit-expiry"),
        )
        .await?;
    assert_eq!(
        replay.json(),
        json!({"id":id,"created":true,"plaintext_available":false})
    );
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn keys_cannot_manage_account_keys_spaces_or_members() -> Result<()> {
    let mut app = TestApp::new(false).await?;
    high_limits(&mut app).await?;
    let session = app.token().await?;
    for scope in ["read", "read_write"] {
        let (id, key) = issue(&app, &session, scope).await?;
        let mut routes = vec![
            ("GET", "/v1/me/api-keys".to_owned()),
            ("POST", "/v1/me/api-keys".into()),
            ("PATCH", format!("/v1/me/api-keys/{id}")),
            ("POST", format!("/v1/me/api-keys/{id}/revoke")),
            ("POST", "/v1/me/password".into()),
            ("PATCH", "/v1/me".into()),
            ("POST", "/v1/auth/logout".into()),
            ("POST", "/v1/spaces".into()),
            ("GET", "/v1/me/invitations".into()),
            ("POST", format!("/v1/me/invitations/{id}/accept")),
            ("POST", format!("/v1/me/invitations/{id}/decline")),
            ("POST", "/v1/client-logs".into()),
        ];
        for (method, path) in ISOLATION_MATRIX.iter().filter(|(_, path)| {
            !path.contains("/tools")
                && !path.contains("/blobs/")
                && *path != AUTHORIZATION_PROBE_PATH
        }) {
            routes.push((
                *method,
                path.replace("{space_id}", &app.plan.space_id.to_string())
                    .replace("{member_id}", &id.to_string())
                    .replace("{inv_id}", &id.to_string())
                    .replace("{message_id}", &id.to_string()),
            ));
        }
        for (method, path) in routes {
            let reply = app
                .request(
                    method,
                    &path,
                    json!({"name":"示例","scope":"read"}),
                    Some(&key),
                    &idem("denied"),
                )
                .await?;
            assert_eq!(
                reply.status,
                StatusCode::FORBIDDEN,
                "{scope} {method} {path}"
            );
            assert_eq!(reply.json()["code"], if path.contains("/chat/") { "api_key_ai_not_allowed" } else { "api_key_not_allowed" });
        }
        for path in ["/v1/me", "/v1/status", "/v1/spaces"] {
            assert_eq!(
                app.request("GET", path, Value::Null, Some(&key), &[])
                    .await?
                    .status,
                StatusCode::OK
            );
        }
    }
    Ok(())
}

#[tokio::test]
async fn readonly_scope_filter_and_authorization_order() -> Result<()> {
    let mut app = TestApp::new(false).await?;
    high_limits(&mut app).await?;
    let session = app.token().await?;
    let (id, key) = issue(&app, &session, "read").await?;
    let registry = jiabu_tools::builtin_registry();
    let reply = app
        .request(
            "GET",
            &format!("/v1/spaces/{}/tools", app.plan.space_id),
            Value::Null,
            Some(&key),
            &[],
        )
        .await?;
    assert_eq!(reply.status, StatusCode::OK);
    let names: Vec<_> = reply.json()["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|t| t["name"].as_str().unwrap().to_owned())
        .collect();
    let expected: Vec<_> = registry
        .tools()
        .filter(|t| t.exposure() != Exposure::AgentOnly && t.effect() == Effect::Read)
        .map(|t| t.name().to_owned())
        .collect();
    assert_eq!(names, expected);
    let owner = app.fixture.owner().await?;
    sqlx::query("update space_member_grants set level='none' where member_id in(select id from space_members where user_id=$1)").bind(app.plan.user_id.0).execute(&owner).await?;
    for tool_def in registry
        .tools()
        .filter(|t| t.exposure() != Exposure::AgentOnly && t.effect() != Effect::Read)
    {
        let args = tool_def.example_args();
        let reply = tool(
            &app,
            &key,
            app.plan.space_id.0,
            tool_def.name(),
            args.clone(),
            None,
        )
        .await?;
        assert_eq!(reply.status, StatusCode::FORBIDDEN, "{}", tool_def.name());
        assert_eq!(reply.json()["code"], "api_key_read_only");
        let foreign = tool(
            &app,
            &key,
            Uuid::now_v7(),
            tool_def.name(),
            args,
            Some("foreign"),
        )
        .await?;
        assert_eq!(foreign.status, StatusCode::NOT_FOUND);
    }
    let count: i64 =
        sqlx::query_scalar("select count(*) from entity_events where via_api_key_id=$1")
            .bind(id)
            .fetch_one(&owner)
            .await?;
    assert_eq!(count, 0);
    let denied = tool(
        &app,
        &key,
        app.plan.space_id.0,
        "list_accounts",
        json!({}),
        None,
    )
    .await?;
    assert_eq!(denied.status, StatusCode::NOT_FOUND);
    let writes = registry
        .tools()
        .filter(|t| t.exposure() != Exposure::AgentOnly && t.effect() != Effect::Read)
        .count() as i64;
    assert_eq!(audit_count(&owner, id).await?, 2 * writes + 1);
    let readonly:i64=sqlx::query_scalar("select count(*) from api_key_audit where api_key_id=$1 and outcome='api_key_read_only' and effect='local_write'").bind(id).fetch_one(&owner).await?;
    assert_eq!(readonly, writes);
    let absent: i64 = sqlx::query_scalar(
        "select count(*) from api_key_audit where api_key_id=$1 and outcome='not_found'",
    )
    .bind(id)
    .fetch_one(&owner)
    .await?;
    assert_eq!(absent, writes + 1);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn authentication_is_live_last_used_is_throttled_and_replay_cannot_bypass() -> Result<()> {
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let (id, key) = issue(&app, &session, "read_write").await?;
    let owner = app.fixture.owner().await?;
    let before: Option<DateTime<Utc>> =
        sqlx::query_scalar("select last_used_at from api_keys where id=$1")
            .bind(id)
            .fetch_one(&owner)
            .await?;
    assert!(before.is_none());
    let first = write_tag(&app, &key, "live-write").await?;
    assert_eq!(first.status, StatusCode::OK);
    let last: DateTime<Utc> = sqlx::query_scalar("select last_used_at from api_keys where id=$1")
        .bind(id)
        .fetch_one(&owner)
        .await?;
    assert_eq!(
        write_tag(&app, &key, "live-write").await?.json(),
        first.json()
    );
    let same: DateTime<Utc> = sqlx::query_scalar("select last_used_at from api_keys where id=$1")
        .bind(id)
        .fetch_one(&owner)
        .await?;
    assert_eq!(last, same);
    sqlx::query("update api_keys set last_used_at=now()-interval '61 seconds' where id=$1")
        .bind(id)
        .execute(&owner)
        .await?;
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&key), &[])
            .await?
            .status,
        StatusCode::OK
    );
    let refreshed: DateTime<Utc> =
        sqlx::query_scalar("select last_used_at from api_keys where id=$1")
            .bind(id)
            .fetch_one(&owner)
            .await?;
    assert!(refreshed >= last);
    let admin = jiabu_db_admin::users::AdminDb::connect(&app.fixture.admin_url).await?;
    jiabu_admin::set_disabled(&admin, "sample", true, "example-operator").await?;
    assert_eq!(
        write_tag(&app, &key, "live-write").await?.status,
        StatusCode::UNAUTHORIZED
    );
    jiabu_admin::set_disabled(&admin, "sample", false, "example-operator").await?;
    let session = app.token().await?;
    assert_eq!(
        write_tag(&app, &key, "live-write").await?.status,
        StatusCode::OK
    );
    sqlx::query("update api_keys set expires_at=now()-interval '1 second' where id=$1")
        .bind(id)
        .execute(&owner)
        .await?;
    assert_eq!(
        write_tag(&app, &key, "live-write").await?.status,
        StatusCode::UNAUTHORIZED
    );
    sqlx::query("update api_keys set expires_at=null where id=$1")
        .bind(id)
        .execute(&owner)
        .await?;
    assert_eq!(
        write_tag(&app, &key, "live-write").await?.status,
        StatusCode::OK
    );
    app.request(
        "POST",
        &format!("/v1/me/api-keys/{id}/revoke"),
        Value::Null,
        Some(&session),
        &idem("revoke-live"),
    )
    .await?;
    assert_eq!(
        write_tag(&app, &key, "live-write").await?.status,
        StatusCode::UNAUTHORIZED
    );
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn membership_lifecycle_new_spaces_and_replay() -> Result<()> {
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let (_, key) = issue(&app, &session, "read_write").await?;
    let owner = app.fixture.owner().await?;
    let plan = app.fixture.seed("shared-owner", "unused").await?;
    sqlx::query("update spaces set is_default=false where id=$1")
        .bind(plan.space_id.0)
        .execute(&owner)
        .await?;
    let user = app.plan.user_id.0;
    let add = |space: Uuid| {
        let owner = &owner;
        async move {
            let member:Uuid=sqlx::query_scalar("insert into space_members(space_id,user_id,display_name,role,status,joined_at,change_seq) values($1,$2,'示例成员','member','active',now(),nextval('change_seq')) returning id").bind(space).bind(user).fetch_one(owner).await?;
            sqlx::query("insert into space_member_grants(member_id,module,level,change_seq) values($1,'ledger','write',nextval('change_seq')),($1,'documents','write',nextval('change_seq'))").bind(member).execute(owner).await?;
            anyhow::Ok(member)
        }
    };
    let member = add(plan.space_id.0).await?;
    let read = || tool(&app, &key, plan.space_id.0, "list_tags", json!({}), None);
    assert_eq!(read().await?.status, StatusCode::OK);
    let args = json!({"name":"示例成员标签"});
    let first = tool(
        &app,
        &key,
        plan.space_id.0,
        "create_tag",
        args.clone(),
        Some("member-write"),
    )
    .await?;
    assert_eq!(first.status, StatusCode::OK);
    let leave = app
        .request(
            "POST",
            &format!("/v1/spaces/{}/leave", plan.space_id),
            Value::Null,
            Some(&session),
            &[
                ("idempotency-key", "leave".into()),
                ("x-jiabu-join-epoch", "1".into()),
            ],
        )
        .await?;
    assert_eq!(leave.status, StatusCode::OK);
    assert_eq!(read().await?.status, StatusCode::NOT_FOUND);
    let spaces = app
        .request("GET", "/v1/spaces", Value::Null, Some(&key), &[])
        .await?
        .json();
    assert_eq!(spaces["spaces"].as_array().unwrap().len(), 1);
    assert_eq!(
        tool(
            &app,
            &key,
            plan.space_id.0,
            "create_tag",
            args.clone(),
            Some("member-write")
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    sqlx::query("update space_members set status='active',join_epoch=join_epoch+1,left_at=null,left_reason=null,joined_at=now() where id=$1").bind(member).execute(&owner).await?;
    assert_eq!(read().await?.status, StatusCode::OK);
    let replay_path = format!("/v1/spaces/{}/tools/create_tag", plan.space_id);
    let old_epoch = app
        .request(
            "POST",
            &replay_path,
            args.clone(),
            Some(&key),
            &[
                ("idempotency-key", "member-write".into()),
                ("x-jiabu-join-epoch", "1".into()),
            ],
        )
        .await?;
    assert_eq!(old_epoch.json()["code"], "membership_changed");
    let another = app.fixture.seed("another-owner", "unused").await?;
    add(another.space_id.0).await?;
    for scope in ["read", "read_write"] {
        let (_, token) = issue(&app, &session, scope).await?;
        let list = app
            .request("GET", "/v1/spaces", Value::Null, Some(&token), &[])
            .await?
            .json();
        assert_eq!(list["spaces"].as_array().unwrap().len(), 3);
    }
    assert_eq!(
        tool(&app, &key, another.space_id.0, "list_tags", json!({}), None)
            .await?
            .status,
        StatusCode::OK
    );
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='ledger'",
    )
    .bind(member)
    .execute(&owner)
    .await?;
    assert_eq!(
        tool(
            &app,
            &key,
            plan.space_id.0,
            "create_tag",
            args,
            Some("member-write")
        )
        .await?
        .status,
        StatusCode::NOT_FOUND
    );
    owner.close().await;
    Ok(())
}

#[utoipa::path(post,path="/v1/test-ai-session",security(("bearer"=[])),responses((status=204,description="Session accepted"),(status=403,body=crate::Problem,description="API key cannot use AI")))]
pub(crate) async fn ai_probe(
    crate::SessionOnly(principal): crate::SessionOnly,
) -> Result<StatusCode, crate::ApiError> {
    principal.require_ai_session()?;
    Ok(StatusCode::NO_CONTENT)
}
#[tokio::test]
async fn ai_route_and_service_guard_never_create_runs_or_usage() -> Result<()> {
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let (_, key) = issue(&app, &session, "read_write").await?;
    assert_eq!(
        app.request(
            "POST",
            "/v1/test-ai-session",
            Value::Null,
            Some(&session),
            &[]
        )
        .await?
        .status,
        StatusCode::NO_CONTENT
    );
    let reply = app
        .request("POST", "/v1/test-ai-session", Value::Null, Some(&key), &[])
        .await?;
    assert_eq!(reply.status, StatusCode::FORBIDDEN);
    assert_eq!(reply.json()["code"], "api_key_ai_not_allowed");
    let db = AppDb::connect(&app.fixture.app_url).await?;
    let principal = db
        .authenticate_api_key(crate::credentials::token_hash(&key))
        .await?;
    assert_eq!(
        principal.require_ai_session().unwrap_err().code,
        "api_key_ai_not_allowed"
    );
    let owner = app.fixture.owner().await?;
    for table in ["agent_runs", "ai_calls", "ai_step_meters"] {
        let n: i64 =
            sqlx::query_scalar(sqlx::AssertSqlSafe(format!("select count(*) from {table}")))
                .fetch_one(&owner)
                .await?;
        assert_eq!(n, 0);
    }
    owner.close().await;
    db.close().await?;
    Ok(())
}

#[derive(Default)]
struct Clock(AtomicU64);
impl jiabu_tools::api_key::RateClock for Clock {
    fn now(&self) -> Duration {
        Duration::from_millis(self.0.load(Ordering::Relaxed))
    }
}
#[tokio::test]
async fn read_write_limits_retry_after_and_admission_order() -> Result<()> {
    let mut app = TestApp::new(false).await?;
    let clock = Arc::new(Clock::default());
    let limiter = Arc::new(jiabu_tools::api_key::ApiKeyLimiter::new(
        jiabu_tools::api_key::ApiKeyLimits {
            read_per_minute: 4,
            write_per_minute: 2,
            unknown_per_minute: 2,
        },
        clock.clone(),
    ));
    let state = AppState::new(AppDb::connect(&app.fixture.app_url).await?)
        .await
        .map_err(anyhow::Error::msg)?
        .with_api_key_limiter(limiter)
        .map_err(anyhow::Error::msg)?;
    app.router = crate::router(state);
    let session = app.token().await?;
    let (id, key) = issue(&app, &session, "read_write").await?;
    for path in ["/v1/me", "/v1/status", "/v1/spaces"] {
        assert_eq!(
            app.request("GET", path, Value::Null, Some(&key), &[])
                .await?
                .status,
            StatusCode::OK
        );
    }
    assert_eq!(
        tool(
            &app,
            &key,
            app.plan.space_id.0,
            "list_tags",
            json!({}),
            None
        )
        .await?
        .status,
        StatusCode::OK
    );
    let limited = tool(
        &app,
        &key,
        app.plan.space_id.0,
        "list_tags",
        json!({}),
        None,
    )
    .await?;
    assert_eq!(limited.status, StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(limited.headers["retry-after"], "15");
    assert_eq!(
        tool(&app, &key, Uuid::now_v7(), "list_tags", json!({}), None)
            .await?
            .status,
        StatusCode::TOO_MANY_REQUESTS
    );
    let first = write_tag(&app, &key, "rate-write").await?;
    assert_eq!(first.status, StatusCode::OK);
    assert_eq!(
        write_tag(&app, &key, "rate-write").await?.json(),
        first.json()
    );
    let limited = write_tag(&app, &key, "rate-write").await?;
    assert_eq!(limited.status, StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(limited.headers["retry-after"], "30");
    let (_, other) = issue(&app, &session, "read").await?;
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&other), &[])
            .await?
            .status,
        StatusCode::OK
    );
    clock.0.store(30_000, Ordering::Relaxed);
    assert_eq!(
        write_tag(&app, &key, "rate-write").await?.status,
        StatusCode::OK
    );
    let owner = app.fixture.owner().await?;
    let limited: i64 = sqlx::query_scalar(
        "select count(*) from api_key_audit where api_key_id=$1 and outcome='rate_limited'",
    )
    .bind(id)
    .fetch_one(&owner)
    .await?;
    assert_eq!(limited, 0);
    assert_eq!(audit_count(&owner, id).await?, 4);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn malformed_tokens_do_not_query_identity_tables_and_unknown_tokens_are_limited() -> Result<()>
{
    let mut app = TestApp::new(false).await?;
    let state = AppState::new(AppDb::connect(&app.fixture.app_url).await?)
        .await
        .map_err(anyhow::Error::msg)?
        .with_api_key_limiter(Arc::new(jiabu_tools::api_key::ApiKeyLimiter::new(
            jiabu_tools::api_key::ApiKeyLimits {
                unknown_per_minute: 2,
                ..Default::default()
            },
            Arc::new(Clock::default()),
        )))
        .map_err(anyhow::Error::msg)?;
    app.router = crate::router(state);
    let owner = app.fixture.owner().await?;
    let mut lock = owner.begin().await?;
    sqlx::query("lock table users,sessions,api_keys,app_releases in access exclusive mode")
        .execute(&mut *lock)
        .await?;
    let good = crate::api_key_token::generate();
    let mut bad = good.clone().into_bytes();
    bad[55] = if bad[55] == b'0' { b'1' } else { b'0' };
    for token in [
        "jiabu_pat_bad".to_owned(),
        String::from_utf8(bad)?,
        "jiabu_adm_invalid".to_owned(),
        "é".repeat(28),
    ] {
        let reply = tokio::time::timeout(
            Duration::from_millis(500),
            app.request(
                "GET",
                "/v1/me",
                Value::Null,
                Some(&token),
                &[("x-jiabu-client", "android/0.1.0+1; channel=stable".into())],
            ),
        )
        .await??;
        assert_eq!(reply.status, StatusCode::UNAUTHORIZED);
    }
    lock.rollback().await?;
    for fake_ip in ["198.51.100.1", "198.51.100.2"] {
        assert_eq!(
            app.request(
                "GET",
                "/v1/me",
                Value::Null,
                Some(&good),
                &[("x-real-ip", fake_ip.into())]
            )
            .await?
            .status,
            StatusCode::UNAUTHORIZED
        );
    }
    let mut blocked = owner.begin().await?;
    sqlx::query("lock table users,sessions,api_keys,app_releases in access exclusive mode")
        .execute(&mut *blocked)
        .await?;
    let limited = tokio::time::timeout(
        Duration::from_millis(500),
        app.request(
            "GET",
            "/v1/me",
            Value::Null,
            Some(&good),
            &[("x-jiabu-client", "android/0.1.0+1; channel=stable".into())],
        ),
    )
    .await??;
    blocked.rollback().await?;
    assert_eq!(limited.status, StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(limited.headers["retry-after"], "30");
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from api_key_audit")
            .fetch_one(&owner)
            .await?,
        0
    );
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn events_audit_denials_versions_epoch_and_secret_idempotency() -> Result<()> {
    use tracing::instrument::WithSubscriber;
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let (id, key) = issue(&app, &session, "read_write").await?;
    let owner = app.fixture.owner().await?;
    let path = format!("/v1/spaces/{}/tools/create_tag", app.plan.space_id);
    let args = json!({"name":"示例内容不会进入审计"});
    let missing = tool(
        &app,
        &key,
        app.plan.space_id.0,
        "create_tag",
        args.clone(),
        None,
    )
    .await?;
    assert_eq!(missing.status, StatusCode::BAD_REQUEST);
    assert_eq!(missing.json()["code"], "idempotency_key_required");
    let request = Uuid::now_v7();
    let buffer = Arc::new(std::sync::Mutex::new(Vec::new()));
    let subscriber = tracing_subscriber::fmt()
        .json()
        .flatten_event(true)
        .with_current_span(true)
        .with_span_list(false)
        .with_max_level(tracing::Level::TRACE)
        .with_writer(LogWriter(buffer.clone()))
        .finish();
    let first = app
        .request(
            "POST",
            &path,
            args.clone(),
            Some(&key),
            &[
                ("idempotency-key", "audit-write".into()),
                ("x-request-id", request.to_string()),
            ],
        )
        .with_subscriber(subscriber)
        .await?;
    assert_eq!(first.status, StatusCode::OK);
    let tag_id = first.json()["id"].clone();
    let log = String::from_utf8(buffer.lock().unwrap().clone())?;
    assert!(!log.contains(&key));
    assert!(!log.contains("示例内容不会进入审计"));
    assert!(log.contains(&id.to_string()));
    assert!(log.contains("api_key"));
    assert!(log.contains("create_tag"));
    let event: Value = sqlx::query_scalar(
        "select to_jsonb(e) from entity_events e where via_api_key_id=$1 order by id limit 1",
    )
    .bind(id)
    .fetch_one(&owner)
    .await?;
    assert_eq!(event["via_api_key_name"], "示例脚本");
    assert_eq!(event["via_api_key_id"], id.to_string());
    assert_eq!(event["request_id"], request.to_string());
    let audit: Value =
        sqlx::query_scalar("select to_jsonb(a) from api_key_audit a where request_id=$1")
            .bind(request)
            .fetch_one(&owner)
            .await?;
    assert_eq!(audit["outcome"], "ok");
    assert_eq!(audit["operation"], "tool:create_tag");
    assert_eq!(audit["effect"], "local_write");
    assert_eq!(audit["space_id"], app.plan.space_id.to_string());
    assert_eq!(audit["idempotency_key"], "audit-write");
    assert_eq!(
        tool(
            &app,
            &key,
            app.plan.space_id.0,
            "create_tag",
            args.clone(),
            Some("audit-write")
        )
        .await?
        .json(),
        first.json()
    );
    app.request(
        "PATCH",
        &format!("/v1/me/api-keys/{id}"),
        json!({"name":"改名后的脚本"}),
        Some(&session),
        &idem("rename-audit"),
    )
    .await?;
    let rename_args = json!({"id":tag_id,"name":"另一示例内容","expected_version":1});
    let renamed = tool(
        &app,
        &key,
        app.plan.space_id.0,
        "rename_tag",
        rename_args.clone(),
        Some("rename-tag"),
    )
    .await?;
    assert_eq!(renamed.status, StatusCode::OK);
    let names: Vec<String> = sqlx::query_scalar(
        "select via_api_key_name from entity_events where via_api_key_id=$1 order by id",
    )
    .bind(id)
    .fetch_all(&owner)
    .await?;
    assert_eq!(names, vec!["示例脚本", "改名后的脚本"]);
    let conflict = tool(
        &app,
        &key,
        app.plan.space_id.0,
        "rename_tag",
        rename_args,
        Some("stale-version"),
    )
    .await?;
    assert_eq!(conflict.status, StatusCode::CONFLICT);
    assert_eq!(conflict.json()["code"], "version_conflict");
    let invalid = tool(
        &app,
        &key,
        app.plan.space_id.0,
        "rename_tag",
        json!({"id":tag_id,"name":"示例"}),
        Some("missing-version"),
    )
    .await?;
    assert_eq!(invalid.status, StatusCode::UNPROCESSABLE_ENTITY);
    let bad_epoch = app
        .request(
            "POST",
            &path,
            args.clone(),
            Some(&key),
            &[
                ("idempotency-key", "audit-write".into()),
                ("x-jiabu-join-epoch", "2".into()),
            ],
        )
        .await?;
    assert_eq!(bad_epoch.json()["code"], "membership_changed");
    let good_epoch = app
        .request(
            "POST",
            &path,
            args.clone(),
            Some(&key),
            &[
                ("idempotency-key", "audit-write".into()),
                ("x-jiabu-join-epoch", "1".into()),
            ],
        )
        .await?;
    assert_eq!(good_epoch.json(), first.json());
    let session_epoch = tool(
        &app,
        &session,
        app.plan.space_id.0,
        "create_tag",
        args.clone(),
        Some("session-needs-epoch"),
    )
    .await?;
    assert_eq!(session_epoch.status, StatusCode::BAD_REQUEST);
    let leaked = app
        .request(
            "POST",
            &path,
            args,
            Some(&key),
            &idem(&format!("prefix-{key}-suffix")),
        )
        .await?;
    assert_eq!(leaked.status, StatusCode::BAD_REQUEST);
    let secret_audit: Value = sqlx::query_scalar(
        "select to_jsonb(a) from api_key_audit a where api_key_id=$1 order by id desc limit 1",
    )
    .bind(id)
    .fetch_one(&owner)
    .await?;
    assert!(secret_audit["idempotency_key"].is_null());
    let outcomes: Vec<String> =
        sqlx::query_scalar("select outcome from api_key_audit where api_key_id=$1 order by id")
            .bind(id)
            .fetch_all(&owner)
            .await?;
    assert_eq!(
        outcomes,
        vec![
            "idempotency_key_required",
            "ok",
            "ok",
            "ok",
            "version_conflict",
            "validation_failed",
            "membership_changed",
            "ok",
            "bad_request"
        ]
    );
    assert_eq!(audit_count(&owner, id).await?, 9);
    assert_secret_absent(&owner, &key).await?;
    for table in ["api_keys", "idempotency", "api_key_audit"] {
        let rows: Vec<Value> = sqlx::query_scalar(sqlx::AssertSqlSafe(format!(
            "select to_jsonb(t) from {table} t"
        )))
        .fetch_all(&owner)
        .await?;
        let text = serde_json::to_string(&rows)?;
        assert!(!text.contains(&key), "{table}");
        if table == "api_key_audit" {
            assert!(!text.contains("示例内容不会进入审计"));
            assert!(!text.contains("另一示例内容"));
        }
    }
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn audit_failure_rolls_back_successful_writes_and_fails_independent_append() -> Result<()> {
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let (id, key) = issue(&app, &session, "read_write").await?;
    let owner = app.fixture.owner().await?;
    sqlx::raw_sql("create function test_reject_key_audit() returns trigger language plpgsql as $$ begin raise exception 'test audit unavailable'; end $$; create trigger test_reject_key_audit before insert on api_key_audit for each row execute function test_reject_key_audit()").execute(&owner).await?;
    assert_eq!(
        write_tag(&app, &key, "audit-failure").await?.status,
        StatusCode::SERVICE_UNAVAILABLE
    );
    assert_eq!(
        tool(&app, &key, Uuid::now_v7(), "list_tags", json!({}), None)
            .await?
            .status,
        StatusCode::SERVICE_UNAVAILABLE
    );
    let count: i64 =
        sqlx::query_scalar("select count(*) from entity_events where via_api_key_id=$1")
            .bind(id)
            .fetch_one(&owner)
            .await?;
    assert_eq!(count, 0);
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from idempotency where key='audit-failure'")
            .fetch_one(&owner)
            .await?,
        0
    );
    sqlx::query("drop trigger test_reject_key_audit on api_key_audit")
        .execute(&owner)
        .await?;
    assert_eq!(
        write_tag(&app, &key, "audit-failure").await?.status,
        StatusCode::OK
    );
    assert_eq!(audit_count(&owner, id).await?, 1);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn admin_safe_projection_revocation_and_ownership() -> Result<()> {
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let (id, key) = issue(&app, &session, "read").await?;
    let db = jiabu_db_admin::users::AdminDb::connect(&app.fixture.admin_url).await?;
    let list = jiabu_admin::api_keys(&db, "SAMPLE", None, "example-operator").await?;
    assert_eq!(list["api_keys"][0]["id"], id.to_string());
    assert_eq!(list["api_keys"][0]["status"], "active");
    assert!(list["api_keys"][0].get("token_hash").is_none());
    assert!(!list.to_string().contains(&key));
    assert!(
        jiabu_admin::api_keys(&db, "sample", Some(Uuid::now_v7()), "example-operator")
            .await
            .is_err()
    );
    app.fixture.seed("other-admin-target", "unused").await?;
    assert!(
        jiabu_admin::api_keys(&db, "other-admin-target", Some(id), "example-operator")
            .await
            .is_err()
    );
    let revoked = jiabu_admin::api_keys(&db, "sample", Some(id), "example-operator").await?;
    assert_eq!(revoked["api_keys"][0]["revoked_by"], "admin");
    let repeated = jiabu_admin::api_keys(&db, "sample", Some(id), "example-operator").await?;
    assert_eq!(revoked, repeated);
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&key), &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    let user_revoked = app
        .request(
            "POST",
            &format!("/v1/me/api-keys/{id}/revoke"),
            Value::Null,
            Some(&session),
            &idem("user-after-admin"),
        )
        .await?;
    assert_eq!(user_revoked.json()["revoked_by"], "admin");
    assert_eq!(
        user_revoked.json()["revoked_at"],
        revoked["api_keys"][0]["revoked_at"]
    );
    let admin = sqlx::PgPool::connect(&app.fixture.admin_url).await?;
    assert!(
        sqlx::query("select token_hash from api_keys")
            .fetch_all(&admin)
            .await
            .is_err()
    );
    assert!(
        sqlx::query("select * from api_key_audit")
            .fetch_all(&admin)
            .await
            .is_err()
    );
    assert!(
        sqlx::query("update api_keys set name='forbidden'")
            .execute(&admin)
            .await
            .is_err()
    );
    let owner = app.fixture.owner().await?;
    let count:i64=sqlx::query_scalar("select count(*) from admin_audit where actor_kind='cli' and actor_label='example-operator' and action='user.api-keys.revoke' and target_id=$1").bind(id.to_string()).fetch_one(&owner).await?;
    assert_eq!(count, 2);
    owner.close().await;
    admin.close().await;
    Ok(())
}

#[test]
fn openapi_keys_bearer_and_agent_only_exclusion() -> Result<()> {
    let doc = serde_json::to_value(crate::openapi())?;
    for (path, method) in [
        ("/v1/me/api-keys", "get"),
        ("/v1/me/api-keys", "post"),
        ("/v1/me/api-keys/{id}", "patch"),
        ("/v1/me/api-keys/{id}/revoke", "post"),
    ] {
        assert!(doc["paths"][path][method].is_object());
    }
    assert!(
        doc["components"]["securitySchemes"]["bearer"]["description"]
            .as_str()
            .unwrap()
            .contains("jiabu_pat_")
    );
    assert!(
        doc["paths"]
            .get("/v1/spaces/{space_id}/tools/ask_user")
            .is_none()
    );
    assert!(
        !crate::route_catalog()
            .iter()
            .any(|r| r.path.ends_with("/ask_user"))
    );
    Ok(())
}

#[tokio::test]
async fn concurrent_creation_replay_returns_plaintext_to_only_one_request() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20), async {
        let app = TestApp::new(false).await?;
        let session = app.token().await?;
        let barrier = tokio::sync::Barrier::new(2);
        let first = async {
            barrier.wait().await;
            app.request(
                "POST",
                "/v1/me/api-keys",
                json!({"name":"并发示例","scope":"read"}),
                Some(&session),
                &idem("concurrent-same-key"),
            )
            .await
        };
        let second = async {
            barrier.wait().await;
            app.request(
                "POST",
                "/v1/me/api-keys",
                json!({"name":"并发示例","scope":"read"}),
                Some(&session),
                &idem("concurrent-same-key"),
            )
            .await
        };
        let (first, second) = tokio::join!(first, second);
        let mut replies = [first?, second?];
        replies.sort_by_key(|reply| reply.status.as_u16());
        assert_eq!(replies[0].status, StatusCode::OK);
        assert_eq!(replies[1].status, StatusCode::CREATED);
        assert_eq!(replies[0].json()["id"], replies[1].json()["id"]);
        assert!(replies[0].json().get("key").is_none());
        assert!(replies[1].json()["key"].is_string());
        let owner = app.fixture.owner().await?;
        assert_eq!(
            sqlx::query_scalar::<_, i64>("select count(*) from api_keys")
                .fetch_one(&owner)
                .await?,
            1
        );
        owner.close().await;
        anyhow::Ok(())
    })
    .await??;
    Ok(())
}

#[tokio::test]
async fn admission_limits_early_denials_without_transactions_updates_or_audit() -> Result<()> {
    let mut app = TestApp::new(false).await?;
    configure_limits(
        &mut app,
        jiabu_tools::api_key::ApiKeyLimits {
            read_per_minute: 2,
            write_per_minute: 2,
            unknown_per_minute: 2,
        },
        Arc::new(Clock::default()),
    )
    .await?;
    let session = app.token().await?;
    let (id, key) = issue(&app, &session, "read").await?;
    for _ in 0..2 {
        let denied = app
            .request("POST", "/v1/me/password", Value::Null, Some(&key), &[])
            .await?;
        assert_eq!(denied.json()["code"], "api_key_not_allowed");
    }
    for (method, path) in [("GET", "/v1/me"), ("HEAD", "/v1/status")] {
        assert_eq!(
            app.request(method, path, Value::Null, Some(&key), &[])
                .await?
                .status,
            StatusCode::OK
        );
    }
    let owner = app.fixture.owner().await?;
    assert_eq!(audit_count(&owner, id).await?, 2);
    sqlx::query("update api_keys set last_used_at=now()-interval '61 seconds' where id=$1")
        .bind(id)
        .execute(&owner)
        .await?;
    let last_used: DateTime<Utc> =
        sqlx::query_scalar("select last_used_at from api_keys where id=$1")
            .bind(id)
            .fetch_one(&owner)
            .await?;
    let member_write = format!("/v1/spaces/{}/tools/create_tag", app.plan.space_id);
    let foreign_read = format!("/v1/spaces/{}/tools/list_tags", Uuid::now_v7());
    let invalid_read = format!("/v1/spaces/{}/tools/list_tags", app.plan.space_id);
    // Any business lookup/transaction or error audit now blocks; a genuine
    // admission rejection must finish without touching these tables.
    let mut blocked = owner.begin().await?;
    sqlx::query("lock table spaces,space_members,api_key_audit,idempotency,app_releases in access exclusive mode").execute(&mut *blocked).await?;
    for (method, path) in [
        ("POST", "/v1/me/password"),
        ("POST", "/v1/spaces"),
        ("POST", foreign_read.as_str()),
        ("POST", member_write.as_str()),
        ("POST", invalid_read.as_str()),
        ("HEAD", "/v1/me"),
        ("GET", "/v1/spaces"),
    ] {
        let reply = tokio::time::timeout(
            Duration::from_millis(500),
            app.request(
                method,
                path,
                Value::Null,
                Some(&key),
                &[("x-jiabu-client", "android/0.1.0+1; channel=stable".into())],
            ),
        )
        .await??;
        assert_eq!(
            reply.status,
            StatusCode::TOO_MANY_REQUESTS,
            "{method} {path}"
        );
        assert_eq!(reply.headers["retry-after"], "30");
    }
    blocked.rollback().await?;
    assert_eq!(audit_count(&owner, id).await?, 2);
    let unchanged: DateTime<Utc> =
        sqlx::query_scalar("select last_used_at from api_keys where id=$1")
            .bind(id)
            .fetch_one(&owner)
            .await?;
    assert_eq!(last_used, unchanged);
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn key_and_session_replays_cannot_cross_membership_generations() -> Result<()> {
    let app = TestApp::new(false).await?;
    let session = app.token().await?;
    let (_, key) = issue(&app, &session, "read_write").await?;
    let owner = app.fixture.owner().await?;
    let space = app
        .fixture
        .seed("epoch-space-owner", "unused")
        .await?
        .space_id
        .0;
    sqlx::query("update spaces set is_default=false where id=$1")
        .bind(space)
        .execute(&owner)
        .await?;
    let member: Uuid = sqlx::query_scalar("insert into space_members(space_id,user_id,display_name,role,status,joined_at,change_seq) values($1,$2,'示例成员','member','active',now(),nextval('change_seq')) returning id")
        .bind(space).bind(app.plan.user_id.0).fetch_one(&owner).await?;
    sqlx::query("insert into space_member_grants(member_id,module,level,change_seq) values($1,'ledger','write',nextval('change_seq'))").bind(member).execute(&owner).await?;
    let path = format!("/v1/spaces/{space}/tools/create_tag");
    for (index, token, is_key) in [(0, &key, true), (1, &session, false)] {
        let epoch: i32 = sqlx::query_scalar("select join_epoch from space_members where id=$1")
            .bind(member)
            .fetch_one(&owner)
            .await?;
        let operation = format!("generation-{index}");
        let args = json!({"name":format!("示例世代-{index}")});
        let mut headers = Vec::from(idem(&operation));
        if !is_key {
            headers.push(("x-jiabu-join-epoch", epoch.to_string()));
        }
        let first = app
            .request("POST", &path, args.clone(), Some(token), &headers)
            .await?;
        assert_eq!(first.status, StatusCode::OK);
        let _: jiabu_domain::ledger::Tag = serde_json::from_value(first.json())?;
        assert_eq!(
            app.request("POST", &path, args.clone(), Some(token), &headers)
                .await?
                .json(),
            first.json()
        );
        let stored = sqlx::query(
            "select join_epoch,response_body from idempotency where user_id=$1 and key=$2",
        )
        .bind(app.plan.user_id.0)
        .bind(&operation)
        .fetch_one(&owner)
        .await?;
        assert_eq!(stored.try_get::<Option<i32>, _>("join_epoch")?, Some(epoch));
        assert_eq!(stored.try_get::<Value, _>("response_body")?, first.json());
        let leave = app
            .request(
                "POST",
                &format!("/v1/spaces/{space}/leave"),
                Value::Null,
                Some(&session),
                &[
                    ("idempotency-key", format!("leave-generation-{index}")),
                    ("x-jiabu-join-epoch", epoch.to_string()),
                ],
            )
            .await?;
        assert_eq!(leave.status, StatusCode::OK);
        assert_eq!(
            app.request("POST", &path, args.clone(), Some(token), &headers)
                .await?
                .status,
            StatusCode::NOT_FOUND
        );
        sqlx::query("update space_members set status='active',join_epoch=join_epoch+1,left_at=null,left_reason=null,joined_at=now() where id=$1").bind(member).execute(&owner).await?;
        if !is_key {
            // Use the NEW header, so only the stored replay generation can reject it.
            headers = vec![
                ("idempotency-key", operation.clone()),
                ("x-jiabu-join-epoch", (epoch + 1).to_string()),
            ];
        }
        // API keys still omit the header here; they cannot recover the old result.
        let replay = app
            .request("POST", &path, args, Some(token), &headers)
            .await?;
        assert_eq!(replay.status, StatusCode::CONFLICT);
        assert_eq!(replay.json()["code"], "membership_changed");
        assert_ne!(replay.json(), first.json());
        let events: i64 =
            sqlx::query_scalar("select count(*) from entity_events where entity_id=$1")
                .bind(Uuid::parse_str(first.json()["id"].as_str().unwrap())?)
                .fetch_one(&owner)
                .await?;
        assert_eq!(events, 1);
    }
    owner.close().await;
    Ok(())
}

// Exercise the real S4 integration primitives without adding any S4 HTTP route.
async fn admitted_batch(
    state: &AppState,
    key: &str,
) -> Result<(crate::Principal, crate::RequestAudit)> {
    use axum::extract::FromRequestParts;
    let audit = crate::RequestAudit::default();
    let (mut parts, _) = Request::builder()
        .method("POST")
        .uri("/v1/test-batch-admission")
        .header("authorization", format!("Bearer {key}"))
        .body(Body::empty())?
        .into_parts();
    parts.extensions.insert(audit.clone());
    let principal = crate::Principal::from_request_parts(&mut parts, state)
        .await
        .map_err(|error| anyhow::anyhow!(error.code))?;
    Ok((principal, audit))
}

#[tokio::test]
async fn push_helpers_charge_each_item_once_and_audit_only_admitted_items() -> Result<()> {
    let mut app = TestApp::new(false).await?;
    let state = configure_limits(
        &mut app,
        jiabu_tools::api_key::ApiKeyLimits {
            read_per_minute: 3,
            write_per_minute: 3,
            unknown_per_minute: 3,
        },
        Arc::new(Clock::default()),
    )
    .await?;
    let session = app.token().await?;
    let (id, key) = issue(&app, &session, "read_write").await?;
    let (principal, request) = admitted_batch(&state, &key).await?;
    let op_id = Uuid::now_v7();
    let item_request_id = Uuid::now_v7();
    let missing_request_id = Uuid::now_v7();
    let ticket = request
        .begin_push_item(
            &state,
            &principal,
            Some(app.plan.space_id.0),
            Some("create_tag"),
            Some(op_id),
            Some(item_request_id),
        )
        .map_err(|error| anyhow::anyhow!(error.code))?;
    let mut ctx = jiabu_tools::ToolCtx::begin(
        &state.db,
        principal.clone(),
        app.plan.space_id,
        None,
        Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(Uuid::new_v5(
                &principal.user_id.0,
                op_id.to_string().as_bytes(),
            )),
            replay_key: Some(op_id.to_string()),
            run_id: None,
            request_id: item_request_id,
            now: Utc::now(),
        },
    )
    .await?;
    ticket
        .attach(&mut ctx)
        .map_err(|error| anyhow::anyhow!(error.code))?;
    state
        .tools
        .invoke("create_tag", json!({"name":"示例批次标签"}), &ctx)
        .await?;
    ticket
        .finish(&state, "ok")
        .await
        .map_err(|error| anyhow::anyhow!(error.code))?;

    let absent = Uuid::now_v7();
    let ticket = request
        .begin_push_item(
            &state,
            &principal,
            Some(absent),
            Some("list_tags"),
            Some(Uuid::now_v7()),
            Some(missing_request_id),
        )
        .map_err(|error| anyhow::anyhow!(error.code))?;
    let result = jiabu_tools::ToolCtx::begin(
        &state.db,
        principal.clone(),
        jiabu_domain::SpaceId(absent),
        None,
        Effect::Read,
        jiabu_tools::Invocation {
            idempotency_key: None,
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: Utc::now(),
        },
    )
    .await;
    let error = result
        .err()
        .ok_or_else(|| anyhow::anyhow!("nonmember admitted"))?;
    assert_eq!(error.code, "not_found");
    ticket
        .finish(&state, error.code)
        .await
        .map_err(|error| anyhow::anyhow!(error.code))?;

    // Missing/invalid metadata must still cost an item and receive safe audit.
    let ticket = request
        .begin_push_item(&state, &principal, None, None, None, None)
        .map_err(|error| anyhow::anyhow!(error.code))?;
    ticket
        .finish(&state, "validation_failed")
        .await
        .map_err(|error| anyhow::anyhow!(error.code))?;
    let error = request
        .begin_push_item(&state, &principal, None, None, None, None)
        .err()
        .ok_or_else(|| anyhow::anyhow!("fourth item bypassed quota"))?;
    assert_eq!(error.status, StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(error.retry_after, Some(20));
    // A 200 batch containing per-item errors must not append a generic batch row.
    request
        .finish(&state, "ok")
        .await
        .map_err(|error| anyhow::anyhow!(error.code))?;
    let owner = app.fixture.owner().await?;
    let operations: Vec<String> =
        sqlx::query_scalar("select operation from api_key_audit where api_key_id=$1 order by id")
            .bind(id)
            .fetch_all(&owner)
            .await?;
    assert_eq!(
        operations,
        vec!["push:create_tag", "push:list_tags", "push:unknown"]
    );
    let outcomes: Vec<String> =
        sqlx::query_scalar("select outcome from api_key_audit where api_key_id=$1 order by id")
            .bind(id)
            .fetch_all(&owner)
            .await?;
    assert_eq!(outcomes, vec!["ok", "not_found", "validation_failed"]);
    let request_ids: i64 = sqlx::query_scalar(
        "select count(distinct request_id) from api_key_audit where api_key_id=$1",
    )
    .bind(id)
    .fetch_one(&owner)
    .await?;
    assert_eq!(request_ids, 3);

    // Push must require read_write even when the chosen tool is read-only.
    let (readonly_id, readonly_key) = issue(&app, &session, "read").await?;
    let (readonly, request) = admitted_batch(&state, &readonly_key).await?;
    let ticket = request
        .begin_push_item(
            &state,
            &readonly,
            Some(app.plan.space_id.0),
            Some("list_tags"),
            Some(Uuid::now_v7()),
            None,
        )
        .map_err(|error| anyhow::anyhow!(error.code))?;
    let mut ctx = jiabu_tools::ToolCtx::begin(
        &state.db,
        readonly,
        app.plan.space_id,
        None,
        Effect::Read,
        jiabu_tools::Invocation {
            idempotency_key: None,
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: Utc::now(),
        },
    )
    .await?;
    let error = ticket
        .attach(&mut ctx)
        .err()
        .ok_or_else(|| anyhow::anyhow!("readonly key admitted into push"))?;
    assert_eq!(error.code, "api_key_read_only");
    drop(ctx); // Release the preflight transaction before independent error audit.
    ticket
        .finish(&state, error.code)
        .await
        .map_err(|error| anyhow::anyhow!(error.code))?;
    request
        .finish(&state, error.code)
        .await
        .map_err(|error| anyhow::anyhow!(error.code))?;
    assert_eq!(audit_count(&owner, readonly_id).await?, 1);
    owner.close().await;
    Ok(())
}
