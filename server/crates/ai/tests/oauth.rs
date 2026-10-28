mod support;
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use jiabu_ai::{
    ProviderError,
    credentials::{CredentialManager, TokenStore},
    siwc::oauth::{OAuthClient, REDIRECT, SCOPES},
};
use serde_json::json;
use std::sync::Arc;
use support::*;
use wiremock::{
    Mock, MockServer, ResponseTemplate,
    matchers::{body_string_contains, method, path},
};
fn id_token(issuer: &str, aud: &str, nonce: &str, exp: i64) -> String {
    // Synthetic JWT: deliberately no real signature; direct token TLS trust per go1.
    let claims = json!({"iss":issuer,"aud":aud,"exp":exp,"nonce":nonce,"https://api.openai.com/auth":{"chatgpt_account_id":"synthetic-account"}});
    format!(
        "e30.{}.synthetic",
        URL_SAFE_NO_PAD.encode(serde_json::to_vec(&claims).unwrap())
    )
}
#[tokio::test]
async fn pkce_login_posts_verifier_resource_and_validates_callback_state() {
    let server = MockServer::start().await;
    let oauth = OAuthClient::at(&server.uri()).unwrap();
    let login = oauth.begin(uuid::Uuid::nil(), Some("oaiapp_fake")).unwrap();
    let query: std::collections::BTreeMap<_, _> = login
        .authorize_url
        .query_pairs()
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    assert_eq!(query["code_challenge_method"], "S256");
    assert_eq!(query["resource"], "https://api.openai.com/v1");
    assert_eq!(query["ext_agent_host_id"], uuid::Uuid::nil().to_string());
    assert!(!login.authorize_url.as_str().contains("code_verifier"));
    let token = id_token(
        &server.uri(),
        "oaiapp_fake",
        &query["nonce"],
        chrono::Utc::now().timestamp() + 3600,
    );
    Mock::given(method("POST"))
        .and(path("/oauth/token")).and(body_string_contains("code_verifier=")).and(body_string_contains("grant_type=authorization_code")).respond_with(ResponseTemplate::new(200).set_body_json(json!({"access_token":"synthetic-access","refresh_token":"synthetic-refresh","id_token":token,"expires_in":3600,"token_type":"Bearer","scope":SCOPES})))
    .expect(1)
    .mount(&server)
    .await;
    let callback = format!("{REDIRECT}?code=synthetic-code&state={}", query["state"]);
    let credentials = oauth.complete(login, &callback).await.unwrap();
    assert_eq!(credentials.account_id, "synthetic-account");
    let request = &server.received_requests().await.unwrap()[0];
    let form: std::collections::BTreeMap<_, _> = reqwest::Url::parse(&format!(
        "http://localhost/?{}",
        String::from_utf8_lossy(&request.body)
    ))
    .unwrap()
    .query_pairs()
    .map(|(k, v)| (k.into_owned(), v.into_owned()))
    .collect();
    use oauth2::{PkceCodeChallenge, PkceCodeVerifier};
    let challenge = PkceCodeChallenge::from_code_verifier_sha256(&PkceCodeVerifier::new(
        form["code_verifier"].clone(),
    ));
    assert_eq!(challenge.as_str(), query["code_challenge"]);
}
#[tokio::test]
async fn state_mismatch_duplicate_state_and_wrong_callback_never_contact_token_endpoint() {
    let server = MockServer::start().await;
    let oauth = OAuthClient::at(&server.uri()).unwrap();
    for callback in [
        format!("{REDIRECT}?code=synthetic&state=wrong"),
        format!("{REDIRECT}?code=synthetic&state=x&state=x"),
        "http://localhost:9999/auth/callback?code=synthetic&state=x".into(),
    ] {
        let login = oauth.begin(uuid::Uuid::nil(), None).unwrap();
        assert!(matches!(
            oauth.complete(login, &callback).await,
            Err(ProviderError::Auth)
        ));
    }
    assert!(server.received_requests().await.unwrap().is_empty());
}
#[tokio::test]
async fn id_token_issuer_audience_expiry_and_nonce_are_checked() {
    let server = MockServer::start().await;
    let oauth = OAuthClient::at(&server.uri()).unwrap();
    for field in ["iss", "aud", "exp", "nonce"] {
        server.reset().await;
        let login = oauth.begin(uuid::Uuid::nil(), Some("oaiapp_fake")).unwrap();
        let params: std::collections::BTreeMap<_, _> = login
            .authorize_url
            .query_pairs()
            .map(|(k, v)| (k.into_owned(), v.into_owned()))
            .collect();
        let uri = server.uri();
        let token = id_token(
            if field == "iss" {
                "https://invalid.example"
            } else {
                &uri
            },
            if field == "aud" {
                "wrong"
            } else {
                "oaiapp_fake"
            },
            if field == "nonce" {
                "wrong"
            } else {
                &params["nonce"]
            },
            if field == "exp" {
                1
            } else {
                chrono::Utc::now().timestamp() + 3600
            },
        );
        Mock::given(method("POST")).respond_with(ResponseTemplate::new(200).set_body_json(json!({"access_token":"synthetic-access","refresh_token":"synthetic-refresh","id_token":token,"expires_in":3600,"token_type":"Bearer","scope":SCOPES}))).mount(&server).await;
        let result = oauth
            .complete(
                login,
                &format!("{REDIRECT}?code=synthetic&state={}", params["state"]),
            )
            .await;
        assert!(matches!(result, Err(ProviderError::Auth)), "{field}");
    }
}
#[tokio::test]
async fn refresh_rotation_saves_new_refresh_token_and_failure_disables_availability() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/oauth/token")).respond_with(ResponseTemplate::new(200).set_body_json(json!({"access_token":"synthetic-new-access","refresh_token":"synthetic-rotated-refresh","expires_in":3600,"token_type":"Bearer"})))
    .expect(1)
    .mount(&server)
    .await;
    let tokens = Tokens::new(1);
    let manager = Arc::new(
        CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await,
    );
    let adapter = Arc::new(
        jiabu_ai::siwc::SiwcProvider::at(
            "fake-1".into(),
            capabilities(),
            manager.clone(),
            &format!("{}/v1/responses", server.uri()),
        )
        .unwrap(),
    );
    let router = jiabu_ai::AiRouter::new(config(), vec![adapter]);
    assert!(router.availability(jiabu_ai::TaskKind::Chat).available);
    assert!(manager.available());
    let access = manager.access().await.unwrap();
    assert_eq!(access.refresh_token, "synthetic-rotated-refresh");
    assert_eq!(tokens.snapshot().await.revision, 2);
    server.reset().await;
    Mock::given(method("POST"))
        .respond_with(ResponseTemplate::new(400).set_body_json(json!({"error":"invalid_grant"})))
        .mount(&server)
        .await;
    {
        tokens.0.lock().unwrap().credentials.expires_at = 1;
    }
    assert!(manager.access().await.is_err());
    assert!(!manager.available());
    assert!(!router.availability(jiabu_ai::TaskKind::Chat).available);
    assert!(!tokens.snapshot().await.usable);
}
#[tokio::test]
async fn concurrent_access_serializes_one_refresh_and_stale_access_error_preserves_rotation() {
    let server = MockServer::start().await;
    Mock::given(method("POST")).respond_with(ResponseTemplate::new(200).set_body_json(json!({"access_token":"synthetic-new-access","refresh_token":"synthetic-new-refresh","expires_in":3600,"token_type":"Bearer"})))
    .expect(1)
    .mount(&server)
    .await;
    let tokens = Tokens::new(1);
    let manager =
        CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await;
    let (a, b) = tokio::join!(manager.access(), manager.access());
    assert!(a.is_ok() && b.is_ok());
    assert_eq!(tokens.snapshot().await.revision, 2);
    manager
        .refresh_after_rejection("synthetic-old-access")
        .await
        .unwrap();
    assert!(manager.available());
    assert!(tokens.snapshot().await.usable);
}

