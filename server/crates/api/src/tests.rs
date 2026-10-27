#[path = "../../../tests/support/mod.rs"]
mod support;
use crate::{ApiError, AppState, Principal};
use anyhow::{Result, ensure};
use axum::{
    Json, Router,
    body::{Body, to_bytes},
    extract::{ConnectInfo, Path, State},
    http::{HeaderMap, Request, StatusCode},
};
use jiabu_db::{AppDb, Mode, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
use serde_json::{Value, json};
use tower::ServiceExt;
use uuid::Uuid;

#[utoipa::path(get,path="/v1/spaces/{space_id}/probe",params(("space_id"=Uuid,Path)),responses((status=200,description="Test-only scope probe")))]
pub(crate) async fn probe(
    State(state): State<AppState>,
    principal: Principal,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let epoch = headers
        .get("x-jiabu-join-epoch")
        .map(|h| {
            h.to_str()
                .ok()
                .and_then(|s| s.parse::<i32>().ok())
                .map(JoinEpoch)
                .ok_or_else(ApiError::bad_request)
        })
        .transpose()?;
    let tx = SpaceTx::begin(
        &state.db,
        principal.user_id,
        &[(SpaceId(id), epoch)],
        Mode::Read,
    )
    .await?;
    jiabu_tools::authorize(
        tx.member(SpaceId(id)),
        jiabu_tools::Module::Ledger,
        jiabu_tools::Action::Read,
    )
    .map_err(|_| ApiError::not_found())?;
    Ok(Json(json!({"ok":true})))
}
struct TestApp {
    fixture: support::TestDb,
    router: Router,
    plan: jiabu_domain::space_init::SpaceInit,
}
struct Reply {
    status: StatusCode,
    headers: HeaderMap,
    bytes: Vec<u8>,
}
impl Reply {
    fn json(&self) -> Value {
        serde_json::from_slice(&self.bytes).unwrap_or(Value::Null)
    }
}
fn normalize_request_id(reply: &Reply) -> Result<Vec<u8>> {
    let parsed = reply.json();
    let id = parsed["request_id"]
        .as_str()
        .ok_or_else(|| anyhow::anyhow!("missing request ID"))?;
    let raw = std::str::from_utf8(&reply.bytes)?;
    ensure!(raw.matches(id).count() == 1, "request ID must occur once");
    // Preserve every other byte, including JSON key order and whitespace.
    Ok(raw
        .replacen(id, "00000000-0000-7000-8000-000000000000", 1)
        .into_bytes())
}
impl TestApp {
    async fn new(restricted: bool) -> Result<Self> {
        let fixture = support::TestDb::new().await?;
        let hash =
            crate::credentials::hash_password("sample-old-password").map_err(anyhow::Error::msg)?;
        let plan = fixture.seed("sample", &hash).await?;
        if !restricted {
            let owner = fixture.owner().await?;
            sqlx::query("update users set must_change_password=false")
                .execute(&owner)
                .await?;
            owner.close().await;
        }
        let state = AppState::new(AppDb::connect(&fixture.app_url).await?)
            .await
            .map_err(anyhow::Error::msg)?;
        Ok(Self {
            fixture,
            router: crate::router(state),
            plan,
        })
    }
    async fn request(
        &self,
        method: &str,
        path: &str,
        body: Value,
        token: Option<&str>,
        extra: &[(&str, String)],
    ) -> Result<Reply> {
        let mut builder = Request::builder()
            .method(method)
            .uri(path)
            .header("content-type", "application/json");
        if let Some(token) = token {
            builder = builder.header("authorization", format!("Bearer {token}"));
        }
        for (name, value) in extra {
            builder = builder.header(*name, value);
        }
        let mut request = builder.body(Body::from(serde_json::to_vec(&body)?))?;
        request.extensions_mut().insert(ConnectInfo(
            "192.0.2.1:12345".parse::<std::net::SocketAddr>()?,
        ));
        let response = self.router.clone().oneshot(request).await?;
        Ok(Reply {
            status: response.status(),
            headers: response.headers().clone(),
            bytes: to_bytes(response.into_body(), 3 * 1024 * 1024)
                .await?
                .to_vec(),
        })
    }
    async fn login(&self, password: &str) -> Result<Reply> {
        self.request(
            "POST",
            "/v1/auth/login",
            json!({"username":"sample","password":password,"device_name":"test-device"}),
            None,
            &[],
        )
        .await
    }
    async fn token(&self) -> Result<String> {
        let reply = self.login("sample-old-password").await?;
        ensure!(
            reply.status == StatusCode::OK,
            "login failed: {}",
            reply.status
        );
        Ok(reply.json()["token"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("missing token"))?
            .to_owned())
    }
}
// The matrix is separate from mounting so forgetting a registration actually fails.
const ISOLATION_MATRIX: &[(&str, &str)] = &[("GET", "/v1/spaces/{space_id}/probe")];
fn missing_routes(catalog: &[crate::RouteSpec], matrix: &[(&str, &str)]) -> Vec<String> {
    catalog
        .iter()
        .filter(|route| route.path.contains("/spaces/{") || route.path.contains("{space_id}"))
        .filter(|route| !matrix.contains(&(route.method, route.path)))
        .map(|r| format!("{} {}", r.method, r.path))
        .collect()
}
#[test]
fn every_space_route_is_registered_and_catalog_matches_router_document() -> Result<()> {
    let catalog = crate::route_catalog();
    assert!(missing_routes(&catalog, ISOLATION_MATRIX).is_empty());
    assert!(
        !missing_routes(&catalog, &[]).is_empty(),
        "negative control must catch an unregistered route"
    );
    let doc = serde_json::to_value(crate::openapi())?;
    let mut actual = std::collections::BTreeSet::new();
    for (path, item) in doc["paths"]
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("missing paths"))?
    {
        for method in ["get", "post", "patch", "delete", "put", "head", "options"] {
            if item.get(method).is_some() {
                actual.insert((method.to_uppercase(), path.clone()));
            }
        }
    }
    assert_eq!(
        actual,
        catalog
            .iter()
            .map(|r| (r.method.to_owned(), r.path.to_owned()))
            .collect()
    );
    Ok(())
}
#[tokio::test]
async fn isolation_matrix_responses_are_byte_identical() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let nonmember = app.fixture.seed("nonmember", "unused").await?;
    let exited = app.fixture.seed("exited", "unused").await?;
    let other = app.fixture.seed("other", "unused").await?;
    let owner = app.fixture.owner().await?;
    // A realistic former member keeps its row and module grants (only status changes),
    // so this case exercises the membership-status check rather than the grant check.
    let former: Uuid = sqlx::query_scalar("insert into space_members(space_id,user_id,display_name,role,status,left_reason,joined_at,left_at,change_seq) values($1,$2,'former','member','left','left',now(),now(),nextval('change_seq')) returning id")
        .bind(exited.space_id.0).bind(app.plan.user_id.0).fetch_one(&owner).await?;
    sqlx::query("insert into space_member_grants(member_id,module,level,change_seq) values($1,'ledger','write',nextval('change_seq')),($1,'documents','write',nextval('change_seq'))")
        .bind(former).execute(&owner).await?;
    owner.close().await;
    for (method, pattern) in ISOLATION_MATRIX {
        let mut previous = None;
        for id in [
            nonmember.space_id.0,
            exited.space_id.0,
            other.space_id.0,
            Uuid::now_v7(),
        ] {
            let reply = app
                .request(
                    method,
                    &pattern.replace("{space_id}", &id.to_string()),
                    Value::Null,
                    Some(&token),
                    &[],
                )
                .await?;
            assert_eq!(reply.status, StatusCode::NOT_FOUND);
            let normalized = normalize_request_id(&reply)?;
            if let Some(expected) = &previous {
                assert_eq!(expected, &normalized);
            }
            previous = Some(normalized);
        }
    }
    // The same mounted route must admit a real member, and reject stale epochs.
    let path = format!("/v1/spaces/{}/probe", app.plan.space_id);
    assert_eq!(
        app.request("GET", &path, Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::OK
    );
    let stale = app
        .request(
            "GET",
            &path,
            Value::Null,
            Some(&token),
            &[("x-jiabu-join-epoch", "2".into())],
        )
        .await?;
    assert_eq!(stale.status, StatusCode::CONFLICT);
    assert_eq!(stale.json()["code"], "membership_changed");
    let owner = app.fixture.owner().await?;
    sqlx::query("update space_members set join_epoch=2 where space_id=$1")
        .bind(app.plan.space_id.0)
        .execute(&owner)
        .await?;
    let stale = app
        .request(
            "GET",
            &path,
            Value::Null,
            Some(&token),
            &[("x-jiabu-join-epoch", "1".into())],
        )
        .await?;
    assert_eq!(stale.status, StatusCode::CONFLICT);
    sqlx::query("update space_member_grants set level='none'")
        .execute(&owner)
        .await?;
    assert_eq!(
        app.request("GET", &path, Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::NOT_FOUND
    );
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn tokens_are_hashes_logout_and_expiry_are_immediate() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let owner = app.fixture.owner().await?;
    let digest: Vec<u8> = sqlx::query_scalar("select token_hash from sessions")
        .fetch_one(&owner)
        .await?;
    assert_eq!(digest, crate::credentials::token_hash(&token));
    assert_ne!(digest, token.as_bytes());
    assert_eq!(digest.len(), 32);
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::OK
    );
    sqlx::query("update sessions set last_seen_at=now()-interval '2 days',expires_at=now()+interval '1 day'").execute(&owner).await?;
    app.request("GET", "/v1/me", Value::Null, Some(&token), &[])
        .await?;
    let renewed: bool =
        sqlx::query_scalar("select expires_at>now()+interval '179 days' from sessions")
            .fetch_one(&owner)
            .await?;
    assert!(renewed);
    assert_eq!(
        app.request("POST", "/v1/auth/logout", Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    let token = app.token().await?;
    sqlx::query("update sessions set expires_at=now()-interval '1 second'")
        .execute(&owner)
        .await?;
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn restricted_session_upgrade_removes_other_sessions() -> Result<()> {
    let app = TestApp::new(true).await?;
    let token = app.token().await?;
    let other = app.token().await?;
    let leaving = app.token().await?;
    for (method, path) in [
        ("GET", "/v1/me"),
        ("PATCH", "/v1/me"),
        ("POST", "/v1/client-logs"),
    ] {
        let reply = app
            .request(method, path, json!({}), Some(&token), &[])
            .await?;
        assert_eq!(reply.status, StatusCode::FORBIDDEN);
        assert_eq!(reply.json()["code"], "password_change_required");
    }
    // A restricted session can still end itself.
    assert_eq!(
        app.request("POST", "/v1/auth/logout", Value::Null, Some(&leaving), &[])
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        app.request("POST", "/v1/me/password", json!({}), Some(&leaving), &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    let owner = app.fixture.owner().await?;
    let short: bool = sqlx::query_scalar(
        "select bool_and(expires_at<=created_at+interval '15 minutes') from sessions",
    )
    .fetch_one(&owner)
    .await?;
    assert!(short);
    let body =
        json!({"current_password":"sample-old-password","new_password":"sample-new-password"});
    assert_eq!(
        app.request("POST", "/v1/me/password", body, Some(&token), &[])
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::OK
    );
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&other), &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    assert_eq!(
        app.login("sample-old-password").await?.status,
        StatusCode::UNAUTHORIZED
    );
    let full: bool = sqlx::query_scalar(
        "select kind='full' and expires_at>now()+interval '179 days' from sessions",
    )
    .fetch_one(&owner)
    .await?;
    assert!(full);
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn reset_notice_is_once_and_disable_deletes_sessions() -> Result<()> {
    let app = TestApp::new(false).await?;
    let old = app.token().await?;
    let admin = app.fixture.admin().await?;
    let temporary = jiabu_admin::reset_password(&admin, "sample", "test-operator").await?;
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&old), &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    let (a, b) = tokio::join!(app.login(&temporary), app.login(&temporary));
    let a = a?;
    let b = b?;
    assert_eq!(a.status, StatusCode::OK);
    assert_eq!(b.status, StatusCode::OK);
    assert_eq!(
        usize::from(a.json().get("admin_reset_at").is_some())
            + usize::from(b.json().get("admin_reset_at").is_some()),
        1
    );
    assert_eq!(a.json()["session_kind"], "password_change");
    let token = a.json()["token"]
        .as_str()
        .ok_or_else(|| anyhow::anyhow!("missing token"))?
        .to_owned();
    jiabu_admin::set_disabled(&admin, "sample", true, "test-operator").await?;
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    let owner = app.fixture.owner().await?;
    let count: i64 = sqlx::query_scalar("select count(*) from sessions")
        .fetch_one(&owner)
        .await?;
    assert_eq!(count, 0);
    assert_eq!(
        app.login(&temporary).await?.status,
        StatusCode::UNAUTHORIZED
    );
    jiabu_admin::set_disabled(&admin, "sample", false, "test-operator").await?;
    assert_eq!(
        app.request("GET", "/v1/me", Value::Null, Some(&token), &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    assert_eq!(app.login(&temporary).await?.status, StatusCode::OK);
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn login_sixth_attempt_is_429_and_failures_are_indistinguishable() -> Result<()> {
    let app = TestApp::new(false).await?;
    let mut failure = None;
    for i in 0..6 {
        let reply = app
            .request(
                "POST",
                "/v1/auth/login",
                json!({"username":if i%2==0{"sample"}else{"missing"},"password":"wrong-password"}),
                None,
                &[],
            )
            .await?;
        if i < 5 {
            assert_eq!(reply.status, StatusCode::UNAUTHORIZED);
            let value = normalize_request_id(&reply)?;
            if let Some(expected) = &failure {
                assert_eq!(&value, expected);
            }
            failure = Some(value);
        } else {
            assert_eq!(reply.status, StatusCode::TOO_MANY_REQUESTS);
            assert!(reply.headers.contains_key("retry-after"));
        }
    }
    Ok(())
}
#[tokio::test]
async fn meta_handshake_locale_and_problem_contract() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let meta = app
        .request("GET", "/v1/meta", Value::Null, None, &[])
        .await?;
    assert_eq!(meta.json()["api_versions"], json!([1]));
    assert_eq!(
        meta.json()["min_client_build"],
        json!({"stable":0,"beta":0})
    );
    assert_eq!(meta.json()["features"], json!([]));
    assert!(meta.json().get("server_version").is_some());
    assert_eq!(
        app.request("PATCH", "/v1/me", json!({"locale":"en"}), Some(&token), &[])
            .await?
            .json()["locale"],
        "en"
    );
    assert_eq!(
        app.request(
            "PATCH",
            "/v1/me",
            json!({"locale":"invalid"}),
            Some(&token),
            &[]
        )
        .await?
        .status,
        StatusCode::UNPROCESSABLE_ENTITY
    );
    let owner = app.fixture.owner().await?;
    sqlx::query("insert into app_releases(build,version,channel,sha256,bytes,cert_sha256,min_server_api,security_force,notes,source,status) values(10,'0.1.0','stable',decode('00','hex'),1,decode('00','hex'),1,true,'{}','manual','available')").execute(&owner).await?;
    let header = [("x-jiabu-client", "android/0.1.0+9; channel=stable".into())];
    let old = app
        .request("GET", "/v1/me", Value::Null, Some(&token), &header)
        .await?;
    assert_eq!(old.status, StatusCode::UPGRADE_REQUIRED);
    assert_eq!(old.json()["code"], "client_too_old");
    assert_eq!(
        app.request("GET", "/v1/meta", Value::Null, None, &header)
            .await?
            .status,
        StatusCode::OK
    );
    assert_eq!(
        app.request(
            "POST",
            "/v1/auth/login",
            json!({"username":"sample","password":"sample-old-password"}),
            None,
            &header
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_eq!(app.request("POST","/v1/client-logs",json!({"entries":[],"app_version":"0.1.0","build":9,"device_model":"example-device","os_version":"example-os"}),Some(&token),&header).await?.status,StatusCode::NO_CONTENT);
    assert_eq!(
        app.request(
            "GET",
            "/v1/me",
            Value::Null,
            Some(&token),
            &[("x-jiabu-client", "android/0.1.0+9; channel=beta".into())]
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_eq!(
        app.request(
            "GET",
            "/v1/me",
            Value::Null,
            Some(&token),
            &[("x-jiabu-client", "malformed".into())]
        )
        .await?
        .status,
        StatusCode::BAD_REQUEST
    );
    assert_eq!(
        app.request("GET", "/healthz", Value::Null, None, &header)
            .await?
            .status,
        StatusCode::OK
    );
    assert_eq!(
        app.request(
            "GET",
            "/v1/me",
            Value::Null,
            Some(&token),
            &[("x-jiabu-client", "android/0.1.0+10; channel=stable".into())]
        )
        .await?
        .status,
        StatusCode::OK
    );
    let id = Uuid::now_v7();
    let reply = app
        .request(
            "GET",
            "/missing",
            Value::Null,
            None,
            &[("x-request-id", id.to_string())],
        )
        .await?;
    assert_eq!(reply.json()["request_id"], id.to_string());
    assert_eq!(reply.headers["x-request-id"].to_str()?, id.to_string());
    assert_eq!(reply.headers["content-type"], "application/problem+json");
    let bad = app
        .request(
            "GET",
            "/missing",
            Value::Null,
            None,
            &[("x-request-id", "untrusted-text".into())],
        )
        .await?;
    assert!(Uuid::parse_str(bad.json()["request_id"].as_str().unwrap()).is_ok());
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn client_log_limits_and_authentication() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let entry = json!({"ts":"2026-01-01T00:00:00Z","level":"ERROR","logger":"example","message":"example crash","error_type":"ExampleError","stack":"example frame"});
    let body = json!({"entries":[entry.clone()],"app_version":"0.1.0","build":1,"device_model":"example-device","os_version":"example-os"});
    assert_eq!(
        app.request("POST", "/v1/client-logs", body.clone(), None, &[])
            .await?
            .status,
        StatusCode::UNAUTHORIZED
    );
    assert_eq!(
        app.request("POST", "/v1/client-logs", body.clone(), Some(&token), &[])
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    let mut too_many = body.clone();
    too_many["entries"] = json!(vec![entry; 101]);
    assert_eq!(
        app.request("POST", "/v1/client-logs", too_many, Some(&token), &[])
            .await?
            .status,
        StatusCode::PAYLOAD_TOO_LARGE
    );
    for (field, size) in [("message", 2049), ("stack", 8193)] {
        let mut invalid = body.clone();
        invalid["entries"][0][field] = json!("a".repeat(size));
        assert_eq!(
            app.request("POST", "/v1/client-logs", invalid, Some(&token), &[])
                .await?
                .status,
            StatusCode::UNPROCESSABLE_ENTITY
        );
    }
    let mut multibyte = body.clone();
    multibyte["entries"][0]["message"] = json!("字".repeat(683));
    assert_eq!(
        app.request("POST", "/v1/client-logs", multibyte, Some(&token), &[])
            .await?
            .status,
        StatusCode::UNPROCESSABLE_ENTITY
    );
    let mut maximum = body;
    maximum["entries"][0]["message"] = json!("a".repeat(2048));
    maximum["entries"][0]["stack"] = json!("a".repeat(8192));
    assert_eq!(
        app.request("POST", "/v1/client-logs", maximum, Some(&token), &[])
            .await?
            .status,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        app.request(
            "POST",
            "/v1/auth/login",
            json!({"username":"sample","password":"a".repeat(2*1024*1024)}),
            None,
            &[]
        )
        .await?
        .status,
        StatusCode::PAYLOAD_TOO_LARGE
    );
    Ok(())
}
#[derive(Clone)]
struct LogWriter(std::sync::Arc<std::sync::Mutex<Vec<u8>>>);
impl std::io::Write for LogWriter {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        self.0
            .lock()
            .map_err(|_| std::io::Error::other("log lock"))?
            .extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
impl<'a> tracing_subscriber::fmt::MakeWriter<'a> for LogWriter {
    type Writer = Self;
    fn make_writer(&'a self) -> Self {
        self.clone()
    }
}
#[tokio::test]
async fn request_log_snapshot_contains_context_without_credentials() -> Result<()> {
    use tracing::instrument::WithSubscriber;
    let app = TestApp::new(false).await?;
    let buffer = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
    let subscriber = tracing_subscriber::fmt()
        .json()
        .flatten_event(true)
        .with_current_span(true)
        .with_span_list(false)
        .with_max_level(tracing::Level::INFO)
        .with_writer(LogWriter(buffer.clone()))
        .finish();
    let id = Uuid::now_v7();
    let reply = app
        .request(
            "POST",
            "/v1/auth/login",
            json!({"username":"sample","password":"sample-old-password"}),
            None,
            &[("x-request-id", id.to_string())],
        )
        .with_subscriber(subscriber)
        .await?;
    let token = reply.json()["token"].as_str().unwrap().to_owned();
    let bytes = buffer.lock().unwrap().clone();
    let raw = String::from_utf8(bytes)?;
    assert!(!raw.contains("sample-old-password"));
    assert!(!raw.contains(&token));
    assert!(!raw.contains("Authorization"));
    let mut snapshot = Vec::new();
    for line in raw.lines() {
        let value: Value = serde_json::from_str(line)?;
        assert_eq!(value["span"]["request_id"], id.to_string());
        if value.get("message") == Some(&json!("Request completed")) {
            snapshot.push(json!({"message":value["message"],"route":value["span"]["route"],"status":value["span"]["status"],"has_user_id":value["span"].get("user_id").is_some(),"has_elapsed_ms":value["span"].get("elapsed_ms").is_some()}));
        }
    }
    assert_eq!(snapshot,json!([{"message":"Request completed","route":"/v1/auth/login","status":200,"has_user_id":true,"has_elapsed_ms":true}]).as_array().unwrap().clone());
    Ok(())
}

#[tokio::test]
async fn module_grants_are_loaded_without_owner_shortcut() -> Result<()> {
    let app = TestApp::new(false).await?;
    let owner = app.fixture.owner().await?;
    sqlx::query("update space_member_grants set level=case module when 'ledger' then 'write' else 'none' end").execute(&owner).await?;
    let db = AppDb::connect(&app.fixture.app_url).await?;
    let tx = SpaceTx::begin(
        &db,
        app.plan.user_id,
        &[(app.plan.space_id, None)],
        Mode::Read,
    )
    .await?;
    let member = tx.member(app.plan.space_id);
    assert!(member.is_owner());
    assert!(
        jiabu_tools::authorize(
            member,
            jiabu_tools::Module::Ledger,
            jiabu_tools::Action::Write
        )
        .is_ok()
    );
    assert!(
        jiabu_tools::authorize(
            member,
            jiabu_tools::Module::Ledger,
            jiabu_tools::Action::Manage
        )
        .is_err()
    );
    assert!(
        jiabu_tools::authorize(
            member,
            jiabu_tools::Module::Documents,
            jiabu_tools::Action::Read
        )
        .is_err()
    );
    tx.rollback().await?;
    db.close().await?;
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn admin_create_uses_domain_defaults_and_requires_password_change() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let admin = fixture.admin().await?;
    let result = jiabu_admin::create_user(
        &admin,
        jiabu_admin::CreateUser {
            username: "created".into(),
            password: None,
            space_name: "个人空间".into(),
            timezone: "Asia/Shanghai".into(),
            currency: "CNY".into(),
        },
        "test-operator",
    )
    .await?;
    let password = result
        .temporary_password
        .ok_or_else(|| anyhow::anyhow!("expected generated password"))?;
    let owner = fixture.owner().await?;
    let valid:bool=sqlx::query_scalar("select s.name='个人空间' and s.accent_color='terracotta' and s.timezone='Asia/Shanghai' and s.currency='CNY' and s.is_default and u.must_change_password from spaces s join users u on u.id=s.created_by_user_id where u.id=$1").bind(result.id.0).fetch_one(&owner).await?;
    assert!(valid);
    let state = AppState::new(AppDb::connect(&fixture.app_url).await?)
        .await
        .map_err(anyhow::Error::msg)?;
    let response = crate::router(state)
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/auth/login")
                .header("content-type", "application/json")
                .extension(ConnectInfo(
                    "192.0.2.1:1234".parse::<std::net::SocketAddr>()?,
                ))
                .body(Body::from(serde_json::to_vec(
                    &json!({"username":"created","password":password}),
                )?))?,
        )
        .await?;
    assert_eq!(response.status(), StatusCode::OK);
    let value: Value = serde_json::from_slice(&to_bytes(response.into_body(), 1024 * 1024).await?)?;
    assert_eq!(value["session_kind"], "password_change");
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn client_crash_logs_keep_upload_context_and_no_authorization() -> Result<()> {
    use tracing::instrument::WithSubscriber;
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let buffer = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
    let subscriber = tracing_subscriber::fmt()
        .json()
        .flatten_event(true)
        .with_current_span(true)
        .with_span_list(false)
        .with_max_level(tracing::Level::INFO)
        .with_writer(LogWriter(buffer.clone()))
        .finish();
    let id = Uuid::now_v7();
    let client_id = Uuid::now_v7();
    let body = json!({"entries":[{"ts":"2026-01-01T00:00:00Z","level":"ERROR","logger":"example","message":"example crash","error_type":"ExampleError","stack":"example frame","request_id":client_id}],"app_version":"0.1.0","build":1,"device_model":"example-device","os_version":"example-os"});
    let reply = app
        .request(
            "POST",
            "/v1/client-logs",
            body,
            Some(&token),
            &[("x-request-id", id.to_string())],
        )
        .with_subscriber(subscriber)
        .await?;
    assert_eq!(reply.status, StatusCode::NO_CONTENT);
    let text = String::from_utf8(buffer.lock().unwrap().clone())?;
    assert!(!text.contains(&token));
    assert!(!text.contains("Bearer "));
    let mut client_count = 0;
    for line in text.lines() {
        let value: Value = serde_json::from_str(line)?;
        assert_eq!(value["span"]["request_id"], id.to_string());
        assert_eq!(value["span"]["user_id"], app.plan.user_id.to_string());
        assert_eq!(value["span"]["status"], 204);
        assert!(value["span"].get("elapsed_ms").is_some());
        if value["target"] == "client" {
            client_count += 1;
            assert_eq!(value["request_id"], id.to_string());
            assert_eq!(value["message"], "example crash");
            assert_eq!(value["stack"], "example frame");
            assert_eq!(value["client_request_id"], client_id.to_string());
        }
    }
    assert_eq!(client_count, 1);
    let batches: Vec<Value> = text
        .lines()
        .map(serde_json::from_str::<Value>)
        .collect::<Result<Vec<_>, _>>()?
        .into_iter()
        .filter(|v| v["target"] == "client_batch")
        .collect();
    assert_eq!(batches.len(), 1);
    assert_eq!(batches[0]["request_id"], id.to_string());
    assert_eq!(batches[0]["device_model"], "example-device");
    assert_eq!(batches[0]["entries"], 1);
    // Entry lines join the batch by request_id instead of repeating device context.
    for line in text.lines() {
        let value: Value = serde_json::from_str(line)?;
        if value["target"] == "client" {
            assert!(value.get("device_model").is_none());
            assert!(value.get("app_version").is_none());
        }
    }
    Ok(())
}
#[tokio::test]
async fn principal_rechecks_disabled_state_even_with_a_retained_session() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let owner = app.fixture.owner().await?;
    // Bypass the management service to prove the extractor itself checks disabled_at.
    sqlx::query("update users set disabled_at=now() where id=$1")
        .bind(app.plan.user_id.0)
        .execute(&owner)
        .await?;
    let reply = app
        .request("GET", "/v1/me", Value::Null, Some(&token), &[])
        .await?;
    assert_eq!(reply.status, StatusCode::UNAUTHORIZED);
    assert_eq!(reply.json()["code"], "account_disabled");
    owner.close().await;
    Ok(())
}
#[test]
fn openapi_body_operations_have_examples() -> Result<()> {
    fn has_example(value: &Value) -> bool {
        match value {
            Value::Object(fields) => {
                fields.contains_key("example")
                    || fields.contains_key("examples")
                    || fields.values().any(has_example)
            }
            Value::Array(items) => items.iter().any(has_example),
            _ => false,
        }
    }
    let document = serde_json::to_value(crate::openapi())?;
    for (path, item) in document["paths"].as_object().unwrap() {
        for method in ["get", "post", "patch", "delete"] {
            if let Some(operation) = item.get(method) {
                let has_request = operation.get("requestBody").is_some();
                let has_success_body =
                    operation["responses"].as_object().is_some_and(|responses| {
                        responses.iter().any(|(status, response)| {
                            status.starts_with('2') && response.get("content").is_some()
                        })
                    });
                if has_request || has_success_body {
                    assert!(has_example(operation), "missing example: {method} {path}");
                }
            }
        }
    }
    Ok(())
}

fn client_log_body() -> Value {
    json!({"entries":[{"ts":"2026-01-01T00:00:00Z","level":"ERROR","logger":"example","message":"example crash","error_type":"ExampleError","stack":"example frame"}],"app_version":"0.1.0","build":1,"device_model":"example-device","os_version":"example-os"})
}
#[tokio::test]
async fn client_log_metadata_fields_are_capped() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let cases: [(&[&str], Value); 7] = [
        (&["app_version"], json!("a".repeat(65))),
        (&["device_model"], json!("a".repeat(129))),
        (&["os_version"], json!("a".repeat(129))),
        (&["entries", "logger"], json!("a".repeat(129))),
        (&["entries", "level"], json!("A".repeat(17))),
        (&["entries", "level"], json!("ERROR\nforged")),
        (&["entries", "error_type"], json!("a".repeat(257))),
    ];
    for (path, value) in cases {
        let mut body = client_log_body();
        match path {
            [field] => body[*field] = value,
            [_, field] => body["entries"][0][*field] = value,
            _ => unreachable!(),
        }
        let reply = app
            .request("POST", "/v1/client-logs", body, Some(&token), &[])
            .await?;
        assert_eq!(reply.status, StatusCode::UNPROCESSABLE_ENTITY, "{path:?}");
    }
    Ok(())
}
#[tokio::test]
async fn client_log_uploads_have_a_per_user_quota() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    for _ in 0..crate::state::CLIENT_LOG_BATCHES_PER_MINUTE {
        let reply = app
            .request(
                "POST",
                "/v1/client-logs",
                client_log_body(),
                Some(&token),
                &[],
            )
            .await?;
        assert_eq!(reply.status, StatusCode::NO_CONTENT);
    }
    let reply = app
        .request(
            "POST",
            "/v1/client-logs",
            client_log_body(),
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(reply.status, StatusCode::TOO_MANY_REQUESTS);
    assert!(reply.headers.contains_key("retry-after"));
    Ok(())
}
#[tokio::test]
async fn password_change_attempts_share_the_login_limit() -> Result<()> {
    let app = TestApp::new(false).await?;
    // The login that created this session already used one of the user's five attempts.
    let token = app.token().await?;
    let wrong = json!({"current_password":"wrong-password","new_password":"sample-new-password"});
    for _ in 0..4 {
        let reply = app
            .request("POST", "/v1/me/password", wrong.clone(), Some(&token), &[])
            .await?;
        assert_eq!(reply.status, StatusCode::UNAUTHORIZED);
    }
    let reply = app
        .request("POST", "/v1/me/password", wrong, Some(&token), &[])
        .await?;
    assert_eq!(reply.status, StatusCode::TOO_MANY_REQUESTS);
    assert!(reply.headers.contains_key("retry-after"));
    // The same bucket now also blocks login for this username.
    assert_eq!(
        app.login("sample-old-password").await?.status,
        StatusCode::TOO_MANY_REQUESTS
    );
    Ok(())
}
