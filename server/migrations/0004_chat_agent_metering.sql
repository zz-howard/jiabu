-- S1: append migrations after release; never edit an applied migration.

create table conversations (
  id uuid primary key default uuidv7(),
  space_id uuid not null references spaces,
  member_id uuid not null references space_members,
  created_at timestamptz not null default now(),
  change_seq bigint not null,
  unique (space_id, member_id));

create table chat_entries (id uuid primary key, space_id uuid not null references spaces,
  member_id uuid not null references space_members,
  conversation_id uuid not null references conversations, role text not null check (role in ('user','assistant','system')),
  reply_to_id uuid,
  agent_run_id uuid,
  protocol_version text not null,
  message jsonb not null,
  fallback_text text not null,
  stream_status text not null check (stream_status in ('streaming','paused','complete','interrupted','error')),
  rev int not null default 0,
  last_seq int not null default 0,
  change_seq bigint not null, created_at timestamptz not null, updated_at timestamptz not null);

create table chat_stream_events (message_id uuid not null, seq int not null,
  space_id uuid not null, member_id uuid not null,
  event jsonb not null, created_at timestamptz not null default now(),
  primary key (message_id, seq));

create table chat_actions (id uuid primary key,
  space_id uuid not null, member_id uuid not null, message_id uuid not null, block_id text not null,
  action_type text not null, target text not null, payload jsonb not null,
  status text not null, result jsonb not null,
  actor_member_id uuid not null references space_members, request_id uuid,
  created_at timestamptz not null default now());

create table agent_prompt_snapshots (
  hash bytea primary key,
  agent_def_version text not null, provider_kind text not null, model text not null,
  instructions text not null, tools jsonb not null,
  settings jsonb not null,
  created_at timestamptz not null default now()
);

create table agent_runs (
  id uuid primary key default uuidv7(),
  space_id uuid not null, member_id uuid not null,
  conversation_id uuid not null,
  assistant_message_id uuid not null,
  input_entry_id uuid not null,
  join_epoch int not null,
  retry_of_run_id uuid references agent_runs,
  kind text not null check (kind = 'chat'),
  status text not null check (status in
    ('queued','running','paused','waiting_ai','completed','cancelled','expired','failed')),
  agent_def_version text not null,
  prompt_snapshot bytea not null,
  journal_schema smallint not null default 1,
  provider_id text, model text,

  run_after timestamptz not null default now(),
  lease_owner uuid, lease_until timestamptz,
  lease_epoch bigint not null default 0,
  attempt int not null default 0,

  open_interrupt jsonb,
  cancel_requested boolean not null default false,

  model_turns int not null default 0,
  active_ms bigint not null default 0,
  next_item_idx int not null default 1,
  history_item jsonb,
  last_error text, origin_request_id uuid, client_capabilities jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  ended_at timestamptz
);
create unique index one_active_run_per_conversation on agent_runs (conversation_id)
  where status in ('running','paused');
create index agent_runs_conversation_fifo on agent_runs (conversation_id, created_at)
  where status in ('queued','running','paused','waiting_ai');
create unique index one_retry_per_run on agent_runs (retry_of_run_id) where retry_of_run_id is not null;
create index agent_runs_ready on agent_runs (run_after) where status in ('queued','waiting_ai');
create index agent_runs_lease on agent_runs (lease_until) where status = 'running';
-- expires_at uses canonical UTC RFC3339 text (YYYY-MM-DDTHH:MM:SS.ffffffZ).
create index agent_runs_expiry on agent_runs ((open_interrupt->>'expires_at')) where status = 'paused';

create table agent_run_items (
  run_id uuid not null references agent_runs, idx int not null,
  kind text not null check (kind in (
    'context',
    'input',
    'model_turn',
    'tool_result',
    'interrupt',
    'interrupt_answer',
    'note')),
  call_id text,
  payload jsonb not null,
  provider_blob jsonb,
  schema_version smallint not null default 1,
  created_at timestamptz not null default now(),
  primary key (run_id, idx)
);
create unique index one_result_per_call on agent_run_items (run_id, call_id) where kind = 'tool_result';

create table agent_tool_calls (
  run_id uuid not null references agent_runs, call_id text not null,
  tool text not null, tool_schema_version int not null,
  args jsonb not null, args_hash bytea not null,
  effect text not null check (effect in ('read','local_write')),
  status text not null check (status in
    ('proposed','awaiting_user','approved','rejected','expired','executing','succeeded','failed','cancelled')),
  idempotency_key uuid not null,
  guard jsonb,
  effect_ref jsonb,
  attempts int not null default 0, updated_at timestamptz not null default now(),
  primary key (run_id, call_id)
);

create table ai_calls (
  id bigint generated always as identity primary key,
  run_id uuid,
  space_id uuid, member_id uuid, user_id uuid,
  task_kind text not null check (task_kind in ('chat','chat_vision','probe')),
  provider_id text not null, model text not null,
  structured_mode text not null, latency_ms int, input_tokens int, output_tokens int,
  cached_input_tokens int, cache_write_tokens int,
  call_kind text not null check (call_kind in ('first','continue','resume','retry')),
  since_prev_call_ms bigint, prefix_hash bytea,
  cache_miss_reason text,
  cost_usd numeric(12,6), price_id uuid, price_as_of date,
  cache_saving_usd numeric(12,6),
  outcome text not null, error_kind text, at timestamptz not null default now()
);
create index ai_calls_at on ai_calls (at);
create index ai_calls_space_at on ai_calls (space_id, at);

create table ai_step_meters (
  run_id uuid not null, step_no int not null,
  step_kind text not null,

  status text not null check (status in ('succeeded','failed','awaiting_user','cancelled')),
  started_at timestamptz not null, duration_ms int,
  primary key (run_id, step_no)
);

create index conversations_sync on conversations (space_id, change_seq);
create index chat_entries_sync on chat_entries (space_id, change_seq);
create index chat_stream_events_created on chat_stream_events (created_at);
create index agent_run_items_created on agent_run_items (created_at);