#[tokio::test]
async fn reload_generations_share_refresh_gate_and_do_not_reuse_rotated_token() {
    let server = MockServer::start().await;
    Mock::given(method("POST")).respond_with(ResponseTemplate::new(200).set_delay(std::time::Duration::from_millis(20)).set_body_json(json!({"access_token":"synthetic-new-access","refresh_token":"synthetic-new-refresh","expires_in":3600,"token_type":"Bearer"})))
    .expect(1)
    .mount(&server)
    .await;
    let tokens = Tokens::new(1);
    let gate = Arc::new(jiabu_ai::credentials::RefreshGate::default());
    let first = CredentialManager::with_gate(
        tokens.clone(),
        OAuthClient::at(&server.uri()).unwrap(),
        gate.clone(),
    )
    .await;
    let next = CredentialManager::with_gate(
        tokens.clone(),
        OAuthClient::at(&server.uri()).unwrap(),
        gate,
    )
    .await;
    let (a, b) = tokio::join!(first.access(), next.access());
    assert!(a.is_ok() && b.is_ok());
    assert_eq!(tokens.snapshot().await.revision, 2);
}

#[tokio::test]
async fn temporary_refresh_failure_recovers_without_login_and_observes_backoff() {
    for still_valid in [false, true] {
        let server = MockServer::start().await;
        Mock::given(method("POST"))
            .respond_with(ResponseTemplate::new(503))
            .expect(1)
            .mount(&server)
            .await;
        let tokens = Tokens::new(if still_valid {
            chrono::Utc::now().timestamp() + 30
        } else {
            1
        });
        let manager =
            CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await;
        let result = manager.access().await;
        if still_valid {
            assert_eq!(result.unwrap().access_token, "synthetic-access");
        } else {
            assert!(matches!(result, Err(ProviderError::Transport)));
        }
        assert_eq!(manager.available(), still_valid);
        assert!(tokens.snapshot().await.usable);
        assert_eq!(tokens.snapshot().await.revision, 1);
        assert_eq!(manager.access().await.is_ok(), still_valid);
        assert_eq!(server.received_requests().await.unwrap().len(), 1);
        server.reset().await;
        Mock::given(method("POST")).respond_with(ResponseTemplate::new(200).set_body_json(json!({"access_token":"synthetic-recovered","expires_in":3600,"token_type":"Bearer"})))
        .expect(1)
        .mount(&server)
        .await;
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        assert!(manager.available());
        assert_eq!(
            manager.access().await.unwrap().access_token,
            "synthetic-recovered"
        );
        assert!(tokens.snapshot().await.usable);
        assert_eq!(tokens.snapshot().await.revision, 2);
    }
}
#[tokio::test]
async fn only_explicit_oauth_rejection_is_permanent() {
    for (status, body, permanent) in [
        (400, json!({"error":"invalid_grant"}), true),
        (401, json!({"error":"invalid_client"}), true),
        (401, json!({"error":"unknown"}), false),
        (400, json!({"error":"temporarily_unavailable"}), false),
        (429, json!({"error":"invalid_grant"}), false),
        (503, json!({"error":"invalid_grant"}), false),
    ] {
        let server = MockServer::start().await;
        Mock::given(method("POST"))
            .respond_with(ResponseTemplate::new(status).set_body_json(body))
            .mount(&server)
            .await;
        let tokens = Tokens::new(1);
        let manager =
            CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await;
        let error = manager.access().await.err().unwrap();
        assert_eq!(error == ProviderError::Auth, permanent);
        assert_eq!(!tokens.snapshot().await.usable, permanent);
        if permanent {
            assert!(matches!(manager.access().await, Err(ProviderError::Auth)));
            assert_eq!(server.received_requests().await.unwrap().len(), 1);
            assert!(!manager.available());
        }
    }
}

