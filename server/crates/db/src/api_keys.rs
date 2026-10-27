//! Account metadata persistence. Only digests cross the credential boundary.
use crate::{
    AppDb, Idempotency, OperationError as Error, OperationReply as Reply, Principal, Via,
    auth::{AuthError, User},
    idempotency,
};
use chrono::{DateTime, Utc};
use jiabu_domain::UserId;
use sea_orm::{ConnectionTrait, DatabaseTransaction, DbBackend, Statement, TransactionTrait};
use serde_json::{Value, json};
use uuid::Uuid;

const VIEW: &str = "jsonb_build_object('id',id,'name',name,'display_prefix',display_prefix,'scope',scope,'expires_at',expires_at,'created_at',created_at,'last_used_at',last_used_at,'revoked_at',revoked_at,'revoked_by',revoked_by,'status',case when revoked_at is not null then 'revoked' when expires_at<=now() then 'expired' else 'active' end)";
pub struct NewKey {
    pub name: String,
    pub digest: Vec<u8>,
    pub display_prefix: String,
    pub scope: String,
    pub expires_at: Option<DateTime<Utc>>,
}
pub enum KeyChange {
    Rename(String),
    Revoke,
}
impl AppDb {
    pub async fn authenticate_api_key(&self, digest: Vec<u8>) -> Result<Principal, AuthError> {
        let row = self.connection.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select k.id key_id,k.name,k.scope,u.id,u.username,u.locale from api_keys k join users u on u.id=k.user_id where k.token_hash=$1 and k.revoked_at is null and (k.expires_at is null or k.expires_at>now()) and u.disabled_at is null",
            [digest.into()])).await?.ok_or(AuthError::Unauthenticated)?;
        let id: Uuid = row.try_get("", "key_id")?;
        let user = User {
            id: row.try_get("", "id")?,
            username: row.try_get("", "username")?,
            locale: row.try_get("", "locale")?,
        };
        Ok(Principal {
            user_id: UserId(user.id),
            user,
            via: Via::ApiKey {
                id,
                name: row.try_get("", "name")?,
                scope: row.try_get("", "scope")?,
            },
        })
    }
    /// Only after request admission: throttled requests must not perform writes.
    pub async fn touch_api_key(&self, id: Uuid) -> Result<(), Error> {
        self.connection.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "update api_keys set last_used_at=now() where id=$1 and (last_used_at is null or last_used_at<=now()-interval '60 seconds')", [id.into()])).await?;
        Ok(())
    }
    pub async fn api_keys(&self, user: UserId) -> Result<Value, Error> {
        let rows = self
            .connection
            .query_all_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                format!(
                    "select {VIEW} value from api_keys where user_id=$1 order by created_at,id"
                ),
                [user.0.into()],
            ))
            .await?;
        let keys = rows
            .iter()
            .map(|r| r.try_get::<Value>("", "value"))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(json!({"api_keys":keys}))
    }
    pub async fn create_api_key(
        &self,
        user: UserId,
        key: NewKey,
        operation: &Idempotency,
    ) -> Result<Reply, Error> {
        let tx = self.key_account_lock(user).await?;
        if let Some(reply) = idempotency::replay(&tx, user, operation).await? {
            tx.commit().await?;
            return Ok(Reply::ok(
                json!({"id":reply.body["id"],"created":true,"plaintext_available":false}),
            ));
        }
        let count = tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select count(*)::bigint n from api_keys where user_id=$1 and revoked_at is null and (expires_at is null or expires_at>now())", [user.0.into()])).await?.ok_or_else(Error::internal)?.try_get::<i64>("", "n")?;
        if count >= 20 {
            return Err(Error::new(422, "api_key_limit_reached"));
        }
        if key.expires_at.is_some_and(|at| at <= Utc::now()) {
            return Err(Error::invalid());
        }
        let row = tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into api_keys(user_id,name,token_hash,display_prefix,scope,expires_at) values($1,$2,$3,$4,$5,$6) returning id",
            [user.0.into(), key.name.into(), key.digest.into(), key.display_prefix.into(), key.scope.into(), key.expires_at.into()])).await?.ok_or_else(Error::internal)?;
        let id: Uuid = row.try_get("", "id")?;
        let reply = Reply {
            status: 201,
            body: json!({"id":id}),
        };
        idempotency::remember(&tx, user, operation, &reply).await?;
        tx.commit().await?;
        Ok(reply)
    }
    pub async fn change_api_key(
        &self,
        user: UserId,
        id: Uuid,
        change: KeyChange,
        operation: &Idempotency,
    ) -> Result<Reply, Error> {
        let tx = self.key_account_lock(user).await?;
        tx.query_one_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            "select id from api_keys where id=$1 and user_id=$2 for no key update",
            [id.into(), user.0.into()],
        ))
        .await?
        .ok_or_else(Error::not_found)?;
        if let Some(reply) = idempotency::replay(&tx, user, operation).await? {
            tx.commit().await?;
            return Ok(reply);
        }
        let (sql, values): (&str, Vec<sea_orm::Value>) = match change {
            KeyChange::Rename(name) => (
                "update api_keys set name=$3 where id=$1 and user_id=$2",
                vec![id.into(), user.0.into(), name.into()],
            ),
            KeyChange::Revoke => (
                "update api_keys set revoked_at=now(),revoked_by='user' where id=$1 and user_id=$2 and revoked_at is null",
                vec![id.into(), user.0.into()],
            ),
        };
        tx.execute_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            sql,
            values,
        ))
        .await?;
        let row = tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                format!("select {VIEW} value from api_keys where id=$1 and user_id=$2"),
                [id.into(), user.0.into()],
            ))
            .await?
            .ok_or_else(Error::not_found)?;
        let reply = Reply::ok(row.try_get("", "value")?);
        idempotency::remember(&tx, user, operation, &reply).await?;
        tx.commit().await?;
        Ok(reply)
    }
    // Serialize management without conflicting with content writes taking FK key-share locks.
    async fn key_account_lock(&self, user: UserId) -> Result<DatabaseTransaction, Error> {
        let tx = self.connection.begin().await?;
        tx.query_one_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            "select id from users where id=$1 and disabled_at is null for no key update",
            [user.0.into()],
        ))
        .await?
        .ok_or_else(|| Error::new(401, "unauthenticated"))?;
        Ok(tx)
    }
}
