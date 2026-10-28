//! Attempts commit before HTTP and finish in a separate transaction from journals.
use crate::{AppDb, DbErr, SystemTx};
use sea_orm::{ConnectionTrait, DbBackend, Statement};
use uuid::Uuid;
pub struct CallStart<'a> {
    pub run_id: Option<Uuid>,
    pub task: &'a str,
    pub provider: &'a str,
    pub model: &'a str,
    pub structured: &'a str,
    pub call_kind: &'a str,
    pub attempt_token: Uuid,
}
pub struct CallFinish<'a> {
    pub id: i64,
    pub attempt_token: Uuid,
    pub latency_ms: i32,
    pub usage: Option<[i32; 4]>,
    pub error_kind: Option<&'a str>,
}
impl AppDb {
    pub async fn register_ai_call(&self, call: CallStart<'_>) -> Result<i64, DbErr> {
        let tx = SystemTx::begin(self).await?;
        // Ownership is copied from the durable run, never accepted from HTTP input.
        // probe is the only case with no run or space ownership.
        let row=tx.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into ai_calls(run_id,space_id,member_id,user_id,task_kind,provider_id,model,structured_mode,call_kind,outcome,attempt_token,price_id,price_as_of)
             select r.id,r.space_id,r.member_id,member.user_id,$2,$3,$4,$5,$6,'started',$7,p.id,p.as_of
             from (select $1::uuid as requested) a left join agent_runs r on r.id=a.requested left join space_members member on member.id=r.member_id and member.space_id=r.space_id
             left join lateral(select p.id,p.as_of from ai_prices p join ai_providers ap on ap.id=$3 and ap.kind=p.provider_kind where p.model=$4 and p.effective_from<=now() order by p.effective_from desc,p.created_at desc,p.id desc limit 1) p on true
             where (r.id is not null and $2<>'probe') or ($1 is null and $2='probe') returning id,price_id",
            vec![call.run_id.into(),call.task.into(),call.provider.into(),call.model.into(),call.structured.into(),call.call_kind.into(),call.attempt_token.into()])).await?.ok_or_else(|| DbErr::Custom("AI call run not found".into()))?;
        let id = row.try_get("", "id")?;
        if row.try_get::<Option<Uuid>>("", "price_id")?.is_none() {
            tracing::warn!(
                provider_id = call.provider,
                model = call.model,
                error_kind = "missing_price",
                "AI price unavailable"
            );
        }
        tx.commit().await?;
        Ok(id)
    }
    pub async fn finish_ai_call(&self, call: CallFinish<'_>) -> Result<(), DbErr> {
        if call.usage.is_some_and(|u| {
            u.iter().any(|v| *v < 0) || i64::from(u[2]) + i64::from(u[3]) > i64::from(u[0])
        }) {
            return Err(DbErr::Custom("invalid AI usage".into()));
        }
        let tx = SystemTx::begin(self).await?;
        let u = call.usage;
        let result=tx.tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "update ai_calls set latency_ms=$3,input_tokens=$4,output_tokens=$5,cached_input_tokens=$6,cache_write_tokens=$7,error_kind=$8,outcome=case when $8::text is null then 'succeeded' else 'failed' end,completed_at=now() where id=$1 and attempt_token=$2 and completed_at is null",
            vec![call.id.into(),call.attempt_token.into(),call.latency_ms.into(),u.map(|v|v[0]).into(),u.map(|v|v[1]).into(),u.map(|v|v[2]).into(),u.map(|v|v[3]).into(),call.error_kind.map(str::to_owned).into()])).await?;
        if result.rows_affected() != 1 {
            return Err(DbErr::Custom(
                "AI call already completed or not owned".into(),
            ));
        }
        // Decimal arithmetic stays in PostgreSQL NUMERIC; no binary floating point.
        // If a cache tariff cannot be determined, cost remains NULL.
        tx.tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "with rates as (select c.id,case when c.input_tokens>coalesce((p.long_context->>'above_tokens')::int,2147483647) then (p.long_context->>'input')::numeric else p.input end as i,
             case when c.input_tokens>coalesce((p.long_context->>'above_tokens')::int,2147483647) then (p.long_context->>'cached_input')::numeric else p.cached_input end as ci,
             case when c.input_tokens>coalesce((p.long_context->>'above_tokens')::int,2147483647) then (p.long_context->>'output')::numeric else p.output end as o,
             coalesce((p.cache_write->>'default')::numeric,(select case when count(*)=1 then min(value::text::numeric) end from jsonb_each_text(p.cache_write))) as cw from ai_calls c join ai_prices p on p.id=c.price_id where c.id=$1 and p.currency='USD')
             update ai_calls c set cost_usd=((c.input_tokens-c.cached_input_tokens-c.cache_write_tokens)*r.i+case when c.cached_input_tokens=0 then 0 else c.cached_input_tokens*r.ci end+case when c.cache_write_tokens=0 then 0 else c.cache_write_tokens*r.cw end+c.output_tokens*r.o)/1000000::numeric,
             cache_saving_usd=(case when c.cached_input_tokens=0 then 0 else c.cached_input_tokens*(r.i-r.ci) end-case when c.cache_write_tokens=0 then 0 else c.cache_write_tokens*(r.cw-r.i) end)/1000000::numeric from rates r where c.id=r.id",
            [call.id.into()])).await?;
        tx.commit().await
    }
    /// The single server process calls this ONCE before accepting work; no live
    /// HTTP attempts exist yet. A timer must never classify an active call lost.
    pub async fn recover_lost_ai_calls(&self) -> Result<(), DbErr> {
        let tx = SystemTx::begin(self).await?;
        tx.tx.execute_raw(Statement::from_string(DbBackend::Postgres,"update ai_calls set outcome='lost',error_kind='process_lost',completed_at=now() where completed_at is null and outcome='started'".to_owned())).await?;
        tx.commit().await
    }
}
