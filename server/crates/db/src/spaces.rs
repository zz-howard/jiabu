//! Space service and scoped persistence. No connection/transaction escapes this crate.
pub use crate::idempotency::Idempotency;
use crate::{AppDb, BeginError, DbErr, Mode, SpaceTx, json_time::normalize_fields};
use jiabu_domain::{
    MemberId, SpaceId, UserId,
    presets::PRESETS,
    space_init::{PresetSeed, SPACE_ACCENT_KEYS, SpaceInit},
    spaces::{Change, CreateSpace, Decision, valid_name},
};
use sea_orm::{ConnectionTrait, DbBackend, QueryResult, Statement, Value as SqlValue};
use serde_json::{Value, json};
use uuid::Uuid;

pub use crate::operation::{Error, Reply};

impl SpaceTx {
    /// Shared app-side adapter for the S1 SQL primitive, without committing the
    /// caller's transaction: S2 must append audit and idempotency atomically.
    pub(crate) async fn initialize_space(&self, plan: &SpaceInit) -> Result<MemberId, DbErr> {
        self.assert_write();
        let seeds = serde_json::to_value(&plan.presets)
            .map_err(|error| DbErr::Custom(error.to_string()))?;
        let row = self
            .tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select initialize_space($1,$2,$3,$4,$5,$6,$7,$8,$9) as id",
                [
                    plan.space_id.0.into(),
                    plan.user_id.0.into(),
                    plan.name.clone().into(),
                    plan.accent.clone().into(),
                    plan.currency.clone().into(),
                    plan.timezone.clone().into(),
                    plan.is_default.into(),
                    plan.display_name.clone().into(),
                    seeds.into(),
                ],
            ))
            .await?
            .ok_or_else(|| DbErr::Custom("missing initialized member".into()))?;
        Ok(MemberId(row.try_get("", "id")?))
    }
    async fn one(&self, sql: &str, values: Vec<SqlValue>) -> Result<Option<QueryResult>, Error> {
        Ok(self
            .tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                sql,
                values,
            ))
            .await?)
    }
    async fn execute(&self, sql: &str, values: Vec<SqlValue>) -> Result<u64, Error> {
        Ok(self
            .tx
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                sql,
                values,
            ))
            .await?
            .rows_affected())
    }
    async fn event(
        &self,
        space: SpaceId,
        actor: MemberId,
        subject: Option<MemberId>,
        kind: &str,
        request: Uuid,
    ) -> Result<(), Error> {
        self.execute("insert into space_events(space_id,actor_member_id,subject_member_id,kind,request_id) values($1,$2,$3,$4,$5)",
            vec![space.0.into(), actor.0.into(), subject.map(|id| id.0).into(), kind.into(), request.into()]).await?;
        Ok(())
    }
    /// Public space metadata, also used as the version-conflict payload.
    async fn space(&self, space: SpaceId) -> Result<Value, Error> {
        self.one(
            "select jsonb_build_object('id',s.id,'name',s.name,'accent_color',s.accent_color,'currency',s.currency,'timezone',s.timezone,'is_default',s.is_default,'version',s.version,'change_seq',s.change_seq) value from spaces s where id=$1 and deleted_at is null",
            vec![space.0.into()],
        )
        .await?
        .ok_or_else(Error::not_found)?
        .try_get("", "value")
        .map_err(Into::into)
    }
    /// The public member projection is shared by successful edits and conflicts.
    async fn member_view(&self, space: SpaceId, member: MemberId) -> Result<Value, Error> {
        let value = self.one(
            "select jsonb_build_object('id',m.id,'display_name',m.display_name,'role',m.role,'status',m.status,'join_epoch',m.join_epoch,'joined_at',m.joined_at,'left_at',m.left_at,'left_reason',m.left_reason,'version',m.version,'change_seq',m.change_seq) value from space_members m where space_id=$1 and id=$2",
            vec![space.0.into(), member.0.into()],
        )
        .await?
        .ok_or_else(Error::not_found)?
        .try_get("", "value")?;
        Ok(normalize_fields(value, &["joined_at", "left_at"])?)
    }
    async fn grant(&self, space: SpaceId, member: MemberId, level: &str) -> Result<(), Error> {
        for module in ["ledger", "documents"] {
            let seq = self.next_seq().await?;
            self.execute("insert into space_member_grants(member_id,module,level,change_seq) select m.id,$3,$4,$5 from space_members m where m.id=$2 and m.space_id=$1 on conflict(member_id,module) do update set level=excluded.level,change_seq=excluded.change_seq",
                vec![space.0.into(), member.0.into(), module.into(), level.into(), seq.into()]).await?;
        }
        Ok(())
    }
    pub async fn authorize_change(&self, space: SpaceId, change: &Change) -> Result<(), Error> {
        let actor = self.member(space);
        if change.requires_owner() && !actor.is_owner() {
            return Err(Error::not_found());
        }
        if let Change::Cancel { invitation } = change {
            self.one("select id from space_invitations where space_id=$1 and id=$2 and invited_by_member_id=$3",
                vec![space.0.into(), (*invitation).into(), actor.id().0.into()]).await?.ok_or_else(Error::not_found)?;
        }
        Ok(())
    }
    async fn active_target(&self, space: SpaceId, id: Uuid) -> Result<MemberId, Error> {
        self.one(
            "select id from space_members where space_id=$1 and id=$2 and status='active'",
            vec![space.0.into(), id.into()],
        )
        .await?
        .ok_or_else(Error::not_found)?;
        Ok(MemberId(id))
    }
    async fn cancel_runs(&self, space: SpaceId, member: Option<MemberId>) -> Result<(), Error> {
        self.execute("update agent_runs set status='cancelled',last_error='space_unavailable' where space_id=$1 and ($2::uuid is null or member_id=$2) and status in ('queued','running','paused','waiting_ai')",
            vec![space.0.into(), member.map(|m| m.0).into()]).await?;
        Ok(())
    }
    async fn depart(&self, space: SpaceId, member: MemberId, reason: &str) -> Result<(), Error> {
        let seq = self.next_seq().await?;
        self.execute("update space_members set status='left',left_at=now(),left_reason=$3,version=version+1,change_seq=$4 where space_id=$1 and id=$2 and status='active'",
            vec![space.0.into(), member.0.into(), reason.into(), seq.into()]).await?;
        self.cancel_runs(space, Some(member)).await?;
        self.execute("update space_invitations set status='cancelled',decided_at=now() where space_id=$1 and invited_by_member_id=$2 and status='pending'",
            vec![space.0.into(), member.0.into()]).await?;
        Ok(())
    }
    fn version(&self, current: &Value, expected: i32) -> Result<(), Error> {
        if current["version"].as_i64() != Some(i64::from(expected)) {
            return Err(Error {
                status: 409,
                code: "version_conflict",
                current: Some(current.clone()),
                errors: None,
                retry_after: None,
                space_unavailable: false,
            });
        }
        Ok(())
    }
    /// Called by the API service only after current authorization and idempotency replay.
    pub async fn apply_change(
        &self,
        space: SpaceId,
        change: Change,
        request: Uuid,
    ) -> Result<Reply, Error> {
        self.assert_write();
        let actor = self.member(space).id();
        let current = self.space(space).await?;
        match change {
            Change::Rename {
                name,
                accent_color,
                expected_version,
            } => {
                self.version(&current, expected_version)?;
                if name.as_ref().is_some_and(|s| !valid_name(s, 40))
                    || accent_color
                        .as_ref()
                        .is_some_and(|s| !SPACE_ACCENT_KEYS.contains(&s.as_str()))
                    || (name.is_none() && accent_color.is_none())
                {
                    return Err(Error::invalid());
                }
                let seq = self.next_seq().await?;
                self.execute("update spaces set name=coalesce($2,name),accent_color=coalesce($3,accent_color),version=version+1,change_seq=$4 where id=$1",
                    vec![space.0.into(), name.into(), accent_color.into(), seq.into()]).await?;
                self.event(space, actor, None, "rename", request).await?;
                Ok(Reply::ok(self.space(space).await?))
            }
            Change::DisplayName {
                display_name,
                expected_version,
            } => {
                let member = self.member_view(space, actor).await?;
                self.version(&member, expected_version)?;
                if !valid_name(&display_name, 20) {
                    return Err(Error::invalid());
                }
                let seq = self.next_seq().await?;
                self.execute("update space_members set display_name=$3,version=version+1,change_seq=$4 where space_id=$1 and id=$2",
                    vec![space.0.into(), actor.0.into(), display_name.into(), seq.into()]).await?;
                Ok(Reply::ok(self.member_view(space, actor).await?))
            }
            Change::Invite { username } => {
                if current["is_default"] == true {
                    return Err(Error::new(422, "default_space_forbidden"));
                }
                let invitee = self.one("select u.id from users u where lower(u.username)=lower($2) and u.disabled_at is null and u.id<>$3 and not exists(select 1 from space_members m where m.space_id=$1 and m.user_id=u.id and m.status='active')",
                    vec![space.0.into(), username.trim().into(), self.member(space).user_id().0.into()]).await?.ok_or_else(Error::invalid)?;
                let user: Uuid = invitee.try_get("", "id")?;
                if let Some(row) = self.one("select to_jsonb(i) value from space_invitations i where space_id=$1 and invitee_user_id=$2 and status='pending'", vec![space.0.into(), user.into()]).await? {
                    return Ok(Reply::ok(normalize_fields(row.try_get("", "value")?, &["created_at", "decided_at"])?));
                }
                let row = self.one("insert into space_invitations(space_id,invitee_user_id,invited_by_member_id,status) values($1,$2,$3,'pending') returning to_jsonb(space_invitations) value",
                    vec![space.0.into(), user.into(), actor.0.into()]).await?.ok_or_else(Error::internal)?;
                self.event(space, actor, None, "invite", request).await?;
                Ok(Reply {
                    status: 201,
                    body: normalize_fields(
                        row.try_get("", "value")?,
                        &["created_at", "decided_at"],
                    )?,
                })
            }
            Change::Cancel { invitation } => {
                self.execute("update space_invitations set status='cancelled',decided_at=now() where space_id=$1 and id=$2 and status='pending'", vec![space.0.into(), invitation.into()]).await?;
                let row = self
                    .one(
                        "select status from space_invitations where space_id=$1 and id=$2",
                        vec![space.0.into(), invitation.into()],
                    )
                    .await?
                    .ok_or_else(Error::not_found)?;
                let status: String = row.try_get("", "status")?;
                if status != "cancelled" {
                    return Err(Error::conflict(json!({"status":status})));
                }
                Ok(Reply::ok(json!({"status":status})))
            }
            Change::Leave | Change::Remove { .. } => {
                let removing = matches!(change, Change::Remove { .. });
                let target = if let Change::Remove { member } = change {
                    if member == actor.0 {
                        return Err(Error::invalid());
                    }
                    self.active_target(space, member).await?
                } else {
                    actor
                };
                if !removing && current["is_default"] == true {
                    return Err(Error::new(422, "default_space_forbidden"));
                }
                let owners = self.one("select count(*)::bigint n from space_members where space_id=$1 and status='active' and role='owner' and id<>$2", vec![space.0.into(), target.0.into()]).await?.ok_or_else(Error::internal)?;
                let target_owner = self
                    .one(
                        "select role='owner' owner from space_members where space_id=$1 and id=$2",
                        vec![space.0.into(), target.0.into()],
                    )
                    .await?
                    .ok_or_else(Error::not_found)?;
                if target_owner.try_get::<bool>("", "owner")?
                    && owners.try_get::<i64>("", "n")? == 0
                {
                    return Err(Error::new(409, "space_last_owner"));
                }
                self.depart(space, target, if removing { "removed" } else { "left" })
                    .await?;
                self.event(
                    space,
                    actor,
                    Some(target),
                    if removing { "remove" } else { "leave" },
                    request,
                )
                .await?;
                Ok(Reply::ok(json!({"status":"left"})))
            }
            Change::Transfer { member } => {
                if member == actor.0 {
                    return Err(Error::invalid());
                }
                let target = self.active_target(space, member).await?;
                for (id, role, level) in [(actor, "member", "write"), (target, "owner", "manage")] {
                    let seq = self.next_seq().await?;
                    self.execute("update space_members set role=$3,version=version+1,change_seq=$4 where space_id=$1 and id=$2", vec![space.0.into(), id.0.into(), role.into(), seq.into()]).await?;
                    self.grant(space, id, level).await?;
                }
                self.event(space, actor, Some(target), "transfer", request)
                    .await?;
                Ok(Reply::ok(json!({"owner_member_id":target.0})))
            }
            Change::Delete { name } => {
                if current["is_default"] == true {
                    return Err(Error::new(422, "default_space_forbidden"));
                }
                let row = self.one("select count(*)::bigint n from space_members where space_id=$1 and status='active'", vec![space.0.into()]).await?.ok_or_else(Error::internal)?;
                if row.try_get::<i64>("", "n")? != 1 {
                    return Err(Error::new(409, "space_not_empty"));
                }
                if current["name"].as_str() != Some(name.as_str()) {
                    return Err(Error::new(422, "space_name_mismatch"));
                }
                let seq = self.next_seq().await?;
                self.execute("update spaces set deleted_at=now(),version=version+1,change_seq=$2 where id=$1", vec![space.0.into(), seq.into()]).await?;
                self.depart(space, actor, "space_deleted").await?;
                self.cancel_runs(space, None).await?;
                self.execute("update space_invitations set status='cancelled',decided_at=now() where space_id=$1 and status='pending'", vec![space.0.into()]).await?;
                self.event(space, actor, None, "delete", request).await?;
                Ok(Reply::ok(json!({"status":"deleted"})))
            }
        }
    }
}

