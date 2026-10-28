use crate::{ai_configuration::audit, users::AdminDb};
use anyhow::{Result, ensure};
use jiabu_domain::ai::EncryptedSecret;
impl AdminDb {
    /// Only accepts already-encrypted values. Never sees the plaintext/master key.
    pub async fn ai_set_secret(
        &self,
        provider: &str,
        field: &str,
        secret: Option<&EncryptedSecret>,
        actor: &str,
    ) -> Result<()> {
        self.ai_secret_write(provider, field, secret, None, actor)
            .await
    }
    pub async fn ai_login_client(&self, provider: &str) -> Result<Option<String>> {
        Ok(sqlx::query_scalar(
            "select oauth_client_id from ai_providers where id=$1 and kind='siwc'",
        )
        .bind(provider)
        .fetch_one(&self.pool)
        .await?)
    }
    pub async fn ai_save_oauth(
        &self,
        provider: &str,
        secret: &EncryptedSecret,
        client_id: &str,
        expires_at: i64,
        actor: &str,
    ) -> Result<()> {
        self.ai_secret_write(
            provider,
            "oauth",
            Some(secret),
            Some((client_id, expires_at)),
            actor,
        )
        .await
    }
    async fn ai_secret_write(
        &self,
        provider: &str,
        field: &str,
        secret: Option<&EncryptedSecret>,
        metadata: Option<(&str, i64)>,
        actor: &str,
    ) -> Result<()> {
        let mut tx = self.pool.begin().await?;
        sqlx::query("select pg_advisory_xact_lock(726401,8)")
            .execute(&mut *tx)
            .await?;
        sqlx::query("select id from ai_settings where id for update")
            .execute(&mut *tx)
            .await?;
        let exists: bool =
            sqlx::query_scalar("select exists(select 1 from ai_providers where id=$1)")
                .bind(provider)
                .fetch_one(&mut *tx)
                .await?;
        ensure!(exists, "provider not found");
        if let Some(s) = secret {
            sqlx::query("insert into secrets(owner_kind,owner_id,field,key_id,nonce,ciphertext,last4) values('provider',$1,$2,$3,$4,$5,$6) on conflict(owner_kind,owner_id,field) do update set key_id=excluded.key_id,nonce=excluded.nonce,ciphertext=excluded.ciphertext,last4=excluded.last4,revision=secrets.revision+1,usable=true,updated_at=now()")
                .bind(provider).bind(field).bind(&s.key_id).bind(&s.nonce).bind(&s.ciphertext).bind(&s.last4).execute(&mut *tx).await?;
            sqlx::query("update ai_providers set secret_source='db',version=version+1,updated_at=now() where id=$1").bind(provider).execute(&mut *tx).await?;
        } else {
            sqlx::query(
                "delete from secrets where owner_kind='provider' and owner_id=$1 and field=$2",
            )
            .bind(provider)
            .bind(field)
            .execute(&mut *tx)
            .await?;
        }
        if let Some((client, expires)) = metadata {
            sqlx::query("update ai_providers set oauth_client_id=$2,oauth_expires_at=$3 where id=$1 and kind='siwc'").bind(provider).bind(client).bind(expires).execute(&mut *tx).await?;
        }
        audit(
            &mut tx,
            if secret.is_some() {
                "provider.set-secret"
            } else {
                "provider.clear-secret"
            },
            provider,
            actor,
        )
        .await?;
        tx.commit().await?;
        Ok(())
    }
}
