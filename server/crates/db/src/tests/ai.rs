use super::*;
use crate::DbErr;
use crate::{
    SystemTx,
    ai_config::ConfigNotifications,
    ai_metering::{CallFinish, CallStart},
};
use jiabu_db_admin::ai_configuration::{ConfigWrite, PolicyInput, PriceInput};
use jiabu_domain::ai::*;
use uuid::Uuid;
fn provider() -> ProviderConfig {
    ProviderConfig {
        id: "synthetic".into(),
        kind: "siwc".into(),
        base_url: None,
        billing: Billing::Subscription,
        secret_source: None,
        enabled: true,
        version: 1,
    }
}
fn encrypted() -> EncryptedSecret {
    EncryptedSecret {
        key_id: "synthetic-key".into(),
        nonce: vec![1; 24],
        ciphertext: vec![2; 32],
        last4: String::new(),
        revision: 1,
        usable: true,
    }
}
#[tokio::test]
async fn refresh_cas_two_concurrent_rotations_have_exactly_one_winner_and_narrow_grants()
-> Result<()> {
    let fixture = support::TestDb::new().await?;
    let admin = fixture.admin().await?;
    admin
        .ai_write(
            ConfigWrite::Provider {
                config: provider(),
                create: true,
            },
            "test-operator",
        )
        .await?;
    admin
        .ai_set_secret("synthetic", "oauth", Some(&encrypted()), "test-operator")
        .await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let tx = SystemTx::begin(&db).await?;
    let old = tx.ai_secret("synthetic").await?.unwrap();
    tx.commit().await?;
    let mut tasks = vec![];
    let barrier = std::sync::Arc::new(tokio::sync::Barrier::new(3));
    for n in [3u8, 4] {
        let db = db.clone();
        let barrier = barrier.clone();
        let revision = old.revision;
        tasks.push(tokio::spawn(async move {
            let mut next = encrypted();
            next.ciphertext = vec![n; 32];
            let tx = SystemTx::begin(&db).await?;
            barrier.wait().await;
            let won = tx
                .rotate_ai_secret("synthetic", revision, &next, 3600)
                .await?;
            tx.commit().await?;
            Ok::<_, DbErr>(won)
        }));
    }
    barrier.wait().await;
    let mut winners = 0;
    for task in tasks {
        winners += usize::from(task.await??);
    }
    assert_eq!(winners, 1);
    let tx = SystemTx::begin(&db).await?;
    let stored = tx.ai_secret("synthetic").await?.unwrap();
    assert_eq!(stored.revision, old.revision + 1);
    assert!(!tx.rotate_ai_secret("absent", 1, &encrypted(), 3600).await?);
    tx.commit().await?;
    let owner = fixture.owner().await?;
    let app = sqlx::PgPool::connect(&fixture.app_url).await?;
    assert!(
        sqlx::query("update secrets set usable=false")
            .execute(&app)
            .await
            .is_err()
    );
    for sql in [
        "select has_function_privilege('jiabu_app','ai_refresh_oauth(text,bigint,text,bytea,bytea,bigint)','execute')",
        "select has_function_privilege('jiabu_app','ai_invalidate_oauth(text,bigint)','execute')",
    ] {
        assert!(sqlx::query_scalar::<_, bool>(sql).fetch_one(&owner).await?);
    }
    assert!(!sqlx::query_scalar::<_,bool>("select has_function_privilege('jiabu_admin','ai_refresh_oauth(text,bigint,text,bytea,bytea,bigint)','execute')").fetch_one(&owner).await?);
    let public_execute:i64=sqlx::query_scalar("select count(*) from pg_proc p cross join lateral aclexplode(p.proacl) a where p.proname in ('ai_refresh_oauth','ai_invalidate_oauth') and a.grantee=0 and a.privilege_type='EXECUTE'").fetch_one(&owner).await?;
    assert_eq!(public_execute, 0);
    let fixed:i64=sqlx::query_scalar("select count(*) from pg_proc where proname in ('ai_refresh_oauth','ai_invalidate_oauth') and prosecdef and 'search_path=pg_catalog, public, pg_temp'=any(proconfig)").fetch_one(&owner).await?;
    assert_eq!(fixed, 2);
    let plaintext_columns:i64=sqlx::query_scalar("select count(*) from information_schema.columns where table_name='secrets' and column_name in ('master_key','access_token','refresh_token')").fetch_one(&owner).await?;
    assert_eq!(plaintext_columns, 0);
    let projection = admin
        .ai_show("provider", Some("synthetic"))
        .await?
        .to_string();
    for excluded in ["ciphertext", "nonce", "synthetic-key"] {
        assert!(!projection.contains(excluded));
    }
    app.close().await;
    owner.close().await;
    db.close().await?;
    Ok(())
}
#[tokio::test]
async fn config_writes_are_audited_versioned_notified_and_price_rows_are_append_only() -> Result<()>
{
    let fixture = support::TestDb::new().await?;
    let admin = fixture.admin().await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let mut listener = ConfigNotifications::connect(&fixture.app_url).await?;
    let before = db.ai_configuration().await?;
    assert!(!before.allow_paid_fallback);
    assert_eq!(before.breaker.failures, 3);
    assert_eq!(before.breaker.cool_down_secs, 60);
    admin
        .ai_write(
            ConfigWrite::Provider {
                config: provider(),
                create: true,
            },
            "test-operator",
        )
        .await?;
    tokio::time::timeout(std::time::Duration::from_secs(5), listener.changed()).await??;
    let after = db.ai_configuration().await?;
    assert!(after.version > before.version);
    assert_eq!(after.providers.len(), 1);
    let id = Uuid::now_v7();
    admin
        .ai_write(
            ConfigWrite::Model {
                config: ModelConfig {
                    id,
                    provider_id: "synthetic".into(),
                    model: "synthetic-model".into(),
                    structured: StructuredMode::ToolCall,
                    vision: true,
                    context_tokens: Some(32000),
                    enabled: true,
                },
                create: true,
            },
            "test-operator",
        )
        .await?;
    admin
        .ai_write(
            ConfigWrite::Route {
                task: TaskKind::Chat,
                models: vec![id],
            },
            "test-operator",
        )
        .await?;
    admin
        .ai_write(
            ConfigWrite::Policy(PolicyInput {
                allow_paid_fallback: false,
                breaker: BreakerConfig::default(),
                retry_initial_secs: 5,
                retry_max_secs: 60,
                waiting_timeout_secs: 600,
            }),
            "test-operator",
        )
        .await?;
    admin
        .ai_write(
            ConfigWrite::Price(PriceInput {
                provider_kind: "siwc".into(),
                model: "synthetic-model".into(),
                currency: "USD".into(),
                input: "10".into(),
                cached_input: Some("2".into()),
                output: "20".into(),
                cache_write: Some(serde_json::json!({"30m":"12"})),
                long_context: None,
                source: "https://example.invalid/synthetic-prices".into(),
                as_of: chrono::Utc::now().date_naive(),
                effective_from: chrono::Utc::now() - chrono::Duration::days(1),
            }),
            "test-operator",
        )
        .await?;
    let current = db.ai_configuration().await?;
    assert!(current.version > after.version);
    assert_eq!(current.routes[0].model_id, id);
    let owner = fixture.owner().await?;
    let audits:i64=sqlx::query_scalar("select count(*) from admin_audit where actor_kind='cli' and actor_label='test-operator' and target_kind='ai_configuration'").fetch_one(&owner).await?;
    assert_eq!(audits, 5);
    let admin_pool = sqlx::PgPool::connect(&fixture.admin_url).await?;
    assert!(
        sqlx::query("delete from ai_prices")
            .execute(&admin_pool)
            .await
            .is_err()
    );
    assert!(
        sqlx::query("update ai_prices set input=0")
            .execute(&admin_pool)
            .await
            .is_err()
    );
    // Rollback never publishes a new configuration or an audit receipt.
    let stable = current.version;
    let mut tx = owner.begin().await?;
    sqlx::query("update ai_providers set enabled=false")
        .execute(&mut *tx)
        .await?;
    tx.rollback().await?;
    assert_eq!(db.ai_configuration().await?.version, stable);
    admin_pool.close().await;
    owner.close().await;
    db.close().await?;
    Ok(())
}
#[tokio::test]
async fn attempt_meters_commit_independently_freeze_prices_and_keep_unknown_cost_null() -> Result<()>
{
    let fixture = support::TestDb::new().await?;
    let admin = fixture.admin().await?;
    admin
        .ai_write(
            ConfigWrite::Provider {
                config: provider(),
                create: true,
            },
            "test",
        )
        .await?;
    let owner = fixture.owner().await?;
    sqlx::query("insert into ai_prices(provider_kind,model,input,cached_input,output,cache_write,source,as_of,effective_from) values('siwc','synthetic-model',10,2,20,'{\"30m\":\"12\"}','https://example.invalid/prices',current_date,now()-interval '1 day')").execute(&owner).await?;
    let db = AppDb::connect(&fixture.app_url).await?;
    let token = Uuid::now_v7();
    let register = |model| CallStart {
        run_id: None,
        task: "probe",
        provider: "synthetic",
        model,
        structured: "tool_call",
        call_kind: "first",
        attempt_token: token,
    };
    let journal = SystemTx::begin(&db).await?;
    let id = db.register_ai_call(register("synthetic-model")).await?;
    journal.rollback().await?;
    let started: String = sqlx::query_scalar("select outcome from ai_calls where id=$1")
        .bind(id)
        .fetch_one(&owner)
        .await?;
    assert_eq!(started, "started");
    // A newer price added before completion cannot reprice the registered call.
    sqlx::query("insert into ai_prices(provider_kind,model,input,output,source,as_of,effective_from) values('siwc','synthetic-model',999,999,'https://example.invalid/new-prices',current_date,now())").execute(&owner).await?;
    db.finish_ai_call(CallFinish {
        id,
        attempt_token: token,
        latency_ms: 20,
        usage: Some([1000, 100, 200, 100]),
        error_kind: None,
    })
    .await?;
    let row=sqlx::query("select cost_usd::text as cost,cache_saving_usd::text as saving,cached_input_tokens,cache_write_tokens from ai_calls where id=$1").bind(id).fetch_one(&owner).await?;
    assert_eq!(row.try_get::<String, _>("cost")?, "0.010600");
    assert_eq!(row.try_get::<String, _>("saving")?, "0.001400");
    assert_eq!(row.try_get::<i32, _>("cached_input_tokens")?, 200);
    assert_eq!(row.try_get::<i32, _>("cache_write_tokens")?, 100);
    assert!(
        db.finish_ai_call(CallFinish {
            id,
            attempt_token: token,
            latency_ms: 20,
            usage: Some([1, 1, 0, 0]),
            error_kind: None
        })
        .await
        .is_err()
    );
    let no_price = db.register_ai_call(register("unknown-model")).await?;
    db.finish_ai_call(CallFinish {
        id: no_price,
        attempt_token: token,
        latency_ms: 20,
        usage: Some([100, 10, 0, 0]),
        error_kind: None,
    })
    .await?;
    let cost: Option<String> =
        sqlx::query_scalar("select cost_usd::text from ai_calls where id=$1")
            .bind(no_price)
            .fetch_one(&owner)
            .await?;
    assert!(cost.is_none());
    let failed = db.register_ai_call(register("unknown-model")).await?;
    db.finish_ai_call(CallFinish {
        id: failed,
        attempt_token: token,
        latency_ms: 20,
        usage: None,
        error_kind: Some("quota"),
    })
    .await?;
    let lost = db.register_ai_call(register("unknown-model")).await?;
    db.recover_lost_ai_calls().await?;
    let outcome: String = sqlx::query_scalar("select outcome from ai_calls where id=$1")
        .bind(lost)
        .fetch_one(&owner)
        .await?;
    assert_eq!(outcome, "lost");
    assert_eq!(
        sqlx::query_scalar::<_, i64>("select count(*) from ai_calls")
            .fetch_one(&owner)
            .await?,
        4
    );
    owner.close().await;
    db.close().await?;
    Ok(())
}
