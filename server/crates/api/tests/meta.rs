use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use tower::ServiceExt;

#[tokio::test]
async fn meta_advertises_api_v1() -> Result<(), Box<dyn std::error::Error>> {
    let router = jiabu_api::router();
    let response = router
        .clone()
        .oneshot(Request::builder().uri("/v1/meta").body(Body::empty())?)
        .await?;
    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), 1024 * 1024).await?;
    let value: serde_json::Value = serde_json::from_slice(&body)?;
    assert!(
        value["api_versions"]
            .as_array()
            .is_some_and(|versions| versions.contains(&serde_json::json!(1)))
    );
    let health = router
        .oneshot(Request::builder().uri("/healthz").body(Body::empty())?)
        .await?;
    assert_eq!(health.status(), StatusCode::OK);
    Ok(())
}
