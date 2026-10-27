use super::*;
use crate::{AppDb, SystemTx};
use jiabu_domain::{
    allocation::{month_key, next_month},
    ledger::AllocationPlan,
};

pub trait Clock: Send + Sync {
    fn now(&self) -> DateTime<Utc>;
}
pub struct SystemClock;
impl Clock for SystemClock {
    fn now(&self) -> DateTime<Utc> {
        Utc::now()
    }
}
#[derive(Debug, Default)]
pub struct AllocationReport {
    pub inserted: u64,
    pub failed_spaces: u64,
}

/// A lock capability, constructed only after the corresponding space lock is held.
enum LockedLedger<'a> {
    User(&'a SpaceTx),
    System(&'a SystemTx),
}
impl LockedLedger<'_> {
    fn tx(&self) -> &DatabaseTransaction {
        match self {
            Self::User(tx) => &tx.tx,
            Self::System(tx) => &tx.tx,
        }
    }
    async fn seq(&self, space: SpaceId) -> Result<i64, Error> {
        match self {
            Self::User(tx) => Ok(tx.next_seq().await?),
            Self::System(tx) => Ok(tx.next_seq(space).await?),
        }
    }
}
impl SpaceTx {
    pub(super) async fn ledger_catch_up(
        &self,
        space: SpaceId,
        account: Uuid,
        now: DateTime<Utc>,
        include_disabled: bool,
    ) -> Result<u64, Error> {
        self.assert_write();
        self.member(space);
        catch_up(
            &LockedLedger::User(self),
            space,
            account,
            now,
            include_disabled,
        )
        .await
    }
}
async fn catch_up(
    locked: &LockedLedger<'_>,
    space: SpaceId,
    account: Uuid,
    now: DateTime<Utc>,
    include_disabled: bool,
) -> Result<u64, Error> {
    let tx = locked.tx();
    let Some(mut before) = snapshot(tx, space, Entity::Plan, account).await? else {
        return Ok(0);
    };
    let account_row = snapshot(tx, space, Entity::Account, account)
        .await?
        .ok_or_else(Error::not_found)?;
    if !account_row["archived_at"].is_null() || (!include_disabled && before["enabled"] != true) {
        return Ok(0);
    }
    let today = local_today(tx, space, now).await?;
    let mut inserted = 0;
    let audit = AuditCtx {
        actor_member_id: None,
        run_id: None,
        request_id: None,
        via_api_key_id: None,
        via_api_key_name: None,
        now,
        origin: "allocation",
    };
    loop {
        let plan: AllocationPlan = decode(before.clone())?;
        if plan.next_run_on > today {
            break;
        }
        let month = month_key(plan.next_run_on);
        if plan.last_run_month.as_deref() != Some(month.as_str()) {
            let id = Uuid::new_v5(&account, month.as_bytes());
            let record = json!({"id":id,"space_id":space.0,"module":"ledger","visibility":null,"kind":"allocation","amount_minor":plan.amount_minor,"occurred_on":plan.next_run_on,
                "account_id":null,"to_account_id":null,"purpose_id":account,"to_purpose_id":null,"refund_of_id":null,"tag_ids":[],"note":null,"attachments":[],"status":"active","void_reason":null,"origin":"allocation","run_id":null,"created_by_member_id":null,"updated_by_member_id":null,
                "version":1,"change_seq":locked.seq(space).await?,"created_at":now,"updated_at":now});
            if let Some(after) = insert_row(tx, Entity::Record, record).await? {
                append_event(
                    tx,
                    space,
                    Entity::Record,
                    id,
                    "create",
                    None,
                    after,
                    &audit,
                    locked.seq(space).await?,
                )
                .await?;
                inserted += 1;
            }
        }
        let next =
            next_month(plan.next_run_on, plan.day_of_month as u32).ok_or_else(Error::invalid)?;
        let after = one(tx,"update allocation_plans set last_run_month=$3,next_run_on=$4,version=version+1,change_seq=$5,updated_at=$6 where space_id=$1 and account_id=$2 returning to_jsonb(allocation_plans.*) data",
            vec![space.0.into(),account.into(),month.into(),next.into(),locked.seq(space).await?.into(),now.into()]).await?;
        append_event(
            tx,
            space,
            Entity::Plan,
            account,
            "update",
            Some(before),
            after.clone(),
            &audit,
            locked.seq(space).await?,
        )
        .await?;
        before = after;
    }
    Ok(inserted)
}
/// One injected instant, one transaction per space, no session-scoped settings.
/// Failed spaces roll back completely and will be retried by the next hourly pass.
pub async fn run_allocations(db: &AppDb, clock: &dyn Clock) -> Result<AllocationReport, Error> {
    let now = clock.now();
    let scan = SystemTx::begin(db).await?;
    let rows = scan.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
        "select distinct p.space_id from allocation_plans p join spaces s on s.id=p.space_id join accounts a on a.id=p.account_id and a.space_id=p.space_id where s.deleted_at is null and a.archived_at is null and p.enabled and p.next_run_on<=($1::timestamptz at time zone s.timezone)::date order by p.space_id", [now.into()])).await?;
    let spaces = rows
        .into_iter()
        .map(|r| r.try_get::<Uuid>("", "space_id").map(SpaceId))
        .collect::<Result<Vec<_>, _>>()?;
    scan.commit().await?;
    let mut report = AllocationReport::default();
    for space in spaces {
        match run_space(db, space, now).await {
            Ok(count) => report.inserted += count,
            Err(_) => report.failed_spaces += 1,
        }
    }
    Ok(report)
}
async fn run_space(db: &AppDb, space: SpaceId, now: DateTime<Utc>) -> Result<u64, Error> {
    let mut tx = SystemTx::begin(db).await?;
    tx.lock_space(space).await?;
    // Recheck after locking: a user may have disabled/archived/deleted since the scan.
    let rows = tx.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
        "select p.account_id from allocation_plans p join spaces s on s.id=p.space_id join accounts a on a.id=p.account_id and a.space_id=p.space_id where p.space_id=$1 and s.deleted_at is null and a.archived_at is null and p.enabled and p.next_run_on<=($2::timestamptz at time zone s.timezone)::date order by p.account_id",vec![space.0.into(),now.into()])).await?;
    let mut inserted = 0;
    for row in rows {
        inserted += catch_up(
            &LockedLedger::System(&tx),
            space,
            row.try_get("", "account_id")?,
            now,
            false,
        )
        .await?;
    }
    tx.commit().await?;
    Ok(inserted)
}
