use super::*;
use crate::tasks::test_support as support;
use anyhow::Result;
use jiabu_db::{Mode, SpaceTx, spaces::Idempotency};
use jiabu_domain::{
    SpaceId,
    spaces::{Change, CreateSpace, Decision},
};
use serde_json::Value;
use uuid::Uuid;

async fn seed_content(
    owner: &sqlx::PgPool,
    space: Uuid,
    member: Uuid,
    invitee: Uuid,
) -> Result<()> {
    let real = Uuid::now_v7();
    let purpose = Uuid::now_v7();
    for (id, kind, name) in [
        (real, "real", "示例资金账户"),
        (purpose, "purpose", "示例用途账户"),
    ] {
        sqlx::query("insert into accounts(id,space_id,kind,name,opening_on,created_by_member_id,change_seq,created_at,updated_at) values($1,$2,$3,$4,current_date,$5,nextval('change_seq'),now(),now())")
            .bind(id).bind(space).bind(kind).bind(name).bind(member).execute(owner).await?;
    }
    sqlx::query("insert into allocation_plans(account_id,space_id,amount_minor,day_of_month,next_run_on,change_seq,updated_at) values($1,$2,100,1,current_date,nextval('change_seq'),now())").bind(purpose).bind(space).execute(owner).await?;
    let expense = Uuid::now_v7();
    sqlx::query("insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,purpose_id,origin,created_by_member_id,change_seq,created_at,updated_at) values($1,$2,'expense',100,current_date,$3,$4,'manual',$5,nextval('change_seq'),now(),now())")
        .bind(expense).bind(space).bind(real).bind(purpose).bind(member).execute(owner).await?;
    sqlx::query("insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,purpose_id,refund_of_id,origin,created_by_member_id,change_seq,created_at,updated_at) values(uuidv7(),$1,'refund',50,current_date,$2,$3,$4,'manual',$5,nextval('change_seq'),now(),now())")
        .bind(space).bind(real).bind(purpose).bind(expense).bind(member).execute(owner).await?;
    sqlx::query("insert into entity_events(space_id,entity_kind,entity_id,kind,after,actor_member_id,change_seq) values($1,'record',$2,'create','{}',$3,nextval('change_seq'))").bind(space).bind(expense).bind(member).execute(owner).await?;
    sqlx::query("insert into subjects(id,space_id,kind,name,created_by_member_id,change_seq,created_at,updated_at) values(uuidv7(),$1,'other','示例对象',$2,nextval('change_seq'),now(),now())").bind(space).bind(member).execute(owner).await?;
    sqlx::query("insert into documents(id,space_id,title,event_date,content,origin,created_by_member_id,updated_by_member_id,change_seq,created_at,updated_at) values(uuidv7(),$1,'示例资料',current_date,'{}','manual',$2,$2,nextval('change_seq'),now(),now())").bind(space).bind(member).execute(owner).await?;
    sqlx::query("insert into blobs(sha256,mime,bytes) values(decode(repeat('00',32),'hex'),'image/jpeg',100)").execute(owner).await?;
    sqlx::query("insert into blob_refs(space_id,module,sha256,uploaded_by_member_id) values($1,'ledger',decode(repeat('00',32),'hex'),$2)").bind(space).bind(member).execute(owner).await?;
    let conversation = Uuid::now_v7();
    let message = Uuid::now_v7();
    let run = Uuid::now_v7();
    sqlx::query("insert into conversations(id,space_id,member_id,change_seq) values($1,$2,$3,nextval('change_seq'))").bind(conversation).bind(space).bind(member).execute(owner).await?;
    sqlx::query("insert into chat_entries(id,space_id,member_id,conversation_id,role,protocol_version,message,fallback_text,stream_status,change_seq,created_at,updated_at) values($1,$2,$3,$4,'assistant','test-only','{}','示例回复','paused',nextval('change_seq'),now(),now())")
        .bind(message).bind(space).bind(member).bind(conversation).execute(owner).await?;
    sqlx::query("insert into chat_stream_events(message_id,seq,space_id,member_id,event) values($1,1,$2,$3,'{}')").bind(message).bind(space).bind(member).execute(owner).await?;
    sqlx::query("insert into chat_actions(id,space_id,member_id,message_id,block_id,action_type,target,payload,status,result,actor_member_id) values(uuidv7(),$1,$2,$3,'sample','sample','sample','{}','done','{}',$2)").bind(space).bind(member).bind(message).execute(owner).await?;
    sqlx::query("insert into agent_runs(id,space_id,member_id,conversation_id,assistant_message_id,input_entry_id,join_epoch,kind,status,agent_def_version,prompt_snapshot) values($1,$2,$3,$4,$5,uuidv7(),1,'chat','paused','test-only',decode('00','hex'))")
        .bind(run).bind(space).bind(member).bind(conversation).bind(message).execute(owner).await?;
    sqlx::query("insert into agent_runs(space_id,member_id,conversation_id,assistant_message_id,input_entry_id,join_epoch,retry_of_run_id,kind,status,agent_def_version,prompt_snapshot) values($1,$2,$3,uuidv7(),uuidv7(),1,$4,'chat','queued','test-only',decode('00','hex'))")
        .bind(space).bind(member).bind(conversation).bind(run).execute(owner).await?;
    sqlx::query("insert into agent_run_items(run_id,idx,kind,payload) values($1,1,'note','{}')")
        .bind(run)
        .execute(owner)
        .await?;
    sqlx::query("insert into agent_tool_calls(run_id,call_id,tool,tool_schema_version,args,args_hash,effect,status,idempotency_key) values($1,'sample','sample',1,'{}',decode('00','hex'),'read','succeeded',uuidv7())").bind(run).execute(owner).await?;
    sqlx::query("insert into ai_step_meters(run_id,step_no,step_kind,status,started_at) values($1,1,'sample','awaiting_user',now())").bind(run).execute(owner).await?;
    sqlx::query("insert into ai_calls(run_id,space_id,member_id,user_id,task_kind,provider_id,model,structured_mode,call_kind,outcome) select $1,$2,$3,user_id,'chat','test-only','test-only','none','first','ok' from space_members where id=$3")
        .bind(run).bind(space).bind(member).execute(owner).await?;
    let key: Uuid=sqlx::query_scalar("insert into api_keys(user_id,name,token_hash,display_prefix,scope) select user_id,'示例密钥',decode(repeat('01',32),'hex'),'jiabu_pat_sample','read' from space_members where id=$1 returning id").bind(member).fetch_one(owner).await?;
    sqlx::query("insert into api_key_audit(api_key_id,user_id,space_id,operation,effect,outcome) select $1,user_id,$2,'sample','read','ok' from space_members where id=$3").bind(key).bind(space).bind(member).execute(owner).await?;
    sqlx::query("insert into space_invitations(space_id,invitee_user_id,invited_by_member_id,status) values($1,$2,$3,'pending')").bind(space).bind(invitee).bind(member).execute(owner).await?;
    Ok(())
}
const CONTENT_TABLES: &[&str] = &[
    "accounts",
    "allocation_plans",
    "tags",
    "records",
    "subjects",
    "documents",
    "blob_refs",
    "entity_events",
    "conversations",
    "chat_entries",
    "chat_stream_events",
    "chat_actions",
    "agent_runs",
    "space_invitations",
    "space_events",
    "api_key_audit",
];
#[tokio::test]
async fn startup_sweep_purges_all_content_and_retains_metadata_and_usage() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let host = fixture.seed("host", "unused").await?;
    let guest = fixture.seed("guest", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let space = SpaceId(Uuid::now_v7());
    let key = Idempotency {
        key: Uuid::now_v7().to_string(),
        hash: vec![1],
    };
    db.create_space(
        host.user_id,
        "host",
        CreateSpace {
            id: space.0,
            name: "示例待删空间".into(),
            accent_color: "pine".into(),
            currency: "CNY".into(),
            timezone: "UTC".into(),
        },
        &key,
        Uuid::now_v7(),
    )
    .await?;
    let owner = fixture.owner().await?;
    let member: Uuid = sqlx::query_scalar("select id from space_members where space_id=$1")
        .bind(space.0)
        .fetch_one(&owner)
        .await?;
    seed_content(&owner, space.0, member, guest.user_id.0).await?;
    for table in CONTENT_TABLES {
        let n: i64 = sqlx::query_scalar(sqlx::AssertSqlSafe(format!(
            "select count(*) from {table} where space_id=$1"
        )))
        .bind(space.0)
        .fetch_one(&owner)
        .await?;
        assert!(n > 0, "fixture must exercise {table}");
    }
    let tx = SpaceTx::begin(&db, host.user_id, &[(space, None)], Mode::Write).await?;
    tx.apply_change(
        space,
        Change::Delete {
            name: "示例待删空间".into(),
        },
        Uuid::now_v7(),
    )
    .await?;
    tx.commit().await?;
    let invitation: Uuid = sqlx::query_scalar("select id from space_invitations where space_id=$1")
        .bind(space.0)
        .fetch_one(&owner)
        .await?;
    let tombstone: Value = sqlx::query_scalar("select to_jsonb(s) from spaces s where id=$1")
        .bind(space.0)
        .fetch_one(&owner)
        .await?;
    let retained_member: Value =
        sqlx::query_scalar("select to_jsonb(m) from space_members m where id=$1")
            .bind(member)
            .fetch_one(&owner)
            .await?;
    assert!(!tombstone["deleted_at"].is_null());
    assert_eq!(retained_member["left_reason"], "space_deleted");
    let scan = SystemTx::begin(&db).await?;
    assert_eq!(scan.spaces_to_purge().await?, vec![space]);
    scan.commit().await?;
    // No notification is sent: this is the same entry point the process uses on startup.
    sqlx::query("revoke execute on function purge_space(uuid) from jiabu_app")
        .execute(&owner)
        .await?;
    assert!(purge_deleted_spaces_once(&db).await.is_err());
    let remaining: i64 = sqlx::query_scalar("select count(*) from tags where space_id=$1")
        .bind(space.0)
        .fetch_one(&owner)
        .await?;
    assert_eq!(remaining, 11);
    sqlx::query("grant execute on function purge_space(uuid) to jiabu_app")
        .execute(&owner)
        .await?;
    purge_deleted_spaces_once(&db).await?;
    purge_deleted_spaces_once(&db).await?;
    for table in CONTENT_TABLES {
        let n: i64 = sqlx::query_scalar(sqlx::AssertSqlSafe(format!(
            "select count(*) from {table} where space_id=$1"
        )))
        .bind(space.0)
        .fetch_one(&owner)
        .await?;
        assert_eq!(n, 0, "{table}");
    }
    for table in ["agent_run_items", "agent_tool_calls", "ai_step_meters"] {
        let n: i64 =
            sqlx::query_scalar(sqlx::AssertSqlSafe(format!("select count(*) from {table}")))
                .fetch_one(&owner)
                .await?;
        assert_eq!(n, 0, "{table}");
    }
    let grants: i64 =
        sqlx::query_scalar("select count(*) from space_member_grants where member_id=$1")
            .bind(member)
            .fetch_one(&owner)
            .await?;
    assert_eq!(grants, 0);
    let after: Value = sqlx::query_scalar("select to_jsonb(s) from spaces s where id=$1")
        .bind(space.0)
        .fetch_one(&owner)
        .await?;
    assert_eq!(after, tombstone);
    let after: Value = sqlx::query_scalar("select to_jsonb(m) from space_members m where id=$1")
        .bind(member)
        .fetch_one(&owner)
        .await?;
    assert_eq!(after, retained_member);
    let usage: i64 = sqlx::query_scalar("select count(*) from ai_calls where space_id=$1")
        .bind(space.0)
        .fetch_one(&owner)
        .await?;
    assert_eq!(usage, 1);
    let decision_key = Idempotency {
        key: Uuid::now_v7().to_string(),
        hash: vec![3],
    };
    let missing = db
        .decide_invitation(
            guest.user_id,
            invitation,
            Decision::Accept,
            &decision_key,
            Uuid::now_v7(),
        )
        .await;
    assert_eq!(
        missing
            .err()
            .ok_or_else(|| anyhow::anyhow!("accepted purged invitation"))?
            .code,
        "not_found"
    );
    let unaffected: i64 = sqlx::query_scalar("select count(*) from tags where space_id=$1")
        .bind(host.space_id.0)
        .fetch_one(&owner)
        .await?;
    assert_eq!(unaffected, 11);
    let scan = SystemTx::begin(&db).await?;
    assert!(scan.spaces_to_purge().await?.is_empty());
    scan.commit().await?;
    assert!(matches!(
        SpaceTx::begin(&db, host.user_id, &[(space, None)], Mode::Read).await,
        Err(jiabu_db::BeginError::NotFound)
    ));
    owner.close().await;
    db.close().await?;
    Ok(())
}

