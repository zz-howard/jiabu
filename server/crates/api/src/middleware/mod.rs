pub(crate) mod api_key_audit;
mod login_limit;
use crate::{ApiError, AppState};
use axum::{
    Router,
    extract::{DefaultBodyLimit, MatchedPath, Request, State},
    http::{HeaderValue, Method, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
};
pub(crate) use login_limit::{LoginLimiter, WindowLimiter, ip_key, source_ip};
use tower_http::{
    catch_panic::CatchPanicLayer, compression::CompressionLayer,
    sensitive_headers::SetSensitiveHeadersLayer,
};
use tracing::Instrument;
use uuid::Uuid;
tokio::task_local! { static REQUEST_ID: Uuid; }
pub(crate) fn request_id() -> Uuid {
    REQUEST_ID
        .try_with(|id| *id)
        .unwrap_or_else(|_| Uuid::now_v7())
}
pub(crate) fn apply(router: Router<AppState>, state: AppState) -> Router {
    router
        .fallback(not_found)
        .method_not_allowed_fallback(method_not_allowed)
        .layer(DefaultBodyLimit::max(2 * 1024 * 1024))
        .layer(CatchPanicLayer::custom(|_| {
            ApiError::internal().into_response()
        }))
        .layer(CompressionLayer::new())
        .layer(SetSensitiveHeadersLayer::new([
            axum::http::header::AUTHORIZATION,
        ]))
        .layer(middleware::from_fn_with_state(state.clone(), context))
        .with_state(state)
}
fn blob_transfer(route: Option<&str>, method: &Method) -> bool {
    route == Some("/v1/spaces/{space_id}/blobs/{sha256}")
        && matches!(*method, Method::PUT | Method::GET)
}
fn request_timeout(blob: bool, blob_seconds: u64) -> std::time::Duration {
    std::time::Duration::from_secs(if blob { blob_seconds } else { 30 })
}
async fn deadline_response(
    future: impl std::future::Future<Output = Response>,
    timeout: std::time::Duration,
    stream_body: bool,
) -> Response {
    use futures_util::StreamExt;
    let deadline = tokio::time::Instant::now() + timeout;
    let response = match tokio::time::timeout_at(deadline, future).await {
        Ok(response) => response,
        Err(_) => {
            return ApiError::new(StatusCode::SERVICE_UNAVAILABLE, "unavailable").into_response();
        }
    };
    if !stream_body {
        return response;
    }
    let (parts, body) = response.into_parts();
    // The same absolute deadline covers streamed downloads after their headers
    // have been sent. A stalled stream ends with a body error, never silently EOF.
    let stream =
        futures_util::stream::unfold(Some(body.into_data_stream()), move |state| async move {
            let mut stream = state?;
            match tokio::time::timeout_at(deadline, stream.next()).await {
                Ok(Some(item)) => Some((item.map_err(std::io::Error::other), Some(stream))),
                Ok(None) => None,
                Err(_) => Some((
                    Err(std::io::Error::new(
                        std::io::ErrorKind::TimedOut,
                        "blob transfer timed out",
                    )),
                    None,
                )),
            }
        });
    Response::from_parts(parts, axum::body::Body::from_stream(stream))
}

async fn not_found() -> ApiError {
    ApiError::not_found()
}
async fn method_not_allowed() -> ApiError {
    ApiError::new(StatusCode::METHOD_NOT_ALLOWED, "bad_request")
}
async fn context(State(state): State<AppState>, mut request: Request, next: Next) -> Response {
    let audit = api_key_audit::RequestAudit::default();
    request.extensions_mut().insert(audit.clone());
    let id = request
        .headers()
        .get("x-request-id")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| Uuid::parse_str(s).ok())
        .filter(|id| id.get_version_num() == 7 && id.get_variant() == uuid::Variant::RFC4122)
        .unwrap_or_else(Uuid::now_v7);
    let route = request
        .extensions()
        .get::<MatchedPath>()
        .map_or("unmatched", MatchedPath::as_str)
        .to_owned();
    let span = tracing::info_span!("http", request_id=%id, user_id="", route=%route,
        auth_kind="", api_key_id="", tool="", status=0_u16, elapsed_ms=0_u64);
    REQUEST_ID
        .scope(
            id,
            async move {
                let start = std::time::Instant::now();
                let (mut parts, body) = request.into_parts();
                let handshake_result = match crate::principal::prepare_api_key(&mut parts, &state)
                    .await
                {
                    Ok(()) => {
                        handshake(&state, parts.headers.clone(), parts.uri.path().to_owned()).await
                    }
                    Err(error) => Err(error),
                };
                let mut response = match handshake_result {
                    Ok(()) => {
                        let blob = blob_transfer(Some(&route), &parts.method);
                        let timeout =
                            request_timeout(blob, state.image_limits.transfer_timeout_secs);
                        deadline_response(next.run(Request::from_parts(parts, body)), timeout, blob)
                            .await
                    }
                    Err(error) => error.into_response(),
                };
                // Turn framework-level body limit rejections into the same error contract.
                if response.status() == StatusCode::PAYLOAD_TOO_LARGE {
                    response = ApiError::new(StatusCode::PAYLOAD_TOO_LARGE, "payload_too_large")
                        .into_response();
                }
                if response.status() == StatusCode::SERVICE_UNAVAILABLE
                    && response
                        .extensions()
                        .get::<api_key_audit::ErrorCode>()
                        .is_none()
                {
                    response = ApiError::new(StatusCode::SERVICE_UNAVAILABLE, "unavailable")
                        .into_response();
                }
                let outcome = if response.status() == StatusCode::TOO_MANY_REQUESTS {
                    "rate_limited"
                } else {
                    response
                        .extensions()
                        .get::<api_key_audit::ErrorCode>()
                        .map_or_else(
                            || {
                                if response.status().is_success() {
                                    "ok"
                                } else {
                                    "invalid"
                                }
                            },
                            |code| code.0,
                        )
                };
                if let Err(error) = audit.finish(&state, outcome).await {
                    response = error.into_response();
                }
                let elapsed = start.elapsed().as_millis() as u64;
                tracing::Span::current().record("status", response.status().as_u16());
                tracing::Span::current().record("elapsed_ms", elapsed);
                if let Some(batch) = response
                    .extensions_mut()
                    .remove::<crate::handlers::client_logs::AcceptedLogs>()
                {
                    batch.emit();
                }
                if response.status().is_server_error() {
                    tracing::error!(code = "internal", "Request failed");
                }
                tracing::info!("Request completed");
                if let Ok(value) = HeaderValue::from_str(&id.to_string()) {
                    response.headers_mut().insert("x-request-id", value);
                }
                response
            }
            .instrument(span),
        )
        .await
}
async fn handshake(
    state: &AppState,
    headers: axum::http::HeaderMap,
    path: String,
) -> Result<(), ApiError> {
    // A malformed credential must not cause even a version-handshake DB query.
    if !matches!(
        path.as_str(),
        "/v1/auth/login" | "/v1/meta" | "/healthz" | "/v1/healthz"
    ) && let Some(header) = headers.get("authorization")
        && !header
            .to_str()
            .ok()
            .and_then(|value| value.strip_prefix("Bearer "))
            .is_some_and(crate::principal::valid_token_shape)
    {
        return Err(ApiError::unauthorized());
    }
    let Some(header) = headers.get("x-jiabu-client") else {
        return Ok(());
    };
    let raw = header.to_str().map_err(|_| ApiError::bad_request())?;
    let (app, channel) = raw
        .split_once("; channel=")
        .ok_or_else(ApiError::bad_request)?;
    let version = app
        .strip_prefix("android/")
        .ok_or_else(ApiError::bad_request)?;
    let (version, build) = version.split_once('+').ok_or_else(ApiError::bad_request)?;
    let segments: Vec<_> = version.split('.').collect();
    if segments.len() != 3
        || segments
            .iter()
            .any(|s| s.is_empty() || !s.bytes().all(|b| b.is_ascii_digit()))
    {
        return Err(ApiError::bad_request());
    }
    let build: i32 = build.parse().map_err(|_| ApiError::bad_request())?;
    if build < 0 || !matches!(channel, "stable" | "beta") {
        return Err(ApiError::bad_request());
    }
    let path = path.as_str();
    if matches!(
        path,
        "/healthz" | "/v1/healthz" | "/v1/meta" | "/v1/client-logs"
    ) || path.starts_with("/v1/auth/")
        || path.starts_with("/v1/app/")
    {
        return Ok(());
    }
    let (stable, beta) = state.db.minimum_builds().await?;
    let minimum = if channel == "stable" { stable } else { beta };
    if build < minimum {
        Err(ApiError::new(
            StatusCode::UPGRADE_REQUIRED,
            "client_too_old",
        ))
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod timeout_tests {
    use super::*;
    use axum::body::{Body, to_bytes};
    use std::time::Duration;

    #[tokio::test(start_paused = true)]
    async fn blob_deadline_allows_slow_uploads_and_keeps_other_routes_at_thirty_seconds() {
        let path = Some("/v1/spaces/{space_id}/blobs/{sha256}");
        assert!(blob_transfer(path, &Method::PUT));
        assert!(blob_transfer(path, &Method::GET));
        assert!(!blob_transfer(path, &Method::POST));
        assert!(!blob_transfer(Some("/v1/sync/pull"), &Method::POST));
        for blob in [true, false] {
            let response = deadline_response(
                async {
                    tokio::time::sleep(Duration::from_secs(45)).await;
                    StatusCode::NO_CONTENT.into_response()
                },
                request_timeout(blob, 600),
                blob,
            )
            .await;
            assert_eq!(
                response.status(),
                if blob {
                    StatusCode::NO_CONTENT
                } else {
                    StatusCode::SERVICE_UNAVAILABLE
                }
            );
        }
        let response = deadline_response(
            async {
                tokio::time::sleep(Duration::from_secs(61)).await;
                StatusCode::NO_CONTENT.into_response()
            },
            request_timeout(true, 60),
            true,
        )
        .await;
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[tokio::test(start_paused = true)]
    async fn download_deadline_covers_the_stream_after_headers() {
        let delayed = futures_util::stream::once(async {
            tokio::time::sleep(Duration::from_secs(45)).await;
            Ok::<_, std::io::Error>("jpeg")
        });
        let response = deadline_response(
            async { Body::from_stream(delayed).into_response() },
            Duration::from_secs(600),
            true,
        )
        .await;
        assert_eq!(
            to_bytes(response.into_body(), 100).await.unwrap().as_ref(),
            b"jpeg"
        );
        let stalled = futures_util::stream::once(async {
            tokio::time::sleep(Duration::from_secs(601)).await;
            Ok::<_, std::io::Error>("late")
        });
        let response = deadline_response(
            async { Body::from_stream(stalled).into_response() },
            Duration::from_secs(600),
            true,
        )
        .await;
        assert!(to_bytes(response.into_body(), 100).await.is_err());
    }
}
