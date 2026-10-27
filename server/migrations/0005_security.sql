-- Roles are cluster objects created by admin db init-roles, never by migrations.
revoke create on schema public from public;
grant usage on schema public to jiabu_app, jiabu_admin;
create function jiabu_allowed_spaces() returns uuid[] language sql stable
set search_path = pg_catalog, public, pg_temp as $$
 select coalesce(nullif(current_setting('jiabu.space_ids', true), '')::uuid[], '{}')
$$;
create function jiabu_system() returns boolean language sql stable
set search_path = pg_catalog, public, pg_temp as $$
 select coalesce(current_setting('jiabu.system', true), '') = 'on'
$$;
revoke all on function jiabu_allowed_spaces(), jiabu_system() from public;
grant execute on function jiabu_allowed_spaces(), jiabu_system() to jiabu_app;
DO $$
declare t text;
begin
 foreach t in array array['accounts','allocation_plans','tags','records','entity_events',
 'subjects','documents','blob_refs','conversations','chat_entries','chat_stream_events',
 'chat_actions','agent_runs'] loop
  execute format('alter table public.%I enable row level security', t);
  execute format('create policy space_scope on public.%I to jiabu_app using
   (space_id = any(public.jiabu_allowed_spaces()) or public.jiabu_system()) with check
   (space_id = any(public.jiabu_allowed_spaces()) or public.jiabu_system())', t);
 end loop;
end $$;
create policy admin_metadata on agent_runs for select to jiabu_admin using (true);

grant select, insert, update, delete on users, sessions, api_keys, idempotency,
 spaces, space_members, space_member_grants, space_invitations, accounts,
 allocation_plans, tags, records, subjects, documents, template_snapshots, blobs,
 blob_refs, conversations, chat_entries, chat_stream_events, agent_runs,
 agent_tool_calls, agent_prompt_snapshots to jiabu_app;
grant select, insert on entity_events, space_events, chat_actions, api_key_audit,
 agent_run_items to jiabu_app;
-- Journal retention will need a separate narrowly scoped function in S7.
grant select on ai_providers, ai_models, ai_routes, ai_settings, ai_prices, secrets,
 app_releases to jiabu_app;
grant select, insert, update on ai_calls, ai_step_meters to jiabu_app;
grant usage on sequence change_seq, entity_events_id_seq, space_events_id_seq,
 api_key_audit_id_seq, ai_calls_id_seq to jiabu_app;

grant select (id, username, must_change_password, admin_reset_at, disabled_at,
 password_changed_at, created_at), insert,
 update (password_hash, must_change_password, admin_reset_at,
 admin_reset_notice_pending, disabled_at, password_changed_at) on users to jiabu_admin;
grant select (id, user_id, kind, device_name, created_at, expires_at, last_seen_at),
 delete on sessions to jiabu_admin;
grant select (id, name, is_default, created_by_user_id, created_at, deleted_at),
 insert on spaces to jiabu_admin;
grant select (id, space_id, user_id, role, status, left_reason, joined_at, left_at),
 insert on space_members to jiabu_admin;
grant insert on space_member_grants to jiabu_admin;
grant select (id, user_id, name, display_prefix, scope, expires_at, created_at,
 last_used_at, revoked_at, revoked_by), update (revoked_at, revoked_by)
 on api_keys to jiabu_admin;
grant select (id, space_id, member_id, kind, status, provider_id, model,
 model_turns, active_ms, attempt, created_at, ended_at) on agent_runs to jiabu_admin;
grant select on ai_calls, ai_step_meters to jiabu_admin;
grant select, insert, update, delete on app_releases, ai_providers, ai_models,
 ai_routes, ai_settings, secrets, admin_tokens to jiabu_admin;
grant select, insert on ai_prices, admin_audit to jiabu_admin;
grant usage on sequence admin_audit_id_seq, change_seq to jiabu_admin;
-- Startup validates embedded migration checksums even when automatic migration is off.
grant select on _sqlx_migrations to jiabu_app, jiabu_admin;

-- Shared creation primitive; all identifiers/labels come from the caller's domain plan.
-- It never selects existing content. Inserting the space first prevents reuse of an ID.
create function initialize_space(p_space uuid, p_user uuid, p_name text,
 p_accent text, p_currency text, p_timezone text, p_default boolean,
 p_display_name text, p_presets jsonb) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare owner_member uuid; preset jsonb;
begin
 if p_presets is null or jsonb_typeof(p_presets) <> 'array' or jsonb_array_length(p_presets) <> 11 then
  raise exception 'invalid preset plan' using errcode = '22023';
 end if;
 if not exists (select 1 from pg_catalog.pg_timezone_names where name = p_timezone) then
  raise exception 'invalid timezone' using errcode = '22023';
 end if;
 if p_currency not in ('CNY','HKD','USD','EUR','GBP','JPY') then
  raise exception 'invalid currency' using errcode = '22023';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_space::text, 0));
 insert into public.spaces(id,name,accent_color,currency,timezone,is_default,
  created_by_user_id,change_seq)
 values(p_space,p_name,p_accent,p_currency,p_timezone,p_default,p_user,nextval('public.change_seq'));
 insert into public.space_members(space_id,user_id,display_name,role,status,joined_at,change_seq)
 values(p_space,p_user,p_display_name,'owner','active',now(),nextval('public.change_seq'))
 returning id into owner_member;
 insert into public.space_member_grants(member_id,module,level,change_seq) values
 (owner_member,'ledger','manage',nextval('public.change_seq')),
 (owner_member,'documents','manage',nextval('public.change_seq'));
 for preset in select value from jsonb_array_elements(p_presets) loop
  if preset->>'preset_key' is null or preset->>'id' is null then
   raise exception 'invalid preset plan' using errcode = '22023';
  end if;
  insert into public.tags(id,space_id,preset_key,change_seq)
  values((preset->>'id')::uuid,p_space,preset->>'preset_key',nextval('public.change_seq'));
 end loop;
 return owner_member;
