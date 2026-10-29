-- Producer clocks are private checkpoint state, never protocol metadata.
-- This is step timing only, not the removed crash-recovery active-time budget.
alter table chat_entries add column checkpoint_work_ms jsonb not null default '{}'::jsonb
  check (jsonb_typeof(checkpoint_work_ms) = 'object');
