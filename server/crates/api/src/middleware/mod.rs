mod login_limit;
use crate::{ApiError, AppState};
use axum::{
    Router,
    extract::{DefaultBodyLimit, MatchedPath, Request, State},
    http::{HeaderValue, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
};
pub(crate) use login_limit::{LoginLimiter, source_ip};
use tower_http::{
    catch_panic::CatchPanicLayer, compression::CompressionLayer,
    sensitive_headers::SetSensitiveHeadersLayer, timeout::TimeoutLayer,
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
        .layer(TimeoutLayer::with_status_code(
            StatusCode::SERVICE_UNAVAILABLE,
            std::time::Duration::from_secs(30),
        ))
        .layer(CompressionLayer::new())
        .layer(SetSensitiveHeadersLayer::new([
            axum::http::header::AUTHORIZATION,
        ]))
        .layer(middleware::from_fn_with_state(state.clone(), context))
        .with_state(state)
}
async fn not_found() -> ApiError {
    ApiError::not_found()
}
async fn method_not_allowed() -> ApiError {
    ApiError::new(StatusCode::METHOD_NOT_ALLOWED, "bad_request")
}
async fn context(State(state): State<AppState>, request: Request, next: Next) -> Response {
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
        auth_kind="", status=0_u16, elapsed_ms=0_u64);
    REQUEST_ID
        .scope(
            id,
            async move {
                let start = std::time::Instant::now();
                let handshake_result = handshake(
                    &state,
                    request.headers().clone(),
                    request.uri().path().to_owned(),
                )
                .await;
                let mut response = match handshake_result {
                    Ok(()) => next.run(request).await,
                    Err(error) => error.into_response(),
                };
                // Turn framework-level body limit rejections into the same error contract.
                if response.status() == StatusCode::PAYLOAD_TOO_LARGE {
                    response = ApiError::new(StatusCode::PAYLOAD_TOO_LARGE, "payload_too_large")
                        .into_response();
                }
                if response.status() == StatusCode::SERVICE_UNAVAILABLE {
                    response = ApiError::new(StatusCode::SERVICE_UNAVAILABLE, "unavailable")
                        .into_response();
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
