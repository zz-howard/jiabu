use anyhow::Result;
use sqlx::PgPool;
pub const INIT_ROLES_SQL: &str = include_str!("sql/init_roles.sql");
pub async fn init_roles(url: &str) -> Result<()> {
    let pool = PgPool::connect(url).await?;
    let mut tx = pool.begin().await?;
    sqlx::raw_sql(INIT_ROLES_SQL).execute(&mut *tx).await?;
    tx.commit().await?;
    pool.close().await;
    Ok(())
}
