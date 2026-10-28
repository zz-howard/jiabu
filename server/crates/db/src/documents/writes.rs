use super::*;
use jiabu_domain::templates::{Template, ValueType};
fn name(name: &str) -> Result<String, Error> {
    let name = normalize_name(name);
    if !(1..=30).contains(&name.chars().count()) {
        return Err(Error::invalid());
    }
    Ok(name)
}
impl SpaceTx {
    async fn subject_member(
        &self,
        space: SpaceId,
        kind: SubjectKind,
        member: Option<Uuid>,
    ) -> Result<(), Error> {
        if let Some(id) = member {
            if kind != SubjectKind::FamilyMember {
                return Err(Error::invalid());
            }
            if self
                .documents_optional(
                    space,
                    "select to_jsonb(m) data from space_members m where space_id=$1 and id=$2",
                    vec![space.0.into(), id.into()],
                )
                .await?
                .is_none()
            {
                return Err(Error::not_found());
            }
        }
        Ok(())
    }
    pub async fn documents_create_subject(
        &self,
        space: SpaceId,
        id: Uuid,
        args: CreateSubject,
        audit: &AuditCtx,
    ) -> Result<Subject, Error> {
        self.assert_write();
        let name = name(&args.name)?;
        // P58 lookup must precede member binding/new-id validation and include archives.
        if let Some(old)=self.documents_optional(space,"select to_jsonb(s) data from subjects s where space_id=$1 and kind=$2 and lower(name)=lower($3) and deleted_at is null",
            vec![space.0.into(),encode(args.kind)?.as_str().ok_or_else(Error::internal)?.into(),name.clone().into()]).await?{
            let old:Subject=decode(old)?;if old.archived_at.is_none(){return Ok(old);}
            let mut after=old.clone();after.archived_at=None;return self.save_subject(space,Some(old),after,"unarchive",audit).await;
        }
        self.subject_member(space, args.kind, args.member_id)
            .await?;
        self.save_subject(
            space,
            None,
            Subject {
                id,
                space_id: space.0,
                module: "documents".into(),
                visibility: None,
                kind: args.kind,
                name,
                member_id: args.member_id,
                archived_at: None,
                deleted_at: None,
                created_by_member_id: audit.actor_member_id.ok_or_else(Error::internal)?,
                version: 1,
                change_seq: 0,
                created_at: audit.now,
                updated_at: audit.now,
            },
            "create",
            audit,
        )
        .await
    }
    pub async fn documents_update_subject(
        &self,
        space: SpaceId,
        args: UpdateSubject,
        audit: &AuditCtx,
    ) -> Result<Subject, Error> {
        self.assert_write();
        let old = self.documents_subject(space, args.id).await?;
        version(&old, old.version, args.expected_version)?;
        let mut after = old.clone();
        if let Some(value) = args.name {
            after.name = name(&value)?;
        }
        if let Some(member) = args.member_id {
            after.member_id = member;
        }
        self.subject_member(space, after.kind, after.member_id)
            .await?;
        if self.documents_optional(space,"select to_jsonb(s) data from subjects s where space_id=$1 and kind=$2 and lower(name)=lower($3) and id<>$4 and deleted_at is null",
            vec![space.0.into(),encode(after.kind)?.as_str().ok_or_else(Error::internal)?.into(),after.name.clone().into(),after.id.into()]).await?.is_some(){return Err(Error::new(422,"name_taken"));}
        self.save_subject(space, Some(old), after, "update", audit)
            .await
    }
    pub async fn documents_archive_subject(
        &self,
        space: SpaceId,
        args: Versioned,
        audit: &AuditCtx,
    ) -> Result<Subject, Error> {
        self.assert_write();
        let old = self.documents_subject(space, args.id).await?;
        version(&old, old.version, args.expected_version)?;
        if old.archived_at.is_some() {
            return Ok(old);
        }
        let mut after = old.clone();
        after.archived_at = Some(audit.now);
        self.save_subject(space, Some(old), after, "archive", audit)
            .await
    }
    pub async fn documents_delete_subject(
        &self,
        space: SpaceId,
        args: Versioned,
        audit: &AuditCtx,
    ) -> Result<Subject, Error> {
        self.assert_write();
        let old = self.documents_subject(space, args.id).await?;
        version(&old, old.version, args.expected_version)?;
        if self.documents_optional(space,"select to_jsonb(d) data from documents d where space_id=$1 and subject_ids @> array[$2::uuid] limit 1",vec![space.0.into(),args.id.into()]).await?.is_some(){return Err(Error::new(422,"subject_in_use"));}
        let mut after = old.clone();
        after.deleted_at = Some(audit.now);
        self.save_subject(space, Some(old), after, "delete", audit)
            .await
    }
    #[allow(clippy::too_many_arguments)]
    pub async fn documents_create(
        &self,
        space: SpaceId,
        id: Uuid,
        args: CreateDocument,
        templates: &BTreeMap<String, Template>,
        audit: &AuditCtx,
        locale: &str,
    ) -> Result<Document, Error> {
        self.assert_write();
        let template = self
            .documents_template(space, args.template_id.as_deref(), templates, false)
            .await?;
        let subjects = self
            .documents_subjects_check(space, &args.subject_ids, template.as_ref())
            .await?;
        let mut content = args.content;
        let images = normalize_content(&mut content, template.as_ref()).map_err(invalid)?;
        let today = self.ledger_today(space, audit.now).await?;
        let event_date = resolve_date(&content, template.as_ref(), args.event_date, today)?;
        let title = title(
            args.title,
            template.as_ref(),
            &content,
            subjects.first().map_or("", |s| s.name.as_str()),
            locale,
        )?;
        self.documents_images(space, images).await?;
        let actor = audit.actor_member_id.ok_or_else(Error::internal)?;
        let origin = match audit.origin {
            "chat" => Origin::Chat,
            "manual" => Origin::Manual,
            _ => Origin::Api,
        };
        self.save_document(
            space,
            None,
            Document {
                id,
                space_id: space.0,
                module: "documents".into(),
                visibility: None,
                template_id: args.template_id,
                template_version: template.as_ref().map(|t| t.version),
                title,
                event_date,
                subject_ids: args.subject_ids,
                content,
                status: Status::Active,
                origin,
                run_id: audit.run_id,
                created_by_member_id: actor,
                updated_by_member_id: actor,
                version: 1,
                change_seq: 0,
                created_at: audit.now,
                updated_at: audit.now,
            },
            "create",
            audit,
        )
        .await
    }
    pub async fn documents_update(
        &self,
        space: SpaceId,
        args: UpdateDocument,
        templates: &BTreeMap<String, Template>,
        audit: &AuditCtx,
        locale: &str,
    ) -> Result<Document, Error> {
        self.assert_write();
        let old = self
            .documents_get(space, GetDocument { id: args.id })
            .await?;
        version(&old, old.version, args.expected_version)?;
        if old.status != Status::Active {
            return Err(Error::new(422, "document_voided"));
        }
        let mut after = old.clone();
        let changes = args.changes;
        let content_changed = changes.content.is_some();
        let template_changed = changes.template_id.is_some();
        if let Some(id) = changes.template_id {
            after.template_id = id;
        }
        let template = self
            .documents_template(
                space,
                after.template_id.as_deref(),
                templates,
                after.template_id == old.template_id,
            )
            .await?;
        if let Some(ids) = changes.subject_ids {
            after.subject_ids = ids;
        }
        let subjects = self
            .documents_subjects_check(space, &after.subject_ids, template.as_ref())
            .await?;
        if let Some(content) = changes.content {
            after.content = content;
        }
        // Rebind derived metric keys when switching templates, keeping historical
        // values and units intact unless the caller also submitted content.
        if template_changed {
            for item in &mut after.content.items {
                item.metric = template
                    .as_ref()
                    .and_then(|t| t.fields.iter().find(|field| field.key == item.key))
                    .and_then(|field| field.metric.clone());
            }
        }
        let images = if content_changed {
            normalize_content(&mut after.content, template.as_ref()).map_err(invalid)?
        } else {
            validate_content(&after.content, template.as_ref()).map_err(invalid)?
        };
        if content_changed || template_changed || changes.event_date.is_some() {
            let recorded = self.ledger_today(space, old.created_at).await?;
            after.event_date = resolve_date(
                &after.content,
                template.as_ref(),
                changes.event_date,
                recorded,
            )?;
        }
        if let Some(value) = changes.title {
            after.title = title(
                Some(value),
                template.as_ref(),
                &after.content,
                subjects.first().map_or("", |s| s.name.as_str()),
                locale,
            )?;
        }
        after.template_version = template.as_ref().map(|t| t.version);
        self.documents_images(space, images).await?;
        self.save_document(space, Some(old), after, "update", audit)
            .await
    }
    pub async fn documents_status(
        &self,
        space: SpaceId,
        args: Versioned,
        restore: bool,
        audit: &AuditCtx,
    ) -> Result<Document, Error> {
        self.assert_write();
        let old = self
            .documents_get(space, GetDocument { id: args.id })
            .await?;
        version(&old, old.version, args.expected_version)?;
        let desired = if restore {
            Status::Active
        } else {
            Status::Voided
        };
        if old.status == desired {
            return Ok(old);
        }
        let mut after = old.clone();
        after.status = desired;
        self.save_document(
            space,
            Some(old),
            after,
            if restore { "restore" } else { "void" },
            audit,
        )
        .await
    }
}
fn resolve_date(
    content: &Content,
    template: Option<&Template>,
    explicit: Option<chrono::NaiveDate>,
    fallback: chrono::NaiveDate,
) -> Result<chrono::NaiveDate, Error> {
    let derived = template
        .and_then(|t| t.event_date_field.as_ref())
        .and_then(|key| {
            content
                .items
                .iter()
                .find(|i| &i.key == key && i.kind == ValueType::Date)
        })
        .and_then(|i| i.value.as_str())
        .and_then(|s| chrono::NaiveDate::parse_from_str(s, "%Y-%m-%d").ok());
    if derived.zip(explicit).is_some_and(|(a, b)| a != b) {
        return Err(Error::invalid());
    }
    Ok(derived.or(explicit).unwrap_or(fallback))
}
fn title(
    explicit: Option<String>,
    template: Option<&Template>,
    content: &Content,
    subject: &str,
    locale: &str,
) -> Result<String, Error> {
    let title = explicit
        .or_else(|| template.and_then(|t| render_title(t, content, subject, locale)))
        .ok_or_else(Error::invalid)?;
    if !(1..=60).contains(&title.chars().count()) {
        return Err(Error::invalid());
    }
    Ok(title)
}
