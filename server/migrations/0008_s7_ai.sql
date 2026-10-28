-- S7 PR 1: AI configuration, credential rotation and independent attempt meters.
-- No changes to run/chat state: those belong to 0009 (PR 2).
alter table ai_providers add column oauth_client_id text, add column oauth_expires_at bigint;
alter table secrets add column revision bigint not null default 1,
  add column usable boolean not null default true;
alter table ai_settings add column host_id uuid not null default uuidv7(),
  add column retry_initial_secs int not null default 5 check (retry_initial_secs > 0),
  add column retry_max_secs int not null default 60 check (retry_max_secs >= retry_initial_secs),
  add column waiting_timeout_secs int not null default 600 check (waiting_timeout_secs > 0);
insert into ai_settings(id,breaker) values(true,'{"failures":3,"cool_down_secs":60}') on conflict(id) do nothing;
alter table ai_calls add column completed_at timestamptz,
  add column attempt_token uuid;
create index ai_calls_unfinished on ai_calls(at) where completed_at is null and outcome='started';

-- Serialized version bump and transactional notification. Settings updates also
-- pass through this BEFORE trigger, including changes initiated by other triggers.
create function ai_settings_changed() returns trigger
language plpgsql set search_path = pg_catalog, public, pg_temp as $$
begin
 new.config_version := old.config_version + 1;
 perform pg_notify('ai_config', new.config_version::text);
 return new;
end $$;
revoke all on function ai_settings_changed() from public;
create trigger ai_settings_changed before update on ai_settings
for each row execute function ai_settings_changed();
create function ai_configuration_changed() returns trigger
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
begin
 update public.ai_settings set config_version=config_version+1 where id;
 return null;
end $$;
alter function ai_configuration_changed() owner to jiabu_owner;
revoke all on function ai_configuration_changed() from public;
create trigger ai_provider_changed after insert or update or delete on ai_providers
for each statement execute function ai_configuration_changed();
create trigger ai_model_changed after insert or update or delete on ai_models
for each statement execute function ai_configuration_changed();
create trigger ai_route_changed after insert or update or delete on ai_routes
for each statement execute function ai_configuration_changed();
create trigger ai_price_changed after insert on ai_prices
for each statement execute function ai_configuration_changed();
create trigger ai_secret_changed after insert or update or delete on secrets
for each statement execute function ai_configuration_changed();

-- Only an existing provider OAuth row may rotate. No insert, owner reassignment,
-- field reassignment, source changes, key deletion or general secret update grant.
create function ai_refresh_oauth(p_provider text, p_revision bigint, p_key_id text,
 p_nonce bytea, p_ciphertext bytea, p_expires_at bigint) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare changed int;
begin
 if p_nonce is null or p_ciphertext is null or p_key_id is null or p_expires_at is null or
    octet_length(p_nonce) <> 24 or octet_length(p_ciphertext) < 16 or p_key_id = '' then
  raise exception 'invalid encrypted credential' using errcode='22023';
 end if;
 perform 1 from public.ai_settings where id for update;
 update public.secrets s set key_id=p_key_id,nonce=p_nonce,ciphertext=p_ciphertext,
  revision=revision+1,usable=true,updated_at=now()
 where s.owner_kind='provider' and s.owner_id=p_provider and s.field='oauth'
  and s.revision=p_revision and s.usable and exists(
   select 1 from public.ai_providers p where p.id=p_provider and p.kind='siwc'
    and p.enabled and (p.secret_source is null or p.secret_source='db'));
 get diagnostics changed = row_count;
 if changed=1 then update public.ai_providers set oauth_expires_at=p_expires_at where id=p_provider; end if;
 return changed=1;
end $$;
alter function ai_refresh_oauth(text,bigint,text,bytea,bytea,bigint) owner to jiabu_owner;
revoke all on function ai_refresh_oauth(text,bigint,text,bytea,bytea,bigint) from public;
grant execute on function ai_refresh_oauth(text,bigint,text,bytea,bytea,bigint) to jiabu_app;
create function ai_invalidate_oauth(p_provider text,p_revision bigint) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare changed int;
begin
 perform 1 from public.ai_settings where id for update;
 update public.secrets set usable=false,revision=revision+1,updated_at=now()
 where owner_kind='provider' and owner_id=p_provider and field='oauth' and revision=p_revision;
 get diagnostics changed = row_count;
 return changed=1;
end $$;
alter function ai_invalidate_oauth(text,bigint) owner to jiabu_owner;
revoke all on function ai_invalidate_oauth(text,bigint) from public;
grant execute on function ai_invalidate_oauth(text,bigint) to jiabu_app;
