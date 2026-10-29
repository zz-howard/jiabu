use super::*;
use jiabu_domain::ledger::*;

impl SpaceTx {
    #[allow(clippy::too_many_arguments)] // One transaction persists an entity plus its two audit snapshots.
    async fn save(
        &self,
        space: SpaceId,
        entity: Entity,
        id: Uuid,
        kind: &str,
        before: Option<Value>,
        mut after: Value,
        audit: &AuditCtx,
    ) -> Result<Value, Error> {
        self.assert_write();
        after["change_seq"] = json!(self.next_seq().await?);
        let saved = if before.is_none() {
            insert_row(&self.tx, entity, after)
                .await?
                .ok_or_else(|| Error::new(422, "id_taken"))?
        } else {
            after["version"] = json!(
                before
                    .as_ref()
                    .and_then(|v| v["version"].as_i64())
                    .ok_or_else(Error::internal)?
                    .checked_add(1)
                    .ok_or_else(Error::invalid)?
            );
            if !matches!(entity, Entity::Tag) {
                after["updated_at"] = json!(audit.now);
            }
            let columns = match entity {
                Entity::Record => {
                    "amount_minor=x.amount_minor,occurred_on=x.occurred_on,account_id=x.account_id,to_account_id=x.to_account_id,purpose_id=x.purpose_id,to_purpose_id=x.to_purpose_id,tag_ids=x.tag_ids,note=x.note,attachments=x.attachments,status=x.status,void_reason=x.void_reason,updated_by_member_id=x.updated_by_member_id,updated_at=x.updated_at"
                }
                Entity::Account => {
                    "name=x.name,is_reserve=x.is_reserve,opening_balance_minor=x.opening_balance_minor,opening_on=x.opening_on,sort_key=x.sort_key,archived_at=x.archived_at,updated_at=x.updated_at"
                }
                Entity::Tag => "name=x.name,deleted_at=x.deleted_at",
                Entity::Plan => {
                    "amount_minor=x.amount_minor,day_of_month=x.day_of_month,enabled=x.enabled,next_run_on=x.next_run_on,last_run_month=x.last_run_month,updated_at=x.updated_at"
                }
            };
            one(&self.tx, &format!("update {} t set {columns},version=x.version,change_seq=x.change_seq from jsonb_populate_record(null::{},$3) x where t.space_id=$1 and t.{}=$2 returning to_jsonb(t.*) data", entity.table(), entity.table(), entity.key()), vec![space.0.into(), id.into(), after.into()]).await?
        };
        self.entity_event(space, entity, id, kind, before, saved.clone(), audit)
            .await?;
        Ok(saved)
    }
    pub async fn ledger_create_account(
        &self,
        space: SpaceId,
        id: Uuid,
        args: CreateAccount,
        audit: &AuditCtx,
    ) -> Result<Account, Error> {
        self.assert_write();
        self.member(space);
        if let Some(old) = snapshot(&self.tx, space, Entity::Account, id).await? {
            if old["kind"] == encode(args.kind)?
                && old["name"] == args.name
                && old["opening_balance_minor"] == args.opening_balance_minor
                && old["opening_on"] == json!(args.opening_on)
                && old["is_reserve"] == args.is_reserve
                && old["sort_key"] == args.sort_key
            {
                return decode(old);
            }
            return Err(Error::new(422, "id_taken"));
        }
        let mut value = encode(args)?;
        value["id"] = json!(id);
        value["space_id"] = json!(space.0);
        value["module"] = json!("ledger");
        value["visibility"] = Value::Null;
        value["created_by_member_id"] = json!(audit.actor_member_id);
        value["archived_at"] = Value::Null;
        value["version"] = json!(1);
        value["created_at"] = json!(audit.now);
        value["updated_at"] = json!(audit.now);
        self.check_account(space, id, &value).await?;
        decode(
            self.save(space, Entity::Account, id, "create", None, value, audit)
                .await?,
        )
    }
    async fn check_account(&self, space: SpaceId, id: Uuid, value: &Value) -> Result<(), Error> {
        let name = value["name"].as_str().ok_or_else(Error::invalid)?;
        if name.trim().is_empty() || (value["is_reserve"] == true && value["kind"] != "purpose") {
            return Err(Error::invalid());
        }
        let collision = optional(&self.tx,
            "select to_jsonb(a) data from accounts a where space_id=$1 and id<>$2 and archived_at is null and ((kind=$3 and lower(name)=lower($4)) or ($5 and is_reserve)) limit 1",
            vec![space.0.into(), id.into(), value["kind"].as_str().ok_or_else(Error::invalid)?.into(), name.into(), value["is_reserve"].as_bool().ok_or_else(Error::invalid)?.into()]).await?;
        if value["archived_at"].is_null() && collision.is_some() {
            return Err(Error::invalid());
        }
        Ok(())
    }
    pub async fn ledger_update_account(
        &self,
        space: SpaceId,
        args: UpdateAccount,
        audit: &AuditCtx,
    ) -> Result<Account, Error> {
        self.assert_write();
        let before = self
            .ledger_snapshot(space, Entity::Account, args.id)
            .await?;
        version(&before, args.expected_version)?;
        let mut after = before.clone();
        let patch = encode(&args)?;
        for key in [
            "name",
            "is_reserve",
            "opening_balance_minor",
            "opening_on",
            "sort_key",
        ] {
            if !patch[key].is_null() {
                after[key] = patch[key].clone();
            }
        }
        self.check_account(space, args.id, &after).await?;
        decode(
            self.save(
                space,
                Entity::Account,
                args.id,
                "update",
                Some(before),
                after,
                audit,
            )
            .await?,
        )
    }
    pub async fn ledger_archive_account(
        &self,
        space: SpaceId,
        args: ArchiveAccount,
        audit: &AuditCtx,
    ) -> Result<Account, Error> {
        self.assert_write();
        let before = self
            .ledger_snapshot(space, Entity::Account, args.id)
            .await?;
        version(&before, args.expected_version)?;
        if !before["archived_at"].is_null() {
            return decode(before);
        }
        let balances = self
            .ledger_balance(
                space,
                QueryBalance {
                    account_id: Some(args.id),
                },
            )
            .await?;
        if balances.balances.iter().any(|b| b.balance_minor != 0) {
            return Err(Error::new(422, "balance_not_zero"));
        }
        let mut after = before.clone();
        after["archived_at"] = json!(audit.now);
        if let Some(plan) = snapshot(&self.tx, space, Entity::Plan, args.id).await?
            && plan["enabled"] == true
        {
            let mut disabled = plan.clone();
            disabled["enabled"] = json!(false);
            self.save(
                space,
                Entity::Plan,
                args.id,
                "update",
                Some(plan),
                disabled,
                audit,
            )
            .await?;
        }
        decode(
            self.save(
                space,
                Entity::Account,
                args.id,
                "archive",
                Some(before),
                after,
                audit,
            )
            .await?,
        )
    }
    pub async fn ledger_create_tag(
        &self,
        space: SpaceId,
        id: Uuid,
        args: CreateTag,
        audit: &AuditCtx,
    ) -> Result<Tag, Error> {
        self.assert_write();
        self.member(space);
        if args.name.trim().is_empty() {
            return Err(Error::invalid());
        }
        if let Some(old) = snapshot(&self.tx, space, Entity::Tag, id).await? {
            if old["name"] == args.name {
                return decode(old);
            }
            return Err(Error::new(422, "id_taken"));
        }
        let value = json!({"id":id,"space_id":space.0,"module":"ledger","preset_key":null,"name":args.name,"created_by_member_id":audit.actor_member_id,"deleted_at":null,"version":1});
        decode(
            self.save(space, Entity::Tag, id, "create", None, value, audit)
                .await?,
        )
    }
    pub async fn ledger_rename_tag(
        &self,
        space: SpaceId,
        args: RenameTag,
        audit: &AuditCtx,
    ) -> Result<Tag, Error> {
        self.assert_write();
        if args.name.trim().is_empty() {
            return Err(Error::invalid());
        }
        let before = self.ledger_snapshot(space, Entity::Tag, args.id).await?;
        version(&before, args.expected_version)?;
        if !before["deleted_at"].is_null() {
            return Err(Error::not_found());
        }
        let mut after = before.clone();
        after["name"] = json!(args.name);
        decode(
            self.save(
                space,
                Entity::Tag,
                args.id,
                "update",
                Some(before),
                after,
                audit,
            )
            .await?,
        )
    }
    pub async fn ledger_delete_tag(
        &self,
        space: SpaceId,
        args: DeleteTag,
        audit: &AuditCtx,
    ) -> Result<Tag, Error> {
        self.assert_write();
        let before = self.ledger_snapshot(space, Entity::Tag, args.id).await?;
        version(&before, args.expected_version)?;
        if !before["deleted_at"].is_null() {
            return decode(before);
        }
        let mut after = before.clone();
        after["deleted_at"] = json!(audit.now);
        decode(
            self.save(
                space,
                Entity::Tag,
                args.id,
                "delete",
                Some(before),
                after,
                audit,
            )
            .await?,
        )
    }
    pub async fn ledger_create_record(
        &self,
        space: SpaceId,
        id: Uuid,
        args: CreateRecord,
        audit: &AuditCtx,
    ) -> Result<Record, Error> {
        self.assert_write();
        self.member(space);
        let mut value = encode(args)?;
        value["id"] = json!(id);
        value["space_id"] = json!(space.0);
        value["module"] = json!("ledger");
        value["visibility"] = Value::Null;
        value["status"] = json!("active");
        value["void_reason"] = Value::Null;
        value["origin"] = json!(audit.origin);
        value["run_id"] = json!(audit.run_id);
        value["created_by_member_id"] = json!(audit.actor_member_id);
        value["updated_by_member_id"] = json!(audit.actor_member_id);
        value["version"] = json!(1);
        value["created_at"] = json!(audit.now);
        value["updated_at"] = json!(audit.now);
        if value["kind"] == "refund" {
            let parent_id = identifier(&value, "refund_of_id")
                .map_err(|_| Error::invalid_at("/refund_of_id", "required_for_kind"))?;
            let parent = self
                .ledger_snapshot(space, Entity::Record, parent_id)
                .await
                .map_err(|error| at_field(error, "refund_of_id"))?;
            check_parent(&parent).map_err(|error| at_field(error, "refund_of_id"))?;
            for field in ["account_id", "purpose_id"] {
                if value[field].is_null() {
                    let original = self
                        .ledger_snapshot(space, Entity::Account, identifier(&parent, field)?)
                        .await?;
                    active(&original, "archived_at")?;
                    value[field] = parent[field].clone();
                }
            }
        }
        // Expired idempotency rows still cannot overwrite/recreate an existing client ID.
        if let Some(old) = snapshot(&self.tx, space, Entity::Record, id).await? {
            let same = [
                "kind",
                "amount_minor",
                "occurred_on",
                "account_id",
                "to_account_id",
                "purpose_id",
                "to_purpose_id",
                "refund_of_id",
                "tag_ids",
                "note",
                "attachments",
            ]
            .iter()
            .all(|k| old[*k] == value[*k]);
            if same {
                return decode(old);
            }
            return Err(Error::new(422, "id_taken"));
        }
        self.check_record(space, &value, None).await?;
        self.check_refund_invariant(space, &value, None).await?;
        decode(
            self.save(space, Entity::Record, id, "create", None, value, audit)
                .await?,
        )
    }
    async fn check_record(
        &self,
        space: SpaceId,
        value: &Value,
        original: Option<&Value>,
    ) -> Result<(), Error> {
        let record: Record = decode(value_with_seq(value.clone()))?;
        if record.amount_minor <= 0 {
            return Err(Error::invalid_at("/amount_minor", "positive"));
        }
        if record
            .note
            .as_ref()
            .is_some_and(|s| s.chars().count() > 500)
        {
            return Err(Error::invalid_at("/note", "max_length_500"));
        }
        let shape = record_shape_issues(&record);
        if !shape.is_empty() {
            let mut error = Error::invalid();
            error.errors = Some(
                shape
                    .into_iter()
                    .map(|(field, rule)| crate::ValidationIssue {
                        pointer: format!("/{field}"),
                        rule: rule.into(),
                    })
                    .collect(),
            );
            return Err(error);
        }
        let mut tags = std::collections::HashSet::new();
        if record.tag_ids.iter().any(|id| !tags.insert(*id)) {
            return Err(Error::invalid_at("/tag_ids", "unique"));
        }
        for (field, id, kind) in [
            ("account_id", record.account_id, "real"),
            ("to_account_id", record.to_account_id, "real"),
            ("purpose_id", record.purpose_id, "purpose"),
            ("to_purpose_id", record.to_purpose_id, "purpose"),
        ] {
            if let Some(id) = id {
                let account = self
                    .ledger_snapshot(space, Entity::Account, id)
                    .await
                    .map_err(|error| at_field(error, field))?;
                if account["kind"] != kind {
                    return Err(Error::invalid_at(
                        &format!("/{field}"),
                        if kind == "real" {
                            "real_account_required"
                        } else {
                            "purpose_account_required"
                        },
                    ));
                }
                if original.is_none_or(|before| before[field] != value[field]) {
                    active(&account, "archived_at").map_err(|error| at_field(error, field))?;
                }
            }
        }
        for id in record.tag_ids {
            let tag = self
                .ledger_snapshot(space, Entity::Tag, id)
                .await
                .map_err(|error| at_field(error, "tag_ids"))?;
            let retained = original
                .and_then(|before| before["tag_ids"].as_array())
                .is_some_and(|tags| tags.contains(&json!(id)));
            if !retained && !tag["deleted_at"].is_null() {
                return Err(at_field(Error::not_found(), "tag_ids"));
            }
        }
        for sha in record.attachments {
            if sha.len() != 64
                || !sha
                    .bytes()
                    .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
            {
                return Err(Error::invalid_at("/attachments", "sha256_hex"));
            }
            self.ledger_blob_ref(space, &sha).await?;
        }
        Ok(())
    }
    async fn refund_sum(
        &self,
        space: SpaceId,
        parent: Uuid,
        exclude: Option<Uuid>,
    ) -> Result<i64, Error> {
        let row = self.tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select coalesce(sum(amount_minor),0)::bigint amount from records where space_id=$1 and refund_of_id=$2 and kind='refund' and status='active' and ($3::uuid is null or id<>$3)", vec![space.0.into(),parent.into(),exclude.into()])).await?.ok_or_else(Error::internal)?;
        row.try_get("", "amount").map_err(Error::from)
    }
    async fn check_refund_invariant(
        &self,
        space: SpaceId,
        value: &Value,
        exclude: Option<Uuid>,
    ) -> Result<(), Error> {
        if value["status"] != "active" {
            return Ok(());
        }
        let amount = value["amount_minor"].as_i64().ok_or_else(Error::invalid)?;
        if value["kind"] == "refund" {
            let parent_id = identifier(value, "refund_of_id")?;
            let parent = self
                .ledger_snapshot(space, Entity::Record, parent_id)
                .await?;
            check_parent(&parent)?;
            let refunded = self.refund_sum(space, parent_id, exclude).await?;
            #[cfg(test)]
            if let Some((entered, release)) = &self.refund_gate {
                entered.notify_one();
                release.notified().await;
            }
            if !refund_within_limit(
                refunded,
                amount,
                parent["amount_minor"]
                    .as_i64()
                    .ok_or_else(Error::internal)?,
            ) {
                return Err(Error::new(422, "refund_exceeds_original"));
            }
        } else if value["kind"] == "expense"
            && self
                .refund_sum(space, identifier(value, "id")?, None)
                .await?
                > amount
        {
            return Err(Error::new(422, "refund_exceeds_original"));
        }
        Ok(())
    }
    pub async fn ledger_update_record(
        &self,
        space: SpaceId,
        args: UpdateRecord,
        audit: &AuditCtx,
    ) -> Result<Record, Error> {
        self.assert_write();
        let before = self.ledger_snapshot(space, Entity::Record, args.id).await?;
        version(&before, args.expected_version)?;
        if before["status"] != "active" {
            return Err(Error::invalid());
        }
        let mut after = before.clone();
        let patch = encode(&args.changes)?;
        for key in [
            "amount_minor",
            "occurred_on",
            "account_id",
            "to_account_id",
            "purpose_id",
            "to_purpose_id",
            "tag_ids",
            "attachments",
        ] {
            if !patch[key].is_null() {
                after[key] = patch[key].clone();
            }
        }
        if let Some(note) = args.changes.note {
            after["note"] = json!(note);
        }
        after["updated_by_member_id"] = json!(audit.actor_member_id);
        self.check_record(space, &after, Some(&before)).await?;
        self.check_refund_invariant(space, &after, Some(args.id))
            .await?;
        decode(
            self.save(
                space,
                Entity::Record,
                args.id,
                "update",
                Some(before),
                after,
                audit,
            )
            .await?,
        )
    }
    pub async fn ledger_record_status(
        &self,
        space: SpaceId,
        args: VersionedRecord,
        restore: bool,
        audit: &AuditCtx,
    ) -> Result<Record, Error> {
        self.assert_write();
        let before = self.ledger_snapshot(space, Entity::Record, args.id).await?;
        version(&before, args.expected_version)?;
        let status = if restore { "active" } else { "voided" };
        if before["status"] == status {
            return decode(before);
        }
        if !restore
            && before["kind"] == "expense"
            && self.refund_sum(space, args.id, None).await? > 0
        {
            return Err(Error::new(422, "has_refunds"));
        }
        let mut after = before.clone();
        after["status"] = json!(status);
        after["void_reason"] = if restore { Value::Null } else { json!("user") };
        after["updated_by_member_id"] = json!(audit.actor_member_id);
        if restore {
            self.check_refund_invariant(space, &after, Some(args.id))
                .await?;
        }
        decode(
            self.save(
                space,
                Entity::Record,
                args.id,
                if restore { "restore" } else { "void" },
                Some(before),
                after,
                audit,
            )
            .await?,
        )
    }
    pub async fn ledger_set_plan(
        &self,
        space: SpaceId,
        args: SetAllocationPlan,
        audit: &AuditCtx,
    ) -> Result<AllocationPlan, Error> {
        self.assert_write();
        let account = self
            .ledger_snapshot(space, Entity::Account, args.account_id)
            .await?;
        active(&account, "archived_at")?;
        if account["kind"] != "purpose" {
            return Err(Error::invalid());
        }
        let old = snapshot(&self.tx, space, Entity::Plan, args.account_id).await?;
        match (&old, args.expected_version) {
            (Some(value), Some(expected)) => version(value, expected)?,
            (None, None) => (),
            (Some(value), None) => {
                return Err(Error {
                    status: 409,
                    code: "version_conflict",
                    current: Some(value.clone()),
                    errors: None,
                    retry_after: None,
                    space_unavailable: false,
                });
            }
            (None, Some(_)) => return Err(Error::not_found()),
        }
        // Only a continuously enabled plan owes allocations under the old settings.
        // Re-enabling starts afresh, and disabling never catches up.
        let continuing = args.enabled && old.as_ref().is_some_and(|plan| plan["enabled"] == true);
        if continuing {
            self.ledger_catch_up(space, args.account_id, audit.now)
                .await?;
        }
        let before = snapshot(&self.tx, space, Entity::Plan, args.account_id).await?;
        let last = before.as_ref().and_then(|v| v["last_run_month"].as_str());
        let today = self.ledger_today(space, audit.now).await?;
        let next = if continuing {
            jiabu_domain::allocation::continued_run(today, args.day_of_month as u32, last)
        } else {
            jiabu_domain::allocation::first_run(today, args.day_of_month as u32, last)
        }
        .ok_or_else(Error::invalid)?;
        let after = json!({"account_id":args.account_id,"space_id":space.0,"amount_minor":args.amount_minor,"day_of_month":args.day_of_month,"enabled":args.enabled,"next_run_on":next,"last_run_month":last,"version":1,"updated_at":audit.now});
        let saved = self
            .save(
                space,
                Entity::Plan,
                args.account_id,
                if before.is_some() { "update" } else { "create" },
                before,
                after,
                audit,
            )
            .await?;
        if continuing && next <= today {
            // The old due day was still in the future, but the new day is due.
            // The same locked implementation inserts this month's new allocation
            // and advances next_run_on, atomically with the user's edit and audit.
            self.ledger_catch_up(space, args.account_id, audit.now)
                .await?;
            return decode(
                self.ledger_snapshot(space, Entity::Plan, args.account_id)
                    .await?,
            );
        }
        decode(saved)
    }
}
fn value_with_seq(mut value: Value) -> Value {
    if value.get("change_seq").is_none() {
        value["change_seq"] = json!(0);
    }
    value
}
fn check_parent(parent: &Value) -> Result<(), Error> {
    if parent["kind"] != "expense" {
        return Err(Error::invalid_at("/refund_of_id", "expense_required"));
    }
    if parent["status"] != "active" {
        return Err(Error::new(422, "parent_voided"));
    }
    Ok(())
}
/// Name the request field behind a lookup failure (`not_found`, `account_archived`) so
/// the Agent can tell the model which argument to fix. Other errors pass through.
fn at_field(mut error: Error, field: &str) -> Error {
    if error.status < 500 && error.errors.is_none() {
        error.errors = Some(vec![crate::ValidationIssue {
            pointer: format!("/{field}"),
            rule: error.code.into(),
        }]);
    }
    error
}