#[tokio::test]
async fn deletion_notification_wakes_worker() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let host = fixture.seed("host", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let owner = fixture.owner().await?;
    let space = SpaceId(Uuid::now_v7());
    let key = Idempotency {
        key: Uuid::now_v7().to_string(),
        hash: vec![1],
    };
    db.create_space(
        host.user_id,
        "host",
        CreateSpace {
            id: space.0,
            name: "示例通知空间".into(),
            accent_color: "pine".into(),
            currency: "CNY".into(),
            timezone: "UTC".into(),
        },
        &key,
        Uuid::now_v7(),
    )
    .await?;
    let startup = SpaceId(Uuid::now_v7());
    let startup_key = Idempotency {
        key: Uuid::now_v7().to_string(),
        hash: vec![2],
    };
    db.create_space(
        host.user_id,
        "host",
        CreateSpace {
            id: startup.0,
            name: "示例启动空间".into(),
            accent_color: "pine".into(),
            currency: "CNY".into(),
            timezone: "UTC".into(),
        },
        &startup_key,
        Uuid::now_v7(),
    )
    .await?;
    let tx = SpaceTx::begin(&db, host.user_id, &[(startup, None)], Mode::Write).await?;
    tx.apply_change(
        startup,
        Change::Delete {
            name: "示例启动空间".into(),
        },
        Uuid::now_v7(),
    )
    .await?;
    tx.commit().await?;
    let worker_signal = Arc::new(Notify::new());
    let worker = tokio::spawn(run(db.clone(), worker_signal.clone()));
    // Wait until the initial scan has purged the startup sentinel. The live space
    // is deleted later, so it must be picked up by a notification, not that scan.
    let ready = tokio::time::timeout(Duration::from_secs(3), async {
        loop {
            let n: i64 = sqlx::query_scalar("select count(*) from tags where space_id=$1")
                .bind(startup.0)
                .fetch_one(&owner)
                .await?;
            if n == 0 {
                break anyhow::Ok(());
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await;
    if !matches!(&ready, Ok(Ok(()))) {
        worker.abort();
        let _ = worker.await;
        ready??;
        return Ok(());
    }
    let tx = SpaceTx::begin(&db, host.user_id, &[(space, None)], Mode::Write).await?;
    tx.apply_change(
        space,
        Change::Delete {
            name: "示例通知空间".into(),
        },
        Uuid::now_v7(),
    )
    .await?;
    tx.commit().await?;
    worker_signal.notify_one();
    let result = tokio::time::timeout(Duration::from_secs(3), async {
        loop {
            let n: i64 = sqlx::query_scalar("select count(*) from tags where space_id=$1")
                .bind(space.0)
                .fetch_one(&owner)
                .await?;
            if n == 0 {
                break anyhow::Ok(());
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await;
    worker.abort();
    let _ = worker.await;
    result??;
    owner.close().await;
    db.close().await?;
    Ok(())
}
