//! Jiabu admin HTTP surface and its OpenAPI document.

use axum::{Json, Router};
use serde::Serialize;
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

#[derive(Serialize, ToSchema)]
struct AdminMetaResponse {
    server_version: String,
    api_versions: Vec<i32>,
}

#[utoipa::path(
    get,
    path = "/admin/v1/meta",
    operation_id = "get_admin_meta",
    responses((status = 200, description = "Server and API versions", body = AdminMetaResponse,
        example = json!({"server_version": "0.1.0", "api_versions": [1]})))
)]
async fn meta() -> Json<AdminMetaResponse> {
    Json(AdminMetaResponse {
        server_version: env!("CARGO_PKG_VERSION").to_owned(),
        api_versions: vec![1],
    })
}

fn documented_router() -> OpenApiRouter {
    let document = utoipa::openapi::OpenApiBuilder::new()
        .info(utoipa::openapi::Info::new(
            "Jiabu admin API",
            env!("CARGO_PKG_VERSION"),
        ))
        .build();
    OpenApiRouter::with_openapi(document).routes(routes!(meta))
}

/// Build the admin router without opening a database connection.
pub fn router() -> Router {
    documented_router().split_for_parts().0
}

/// Generate the document from the same handlers used by the router.
pub fn openapi() -> utoipa::openapi::OpenApi {
    documented_router().split_for_parts().1
}
