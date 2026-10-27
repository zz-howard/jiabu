use anyhow::{Context, Result, bail, ensure};
use sqlx::{PgPool, Row, migrate::Migrator};
pub static MIGRATOR: Migrator = sqlx::migrate!("../../migrations");
/// No schema mutation. Also called when migrate_on_start is false.
pub async fn validate(pool: &PgPool, migrator: &Migrator) -> Result<()> {
    let rows =
        sqlx::query("select version,checksum,success from _sqlx_migrations order by version")
            .fetch_all(pool)
            .await
            .context("Migration metadata unavailable; run admin migrate")?;
    for row in rows {
        let version: i64 = row.try_get("version")?;
        ensure!(
            row.try_get::<bool, _>("success")?,
            "Migration {version} is dirty"
        );
        let Some(embedded) = migrator.iter().find(|m| m.version == version) else {
            bail!("Applied migration {version} is not in this binary");
        };
        let checksum: Vec<u8> = row.try_get("checksum")?;
        ensure!(
            checksum.as_slice() == embedded.checksum.as_ref(),
            "Migration {version} previously applied but has been modified"
        );
    }
    Ok(())
}
pub async fn migrate(url: &str) -> Result<()> {
    let pool = PgPool::connect(url).await?;
    let role: String = sqlx::query_scalar("select current_user::text")
        .fetch_one(&pool)
        .await?;
    ensure!(role == "jiabu_owner", "Migrations require jiabu_owner");
    MIGRATOR.run(&pool).await?;
    validate(&pool, &MIGRATOR).await?;
    pool.close().await;
    Ok(())
}
pub async fn validate_startup(url: &str) -> Result<()> {
    let pool = PgPool::connect(url).await?;
    validate(&pool, &MIGRATOR).await?;
    let count: i64 = sqlx::query_scalar("select count(*) from _sqlx_migrations where success")
        .fetch_one(&pool)
        .await?;
    ensure!(
        count as usize == MIGRATOR.iter().count(),
        "Unapplied migrations; run admin migrate"
    );
    pool.close().await;
    Ok(())
}
