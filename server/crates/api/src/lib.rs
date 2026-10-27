//! Public HTTP surface; routes and their catalog have one mounting entry point.
mod api_key_token;
#[path = "../../../support/credentials.rs"]
mod credentials;
mod error;
mod handlers;
mod middleware;
mod principal;
mod route_catalog;
mod services;
mod state;
mod tool_openapi;
use axum::Router;
pub use error::{ApiError, Problem};
pub use middleware::api_key_audit::{PushItemAudit, RequestAudit};
pub use principal::{AccountSession, Principal, SessionOnly, Via};
pub use route_catalog::{RouteSpec, route_catalog};
pub use state::AppState;
pub fn router(state: AppState) -> Router {
    middleware::apply(route_catalog::documented_router().0, state)
}
pub fn openapi() -> utoipa::openapi::OpenApi {
    let mut document = route_catalog::documented_router().1;
    document
        .components
        .get_or_insert_with(Default::default)
        .add_security_scheme(
            "bearer",
            utoipa::openapi::security::SecurityScheme::Http(
                utoipa::openapi::security::HttpBuilder::new()
                    .scheme(utoipa::openapi::security::HttpAuthScheme::Bearer)
                    .description(Some("Bearer session token or personal API key (jiabu_pat_). Account administration requires a session; API keys cannot use AI."))
                    .build(),
            ),
        );
    document
}
#[cfg(test)]
mod tests;
