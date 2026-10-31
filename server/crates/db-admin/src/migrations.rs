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

#[cfg(test)]
mod tests {
    use super::*;
    use jiabu_domain::{
        SpaceId, UserId,
        presets::PRESETS,
        space_init::{DEFAULT_ACCENT, PresetSeed, SpaceInit},
    };
    use sqlx::AssertSqlSafe;
    use uuid::Uuid;

    #[tokio::test]
    async fn migration_0011_upgrades_seeded_jpeg_rows_from_0010() -> Result<()> {
        let root_url = std::env::var("DATABASE_URL")?;
        let root = PgPool::connect(&root_url).await?;
        let disposable: bool = sqlx::query_scalar(include_str!(
            "../../../tests/support/disposable_cluster.sql"
        ))
        .fetch_one(&root)
        .await?;
        ensure!(
            disposable,
            "upgrade test requires the disposable test cluster"
        );
        let mut role_guard = root.acquire().await?;
        sqlx::query("select pg_advisory_lock(726401990)")
            .execute(&mut *role_guard)
            .await?;
        crate::roles::init_roles(&root_url).await?;
        sqlx::query("alter role jiabu_owner password 'jiabu-test-only'")
            .execute(&mut *role_guard)
            .await?;
        sqlx::query("alter role jiabu_admin password 'jiabu-test-only'")
            .execute(&mut *role_guard)
            .await?;
        sqlx::query("select pg_advisory_unlock(726401990)")
            .execute(&mut *role_guard)
            .await?;
        drop(role_guard);

        let name = format!("jiabu_test_upgrade_{}", Uuid::now_v7().simple());
        sqlx::query(AssertSqlSafe(format!(
            "create database {name} owner jiabu_owner"
        )))
        .execute(&root)
        .await?;
        let (scheme, rest) = root_url
            .split_once("://")
            .context("expected PostgreSQL URL")?;
        let host = rest
            .split('/')
            .next()
            .context("missing database host")?
            .rsplit('@')
            .next()
            .context("missing database host")?;
        let owner_url = format!("{scheme}://jiabu_owner:jiabu-test-only@{host}/{name}");
        let admin_url = format!("{scheme}://jiabu_admin:jiabu-test-only@{host}/{name}");
        let directory = std::env::temp_dir().join(format!("jiabu_migrations_{name}"));

        let outcome = async {
            std::fs::create_dir(&directory)?;
            for migration in MIGRATOR.iter().filter(|migration| migration.version <= 10) {
                let description = migration.description.replace(' ', "_");
                std::fs::write(
                    directory.join(format!("{}_{description}.sql", migration.version)),
                    migration.sql.as_str().as_bytes(),
                )?;
            }
            let old = Migrator::new(directory.clone()).await?;
            let owner = PgPool::connect(&owner_url).await?;
            old.run(&owner).await?;
            let plan = SpaceInit {
                space_id: SpaceId(Uuid::now_v7()),
                user_id: UserId(Uuid::now_v7()),
                name: "upgrade fixture".into(),
                accent: DEFAULT_ACCENT.into(),
                currency: "CNY".into(),
                timezone: "UTC".into(),
                is_default: true,
                display_name: "upgrade-fixture".into(),
                presets: PRESETS
                    .iter()
                    .map(|preset| PresetSeed {
                        id: Uuid::now_v7(),
                        preset_key: preset.preset_key.into(),
                    })
                    .collect(),
            };
            crate::users::AdminDb::connect(&admin_url)
                .await?
                .create("upgrade-fixture", "unused", &plan, "test")
                .await?;
            let member: Uuid =
                sqlx::query_scalar("select id from space_members where space_id=$1")
                    .bind(plan.space_id.0)
                    .fetch_one(&owner)
                    .await?;
            sqlx::query("insert into blobs(sha256,mime,bytes,width,height) values(decode(repeat('07',32),'hex'),'image/jpeg',100,12,8)")
                .execute(&owner)
                .await?;
            sqlx::query("insert into blob_refs(space_id,module,sha256,uploaded_by_member_id) values($1,'ledger',decode(repeat('07',32),'hex'),$2)")
                .bind(plan.space_id.0)
                .bind(member)
                .execute(&owner)
                .await?;

            MIGRATOR.run(&owner).await?;
            validate(&owner, &MIGRATOR).await?;
            let dimensions: (Option<i32>, Option<i32>) = sqlx::query_as(
                "select width,height from blobs where sha256=decode(repeat('07',32),'hex')",
            )
            .fetch_one(&owner)
            .await?;
            assert_eq!(dimensions, (Some(12), Some(8)));
            owner.close().await;
            anyhow::Ok(())
        }
        .await;

        sqlx::query(AssertSqlSafe(format!(
            "drop database if exists {name} with (force)"
        )))
        .execute(&root)
        .await?;
        root.close().await;
        let _ = std::fs::remove_dir_all(directory);
        outcome
    }
}
