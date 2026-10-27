use super::{AppDb, Mode, SpaceTx, support};
use crate::{ledger::AuditCtx, sync::VisibleModules};
use anyhow::Result;
use jiabu_domain::{
    SpaceId,
    ledger::{CreateAccount, CreateTag},
};
use sea_orm::{ConnectionTrait, DbBackend, Statement};
use serde_json::json;
use std::{sync::Arc, time::Duration};
use tokio::sync::Notify;
use uuid::Uuid;
fn audit(tx: &SpaceTx, space: SpaceId) -> AuditCtx {
    AuditCtx {
        actor_member_id: Some(tx.member(space).id().0),
        run_id: None,
        request_id: Some(Uuid::now_v7()),
        via_api_key_id: None,
        via_api_key_name: None,
        now: chrono::Utc::now(),
        origin: "manual",
    }
}
#[tokio::test]
async fn space_sequence_order_matches_commit_order_without_cursor_holes() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20),async {
        let fixture=support::TestDb::new().await?;
        let seed=fixture.seed("sample","unused").await?;
        let db=AppDb::connect(&fixture.app_url).await?;
        let owner=fixture.owner().await?;
        let cursor:i64=sqlx::query_scalar("select last_value from change_seq").fetch_one(&owner).await?;
        let space=seed.space_id;let user=seed.user_id;
        let allocated=Arc::new(Notify::new());let release=Arc::new(Notify::new());
        let (first_db,first_entered,first_release)=(db.clone(),allocated.clone(),release.clone());
        let first=tokio::spawn(async move {
            let tx=SpaceTx::begin(&first_db,user,&[(space,None)],Mode::Write).await?;
            tx.ledger_create_tag(space,Uuid::now_v7(),CreateTag { id:None,name:"示例先取号后提交".into() },&audit(&tx,space)).await?;
            first_entered.notify_one();first_release.notified().await;
            tx.commit().await?;Ok::<_,anyhow::Error>(())
        });
        allocated.notified().await;
        let second_db=db.clone();let attempting=Arc::new(Notify::new());let second_attempt=attempting.clone();
        let mut second=tokio::spawn(async move {
            second_attempt.notify_one();
            let tx=SpaceTx::begin(&second_db,user,&[(space,None)],Mode::Write).await?;
            tx.ledger_create_tag(space,Uuid::now_v7(),CreateTag { id:None,name:"示例后取号先尝试提交".into() },&audit(&tx,space)).await?;
            tx.commit().await?;Ok::<_,anyhow::Error>(())
        });
        attempting.notified().await;
        // A real PostgreSQL lock barrier, not a timing guess. With the lock
        // removed, the second writer completes instead; continue into pull so
        // the test observes the skipped lower sequence rather than deadlocking.
        let mut finished=None;
        loop {
            tokio::select! {
                value=&mut second=>{ finished=Some(value?);break; },
                _=tokio::task::yield_now()=>{
                    let waiting:bool=sqlx::query_scalar("select exists(select 1 from pg_locks where database=(select oid from pg_database where datname=current_database()) and locktype='advisory' and not granted)").fetch_one(&owner).await?;
                    if waiting { break; }
                }
            }
        }
        let tx=SpaceTx::begin_snapshot(&db,user,space).await?;
        let mid=tx.sync_page(space,cursor,500,VisibleModules { ledger:true,documents:true }).await?;tx.commit().await?;
        release.notify_one();first.await??;
        match finished {Some(value)=>value?,None=>second.await??};
        let tx=SpaceTx::begin_snapshot(&db,user,space).await?;
        let end=tx.sync_page(space,mid.cursor,500,VisibleModules { ledger:true,documents:true }).await?;tx.commit().await?;
        let all=mid.changes.into_iter().chain(end.changes).collect::<Vec<_>>();
        assert_eq!(all.iter().filter(|r|r.entity=="tag").count(),2,"cursor skipped a late lower-sequence commit");
        assert_eq!(all.iter().filter(|r|r.entity=="entity_event").count(),2);
        assert!(all.windows(2).all(|w|w[0].change_seq<w[1].change_seq));
        owner.close().await;db.close().await?;Ok::<_,anyhow::Error>(())
    }).await??;
    Ok(())
}
#[tokio::test]
async fn pull_uses_repeatable_read_read_only_across_table_query_barrier() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20),async {
        let fixture=support::TestDb::new().await?;let seed=fixture.seed("sample","unused").await?;
        let db=AppDb::connect(&fixture.app_url).await?;let owner=fixture.owner().await?;
        let cursor:i64=sqlx::query_scalar("select last_value from change_seq").fetch_one(&owner).await?;
        let mut tx=SpaceTx::begin_snapshot(&db,seed.user_id,seed.space_id).await?;
        let settings=tx.tx.query_one_raw(Statement::from_string(DbBackend::Postgres,"select current_setting('transaction_isolation') isolation,current_setting('transaction_read_only') readonly".to_owned())).await?.unwrap();
        assert_eq!(settings.try_get::<String>("","isolation")?,"repeatable read");
        assert_eq!(settings.try_get::<String>("","readonly")?,"on");
        let entered=Arc::new(Notify::new());let release=Arc::new(Notify::new());
        tx.sync_gate=Some((entered.clone(),release.clone()));let space=seed.space_id;
        let reader=tokio::spawn(async move {
            let page=tx.sync_page(space,cursor,500,VisibleModules { ledger:true,documents:true }).await?;
            tx.commit().await?;Ok::<_,anyhow::Error>(page)
        });
        entered.notified().await; // accounts read completed, tags/events not read yet.
        let writer=SpaceTx::begin(&db,seed.user_id,&[(space,None)],Mode::Write).await?;
        let account:CreateAccount=serde_json::from_value(json!({"kind":"real","name":"示例快照账户","opening_on":"2026-10-01"}))?;
        writer.ledger_create_account(space,Uuid::now_v7(),account,&audit(&writer,space)).await?;
        writer.ledger_create_tag(space,Uuid::now_v7(),CreateTag { id:None,name:"示例快照标签".into() },&audit(&writer,space)).await?;
        writer.commit().await?;release.notify_one();
        let page=reader.await??;assert!(page.changes.is_empty());assert_eq!(page.cursor,cursor);
        let tx=SpaceTx::begin_snapshot(&db,seed.user_id,space).await?;
        let page=tx.sync_page(space,cursor,500,VisibleModules { ledger:true,documents:true }).await?;tx.commit().await?;
        assert_eq!(page.changes.len(),4);assert_eq!(page.changes[0].entity,"account");
        owner.close().await;db.close().await?;Ok::<_,anyhow::Error>(())
    }).await??;
    Ok(())
}

