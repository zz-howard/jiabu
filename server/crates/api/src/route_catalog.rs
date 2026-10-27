use crate::{
    AppState,
    handlers::{auth, client_logs, me, meta},
};
use utoipa_axum::{router::OpenApiRouter, routes};
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RouteSpec {
    pub method: &'static str,
    pub path: &'static str,
}
fn build() -> (OpenApiRouter<AppState>, Vec<RouteSpec>) {
    let document = utoipa::openapi::OpenApiBuilder::new()
        .info(utoipa::openapi::Info::new(
            "Jiabu public API",
            env!("CARGO_PKG_VERSION"),
        ))
        .build();
    let mut router = OpenApiRouter::with_openapi(document);
    let mut catalog = Vec::new();
    // CI prohibits production route mounting outside this module.
    macro_rules! mount {
        ($method:literal,$path:literal,$handler:path) => {{
            catalog.push(RouteSpec {
                method: $method,
                path: $path,
            });
            router = router.routes(routes!($handler));
        }};
    }
    mount!("GET", "/v1/meta", meta::meta);
    mount!("GET", "/healthz", meta::healthz);
    mount!("GET", "/v1/healthz", meta::versioned_healthz);
    mount!("POST", "/v1/auth/login", auth::login);
    mount!("POST", "/v1/auth/logout", auth::logout);
    mount!("GET", "/v1/me", me::get);
    mount!("PATCH", "/v1/me", me::patch);
    mount!("POST", "/v1/me/password", me::password);
    mount!("POST", "/v1/client-logs", client_logs::upload);
    #[cfg(test)]
    {
        mount!("GET", "/v1/spaces/{space_id}/probe", crate::tests::probe);
    }
    (router, catalog)
}
pub(crate) fn documented_router() -> OpenApiRouter<AppState> {
    build().0
}
pub fn route_catalog() -> Vec<RouteSpec> {
    build().1
}
