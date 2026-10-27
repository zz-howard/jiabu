//! Jiabu public HTTP surface and its OpenAPI document.

use axum::{Json, Router};
use serde::Serialize;
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

#[derive(Serialize, ToSchema)]
struct MetaResponse {
    server_version: String,
    api_versions: Vec<i32>,
}

#[utoipa::path(
    get,
    path = "/v1/meta",
    operation_id = "get_public_meta",
    responses((status = 200, description = "Server and API versions", body = MetaResponse,
        example = json!({"server_version": "0.1.0", "api_versions": [1]})))
)]
async fn meta() -> Json<MetaResponse> {
    Json(MetaResponse {
        server_version: env!("CARGO_PKG_VERSION").to_owned(),
        api_versions: vec![1],
    })
}

#[utoipa::path(
    get,
    path = "/healthz",
    operation_id = "healthz",
    responses((status = 200, description = "Service is healthy"))
)]
async fn healthz() -> axum::http::StatusCode {
    axum::http::StatusCode::OK
}

fn documented_router() -> OpenApiRouter {
    let document = utoipa::openapi::OpenApiBuilder::new()
        .info(utoipa::openapi::Info::new(
            "Jiabu public API",
            env!("CARGO_PKG_VERSION"),
        ))
        .build();
    OpenApiRouter::with_openapi(document)
        .routes(routes!(meta))
        .routes(routes!(healthz))
}

/// Build the public router without opening a database connection.
pub fn router() -> Router {
    documented_router().split_for_parts().0
}

/// Generate the document from the same handlers used by the router.
pub fn openapi() -> utoipa::openapi::OpenApi {
    documented_router().split_for_parts().1
}
