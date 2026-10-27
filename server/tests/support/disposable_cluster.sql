-- Test tooling sets fake passwords on the cluster-wide jiabu_* roles. It runs only when
-- this query returns true: the cluster carries the disposable-test marker database
-- (created by tool/dev-db.sh and CI, never by deployment), and no database other than
-- the tooling's own temporary ones belongs to a jiabu_* role (a real deployment's
-- application database is owned by jiabu_owner).
select exists (select 1 from pg_database where datname = 'jiabu_disposable_test_cluster')
   and not exists (
     select 1 from pg_database d join pg_roles r on r.oid = d.datdba
     where r.rolname like 'jiabu\_%'
       and d.datname not like 'jiabu\_test\_%'
       and d.datname not like 'jiabu\_entities\_%')
