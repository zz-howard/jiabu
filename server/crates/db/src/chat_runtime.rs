//! Durable runtime repository. SQL and connection ownership stay in db.
use crate::{AppDb, DbErr, SpaceTx, SystemTx};
use jiabu_domain::{MemberId, SpaceId, UserId};
use sea_orm::{ConnectionTrait, DbBackend, Statement, Value as SqlValue};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

fn statement(sql: &str, values: Vec<SqlValue>) -> Statement {
    Statement::from_sql_and_values(DbBackend::Postgres, sql, values)
}
fn conflict(reason: &'static str) -> DbErr {
    tracing::warn!(reason, "chat runtime conflict");
    DbErr::Custom(format!("runtime_conflict: {reason}"))
}
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct RunLease {
    pub run_id: Uuid,
    pub owner: Uuid,
    pub epoch: i64,
}
#[derive(Clone, Deserialize)]
pub struct RunRow {
    pub id: Uuid,
    pub space_id: Uuid,
    pub member_id: Uuid,
    pub conversation_id: Uuid,
    pub assistant_message_id: Uuid,
    pub input_entry_id: Uuid,
    pub join_epoch: i32,
    pub status: String,
    pub lease_epoch: i64,
    pub lease_owner: Option<Uuid>,
    pub retry_of_run_id: Option<Uuid>,
    pub open_interrupt: Option<Value>,
    pub history_item: Option<Value>,
    pub model_turns: i32,
    pub attempt: i32,
    pub cancel_requested: bool,
    pub journal_compacted_at: Option<String>,
    pub last_error: Option<String>,
}
#[derive(Clone, Serialize, Deserialize)]
pub struct JournalItem {
    pub idx: i32,
    pub kind: String,
    pub call_id: Option<String>,
    pub payload: Value,
    pub provider_blob: Option<Value>,
}
#[derive(Clone, Serialize, Deserialize, PartialEq)]
pub struct ToolCallRow {
    pub call_id: String,
    pub tool: String,
    pub tool_schema_version: i32,
    pub args: Value,
    pub effect: String,
    pub status: String,
    pub idempotency_key: Uuid,
    pub guard: Option<Value>,
}
#[derive(Clone)]
pub struct StoredMessage {
    pub message: Value,
    pub last_seq: i32,
    pub step_work_ms: std::collections::HashMap<String, u64>,
}
impl SpaceTx {
    fn chat_scope(&self, space: SpaceId) -> MemberId {
        self.member(space).id()
    }
    /// Lock the lease row for the entire transaction. Even a lease that has not
    /// yet been swept cannot write after its wall-clock expiry.
    pub async fn guard_run(&self, space: SpaceId, lease: RunLease) -> Result<RunRow, DbErr> {
        self.assert_write();
        let row = self.tx.query_one_raw(statement(
            "select to_jsonb(r) as data from agent_runs r where r.id=$1 and r.space_id=$2 and r.member_id=$3 and r.status='running' and r.lease_owner=$4 and r.lease_epoch=$5 and r.lease_until>clock_timestamp() and r.join_epoch=$6 and not r.cancel_requested for update",
            vec![lease.run_id.into(), space.0.into(), self.chat_scope(space).0.into(), lease.owner.into(), lease.epoch.into(), self.member(space).join_epoch().0.into()])).await?.ok_or_else(|| conflict("guard_run: lease, status or membership mismatch"))?;
        serde_json::from_value(row.try_get("", "data")?)
            .map_err(|_| conflict("guard_run: invalid run row"))
    }
    pub async fn conversation(&self, space: SpaceId) -> Result<Uuid, DbErr> {
        self.assert_write();
        let row = self.tx.query_one_raw(statement(
            "insert into conversations(space_id,member_id,change_seq) values($1,$2,nextval('change_seq')) on conflict(space_id,member_id) do update set member_id=excluded.member_id returning id",
            vec![space.0.into(),self.chat_scope(space).0.into()])).await?.ok_or_else(|| conflict("conversation: missing inserted conversation"))?;
        row.try_get("", "id")
    }
    pub async fn message(&self, space: SpaceId, id: Uuid) -> Result<Option<StoredMessage>, DbErr> {
        self.tx.query_one_raw(statement("select message,last_seq,checkpoint_work_ms from chat_entries where id=$1 and space_id=$2 and member_id=$3",
            vec![id.into(),space.0.into(),self.chat_scope(space).0.into()])).await?.map(|r| Ok(StoredMessage{message:r.try_get("","message")?,last_seq:r.try_get("","last_seq")?,step_work_ms:serde_json::from_value(r.try_get("","checkpoint_work_ms")?).map_err(|_|conflict("message: invalid checkpoint clocks"))?})).transpose()
    }
    pub async fn insert_message(
        &self,
        space: SpaceId,
        conversation: Uuid,
        run: Option<Uuid>,
        reply: Option<Uuid>,
        message: Value,
        seq: i32,
    ) -> Result<(), DbErr> {
        self.assert_write();
        let id: Uuid = message["id"]
            .as_str()
            .ok_or_else(|| conflict("insert_message: missing message id"))?
            .parse()
            .map_err(|_| conflict("insert_message: invalid message id"))?;
        let role = message["role"]
            .as_str()
            .ok_or_else(|| conflict("insert_message: missing role"))?;
        self.tx.execute_raw(statement("insert into chat_entries(id,space_id,member_id,conversation_id,agent_run_id,reply_to_id,protocol_version,message,fallback_text,stream_status,rev,last_seq,role,change_seq,created_at,updated_at) values($1,$2,$3,$4,$5,$6,'0.1',$7,$8,$9,$10,$11,$12,nextval('change_seq'),now(),now())",
            vec![id.into(),space.0.into(),self.chat_scope(space).0.into(),conversation.into(),run.into(),reply.into(),message.clone().into(),message["fallbackText"].as_str().unwrap_or_default().into(),message["status"].as_str().ok_or_else(|| conflict("insert_message: missing status"))?.into(),(message["rev"].as_i64().unwrap_or(0) as i32).into(),seq.into(),role.into()])).await?;
        Ok(())
    }
    /// Atomic event batch + authoritative checkpoint. No caller can lower the
    /// watermark or change another member's message. Expected seq is mandatory.
    pub async fn save_emission(
        &self,
        space: SpaceId,
        id: Uuid,
        expected: i32,
        message: Value,
        events: Vec<Value>,
        work_ms: Value,
    ) -> Result<(), DbErr> {
        self.assert_write();
        let seq = expected
            .checked_add(
                i32::try_from(events.len())
                    .map_err(|_| conflict("save_emission: event count overflow"))?,
            )
            .ok_or_else(|| conflict("save_emission: sequence overflow"))?;
        for (offset, event) in events.iter().enumerate() {
            if event["messageId"] != id.to_string()
                || event["seq"].as_i64() != Some(i64::from(expected) + offset as i64 + 1)
                || event["type"] == "message.activity"
            {
                return Err(conflict("save_emission: invalid event batch"));
            }
        }
        let n=self.tx.execute_raw(statement("update chat_entries set message=$5,last_seq=$6,rev=$7,stream_status=$8,fallback_text=$9,updated_at=now(),change_seq=nextval('change_seq'),checkpoint_work_ms=$10 where id=$1 and space_id=$2 and member_id=$3 and last_seq=$4 and rev<=$7",
            vec![id.into(),space.0.into(),self.chat_scope(space).0.into(),expected.into(),message.clone().into(),seq.into(),(message["rev"].as_i64().unwrap_or(0) as i32).into(),message["status"].as_str().ok_or_else(|| conflict("save_emission: missing status"))?.into(),message["fallbackText"].as_str().unwrap_or_default().into(),work_ms.into()])).await?;
        if n.rows_affected() != 1 {
            return Err(conflict(
                "save_emission: checkpoint watermark or revision mismatch",
            ));
        }
        for event in events {
            self.tx.execute_raw(statement("insert into chat_stream_events(message_id,seq,space_id,member_id,event) values($1,$2,$3,$4,$5)",vec![id.into(),(event["seq"].as_i64().ok_or_else(|| conflict("save_emission: missing event sequence"))? as i32).into(),space.0.into(),self.chat_scope(space).0.into(),event.into()])).await?;
        }
        Ok(())
    }
    pub async fn chat_events(
        &self,
        space: SpaceId,
        id: Uuid,
        after: i32,
        through: i32,
    ) -> Result<Vec<Value>, DbErr> {
        self.tx.query_all_raw(statement("select event from chat_stream_events where space_id=$1 and member_id=$2 and message_id=$3 and seq>$4 and seq<=$5 order by seq",vec![space.0.into(),self.chat_scope(space).0.into(),id.into(),after.into(),through.into()])).await?.into_iter().map(|r| r.try_get("","event")).collect()
    }
    pub async fn run_for_message(
        &self,
        space: SpaceId,
        message: Uuid,
    ) -> Result<Option<RunRow>, DbErr> {
        self.tx.query_one_raw(statement("select to_jsonb(r) as data from agent_runs r where r.space_id=$1 and r.member_id=$2 and r.assistant_message_id=$3 for update",vec![space.0.into(),self.chat_scope(space).0.into(),message.into()])).await?.map(|r|serde_json::from_value(r.try_get("","data")?).map_err(|_|conflict("run_for_message: invalid run row"))).transpose()
    }
    pub async fn active_runs(&self, space: SpaceId) -> Result<Vec<RunRow>, DbErr> {
        self.tx.query_all_raw(statement("select to_jsonb(r) as data from agent_runs r where r.space_id=$1 and r.member_id=$2 and status in ('queued','running','waiting_ai','paused') order by created_at,id for update",vec![space.0.into(),self.chat_scope(space).0.into()])).await?.into_iter().map(|r|serde_json::from_value(r.try_get("","data")?).map_err(|_|conflict("active_runs: invalid run row"))).collect()
    }
    pub async fn active_chat_messages(&self, space: SpaceId) -> Result<Vec<Value>, DbErr> {
        self.tx.query_all_raw(statement(
            "select jsonb_build_object('messageId',c.id,'conversationId',r.conversation_id,'lastSeq',c.last_seq,'replyTo',r.input_entry_id,'status',c.stream_status) as data from agent_runs r join chat_entries c on c.id=r.assistant_message_id and c.space_id=r.space_id and c.member_id=r.member_id where r.space_id=$1 and r.member_id=$2 and r.join_epoch=$3 and r.status in ('queued','running','waiting_ai','paused') order by r.created_at,r.id",
            vec![space.0.into(),self.chat_scope(space).0.into(),self.member(space).join_epoch().0.into()]
        )).await?.into_iter().map(|r| r.try_get("", "data")).collect()
    }
    pub async fn enqueue_run(
        &self,
        space: SpaceId,
        conversation: Uuid,
        input: Uuid,
        message: Uuid,
        id: Uuid,
        retry: Option<Uuid>,
    ) -> Result<(), DbErr> {
        self.assert_write();
        self.tx.execute_raw(statement("insert into agent_runs(id,space_id,member_id,conversation_id,assistant_message_id,input_entry_id,join_epoch,retry_of_run_id,kind,status,agent_def_version,prompt_snapshot) values($1,$2,$3,$4,$5,$6,$7,$8,'chat','queued','s7-v1',''::bytea)",vec![id.into(),space.0.into(),self.chat_scope(space).0.into(),conversation.into(),message.into(),input.into(),self.member(space).join_epoch().0.into(),retry.into()])).await?;
        self.tx
            .execute_raw(statement("select pg_notify('agent_runs','')", vec![]))
            .await?;
        Ok(())
    }
    pub async fn journal(&self, space: SpaceId, run: Uuid) -> Result<Vec<JournalItem>, DbErr> {
        self.tx.query_all_raw(statement("select to_jsonb(i) as data from agent_run_items i join agent_runs r on r.id=i.run_id where r.space_id=$1 and r.member_id=$2 and r.id=$3 order by i.idx",vec![space.0.into(),self.chat_scope(space).0.into(),run.into()])).await?.into_iter().map(|r|serde_json::from_value(r.try_get("","data")?).map_err(|_|conflict("journal: invalid journal item"))).collect()
    }
    pub async fn calls(&self, space: SpaceId, run: Uuid) -> Result<Vec<ToolCallRow>, DbErr> {
        self.tx.query_all_raw(statement("select to_jsonb(c) as data from agent_tool_calls c join agent_runs r on r.id=c.run_id where r.space_id=$1 and r.member_id=$2 and r.id=$3 order by c.updated_at,c.call_id",vec![space.0.into(),self.chat_scope(space).0.into(),run.into()])).await?.into_iter().map(|r|serde_json::from_value(r.try_get("","data")?).map_err(|_|conflict("calls: invalid tool call row"))).collect()
    }
    pub async fn append_journal(
        &self,
        space: SpaceId,
        lease: RunLease,
        kind: &str,
        call: Option<&str>,
        payload: Value,
        blob: Option<Value>,
    ) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        self.tx.execute_raw(statement("with n as (update agent_runs set next_item_idx=next_item_idx+1,updated_at=now() where id=$1 and space_id=$2 returning next_item_idx-1 idx) insert into agent_run_items(run_id,idx,kind,call_id,payload,provider_blob) select $1,idx,$3,$4,$5,$6 from n",vec![lease.run_id.into(),space.0.into(),kind.into(),call.map(str::to_owned).into(),payload.into(),blob.into()])).await?;
        Ok(())
    }
    pub async fn insert_call(
        &self,
        space: SpaceId,
        lease: RunLease,
        call: &ToolCallRow,
        hash: Vec<u8>,
    ) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        self.tx.execute_raw(statement("insert into agent_tool_calls(run_id,call_id,tool,tool_schema_version,args,args_hash,effect,status,idempotency_key,guard) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)",vec![lease.run_id.into(),call.call_id.clone().into(),call.tool.clone().into(),call.tool_schema_version.into(),call.args.clone().into(),hash.into(),call.effect.clone().into(),call.status.clone().into(),call.idempotency_key.into(),call.guard.clone().into()])).await?;
        Ok(())
    }
    pub async fn set_call_status(
        &self,
        space: SpaceId,
        lease: RunLease,
        call: &str,
        status: &str,
    ) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        self.tx.execute_raw(statement("update agent_tool_calls set status=$3,updated_at=now(),attempts=attempts+case when $3='executing' then 1 else 0 end where run_id=$1 and call_id=$2",vec![lease.run_id.into(),call.into(),status.into()])).await?;
        Ok(())
    }
    pub async fn freeze_history(
        &self,
        space: SpaceId,
        lease: RunLease,
        history: Value,
    ) -> Result<Value, DbErr> {
        self.guard_run(space, lease).await?;
        let r=self.tx.query_one_raw(statement("update agent_runs set history_item=coalesce(history_item,$3) where id=$1 and space_id=$2 returning history_item",vec![lease.run_id.into(),space.0.into(),history.into()])).await?.ok_or_else(|| conflict("freeze_history: run missing during history freeze"))?;
        r.try_get("", "history_item")
    }
    pub async fn recent_history(&self, space: SpaceId, before: Uuid) -> Result<Vec<Value>, DbErr> {
        self.tx.query_all_raw(statement("select message from (select message,created_at,id from chat_entries where space_id=$1 and member_id=$2 and (created_at,id)<(select created_at,id from chat_entries where id=$3 and space_id=$1 and member_id=$2) and stream_status in ('complete','interrupted','error') order by created_at desc,id desc limit 100) h order by created_at,id",vec![space.0.into(),self.chat_scope(space).0.into(),before.into()])).await?.into_iter().map(|r|r.try_get("","message")).collect()
    }
    pub async fn finish_run(
        &self,
        space: SpaceId,
        id: Uuid,
        status: &str,
        error: Option<&str>,
    ) -> Result<(), DbErr> {
        self.assert_write();
        if !matches!(
            status,
            "completed" | "cancelled" | "expired" | "failed" | "interrupted"
        ) {
            return Err(conflict("finish_run: invalid terminal status"));
        }
        let n=self.tx.execute_raw(statement("update agent_runs set status=$4,last_error=$5,open_interrupt=null,lease_epoch=lease_epoch+1,lease_owner=null,lease_until=null,ended_at=now(),updated_at=now(),history_item=(select jsonb_build_object('role',c.role,'text',c.fallback_text) from chat_entries c where c.id=agent_runs.assistant_message_id and c.space_id=agent_runs.space_id) where id=$1 and space_id=$2 and member_id=$3 and status in ('queued','running','waiting_ai','paused')",vec![id.into(),space.0.into(),self.chat_scope(space).0.into(),status.into(),error.map(str::to_owned).into()])).await?;
        if n.rows_affected() != 1 {
            return Err(conflict("finish_run: run already terminal or missing"));
        }
        self.tx.execute_raw(statement("update agent_tool_calls set status=case when $2='expired' then 'expired' else 'cancelled' end,updated_at=now() where run_id=$1 and status in ('proposed','awaiting_user','approved','executing')",vec![id.into(),status.into()])).await?;
        Ok(())
    }
    pub async fn pause_run(
        &self,
        space: SpaceId,
        lease: RunLease,
        interrupt: Value,
        call: &str,
    ) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        self.set_call_status(space, lease, call, "awaiting_user")
            .await?;
        self.append_journal(
            space,
            lease,
            "interrupt",
            Some(call),
            interrupt.clone(),
            None,
        )
        .await?;
        self.tx.execute_raw(statement("update agent_runs set status='paused',open_interrupt=$2,lease_owner=null,lease_until=null,lease_epoch=lease_epoch+1,updated_at=now() where id=$1",vec![lease.run_id.into(),interrupt.into()])).await?;
        Ok(())
    }
    pub async fn wait_for_ai(&self, space: SpaceId, lease: RunLease) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        self.tx.execute_raw(statement("update agent_runs set status='waiting_ai',waiting_ai_since=coalesce(waiting_ai_since,now()),run_after=now()+least(60,5*power(2,least(attempt,4))) * interval '1 second',attempt=attempt+1,lease_owner=null,lease_until=null,lease_epoch=lease_epoch+1 where id=$1",vec![lease.run_id.into()])).await?;
        Ok(())
    }
    pub async fn model_turn_committed(&self, space: SpaceId, lease: RunLease) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        self.tx
            .execute_raw(statement(
                "update agent_runs set waiting_ai_since=null,attempt=0 where id=$1",
                vec![lease.run_id.into()],
            ))
            .await?;
        Ok(())
    }
    pub async fn retry_copy(&self, space: SpaceId, old: &RunRow, new: Uuid) -> Result<(), DbErr> {
        self.assert_write();
        // Caller locked old via run_for_message. Retention locks the same row.
        if old.journal_compacted_at.is_some() {
            return Err(conflict("retry_copy: journal compacted"));
        }
        self.tx.execute_raw(statement("insert into agent_run_items(run_id,idx,kind,call_id,payload,provider_blob,schema_version) select $1,i.idx,i.kind,i.call_id,i.payload,i.provider_blob,i.schema_version from agent_run_items i join agent_runs r on r.id=i.run_id where i.run_id=$2 and r.space_id=$3 and r.member_id=$4",vec![new.into(),old.id.into(),space.0.into(),self.chat_scope(space).0.into()])).await?;
        self.tx.execute_raw(statement("insert into agent_tool_calls(run_id,call_id,tool,tool_schema_version,args,args_hash,effect,status,idempotency_key,guard,effect_ref,attempts) select $1,call_id,tool,tool_schema_version,args,args_hash,effect,case when status in ('executing','failed','cancelled','expired') then 'proposed' else status end,idempotency_key,guard,effect_ref,attempts from agent_tool_calls where run_id=$2",vec![new.into(),old.id.into()])).await?;
        self.tx.execute_raw(statement("update agent_runs set history_item=null,prompt_snapshot=o.prompt_snapshot,next_item_idx=o.next_item_idx,model_turns=0 from agent_runs o where agent_runs.id=$1 and o.id=$2",vec![new.into(),old.id.into()])).await?;
        self.tx.execute_raw(statement("with n as (update agent_runs set next_item_idx=next_item_idx+1 where id=$1 returning next_item_idx-1 idx) insert into agent_run_items(run_id,idx,kind,payload) select $1,idx,'note',jsonb_build_object('text','Previous reply did not finish. Recorded operations already took effect; do not repeat them. Continue unfinished work.') from n",vec![new.into()])).await?;
        Ok(())
    }
    pub async fn retry_child(&self, space: SpaceId, old: Uuid) -> Result<Option<RunRow>, DbErr> {
        self.tx.query_one_raw(statement("select to_jsonb(r) data from agent_runs r where space_id=$1 and member_id=$2 and retry_of_run_id=$3",vec![space.0.into(),self.chat_scope(space).0.into(),old.into()])).await?.map(|r|serde_json::from_value(r.try_get("","data")?).map_err(|_|conflict("retry_child: invalid run row"))).transpose()
    }
}
impl AppDb {
    /// Discovery only. All space content writes subsequently enter SpaceTx.
    pub async fn runnable_scopes(&self) -> Result<Vec<(SpaceId, UserId, i32)>, DbErr> {
        let tx = SystemTx::begin(self).await?;
        let rows=tx.tx.query_all_raw(statement("select distinct r.space_id,m.user_id,r.join_epoch from agent_runs r join space_members m on m.id=r.member_id and m.space_id=r.space_id where r.status in ('queued','waiting_ai') and r.run_after<=now() order by r.space_id limit 100",vec![])).await?;
        let result = rows
            .into_iter()
            .map(|r| {
                Ok((
                    SpaceId(r.try_get("", "space_id")?),
                    UserId(r.try_get("", "user_id")?),
                    r.try_get("", "join_epoch")?,
                ))
            })
            .collect();
        tx.commit().await?;
        result
    }
    pub async fn sweep_candidates(&self) -> Result<Vec<(SpaceId, UserId, Uuid, String)>, DbErr> {
        let tx = SystemTx::begin(self).await?;
        let rows=tx.tx.query_all_raw(statement("select r.space_id,m.user_id,r.assistant_message_id,r.status from agent_runs r join space_members m on m.id=r.member_id and m.space_id=r.space_id where (r.status='running' and r.lease_until<now()) or (r.status='waiting_ai' and r.waiting_ai_since<now()-interval '10 minutes') or (r.status='paused' and (r.open_interrupt->>'expires_at')::timestamptz<now())",vec![])).await?;
        let result = rows
            .into_iter()
            .map(|r| {
                Ok((
                    SpaceId(r.try_get("", "space_id")?),
                    UserId(r.try_get("", "user_id")?),
                    r.try_get("", "assistant_message_id")?,
                    r.try_get("", "status")?,
                ))
            })
            .collect();
        tx.commit().await?;
        result
    }
    pub async fn cleanup_chat_logs(&self) -> Result<(), DbErr> {
        let tx = SystemTx::begin(self).await?;
        tx.tx.execute_raw(statement("delete from chat_stream_events e using chat_entries c where e.message_id=c.id and e.space_id=c.space_id and c.stream_status in ('paused','complete','interrupted','error') and c.updated_at<now()-interval '10 minutes' and e.created_at<now()-interval '10 minutes'",vec![])).await?;
        tx.tx
            .execute_raw(statement("select retain_agent_journals(100)", vec![]))
            .await?;
        tx.commit().await
    }
}
impl SpaceTx {
    pub async fn claim_run(&self, space: SpaceId, owner: Uuid) -> Result<Option<RunRow>, DbErr> {
        self.assert_write();
        self.tx.query_one_raw(statement("update agent_runs r set status='running',lease_owner=$3,lease_until=now()+interval '60 seconds',lease_epoch=lease_epoch+1,updated_at=now() where r.id=(select a.id from agent_runs a where a.space_id=$1 and a.member_id=$2 and a.join_epoch=$4 and a.status in ('queued','waiting_ai') and a.run_after<=now() and (a.waiting_ai_since is null or a.waiting_ai_since>now()-interval '10 minutes') and not exists(select 1 from agent_runs b where b.conversation_id=a.conversation_id and b.id<>a.id and (b.status in ('running','paused') or (b.status in ('queued','waiting_ai') and (b.created_at,b.id)<(a.created_at,a.id)))) order by a.created_at,a.id for update skip locked limit 1) returning to_jsonb(r) data",vec![space.0.into(),self.chat_scope(space).0.into(),owner.into(),self.member(space).join_epoch().0.into()])).await?.map(|r|serde_json::from_value(r.try_get("","data")?).map_err(|_|conflict("claim_run: invalid run row"))).transpose()
    }
    pub async fn renew_run(&self, space: SpaceId, lease: RunLease) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        self.tx
            .execute_raw(statement(
                "update agent_runs set lease_until=now()+interval '60 seconds' where id=$1",
                vec![lease.run_id.into()],
            ))
            .await?;
        Ok(())
    }
    pub async fn sweep_still_due(&self, space: SpaceId, run: Uuid) -> Result<bool, DbErr> {
        Ok(self.tx.query_one_raw(statement("select id from agent_runs where id=$1 and space_id=$2 and member_id=$3 and ((status='running' and lease_until<clock_timestamp()) or (status='waiting_ai' and waiting_ai_since<now()-interval '10 minutes') or (status='paused' and (open_interrupt->>'expires_at')::timestamptz<now())) for update",vec![run.into(),space.0.into(),self.chat_scope(space).0.into()])).await?.is_some())
    }
}
impl SpaceTx {
    pub async fn space_context(&self, space: SpaceId) -> Result<Value, DbErr> {
        let m = self.member(space);
        let ledger = m.ledger_grant() >= crate::GrantLevel::Read;
        let documents = m.documents_grant() >= crate::GrantLevel::Read;
        let row=self.tx.query_one_raw(statement("select jsonb_build_object('currency',s.currency,'timezone',s.timezone,'accounts',case when $2 then (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'kind',a.kind,'name',a.name,'is_reserve',a.is_reserve,'archived',a.archived_at is not null) order by a.id),'[]'::jsonb) from accounts a where a.space_id=s.id) else '[]'::jsonb end,'tags',case when $2 then (select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'preset_key',t.preset_key) order by t.id),'[]'::jsonb) from tags t where t.space_id=s.id) else '[]'::jsonb end,'subjects',case when $3 then (select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'name',x.name) order by x.id),'[]'::jsonb) from subjects x where x.space_id=s.id) else '[]'::jsonb end,'members',(select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',m.display_name) order by m.id),'[]'::jsonb) from space_members m where m.space_id=s.id and m.status='active')) data from spaces s where s.id=$1",vec![space.0.into(),ledger.into(),documents.into()])).await?.ok_or_else(|| conflict("space_context: space missing"))?;
        row.try_get("", "data")
    }
    pub async fn action_receipt(
        &self,
        space: SpaceId,
        id: Uuid,
        fingerprint: Vec<u8>,
    ) -> Result<Option<Value>, crate::OperationError> {
        let row=self.tx.query_one_raw(statement("select result,request_fingerprint from chat_actions where id=$1 and space_id=$2 and member_id=$3",vec![id.into(),space.0.into(),self.chat_scope(space).0.into()])).await?;
        if let Some(row) = row {
            if row.try_get::<Option<Vec<u8>>>("", "request_fingerprint")? != Some(fingerprint) {
                return Err(crate::OperationError::new(409, "idempotency_conflict"));
            }
            return Ok(Some(row.try_get("", "result")?));
        }
        Ok(None)
    }
    pub async fn resolve_interrupt(
        &self,
        space: SpaceId,
        run: Uuid,
        interrupt: &Value,
        answer: Value,
        approved: bool,
    ) -> Result<(), crate::OperationError> {
        self.assert_write();
        let call = interrupt["call_id"]
            .as_str()
            .ok_or_else(|| conflict("resolve_interrupt: missing call id"))?;
        let id = interrupt["id"]
            .as_str()
            .ok_or_else(|| conflict("resolve_interrupt: missing interrupt id"))?;
        let n=self.tx.execute_raw(statement("update agent_runs set status='queued',open_interrupt=null,run_after=now(),lease_epoch=lease_epoch+1,updated_at=now() where id=$1 and space_id=$2 and member_id=$3 and status='paused' and open_interrupt->>'id'=$4 and (open_interrupt->>'expires_at')::timestamptz>clock_timestamp()",vec![run.into(),space.0.into(),self.chat_scope(space).0.into(),id.into()])).await?;
        if n.rows_affected() != 1 {
            return Err(crate::OperationError::new(409, "interrupt_resolved"));
        }
        self.tx.execute_raw(statement("update agent_tool_calls set status=$3,updated_at=now() where run_id=$1 and call_id=$2 and status='awaiting_user'",vec![run.into(),call.into(),(if approved {"approved"} else {"rejected"}).into()])).await?;
        for (kind, payload) in [
            ("interrupt_answer", answer.clone()),
            (
                "tool_result",
                serde_json::json!({"output":if answer["outcome"]=="answer"{serde_json::json!({"answer":answer["payload"]})}else{answer.clone()}}),
            ),
        ] {
            if kind == "tool_result" && approved {
                continue;
            }
            self.tx.execute_raw(statement("with n as (update agent_runs set next_item_idx=next_item_idx+1 where id=$1 returning next_item_idx-1 idx) insert into agent_run_items(run_id,idx,kind,call_id,payload) select $1,idx,$2,$3,$4 from n",vec![run.into(),kind.into(),call.into(),payload.into()])).await?;
        }
        if !approved {
            self.tx.execute_raw(statement("update agent_tool_calls set status='succeeded' where run_id=$1 and call_id=$2 and tool='ask_user'",vec![run.into(),call.into()])).await?;
        }
        self.tx
            .execute_raw(statement("select pg_notify('agent_runs','')", vec![]))
            .await?;
        Ok(())
    }
    #[allow(clippy::too_many_arguments)]
    pub async fn remember_action(
        &self,
        space: SpaceId,
        id: Uuid,
        message: Uuid,
        block: &str,
        request: Value,
        fingerprint: Vec<u8>,
        result: Value,
    ) -> Result<(), DbErr> {
        self.tx.execute_raw(statement("insert into chat_actions(id,space_id,member_id,message_id,block_id,action_type,target,payload,status,result,actor_member_id,request_fingerprint) values($1,$2,$3,$4,$5,$6,$7,$8,'accepted',$9,$3,$10)",vec![id.into(),space.0.into(),self.chat_scope(space).0.into(),message.into(),block.into(),request["type"].as_str().ok_or_else(|| conflict("remember_action: missing action type"))?.into(),request["target"].as_str().ok_or_else(|| conflict("remember_action: missing target"))?.into(),request["payload"].clone().into(),result.into(),fingerprint.into()])).await?;
        Ok(())
    }
    pub async fn save_prompt_snapshot(
        &self,
        space: SpaceId,
        lease: RunLease,
        hash: Vec<u8>,
        snapshot: Value,
    ) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        self.tx.execute_raw(statement("insert into agent_prompt_snapshots(hash,agent_def_version,provider_kind,model,instructions,tools,settings) values($1,'s7-v1','router','',$2,$3,$4) on conflict(hash) do nothing",vec![hash.clone().into(),snapshot["instructions"].as_str().ok_or_else(|| conflict("save_prompt_snapshot: missing instructions"))?.into(),snapshot["tools"].clone().into(),snapshot.clone().into()])).await?;
        self.tx
            .execute_raw(statement(
                "update agent_runs set prompt_snapshot=$2 where id=$1",
                vec![lease.run_id.into(), hash.into()],
            ))
            .await?;
        Ok(())
    }
    pub async fn record_interrupt_close(
        &self,
        space: SpaceId,
        run: &RunRow,
        outcome: &str,
    ) -> Result<(), DbErr> {
        self.assert_write();
        if let Some(interrupt) = &run.open_interrupt {
            self.tx.execute_raw(statement("with n as (update agent_runs set next_item_idx=next_item_idx+1 where id=$1 and space_id=$2 and member_id=$3 returning next_item_idx-1 idx) insert into agent_run_items(run_id,idx,kind,call_id,payload) select $1,idx,'interrupt_answer',$4,$5 from n",vec![run.id.into(),space.0.into(),self.chat_scope(space).0.into(),interrupt["call_id"].as_str().map(str::to_owned).into(),serde_json::json!({"interrupt_id":interrupt["id"],"outcome":outcome}).into()])).await?;
        }
        Ok(())
    }
}
impl SpaceTx {
    pub async fn reply_for_input(
        &self,
        space: SpaceId,
        input: Uuid,
    ) -> Result<Option<Uuid>, DbErr> {
        self.tx.query_one_raw(statement("select assistant_message_id from agent_runs where space_id=$1 and member_id=$2 and input_entry_id=$3 and retry_of_run_id is null",vec![space.0.into(),self.chat_scope(space).0.into(),input.into()])).await?.map(|r|r.try_get("","assistant_message_id")).transpose()
    }
    pub async fn require_chat_image(&self, space: SpaceId, image: &str) -> Result<(), DbErr> {
        if image.len() != 64
            || !image
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err(conflict("require_chat_image: invalid image hash"));
        }
        let row=self.tx.query_one_raw(statement("select b.sha256 from blobs b join blob_refs r on r.sha256=b.sha256 where b.sha256=decode($1,'hex') and r.space_id=$2 and r.module='chat' and r.uploaded_by_member_id=$3 and b.mime='image/jpeg'",vec![image.into(),space.0.into(),self.chat_scope(space).0.into()])).await?;
        if row.is_none() {
            return Err(conflict("require_chat_image: image unavailable"));
        }
        Ok(())
    }
    pub async fn seed_run_context(
        &self,
        space: SpaceId,
        run: Uuid,
        context: Value,
        input: Value,
        definitions: Value,
    ) -> Result<(), DbErr> {
        self.assert_write();
        let member = self.member(space);
        let permissions = serde_json::json!({"ledger":format!("{:?}",member.ledger_grant()),"documents":format!("{:?}",member.documents_grant())});
        for (idx, kind, payload) in [
            (
                1,
                "context",
                serde_json::json!({"space":context,"permissions":permissions,"definitions":definitions}),
            ),
            (2, "input", input),
        ] {
            self.tx.execute_raw(statement("insert into agent_run_items(run_id,idx,kind,payload) select r.id,$2,$3,$4 from agent_runs r where r.id=$1 and r.space_id=$5 and r.member_id=$6",vec![run.into(),idx.into(),kind.into(),payload.into(),space.0.into(),member.id().0.into()])).await?;
        }
        self.tx.execute_raw(statement("update agent_runs set next_item_idx=3 where id=$1 and space_id=$2 and member_id=$3",vec![run.into(),space.0.into(),member.id().0.into()])).await?;
        Ok(())
    }
}
pub struct RunNotifications(sqlx::postgres::PgListener);
impl RunNotifications {
    pub async fn connect(url: &str) -> Result<Self, sqlx::Error> {
        let mut listener = sqlx::postgres::PgListener::connect(url).await?;
        listener.listen("agent_runs").await?;
        Ok(Self(listener))
    }
    pub async fn recv(&mut self) -> Result<(), sqlx::Error> {
        self.0.recv().await.map(|_| ())
    }
}
impl AppDb {
    /// Internal worker identity; SpaceTx still checks current membership + epoch.
    /// This never authenticates a client or produces a bearer session.
    pub async fn runtime_principal(
        &self,
        user: UserId,
        run: Uuid,
    ) -> Result<crate::Principal, DbErr> {
        let tx = SystemTx::begin(self).await?;
        let row=tx.tx.query_one_raw(statement("select u.id,u.username,u.locale from users u join space_members m on m.user_id=u.id join agent_runs r on r.member_id=m.id and r.space_id=m.space_id where u.id=$1 and r.id=$2 and u.disabled_at is null",vec![user.0.into(),run.into()])).await?.ok_or_else(|| conflict("runtime_principal: user or run unavailable"))?;
        let principal = crate::Principal {
            user_id: user,
            via: crate::Via::Session {
                session_id: jiabu_domain::SessionId(run),
                kind: crate::auth::SessionKind::Full,
            },
            user: crate::auth::User {
                id: row.try_get("", "id")?,
                username: row.try_get("", "username")?,
                locale: row.try_get("", "locale")?,
            },
        };
        tx.commit().await?;
        Ok(principal)
    }
    pub async fn owned_running_messages(
        &self,
        owners: &[Uuid],
    ) -> Result<Vec<(SpaceId, UserId, Uuid)>, DbErr> {
        let tx = SystemTx::begin(self).await?;
        let rows=tx.tx.query_all_raw(statement("select r.space_id,m.user_id,r.assistant_message_id from agent_runs r join space_members m on m.id=r.member_id and m.space_id=r.space_id where r.status='running' and r.lease_owner=any($1::uuid[])",vec![format!("{{{}}}",owners.iter().map(Uuid::to_string).collect::<Vec<_>>().join(",")).into()])).await?;
        let result = rows
            .into_iter()
            .map(|r| {
                Ok((
                    SpaceId(r.try_get("", "space_id")?),
                    UserId(r.try_get("", "user_id")?),
                    r.try_get("", "assistant_message_id")?,
                ))
            })
            .collect();
        tx.commit().await?;
        result
    }
}
impl AppDb {
    pub async fn unavailable_run_messages(&self) -> Result<Vec<(RunRow, StoredMessage)>, DbErr> {
        let tx = SystemTx::begin(self).await?;
        let rows=tx.tx.query_all_raw(statement("select to_jsonb(r) data,c.message,c.last_seq,c.checkpoint_work_ms from agent_runs r join chat_entries c on c.id=r.assistant_message_id and c.space_id=r.space_id join space_members m on m.id=r.member_id and m.space_id=r.space_id join users u on u.id=m.user_id join spaces s on s.id=r.space_id where (r.status in ('queued','running','waiting_ai','paused') or (r.status='cancelled' and r.last_error='space_unavailable' and c.stream_status in ('streaming','paused'))) and (m.status<>'active' or m.join_epoch<>r.join_epoch or u.disabled_at is not null or s.deleted_at is not null)",vec![])).await?;
        let result = rows
            .into_iter()
            .map(|r| {
                Ok((
                    serde_json::from_value(r.try_get("", "data")?)
                        .map_err(|_| conflict("unavailable_run_messages: invalid run row"))?,
                    StoredMessage {
                        message: r.try_get("", "message")?,
                        last_seq: r.try_get("", "last_seq")?,
                        step_work_ms: serde_json::from_value(r.try_get("", "checkpoint_work_ms")?)
                            .map_err(|_| {
                                conflict("unavailable_run_messages: invalid checkpoint clocks")
                            })?,
                    },
                ))
            })
            .collect();
        tx.commit().await?;
        result
    }
    /// Membership revocation cannot enter SpaceTx as the departed member.
    /// This narrow maintenance operation rechecks revocation under the space
    /// lock and only permits terminal cancellation; it cannot execute tools.
    pub async fn cancel_unavailable_run(
        &self,
        run: &RunRow,
        expected: i32,
        message: Value,
        events: Vec<Value>,
    ) -> Result<bool, DbErr> {
        let mut tx = SystemTx::begin(self).await?;
        tx.lock_space(SpaceId(run.space_id)).await?;
        let row=tx.tx.query_one_raw(statement("select r.id from agent_runs r join space_members m on m.id=r.member_id and m.space_id=r.space_id join users u on u.id=m.user_id join spaces s on s.id=r.space_id where r.id=$1 and r.space_id=$2 and (r.status in ('queued','running','waiting_ai','paused') or (r.status='cancelled' and r.last_error='space_unavailable')) and (m.status<>'active' or m.join_epoch<>r.join_epoch or u.disabled_at is not null or s.deleted_at is not null) for update of r",vec![run.id.into(),run.space_id.into()])).await?;
        if row.is_none() {
            return Ok(false);
        }
        if message["id"] != run.assistant_message_id.to_string()
            || !matches!(message["status"].as_str(), Some("interrupted" | "error"))
        {
            return Err(conflict("cancel_unavailable_run: invalid terminal message"));
        }
        let n=tx.tx.execute_raw(statement("update chat_entries set message=$4,last_seq=$5,rev=1,stream_status=$6,fallback_text=$7,updated_at=now(),change_seq=nextval('change_seq') where id=$1 and space_id=$2 and last_seq=$3",vec![run.assistant_message_id.into(),run.space_id.into(),expected.into(),message.clone().into(),(expected+events.len() as i32).into(),message["status"].as_str().ok_or_else(|| conflict("cancel_unavailable_run: missing status"))?.into(),message["fallbackText"].as_str().unwrap_or_default().into()])).await?;
        if n.rows_affected() != 1 {
            return Err(conflict(
                "cancel_unavailable_run: checkpoint watermark mismatch",
            ));
        }
        for (offset, event) in events.into_iter().enumerate() {
            if event["seq"].as_i64() != Some(i64::from(expected) + offset as i64 + 1)
                || event["messageId"] != run.assistant_message_id.to_string()
            {
                return Err(conflict("cancel_unavailable_run: invalid event sequence"));
            }
            tx.tx.execute_raw(statement("insert into chat_stream_events(message_id,space_id,member_id,seq,event) values($1,$2,$3,$4,$5)",vec![run.assistant_message_id.into(),run.space_id.into(),run.member_id.into(),(expected+offset as i32+1).into(),event.into()])).await?;
        }
        tx.tx.execute_raw(statement("update agent_runs set status='cancelled',last_error='space_unavailable',open_interrupt=null,lease_epoch=lease_epoch+1,lease_owner=null,lease_until=null,ended_at=now(),updated_at=now() where id=$1 and space_id=$2",vec![run.id.into(),run.space_id.into()])).await?;
        tx.tx.execute_raw(statement("update agent_tool_calls set status='cancelled' where run_id=$1 and status in ('proposed','approved','awaiting_user','executing')",vec![run.id.into()])).await?;
        tx.commit().await?;
        Ok(true)
    }
    pub async fn finish_abandoned_run_calls(&self, run: Uuid) -> Result<(), DbErr> {
        let tx = SystemTx::begin(self).await?;
        tx.tx.execute_raw(statement("update ai_calls set outcome='failed',error_kind='interrupted',completed_at=now() where run_id=$1 and completed_at is null",vec![run.into()])).await?;
        tx.commit().await
    }
}
impl SpaceTx {
    pub async fn begin_model_call(&self, space: SpaceId, lease: RunLease) -> Result<(), DbErr> {
        self.guard_run(space, lease).await?;
        let n=self.tx.execute_raw(statement("update agent_runs set model_turns=model_turns+1 where id=$1 and space_id=$2 and model_turns<20",vec![lease.run_id.into(),space.0.into()])).await?;
        if n.rows_affected() != 1 {
            return Err(conflict("begin_model_call: model turn budget exhausted"));
        }
        Ok(())
    }
}
impl SpaceTx {
    pub async fn revise_final_chat_message(
        &self,
        space: SpaceId,
        id: Uuid,
        expected_rev: i32,
        message: Value,
    ) -> Result<(), DbErr> {
        self.assert_write();
        if expected_rev < 1
            || message["id"] != id.to_string()
            || message["rev"].as_i64() != Some(i64::from(expected_rev) + 1)
        {
            return Err(conflict("revise_final_chat_message: invalid revision"));
        }
        let n=self.tx.execute_raw(statement("update chat_entries set message=$5,rev=rev+1,fallback_text=$6,updated_at=now(),change_seq=nextval('change_seq') where id=$1 and space_id=$2 and member_id=$3 and rev=$4 and stream_status in ('complete','interrupted','error') and message->>'status'=$5::jsonb->>'status' and message->>'role'=$5::jsonb->>'role'",vec![id.into(),space.0.into(),self.chat_scope(space).0.into(),expected_rev.into(),message.clone().into(),message["fallbackText"].as_str().unwrap_or_default().into()])).await?;
        if n.rows_affected() != 1 {
            return Err(conflict(
                "revise_final_chat_message: message revision or status mismatch",
            ));
        }
        Ok(())
    }
}
impl AppDb {
    pub async fn runtime_call_kind(&self, run: Uuid) -> Result<String, DbErr> {
        let tx = SystemTx::begin(self).await?;
        let row=tx.tx.query_one_raw(statement("select case when not exists(select 1 from agent_run_items i where i.run_id=r.id and i.kind='model_turn') then case when retry_of_run_id is null then 'first' else 'retry' end when coalesce((select max(idx) from agent_run_items i where i.run_id=r.id and i.kind='interrupt_answer'),0)>coalesce((select max(idx) from agent_run_items i where i.run_id=r.id and i.kind='model_turn'),0) then 'resume' else 'continue' end kind from agent_runs r where r.id=$1",vec![run.into()])).await?.ok_or_else(|| conflict("runtime_call_kind: run missing"))?;
        let kind = row.try_get("", "kind")?;
        tx.commit().await?;
        Ok(kind)
    }
    pub async fn set_ai_prefix_hash(
        &self,
        id: i64,
        token: Uuid,
        hash: Vec<u8>,
    ) -> Result<(), DbErr> {
        let tx = SystemTx::begin(self).await?;
        tx.tx.execute_raw(statement("update ai_calls set prefix_hash=$3 where id=$1 and attempt_token=$2 and completed_at is null",vec![id.into(),token.into(),hash.into()])).await?;
        tx.commit().await
    }
}