/// Compare full database rows, not just nonempty pull fixtures. Four ledger
/// results reject unknown fields; the other tables currently use generated
/// models (with explicit public projections for space/member identity data).
#[tokio::test]
async fn all_sync_table_columns_match_generated_models_and_strict_domain_results() -> Result<()> {
    use jiabu_domain::ledger::{Account, AllocationPlan, Record, Tag};
    use sea_orm::Iterable;
    use std::collections::BTreeSet;
    macro_rules! columns {
        ($entity:ident) => {
            crate::entity::$entity::Column::iter()
                .map(|column| sea_orm::sea_query::Iden::to_string(&column))
                .collect::<BTreeSet<_>>()
        };
    }
    let tables = [
        ("spaces", columns!(spaces), None),
        ("space_members", columns!(space_members), None),
        ("space_member_grants", columns!(space_member_grants), None),
        (
            "accounts",
            columns!(accounts),
            Some(serde_json::to_value(schemars::schema_for!(Account))?),
        ),
        (
            "allocation_plans",
            columns!(allocation_plans),
            Some(serde_json::to_value(schemars::schema_for!(AllocationPlan))?),
        ),
        (
            "tags",
            columns!(tags),
            Some(serde_json::to_value(schemars::schema_for!(Tag))?),
        ),
        (
            "records",
            columns!(records),
            Some(serde_json::to_value(schemars::schema_for!(Record))?),
        ),
        ("entity_events", columns!(entity_events), None),
        ("subjects", columns!(subjects), None),
        ("documents", columns!(documents), None),
        ("conversations", columns!(conversations), None),
        ("chat_entries", columns!(chat_entries), None),
    ];
    let fixture = support::TestDb::new().await?;
    let owner = fixture.owner().await?;
    for (table, generated, domain) in tables {
        let actual=sqlx::query_scalar::<_,String>("select column_name::text from information_schema.columns where table_schema='public' and table_name=$1")
            .bind(table).fetch_all(&owner).await?.into_iter().collect::<BTreeSet<_>>();
        assert!(!actual.is_empty(), "missing sync table {table}");
        assert_eq!(actual, generated, "regenerate entity for {table}");
        if let Some(schema) = domain {
            assert_eq!(
                schema["additionalProperties"], false,
                "{table} must reject unknown fields"
            );
            let fields = schema["properties"]
                .as_object()
                .unwrap()
                .keys()
                .cloned()
                .collect::<BTreeSet<_>>();
            assert_eq!(
                actual, fields,
                "update deny_unknown_fields domain result for {table}"
            );
        }
    }
    owner.close().await;
    Ok(())
}
