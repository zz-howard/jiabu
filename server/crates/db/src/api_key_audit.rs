//! Append-only credential audit: deliberately cannot contain tool args/results.
use crate::{AppDb, OperationError, SpaceTx};
use sea_orm::{ConnectionTrait, DbBackend, Statement};
use uuid::Uuid;

#[derive(Clone)]
pub struct ApiKeyAudit {
    pub key_id: Uuid,
    pub user_id: Uuid,
    pub space_id: Option<Uuid>,
    pub operation: String,
    pub effect: &'static str,
    pub outcome: &'static str,
    pub request_id: Uuid,
    pub idempotency_key: Option<String>,
}
impl ApiKeyAudit {
    fn statement(&self) -> Statement {
        Statement::from_sql_and_values(
            DbBackend::Postgres,
            "insert into api_key_audit(api_key_id,user_id,space_id,operation,effect,outcome,request_id,idempotency_key) values($1,$2,$3,$4,$5,$6,$7,$8)",
            [
                self.key_id.into(),
                self.user_id.into(),
                self.space_id.into(),
                self.operation.clone().into(),
                self.effect.into(),
                self.outcome.into(),
                self.request_id.into(),
                self.idempotency_key.clone().into(),
            ],
        )
    }
}
impl AppDb {
    pub async fn append_api_key_audit(&self, audit: &ApiKeyAudit) -> Result<(), OperationError> {
        self.connection
            .execute_raw(audit.statement())
            .await
            .map_err(|_| OperationError::new(503, "unavailable"))?;
        Ok(())
    }
}
impl SpaceTx {
    pub async fn append_api_key_audit(&self, audit: &ApiKeyAudit) -> Result<(), OperationError> {
        self.tx
            .execute_raw(audit.statement())
            .await
            .map_err(|_| OperationError::new(503, "unavailable"))?;
        Ok(())
    }
}
