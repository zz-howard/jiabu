//! Transactional response replay. Call only after current authorization.
use crate::{
    SpaceTx,
    operation::{Error, Reply},
};
use jiabu_domain::UserId;
use sea_orm::{ConnectionTrait, DatabaseTransaction, DbBackend, Statement};
pub struct Idempotency {
    pub key: String,
    pub hash: Vec<u8>,
}
impl SpaceTx {
    pub async fn replay(
        &self,
        user: UserId,
        operation: &Idempotency,
    ) -> Result<Option<Reply>, Error> {
        self.assert_write();
        replay(&self.tx, user, operation).await
    }
    pub async fn remember(
        &self,
        user: UserId,
        operation: &Idempotency,
        reply: &Reply,
    ) -> Result<(), Error> {
        self.assert_write();
        remember(&self.tx, user, operation, reply).await
    }
}
pub(crate) async fn replay(
    tx: &DatabaseTransaction,
    user: UserId,
    operation: &Idempotency,
) -> Result<Option<Reply>, Error> {
    tx.execute_raw(Statement::from_sql_and_values(
        DbBackend::Postgres,
        "insert into idempotency(user_id,key,request_hash) values($1,$2,$3) on conflict do nothing",
        [
            user.0.into(),
            operation.key.clone().into(),
            operation.hash.clone().into(),
        ],
    ))
    .await?;
    let row = tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
        "select request_hash,response_status,response_body from idempotency where user_id=$1 and key=$2 for update",
        [user.0.into(), operation.key.clone().into()])).await?.ok_or_else(Error::internal)?;
    if row.try_get::<Vec<u8>>("", "request_hash")? != operation.hash {
        return Err(Error::new(422, "idempotency_key_reused"));
    }
    match row.try_get::<Option<i16>>("", "response_status")? {
        Some(status) => Ok(Some(Reply {
            status: status as u16,
            body: row.try_get("", "response_body")?,
        })),
        None => Ok(None),
    }
}
pub(crate) async fn remember(
    tx: &DatabaseTransaction,
    user: UserId,
    operation: &Idempotency,
    reply: &Reply,
) -> Result<(), Error> {
    tx.execute_raw(Statement::from_sql_and_values(
        DbBackend::Postgres,
        "update idempotency set response_status=$3,response_body=$4 where user_id=$1 and key=$2",
        [
            user.0.into(),
            operation.key.clone().into(),
            (reply.status as i16).into(),
            reply.body.clone().into(),
        ],
    ))
    .await?;
    Ok(())
}
