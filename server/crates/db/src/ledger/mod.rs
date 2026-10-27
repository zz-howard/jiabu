//! Ledger persistence. All SQL stays behind a scoped transaction; no pool escapes.
mod allocation;
mod queries;
mod writes;
use crate::{OperationError as Error, SpaceTx};
pub use allocation::{AllocationReport, Clock, SystemClock, run_allocations};
use chrono::{DateTime, Utc};
use jiabu_domain::SpaceId;
use sea_orm::{ConnectionTrait, DatabaseTransaction, DbBackend, Statement, Value as SqlValue};
use serde::{Serialize, de::DeserializeOwned};
use serde_json::{Value, json};
use uuid::Uuid;

#[derive(Clone)]
pub struct AuditCtx {
    pub actor_member_id: Option<Uuid>,
    pub run_id: Option<Uuid>,
    pub request_id: Option<Uuid>,
    pub via_api_key_id: Option<Uuid>,
    pub via_api_key_name: Option<String>,
    pub now: DateTime<Utc>,
    pub origin: &'static str,
}
#[derive(Clone, Copy)]
pub enum Entity {
    Account,
    Plan,
    Tag,
    Record,
}
impl Entity {
    fn table(self) -> &'static str {
        match self {
            Self::Account => "accounts",
            Self::Plan => "allocation_plans",
            Self::Tag => "tags",
            Self::Record => "records",
        }
    }
    fn key(self) -> &'static str {
        if matches!(self, Self::Plan) {
            "account_id"
        } else {
            "id"
        }
    }
    fn kind(self) -> &'static str {
        match self {
            Self::Account => "account",
            Self::Plan => "allocation_plan",
            Self::Tag => "tag",
            Self::Record => "record",
        }
    }
}
pub(crate) fn decode<T: DeserializeOwned>(value: Value) -> Result<T, Error> {
    serde_json::from_value(value).map_err(|_| Error::internal())
}
pub(crate) fn encode<T: Serialize>(value: T) -> Result<Value, Error> {
    serde_json::to_value(value).map_err(|_| Error::internal())
}
async fn optional(
    tx: &DatabaseTransaction,
    sql: &str,
    values: Vec<SqlValue>,
) -> Result<Option<Value>, Error> {
    tx.query_one_raw(Statement::from_sql_and_values(
        DbBackend::Postgres,
        sql,
        values,
    ))
    .await?
    .map(|row| row.try_get("", "data"))
    .transpose()
    .map_err(Error::from)
}
async fn one(tx: &DatabaseTransaction, sql: &str, values: Vec<SqlValue>) -> Result<Value, Error> {
    optional(tx, sql, values)
        .await?
        .ok_or_else(Error::not_found)
}
async fn snapshot(
    tx: &DatabaseTransaction,
    space: SpaceId,
    entity: Entity,
    id: Uuid,
) -> Result<Option<Value>, Error> {
    optional(
        tx,
        &format!(
            "select to_jsonb(t) data from {} t where space_id=$1 and {}=$2",
            entity.table(),
            entity.key()
        ),
        vec![space.0.into(), id.into()],
    )
    .await
}
fn version(value: &Value, expected: i32) -> Result<(), Error> {
    if value["version"].as_i64() != Some(i64::from(expected)) {
        return Err(Error {
            status: 409,
            code: "version_conflict",
            current: Some(value.clone()),
            errors: None,
            retry_after: None,
        });
    }
    Ok(())
}
fn active(value: &Value, field: &str) -> Result<(), Error> {
    if !value[field].is_null() {
        return Err(Error::new(422, "account_archived"));
    }
    Ok(())
}
fn identifier(value: &Value, field: &str) -> Result<Uuid, Error> {
    value[field]
        .as_str()
        .and_then(|s| Uuid::parse_str(s).ok())
        .ok_or_else(Error::internal)
}
#[allow(clippy::too_many_arguments)] // Complete audit context and both snapshots stay explicit.
async fn append_event(
    tx: &DatabaseTransaction,
    space: SpaceId,
    entity: Entity,
    id: Uuid,
    kind: &str,
    before: Option<Value>,
    after: Value,
    audit: &AuditCtx,
    seq: i64,
) -> Result<(), Error> {
    tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
        "insert into entity_events(space_id,entity_kind,entity_id,kind,before,after,actor_member_id,run_id,request_id,via_api_key_id,via_api_key_name,at,change_seq) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)",
        vec![space.0.into(), entity.kind().into(), id.into(), kind.into(), before.into(), after.into(), audit.actor_member_id.into(), audit.run_id.into(), audit.request_id.into(), audit.via_api_key_id.into(), audit.via_api_key_name.clone().into(), audit.now.into(), seq.into()])).await?;
    Ok(())
}
impl SpaceTx {
    pub async fn ledger_snapshot(
        &self,
        space: SpaceId,
        entity: Entity,
        id: Uuid,
    ) -> Result<Value, Error> {
        self.member(space);
        snapshot(&self.tx, space, entity, id)
            .await?
            .ok_or_else(Error::not_found)
    }
    pub async fn ledger_today(
        &self,
        space: SpaceId,
        now: DateTime<Utc>,
    ) -> Result<chrono::NaiveDate, Error> {
        self.member(space);
        local_today(&self.tx, space, now).await
    }
    #[allow(clippy::too_many_arguments)]
    async fn entity_event(
        &self,
        space: SpaceId,
        entity: Entity,
        id: Uuid,
        kind: &str,
        before: Option<Value>,
        after: Value,
        audit: &AuditCtx,
    ) -> Result<(), Error> {
        append_event(
            &self.tx,
            space,
            entity,
            id,
            kind,
            before,
            after,
            audit,
            self.next_seq().await?,
        )
        .await
    }
}
async fn local_today(
    tx: &DatabaseTransaction,
    space: SpaceId,
    now: DateTime<Utc>,
) -> Result<chrono::NaiveDate, Error> {
    let row = tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
        "select ($2::timestamptz at time zone timezone)::date today from spaces where id=$1 and deleted_at is null", vec![space.0.into(), now.into()])).await?.ok_or_else(Error::not_found)?;
    row.try_get("", "today").map_err(Error::from)
}
// Keep all identifiers generated by our enum. Values always use bound parameters.
async fn insert_row(
    tx: &DatabaseTransaction,
    entity: Entity,
    value: Value,
) -> Result<Option<Value>, Error> {
    optional(tx, &format!("insert into {} select (jsonb_populate_record(null::{},$1)).* on conflict do nothing returning to_jsonb({}.*) data", entity.table(), entity.table(), entity.table()), vec![value.into()]).await
}
