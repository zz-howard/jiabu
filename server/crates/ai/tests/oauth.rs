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
    Mock::given(method("POST")).and(path("/oauth/token")).and(body_string_contains("code_verifier=")).and(body_string_contains("grant_type=authorization_code")).respond_with(ResponseTemplate::new(200).set_body_json(json!({"access_token":"synthetic-access","refresh_token":"synthetic-refresh","id_token":token,"expires_in":3600,"token_type":"Bearer","scope":SCOPES}))).expect(1).mount(&server).await;
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
    Mock::given(method("POST")).and(path("/oauth/token")).respond_with(ResponseTemplate::new(200).set_body_json(json!({"access_token":"synthetic-new-access","refresh_token":"synthetic-rotated-refresh","expires_in":3600,"token_type":"Bearer"}))).expect(1).mount(&server).await;
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
    assert_eq!(tokens.load().await.unwrap().revision, 2);
    server.reset().await;
    Mock::given(method("POST"))
        .respond_with(ResponseTemplate::new(401))
        .mount(&server)
        .await;
    {
        tokens.0.lock().unwrap().credentials.expires_at = 1;
    }
    assert!(manager.access().await.is_err());
    assert!(!manager.available());
    assert!(!router.availability(jiabu_ai::TaskKind::Chat).available);
    assert!(!tokens.load().await.unwrap().usable);
}
#[tokio::test]
async fn concurrent_access_serializes_one_refresh_and_stale_rejection_preserves_rotation() {
    let server = MockServer::start().await;
    Mock::given(method("POST")).respond_with(ResponseTemplate::new(200).set_body_json(json!({"access_token":"synthetic-new-access","refresh_token":"synthetic-new-refresh","expires_in":3600,"token_type":"Bearer"}))).expect(1).mount(&server).await;
    let tokens = Tokens::new(1);
    let manager =
        CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await;
    let (a, b) = tokio::join!(manager.access(), manager.access());
    assert!(a.is_ok() && b.is_ok());
    assert_eq!(tokens.load().await.unwrap().revision, 2);
    manager.reject("synthetic-old-access").await;
    assert!(manager.available());
    assert!(tokens.load().await.unwrap().usable);
}

#[tokio::test]
async fn reload_generations_share_refresh_gate_and_do_not_reuse_rotated_token() {
    let server = MockServer::start().await;
    Mock::given(method("POST")).respond_with(ResponseTemplate::new(200).set_delay(std::time::Duration::from_millis(20)).set_body_json(json!({"access_token":"synthetic-new-access","refresh_token":"synthetic-new-refresh","expires_in":3600,"token_type":"Bearer"}))).expect(1).mount(&server).await;
    let tokens = Tokens::new(1);
    let gate = Arc::new(tokio::sync::Mutex::new(()));
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
    assert_eq!(tokens.load().await.unwrap().revision, 2);
}
