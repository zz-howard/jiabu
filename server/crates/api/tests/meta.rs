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
    let state = jiabu_api::AppState::new(jiabu_db::AppDb::connect(&fixture.app_url).await?)
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
