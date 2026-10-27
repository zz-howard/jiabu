#[path = "../../../tests/support/mod.rs"]
mod support;
use crate::{AppDb, BeginError, Mode, SpaceTx};
use anyhow::Result;
use sea_orm::{ConnectOptions, ConnectionTrait, Database, DbBackend, Statement, TransactionTrait};
use sqlx::Row;
#[tokio::test]
async fn space_tx_membership_and_join_epoch() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let plan = fixture.seed("sample", "test-only-unused-hash").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let tx = SpaceTx::begin(
        &db,
        plan.user_id,
        &[(plan.space_id, Some(jiabu_domain::JoinEpoch(1)))],
        Mode::Write,
    )
    .await?;
    assert!(tx.member(plan.space_id).is_owner());
    assert!(tx.next_seq().await? > 0);
    tx.commit().await?;
    assert!(matches!(
        SpaceTx::begin(
            &db,
            plan.user_id,
            &[(plan.space_id, Some(jiabu_domain::JoinEpoch(2)))],
            Mode::Write
        )
        .await,
        Err(BeginError::MembershipChanged)
    ));
    let missing = jiabu_domain::SpaceId(uuid::Uuid::now_v7());
    assert!(matches!(
        SpaceTx::begin(
            &db,
            plan.user_id,
            &[
                (plan.space_id, Some(jiabu_domain::JoinEpoch(2))),
                (missing, None)
            ],
            Mode::Read
        )
        .await,
        Err(BeginError::NotFound)
    ));
    let owner = fixture.owner().await?;
    sqlx::query("update space_members set status='left' where space_id=$1")
        .bind(plan.space_id.0)
        .execute(&owner)
        .await?;
    assert!(matches!(
        SpaceTx::begin(&db, plan.user_id, &[(plan.space_id, None)], Mode::Read).await,
        Err(BeginError::NotFound)
    ));
    owner.close().await;
    db.close().await?;
    Ok(())
}
async fn count(connection: &impl ConnectionTrait) -> Result<i64> {
    let row = connection
        .query_one_raw(Statement::from_string(
            DbBackend::Postgres,
            "select count(*)::bigint n from tags".to_owned(),
        ))
        .await?
        .ok_or_else(|| anyhow::anyhow!("missing count"))?;
    Ok(row.try_get("", "n")?)
}
#[tokio::test]
async fn e2_rls_settings_never_leak() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let plan = fixture.seed("sample", "test-only-unused-hash").await?;
    let other = fixture.seed("another", "test-only-unused-hash").await?;
    let mut options = ConnectOptions::new(fixture.app_url.clone());
    options.max_connections(1).min_connections(1);
    let db = AppDb {
        connection: Database::connect(options).await?,
    };
    assert_eq!(count(&db.connection).await?, 0);
    let insert = format!(
        "insert into tags(id,space_id,preset_key,change_seq) values(uuidv7(),'{}','probe',1)",
        plan.space_id
    );
    assert!(
        db.connection
            .execute_raw(Statement::from_string(DbBackend::Postgres, insert))
            .await
            .is_err()
    );
    for outcome in ["commit", "rollback", "drop"] {
        let tx = SpaceTx::begin(&db, plan.user_id, &[(plan.space_id, None)], Mode::Write).await?;
        assert_eq!(count(&tx.tx).await?, 11);
        let local = uuid::Uuid::now_v7();
        for name in ["test-local", "test-updated"] {
            let seq = tx.next_seq().await?;
            tx.tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
                "insert into tags(id,space_id,name,change_seq) values($1,$2,$3,$4) on conflict(id) do update set name=excluded.name,change_seq=excluded.change_seq",
                [local.into(),plan.space_id.0.into(),name.into(),seq.into()])).await?;
        }
        assert_eq!(count(&tx.tx).await?, 12);
        tx.tx
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "delete from tags where id=$1",
                [local.into()],
            ))
            .await?;
        let locks = tx
            .tx
            .query_all_raw(Statement::from_string(
                DbBackend::Postgres,
                "select id from tags for update skip locked".to_owned(),
            ))
            .await?;
        assert_eq!(locks.len(), 11);
        let bad = Statement::from_sql_and_values(
            DbBackend::Postgres,
            "insert into tags(id,space_id,preset_key,change_seq) values($1,$2,'probe',1) on conflict(id) do update set preset_key='bad'",
            [other.presets[0].id.into(), other.space_id.0.into()],
        );
        // Use a savepoint so the expected RLS violation does not abort the outer transaction.
        let savepoint = tx.tx.begin().await?;
        assert!(savepoint.execute_raw(bad).await.is_err());
        savepoint.rollback().await?;
        match outcome {
            "commit" => tx.commit().await?,
            "rollback" => tx.rollback().await?,
            _ => drop(tx),
        }
        assert_eq!(count(&db.connection).await?, 0);
        let row = db
            .connection
            .query_one_raw(Statement::from_string(
                DbBackend::Postgres,
                "select jiabu_allowed_spaces()::text spaces".to_owned(),
            ))
            .await?
            .ok_or_else(|| anyhow::anyhow!("missing settings"))?;
        assert_eq!(row.try_get::<String>("", "spaces")?, "{}");
    }
    for outcome in ["commit", "rollback", "drop"] {
        let system = crate::SystemTx::begin(&db).await?;
        assert_eq!(count(&system.tx).await?, 22);
        match outcome {
            "commit" => system.commit().await?,
            "rollback" => system.rollback().await?,
            _ => drop(system),
        }
        assert_eq!(count(&db.connection).await?, 0);
    }
    assert!(
        db.connection
            .execute_raw(Statement::from_string(
                DbBackend::Postgres,
                "set role jiabu_owner".to_owned()
            ))
            .await
            .is_err()
    );
    let tx = db.connection.begin().await?;
    tx.execute_raw(Statement::from_string(
        DbBackend::Postgres,
        "set local row_security=off".to_owned(),
    ))
    .await?;
    assert!(count(&tx).await.is_err());
    tx.rollback().await?;
    db.close().await?;
    Ok(())
}
#[tokio::test]
async fn admin_cannot_read_content_or_secret_columns() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    fixture.seed("sample", "test-only-unused-hash").await?;
    let owner = fixture.owner().await?;
    sqlx::query("insert into agent_runs(space_id,member_id,conversation_id,assistant_message_id,input_entry_id,join_epoch,kind,status,agent_def_version,prompt_snapshot) select space_id,id,uuidv7(),uuidv7(),uuidv7(),join_epoch,'chat','queued','test-only',decode('00','hex') from space_members limit 1").execute(&owner).await?;
    owner.close().await;
    let admin = sqlx::PgPool::connect(&fixture.admin_url).await?;
    assert_eq!(
        sqlx::query("select id,status from agent_runs")
            .fetch_all(&admin)
            .await?
            .len(),
        1
    );
    for table in [
        "records",
        "entity_events",
        "accounts",
        "allocation_plans",
        "tags",
        "subjects",
        "documents",
        "space_invitations",
        "blobs",
        "blob_refs",
        "conversations",
        "chat_entries",
        "chat_stream_events",
        "chat_actions",
        "agent_run_items",
        "agent_tool_calls",
        "agent_prompt_snapshots",
        "idempotency",
        "api_key_audit",
        "template_snapshots",
    ] {
        let error = sqlx::query(sqlx::AssertSqlSafe(format!("select * from {table}")))
            .fetch_all(&admin)
            .await
            .unwrap_err();
        assert_eq!(
            error.as_database_error().and_then(|e| e.code()).as_deref(),
            Some("42501"),
            "{table}"
        );
    }
    for query in [
        "select password_hash from users",
        "select token_hash from sessions",
        "select token_hash from api_keys",
        "select accent_color from spaces",
        "select open_interrupt from agent_runs",
        "update ai_prices set model='bad'",
        "delete from admin_audit",
    ] {
        assert!(sqlx::query(query).execute(&admin).await.is_err(), "{query}");
    }
    let row = sqlx::query("select name from spaces")
        .fetch_one(&admin)
        .await?;
    assert_eq!(row.try_get::<String, _>("name")?, "示例空间");
    admin.close().await;
    Ok(())
}
#[tokio::test]
async fn account_initialization_is_atomic() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    fixture.seed("sample", "test-only-unused-hash").await?;
    let admin = fixture.admin().await?;
    assert!(
        admin
            .create(
                "sample",
                "unused",
                &support::plan("sample"),
                "test-operator"
            )
            .await
            .is_err()
    );
    let mut broken = support::plan("broken");
    broken.presets[1].id = broken.presets[0].id;
    assert!(
        admin
            .create("broken", "unused", &broken, "test-operator")
            .await
            .is_err()
    );
    let owner = fixture.owner().await?;
    for (table, expected) in [
        ("users", 1_i64),
        ("spaces", 1),
        ("space_members", 1),
        ("space_member_grants", 2),
        ("tags", 11),
        ("admin_audit", 1),
    ] {
        let count: i64 =
            sqlx::query_scalar(sqlx::AssertSqlSafe(format!("select count(*) from {table}")))
                .fetch_one(&owner)
                .await?;
        assert_eq!(count, expected, "{table}");
    }
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn changed_migration_is_rejected_by_migrate_and_startup_validation() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let dir = std::env::temp_dir().join(format!("jiabu-migration-{}", uuid::Uuid::now_v7()));
    std::fs::create_dir(&dir)?;
    for file in std::fs::read_dir(
        std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../migrations"),
    )? {
        let file = file?;
        let mut sql = std::fs::read_to_string(file.path())?;
        sql.push_str("\n-- deliberate checksum change\n");
        std::fs::write(dir.join(file.file_name()), sql)?;
    }
    let migrator = sqlx::migrate::Migrator::new(dir.as_path()).await?;
    let owner = fixture.owner().await?;
    let error = migrator.run(&owner).await.unwrap_err();
    assert!(error.to_string().contains("modified"));
    let error = jiabu_db_admin::migrations::validate(&owner, &migrator)
        .await
        .unwrap_err();
    assert!(error.to_string().contains("modified"));
    sqlx::query("update _sqlx_migrations set checksum=decode('00','hex') where version=1")
        .execute(&owner)
        .await?;
    let error = jiabu_db_admin::migrations::validate_startup(&fixture.app_url)
        .await
        .unwrap_err();
    assert!(error.to_string().contains("modified"));
    owner.close().await;
    std::fs::remove_dir_all(dir)?;
    Ok(())
}
#[tokio::test]
async fn purge_and_append_only_permissions() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let plan = fixture.seed("sample", "unused").await?;
    let app = sqlx::PgPool::connect(&fixture.app_url).await?;
    for table in [
        "entity_events",
        "space_events",
        "chat_actions",
        "api_key_audit",
        "agent_run_items",
    ] {
        assert!(
            sqlx::query(sqlx::AssertSqlSafe(format!("delete from {table}")))
                .execute(&app)
                .await
                .is_err()
        );
        assert!(
            sqlx::query(sqlx::AssertSqlSafe(format!(
                "update {table} set {}=null",
                if table == "agent_run_items" {
                    "provider_blob"
                } else {
                    "request_id"
                }
            )))
            .execute(&app)
            .await
            .is_err()
        );
    }
    assert!(
        sqlx::query("select purge_space($1)")
            .bind(plan.space_id.0)
            .execute(&app)
            .await
            .is_err()
    );
    let owner = fixture.owner().await?;
    sqlx::query("insert into entity_events(space_id,entity_kind,entity_id,kind,after,change_seq) values($1,'tag',$2,'create','{}',nextval('change_seq'))").bind(plan.space_id.0).bind(plan.presets[0].id).execute(&owner).await?;
    sqlx::query("insert into space_events(space_id,kind) values($1,'create')")
        .bind(plan.space_id.0)
        .execute(&owner)
        .await?;
    sqlx::query("insert into ai_calls(space_id,member_id,user_id,task_kind,provider_id,model,structured_mode,call_kind,outcome) select space_id,id,user_id,'chat','test-only','test-only','none','first','ok' from space_members where space_id=$1").bind(plan.space_id.0).execute(&owner).await?;
    sqlx::query("update spaces set deleted_at=now() where id=$1")
        .bind(plan.space_id.0)
        .execute(&owner)
        .await?;
    let mut system = crate::SystemTx::begin(&AppDb::connect(&fixture.app_url).await?).await?;
    system.lock_space(plan.space_id).await?;
    assert!(system.next_seq(plan.space_id).await? > 0);
    system.purge_space(plan.space_id).await?;
    system.commit().await?;
    let tags: i64 = sqlx::query_scalar("select count(*) from tags")
        .fetch_one(&owner)
        .await?;
    assert_eq!(tags, 0);
    let spaces: i64 = sqlx::query_scalar("select count(*) from spaces")
        .fetch_one(&owner)
        .await?;
    assert_eq!(spaces, 1);
    let members: i64 = sqlx::query_scalar("select count(*) from space_members")
        .fetch_one(&owner)
        .await?;
    assert_eq!(members, 1);
    for table in ["entity_events", "space_events"] {
        let n: i64 =
            sqlx::query_scalar(sqlx::AssertSqlSafe(format!("select count(*) from {table}")))
                .fetch_one(&owner)
                .await?;
        assert_eq!(n, 0);
    }
    let calls: i64 = sqlx::query_scalar("select count(*) from ai_calls")
        .fetch_one(&owner)
        .await?;
    assert_eq!(calls, 1);
    app.close().await;
    owner.close().await;
    Ok(())
}
#[tokio::test]
#[should_panic(expected = "change_seq requires a space write lock")]
async fn read_transaction_cannot_allocate_sequence() {
    let fixture = support::TestDb::new().await.unwrap();
    let plan = fixture.seed("sample", "unused").await.unwrap();
    let db = AppDb::connect(&fixture.app_url).await.unwrap();
    let tx = SpaceTx::begin(&db, plan.user_id, &[(plan.space_id, None)], Mode::Read)
        .await
        .unwrap();
    let _ = tx.next_seq().await;
}
#[tokio::test]
#[should_panic(expected = "change_seq requires this space lock")]
async fn system_transaction_cannot_allocate_sequence_before_lock() {
    let fixture = support::TestDb::new().await.unwrap();
    let db = AppDb::connect(&fixture.app_url).await.unwrap();
    let tx = crate::SystemTx::begin(&db).await.unwrap();
    let _ = tx
        .next_seq(jiabu_domain::SpaceId(uuid::Uuid::now_v7()))
        .await;
}

#[path = "tests/ledger.rs"]
mod ledger;
#[path = "tests/spaces.rs"]
mod spaces;
