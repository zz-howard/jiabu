use super::*;
use crate::spaces::{Error, Idempotency, Reply};
use jiabu_domain::{
    SpaceId, UserId,
    spaces::{Change, CreateSpace, Decision},
};
use serde_json::{Value, json};
use std::time::Duration;
use uuid::Uuid;

fn operation() -> Idempotency {
    let key = Uuid::now_v7().to_string();
    Idempotency {
        hash: key.as_bytes().to_vec(),
        key,
    }
}
async fn change(db: &AppDb, user: UserId, space: SpaceId, command: Change) -> Result<Reply, Error> {
    let tx = SpaceTx::begin(db, user, &[(space, None)], Mode::Write).await?;
    tx.authorize_change(space, &command).await?;
    let operation = operation();
    assert!(tx.replay(user, &operation).await?.is_none());
    let result = tx.apply_change(space, command, Uuid::now_v7()).await?;
    tx.remember(user, &operation, &result).await?;
    tx.commit().await?;
    Ok(result)
}
async fn single_connection(url: &str) -> Result<AppDb> {
    let mut options = ConnectOptions::new(url.to_owned());
    options
        .max_connections(1)
        .min_connections(1)
        .sqlx_logging(false);
    Ok(AppDb {
        connection: Database::connect(options).await?,
    })
}
async fn invitation(db: &AppDb, user: UserId, space: SpaceId, username: &str) -> Result<Uuid> {
    let response = change(
        db,
        user,
        space,
        Change::Invite {
            username: username.into(),
        },
    )
    .await?;
    Ok(Uuid::parse_str(
        response.body["id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("missing ID"))?,
    )?)
}
#[tokio::test]
async fn accept_cancel_two_connections_fifty_rounds() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let host = fixture.seed("host", "unused").await?;
    let guest = fixture.seed("guest", "unused").await?;
    let first = single_connection(&fixture.app_url).await?;
    let second = single_connection(&fixture.app_url).await?;
    let pid_sql = Statement::from_string(
        DbBackend::Postgres,
        "select pg_backend_pid() pid".to_owned(),
    );
    let first_pid: i32 = first
        .connection
        .query_one_raw(pid_sql.clone())
        .await?
        .ok_or_else(|| anyhow::anyhow!("no PID"))?
        .try_get("", "pid")?;
    let second_pid: i32 = second
        .connection
        .query_one_raw(pid_sql)
        .await?
        .ok_or_else(|| anyhow::anyhow!("no PID"))?
        .try_get("", "pid")?;
    assert_ne!(first_pid, second_pid);
    let space = SpaceId(Uuid::now_v7());
    first
        .create_space(
            host.user_id,
            "host",
            CreateSpace {
                id: space.0,
                name: "示例竞态空间".into(),
                accent_color: "pine".into(),
                currency: "CNY".into(),
                timezone: "UTC".into(),
            },
            &operation(),
            Uuid::now_v7(),
        )
        .await?;
    let owner = fixture.owner().await?;
    tokio::time::timeout(Duration::from_secs(25),async {
        for round in 0..50 {
            let id=invitation(&first,host.user_id,space,"guest").await?;
            let before: Option<Value>=sqlx::query_scalar("select to_jsonb(m) from space_members m where space_id=$1 and user_id=$2").bind(space.0).bind(guest.user_id.0).fetch_optional(&owner).await?;
            let accept_key=operation();
            let accept_request=Uuid::now_v7();
            let barrier=tokio::sync::Barrier::new(2);
            let accepting=async {
                barrier.wait().await;
                if round%2==0 { tokio::task::yield_now().await; }
                first.decide_invitation(guest.user_id,id,Decision::Accept,&accept_key,accept_request).await
            };
            let cancelling=async {
                barrier.wait().await;
                if round%2!=0 { tokio::task::yield_now().await; }
                change(&second,host.user_id,space,Change::Cancel {invitation:id}).await
            };
            let (accepted,cancelled)=tokio::join!(accepting,cancelling);
            assert_eq!(usize::from(accepted.is_ok())+usize::from(cancelled.is_ok()),1,"round {round}");
            let status: String=sqlx::query_scalar("select status from space_invitations where id=$1").bind(id).fetch_one(&owner).await?;
            let join_count: i64=sqlx::query_scalar("select count(*) from space_events where space_id=$1 and request_id=$2 and kind in ('join','rejoin')").bind(space.0).bind(accept_request).fetch_one(&owner).await?;
            let effective_accept=usize::from(join_count==1);
            let effective_cancel=usize::from(status=="cancelled");
            assert_eq!(effective_accept+effective_cancel,1,"committed transitions in round {round}");
            if status=="accepted" {
                let response=accepted?;
                assert_eq!(response.body["status"],"accepted");
                let losing=cancelled.err().ok_or_else(||anyhow::anyhow!("cancel also succeeded"))?;
                assert_eq!((losing.status,losing.code),(409,"conflict"));
                assert_eq!(losing.current,Some(json!({"status":"accepted"})));
                assert_eq!(join_count,1);
                let grants: i64=sqlx::query_scalar("select count(*) from space_member_grants g join space_members m on m.id=g.member_id where m.space_id=$1 and m.user_id=$2 and m.status='active' and g.level='write'").bind(space.0).bind(guest.user_id.0).fetch_one(&owner).await?;
                assert_eq!(grants,2);
                change(&second,guest.user_id,space,Change::Leave).await?;
            } else {
                assert_eq!(status,"cancelled");
                assert_eq!(cancelled?.body["status"],"cancelled");
                assert_eq!(accepted.err().ok_or_else(||anyhow::anyhow!("accept also succeeded"))?.code,"not_found");
                assert_eq!(join_count,0);
                let after: Option<Value>=sqlx::query_scalar("select to_jsonb(m) from space_members m where space_id=$1 and user_id=$2").bind(space.0).bind(guest.user_id.0).fetch_optional(&owner).await?;
                assert_eq!(after,before);
            }
        }
        anyhow::Ok(())
    }).await??;
    owner.close().await;
    first.close().await?;
    second.close().await?;
    Ok(())
}
#[tokio::test]
async fn both_orderings_and_lock_time_inviter_revalidation() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let host = fixture.seed("host", "unused").await?;
    let guest = fixture.seed("guest", "unused").await?;
    let third = fixture.seed("third", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let space = SpaceId(Uuid::now_v7());
    db.create_space(
        host.user_id,
        "host",
        CreateSpace {
            id: space.0,
            name: "示例状态空间".into(),
            accent_color: "pine".into(),
            currency: "CNY".into(),
            timezone: "UTC".into(),
        },
        &operation(),
        Uuid::now_v7(),
    )
    .await?;
    let id = invitation(&db, host.user_id, space, "guest").await?;
    change(&db, host.user_id, space, Change::Cancel { invitation: id }).await?;
    assert_eq!(
        db.decide_invitation(
            guest.user_id,
            id,
            Decision::Accept,
            &operation(),
            Uuid::now_v7()
        )
        .await
        .err()
        .ok_or_else(|| anyhow::anyhow!("accepted cancelled"))?
        .code,
        "not_found"
    );
    let id = invitation(&db, host.user_id, space, "guest").await?;
    db.decide_invitation(
        guest.user_id,
        id,
        Decision::Accept,
        &operation(),
        Uuid::now_v7(),
    )
    .await?;
    assert_eq!(
        change(&db, host.user_id, space, Change::Cancel { invitation: id })
            .await
            .err()
            .ok_or_else(|| anyhow::anyhow!("cancelled accepted"))?
            .code,
        "conflict"
    );
    let id = invitation(&db, host.user_id, space, "third").await?;
    // P71: a pending invitation is sent on behalf of the space, so it stays valid
    // even when its sender is no longer an active member.
    let owner = fixture.owner().await?;
    sqlx::query("update space_members set status='left' where space_id=$1 and user_id=$2")
        .bind(space.0)
        .bind(host.user_id.0)
        .execute(&owner)
        .await?;
    db.decide_invitation(
        third.user_id,
        id,
        Decision::Accept,
        &operation(),
        Uuid::now_v7(),
    )
    .await?;
    let status: String = sqlx::query_scalar("select status from space_invitations where id=$1")
        .bind(id)
        .fetch_one(&owner)
        .await?;
    assert_eq!(status, "accepted");
    owner.close().await;
    db.close().await?;
    Ok(())
}

