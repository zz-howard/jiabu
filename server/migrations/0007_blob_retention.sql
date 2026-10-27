-- S4: exact last-reference retention (created_at is not a last-reference clock).
alter table blobs add column unreferenced_at timestamptz default clock_timestamp();
-- Existing orphans start a conservative one-day grace period at migration time.
update blobs b set unreferenced_at=null where exists(select 1 from blob_refs r where r.sha256=b.sha256);
create index blobs_unreferenced on blobs(unreferenced_at) where unreferenced_at is not null;
create index blob_refs_sha256 on blob_refs(sha256);

-- Distinct two-int advisory namespace, shared with db::blobs::lock_lifecycle.
-- Lock order: space advisory lock -> blob lifecycle advisory lock. Image decode,
-- resize and hashing NEVER run under either lifecycle critical section.
-- A BEFORE STATEMENT trigger takes this before row/FK locks (including purge).
create function jiabu_blob_refs_lock() returns trigger
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
begin
 perform pg_advisory_xact_lock(726401, 4);
 return null;
end $$;
alter function jiabu_blob_refs_lock() owner to jiabu_owner;
revoke all on function jiabu_blob_refs_lock() from public, jiabu_app, jiabu_admin;
create trigger blob_refs_lifecycle_lock before insert or update or delete on blob_refs
 for each statement execute function jiabu_blob_refs_lock();

-- Owner executes the global existence query: space RLS must not hide a reference
-- in a different space. This is a trigger, never a callable content-read API.
create function jiabu_blob_refs_retention() returns trigger
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare old_hash bytea; new_hash bytea; instant timestamptz;
begin
 instant := coalesce(nullif(current_setting('jiabu.task_now',true),'')::timestamptz, clock_timestamp());
 if TG_OP <> 'INSERT' then old_hash := OLD.sha256; end if;
 if TG_OP <> 'DELETE' then new_hash := NEW.sha256; end if;
 update public.blobs b set unreferenced_at = case
  when exists(select 1 from public.blob_refs r where r.sha256=b.sha256) then null
  else coalesce(b.unreferenced_at,instant) end
 where b.sha256=old_hash or b.sha256=new_hash;
 return null;
end $$;
alter function jiabu_blob_refs_retention() owner to jiabu_owner;
revoke all on function jiabu_blob_refs_retention() from public, jiabu_app, jiabu_admin;
create trigger blob_refs_retention after insert or update or delete on blob_refs
 for each row execute function jiabu_blob_refs_retention();
-- No content grants to jiabu_admin. Trigger EXECUTE is checked at creation time;
-- jiabu_app can mutate scoped references, but cannot directly invoke the functions.
