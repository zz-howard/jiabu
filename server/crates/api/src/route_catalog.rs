use crate::{
    AppState,
    handlers::{auth, client_logs, invitations, me, meta, spaces},
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
    mount!("GET", "/v1/spaces", spaces::list);
    mount!("POST", "/v1/spaces", spaces::create);
    mount!("PATCH", "/v1/spaces/{space_id}", spaces::rename);
    mount!("DELETE", "/v1/spaces/{space_id}", spaces::delete);
    mount!("POST", "/v1/spaces/{space_id}/invitations", spaces::invite);
    mount!(
        "POST",
        "/v1/spaces/{space_id}/invitations/{inv_id}/cancel",
        spaces::cancel
    );
    mount!(
        "DELETE",
        "/v1/spaces/{space_id}/members/{member_id}",
        spaces::remove
    );
    mount!("POST", "/v1/spaces/{space_id}/leave", spaces::leave);
    mount!(
        "POST",
        "/v1/spaces/{space_id}/transfer-ownership",
        spaces::transfer
    );
    mount!(
        "PATCH",
        "/v1/spaces/{space_id}/members/me",
        spaces::display_name
    );
    mount!(
        "GET",
        "/v1/spaces/{space_id}/invitations",
        spaces::invitations
    );
    mount!("GET", "/v1/me/invitations", invitations::list);
    mount!(
        "POST",
        "/v1/me/invitations/{inv_id}/accept",
        invitations::accept
    );
    mount!(
        "POST",
        "/v1/me/invitations/{inv_id}/decline",
        invitations::decline
    );
    (router, catalog)
}
pub(crate) fn documented_router() -> OpenApiRouter<AppState> {
    build().0
}
pub fn route_catalog() -> Vec<RouteSpec> {
    build().1
}
