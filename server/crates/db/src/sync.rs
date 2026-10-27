//! Incremental reads. Filtering happens before LIMIT, inside one SpaceTx snapshot.
use crate::{DbErr, SpaceTx, json_time::normalize_fields, ledger::Entity};
use jiabu_domain::SpaceId;
use sea_orm::{ConnectionTrait, DbBackend, Statement};
use serde::Serialize;
use serde_json::Value;

// Ledger rows share the exact typed serialization used by tool results/current.
// Other modules have no domain result types yet: normalize only their SQL columns.
fn serialize_row(entity: &str, mut value: Value) -> Result<Value, DbErr> {
    let ledger = match entity {
        "account" => Some(Entity::Account),
        "allocation_plan" => Some(Entity::Plan),
        "tag" => Some(Entity::Tag),
        "record" => Some(Entity::Record),
        _ => None,
    };
    if let Some(entity) = ledger {
        return entity
            .serialize(value)
            .map_err(|_| DbErr::Custom("invalid sync entity".into()));
    }
    let fields: &[&str] = match entity {
        "space_member" => &["joined_at", "left_at"],
        "subject" => &["created_at", "updated_at", "archived_at", "deleted_at"],
        "document" | "chat_entry" => &["created_at", "updated_at"],
        "conversation" => &["created_at"],
        "entity_event" => &["at"],
        _ => &[],
    };
    if entity == "entity_event" {
        // Snapshots may be partial. Only known entity timestamp columns are
        // normalized; visibility/content/message and all other payloads are opaque.
        let fields: &[&str] = match value["entity_kind"].as_str() {
            Some("record" | "allocation_plan" | "document") => &["created_at", "updated_at"],
            Some("account") => &["created_at", "updated_at", "archived_at"],
            Some("tag") => &["deleted_at"],
            Some("subject") => &["created_at", "updated_at", "archived_at", "deleted_at"],
            _ => &[],
        };
        for key in ["before", "after"] {
            if let Some(snapshot) = value.get_mut(key) {
                *snapshot = normalize_fields(snapshot.take(), fields)?;
            }
        }
    }
    normalize_fields(value, fields)
}

#[derive(Clone, Copy)]
pub struct VisibleModules {
    pub ledger: bool,
    pub documents: bool,
}
#[derive(Debug, Serialize)]
pub struct SyncChange {
    pub entity: &'static str,
    pub data: Value,
    #[serde(skip)]
    pub change_seq: i64,
}
#[derive(Debug, Serialize)]
pub struct SyncPage {
    pub space_id: SpaceId,
    pub cursor: i64,
    pub has_more: bool,
    pub changes: Vec<SyncChange>,
}
impl SpaceTx {
    pub async fn sync_page(
        &self,
        space: SpaceId,
        cursor: i64,
        limit: u32,
        visible: VisibleModules,
    ) -> Result<SyncPage, DbErr> {
        let member = self.member(space);
        if cursor < 0 || !(1..=500).contains(&limit) {
            return Err(DbErr::Custom("invalid sync page".into()));
        }
        // Identifiers and predicates are constants, never supplied by the caller.
        let tables = [
            ("spaces", "space", "t.id=$1", true),
            ("space_members", "space_member", "t.space_id=$1", true),
            (
                "space_member_grants",
                "space_member_grant",
                "exists(select 1 from space_members m where m.id=t.member_id and m.space_id=$1)",
                true,
            ),
            ("accounts", "account", "t.space_id=$1", visible.ledger),
            (
                "allocation_plans",
                "allocation_plan",
                "t.space_id=$1",
                visible.ledger,
            ),
            ("tags", "tag", "t.space_id=$1", visible.ledger),
            ("records", "record", "t.space_id=$1", visible.ledger),
            (
                "entity_events",
                "entity_event",
                "t.space_id=$1",
                visible.ledger || visible.documents,
            ),
            ("subjects", "subject", "t.space_id=$1", visible.documents),
            ("documents", "document", "t.space_id=$1", visible.documents),
            (
                "conversations",
                "conversation",
                "t.space_id=$1 and t.member_id=$4",
                true,
            ),
            (
                "chat_entries",
                "chat_entry",
                "t.space_id=$1 and t.member_id=$4 and t.stream_status in ('paused','complete','interrupted','error')",
                true,
            ),
        ];
        let mut merged = Vec::new();
        for (table, entity, scope, enabled) in tables {
            if !enabled {
                continue;
            }
            // Metadata uses the S2 public projection, without account-level identity.
            let projection = match table {
                "spaces" => {
                    "jsonb_build_object('id',t.id,'name',t.name,'accent_color',t.accent_color,'currency',t.currency,'timezone',t.timezone,'is_default',t.is_default,'version',t.version,'change_seq',t.change_seq)"
                }
                "space_members" => {
                    "jsonb_build_object('id',t.id,'space_id',t.space_id,'display_name',t.display_name,'role',t.role,'status',t.status,'join_epoch',t.join_epoch,'joined_at',t.joined_at,'left_at',t.left_at,'left_reason',t.left_reason,'version',t.version,'change_seq',t.change_seq)"
                }
                _ => "to_jsonb(t)",
            };
            let filter = if table == "entity_events" {
                match (visible.ledger, visible.documents) {
                    (true, true) => {
                        " and t.entity_kind in ('record','account','allocation_plan','tag','document','subject')"
                    }
                    (true, false) => {
                        " and t.entity_kind in ('record','account','allocation_plan','tag')"
                    }
                    _ => " and t.entity_kind in ('document','subject')",
                }
            } else {
                ""
            };
            let sql = format!(
                "select t.change_seq,{projection} data from {table} t where {scope} and t.change_seq>$2{filter} order by t.change_seq limit $3"
            );
            let mut values = vec![space.0.into(), cursor.into(), (i64::from(limit) + 1).into()];
            if matches!(table, "conversations" | "chat_entries") {
                values.push(member.id().0.into());
            }
            for row in self
                .tx
                .query_all_raw(Statement::from_sql_and_values(
                    DbBackend::Postgres,
                    sql,
                    values,
                ))
                .await?
            {
                merged.push(SyncChange {
                    entity,
                    data: serialize_row(entity, row.try_get("", "data")?)?,
                    change_seq: row.try_get("", "change_seq")?,
                });
            }
            #[cfg(test)]
            if table == "accounts"
                && let Some((entered, release)) = &self.sync_gate
            {
                entered.notify_one();
                release.notified().await;
            }
        }
        merged.sort_by_key(|row| row.change_seq);
        let has_more = merged.len() > limit as usize;
        merged.truncate(limit as usize);
        let cursor = merged.last().map_or(cursor, |row| row.change_seq);
        Ok(SyncPage {
            space_id: space,
            cursor,
            has_more,
            changes: merged,
        })
    }
}
