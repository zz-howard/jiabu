//! Global AI configuration; a single statement gives a consistent MVCC snapshot.
use crate::{AppDb, DbErr, SystemTx};
use jiabu_domain::ai::{AiConfig, EncryptedSecret};
use sea_orm::{ConnectionTrait, DbBackend, Statement};
impl SystemTx {
    pub async fn ai_config(&self) -> Result<AiConfig, DbErr> {
        let row = self.tx.query_one_raw(Statement::from_string(DbBackend::Postgres,
            "select jsonb_build_object('version',s.config_version,'allow_paid_fallback',s.allow_paid_fallback,'breaker',s.breaker,'retry_initial_secs',s.retry_initial_secs,'retry_max_secs',s.retry_max_secs,'waiting_timeout_secs',s.waiting_timeout_secs,'host_id',s.host_id,
             'providers',coalesce((select jsonb_agg(to_jsonb(p) order by p.id) from ai_providers p),'[]'::jsonb),
             'models',coalesce((select jsonb_agg(to_jsonb(m) order by m.id) from ai_models m),'[]'::jsonb),
             'routes',coalesce((select jsonb_agg(to_jsonb(r) order by r.task_kind,r.position) from ai_routes r),'[]'::jsonb)) as body from ai_settings s where s.id".to_owned()))
            .await?.ok_or_else(|| DbErr::Custom("AI settings missing".into()))?;
        let body: serde_json::Value = row.try_get("", "body")?;
        let config: AiConfig = serde_json::from_value(body)
            .map_err(|_| DbErr::Custom("invalid AI configuration".into()))?;
        if config.breaker.failures == 0
            || config.breaker.cool_down_secs == 0
            || config.waiting_timeout_secs == 0
            || config.waiting_timeout_secs > 600
            || config.retry_initial_secs == 0
            || config.retry_max_secs < config.retry_initial_secs
        {
            return Err(DbErr::Custom("invalid AI policy".into()));
        }
        Ok(config)
    }
    pub async fn ai_secret(&self, provider: &str) -> Result<Option<EncryptedSecret>, DbErr> {
        self.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select key_id,nonce,ciphertext,last4,revision,usable from secrets where owner_kind='provider' and owner_id=$1 and field='oauth'",[provider.into()])).await?
            .map(|r| Ok(EncryptedSecret { key_id:r.try_get("","key_id")?,nonce:r.try_get("","nonce")?,ciphertext:r.try_get("","ciphertext")?,last4:r.try_get("","last4")?,revision:r.try_get("","revision")?,usable:r.try_get("","usable")? })).transpose()
    }
    pub async fn rotate_ai_secret(
        &self,
        provider: &str,
        expected: i64,
        next: &EncryptedSecret,
        expires_at: i64,
    ) -> Result<bool, DbErr> {
        let row = self
            .tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select ai_refresh_oauth($1,$2,$3,$4,$5,$6) as changed",
                vec![
                    provider.into(),
                    expected.into(),
                    next.key_id.clone().into(),
                    next.nonce.clone().into(),
                    next.ciphertext.clone().into(),
                    expires_at.into(),
                ],
            ))
            .await?
            .ok_or_else(|| DbErr::Custom("missing OAuth rotation result".into()))?;
        row.try_get("", "changed")
    }
    pub async fn invalidate_ai_secret(&self, provider: &str, expected: i64) -> Result<bool, DbErr> {
        let row = self
            .tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select ai_invalidate_oauth($1,$2) as changed",
                vec![provider.into(), expected.into()],
            ))
            .await?
            .ok_or_else(|| DbErr::Custom("missing OAuth invalidation result".into()))?;
        row.try_get("", "changed")
    }
}
impl AppDb {
    pub async fn ai_configuration(&self) -> Result<AiConfig, DbErr> {
        let tx = SystemTx::begin(self).await?;
        let config = tx.ai_config().await?;
        tx.commit().await?;
        Ok(config)
    }
}
pub struct ConfigNotifications {
    listener: sqlx::postgres::PgListener,
}
impl ConfigNotifications {
    pub async fn connect(url: &str) -> Result<Self, sqlx::Error> {
        let mut listener = sqlx::postgres::PgListener::connect(url).await?;
        listener.listen("ai_config").await?;
        Ok(Self { listener })
    }
    pub async fn changed(&mut self) -> Result<(), sqlx::Error> {
        self.listener.recv().await.map(|_| ())
    }
}