end $$;
alter function initialize_space(uuid,uuid,text,text,text,text,boolean,text,jsonb) owner to jiabu_owner;
revoke all on function initialize_space(uuid,uuid,text,text,text,text,boolean,text,jsonb) from public;
grant execute on function initialize_space(uuid,uuid,text,text,text,text,boolean,text,jsonb)
 to jiabu_app, jiabu_admin;

create function purge_space(p_space uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(p_space::text, 0));
 if not exists(select 1 from public.spaces where id=p_space and deleted_at is not null) then
  raise exception 'space is not deleted' using errcode = '22023';
 end if;
 delete from public.agent_run_items where run_id in (select id from public.agent_runs where space_id=p_space);
 delete from public.agent_tool_calls where run_id in (select id from public.agent_runs where space_id=p_space);
 delete from public.ai_step_meters where run_id in (select id from public.agent_runs where space_id=p_space);
 -- All same-space self references disappear in this one statement.
 delete from public.agent_runs where space_id=p_space;
 delete from public.chat_actions where space_id=p_space;
 delete from public.chat_stream_events where space_id=p_space;
 delete from public.chat_entries where space_id=p_space;
 delete from public.conversations where space_id=p_space;
 delete from public.entity_events where space_id=p_space;
 delete from public.blob_refs where space_id=p_space;
 delete from public.records where space_id=p_space;
 delete from public.allocation_plans where space_id=p_space;
 delete from public.accounts where space_id=p_space;
 delete from public.tags where space_id=p_space;
 delete from public.documents where space_id=p_space;
 delete from public.subjects where space_id=p_space;
 delete from public.space_invitations where space_id=p_space;
 delete from public.space_events where space_id=p_space;
 delete from public.api_key_audit where space_id=p_space;
 -- Grants are authorization metadata on the retained member rows.
 delete from public.space_member_grants where member_id in
  (select id from public.space_members where space_id=p_space);
end $$;
alter function purge_space(uuid) owner to jiabu_owner;
revoke all on function purge_space(uuid) from public;
grant execute on function purge_space(uuid) to jiabu_app;