#[tokio::test]
async fn old_access_expiring_during_refresh_backoff_temporarily_removes_availability() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .respond_with(ResponseTemplate::new(503))
        .expect(1)
        .mount(&server)
        .await;
    let tokens = Tokens::new(chrono::Utc::now().timestamp() + 2);
    let manager =
        CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await;
    assert!(manager.access().await.is_ok());
    assert!(manager.available());
    tokio::time::sleep(std::time::Duration::from_secs(3)).await;
    assert!(!manager.available());
    assert!(matches!(
        manager.access().await,
        Err(ProviderError::Transport)
    ));
    assert!(tokens.snapshot().await.usable);
    assert_eq!(server.received_requests().await.unwrap().len(), 1);
}

struct FlakyRead {
    tokens: Arc<Tokens>,
    fail: std::sync::atomic::AtomicBool,
}
#[async_trait::async_trait]
impl TokenStore for FlakyRead {
    async fn load(&self) -> Result<jiabu_ai::credentials::TokenRead, ProviderError> {
        if self.fail.swap(false, std::sync::atomic::Ordering::SeqCst) {
            Ok(jiabu_ai::credentials::TokenRead::Unavailable)
        } else {
            self.tokens.load().await
        }
    }
    async fn compare_exchange(
        &self,
        revision: i64,
        next: &jiabu_ai::siwc::oauth::OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        self.tokens.compare_exchange(revision, next).await
    }
    async fn invalidate(&self, revision: i64) -> Result<bool, ProviderError> {
        self.tokens.invalidate(revision).await
    }
}
#[tokio::test]
async fn temporary_store_read_failure_at_initialization_or_access_recovers_after_backoff() {
    for initialization in [true, false] {
        let store = Arc::new(FlakyRead {
            tokens: Tokens::new(chrono::Utc::now().timestamp() + 3600),
            fail: std::sync::atomic::AtomicBool::new(initialization),
        });
        // No network needed: the valid stored access token needs no refresh.
        let manager = CredentialManager::new(
            store.clone(),
            OAuthClient::at("http://127.0.0.1:1").unwrap(),
        )
        .await;
        if !initialization {
            assert!(manager.available());
            store.fail.store(true, std::sync::atomic::Ordering::SeqCst);
            assert!(matches!(
                manager.access().await,
                Err(ProviderError::Transport)
            ));
        }
        assert!(!manager.available());
        assert!(matches!(
            manager.access().await,
            Err(ProviderError::Transport)
        ));
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        assert!(manager.available());
        assert_eq!(
            manager.access().await.unwrap().access_token,
            "synthetic-access"
        );
        assert!(manager.available());
        assert!(store.tokens.snapshot().await.usable);
    }
}

