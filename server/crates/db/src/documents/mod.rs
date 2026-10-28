//! Documents persistence. Minimal snapshot/save/event code follows ledger/mod.rs
//! and ledger/writes.rs; deliberately no changes to the S3 write implementation.
mod queries;
mod writes;
use crate::{OperationError as Error, SpaceTx, ledger::AuditCtx};
use jiabu_domain::templates::Template;
use jiabu_domain::{SpaceId, documents::*};
use sea_orm::{ConnectionTrait, DbBackend, Statement, Value as SqlValue};
use serde::{Serialize, de::DeserializeOwned};
use serde_json::Value;
use std::collections::BTreeMap;
use uuid::Uuid;
fn encode<T: Serialize>(value: T) -> Result<Value, Error> {
    serde_json::to_value(value).map_err(|_| Error::internal())
}
fn decode<T: DeserializeOwned>(value: Value) -> Result<T, Error> {
    serde_json::from_value(value).map_err(|_| Error::internal())
}
fn invalid(error: ContentError) -> Error {
    let mut result = Error::invalid();
    result.errors = Some(vec![crate::ValidationIssue {
        pointer: error.pointer,
        rule: error.rule.into(),
    }]);
    result
}
fn version<T: Serialize>(current: &T, actual: i32, expected: i32) -> Result<(), Error> {
    if actual == expected {
        return Ok(());
    }
    let mut error = Error::new(409, "version_conflict");
    error.current = Some(encode(current)?);
    Err(error)
}
impl SpaceTx {
    async fn documents_optional(
        &self,
        space: SpaceId,
        sql: &str,
        values: Vec<SqlValue>,
    ) -> Result<Option<Value>, Error> {
        self.member(space);
        self.tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                sql,
                values,
            ))
            .await?
            .map(|r| r.try_get("", "data"))
            .transpose()
            .map_err(Error::from)
    }
    pub async fn documents_subject(&self, space: SpaceId, id: Uuid) -> Result<Subject, Error> {
        decode(self.documents_optional(space,"select to_jsonb(s) data from subjects s where space_id=$1 and id=$2 and deleted_at is null",vec![space.0.into(),id.into()]).await?.ok_or_else(Error::not_found)?)
    }
    pub async fn documents_get(
        &self,
        space: SpaceId,
        args: GetDocument,
    ) -> Result<Document, Error> {
        decode(
            self.documents_optional(
                space,
                "select to_jsonb(d) data from documents d where space_id=$1 and id=$2",
                vec![space.0.into(), args.id.into()],
            )
            .await?
            .ok_or_else(Error::not_found)?,
        )
    }
    #[allow(clippy::too_many_arguments)]
    async fn documents_event(
        &self,
        space: SpaceId,
        entity: &str,
        id: Uuid,
        kind: &str,
        before: Option<Value>,
        after: Value,
        audit: &AuditCtx,
    ) -> Result<(), Error> {
        self.assert_write();
        self.tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into entity_events(space_id,entity_kind,entity_id,kind,before,after,actor_member_id,run_id,request_id,via_api_key_id,via_api_key_name,at,change_seq) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)",
            vec![space.0.into(),entity.into(),id.into(),kind.into(),before.into(),after.into(),audit.actor_member_id.into(),audit.run_id.into(),audit.request_id.into(),audit.via_api_key_id.into(),audit.via_api_key_name.clone().into(),audit.now.into(),self.next_seq().await?.into()])).await?;
        Ok(())
    }
    async fn save_subject(
        &self,
        space: SpaceId,
        before: Option<Subject>,
        mut after: Subject,
        kind: &str,
        audit: &AuditCtx,
    ) -> Result<Subject, Error> {
        self.assert_write();
        self.member(space);
        after.change_seq = self.next_seq().await?;
        if let Some(old) = &before {
            after.version = old.version.checked_add(1).ok_or_else(Error::invalid)?;
            after.updated_at = audit.now;
        }
        let body = encode(&after)?;
        let sql = if before.is_none() {
            "insert into subjects select (jsonb_populate_record(null::subjects,$3)).* on conflict do nothing returning to_jsonb(subjects.*) data"
        } else {
            "update subjects s set name=x.name,member_id=x.member_id,archived_at=x.archived_at,deleted_at=x.deleted_at,version=x.version,change_seq=x.change_seq,updated_at=x.updated_at from jsonb_populate_record(null::subjects,$3) x where s.space_id=$1 and s.id=$2 returning to_jsonb(s.*) data"
        };
        // The insert binds scope/id in a CTE too, so all bound parameters have types.
        let sql = if before.is_none() {
            format!("with scope as (select $1::uuid space_id,$2::uuid id) {sql}")
        } else {
            sql.to_owned()
        };
        let saved = self
            .documents_optional(
                space,
                &sql,
                vec![space.0.into(), after.id.into(), body.into()],
            )
            .await?
            .ok_or_else(|| Error::new(422, "id_taken"))?;
        let saved: Subject = decode(saved)?;
        self.documents_event(
            space,
            "subject",
            saved.id,
            kind,
            before.map(encode).transpose()?,
            encode(&saved)?,
            audit,
        )
        .await?;
        Ok(saved)
    }
    async fn save_document(
        &self,
        space: SpaceId,
        before: Option<Document>,
        mut after: Document,
        kind: &str,
        audit: &AuditCtx,
    ) -> Result<Document, Error> {
        self.assert_write();
        self.member(space);
        after.change_seq = self.next_seq().await?;
        if let Some(old) = &before {
            after.version = old.version.checked_add(1).ok_or_else(Error::invalid)?;
            after.updated_at = audit.now;
            after.updated_by_member_id = audit.actor_member_id.ok_or_else(Error::internal)?;
        }
        let body = encode(&after)?;
        let sql = if before.is_none() {
            "with scope as (select $1::uuid space_id,$2::uuid id) insert into documents select (jsonb_populate_record(null::documents,$3)).* on conflict do nothing returning to_jsonb(documents.*) data"
        } else {
            "update documents d set template_id=x.template_id,template_version=x.template_version,title=x.title,event_date=x.event_date,subject_ids=x.subject_ids,content=x.content,status=x.status,version=x.version,change_seq=x.change_seq,updated_at=x.updated_at,updated_by_member_id=x.updated_by_member_id from jsonb_populate_record(null::documents,$3) x where d.space_id=$1 and d.id=$2 returning to_jsonb(d.*) data"
        };
        let saved = self
            .documents_optional(
                space,
                sql,
                vec![space.0.into(), after.id.into(), body.into()],
            )
            .await?
            .ok_or_else(|| Error::new(422, "id_taken"))?;
        let saved: Document = decode(saved)?;
        self.documents_event(
            space,
            "document",
            saved.id,
            kind,
            before.map(encode).transpose()?,
            encode(&saved)?,
            audit,
        )
        .await?;
        Ok(saved)
    }
    async fn documents_template(
        &self,
        space: SpaceId,
        id: Option<&str>,
        templates: &BTreeMap<String, Template>,
        allow_snapshot: bool,
    ) -> Result<Option<Template>, Error> {
        let Some(id) = id else { return Ok(None) };
        if let Some(template) = templates.get(id) {
            return Ok(Some(template.clone()));
        }
        if allow_snapshot && let Some(template) = self.document_template_snapshot(space, id).await?
        {
            return Ok(Some(template));
        }
        Err(Error::new(422, "template_unknown"))
    }
    async fn documents_subjects_check(
        &self,
        space: SpaceId,
        ids: &[Uuid],
        template: Option<&Template>,
    ) -> Result<Vec<Subject>, Error> {
        let mut seen = std::collections::BTreeSet::new();
        let mut subjects = Vec::new();
        for id in ids {
            if !seen.insert(id) {
                return Err(Error::new(422, "subject_rule_violated"));
            }
            match self.documents_subject(space, *id).await {
                Ok(s) => subjects.push(s),
                Err(e) if e.status == 404 => return Err(Error::new(422, "subject_rule_violated")),
                Err(e) => return Err(e),
            }
        }
        if !subject_rules(
            template,
            &subjects.iter().map(|s| s.kind).collect::<Vec<_>>(),
        ) {
            return Err(Error::new(422, "subject_rule_violated"));
        }
        Ok(subjects)
    }
    async fn documents_images(&self, space: SpaceId, images: Vec<String>) -> Result<(), Error> {
        for sha in images {
            self.documents_blob_ref(space, &sha).await?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests;
