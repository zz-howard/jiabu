use anyhow::{Context, Result, ensure};
use sea_orm::{ConnectionTrait, Database, DbBackend, Statement};

#[tokio::test]
async fn postgres_is_at_least_18() -> Result<()> {
    let url = std::env::var("DATABASE_URL")
        .context("DATABASE_URL is required: run server/tool/dev-db.sh start and use its URL")?;
    let db = Database::connect(url)
        .await
        .context("Could not connect to PostgreSQL from DATABASE_URL")?;
    let row = db
        .query_one_raw(Statement::from_string(
            DbBackend::Postgres,
            "select current_setting('server_version_num')::int as version_num".to_owned(),
        ))
        .await?
        .context("PostgreSQL did not return its version")?;
    let version: i32 = row.try_get("", "version_num")?;
    ensure!(
        version >= 180_000,
        "PostgreSQL 18 or newer is required; got {version}"
    );
    db.close().await?;
    Ok(())
}
