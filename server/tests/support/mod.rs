//! Real PostgreSQL fixtures. Each test owns a database, including on panic.
#![allow(dead_code)]
use anyhow::{Context, Result};
use jiabu_domain::{
    SpaceId, UserId,
    presets::PRESETS,
    space_init::{DEFAULT_ACCENT, PresetSeed, SpaceInit},
};
use sqlx::PgPool;
use uuid::Uuid;
/// Shared with tool/check-entities.sh; see the file for the rule.
pub const DISPOSABLE_CLUSTER_SQL: &str = include_str!("disposable_cluster.sql");
/// Fake, test-only password for the three database roles; never used outside tests.
pub const TEST_ROLE_PASSWORD: &str = "jiabu-test-only";

pub struct TestDb {
    pub root_url: String,
    pub name: String,
    pub owner_url: String,
    pub app_url: String,
    pub admin_url: String,
}
impl TestDb {
    pub async fn new() -> Result<Self> {
        let root_url = std::env::var("DATABASE_URL")
            .context("DATABASE_URL must be a PostgreSQL 18 superuser URL")?;
        let root = PgPool::connect(&root_url).await?;
        let disposable: bool = sqlx::query_scalar(DISPOSABLE_CLUSTER_SQL)
            .fetch_one(&root)
            .await?;
        anyhow::ensure!(
            disposable,
            "Refusing to touch cluster-wide jiabu_* roles: DATABASE_URL is not a disposable test \
             cluster (needs the jiabu_disposable_test_cluster marker database and no non-test \
             database owned by a jiabu_* role; tool/dev-db.sh start creates the marker)"
        );
        // Tests run in parallel processes; role DDL on the shared cluster must not race
        // ("tuple concurrently updated"). Serialize it with a session-level advisory lock.
        let mut guard = root.acquire().await?;
        sqlx::query("select pg_advisory_lock(726401990)")
            .execute(&mut *guard)
            .await?;
        let setup = async {
            jiabu_db_admin::roles::init_roles(&root_url).await?;
            // Test-only role password so role connections work under password authentication (CI and the build host).
            for role in ["jiabu_owner", "jiabu_app", "jiabu_admin"] {
                sqlx::query(sqlx::AssertSqlSafe(format!(
                    "alter role {role} password '{TEST_ROLE_PASSWORD}'"
                )))
                .execute(&mut *guard)
                .await?;
            }
            anyhow::Ok(())
        }
        .await;
        sqlx::query("select pg_advisory_unlock(726401990)")
            .execute(&mut *guard)
            .await?;
        drop(guard);
        setup?;
        let version: i32 = sqlx::query_scalar("select current_setting('server_version_num')::int")
            .fetch_one(&root)
            .await?;
        anyhow::ensure!(version >= 180000, "PostgreSQL 18 is required");
        let name = format!("jiabu_test_{}", Uuid::now_v7().simple());
        sqlx::query(sqlx::AssertSqlSafe(format!(
            "create database {name} owner jiabu_owner"
        )))
        .execute(&root)
        .await?;
        root.close().await;
        let (scheme, rest) = root_url
            .split_once("://")
            .context("Expected PostgreSQL URL")?;
        let authority = rest.split('/').next().context("Missing database host")?;
        let host = authority
            .rsplit('@')
            .next()
            .context("Missing database host")?;
        let fixture = Self {
            root_url: root_url.clone(),
            name: name.clone(),
            owner_url: format!("{scheme}://jiabu_owner:{TEST_ROLE_PASSWORD}@{host}/{name}"),
            app_url: format!("{scheme}://jiabu_app:{TEST_ROLE_PASSWORD}@{host}/{name}"),
            admin_url: format!("{scheme}://jiabu_admin:{TEST_ROLE_PASSWORD}@{host}/{name}"),
        };
        jiabu_db_admin::migrations::migrate(&fixture.owner_url).await?;
        Ok(fixture)
    }
    pub async fn owner(&self) -> Result<PgPool> {
        Ok(PgPool::connect(&self.owner_url).await?)
    }
    pub async fn admin(&self) -> Result<jiabu_db_admin::users::AdminDb> {
        jiabu_db_admin::users::AdminDb::connect(&self.admin_url).await
    }
    pub async fn seed(&self, username: &str, hash: &str) -> Result<SpaceInit> {
        let plan = plan(username);
        self.admin()
            .await?
            .create(username, hash, &plan, "test-operator")
            .await?;
        Ok(plan)
    }
}
pub fn plan(username: &str) -> SpaceInit {
    SpaceInit {
        space_id: SpaceId(Uuid::now_v7()),
        user_id: UserId(Uuid::now_v7()),
        name: "示例空间".into(),
        accent: DEFAULT_ACCENT.into(),
        currency: "CNY".into(),
        timezone: "Asia/Shanghai".into(),
        is_default: true,
        display_name: username.into(),
        presets: PRESETS
            .iter()
            .map(|p| PresetSeed {
                id: Uuid::now_v7(),
                preset_key: p.preset_key.into(),
            })
            .collect(),
    }
}
impl Drop for TestDb {
    fn drop(&mut self) {
        let url = self.root_url.clone();
        let name = self.name.clone();
        // A separate runtime makes cleanup work even while the test runtime unwinds.
        let _ = std::thread::spawn(move || {
            if let Ok(runtime) = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
            {
                runtime.block_on(async move {
                    if let Ok(root) = PgPool::connect(&url).await {
                        let _ = sqlx::query(sqlx::AssertSqlSafe(format!(
                            "drop database if exists {name} with (force)"
                        )))
                        .execute(&root)
                        .await;
                        root.close().await;
                    }
                });
            }
        })
        .join();
    }
}
