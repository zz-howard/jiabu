//! All configuration changes are audited in the same transaction. Triggers bump
//! config_version and emit NOTIFY only when the transaction commits.
use crate::users::AdminDb;
use anyhow::{Result, ensure};
use jiabu_domain::ai::{ModelConfig, ProviderConfig, TaskKind};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PriceInput {
    pub provider_kind: String,
    pub model: String,
    pub currency: String,
    pub input: String,
    pub cached_input: Option<String>,
    pub output: String,
    pub cache_write: Option<Value>,
    pub long_context: Option<Value>,
    pub source: String,
    pub as_of: chrono::NaiveDate,
    pub effective_from: chrono::DateTime<chrono::Utc>,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PolicyInput {
    pub allow_paid_fallback: bool,
    pub breaker: jiabu_domain::ai::BreakerConfig,
    pub retry_initial_secs: u32,
    pub retry_max_secs: u32,
    pub waiting_timeout_secs: u32,
}
pub enum ConfigWrite {
    Provider {
        config: ProviderConfig,
        create: bool,
    },
    ProviderEnabled {
        id: String,
        enabled: bool,
    },
    Model {
        config: ModelConfig,
        create: bool,
    },
    ModelEnabled {
        id: Uuid,
        enabled: bool,
    },
    Route {
        task: TaskKind,
        models: Vec<Uuid>,
    },
    Price(PriceInput),
    Policy(PolicyInput),
}
impl AdminDb {
    pub async fn ai_show(&self, kind: &str, id: Option<&str>) -> Result<Value> {
        let rows:Vec<Value>=match kind {
            "provider" => sqlx::query_scalar("select jsonb_build_object('id',p.id,'kind',p.kind,'base_url',p.base_url,'billing',p.billing,'secret_source',p.secret_source,'enabled',p.enabled,'version',p.version,'oauth_client_id',p.oauth_client_id,'oauth_expires_at',p.oauth_expires_at,'credential_set',s.id is not null,'credential_usable',coalesce(s.usable,false),'last4',s.last4,'updated_at',s.updated_at,'host_id',a.host_id) from ai_providers p cross join ai_settings a left join secrets s on s.owner_kind='provider' and s.owner_id=p.id and s.field=case when p.kind='siwc' then 'oauth' else 'api_key' end where ($1::text is null or p.id=$1) order by p.id").bind(id).fetch_all(&self.pool).await?,
            "model" => sqlx::query_scalar("select to_jsonb(m) from ai_models m order by provider_id,model").fetch_all(&self.pool).await?,
            "route" => sqlx::query_scalar("select to_jsonb(r) from ai_routes r order by task_kind,position").fetch_all(&self.pool).await?,
            "price" => sqlx::query_scalar("select to_jsonb(p) from ai_prices p order by effective_from desc,id").fetch_all(&self.pool).await?,
            "settings" => sqlx::query_scalar("select to_jsonb(s) from ai_settings s").fetch_all(&self.pool).await?,
            _ => anyhow::bail!("unknown AI configuration kind"),
        };
        Ok(json!({"items":rows}))
    }
    pub async fn ai_write(&self, write: ConfigWrite, actor: &str) -> Result<()> {
        let mut tx = self.pool.begin().await?;
        // Global order: administrative mutex -> settings row -> configuration rows.
        sqlx::query("select pg_advisory_xact_lock(726401,8)")
            .execute(&mut *tx)
            .await?;
        sqlx::query("select id from ai_settings where id for update")
            .execute(&mut *tx)
            .await?;
        let (action, target) = match write {
            ConfigWrite::Provider { config: p, create } => {
                let changed = if create {
                    sqlx::query("insert into ai_providers(id,kind,base_url,billing,secret_source,enabled) values($1,$2,$3,$4,$5,$6)")
                    .bind(&p.id).bind(&p.kind).bind(&p.base_url).bind(billing(p.billing)).bind(&p.secret_source).bind(p.enabled).execute(&mut *tx).await?.rows_affected()
                } else {
                    sqlx::query("update ai_providers set kind=$2,base_url=$3,billing=$4,secret_source=$5,enabled=$6,version=version+1,updated_at=now() where id=$1")
                    .bind(&p.id).bind(&p.kind).bind(&p.base_url).bind(billing(p.billing)).bind(&p.secret_source).bind(p.enabled).execute(&mut *tx).await?.rows_affected()
                };
                ensure!(changed == 1, "provider not found");
                ("provider.configure", p.id)
            }
            ConfigWrite::ProviderEnabled { id, enabled } => {
                let n=sqlx::query("update ai_providers set enabled=$2,version=version+1,updated_at=now() where id=$1").bind(&id).bind(enabled).execute(&mut *tx).await?.rows_affected();
                ensure!(n == 1, "provider not found");
                ("provider.enabled", id)
            }
            ConfigWrite::Model { config: m, create } => {
                let context = m.context_tokens.map(i32::try_from).transpose()?;
                let n = if create {
                    sqlx::query("insert into ai_models(id,provider_id,model,structured,vision,context_tokens,enabled) values($1,$2,$3,$4,$5,$6,$7)")
                    .bind(m.id).bind(&m.provider_id).bind(&m.model).bind(m.structured.as_str()).bind(m.vision).bind(context).bind(m.enabled).execute(&mut *tx).await?.rows_affected()
                } else {
                    sqlx::query("update ai_models set provider_id=$2,model=$3,structured=$4,vision=$5,context_tokens=$6,enabled=$7 where id=$1")
                    .bind(m.id).bind(&m.provider_id).bind(&m.model).bind(m.structured.as_str()).bind(m.vision).bind(context).bind(m.enabled).execute(&mut *tx).await?.rows_affected()
                };
                ensure!(n == 1, "model not found");
                ("model.configure", m.id.to_string())
            }
            ConfigWrite::ModelEnabled { id, enabled } => {
                let n = sqlx::query("update ai_models set enabled=$2 where id=$1")
                    .bind(id)
                    .bind(enabled)
                    .execute(&mut *tx)
                    .await?
                    .rows_affected();
                ensure!(n == 1, "model not found");
                ("model.enabled", id.to_string())
            }
            ConfigWrite::Route { task, models } => {
                sqlx::query("delete from ai_routes where task_kind=$1")
                    .bind(task.as_str())
                    .execute(&mut *tx)
                    .await?;
                for (position, id) in models.into_iter().enumerate() {
                    sqlx::query(
                        "insert into ai_routes(task_kind,position,model_id) values($1,$2,$3)",
                    )
                    .bind(task.as_str())
                    .bind(i16::try_from(position)?)
                    .bind(id)
                    .execute(&mut *tx)
                    .await?;
                }
                ("route.set", task.as_str().into())
            }
            ConfigWrite::Price(p) => {
                let id = Uuid::now_v7();
                sqlx::query("insert into ai_prices(id,provider_kind,model,currency,input,cached_input,output,cache_write,long_context,source,as_of,effective_from) values($1,$2,$3,$4,$5::text::numeric,$6::text::numeric,$7::text::numeric,$8,$9,$10,$11,$12)")
                    .bind(id).bind(&p.provider_kind).bind(&p.model).bind(&p.currency).bind(&p.input).bind(&p.cached_input).bind(&p.output).bind(&p.cache_write).bind(&p.long_context).bind(&p.source).bind(p.as_of).bind(p.effective_from).execute(&mut *tx).await?;
                ("price.add", id.to_string())
            }
            ConfigWrite::Policy(p) => {
                sqlx::query("update ai_settings set allow_paid_fallback=$1,breaker=$2,retry_initial_secs=$3,retry_max_secs=$4,waiting_timeout_secs=$5 where id")
                .bind(p.allow_paid_fallback).bind(serde_json::to_value(p.breaker)?).bind(i32::try_from(p.retry_initial_secs)?).bind(i32::try_from(p.retry_max_secs)?).bind(i32::try_from(p.waiting_timeout_secs)?).execute(&mut *tx).await?;
                ("settings.set", "ai".into())
            }
        };
        audit(&mut tx, action, &target, actor).await?;
        tx.commit().await?;
        Ok(())
    }
    pub async fn ai_host_id(&self) -> Result<Uuid> {
        Ok(
            sqlx::query_scalar("select host_id from ai_settings where id")
                .fetch_one(&self.pool)
                .await?,
        )
    }
}
fn billing(b: jiabu_domain::ai::Billing) -> &'static str {
    match b {
        jiabu_domain::ai::Billing::Subscription => "subscription",
        jiabu_domain::ai::Billing::Local => "local",
        jiabu_domain::ai::Billing::Paid => "paid",
    }
}
pub(crate) async fn audit(
    tx: &mut Transaction<'_, Postgres>,
    action: &str,
    target: &str,
    actor: &str,
) -> Result<()> {
    sqlx::query("insert into admin_audit(actor_kind,actor_label,action,target_kind,target_id) values('cli',$1,$2,'ai_configuration',$3)").bind(actor).bind(action).bind(target).execute(&mut **tx).await?;
    Ok(())
}