#[tokio::test]
async fn concurrent_access_token_rejections_force_only_one_refresh() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/oauth/token"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "access_token":"synthetic-new-access", "refresh_token":"synthetic-new-refresh",
            "expires_in":3600, "token_type":"Bearer"
        })))
        .expect(1)
        .mount(&server)
        .await;
    let tokens = Tokens::new(chrono::Utc::now().timestamp() + 3600);
    let manager =
        CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await;
    let (a, b) = tokio::join!(
        manager.refresh_after_rejection("synthetic-access"),
        manager.refresh_after_rejection("synthetic-access")
    );
    assert_eq!(a.unwrap().access_token, "synthetic-new-access");
    assert_eq!(b.unwrap().access_token, "synthetic-new-access");
    assert_eq!(tokens.snapshot().await.revision, 2);
    assert!(manager.available());
}

struct FlakyWrite {
    tokens: Arc<Tokens>,
    fail: std::sync::atomic::AtomicBool,
    committed: bool,
}
#[async_trait::async_trait]
impl TokenStore for FlakyWrite {
    async fn load(&self) -> Result<jiabu_ai::credentials::TokenRead, ProviderError> {
        self.tokens.load().await
    }
    async fn compare_exchange(
        &self,
        revision: i64,
        next: &jiabu_ai::siwc::oauth::OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        if self.fail.load(std::sync::atomic::Ordering::SeqCst) {
            if self.committed {
                self.tokens.compare_exchange(revision, next).await?;
            }
            return Err(ProviderError::Transport);
        }
        self.tokens.compare_exchange(revision, next).await
    }
    async fn invalidate(&self, revision: i64) -> Result<bool, ProviderError> {
        self.tokens.invalidate(revision).await
    }
}
#[tokio::test]
async fn rotated_credentials_survive_write_failure_and_retry_original_cas() {
    // Also cover an ambiguous commit and a competing login winning the CAS.
    for (committed, competing) in [(false, false), (true, false), (false, true)] {
        let server = MockServer::start().await;
        Mock::given(method("POST"))
            .and(path("/oauth/token"))
            .respond_with(ResponseTemplate::new(200).set_body_json(json!({
                "access_token":"synthetic-new-access", "refresh_token":"synthetic-new-refresh",
                "expires_in":3600, "token_type":"Bearer"
            })))
            .expect(1)
            .mount(&server)
            .await;
        let store = Arc::new(FlakyWrite {
            tokens: Tokens::new(1),
            fail: std::sync::atomic::AtomicBool::new(true),
            committed,
        });
        let gate = Arc::new(jiabu_ai::credentials::RefreshGate::default());
        let manager = CredentialManager::with_gate(
            store.clone(),
            OAuthClient::at(&server.uri()).unwrap(),
            gate.clone(),
        )
        .await;
        assert_eq!(
            manager.access().await.unwrap().access_token,
            "synthetic-new-access"
        );
        drop(manager);
        // A route/price reload must inherit both R1 and the persistence backoff.
        let manager = CredentialManager::with_gate(
            store.clone(),
            OAuthClient::at(&server.uri()).unwrap(),
            gate,
        )
        .await;
        assert!(manager.available());
        assert_eq!(
            manager.access().await.unwrap().refresh_token,
            "synthetic-new-refresh"
        );
        assert_eq!(
            store.tokens.snapshot().await.revision,
            if committed { 2 } else { 1 }
        );
        store.fail.store(false, std::sync::atomic::Ordering::SeqCst);
        if competing {
            let mut winner = store.tokens.snapshot().await.credentials;
            winner.access_token = "synthetic-login-access".into();
            winner.refresh_token = "synthetic-login-refresh".into();
            winner.expires_at = chrono::Utc::now().timestamp() + 3600;
            assert!(store.tokens.compare_exchange(1, &winner).await.unwrap());
        }
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        let expected = if competing {
            "synthetic-login-access"
        } else {
            "synthetic-new-access"
        };
        assert_eq!(manager.access().await.unwrap().access_token, expected);
        let saved = store.tokens.snapshot().await;
        assert_eq!(saved.revision, 2);
        assert_eq!(saved.credentials.access_token, expected);
        assert!(manager.available());
        assert_eq!(server.received_requests().await.unwrap().len(), 1);
    }
}