#[tokio::test]
async fn failed_audit_rolls_back_initialization_and_acceptance() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let host = fixture.seed("host", "unused").await?;
    let guest = fixture.seed("guest", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let space = SpaceId(Uuid::now_v7());
    db.create_space(
        host.user_id,
        "host",
        CreateSpace {
            id: space.0,
            name: "示例事务空间".into(),
            accent_color: "pine".into(),
            currency: "CNY".into(),
            timezone: "UTC".into(),
        },
        &operation(),
        Uuid::now_v7(),
    )
    .await?;
    let invitation = invitation(&db, host.user_id, space, "guest").await?;
    let owner = fixture.owner().await?;
    sqlx::query("create function s2_test_reject_event() returns trigger language plpgsql as $$ begin raise exception 'test-only audit failure'; end; $$").execute(&owner).await?;
    sqlx::query("create trigger s2_test_reject_event before insert on space_events for each row execute function s2_test_reject_event()").execute(&owner).await?;
    let failed_id = Uuid::now_v7();
    let create_key = operation();
    let input = CreateSpace {
        id: failed_id,
        name: "示例回滚空间".into(),
        accent_color: "pine".into(),
        currency: "CNY".into(),
        timezone: "UTC".into(),
    };
    assert_eq!(
        db.create_space(
            host.user_id,
            "host",
            input.clone(),
            &create_key,
            Uuid::now_v7()
        )
        .await
        .err()
        .ok_or_else(|| anyhow::anyhow!("audit failure ignored"))?
        .code,
        "internal"
    );
    for table in ["spaces", "space_members", "tags"] {
        let column = if table == "spaces" { "id" } else { "space_id" };
        let count: i64 = sqlx::query_scalar(sqlx::AssertSqlSafe(format!(
            "select count(*) from {table} where {column}=$1"
        )))
        .bind(failed_id)
        .fetch_one(&owner)
        .await?;
        assert_eq!(count, 0, "{table}");
    }
    let accept_key = operation();
    assert_eq!(
        db.decide_invitation(
            guest.user_id,
            invitation,
            Decision::Accept,
            &accept_key,
            Uuid::now_v7()
        )
        .await
        .err()
        .ok_or_else(|| anyhow::anyhow!("audit failure ignored"))?
        .code,
        "internal"
    );
    let status: String = sqlx::query_scalar("select status from space_invitations where id=$1")
        .bind(invitation)
        .fetch_one(&owner)
        .await?;
    assert_eq!(status, "pending");
    let members: i64 =
        sqlx::query_scalar("select count(*) from space_members where space_id=$1 and user_id=$2")
            .bind(space.0)
            .bind(guest.user_id.0)
            .fetch_one(&owner)
            .await?;
    assert_eq!(members, 0);
    for (user, key) in [(host.user_id, &create_key), (guest.user_id, &accept_key)] {
        let cache: i64 =
            sqlx::query_scalar("select count(*) from idempotency where user_id=$1 and key=$2")
                .bind(user.0)
                .bind(&key.key)
                .fetch_one(&owner)
                .await?;
        assert_eq!(cache, 0);
    }
    sqlx::query("drop trigger s2_test_reject_event on space_events")
        .execute(&owner)
        .await?;
    sqlx::query("drop function s2_test_reject_event()")
        .execute(&owner)
        .await?;
    db.create_space(host.user_id, "host", input, &create_key, Uuid::now_v7())
        .await?;
    db.decide_invitation(
        guest.user_id,
        invitation,
        Decision::Accept,
        &accept_key,
        Uuid::now_v7(),
    )
    .await?;
    owner.close().await;
    db.close().await?;
    Ok(())
}

