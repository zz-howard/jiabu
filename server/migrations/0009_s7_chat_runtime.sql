-- S7 PR 2. go2 supplement: crashes terminate; FIFO uses created_at, UUIDv7 id.
alter table agent_runs
  add column waiting_ai_since timestamptz,
  add column journal_compacted_at timestamptz;
alter table agent_runs drop constraint agent_runs_status_check;
alter table agent_runs add constraint agent_runs_status_check check (status in
  ('queued','running','paused','waiting_ai','completed','cancelled','expired','failed','interrupted'));
-- active_ms already exists in 0004; retained for compatibility, not a recovery checkpoint.
drop index agent_runs_conversation_fifo;
create index agent_runs_conversation_fifo on agent_runs (conversation_id, created_at, id)
  where status in ('queued','running','paused','waiting_ai');
create index agent_runs_waiting_timeout on agent_runs (waiting_ai_since)
  where status = 'waiting_ai';
create index agent_runs_retention on agent_runs (ended_at, id)
  where status in ('completed','cancelled','expired','failed','interrupted');
-- Existing receipts have no fingerprint. Later dispatch must reject, never replay, NULL.
alter table chat_actions add column request_fingerprint bytea
  check (request_fingerprint is null or octet_length(request_fingerprint) = 32);

-- No caller-controlled cutoff: an application role cannot erase fresh journals.
-- Terminal run locks serialize retention with explicit retry copying.
create function retain_agent_journals(p_limit int default 100) returns int
language plpgsql security definer
set search_path = pg_catalog, public, pg_temp as $$
declare r record; processed int := 0;
begin
 if p_limit is null or p_limit < 1 or p_limit > 1000 then
  raise exception 'invalid retention batch size' using errcode = '22023';
 end if;
 for r in
  select id, ended_at, journal_compacted_at from public.agent_runs ar
  where status in ('completed','cancelled','expired','failed','interrupted')
    and ended_at < now() - interval '7 days'
    and ((journal_compacted_at is null and ended_at < now() - interval '30 days')
      or exists (select 1 from public.agent_run_items i
                 where i.run_id=ar.id and i.provider_blob is not null))
  order by ended_at, id limit p_limit for update skip locked
 loop
  update public.agent_run_items set provider_blob=null where run_id=r.id and provider_blob is not null;
  if r.ended_at < now() - interval '30 days' and r.journal_compacted_at is null then
   -- Only non-content step metadata survives. history_item is the separate chat history.
   update public.agent_run_items i set payload=jsonb_strip_nulls(jsonb_build_object(
      'compacted',true,'tool',c.tool,'status',c.status)), provider_blob=null
    from (select i2.idx, tc.tool, tc.status from public.agent_run_items i2
      left join public.agent_tool_calls tc on tc.run_id=i2.run_id and tc.call_id=i2.call_id
      where i2.run_id=r.id) c
    where i.run_id=r.id and i.idx=c.idx;
   update public.agent_tool_calls set args='{}'::jsonb, guard=null, effect_ref=null
    where run_id=r.id;
   update public.agent_runs set journal_compacted_at=now() where id=r.id;
  end if;
  processed := processed + 1;
 end loop;
 return processed;
end $$;
alter function retain_agent_journals(int) owner to jiabu_owner;
revoke all on function retain_agent_journals(int) from public;
grant execute on function retain_agent_journals(int) to jiabu_app;