struct HangingWrite {
    tokens: Arc<Tokens>,
    entered: tokio::sync::Notify,
    hang: std::sync::atomic::AtomicBool,
}
#[async_trait::async_trait]
impl TokenStore for HangingWrite {
    async fn load(&self) -> Result<jiabu_ai::credentials::TokenRead, ProviderError> {
        self.tokens.load().await
    }
    async fn compare_exchange(
        &self,
        revision: i64,
        next: &jiabu_ai::siwc::oauth::OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        assert_eq!(next.refresh_token, "synthetic-new-refresh");
        if self.hang.swap(false, std::sync::atomic::Ordering::SeqCst) {
            self.entered.notify_one();
            std::future::pending::<()>().await;
        }
        self.tokens.compare_exchange(revision, next).await
    }
    async fn invalidate(&self, revision: i64) -> Result<bool, ProviderError> {
        self.tokens.invalidate(revision).await
    }
}
#[tokio::test]
async fn dropping_refresh_during_cas_retains_rotated_credentials() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/oauth/token"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "access_token":"synthetic-new-access", "refresh_token":"synthetic-new-refresh",
            "expires_in":3600, "token_type":"Bearer"
        })))
        .expect(1)
        .mount(&server)
        .await;
    let store = Arc::new(HangingWrite {
        tokens: Tokens::new(1),
        entered: tokio::sync::Notify::new(),
        hang: std::sync::atomic::AtomicBool::new(true),
    });
    let manager =
        CredentialManager::new(store.clone(), OAuthClient::at(&server.uri()).unwrap()).await;
    // select drops access once CAS is waiting, exactly like an outer timeout.
    tokio::select! {
        _ = store.entered.notified() => {},
        _ = manager.access() => panic!("CAS should still be waiting"),
    }
    assert_eq!(store.tokens.snapshot().await.revision, 1);
    assert_eq!(
        manager.access().await.unwrap().refresh_token,
        "synthetic-new-refresh"
    );
    assert_eq!(store.tokens.snapshot().await.revision, 2);
    assert_eq!(server.received_requests().await.unwrap().len(), 1);
}

