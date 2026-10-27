//! Public HTTP surface; routes and their catalog have one mounting entry point.
#[path = "../../../support/credentials.rs"]
mod credentials;
mod error;
mod handlers;
mod middleware;
mod principal;
mod route_catalog;
mod state;
use axum::Router;
pub use error::{ApiError, Problem};
pub use principal::{Principal, SessionOnly, Via};
pub use route_catalog::{RouteSpec, route_catalog};
pub use state::AppState;
pub fn router(state: AppState) -> Router {
    middleware::apply(
        route_catalog::documented_router().split_for_parts().0,
        state,
    )
}
pub fn openapi() -> utoipa::openapi::OpenApi {
    let mut document = route_catalog::documented_router().split_for_parts().1;
    document
        .components
        .get_or_insert_with(Default::default)
        .add_security_scheme(
            "bearer",
            utoipa::openapi::security::SecurityScheme::Http(
                utoipa::openapi::security::HttpBuilder::new()
                    .scheme(utoipa::openapi::security::HttpAuthScheme::Bearer)
                    .build(),
            ),
        );
    document
}
#[cfg(test)]
mod tests;
