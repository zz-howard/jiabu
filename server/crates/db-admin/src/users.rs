use anyhow::{Result, ensure};
use jiabu_domain::{UserId, space_init::SpaceInit};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;
#[derive(Clone)]
pub struct AdminDb {
    pool: PgPool,
}
impl AdminDb {
    pub async fn connect(url: &str) -> Result<Self> {
        let pool = PgPool::connect(url).await?;
        let role: String = sqlx::query_scalar("select current_user::text")
            .fetch_one(&pool)
            .await?;
        ensure!(
            role == "jiabu_admin",
            "Account administration requires jiabu_admin"
        );
        Ok(Self { pool })
    }
    pub async fn create(
        &self,
        username: &str,
        password_hash: &str,
        plan: &SpaceInit,
        actor: &str,
    ) -> Result<UserId> {
        let mut tx = self.pool.begin().await?;
        sqlx::query("insert into users(id,username,password_hash,must_change_password) values($1,$2,$3,true)")
            .bind(plan.user_id.0).bind(username).bind(password_hash).execute(&mut *tx).await?;
        initialize_space(&mut tx, plan).await?;
        audit(&mut tx, "user.create", plan.user_id.0, actor).await?;
        tx.commit().await?;
        Ok(plan.user_id)
    }
    pub async fn reset_password(&self, username: &str, hash: &str, actor: &str) -> Result<()> {
        let mut tx = self.pool.begin().await?;
        let id: Uuid = sqlx::query_scalar("update users set password_hash=$2,must_change_password=true,admin_reset_at=now(),admin_reset_notice_pending=true,password_changed_at=now() where lower(username)=lower($1) returning id")
            .bind(username).bind(hash).fetch_one(&mut *tx).await?;
        sqlx::query("delete from sessions where user_id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await?;
        audit(&mut tx, "user.reset-password", id, actor).await?;
        tx.commit().await?;
        Ok(())
    }
    pub async fn set_disabled(&self, username: &str, disabled: bool, actor: &str) -> Result<()> {
        let mut tx = self.pool.begin().await?;
        let id: Uuid = sqlx::query_scalar("update users set disabled_at=case when $2 then now() else null end where lower(username)=lower($1) returning id")
            .bind(username).bind(disabled).fetch_one(&mut *tx).await?;
        if disabled {
            sqlx::query("delete from sessions where user_id=$1")
                .bind(id)
                .execute(&mut *tx)
                .await?;
        }
        audit(
            &mut tx,
            if disabled {
                "user.disable"
            } else {
                "user.enable"
            },
            id,
            actor,
        )
        .await?;
        tx.commit().await?;
        Ok(())
    }
}
/// Reused by account creation and the app-side SpaceInit adapter through the same SQL primitive.
pub async fn initialize_space(
    tx: &mut Transaction<'_, Postgres>,
    plan: &SpaceInit,
) -> Result<Uuid> {
    Ok(
        sqlx::query_scalar("select initialize_space($1,$2,$3,$4,$5,$6,$7,$8,$9)")
            .bind(plan.space_id.0)
            .bind(plan.user_id.0)
            .bind(&plan.name)
            .bind(&plan.accent)
            .bind(&plan.currency)
            .bind(&plan.timezone)
            .bind(plan.is_default)
            .bind(&plan.display_name)
            .bind(serde_json::to_value(&plan.presets)?)
            .fetch_one(&mut **tx)
            .await?,
    )
}
async fn audit(
    tx: &mut Transaction<'_, Postgres>,
    action: &str,
    id: Uuid,
    actor: &str,
) -> Result<()> {
    sqlx::query("insert into admin_audit(actor_kind,actor_label,action,target_kind,target_id) values('cli',$1,$2,'user',$3)")
        .bind(actor).bind(action).bind(id.to_string()).execute(&mut **tx).await?;
    Ok(())
}
