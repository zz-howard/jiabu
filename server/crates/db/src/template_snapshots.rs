//! Global template declarations. Only startup/reload writes these snapshots.
use crate::{DbErr, SpaceTx, SystemTx};
use jiabu_domain::{SpaceId, templates::Template};
use sea_orm::{ConnectionTrait, DbBackend, Statement};
use std::collections::BTreeMap;
impl SystemTx {
    pub async fn template_snapshots(&self) -> Result<BTreeMap<String, Template>, DbErr> {
        // Independent two-int advisory-lock namespace; never acquire a space lock here.
        self.tx
            .execute_raw(Statement::from_string(
                DbBackend::Postgres,
                "select pg_advisory_xact_lock(726401,6)".to_owned(),
            ))
            .await?;
        let rows = self
            .tx
            .query_all_raw(Statement::from_string(
                DbBackend::Postgres,
                "select id,body from template_snapshots order by id".to_owned(),
            ))
            .await?;
        let mut result = BTreeMap::new();
        for row in rows {
            let id: String = row.try_get("", "id")?;
            let body: serde_json::Value = row.try_get("", "body")?;
            let template = serde_json::from_value(body)
                .map_err(|_| DbErr::Custom("invalid template snapshot".into()))?;
            result.insert(id, template);
        }
        Ok(result)
    }
    pub async fn save_template_snapshot(&self, template: &Template) -> Result<(), DbErr> {
        let body = serde_json::to_value(template)
            .map_err(|_| DbErr::Custom("invalid template snapshot".into()))?;
        self.tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into template_snapshots(id,version,body) values($1,$2,$3) on conflict(id) do update set version=excluded.version,body=excluded.body,loaded_at=now()",
            vec![template.id.clone().into(),template.version.into(),body.into()])).await?;
        Ok(())
    }
}
impl SpaceTx {
    /// Declarations are global/non-private; membership is still bound by the caller.
    pub async fn document_template_snapshot(
        &self,
        space: SpaceId,
        id: &str,
    ) -> Result<Option<Template>, DbErr> {
        self.member(space);
        self.tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select body from template_snapshots where id=$1",
                [id.into()],
            ))
            .await?
            .map(|row| {
                let body: serde_json::Value = row.try_get("", "body")?;
                serde_json::from_value(body)
                    .map_err(|_| DbErr::Custom("invalid template snapshot".into()))
            })
            .transpose()
    }
}
