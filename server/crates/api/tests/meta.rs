#[path = "../../../tests/support/mod.rs"]
mod support;
use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use tower::ServiceExt;
#[tokio::test]
async fn meta_advertises_api_v1() -> anyhow::Result<()> {
    let fixture = support::TestDb::new().await?;
    let state = jiabu_api::AppState::with_storage(
        jiabu_db::AppDb::connect(&fixture.app_url).await?,
        jiabu_storage::BlobStore::local(fixture.data_dir())?,
        jiabu_storage::ImageLimits::default(),
    )
    .await
    .map_err(anyhow::Error::msg)?;
    let router = jiabu_api::router(state);
    let response = router
        .clone()
        .oneshot(Request::builder().uri("/v1/meta").body(Body::empty())?)
        .await?;
    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), 1024 * 1024).await?;
    let value: serde_json::Value = serde_json::from_slice(&body)?;
    assert_eq!(value["api_versions"], serde_json::json!([1]));
    assert_eq!(
        router
            .oneshot(Request::builder().uri("/healthz").body(Body::empty())?)
            .await?
            .status(),
        StatusCode::OK
    );
    Ok(())
}

#[tokio::test]
async fn production_router_excludes_module_authorization_probe() -> anyhow::Result<()> {
    // Integration tests link the library without cfg(test), unlike its unit tests.
    let pattern = "/v1/spaces/{space_id}/authorization-probe";
    assert!(
        jiabu_api::route_catalog()
            .iter()
            .all(|route| route.path != pattern)
    );
    let document = serde_json::to_value(jiabu_api::openapi())?;
    assert!(document["paths"].get(pattern).is_none());
    assert!(
        document["components"]["schemas"]
            .get("AuthorizationProbeResponse")
            .is_none()
    );

    let fixture = support::TestDb::new().await?;
    let state = jiabu_api::AppState::with_storage(
        jiabu_db::AppDb::connect(&fixture.app_url).await?,
        jiabu_storage::BlobStore::local(fixture.data_dir())?,
        jiabu_storage::ImageLimits::default(),
    )
    .await
    .map_err(anyhow::Error::msg)?;
    let response = jiabu_api::router(state)
        .oneshot(
            Request::builder()
                .uri(pattern.replace("{space_id}", &uuid::Uuid::now_v7().to_string()))
                .body(Body::empty())?,
        )
        .await?;
    // A mounted probe would authenticate this request and return 401.
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
    let body: serde_json::Value =
        serde_json::from_slice(&to_bytes(response.into_body(), 1024 * 1024).await?)?;
    assert_eq!(body["code"], "not_found");
    Ok(())
}
