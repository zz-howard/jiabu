-- Executed only by admin db init-roles on the provisioning connection.
select pg_advisory_xact_lock(726401989);
DO $$
declare r text;
begin
 foreach r in array array['jiabu_owner','jiabu_app','jiabu_admin'] loop
  if not exists(select 1 from pg_roles where rolname=r) then
   execute format('create role %I login nosuperuser nocreatedb nocreaterole noinherit nobypassrls',r);
  elsif exists(select 1 from pg_roles where rolname=r and (rolsuper or rolbypassrls or rolcreaterole or rolcreatedb)) then
   raise exception 'unsafe existing role %',r;
  end if;
 end loop;
 if pg_has_role('jiabu_app','jiabu_owner','MEMBER')
 or pg_has_role('jiabu_admin','jiabu_owner','MEMBER')
 or pg_has_role('jiabu_admin','jiabu_app','MEMBER')
 or pg_has_role('jiabu_app','jiabu_admin','MEMBER') then
  raise exception 'application and administration roles must not assume each other or owner';
 end if;
end $$;
grant usage, create on schema public to jiabu_owner;
