use super::*;
use crate::{Idempotency, api_keys::NewKey};
use chrono::Utc;
use std::{sync::Arc, time::Duration};
use tokio::sync::Barrier;

#[tokio::test]
async fn concurrent_key_creation_serializes_before_counting() -> Result<()> {
    tokio::time::timeout(Duration::from_secs(20),async {
        let fixture=support::TestDb::new().await?;
        let plan=fixture.seed("key-limit-owner","unused").await?;
        let owner=fixture.owner().await?;
        let observer=sqlx::PgPool::connect(&fixture.root_url).await?;
        let db=AppDb::connect(&fixture.app_url).await?;
        sqlx::query("insert into api_keys(user_id,name,token_hash,display_prefix,scope) select $1,'示例',decode(repeat(lpad(to_hex(n),2,'0'),32),'hex'),'jiabu_pat_000000','read' from generate_series(1,19) n").bind(plan.user_id.0).execute(&owner).await?;
        let mut lock=owner.begin().await?;
        sqlx::query("select id from users where id=$1 for update").bind(plan.user_id.0).execute(&mut *lock).await?;
        let barrier=Arc::new(Barrier::new(3));
        let mut tasks=Vec::new();
        for n in [30_u8,31] {
            let db=db.clone();let barrier=barrier.clone();let user=plan.user_id;
            tasks.push(tokio::spawn(async move {
                barrier.wait().await;
                db.create_api_key(user,NewKey {name:"并发示例".into(),digest:vec![n;32],display_prefix:"jiabu_pat_000000".into(),scope:"read".into(),expires_at:Some(Utc::now()+chrono::Duration::days(1))},&Idempotency {key:format!("concurrent-{n}"),hash:vec![n;32]}).await
            }));
        }
        barrier.wait().await;
        // Wait for both contenders to reach the account row lock. Without that
        // lock they finish while our lock is held, so this assertion is stable.
        tokio::time::timeout(Duration::from_secs(3),async {
            loop {
                let blocked:i64=sqlx::query_scalar("select count(*) from pg_stat_activity where datname=$1 and usename='jiabu_app' and wait_event_type='Lock'").bind(&fixture.name).fetch_one(&observer).await?;
                if blocked==2 {return anyhow::Ok(());}
                if tasks.iter().any(|task|task.is_finished()) {anyhow::bail!("key creation bypassed account lock");}
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
        }).await??;
        lock.commit().await?;
        let mut created=0;let mut limited=0;
        for task in tasks {match task.await? {Ok(reply)=>{assert_eq!(reply.status,201);created+=1;},Err(error)=>{assert_eq!(error.code,"api_key_limit_reached");limited+=1;}}}
        assert_eq!((created,limited),(1,1));
        assert_eq!(sqlx::query_scalar::<_,i64>("select count(*) from api_keys").fetch_one(&owner).await?,20);
        observer.close().await;owner.close().await;db.close().await?;anyhow::Ok(())
    }).await??;
    Ok(())
}
