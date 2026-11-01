pub mod oauth;
pub mod request;
pub mod stream;
use crate::{credentials::CredentialManager, provider::*, types::*};
use async_trait::async_trait;
use futures_util::StreamExt;
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransportDiagnosticClass {
    Dns,
    Connect,
    Tls,
    Proxy,
    HttpStatus,
    StreamResetOrEof,
    OtherTransport,
}

impl std::fmt::Display for TransportDiagnosticClass {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(match self {
            Self::Dns => "dns",
            Self::Connect => "connect",
            Self::Tls => "tls",
            Self::Proxy => "proxy",
            Self::HttpStatus => "http-status",
            Self::StreamResetOrEof => "stream-reset-or-eof",
            Self::OtherTransport => "other-transport",
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransportDiagnosticStage {
    CredentialOrPreflight,
    RequestSend,
    ResponseStatus,
    ResponseStream,
}

impl std::fmt::Display for TransportDiagnosticStage {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(match self {
            Self::CredentialOrPreflight => "credential-or-preflight",
            Self::RequestSend => "request-send",
            Self::ResponseStatus => "response-status",
            Self::ResponseStream => "response-stream",
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransportStatusClass {
    None,
    FourXx,
    FiveXx,
    Other,
}

impl std::fmt::Display for TransportStatusClass {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(match self {
            Self::None => "none",
            Self::FourXx => "4xx",
            Self::FiveXx => "5xx",
            Self::Other => "other",
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TransportDiagnostic {
    pub class: TransportDiagnosticClass,
    pub stage: TransportDiagnosticStage,
    pub status: TransportStatusClass,
    pub received_headers: bool,
}

static TRANSPORT_DIAGNOSTIC: Mutex<Option<TransportDiagnostic>> = Mutex::new(None);

pub fn clear_transport_diagnostic() {
    if let Ok(mut slot) = TRANSPORT_DIAGNOSTIC.lock() {
        *slot = None;
    }
}

pub fn take_transport_diagnostic() -> Option<TransportDiagnostic> {
    TRANSPORT_DIAGNOSTIC.lock().ok()?.take()
}

fn record_transport_diagnostic(diagnostic: TransportDiagnostic) {
    if let Ok(mut slot) = TRANSPORT_DIAGNOSTIC.lock() {
        *slot = Some(diagnostic);
    }
}

fn status_class(status: reqwest::StatusCode) -> TransportStatusClass {
    if status.is_client_error() {
        TransportStatusClass::FourXx
    } else if status.is_server_error() {
        TransportStatusClass::FiveXx
    } else {
        TransportStatusClass::Other
    }
}
pub struct SiwcProvider {
    id: String,
    capabilities: Capabilities,
    credentials: Arc<CredentialManager>,
    client: reqwest::Client,
    endpoint: String,
}
impl SiwcProvider {
    pub async fn available_models(
        credentials: &oauth::OAuthCredentials,
    ) -> Result<Vec<String>, ProviderError> {
        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(Duration::from_secs(30))
            .build()
            .map_err(|_| ProviderError::Transport)?;
        let response = client
            .get("https://api.openai.com/v1/models")
            .bearer_auth(&credentials.access_token)
            .send()
            .await
            .map_err(|_| ProviderError::Transport)?;
        if !response.status().is_success() {
            return Err(ProviderError::Auth);
        }
        let value: serde_json::Value = response
            .json()
            .await
            .map_err(|_| ProviderError::InvalidOutput)?;
        let data = value["data"]
            .as_array()
            .ok_or(ProviderError::InvalidOutput)?;
        Ok(data
            .iter()
            .filter_map(|m| m["id"].as_str().map(str::to_owned))
            .collect())
    }

    pub fn new(
        id: String,
        capabilities: Capabilities,
        credentials: Arc<CredentialManager>,
    ) -> Result<Self, ProviderError> {
        Self::at(
            id,
            capabilities,
            credentials,
            "https://api.openai.com/v1/responses",
        )
    }
    /// Endpoint override exists only for loopback contract fixtures, not provider configuration.
    pub fn at(
        id: String,
        capabilities: Capabilities,
        credentials: Arc<CredentialManager>,
        endpoint: &str,
    ) -> Result<Self, ProviderError> {
        let url =
            reqwest::Url::parse(endpoint).map_err(|_| ProviderError::Unsupported("endpoint"))?;
        if endpoint != "https://api.openai.com/v1/responses"
            && !(url.scheme() == "http"
                && matches!(url.host_str(), Some("127.0.0.1" | "localhost")))
        {
            return Err(ProviderError::Unsupported("SIWC endpoint"));
        }
        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(Duration::from_secs(300))
            .build()
            .map_err(|_| ProviderError::Transport)?;
        Ok(Self {
            id,
            capabilities,
            credentials,
            client,
            endpoint: endpoint.into(),
        })
    }
}
#[async_trait]
impl ModelProvider for SiwcProvider {
    fn id(&self) -> &str {
        &self.id
    }
    fn capabilities(&self) -> &Capabilities {
        &self.capabilities
    }
    fn credentials_available(&self) -> bool {
        self.credentials.available()
    }
    async fn run_turn_observed(
        &self,
        task: TaskKind,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
        observer: &dyn CallObserver,
        budget: Duration,
    ) -> Result<(), ProviderError> {
        let deadline = tokio::time::Instant::now() + budget;
        let mut creds = tokio::time::timeout_at(deadline, self.credentials.access())
            .await
            .unwrap_or(Err(ProviderError::Timeout))?;
        let mut output = crate::router::OutputSink {
            inner: sink,
            visible: false,
        };
        let result = measured_attempt(
            &HttpAttempt {
                provider: self,
                credentials: &creds,
            },
            task,
            req,
            &mut output,
            observer,
            deadline.saturating_duration_since(tokio::time::Instant::now()),
        )
        .await;
        if result != Err(ProviderError::Auth) || output.visible {
            return result;
        }
        creds = tokio::time::timeout_at(
            deadline,
            self.credentials
                .refresh_after_rejection(&creds.access_token),
        )
        .await
        .unwrap_or(Err(ProviderError::Timeout))?;
        measured_attempt(
            &HttpAttempt {
                provider: self,
                credentials: &creds,
            },
            task,
            req,
            &mut output,
            observer,
            deadline.saturating_duration_since(tokio::time::Instant::now()),
        )
        .await
    }
    async fn run_turn(
        &self,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
    ) -> Result<(), ProviderError> {
        let mut creds = self.credentials.access().await?;
        let mut output = crate::router::OutputSink {
            inner: sink,
            visible: false,
        };
        let result = self.request_once(req, &mut output, &creds).await;
        if result != Err(ProviderError::Auth) || output.visible {
            return result;
        }
        creds = self
            .credentials
            .refresh_after_rejection(&creds.access_token)
            .await?;
        // Only this one retry; a second access-token error never revokes the session.
        self.request_once(req, &mut output, &creds).await
    }
}
impl SiwcProvider {
    async fn request_once(
        &self,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
        creds: &oauth::OAuthCredentials,
    ) -> Result<(), ProviderError> {
        clear_transport_diagnostic();
        let body = request::body(req, &self.id, &creds.account_id)?;
        let response = self
            .client
            .post(&self.endpoint)
            .bearer_auth(&creds.access_token)
            .header("session_id", &req.session_key)
            .header("accept", "text/event-stream")
            .json(&body)
            .send()
            .await
            .map_err(|e| {
                if e.is_timeout() {
                    ProviderError::Timeout
                } else {
                    // reqwest deliberately collapses DNS, TCP, TLS and proxy setup
                    // behind one connect error. Do not infer a narrower cause from text.
                    record_transport_diagnostic(TransportDiagnostic {
                        class: TransportDiagnosticClass::OtherTransport,
                        stage: TransportDiagnosticStage::RequestSend,
                        status: TransportStatusClass::None,
                        received_headers: false,
                    });
                    ProviderError::Transport
                }
            })?;
        let status = response.status();
        if !status.is_success() {
            record_transport_diagnostic(TransportDiagnostic {
                class: TransportDiagnosticClass::HttpStatus,
                stage: TransportDiagnosticStage::ResponseStatus,
                status: status_class(status),
                received_headers: true,
            });
            if status.is_server_error() {
                return Err(ProviderError::Transport);
            }
            let retry_after = response
                .headers()
                .get("retry-after")
                .and_then(|h| h.to_str().ok())
                .and_then(|h| h.parse::<u64>().ok())
                .map(Duration::from_secs);
            let body: Option<serde_json::Value> = response.json().await.ok();
            let mapped = body
                .as_ref()
                .map(stream::error)
                .unwrap_or(ProviderError::InvalidOutput);
            if mapped == ProviderError::QuotaExhausted {
                return Err(mapped);
            }
            if status.as_u16() == 401 {
                return Err(ProviderError::Auth);
            }
            if status.as_u16() == 403 {
                return Err(match mapped {
                    ProviderError::InvalidOutput
                    | ProviderError::UpstreamFailed { .. }
                    | ProviderError::Auth => ProviderError::Unsupported("permission denied"),
                    error => error,
                });
            }
            if status.as_u16() == 429 {
                return Err(ProviderError::RateLimited { retry_after });
            }
            return Err(mapped);
        }
        let mut chunks = Box::pin(response.bytes_stream());
        let mut decoder = stream::Decoder::default();
        let mut turn = stream::TurnState::default();
        while let Some(chunk) = tokio::time::timeout(Duration::from_secs(60), chunks.next())
            .await
            .map_err(|_| ProviderError::Timeout)?
        {
            let chunk = chunk.map_err(|e| {
                if e.is_timeout() {
                    ProviderError::Timeout
                } else {
                    record_transport_diagnostic(TransportDiagnostic {
                        class: TransportDiagnosticClass::StreamResetOrEof,
                        stage: TransportDiagnosticStage::ResponseStream,
                        status: TransportStatusClass::None,
                        received_headers: true,
                    });
                    ProviderError::Transport
                }
            })?;
            for event in decoder.push(&chunk)? {
                if let Err(error) = turn.accept(event, sink).await {
                    if matches!(
                        &error,
                        ProviderError::Incomplete { .. } | ProviderError::UpstreamFailed { .. }
                    ) {
                        record_transport_diagnostic(TransportDiagnostic {
                            class: TransportDiagnosticClass::OtherTransport,
                            stage: TransportDiagnosticStage::ResponseStream,
                            status: TransportStatusClass::None,
                            received_headers: true,
                        });
                    }
                    return Err(error);
                }
                if turn.completed() {
                    let result = turn
                        .finish(&self.id, &req.snapshot.model, &creds.account_id, sink)
                        .await;
                    if matches!(
                        &result,
                        Err(
                            ProviderError::Incomplete { .. }
                                | ProviderError::UpstreamFailed { .. }
                        )
                    ) {
                        record_transport_diagnostic(TransportDiagnostic {
                            class: TransportDiagnosticClass::OtherTransport,
                            stage: TransportDiagnosticStage::ResponseStream,
                            status: TransportStatusClass::None,
                            received_headers: true,
                        });
                    }
                    return result;
                }
            }
        }
        Err(ProviderError::InvalidOutput)
    }
}

// A borrowed, single HTTP request; authentication recovery stays outside its meter.
struct HttpAttempt<'a> {
    provider: &'a SiwcProvider,
    credentials: &'a oauth::OAuthCredentials,
}
#[async_trait]
impl ModelProvider for HttpAttempt<'_> {
    fn id(&self) -> &str {
        self.provider.id()
    }
    fn capabilities(&self) -> &Capabilities {
        self.provider.capabilities()
    }
    async fn run_turn(
        &self,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
    ) -> Result<(), ProviderError> {
        self.provider
            .request_once(req, sink, self.credentials)
            .await
    }
}

#[cfg(test)]
mod diagnostic_tests {
    use super::*;

    #[test]
    fn transport_diagnostics_use_only_bounded_closed_fields() {
        assert_eq!(
            status_class(reqwest::StatusCode::TOO_MANY_REQUESTS),
            TransportStatusClass::FourXx
        );
        assert_eq!(
            status_class(reqwest::StatusCode::BAD_GATEWAY),
            TransportStatusClass::FiveXx
        );
        let diagnostic = TransportDiagnostic {
            class: TransportDiagnosticClass::HttpStatus,
            stage: TransportDiagnosticStage::ResponseStatus,
            status: TransportStatusClass::FiveXx,
            received_headers: true,
        };
        record_transport_diagnostic(diagnostic);
        assert_eq!(take_transport_diagnostic(), Some(diagnostic));
        assert_eq!(take_transport_diagnostic(), None);
    }
}