#[tokio::test]
async fn authoritative_login_discards_pending_on_access_and_reload() {
    for reload in [false, true] {
        let server = MockServer::start().await;
        Mock::given(method("POST"))
            .and(path("/oauth/token"))
            .respond_with(ResponseTemplate::new(200).set_body_json(json!({
                "access_token":"synthetic-pending", "refresh_token":"synthetic-pending-refresh",
                "expires_in":3600, "token_type":"Bearer"
            })))
            .expect(1)
            .mount(&server)
            .await;
        let store = Arc::new(FlakyWrite {
            tokens: Tokens::new(1),
            fail: std::sync::atomic::AtomicBool::new(true),
            committed: false,
        });
        let gate = Arc::new(jiabu_ai::credentials::RefreshGate::default());
        let first = CredentialManager::with_gate(
            store.clone(),
            OAuthClient::at(&server.uri()).unwrap(),
            gate.clone(),
        )
        .await;
        assert_eq!(
            first.access().await.unwrap().access_token,
            "synthetic-pending"
        );
        let mut credentials = store.tokens.snapshot().await.credentials;
        credentials.access_token = "synthetic-login".into();
        credentials.refresh_token = "synthetic-login-refresh".into();
        credentials.expires_at = chrono::Utc::now().timestamp() + 3600;
        assert!(
            store
                .tokens
                .compare_exchange(1, &credentials)
                .await
                .unwrap()
        );
        let manager = if reload {
            CredentialManager::with_gate(
                store.clone(),
                OAuthClient::at(&server.uri()).unwrap(),
                gate,
            )
            .await
        } else {
            first
        };
        // No backoff wait: authoritative changes must take effect immediately.
        assert_eq!(
            manager.access().await.unwrap().access_token,
            "synthetic-login"
        );
        assert!(manager.available());
        assert_eq!(server.received_requests().await.unwrap().len(), 1);
    }
}

