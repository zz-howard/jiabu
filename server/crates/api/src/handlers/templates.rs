use crate::{ApiError, AppState, Principal};
use axum::{
    body::Body,
    extract::State,
    http::{HeaderMap, StatusCode, header},
    response::Response,
};
fn matches(headers: &HeaderMap, etag: &str) -> bool {
    headers
        .get_all(header::IF_NONE_MATCH)
        .iter()
        .filter_map(|h| h.to_str().ok())
        .flat_map(|h| h.split(','))
        .any(|part| {
            let part = part.trim();
            part == "*" || part.strip_prefix("W/").unwrap_or(part) == etag
        })
}
#[utoipa::path(get,path="/v1/templates",security(("bearer"=[])),params(("If-None-Match"=Option<String>,Header,description="Cached template collection ETag")),responses((status=200,body=serde_json::Value,description="All loaded templates; ordered by ID",headers(("ETag"=String,description="SHA-256 of the response bytes")),example=json!({"templates":[]})),(status=304,description="Collection unchanged",headers(("ETag"=String,description="Current collection hash"))),(status=401,body=crate::Problem),(status=403,body=crate::Problem),(status=429,body=crate::Problem)))]
pub(crate) async fn get(
    State(state): State<AppState>,
    _principal: Principal,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let catalog = state.templates.snapshot().await;
    let unchanged = matches(&headers, &catalog.etag);
    Response::builder()
        .status(if unchanged {
            StatusCode::NOT_MODIFIED
        } else {
            StatusCode::OK
        })
        .header(header::ETAG, &catalog.etag)
        .header(header::CONTENT_TYPE, "application/json")
        .body(if unchanged {
            Body::empty()
        } else {
            Body::from(catalog.bytes.clone())
        })
        .map_err(|_| ApiError::internal())
}
