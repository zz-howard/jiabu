use anyhow::{Context, Result};
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<()> {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .json()
        .init();
    let address = std::env::var("JIABU_LISTEN_ADDR").unwrap_or_else(|_| "127.0.0.1:8080".into());
    let listener = tokio::net::TcpListener::bind(&address)
        .await
        .context("Failed to bind public HTTP listener")?;
    tracing::info!(address = %listener.local_addr()?, "Public HTTP listener ready");
    axum::serve(listener, jiabu_api::router())
        .await
        .context("HTTP server failed")
}
