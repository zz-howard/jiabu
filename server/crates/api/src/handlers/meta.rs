use crate::{ApiError, AppState};
use axum::{Json, extract::State, http::StatusCode};
use serde::Serialize;
use utoipa::ToSchema;
#[derive(Serialize, ToSchema)]
pub(crate) struct MinimumBuild {
    stable: i32,
    beta: i32,
}
#[derive(Serialize, ToSchema)]
pub(crate) struct MetaResponse {
    server_version: String,
    api_versions: Vec<i32>,
    min_client_build: MinimumBuild,
    features: Vec<String>,
}
#[utoipa::path(get,path="/v1/meta",responses((status=200,body=MetaResponse,description="Version handshake",example=json!({"server_version":"0.1.0","api_versions":[1],"min_client_build":{"stable":0,"beta":0},"features":[]}))))]
pub(crate) async fn meta(State(state): State<AppState>) -> Result<Json<MetaResponse>, ApiError> {
    let (stable, beta) = state.db.minimum_builds().await?;
    Ok(Json(MetaResponse {
        server_version: env!("CARGO_PKG_VERSION").into(),
        api_versions: vec![1],
        min_client_build: MinimumBuild { stable, beta },
        features: vec![],
    }))
}
#[utoipa::path(get,path="/healthz",responses((status=200,description="Healthy")))]
pub(crate) async fn healthz() -> StatusCode {
    StatusCode::OK
}
#[utoipa::path(get,path="/v1/healthz",responses((status=200,description="Healthy")))]
pub(crate) async fn versioned_healthz() -> StatusCode {
    StatusCode::OK
}
