use super::{AppDb, Mode, SpaceTx, support};
use crate::ledger::{AuditCtx, Clock, run_allocations};
use anyhow::{Result, ensure};
use chrono::{DateTime, Utc};
use jiabu_domain::{JoinEpoch, SpaceId, UserId, ledger::*};
use serde_json::{Value, json};
use sqlx::Row;
use uuid::Uuid;

#[derive(Clone)]
struct Fixed(DateTime<Utc>);
impl Clock for Fixed {
    fn now(&self) -> DateTime<Utc> {
        self.0
    }
}
fn at(s: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(s).unwrap().with_timezone(&Utc)
}
fn parse<T: serde::de::DeserializeOwned>(value: Value) -> Result<T> {
    Ok(serde_json::from_value(value)?)
}
struct LedgerDb {
    fixture: support::TestDb,
    db: AppDb,
    space: SpaceId,
    user: UserId,
    real: Uuid,
    purpose: Uuid,
}
impl LedgerDb {
    async fn new() -> Result<Self> {
        let fixture = support::TestDb::new().await?;
        let seed = fixture.seed("sample", "unused-test-hash").await?;
        let db = AppDb::connect(&fixture.app_url).await?;
        let this = Self {
            fixture,
            db,
            space: seed.space_id,
            user: seed.user_id,
            real: Uuid::now_v7(),
            purpose: Uuid::now_v7(),
        };
        let tx = this.tx().await?;
        let audit = this.audit(&tx, at("2026-01-01T00:00:00Z"));
        for (id, kind, name) in [
            (this.real, "real", "示例银行卡"),
            (this.purpose, "purpose", "示例用途"),
        ] {
            tx.ledger_create_account(
                this.space,
                id,
                parse(json!({"kind":kind,"name":name,"opening_on":"2026-01-01"}))?,
                &audit,
            )
            .await?;
        }
        tx.commit().await?;
        Ok(this)
    }
    async fn tx(&self) -> Result<SpaceTx> {
        Ok(SpaceTx::begin(
            &self.db,
            self.user,
            &[(self.space, Some(JoinEpoch(1)))],
            Mode::Write,
        )
        .await?)
    }
    fn audit(&self, tx: &SpaceTx, now: DateTime<Utc>) -> AuditCtx {
        AuditCtx {
            actor_member_id: Some(tx.member(self.space).id().0),
            run_id: None,
            request_id: Some(Uuid::now_v7()),
            via_api_key_id: None,
            via_api_key_name: None,
            now,
            origin: "api",
        }
    }
    async fn plan(
        &self,
        now: &str,
        day: i16,
        amount: i64,
        enabled: bool,
        version: Option<i32>,
    ) -> Result<AllocationPlan> {
        let tx = self.tx().await?;
        let value = tx
            .ledger_set_plan(
                self.space,
                SetAllocationPlan {
                    account_id: self.purpose,
                    expected_version: version,
                    amount_minor: amount,
                    day_of_month: day,
                    enabled,
                },
                &self.audit(&tx, at(now)),
            )
            .await?;
        tx.commit().await?;
        Ok(value)
    }
    async fn run(&self, now: &str) -> Result<u64> {
        let report = run_allocations(&self.db, &Fixed(at(now))).await?;
        ensure!(report.failed_spaces == 0, "allocation failed");
        Ok(report.inserted)
    }
}
#[tokio::test]
async fn allocation_starts_after_setup_catches_each_month_and_never_repeats_voided_month()
-> Result<()> {
    let h = LedgerDb::new().await?;
    let plan = h.plan("2026-03-15T00:00:00Z", 15, 100, true, None).await?;
    assert_eq!(plan.next_run_on.to_string(), "2026-04-15");
    assert_eq!(h.run("2026-03-16T00:00:00Z").await?, 0);
    assert_eq!(h.run("2026-07-16T00:00:00Z").await?, 4);
    assert_eq!(h.run("2026-07-16T00:00:00Z").await?, 0);
    let owner = h.fixture.owner().await?;
    let records:Vec<(Uuid,String,i64)>=sqlx::query("select id,to_char(occurred_on,'YYYY-MM'),amount_minor from records where space_id=$1 order by occurred_on").bind(h.space.0).fetch_all(&owner).await?.iter().map(|r|Ok((r.try_get(0)?,r.try_get(1)?,r.try_get(2)?))).collect::<Result<_>>()?;
    assert_eq!(records.len(), 4);
    for (index, (id, month, amount)) in records.iter().enumerate() {
        assert_eq!(*id, Uuid::new_v5(&h.purpose, month.as_bytes()));
        assert_eq!(*amount, 100);
        assert_eq!(month, &format!("2026-{:02}", index + 4));
    }
    let tx = h.tx().await?;
    let balance = tx
        .ledger_balance(
            h.space,
            QueryBalance {
                account_id: Some(h.purpose),
            },
        )
        .await?;
    assert_eq!(balance.balances[0].balance_minor, 400);
    let real = tx
        .ledger_balance(
            h.space,
            QueryBalance {
                account_id: Some(h.real),
            },
        )
        .await?;
    assert_eq!(real.balances[0].balance_minor, 0);
    tx.ledger_record_status(
        h.space,
        VersionedRecord {
            id: records[3].0,
            expected_version: 1,
        },
        false,
        &h.audit(&tx, at("2026-07-16T00:00:00Z")),
    )
    .await?;
    tx.commit().await?;
    assert_eq!(h.run("2026-07-17T00:00:00Z").await?, 0);
    let actor_count:i64=sqlx::query_scalar("select count(*) from entity_events where actor_member_id is not null and entity_kind='record' and kind='create'").fetch_one(&owner).await?;
    assert_eq!(actor_count, 0);
    let metadata_ok:bool=sqlx::query_scalar("select bool_and(created_by_member_id is null and (status='voided' or updated_by_member_id is null) and run_id is null and origin='allocation') from records").fetch_one(&owner).await?;
    assert!(metadata_ok);
    let unique:bool=sqlx::query_scalar("select count(*)=count(distinct change_seq) from (select change_seq from accounts union all select change_seq from allocation_plans union all select change_seq from records union all select change_seq from tags union all select change_seq from entity_events) x").fetch_one(&owner).await?;
    assert!(unique);
    owner.close().await;
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn allocation_small_months_29_30_31_leap_year_and_same_month_last_run() -> Result<()> {
    let h = LedgerDb::new().await?;
    for day in 29..=31 {
        // Reset only test data between independent calendar cases.
        let owner = h.fixture.owner().await?;
        sqlx::query("delete from records").execute(&owner).await?;
        sqlx::query("delete from allocation_plans")
            .execute(&owner)
            .await?;
        let plan = h.plan("2024-01-31T00:00:00Z", day, 10, true, None).await?;
        assert_eq!(plan.next_run_on.to_string(), "2024-02-29");
        assert_eq!(h.run("2024-02-28T00:00:00Z").await?, 0);
        assert_eq!(h.run("2024-02-29T00:00:00Z").await?, 1);
        let current: Value = sqlx::query_scalar("select to_jsonb(p) from allocation_plans p")
            .fetch_one(&owner)
            .await?;
        // Changing day after February already ran must not allocate February twice.
        let modified = h
            .plan(
                "2024-02-29T01:00:00Z",
                29,
                20,
                true,
                Some(current["version"].as_i64().unwrap() as i32),
            )
            .await?;
        assert_eq!(modified.next_run_on.to_string(), "2024-03-29");
        assert_eq!(h.run("2024-03-29T00:00:00Z").await?, 1);
        owner.close().await;
    }
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn allocation_uses_space_timezone_not_server_date_and_serializes_concurrent_scans()
-> Result<()> {
    let h = LedgerDb::new().await?;
    let owner = h.fixture.owner().await?;
    sqlx::query("update spaces set timezone='Pacific/Kiritimati' where id=$1")
        .bind(h.space.0)
        .execute(&owner)
        .await?;
    h.plan("2026-02-20T00:00:00Z", 1, 10, true, None).await?;
    let clock = Fixed(at("2026-02-28T10:00:00Z")); // March 1 locally, still February UTC.
    let barrier = std::sync::Arc::new(tokio::sync::Barrier::new(3));
    let mut jobs = Vec::new();
    for _ in 0..2 {
        let db = h.db.clone();
        let clock = clock.clone();
        let barrier = barrier.clone();
        jobs.push(tokio::spawn(async move {
            barrier.wait().await;
            run_allocations(&db, &clock).await
        }));
    }
    barrier.wait().await;
    let mut inserted = 0;
    for job in jobs {
        let report = tokio::time::timeout(std::time::Duration::from_secs(10), job).await???;
        assert_eq!(report.failed_spaces, 0);
        inserted += report.inserted;
    }
    assert_eq!(inserted, 1);
    // West of UTC the same instant has not yet reached the local due date.
    sqlx::query("delete from records").execute(&owner).await?;
    sqlx::query("delete from allocation_plans")
        .execute(&owner)
        .await?;
    sqlx::query("update spaces set timezone='Pacific/Honolulu' where id=$1")
        .bind(h.space.0)
        .execute(&owner)
        .await?;
    h.plan("2026-02-20T00:00:00Z", 1, 10, true, None).await?;
    assert_eq!(h.run("2026-03-01T00:30:00Z").await?, 0);
    assert_eq!(h.run("2026-03-01T10:00:00Z").await?, 1);
    owner.close().await;
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn plan_changes_catch_old_due_months_before_new_settings_disable_does_not_catch_up()
-> Result<()> {
    let h = LedgerDb::new().await?;
    h.plan("2026-01-10T00:00:00Z", 15, 100, true, None).await?;
    let changed = h
        .plan("2026-04-20T00:00:00Z", 20, 200, true, Some(1))
        .await?;
    assert_eq!(changed.next_run_on.to_string(), "2026-05-20");
    assert_eq!(changed.last_run_month.as_deref(), Some("2026-04"));
    let owner = h.fixture.owner().await?;
    let old_amounts: Vec<i64> =
        sqlx::query_scalar("select amount_minor from records order by occurred_on")
            .fetch_all(&owner)
            .await?;
    assert_eq!(old_amounts, vec![100; 4]);
    assert_eq!(h.run("2026-05-20T00:00:00Z").await?, 1);
    let version: i32 = sqlx::query_scalar("select version from allocation_plans")
        .fetch_one(&owner)
        .await?;
    let disabled = h
        .plan("2026-07-21T00:00:00Z", 20, 300, false, Some(version))
        .await?;
    assert_eq!(h.run("2026-08-21T00:00:00Z").await?, 0);
    let count: i64 = sqlx::query_scalar("select count(*) from records")
        .fetch_one(&owner)
        .await?;
    assert_eq!(count, 5);
    let enabled = h
        .plan(
            "2026-09-21T00:00:00Z",
            25,
            400,
            true,
            Some(disabled.version),
        )
        .await?;
    assert_eq!(enabled.next_run_on.to_string(), "2026-09-25");
    assert_eq!(enabled.last_run_month.as_deref(), Some("2026-05"));
    let catchup: Vec<i64> = sqlx::query_scalar(
        "select amount_minor from records where occurred_on>='2026-08-01' order by occurred_on",
    )
    .fetch_all(&owner)
    .await?;
    assert!(
        catchup.is_empty(),
        "disabled months must never be allocated"
    );
    assert_eq!(h.run("2026-09-25T00:00:00Z").await?, 1);
    let resumed_amount: i64 =
        sqlx::query_scalar("select amount_minor from records where occurred_on='2026-09-25'")
            .fetch_one(&owner)
            .await?;
    assert_eq!(resumed_amount, 400);
    let system_actor:bool=sqlx::query_scalar("select bool_and(actor_member_id is null and via_api_key_id is null and via_api_key_name is null and run_id is null) from entity_events where entity_kind='record' and kind='create'").fetch_one(&owner).await?;
    assert!(system_actor);
    owner.close().await;
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn scoped_reads_keep_explicit_space_even_if_rls_allows_both_spaces() -> Result<()> {
    let h = LedgerDb::new().await?;
    let other = h.fixture.seed("other", "unused").await?;
    let owner = h.fixture.owner().await?;
    sqlx::query("insert into space_members(space_id,user_id,display_name,role,status,joined_at,change_seq) values($1,$2,'示例成员','member','active',now(),nextval('change_seq'))").bind(other.space_id.0).bind(h.user.0).execute(&owner).await?;
    let tx = SpaceTx::begin(
        &h.db,
        h.user,
        &[(h.space, None), (other.space_id, None)],
        Mode::Read,
    )
    .await?;
    // Both spaces are permitted by RLS. A missing space predicate now leaks data.
    let error = tx
        .ledger_snapshot(other.space_id, crate::ledger::Entity::Account, h.real)
        .await
        .err()
        .ok_or_else(|| anyhow::anyhow!("foreign account leaked"))?;
    assert_eq!(error.code, "not_found");
    tx.commit().await?;
    owner.close().await;
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn concurrent_refunds_preserve_limit_with_a_deterministic_read_barrier() -> Result<()> {
    tokio::time::timeout(std::time::Duration::from_secs(20),async {
        let h=LedgerDb::new().await?;let tx=h.tx().await?;let parent=Uuid::now_v7();
        tx.ledger_create_record(h.space,parent,parse(json!({"kind":"expense","amount_minor":100,"occurred_on":"2026-01-01","account_id":h.real,"purpose_id":h.purpose}))?,&h.audit(&tx,at("2026-01-01T00:00:00Z"))).await?;tx.commit().await?;
        let entered=std::sync::Arc::new(tokio::sync::Notify::new());let release=std::sync::Arc::new(tokio::sync::Notify::new());
        let mut first_tx=h.tx().await?;first_tx.refund_gate=Some((entered.clone(),release.clone()));
        let first_args:CreateRecord=parse(json!({"kind":"refund","amount_minor":60,"occurred_on":"2026-01-01","refund_of_id":parent}))?;
        let second_args=first_args.clone();let space=h.space;let user=h.user;
        let audit=h.audit(&first_tx,at("2026-01-01T00:00:00Z"));let audit2=audit.clone();
        let first=tokio::spawn(async move {
            let result=first_tx.ledger_create_record(space,Uuid::now_v7(),first_args,&audit).await;
            match result {Ok(_)=>first_tx.commit().await.map_err(crate::OperationError::from),Err(error)=>Err(error)}
        });
        entered.notified().await; // First refund has read the old active sum.
        let db=h.db.clone();
        let mut second=tokio::spawn(async move {
            let tx=SpaceTx::begin(&db,user,&[(space,Some(JoinEpoch(1)))],Mode::Write).await?;
            tx.ledger_create_record(space,Uuid::now_v7(),second_args,&audit2).await?;tx.commit().await?;
            Ok::<_,crate::OperationError>(())
        });
        let owner=h.fixture.owner().await?;let mut interval=tokio::time::interval(std::time::Duration::from_millis(10));
        let mut completed_second=None;
        loop {
            tokio::select! {
                result=&mut second=>{completed_second=Some(result?);break;},
                _=interval.tick()=>{
                    let waiting:bool=sqlx::query_scalar("select exists(select 1 from pg_locks where database=(select oid from pg_database where datname=current_database()) and locktype='advisory' and not granted)").fetch_one(&owner).await?;
                    if waiting {break;}
                }
            }
        }
        // Correct code: second is waiting on the space lock. Negative control with
        // the lock removed: second has already committed while first retains sum=0.
        release.notify_one();
        let first=first.await?;let second=match completed_second {Some(result)=>result,None=>second.await?};
        assert_eq!(usize::from(first.is_ok())+usize::from(second.is_ok()),1);
        let error=first.err().or_else(||second.err()).ok_or_else(||anyhow::anyhow!("no rejected refund"))?;assert_eq!(error.code,"refund_exceeds_original");
        let sum:i64=sqlx::query_scalar("select sum(amount_minor)::bigint from records where kind='refund' and status='active'").fetch_one(&owner).await?;assert_eq!(sum,60);
        owner.close().await;h.db.close().await?;Ok::<_,anyhow::Error>(())
    }).await??;
    Ok(())
}
#[tokio::test]
async fn allocation_conflict_is_noop_archive_disables_plan_and_rollback_leaves_no_audit()
-> Result<()> {
    let h = LedgerDb::new().await?;
    let plan = h.plan("2026-01-01T00:00:00Z", 15, 100, true, None).await?;
    let tx = h.tx().await?;
    let archived = tx
        .ledger_archive_account(
            h.space,
            ArchiveAccount {
                id: h.purpose,
                expected_version: 1,
            },
            &h.audit(&tx, at("2026-01-02T00:00:00Z")),
        )
        .await?;
    assert!(archived.archived_at.is_some());
    tx.commit().await?;
    assert_eq!(h.run("2026-02-20T00:00:00Z").await?, 0);
    let owner = h.fixture.owner().await?;
    let enabled: bool = sqlx::query_scalar("select enabled from allocation_plans")
        .fetch_one(&owner)
        .await?;
    assert!(!enabled);
    let plan_events: i64 = sqlx::query_scalar(
        "select count(*) from entity_events where entity_kind='allocation_plan'",
    )
    .fetch_one(&owner)
    .await?;
    assert_eq!(plan_events, 2);
    // Only a fixture repair: recreate an eligible due state to exercise the
    // deterministic record-ID conflict path independently of last_run_month.
    sqlx::query("update accounts set archived_at=null where id=$1")
        .bind(h.purpose)
        .execute(&owner)
        .await?;
    sqlx::query("update allocation_plans set enabled=true,next_run_on=$1,last_run_month=null")
        .bind(plan.next_run_on)
        .execute(&owner)
        .await?;
    assert_eq!(h.run("2026-01-15T00:00:00Z").await?, 1);
    sqlx::query("update allocation_plans set next_run_on=$1,last_run_month=null")
        .bind(plan.next_run_on)
        .execute(&owner)
        .await?;
    assert_eq!(h.run("2026-01-15T00:00:00Z").await?, 0);
    let count: i64 = sqlx::query_scalar(
        "select count(*) from entity_events where entity_kind='record' and kind='create'",
    )
    .fetch_one(&owner)
    .await?;
    assert_eq!(count, 1);
    let tx = h.tx().await?;
    let transient = Uuid::now_v7();
    tx.ledger_create_tag(
        h.space,
        transient,
        CreateTag {
            id: Some(transient),
            name: "示例回滚标签".into(),
        },
        &h.audit(&tx, at("2026-01-16T00:00:00Z")),
    )
    .await?;
    tx.rollback().await?;
    let left:i64=sqlx::query_scalar("select (select count(*) from tags where id=$1)+(select count(*) from entity_events where entity_id=$1)").bind(transient).fetch_one(&owner).await?;
    assert_eq!(left, 0);
    // Application role really cannot alter append-only audit rows.
    let tx = h.tx().await?;
    use sea_orm::ConnectionTrait;
    assert!(
        tx.tx
            .execute_raw(sea_orm::Statement::from_string(
                sea_orm::DbBackend::Postgres,
                "delete from entity_events".to_owned()
            ))
            .await
            .is_err()
    );
    tx.rollback().await?;
    owner.close().await;
    h.db.close().await?;
    Ok(())
}

#[tokio::test]
async fn reenable_skips_disabled_months_and_past_or_same_day_in_resume_month() -> Result<()> {
    let h = LedgerDb::new().await?;
    let owner = h.fixture.owner().await?;
    for day in [15, 20] {
        sqlx::query("delete from records").execute(&owner).await?;
        sqlx::query("delete from allocation_plans")
            .execute(&owner)
            .await?;
        h.plan("2026-09-01T00:00:00Z", 25, 100, true, None).await?;
        assert_eq!(h.run("2026-09-25T00:00:00Z").await?, 1);
        let version: i32 = sqlx::query_scalar("select version from allocation_plans")
            .fetch_one(&owner)
            .await?;
        let disabled = h
            .plan("2026-09-26T00:00:00Z", 25, 300, false, Some(version))
            .await?;
        assert_eq!(h.run("2026-12-01T00:00:00Z").await?, 0);
        let resumed = h
            .plan(
                "2027-01-20T00:00:00Z",
                day,
                400,
                true,
                Some(disabled.version),
            )
            .await?;
        assert_eq!(resumed.next_run_on.to_string(), format!("2027-02-{day:02}"));
        assert_eq!(resumed.last_run_month.as_deref(), Some("2026-09"));
        let count: i64 = sqlx::query_scalar("select count(*) from records")
            .fetch_one(&owner)
            .await?;
        assert_eq!(count, 1);
        assert_eq!(h.run("2027-01-21T00:00:00Z").await?, 0);
        let due = format!("2027-02-{day:02}T00:00:00Z");
        assert_eq!(h.run(&due).await?, 1);
        let amounts: Vec<i64> =
            sqlx::query_scalar("select amount_minor from records order by occurred_on")
                .fetch_all(&owner)
                .await?;
        assert_eq!(amounts, vec![100, 400]);
    }
    owner.close().await;
    h.db.close().await?;
    Ok(())
}

#[tokio::test]
async fn enabled_day_changes_allocate_unpaid_month_once_using_due_settings() -> Result<()> {
    let h = LedgerDb::new().await?;
    let owner = h.fixture.owner().await?;
    for (old_day, new_day, next, immediate_amount) in [
        (25, 15, "2026-11-15", Some(200_i64)),
        (25, 20, "2026-11-20", Some(200)),
        (25, 22, "2026-10-22", None),
        (15, 10, "2026-11-10", Some(100)),
    ] {
        sqlx::query("delete from records").execute(&owner).await?;
        sqlx::query("delete from allocation_plans")
            .execute(&owner)
            .await?;
        h.plan("2026-09-01T00:00:00Z", old_day, 100, true, None)
            .await?;
        let september = format!("2026-09-{old_day:02}T00:00:00Z");
        assert_eq!(h.run(&september).await?, 1);
        let version: i32 = sqlx::query_scalar("select version from allocation_plans")
            .fetch_one(&owner)
            .await?;
        let changed = h
            .plan("2026-10-20T00:00:00Z", new_day, 200, true, Some(version))
            .await?;
        assert_eq!(changed.next_run_on.to_string(), next);
        let amounts: Vec<i64> = sqlx::query_scalar("select amount_minor from records where occurred_on between '2026-10-01' and '2026-10-31'")
            .fetch_all(&owner).await?;
        assert_eq!(amounts, immediate_amount.into_iter().collect::<Vec<_>>());
        assert_eq!(h.run("2026-10-20T00:00:00Z").await?, 0);
        if immediate_amount.is_none() {
            let due = format!("2026-10-{new_day:02}T00:00:00Z");
            assert_eq!(h.run(&due).await?, 1);
        }
        let version: i32 = sqlx::query_scalar("select version from allocation_plans")
            .fetch_one(&owner)
            .await?;
        let edited_again = h
            .plan("2026-10-28T00:00:00Z", 5, 300, true, Some(version))
            .await?;
        assert_eq!(edited_again.next_run_on.to_string(), "2026-11-05");
        assert_eq!(h.run("2026-10-31T00:00:00Z").await?, 0);
        let rows = sqlx::query("select id,amount_minor,created_by_member_id from records where occurred_on between '2026-10-01' and '2026-10-31'")
            .fetch_all(&owner).await?;
        assert_eq!(rows.len(), 1);
        assert_eq!(
            rows[0].try_get::<Uuid, _>("id")?,
            Uuid::new_v5(&h.purpose, b"2026-10")
        );
        assert_eq!(
            rows[0].try_get::<i64, _>("amount_minor")?,
            immediate_amount.unwrap_or(200)
        );
        assert!(
            rows[0]
                .try_get::<Option<Uuid>, _>("created_by_member_id")?
                .is_none()
        );
        let actor: Option<Uuid> = sqlx::query_scalar("select actor_member_id from entity_events where entity_id=$1 and kind='create' order by id desc limit 1")
            .bind(Uuid::new_v5(&h.purpose, b"2026-10")).fetch_one(&owner).await?;
        assert!(actor.is_none());
    }
    owner.close().await;
    h.db.close().await?;
    Ok(())
}

#[tokio::test]
async fn aggregate_limits_guard_balance_total_and_groups_without_bigint_exceptions() -> Result<()> {
    tokio::time::timeout(std::time::Duration::from_secs(25), async {
        let h = LedgerDb::new().await?;
        let owner = h.fixture.owner().await?;
        let member: Uuid = sqlx::query_scalar("select id from space_members where space_id=$1 and user_id=$2")
            .bind(h.space.0).bind(h.user.0).fetch_one(&owner).await?;
        let tags: Vec<Uuid> = sqlx::query_scalar("select id from tags where space_id=$1 order by id limit 2")
            .bind(h.space.0).fetch_all(&owner).await?;
        // All these rows satisfy the new single-record cap. An unbounded number
        // of otherwise valid rows can still exceed JavaScript's exact range.
        sqlx::query("insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,tag_ids,origin,created_by_member_id,change_seq,created_at,updated_at) select uuidv7(),$1,'income',1000000000000,'2026-01-01',$2,array[$3::uuid],'api',$4,nextval('change_seq'),now(),now() from generate_series(1,9007)")
            .bind(h.space.0).bind(h.real).bind(tags[0]).bind(member).execute(&owner).await?;
        let last = Uuid::now_v7();
        sqlx::query("insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,tag_ids,origin,created_by_member_id,change_seq,created_at,updated_at) values($1,$2,'income',199254740991,'2026-01-01',$3,array[$4::uuid],'api',$5,nextval('change_seq'),now(),now())")
            .bind(last).bind(h.space.0).bind(h.real).bind(tags[0]).bind(member).execute(&owner).await?;
        let tx = h.tx().await?;
        let args: QueryStats = parse(json!({"measure":"sum","kinds":["income"],"period":{"from":"2026-01-01","through":"2026-01-31"},"group_by":"tag"}))?;
        let safe = 9_007_199_254_740_991_i64;
        assert_eq!(tx.ledger_balance(h.space, QueryBalance {account_id:Some(h.real)}).await?.balances[0].balance_minor, safe);
        let stats = tx.ledger_stats(h.space,args.clone()).await?;
        assert_eq!(stats.total,safe);
        assert_eq!(stats.groups[0].value,safe);
        sqlx::query("insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,tag_ids,origin,created_by_member_id,change_seq,created_at,updated_at) values(uuidv7(),$1,'income',1,'2026-01-01',$2,array[$3::uuid],'api',$4,nextval('change_seq'),now(),now())")
            .bind(h.space.0).bind(h.real).bind(tags[0]).bind(member).execute(&owner).await?;
        assert_eq!(tx.ledger_balance(h.space, QueryBalance {account_id:Some(h.real)}).await.err().unwrap().code,"aggregate_out_of_range");
        assert_eq!(tx.ledger_stats(h.space,args.clone()).await.err().unwrap().code,"aggregate_out_of_range");
        // Refunds of previous-period expenses cancel the income total, but put
        // the negative amount in a different tag group. Each group still needs
        // its own guard even though the grand total is exactly zero.
        sqlx::query("with parents as (insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,purpose_id,tag_ids,origin,created_by_member_id,change_seq,created_at,updated_at) select uuidv7(),space_id,'expense',amount_minor,'2025-12-01',account_id,$2,array[$3::uuid],'api',$4,nextval('change_seq'),now(),now() from records where space_id=$1 and kind='income' returning id,space_id,amount_minor,account_id,purpose_id) insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,purpose_id,refund_of_id,origin,created_by_member_id,change_seq,created_at,updated_at) select uuidv7(),space_id,'refund',amount_minor,'2026-01-01',account_id,purpose_id,id,'api',$4,nextval('change_seq'),now(),now() from parents")
            .bind(h.space.0).bind(h.purpose).bind(tags[1]).bind(member).execute(&owner).await?;
        let mut net = args.clone(); net.kinds = vec![RecordKind::Income,RecordKind::Expense]; net.group_by = None;
        assert_eq!(tx.ledger_stats(h.space,net.clone()).await?.total,0);
        net.group_by = Some(GroupBy::Tag);
        assert_eq!(tx.ledger_stats(h.space,net).await.err().unwrap().code,"aggregate_out_of_range");
        // Legacy/fixture data can exceed the input cap. Sum above bigint's max
        // must still return the same structured error, leaving the tx usable.
        sqlx::query("update records set amount_minor=$2 where id=$1")
            .bind(last).bind(i64::MAX).execute(&owner).await?;
        let error = tx.ledger_balance(h.space,QueryBalance {account_id:Some(h.real)}).await.err().unwrap();
        assert_eq!(error.status,422);
        assert_eq!(error.code,"aggregate_out_of_range");
        assert_eq!(tx.ledger_stats(h.space,args).await.err().unwrap().code,"aggregate_out_of_range");
        assert!(!tx.ledger_accounts(h.space,parse(json!({}))?).await?.accounts.is_empty());
        tx.rollback().await?;
        owner.close().await;
        h.db.close().await?;
        Ok::<_,anyhow::Error>(())
    }).await??;
    Ok(())
}
