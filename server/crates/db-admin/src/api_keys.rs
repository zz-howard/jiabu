//! Management-safe key projection; token_hash is intentionally absent.
use crate::users::AdminDb;
use anyhow::{Result, ensure};
use serde_json::Value;
use uuid::Uuid;
impl AdminDb {
    pub async fn api_keys(
        &self,
        username: &str,
        revoke: Option<Uuid>,
        actor: &str,
    ) -> Result<Value> {
        let mut tx = self.pool.begin().await?;
        let user: Uuid = sqlx::query_scalar("select id from users where lower(username)=lower($1)")
            .bind(username)
            .fetch_one(&mut *tx)
            .await?;
        if let Some(id) = revoke {
            let found: Option<Uuid> = sqlx::query_scalar(
                "select id from api_keys where id=$1 and user_id=$2 for no key update",
            )
            .bind(id)
            .bind(user)
            .fetch_optional(&mut *tx)
            .await?;
            ensure!(found.is_some(), "key not found");
            sqlx::query("update api_keys set revoked_at=now(),revoked_by='admin' where id=$1 and user_id=$2 and revoked_at is null").bind(id).bind(user).execute(&mut *tx).await?;
        }
        let keys: Vec<Value> = sqlx::query_scalar("select jsonb_build_object('id',id,'name',name,'display_prefix',display_prefix,'scope',scope,'expires_at',expires_at,'created_at',created_at,'last_used_at',last_used_at,'revoked_at',revoked_at,'revoked_by',revoked_by,'status',case when revoked_at is not null then 'revoked' when expires_at<=now() then 'expired' else 'active' end) from api_keys where user_id=$1 order by created_at,id").bind(user).fetch_all(&mut *tx).await?;
        sqlx::query("insert into admin_audit(actor_kind,actor_label,action,target_kind,target_id,detail) values('cli',$1,$2,$3,$4,$5)")
            .bind(actor).bind(if revoke.is_some() { "user.api-keys.revoke" } else { "user.api-keys.list" })
            .bind(if revoke.is_some() { "api_key" } else { "user" }).bind(revoke.unwrap_or(user).to_string())
            .bind(serde_json::json!({"user_id":user})).execute(&mut *tx).await?;
        tx.commit().await?;
        Ok(serde_json::json!({"api_keys":keys}))
    }
}