// Same contract as env: each load returns the external JSON, CAS cannot write it.
struct EnvironmentSnapshot(String);
#[async_trait::async_trait]
impl TokenStore for EnvironmentSnapshot {
    async fn load(&self) -> Result<jiabu_ai::credentials::TokenRead, ProviderError> {
        Ok(jiabu_ai::credentials::TokenRead::Present {
            revision: 0,
            credentials: serde_json::from_str(&self.0).unwrap(),
        })
    }
    async fn compare_exchange(
        &self,
        revision: i64,
        _next: &jiabu_ai::siwc::oauth::OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        assert_eq!(revision, 0);
        Err(ProviderError::Auth)
    }
    async fn invalidate(&self, _revision: i64) -> Result<bool, ProviderError> {
        Ok(true)
    }
}
#[tokio::test]
async fn env_pending_expiry_refreshes_with_latest_refresh_token_and_original_cas_base() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/oauth/token"))
        .and(body_string_contains("refresh_token=synthetic-refresh"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "access_token":"synthetic-A1", "refresh_token":"synthetic-R1",
            "expires_in":1, "token_type":"Bearer"
        })))
        .expect(1)
        .mount(&server)
        .await;
    Mock::given(method("POST"))
        .and(path("/oauth/token"))
        .and(body_string_contains("refresh_token=synthetic-R1"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "access_token":"synthetic-A2", "refresh_token":"synthetic-R2",
            "expires_in":3600, "token_type":"Bearer"
        })))
        .expect(1)
        .mount(&server)
        .await;
    let store = Arc::new(EnvironmentSnapshot(
        serde_json::to_string(&Tokens::new(1).snapshot().await.credentials).unwrap(),
    ));
    let gate = Arc::new(jiabu_ai::credentials::RefreshGate::default());
    let manager = CredentialManager::with_gate(
        store.clone(),
        OAuthClient::at(&server.uri()).unwrap(),
        gate.clone(),
    )
    .await;
    assert_eq!(manager.access().await.unwrap().access_token, "synthetic-A1");
    tokio::time::sleep(std::time::Duration::from_secs(6)).await;
    let manager =
        CredentialManager::with_gate(store.clone(), OAuthClient::at(&server.uri()).unwrap(), gate)
            .await;
    assert_eq!(manager.access().await.unwrap().access_token, "synthetic-A2");
    assert_eq!(
        manager.access().await.unwrap().refresh_token,
        "synthetic-R2"
    );
    assert!(manager.available());
    assert_eq!(
        serde_json::from_str::<jiabu_ai::siwc::oauth::OAuthCredentials>(&store.0)
            .unwrap()
            .refresh_token,
        "synthetic-refresh"
    );
    assert_eq!(server.received_requests().await.unwrap().len(), 2);
}

struct ReadOutcome {
    inner: FlakyWrite,
    fault: std::sync::atomic::AtomicU8,
}
#[async_trait::async_trait]
impl TokenStore for ReadOutcome {
    async fn load(&self) -> Result<jiabu_ai::credentials::TokenRead, ProviderError> {
        match self.fault.load(std::sync::atomic::Ordering::SeqCst) {
            1 => Ok(jiabu_ai::credentials::TokenRead::Unavailable),
            2 => Err(ProviderError::Auth),
            _ => self.inner.load().await,
        }
    }
    async fn compare_exchange(
        &self,
        revision: i64,
        next: &jiabu_ai::siwc::oauth::OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        self.inner.compare_exchange(revision, next).await
    }
    async fn invalidate(&self, revision: i64) -> Result<bool, ProviderError> {
        self.inner.invalidate(revision).await
    }
}
#[tokio::test]
async fn pending_survives_only_unavailable_reads_and_is_discarded_on_corruption() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/oauth/token"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "access_token":"synthetic-A1", "refresh_token":"synthetic-R1",
            "expires_in":3600, "token_type":"Bearer"
        })))
        .expect(1)
        .mount(&server)
        .await;
    let store = Arc::new(ReadOutcome {
        inner: FlakyWrite {
            tokens: Tokens::new(1),
            fail: std::sync::atomic::AtomicBool::new(true),
            committed: false,
        },
        fault: std::sync::atomic::AtomicU8::new(0),
    });
    let manager =
        CredentialManager::new(store.clone(), OAuthClient::at(&server.uri()).unwrap()).await;
    assert_eq!(manager.access().await.unwrap().access_token, "synthetic-A1");
    store.fault.store(1, std::sync::atomic::Ordering::SeqCst);
    assert_eq!(manager.access().await.unwrap().access_token, "synthetic-A1");
    store.fault.store(2, std::sync::atomic::Ordering::SeqCst);
    assert!(matches!(manager.access().await, Err(ProviderError::Auth)));
    assert!(!manager.available());
    // Even another outage cannot resurrect the discarded A1.
    store.fault.store(1, std::sync::atomic::Ordering::SeqCst);
    assert!(matches!(
        manager.access().await,
        Err(ProviderError::Transport)
    ));
    assert!(!manager.available());
    assert_eq!(server.received_requests().await.unwrap().len(), 1);
}
