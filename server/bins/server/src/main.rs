mod ai_runtime;
mod config;
mod tasks;
mod templates;
use anyhow::{Context, Result};
use secrecy::{ExposeSecret, SecretString};
use tracing_subscriber::EnvFilter;
#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .json()
        .flatten_event(true)
        .with_current_span(true)
        .with_span_list(false)
        .init();
    let settings = config::Settings::load()?;
    let app_url: SecretString = std::env::var("JIABU_DATABASE_URL")
        .context("JIABU_DATABASE_URL is required")?
        .into();
    if settings.migrate_on_start {
        let owner_url: SecretString = std::env::var("JIABU_OWNER_DATABASE_URL")
            .context("JIABU_OWNER_DATABASE_URL is required for automatic migrations")?
            .into();
        jiabu_db_admin::migrations::migrate(owner_url.expose_secret()).await?;
    }
    jiabu_db_admin::migrations::validate_startup(app_url.expose_secret()).await?;
    let db = jiabu_db::AppDb::connect(app_url.expose_secret())
        .await
        .context("Could not connect to application database")?;
    let blobs = jiabu_storage::BlobStore::local(&settings.data_dir)?;
    let state = jiabu_api::AppState::with_storage(db, blobs, settings.blobs)
        .await
        .map_err(anyhow::Error::msg)?;
    let state = state
        .with_api_key_limiter(std::sync::Arc::new(
            jiabu_tools::api_key::ApiKeyLimiter::configured(settings.api_keys),
        ))
        .map_err(anyhow::Error::msg)?;
    let ai_task = ai_runtime::start(state.db.clone(), state.ai.clone(), app_url).await?;
    if templates::load(&state.db, &state.templates, &settings.data_dir)
        .await
        .is_err()
    {
        jiabu_tools::templates::log_rejection("templates", "database");
    }
    #[cfg(unix)]
    let template_task = templates::start(
        state.db.clone(),
        state.templates.clone(),
        settings.data_dir.clone(),
    )?;
    // First pass runs immediately, including tombstones left by a previous process.
    let purge_task = tokio::spawn(tasks::purge_spaces::run(
        state.db.clone(),
        state.purge_signal(),
    ));
    let cleanup_task = tokio::spawn(tasks::cleanup::run(
        state.db.clone(),
        state.blobs.clone(),
        state.clock.clone(),
    ));
    let allocation_task = tokio::spawn(tasks::monthly_allocation::run(state.db.clone()));
    let listener = tokio::net::TcpListener::bind(&settings.listen_addr)
        .await
        .context("Failed to bind HTTP listener")?;
    tracing::info!(address=%listener.local_addr()?,"Public HTTP listener ready");
    let result = axum::serve(
        listener,
        jiabu_api::router(state).into_make_service_with_connect_info::<std::net::SocketAddr>(),
    )
    .await
    .context("HTTP server failed");
    #[cfg(unix)]
    template_task.abort();
    ai_task.abort();
    purge_task.abort();
    allocation_task.abort();
    cleanup_task.abort();
    result
}