impl AppDb {
    /// Identity metadata is used only to discover the caller's permitted space IDs.
    pub async fn list_spaces(&self, user: UserId) -> Result<Value, Error> {
        let ids = self.connection.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select m.space_id from space_members m join spaces s on s.id=m.space_id where m.user_id=$1 and m.status='active' and s.deleted_at is null order by m.space_id", [user.0.into()])).await?;
        let mut result = Vec::new();
        for row in ids {
            let space = SpaceId(row.try_get("", "space_id")?);
            let tx = match SpaceTx::begin(self, user, &[(space, None)], Mode::Read).await {
                Ok(tx) => tx,
                Err(BeginError::NotFound) => continue, // Removed between discovery and membership validation.
                Err(error) => return Err(error.into()),
            };
            let row = tx.one("select jsonb_build_object('id',s.id,'name',s.name,'accent_color',s.accent_color,'currency',s.currency,'timezone',s.timezone,'is_default',s.is_default,'version',s.version,'role',m.role,'join_epoch',m.join_epoch,'member_id',m.id,'modules',jsonb_build_object('ledger',coalesce((select level from space_member_grants where member_id=m.id and module='ledger'),'none'),'documents',coalesce((select level from space_member_grants where member_id=m.id and module='documents'),'none')),'members',(select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'display_name',a.display_name,'role',a.role,'status',a.status,'version',a.version) order by a.id),'[]'::jsonb) from space_members a where a.space_id=s.id)) value from spaces s join space_members m on m.space_id=s.id where s.id=$1 and s.deleted_at is null and m.user_id=$2 and m.status='active'", vec![space.0.into(), user.0.into()]).await?;
            if let Some(row) = row {
                result.push(row.try_get::<Value>("", "value")?);
            }
            tx.commit().await?;
        }
        Ok(json!({"spaces":result}))
    }
    pub async fn create_space(
        &self,
        user: UserId,
        display_name: &str,
        input: CreateSpace,
        operation: &Idempotency,
        request: Uuid,
    ) -> Result<Reply, Error> {
        let space = SpaceId(input.id);
        let tx = SpaceTx::bootstrap(self, space).await?;
        let existing = tx.one("select s.created_by_user_id,m.status,s.deleted_at is not null deleted from spaces s left join space_members m on m.space_id=s.id and m.user_id=$2 where s.id=$1", vec![space.0.into(), user.0.into()]).await?;
        if let Some(row) = &existing {
            if row.try_get::<Uuid>("", "created_by_user_id")? != user.0 {
                return Err(Error::new(422, "id_taken"));
            }
            if row.try_get::<Option<String>>("", "status")?.as_deref() != Some("active")
                || row.try_get::<bool>("", "deleted")?
            {
                return Err(Error::not_found());
            }
        }
        if let Some(reply) = tx.replay(user, operation).await? {
            tx.commit().await?;
            return Ok(reply);
        }
        if existing.is_some() {
            return Err(Error::new(422, "id_taken"));
        }
        if input.id.get_version_num() != 7
            || !valid_name(&input.name, 40)
            || !SPACE_ACCENT_KEYS.contains(&input.accent_color.as_str())
            || !["CNY", "HKD", "USD", "EUR", "GBP", "JPY"].contains(&input.currency.as_str())
        {
            return Err(Error::invalid());
        }
        let timezone = tx
            .one(
                "select 1 from pg_catalog.pg_timezone_names where name=$1",
                vec![input.timezone.clone().into()],
            )
            .await?;
        if timezone.is_none() {
            return Err(Error::invalid());
        }
        let plan = SpaceInit {
            space_id: space,
            user_id: user,
            name: input.name,
            accent: input.accent_color,
            currency: input.currency,
            timezone: input.timezone,
            is_default: false,
            display_name: display_name.to_owned(),
            presets: PRESETS
                .iter()
                .map(|preset| PresetSeed {
                    id: Uuid::now_v7(),
                    preset_key: preset.preset_key.into(),
                })
                .collect(),
        };
        // Same transaction adapter and SECURITY DEFINER primitive as S1.
        let member = tx.initialize_space(&plan).await?;
        tx.event(space, member, None, "create", request).await?;
        let reply = Reply {
            status: 201,
            body: tx.space(space).await?,
        };
        tx.remember(user, operation, &reply).await?;
        tx.commit().await?;
        Ok(reply)
    }
    pub async fn received_invitations(&self, user: UserId) -> Result<Value, Error> {
        // The explicit invitation grants access to these two labels only, not space content.
        let rows = self.connection.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select i.id,s.name space_name,m.display_name inviter_display_name from space_invitations i join spaces s on s.id=i.space_id join space_members m on m.id=i.invited_by_member_id and m.space_id=i.space_id where i.invitee_user_id=$1 and i.status='pending' and s.deleted_at is null and m.status='active' order by i.created_at,i.id", [user.0.into()])).await?;
        let mut invitations = Vec::new();
        for row in rows {
            invitations.push(json!({"id":row.try_get::<Uuid>("","id")?,"space_name":row.try_get::<String>("","space_name")?,"inviter_display_name":row.try_get::<String>("","inviter_display_name")?}));
        }
        Ok(json!({"invitations":invitations}))
    }
    pub async fn decide_invitation(
        &self,
        user: UserId,
        invitation: Uuid,
        decision: Decision,
        operation: &Idempotency,
        request: Uuid,
    ) -> Result<Reply, Error> {
        // Discovery is recipient-scoped metadata. It is never trusted after taking the space lock.
        let row = self
            .connection
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select space_id from space_invitations where id=$1 and invitee_user_id=$2",
                [invitation.into(), user.0.into()],
            ))
            .await?
            .ok_or_else(Error::not_found)?;
        let space = SpaceId(row.try_get("", "space_id")?);
        let tx = SpaceTx::bootstrap(self, space).await?;
        let row = tx.one("select i.status,i.invited_by_member_id,s.deleted_at is not null deleted,m.status='active' inviter_active from space_invitations i join spaces s on s.id=i.space_id join space_members m on m.id=i.invited_by_member_id and m.space_id=i.space_id where i.space_id=$1 and i.id=$2 and i.invitee_user_id=$3", vec![space.0.into(), invitation.into(), user.0.into()]).await?.ok_or_else(Error::not_found)?;
        let current: String = row.try_get("", "status")?;
        // The inviter authorizes a pending join, not retries of a completed join.
        // Space deletion always invalidates access, including accepted replays.
        let space_deleted = row.try_get::<bool>("", "deleted")?;
        let inviter_left = current == "pending" && !row.try_get::<bool>("", "inviter_active")?;
        if space_deleted || inviter_left {
            tx.execute("update space_invitations set status='cancelled',decided_at=now() where space_id=$1 and id=$2 and status='pending'", vec![space.0.into(), invitation.into()]).await?;
            tx.commit().await?; // Preserve invalidation even though the HTTP response is an error.
            return Err(Error::not_found());
        }
        if current != "pending" && current != decision.status() {
            return Err(Error::not_found());
        }
        let accepted_epoch = if current == "accepted" {
            let member = tx.one("select join_epoch from space_members where space_id=$1 and user_id=$2 and status='active'", vec![space.0.into(), user.0.into()]).await?.ok_or_else(Error::not_found)?;
            Some(member.try_get::<i32>("", "join_epoch")?)
        } else {
            None
        };
        if let Some(reply) = tx.replay(user, operation).await? {
            if accepted_epoch
                .is_some_and(|epoch| reply.body["join_epoch"].as_i64() != Some(i64::from(epoch)))
            {
                return Err(Error::new(409, "membership_changed"));
            }
            tx.commit().await?;
            return Ok(reply);
        }
        let changed = tx.execute("update space_invitations set status=$3,decided_at=now() where space_id=$1 and id=$2 and status='pending'", vec![space.0.into(), invitation.into(), decision.status().into()]).await?;
        // On zero affected rows use current state; never create/modify a member twice.
        let actual = tx
            .one(
                "select status from space_invitations where space_id=$1 and id=$2",
                vec![space.0.into(), invitation.into()],
            )
            .await?
            .ok_or_else(Error::not_found)?;
        let status: String = actual.try_get("", "status")?;
        if status != decision.status() {
            return Err(Error::not_found());
        }
        let mut body = json!({"status":status});
        if decision == Decision::Accept && changed == 1 {
            let previous = tx
                .one(
                    "select id,status from space_members where space_id=$1 and user_id=$2",
                    vec![space.0.into(), user.0.into()],
                )
                .await?;
            if previous.as_ref().is_some_and(|r| {
                r.try_get::<String>("", "status")
                    .is_ok_and(|s| s == "active")
            }) {
                return Err(Error::invalid());
            }
            let seq = tx.next_seq().await?;
            let member = if let Some(previous) = previous {
                let id: Uuid = previous.try_get("", "id")?;
                tx.execute("update space_members set status='active',role='member',join_epoch=join_epoch+1,joined_at=now(),left_at=null,left_reason=null,version=version+1,change_seq=$3 where space_id=$1 and id=$2", vec![space.0.into(), id.into(), seq.into()]).await?;
                MemberId(id)
            } else {
                let row = tx.one("insert into space_members(space_id,user_id,display_name,role,status,joined_at,change_seq) select $1,id,username,'member','active',now(),$3 from users where id=$2 returning id", vec![space.0.into(), user.0.into(), seq.into()]).await?.ok_or_else(Error::not_found)?;
                MemberId(row.try_get("", "id")?)
            };
            tx.allow_bootstrap_space(space).await?;
            tx.grant(space, member, "write").await?;
            // A retained member has an incremented epoch; new members start at one.
            let row = tx
                .one(
                    "select join_epoch from space_members where space_id=$1 and id=$2",
                    vec![space.0.into(), member.0.into()],
                )
                .await?
                .ok_or_else(Error::internal)?;
            let epoch: i32 = row.try_get("", "join_epoch")?;
            tx.event(
                space,
                member,
                Some(member),
                if epoch > 1 { "rejoin" } else { "join" },
                request,
            )
            .await?;
            body = json!({"status":"accepted","member_id":member.0,"join_epoch":epoch});
        } else if decision == Decision::Accept {
            let row = tx.one("select id,join_epoch from space_members where space_id=$1 and user_id=$2 and status='active'", vec![space.0.into(), user.0.into()]).await?.ok_or_else(Error::not_found)?;
            body = json!({"status":"accepted","member_id":row.try_get::<Uuid>("","id")?,"join_epoch":row.try_get::<i32>("","join_epoch")?});
        }
        let reply = Reply::ok(body);
        tx.remember(user, operation, &reply).await?;
        tx.commit().await?;
        Ok(reply)
    }
}
impl SpaceTx {
    pub async fn invitations(&self, space: SpaceId) -> Result<Value, Error> {
        self.member(space);
        let rows = self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select jsonb_build_object('id',i.id,'status',i.status,'invitee_username',u.username,'invited_by_member_id',i.invited_by_member_id,'created_at',i.created_at,'decided_at',i.decided_at) value from space_invitations i join users u on u.id=i.invitee_user_id where i.space_id=$1 order by i.created_at,i.id", [space.0.into()])).await?;
        let mut invitations = Vec::new();
        for row in rows {
            invitations.push(normalize_fields(
                row.try_get("", "value")?,
                &["created_at", "decided_at"],
            )?);
        }
        Ok(json!({"invitations":invitations}))
    }
}