#[tokio::test]
async fn accepted_replay_checks_space_deletion_even_with_an_active_member() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let inviter = fixture.seed("inviter", "unused").await?;
    let invitee = fixture.seed("invitee", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let space = SpaceId(Uuid::now_v7());
    db.create_space(
        inviter.user_id,
        "inviter",
        CreateSpace {
            id: space.0,
            name: "示例重试空间".into(),
            accent_color: "pine".into(),
            currency: "CNY".into(),
            timezone: "UTC".into(),
        },
        &operation(),
        Uuid::now_v7(),
    )
    .await?;
    let invitation = invitation(&db, inviter.user_id, space, "invitee").await?;
    let key = operation();
    let first = db
        .decide_invitation(
            invitee.user_id,
            invitation,
            Decision::Accept,
            &key,
            Uuid::now_v7(),
        )
        .await?;
    let member = Uuid::parse_str(
        first.body["member_id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("missing member"))?,
    )?;
    change(&db, inviter.user_id, space, Change::Transfer { member }).await?;
    change(&db, inviter.user_id, space, Change::Leave).await?;
    let retry = db
        .decide_invitation(
            invitee.user_id,
            invitation,
            Decision::Accept,
            &key,
            Uuid::now_v7(),
        )
        .await?;
    assert_eq!(retry.status, first.status);
    assert_eq!(retry.body, first.body);

    let owner = fixture.owner().await?;
    // Preserve an active member deliberately: deletion must be checked independently
    // of membership status and of whether the invitation is still pending.
    sqlx::query("update spaces set deleted_at=now() where id=$1")
        .bind(space.0)
        .execute(&owner)
        .await?;
    let active: bool =
        sqlx::query_scalar("select status='active' from space_members where space_id=$1 and id=$2")
            .bind(space.0)
            .bind(member)
            .fetch_one(&owner)
            .await?;
    assert!(active);
    let retry = db
        .decide_invitation(
            invitee.user_id,
            invitation,
            Decision::Accept,
            &key,
            Uuid::now_v7(),
        )
        .await;
    let error = retry
        .err()
        .ok_or_else(|| anyhow::anyhow!("replayed a deleted space"))?;
    assert_eq!((error.status, error.code), (404, "not_found"));
    owner.close().await;
    db.close().await?;
    Ok(())
}

#[tokio::test]
async fn invitations_are_owner_only_and_survive_transfer() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let host = fixture.seed("host", "unused").await?;
    let guest = fixture.seed("guest", "unused").await?;
    let third = fixture.seed("third", "unused").await?;
    let _fourth = fixture.seed("fourth", "unused").await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let space = SpaceId(Uuid::now_v7());
    db.create_space(
        host.user_id,
        "host",
        CreateSpace {
            id: space.0,
            name: "示例邀请空间".into(),
            accent_color: "pine".into(),
            currency: "CNY".into(),
            timezone: "UTC".into(),
        },
        &operation(),
        Uuid::now_v7(),
    )
    .await?;
    let id = invitation(&db, host.user_id, space, "guest").await?;
    let joined = db
        .decide_invitation(
            guest.user_id,
            id,
            Decision::Accept,
            &operation(),
            Uuid::now_v7(),
        )
        .await?;
    let guest_member = Uuid::parse_str(
        joined.body["member_id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("missing member"))?,
    )?;
    // Rule 1: an ordinary member cannot invite.
    let denied = change(
        &db,
        guest.user_id,
        space,
        Change::Invite {
            username: "third".into(),
        },
    )
    .await;
    assert_eq!(
        denied
            .err()
            .ok_or_else(|| anyhow::anyhow!("member invited"))?
            .code,
        "not_found"
    );
    // Rule 3: the owner's pending invitation survives a transfer and the old owner leaving.
    let pending = invitation(&db, host.user_id, space, "third").await?;
    let other = invitation(&db, host.user_id, space, "fourth").await?;
    change(
        &db,
        host.user_id,
        space,
        Change::Transfer {
            member: guest_member,
        },
    )
    .await?;
    change(&db, host.user_id, space, Change::Leave).await?;
    // Rule 2: the new owner may withdraw an invitation it did not send.
    change(
        &db,
        guest.user_id,
        space,
        Change::Cancel { invitation: other },
    )
    .await?;
    db.decide_invitation(
        third.user_id,
        pending,
        Decision::Accept,
        &operation(),
        Uuid::now_v7(),
    )
    .await?;
    let owner = fixture.owner().await?;
    let statuses: Vec<String> = sqlx::query_scalar(
        "select status from space_invitations where id = any($1) order by array_position($1, id)",
    )
    .bind(vec![pending, other])
    .fetch_all(&owner)
    .await?;
    assert_eq!(statuses, ["accepted", "cancelled"]);
    owner.close().await;
    db.close().await?;
    Ok(())
}
