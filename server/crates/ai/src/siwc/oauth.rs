//! PKCE with pasted loopback callback. Errors never include endpoint bodies/URLs.
use crate::ProviderError;
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use oauth2::{CsrfToken, PkceCodeChallenge, PkceCodeVerifier};
use reqwest::Url;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use zeroize::Zeroize;
pub const ISSUER: &str = "https://auth.openai.com";
pub const REDIRECT: &str = "http://127.0.0.1:1455/auth/callback";
pub const RESOURCE: &str = "https://api.openai.com/v1";
pub const SCOPES: &str = "openid offline_access resource.invoke chatgpt.tokens.use.direct";
#[derive(Clone, Serialize, Deserialize)]
pub struct OAuthCredentials {
    pub access_token: String,
    pub refresh_token: String,
    pub client_id: String,
    pub account_id: String,
    pub expires_at: i64,
    pub host_id: Uuid,
}
impl OAuthCredentials {
    pub fn refreshable(&self) -> bool {
        !self.access_token.is_empty() && !self.refresh_token.is_empty()
    }
}
impl Drop for OAuthCredentials {
    fn drop(&mut self) {
        self.access_token.zeroize();
        self.refresh_token.zeroize();
        self.account_id.zeroize();
    }
}
pub struct Login {
    pub authorize_url: Url,
    state: CsrfToken,
    verifier: PkceCodeVerifier,
    nonce: String,
    client_id: String,
    host_id: Uuid,
}
#[derive(Clone)]
pub struct OAuthClient {
    client: reqwest::Client,
    issuer: String,
}
impl OAuthClient {
    pub fn official() -> Result<Self, ProviderError> {
        Self::at(ISSUER)
    }
    /// HTTP is permitted only for loopback synthetic tests.
    pub fn at(issuer: &str) -> Result<Self, ProviderError> {
        let url = Url::parse(issuer).map_err(|_| ProviderError::Auth)?;
        if url.scheme() != "https"
            && !(url.scheme() == "http"
                && matches!(url.host_str(), Some("127.0.0.1" | "localhost")))
        {
            return Err(ProviderError::Auth);
        }
        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .map_err(|_| ProviderError::Transport)?;
        Ok(Self {
            client,
            issuer: issuer.trim_end_matches('/').into(),
        })
    }
    pub fn begin(&self, host_id: Uuid, client_id: Option<&str>) -> Result<Login, ProviderError> {
        let (challenge, verifier) = PkceCodeChallenge::new_random_sha256();
        let state = CsrfToken::new_random();
        let nonce = CsrfToken::new_random().secret().to_owned();
        let client_id = client_id.unwrap_or("dynamic_agent_client").to_owned();
        let mut url = Url::parse(&format!("{}/oauth/authorize", self.issuer))
            .map_err(|_| ProviderError::Auth)?;
        url.query_pairs_mut().extend_pairs([
            ("response_type", "code"),
            ("client_id", &client_id),
            ("redirect_uri", REDIRECT),
            ("scope", SCOPES),
            ("resource", RESOURCE),
            ("state", state.secret()),
            ("nonce", &nonce),
            ("code_challenge", challenge.as_str()),
            ("code_challenge_method", "S256"),
            ("ext_agent_host_id", &host_id.to_string()),
            ("agent_name_hint", "Jiabu"),
        ]);
        Ok(Login {
            authorize_url: url,
            state,
            verifier,
            nonce,
            client_id,
            host_id,
        })
    }
    pub async fn complete(
        &self,
        login: Login,
        callback: &str,
    ) -> Result<OAuthCredentials, ProviderError> {
        let callback = Url::parse(callback.trim()).map_err(|_| ProviderError::Auth)?;
        let expected = Url::parse(REDIRECT).map_err(|_| ProviderError::Auth)?;
        if callback.origin() != expected.origin()
            || callback.path() != expected.path()
            || callback.fragment().is_some()
            || !callback.username().is_empty()
            || callback.password().is_some()
        {
            return Err(ProviderError::Auth);
        }
        let values = callback.query_pairs().collect::<Vec<_>>();
        let one = |name: &str| -> Result<String, ProviderError> {
            let matches: Vec<_> = values.iter().filter(|(k, _)| k == name).collect();
            if matches.len() != 1 {
                return Err(ProviderError::Auth);
            }
            Ok(matches[0].1.to_string())
        };
        if one("state")? != *login.state.secret() || values.iter().any(|(k, _)| k == "error") {
            return Err(ProviderError::Auth);
        }
        let code = one("code")?;
        let token = self
            .token(&[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("client_id", &login.client_id),
                ("redirect_uri", REDIRECT),
                ("code_verifier", login.verifier.secret()),
                ("resource", RESOURCE),
            ])
            .await?;
        let id = token.id_token.as_deref().ok_or(ProviderError::Auth)?;
        let claims = self.claims(
            id,
            &token.client_id.clone().unwrap_or(login.client_id.clone()),
            Some(&login.nonce),
        )?;
        if token.scope.as_deref().is_some_and(|scope| {
            !SCOPES
                .split_whitespace()
                .all(|s| scope.split_whitespace().any(|v| v == s))
        }) {
            return Err(ProviderError::Auth);
        }
        let assigned_client =
            if login.client_id == "dynamic_agent_client" && token.client_id.is_none() {
                claims
                    .aud
                    .as_str()
                    .filter(|a| a.starts_with("oaiapp_"))
                    .ok_or(ProviderError::Auth)?
                    .to_owned()
            } else {
                token.client_id.clone().unwrap_or(login.client_id.clone())
            };
        Ok(OAuthCredentials {
            access_token: token.access_token.clone(),
            refresh_token: token.refresh_token.clone().ok_or(ProviderError::Auth)?,
            client_id: assigned_client,
            account_id: claims.account_id()?,
            expires_at: expiry(token.expires_in)?.min(claims.exp),
            host_id: login.host_id,
        })
    }
    /// Once the token endpoint has answered, the refresh token may already be rotated
    /// upstream, so nothing after that point may discard the response. A refreshed
    /// id_token that is missing, unparsable or lacks the account claim keeps the stored
    /// `account_id`; a different account claim is adopted so encrypted reasoning bound to
    /// the old account is no longer replayed.
    pub async fn refresh(&self, old: &OAuthCredentials) -> Result<OAuthCredentials, ProviderError> {
        let token = self
            .token(&[
                ("grant_type", "refresh_token"),
                ("refresh_token", &old.refresh_token),
                ("client_id", &old.client_id),
                ("resource", RESOURCE),
            ])
            .await?;
        let account_id = match token
            .id_token
            .as_deref()
            .map(|id| self.claims(id, &old.client_id, None))
        {
            Some(Ok(claims)) => match claims.account_claim() {
                Some(account) if account != old.account_id => {
                    eprintln!("SIWC refresh: account claim changed; reasoning replay reset");
                    account
                }
                _ => old.account_id.clone(),
            },
            Some(Err(_)) => {
                eprintln!("SIWC refresh: id_token not accepted; keeping stored account");
                old.account_id.clone()
            }
            None => old.account_id.clone(),
        };
        Ok(OAuthCredentials {
            access_token: token.access_token.clone(),
            refresh_token: token
                .refresh_token
                .clone()
                .unwrap_or_else(|| old.refresh_token.clone()),
            client_id: old.client_id.clone(),
            account_id,
            // An unusable lifetime forces another refresh instead of dropping the rotation.
            expires_at: expiry(token.expires_in).unwrap_or_else(|_| chrono::Utc::now().timestamp()),
            host_id: old.host_id,
        })
    }
    async fn token(&self, params: &[(&str, &str)]) -> Result<TokenResponse, ProviderError> {
        let response = self
            .client
            .post(format!("{}/oauth/token", self.issuer))
            .form(params)
            .send()
            .await
            .map_err(|e| {
                if e.is_timeout() {
                    ProviderError::Timeout
                } else {
                    ProviderError::Transport
                }
            })?;
        let status = response.status();
        if !status.is_success() {
            if status == reqwest::StatusCode::TOO_MANY_REQUESTS {
                return Err(ProviderError::RateLimited { retry_after: None });
            }
            if matches!(status.as_u16(), 400 | 401) {
                // Only an explicit OAuth rejection permanently revokes credentials.
                let body: serde_json::Value = response.json().await.unwrap_or_default();
                if matches!(
                    body.get("error").and_then(|v| v.as_str()),
                    Some("invalid_grant" | "invalid_client" | "unauthorized_client")
                ) {
                    return Err(ProviderError::Auth);
                }
            }
            return Err(ProviderError::Transport);
        }
        let token: TokenResponse = response
            .json()
            .await
            .map_err(|_| ProviderError::Transport)?;
        if token.access_token.is_empty() || !token.token_type.eq_ignore_ascii_case("bearer") {
            return Err(ProviderError::Transport);
        }
        Ok(token)
    }
    /// Per go1: claims are accepted ONLY from the direct TLS token response.
    /// No JWKS/signature verification and no externally supplied id_token API.
    fn claims(&self, id: &str, client: &str, nonce: Option<&str>) -> Result<Claims, ProviderError> {
        let parts: Vec<_> = id.split('.').collect();
        if parts.len() != 3 {
            return Err(ProviderError::Auth);
        }
        let payload = zeroize::Zeroizing::new(
            URL_SAFE_NO_PAD
                .decode(parts[1])
                .map_err(|_| ProviderError::Auth)?,
        );
        let claims: Claims = serde_json::from_slice(&payload).map_err(|_| ProviderError::Auth)?;
        let audience = (client == "dynamic_agent_client"
            && claims
                .aud
                .as_str()
                .is_some_and(|a| a.starts_with("oaiapp_")))
            || claims.aud.as_str() == Some(client)
            || claims
                .aud
                .as_array()
                .is_some_and(|a| a.iter().any(|v| v.as_str() == Some(client)));
        if claims.iss != self.issuer
            || !audience
            || claims.exp <= chrono::Utc::now().timestamp()
            || nonce.is_some_and(|n| claims.nonce.as_deref() != Some(n))
        {
            return Err(ProviderError::Auth);
        }
        Ok(claims)
    }
}
fn expiry(seconds: i64) -> Result<i64, ProviderError> {
    if seconds <= 0 {
        return Err(ProviderError::Auth);
    }
    chrono::Utc::now()
        .timestamp()
        .checked_add(seconds)
        .ok_or(ProviderError::Auth)
}
#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    refresh_token: Option<String>,
    id_token: Option<String>,
    client_id: Option<String>,
    expires_in: i64,
    token_type: String,
    scope: Option<String>,
}
impl Drop for TokenResponse {
    fn drop(&mut self) {
        self.access_token.zeroize();
        self.refresh_token.zeroize();
        self.id_token.zeroize();
    }
}
#[derive(Deserialize)]
struct Claims {
    iss: String,
    aud: serde_json::Value,
    exp: i64,
    nonce: Option<String>,
    sub: Option<String>,
    #[serde(rename = "https://api.openai.com/auth")]
    auth: Option<serde_json::Value>,
}
impl Claims {
    /// The ChatGPT account claim, when the issuer includes it.
    fn account_claim(&self) -> Option<String> {
        self.auth
            .as_ref()
            .and_then(|a| a.get("chatgpt_account_id"))
            .and_then(|v| v.as_str())
            .filter(|v| !v.is_empty())
            .map(str::to_owned)
    }
    /// Internal replay key only; never sent upstream. Dynamic agent clients receive
    /// id_tokens without `chatgpt_account_id`, so the OIDC subject is the fallback.
    fn account_id(&self) -> Result<String, ProviderError> {
        self.account_claim()
            .or_else(|| {
                self.sub
                    .as_deref()
                    .filter(|v| !v.is_empty())
                    .map(|sub| format!("sub:{sub}"))
            })
            .ok_or(ProviderError::Auth)
    }
}
