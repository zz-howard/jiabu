use crate::{
    AppState,
    handlers::{
        api_keys, auth, blobs, chat, client_logs, invitations, me, meta, spaces, status, sync,
        templates, tools,
    },
};
use utoipa_axum::{router::OpenApiRouter, routes};
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RouteSpec {
    pub method: &'static str,
    pub path: String,
}
fn build() -> (
    axum::Router<AppState>,
    utoipa::openapi::OpenApi,
    Vec<RouteSpec>,
) {
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
                path: $path.into(),
            });
            router = router.routes(routes!($handler));
        }};
    }
    mount!("POST", "/v1/sync/push", sync::push);
    mount!("POST", "/v1/sync/pull", sync::pull);
    mount!("PUT", "/v1/spaces/{space_id}/blobs/{sha256}", blobs::upload);
    mount!("GET", "/v1/spaces/{space_id}/blobs/{sha256}", blobs::get);
    mount!("POST", "/v1/spaces/{space_id}/chat/messages", chat::send);
    mount!(
        "GET",
        "/v1/spaces/{space_id}/chat/messages/{message_id}/stream",
        chat::stream
    );
    mount!("POST", "/v1/spaces/{space_id}/chat/actions", chat::action);
    mount!(
        "POST",
        "/v1/spaces/{space_id}/chat/messages/{message_id}/stop",
        chat::stop
    );
    mount!(
        "POST",
        "/v1/spaces/{space_id}/chat/messages/{message_id}/retry",
        chat::retry
    );
    mount!(
        "GET",
        "/v1/spaces/{space_id}/chat/active-messages",
        chat::active
    );
    mount!("GET", "/v1/status", status::get);
    mount!("GET", "/v1/templates", templates::get);
    mount!("GET", "/v1/spaces/{space_id}/tools", tools::list);
    mount!("GET", "/v1/meta", meta::meta);
    mount!("GET", "/healthz", meta::healthz);
    mount!("GET", "/v1/healthz", meta::versioned_healthz);
    mount!("POST", "/v1/auth/login", auth::login);
    mount!("POST", "/v1/auth/logout", auth::logout);
    mount!("GET", "/v1/me", me::get);
    mount!("GET", "/v1/me/api-keys", api_keys::list);
    mount!("POST", "/v1/me/api-keys", api_keys::create);
    mount!("PATCH", "/v1/me/api-keys/{id}", api_keys::rename);
    mount!("POST", "/v1/me/api-keys/{id}/revoke", api_keys::revoke);
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
    #[cfg(test)]
    {
        mount!(
            "POST",
            "/v1/test-ai-session",
            crate::tests::api_keys::ai_probe
        );
        mount!(
            "GET",
            "/v1/spaces/{space_id}/authorization-probe",
            crate::tests::authorization_probe
        );
    }
    let (mut http, document) = router.split_for_parts();
    let registry = jiabu_tools::builtin_registry();
    for tool in registry
        .tools()
        .filter(|tool| tool.exposure() != jiabu_tools::Exposure::AgentOnly)
    {
        let path = tool.api_path();
        catalog.push(RouteSpec {
            method: "POST",
            path: path.clone(),
        });
        http = http.route(
            &path,
            axum::routing::post(tools::invoke).layer(axum::Extension(tools::ToolName(tool.name()))),
        );
    }
    let document = match crate::tool_openapi::extend(document, &registry) {
        Ok(document) => document,
        Err(error) => panic!("invalid generated tool OpenAPI: {error}"),
    };
    (http, document, catalog)
}
pub(crate) fn documented_router() -> (axum::Router<AppState>, utoipa::openapi::OpenApi) {
    let (router, document, _) = build();
    (router, document)
}
pub fn route_catalog() -> Vec<RouteSpec> {
    build().2
}

#[cfg(test)]
mod tests {
    #[test]
    fn documented_router_openapi_round_trips() -> Result<(), serde_json::Error> {
        let (_, document) = super::documented_router();
        let encoded = serde_json::to_value(&document)?;
        let decoded: utoipa::openapi::OpenApi = serde_json::from_value(encoded.clone())?;
        assert_eq!(serde_json::to_value(decoded)?, encoded);
        Ok(())
    }
}
