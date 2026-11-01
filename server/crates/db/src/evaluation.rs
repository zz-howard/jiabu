//! Narrow read-only observations for offline evaluation. Business data remains
//! scoped to an authorized SpaceTx; this module never returns a connection.
use crate::{AppDb, DbErr, SpaceTx, SystemTx};
use jiabu_domain::SpaceId;
use sea_orm::{ConnectionTrait, DbBackend, Statement};
use serde_json::Value;
use uuid::Uuid;
impl SpaceTx {
    /// Includes every entity event, so write-then-void and non-record writes
    /// cannot masquerade as an empty ledger. Call before and after a run.
    pub async fn evaluation_state(&self, space: SpaceId) -> Result<Value, DbErr> {
        self.member(space);
        let row = self.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select jsonb_build_object('currency',(select currency from spaces where id=$1),'records',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from records r where r.space_id=$1),'[]'::jsonb),'events',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'entity_kind',e.entity_kind,'entity_id',e.entity_id,'kind',e.kind,'after',e.after) order by e.id) from entity_events e where e.space_id=$1),'[]'::jsonb)) data",
            [space.0.into()])).await?.ok_or_else(|| DbErr::Custom("evaluation state missing".into()))?;
        row.try_get("", "data")
    }
    /// Member and run scope match journal/calls; no credentials or model output text.
    pub async fn evaluation_calls(&self, space: SpaceId, run: Uuid) -> Result<Vec<Value>, DbErr> {
        self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select jsonb_build_object('provider_id',c.provider_id,'model',c.model,'call_kind',c.call_kind,'cached_input_tokens',c.cached_input_tokens,'cache_write_tokens',c.cache_write_tokens,'uncached_input_tokens',c.input_tokens-c.cached_input_tokens-c.cache_write_tokens,'cost_usd',c.cost_usd::text,'latency_ms',c.latency_ms,'outcome',c.outcome) data from ai_calls c join agent_runs r on r.id=c.run_id where r.space_id=$1 and r.member_id=$2 and r.id=$3 order by c.id",
            vec![space.0.into(),self.member(space).id().0.into(),run.into()])).await?.into_iter().map(|r| r.try_get("", "data")).collect()
    }
    /// Stream events committed in the same transaction as a display tool result.
    /// PostgreSQL `xmin` identifies the transaction that persisted both rows,
    /// giving the evaluator block provenance without trusting model text or
    /// reconstructing the mapper's output.
    pub async fn evaluation_display_events(
        &self,
        space: SpaceId,
        run: Uuid,
    ) -> Result<Vec<Value>, DbErr> {
        self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select e.event data from chat_stream_events e join agent_runs r on r.assistant_message_id=e.message_id where r.space_id=$1 and r.member_id=$2 and r.id=$3 and exists(select 1 from agent_run_items i join agent_tool_calls c on c.run_id=i.run_id and c.call_id=i.call_id where i.run_id=r.id and i.kind='tool_result' and i.xmin=e.xmin and c.tool in ('show_metrics','show_records','show_trend','show_breakdown','show_bar_chart','show_account_card')) order by e.seq",
            vec![space.0.into(),self.member(space).id().0.into(),run.into()])).await?.into_iter().map(|r| r.try_get("", "data")).collect()
    }
}
impl AppDb {
    /// Non-sensitive tariff snapshot for scratch databases. Decimal rates are
    /// strings, preserving PostgreSQL numeric precision on import.
    pub async fn evaluation_prices(&self) -> Result<Vec<Value>, DbErr> {
        let tx = SystemTx::begin(self).await?;
        let rows = tx.tx.query_all_raw(Statement::from_string(DbBackend::Postgres,
            "select (to_jsonb(p)-'id'-'created_at') || jsonb_build_object('input',p.input::text,'cached_input',p.cached_input::text,'output',p.output::text) data from ai_prices p order by effective_from,created_at,id".to_owned())).await?;
        let values = rows
            .into_iter()
            .map(|r| r.try_get("", "data"))
            .collect::<Result<Vec<Value>, DbErr>>()?;
        tx.commit().await?;
        Ok(values)
    }
}
