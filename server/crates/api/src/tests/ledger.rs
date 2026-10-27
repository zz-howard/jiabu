use super::*;
use chrono::{DateTime, Utc};
use jiabu_db::ledger::Clock;
use jiabu_db::{Principal, Via};
use jiabu_domain::JoinEpoch;
use jiabu_tools::{Effect, Exposure, Invocation, ToolCtx};
use sqlx::Row;
use std::sync::Arc;

#[derive(Clone)]
struct FixedClock(DateTime<Utc>);
impl Clock for FixedClock {
    fn now(&self) -> DateTime<Utc> {
        self.0
    }
}
fn instant() -> DateTime<Utc> {
    DateTime::parse_from_rfc3339("2026-01-01T00:00:00Z")
        .unwrap()
        .with_timezone(&Utc)
}
fn id(n: u128) -> Uuid {
    Uuid::from_u128(0x00000000000070008000000000000000 + n)
}
struct LedgerApp {
    app: TestApp,
    db: AppDb,
    token: String,
    registry: Arc<jiabu_tools::ToolRegistry>,
}
impl LedgerApp {
    async fn new() -> Result<Self> {
        let mut app = TestApp::new(false).await?;
        let db = AppDb::connect(&app.fixture.app_url).await?;
        let mut state = AppState::with_storage(
            db.clone(),
            jiabu_storage::BlobStore::local(app.fixture.data_dir())?,
            jiabu_storage::ImageLimits::default(),
        )
        .await
        .map_err(anyhow::Error::msg)?;
        state = state
            .with_api_key_limiter(Arc::new(jiabu_tools::api_key::ApiKeyLimiter::configured(
                jiabu_tools::api_key::ApiKeyLimits {
                    read_per_minute: 1000,
                    write_per_minute: 1000,
                    unknown_per_minute: 60,
                },
            )))
            .map_err(anyhow::Error::msg)?;
        state.clock = Arc::new(FixedClock(instant()));
        let registry = state.tools.clone();
        app.router = crate::router(state);
        let token = app.token().await?;
        let this = Self {
            app,
            db,
            token,
            registry,
        };
        this.seed().await?;
        Ok(this)
    }
    async fn seed(&self) -> Result<()> {
        let owner = self.app.fixture.owner().await?;
        for (n, kind, name, balance) in [
            (1, "real", "示例银行卡", 0_i64),
            (2, "purpose", "示例用途", 0),
            (7, "real", "示例现金", 0),
            (8, "purpose", "示例备用金", 0),
            (9, "purpose", "示例归档用途", 0),
        ] {
            sqlx::query("insert into accounts(id,space_id,kind,name,is_reserve,opening_balance_minor,opening_on,created_by_member_id,archived_at,change_seq,created_at,updated_at) values($1,$2,$3,$4,$5,$6,'2026-01-01',$7,case when $8 then '2026-01-01'::timestamptz else null end,nextval('change_seq'),$9,$9)")
                .bind(id(n)).bind(self.app.plan.space_id.0).bind(kind).bind(name).bind(n==8).bind(balance).bind(self.member().await?.0).bind(n==9).bind(instant()).execute(&owner).await?;
        }
        sqlx::query("insert into tags(id,space_id,name,created_by_member_id,change_seq) values($1,$2,'示例标签',$3,nextval('change_seq'))").bind(id(3)).bind(self.app.plan.space_id.0).bind(self.member().await?.0).execute(&owner).await?;
        for (n, status) in [(4, "active"), (10, "voided")] {
            sqlx::query("insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,purpose_id,status,void_reason,origin,created_by_member_id,updated_by_member_id,change_seq,created_at,updated_at) values($1,$2,'expense',100,'2026-01-01',$3,$4,$5,case when $5='voided' then 'user' else null end,'api',$6,$6,nextval('change_seq'),$7,$7)")
                .bind(id(n)).bind(self.app.plan.space_id.0).bind(id(1)).bind(id(2)).bind(status).bind(self.member().await?.0).bind(instant()).execute(&owner).await?;
        }
        owner.close().await;
        Ok(())
    }
    async fn member(&self) -> Result<jiabu_domain::MemberId> {
        let tx = SpaceTx::begin(
            &self.db,
            self.app.plan.user_id,
            &[(self.app.plan.space_id, None)],
            Mode::Read,
        )
        .await?;
        let member = tx.member(self.app.plan.space_id).id();
        tx.commit().await?;
        Ok(member)
    }
    async fn principal(&self) -> Result<Principal> {
        if self.token.starts_with("jiabu_pat_") {
            return Ok(self
                .db
                .authenticate_api_key(crate::credentials::token_hash(&self.token))
                .await?);
        }
        let auth = self
            .db
            .authenticate(crate::credentials::token_hash(&self.token))
            .await?;
        Ok(Principal {
            user_id: self.app.plan.user_id,
            user: auth.user,
            via: Via::Session {
                session_id: auth.session_id,
                kind: auth.kind,
            },
        })
    }
    async fn direct(
        &self,
        name: &str,
        args: Value,
        key: &str,
        request: Uuid,
    ) -> Result<Value, jiabu_tools::ToolError> {
        let principal = self
            .principal()
            .await
            .map_err(|_| jiabu_tools::ToolError::internal())?;
        let effect = self.registry.get(name)?.effect();
        let ctx = ToolCtx::begin(
            &self.db,
            principal,
            self.app.plan.space_id,
            if effect == Effect::LocalWrite {
                Some(JoinEpoch(1))
            } else {
                None
            },
            effect,
            Invocation {
                idempotency_key: Some(Uuid::new_v5(&self.app.plan.user_id.0, key.as_bytes())),
                replay_key: Some(key.into()),
                run_id: None,
                request_id: request,
                now: instant(),
            },
        )
        .await?;
        self.registry.invoke(name, args, &ctx).await
    }
    async fn api(
        &self,
        name: &str,
        args: Value,
        key: Option<&str>,
        epoch: i32,
        request: Uuid,
    ) -> Result<Reply> {
        let mut headers = vec![
            ("x-jiabu-join-epoch", epoch.to_string()),
            ("x-request-id", request.to_string()),
        ];
        if let Some(key) = key {
            headers.push(("idempotency-key", key.to_owned()));
        }
        self.app
            .request(
                "POST",
                &format!("/v1/spaces/{}/tools/{name}", self.app.plan.space_id),
                args,
                Some(&self.token),
                &headers,
            )
            .await
    }
    async fn call(&self, name: &str, args: Value) -> Result<Value> {
        let reply = self
            .api(
                name,
                args,
                Some(&Uuid::now_v7().to_string()),
                1,
                Uuid::now_v7(),
            )
            .await?;
        ensure!(
            reply.status == StatusCode::OK,
            "{name}: {} {}",
            reply.status,
            reply.json()
        );
        Ok(reply.json())
    }
    async fn fail(&self, name: &str, args: Value, code: &str) -> Result<Value> {
        let reply = self
            .api(
                name,
                args,
                Some(&Uuid::now_v7().to_string()),
                1,
                Uuid::now_v7(),
            )
            .await?;
        ensure!(
            reply.json()["code"] == code,
            "{name}: {} {} expected {code}",
            reply.status,
            reply.json()
        );
        Ok(reply.json())
    }
    async fn expense(&self, amount: i64) -> Result<Value> {
        self.call("create_record",json!({"kind":"expense","amount_minor":amount,"occurred_on":"2026-01-01","account_id":id(1),"purpose_id":id(2)})).await
    }
    async fn refund(&self, parent: &Value, amount: i64) -> Result<Value> {
        self.call("create_record",json!({"kind":"refund","amount_minor":amount,"occurred_on":"2026-01-02","refund_of_id":parent["id"]})).await
    }
}

// Snapshot/restore is owner-only test setup, never an application escape hatch.
// Reset sequences and use the injected clock to compare COMPLETE business and
// entity_event rows, including IDs, timestamps and change_seq, byte for byte.
async fn checkpoint(owner: &sqlx::PgPool) -> Result<Vec<(String, i64, bool)>> {
    for table in [
        "accounts",
        "allocation_plans",
        "tags",
        "records",
        "entity_events",
        "idempotency",
    ] {
        sqlx::query(sqlx::AssertSqlSafe(format!(
            "create table baseline_{table} as table {table}"
        )))
        .execute(owner)
        .await?;
    }
    let mut sequences = Vec::new();
    for name in ["change_seq", "entity_events_id_seq"] {
        let row = sqlx::query(sqlx::AssertSqlSafe(format!(
            "select last_value,is_called from {name}"
        )))
        .fetch_one(owner)
        .await?;
        sequences.push((
            name.into(),
            row.try_get("last_value")?,
            row.try_get("is_called")?,
        ));
    }
    Ok(sequences)
}
async fn restore(owner: &sqlx::PgPool, sequences: &[(String, i64, bool)]) -> Result<()> {
    for table in [
        "entity_events",
        "records",
        "allocation_plans",
        "accounts",
        "tags",
        "idempotency",
    ] {
        sqlx::query(sqlx::AssertSqlSafe(format!("delete from {table}")))
            .execute(owner)
            .await?;
    }
    for table in [
        "accounts",
        "allocation_plans",
        "tags",
        "records",
        "entity_events",
        "idempotency",
    ] {
        sqlx::query(sqlx::AssertSqlSafe(format!(
            "insert into {table} overriding system value select * from baseline_{table}"
        )))
        .execute(owner)
        .await?;
    }
    for (name, value, called) in sequences {
        sqlx::query("select setval($1::regclass,$2,$3)")
            .bind(name)
            .bind(value)
            .bind(called)
            .execute(owner)
            .await?;
    }
    Ok(())
}
async fn persisted(owner: &sqlx::PgPool) -> Result<Value> {
    let mut value = json!({});
    for table in [
        "accounts",
        "allocation_plans",
        "tags",
        "records",
        "entity_events",
    ] {
        value[table]=sqlx::query_scalar::<_,Value>(sqlx::AssertSqlSafe(format!("select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) from {table} t"))).fetch_one(owner).await?;
    }
    Ok(value)
}
fn valid_args(name: &str, registry: &jiabu_tools::ToolRegistry) -> Result<Value> {
    let mut args = registry.get(name)?.example_args();
    match name {
        "create_account" => {
            args["id"] = json!(id(11));
            args["name"] = json!("示例新账户");
        }
        "create_record" => args["id"] = json!(id(12)),
        "create_tag" => args["id"] = json!(id(13)),
        "archive_account" => args["id"] = json!(id(7)),
        "update_account" => args["name"] = json!("示例改名账户"),
        "restore_record" => {
            args["id"] = json!(id(10));
            args["expected_version"] = json!(1);
        }
        _ => (),
    }
    Ok(args)
}
#[tokio::test]
async fn every_open_tool_matches_direct_invoke_including_full_audit_and_denial() -> Result<()> {
    entry_parity(false).await
}
#[tokio::test]
async fn every_open_tool_key_matches_direct_invoke_including_full_audit_and_denial() -> Result<()> {
    entry_parity(true).await
}
async fn entry_parity(use_key: bool) -> Result<()> {
    let mut harness = LedgerApp::new().await?;
    if use_key {
        harness.token = super::api_keys::issue(&harness.app, &harness.token, "read_write")
            .await?
            .1;
    }
    let owner = harness.app.fixture.owner().await?;
    let sequences = checkpoint(&owner).await?;
    for tool in harness
        .registry
        .tools()
        .filter(|t| t.exposure() != Exposure::AgentOnly)
    {
        let name = tool.name();
        let args = valid_args(name, &harness.registry)?;
        let request = Uuid::now_v7();
        let direct = harness
            .direct(name, args.clone(), "same-call", request)
            .await?;
        let direct_rows = persisted(&owner).await?;
        restore(&owner, &sequences).await?;
        let reply = harness
            .api(name, args.clone(), Some("same-call"), 1, request)
            .await?;
        ensure!(reply.status == StatusCode::OK, "{name}: {}", reply.json());
        assert_eq!(reply.json(), direct, "{name} result");
        assert_eq!(
            persisted(&owner).await?,
            direct_rows,
            "{name} full snapshots/events"
        );
        // Keep the successful API replay row, then revoke permission: replay cannot win.
        sqlx::query(
            "update space_member_grants set level='none' where member_id=$1 and module='ledger'",
        )
        .bind(harness.member().await?.0)
        .execute(&owner)
        .await?;
        let before_denial = persisted(&owner).await?;
        let direct_error = harness
            .direct(name, args.clone(), "same-call", request)
            .await
            .err()
            .ok_or_else(|| anyhow::anyhow!("direct allowed {name}"))?;
        let denied = harness
            .api(name, args, Some("same-call"), 1, request)
            .await?;
        assert_eq!(denied.status.as_u16(), direct_error.status, "{name}");
        assert_eq!(denied.json()["code"], direct_error.code, "{name}");
        assert_eq!(direct_error.code, "not_found");
        assert_eq!(
            persisted(&owner).await?,
            before_denial,
            "{name} denial mutated content"
        );
        sqlx::query(
            "update space_member_grants set level='manage' where member_id=$1 and module='ledger'",
        )
        .bind(harness.member().await?.0)
        .execute(&owner)
        .await?;
        restore(&owner, &sequences).await?;
    }
    owner.close().await;
    harness.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn refunds_enforce_every_s39_transition_and_defaults() -> Result<()> {
    let h = LedgerApp::new().await?;
    let parent = h.expense(100).await?;
    let r = h.refund(&parent, 40).await?;
    assert_eq!(r["account_id"], parent["account_id"]);
    assert_eq!(r["purpose_id"], parent["purpose_id"]);
    let r2 = h.refund(&parent, 60).await?;
    h.fail("create_record",json!({"kind":"refund","amount_minor":1,"occurred_on":"2026-01-02","refund_of_id":parent["id"]}),"refund_exceeds_original").await?;
    h.fail(
        "void_record",
        json!({"id":parent["id"],"expected_version":1}),
        "has_refunds",
    )
    .await?;
    h.fail(
        "update_record",
        json!({"id":parent["id"],"expected_version":1,"changes":{"amount_minor":99}}),
        "refund_exceeds_original",
    )
    .await?;
    h.fail(
        "update_record",
        json!({"id":r["id"],"expected_version":1,"changes":{"amount_minor":41}}),
        "refund_exceeds_original",
    )
    .await?;
    // Exclude this refund's old amount rather than counting it twice.
    let changed=h.call("update_record",json!({"id":r["id"],"expected_version":1,"changes":{"amount_minor":40,"note":"示例退款"}})).await?;
    h.fail(
        "update_record",
        json!({"id":r["id"],"expected_version":2,"changes":{"refund_of_id":id(4)}}),
        "validation_failed",
    )
    .await?;
    let changed = h
        .call(
            "update_record",
            json!({"id":r["id"],"expected_version":changed["version"],"changes":{"note":null}}),
        )
        .await?;
    assert!(changed["note"].is_null());
    let void_r = h
        .call(
            "void_record",
            json!({"id":r["id"],"expected_version":changed["version"]}),
        )
        .await?;
    h.call("void_record", json!({"id":r2["id"],"expected_version":1}))
        .await?;
    let smaller = h
        .call(
            "update_record",
            json!({"id":parent["id"],"expected_version":1,"changes":{"amount_minor":30}}),
        )
        .await?;
    h.fail(
        "restore_record",
        json!({"id":r["id"],"expected_version":void_r["version"]}),
        "refund_exceeds_original",
    )
    .await?;
    let void_parent = h
        .call(
            "void_record",
            json!({"id":parent["id"],"expected_version":smaller["version"]}),
        )
        .await?;
    h.fail(
        "restore_record",
        json!({"id":r["id"],"expected_version":void_r["version"]}),
        "parent_voided",
    )
    .await?;
    h.fail("create_record",json!({"kind":"refund","amount_minor":1,"occurred_on":"2026-01-01","refund_of_id":parent["id"]}),"parent_voided").await?;
    h.call(
        "restore_record",
        json!({"id":parent["id"],"expected_version":void_parent["version"]}),
    )
    .await?;
    let income=h.call("create_record",json!({"kind":"income","amount_minor":100,"occurred_on":"2026-01-01","account_id":id(1)})).await?;
    h.fail("create_record",json!({"kind":"refund","amount_minor":1,"occurred_on":"2026-01-01","refund_of_id":income["id"]}),"validation_failed").await?;
    let balance = h.call("query_balance", json!({})).await?;
    assert_eq!(balance["currency"], "CNY");
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn archived_refund_defaults_require_explicit_active_destinations_and_history_remains_editable()
-> Result<()> {
    let h = LedgerApp::new().await?;
    for n in [1, 2] {
        h.call(
            "update_account",
            json!({"id":id(n),"expected_version":1,"opening_balance_minor":100}),
        )
        .await?;
        h.call("archive_account", json!({"id":id(n),"expected_version":2}))
            .await?;
    }
    let refund =
        json!({"kind":"refund","amount_minor":10,"occurred_on":"2026-01-02","refund_of_id":id(4)});
    h.fail("create_record", refund.clone(), "account_archived")
        .await?;
    let mut explicit = refund.clone();
    explicit["account_id"] = json!(id(7));
    h.fail("create_record", explicit.clone(), "account_archived")
        .await?;
    explicit["purpose_id"] = json!(id(9));
    h.fail("create_record", explicit.clone(), "account_archived")
        .await?;
    explicit["purpose_id"] = json!(id(8));
    h.call("create_record", explicit).await?;
    let old=h.call("update_record",json!({"id":id(4),"expected_version":1,"changes":{"amount_minor":90,"note":"示例修订"}})).await?;
    assert_eq!(old["account_id"], json!(id(1)));
    assert_eq!(old["purpose_id"], json!(id(2)));
    h.fail(
        "void_record",
        json!({"id":id(4),"expected_version":2}),
        "has_refunds",
    )
    .await?;
    h.fail(
        "create_record",
        json!({"kind":"income","amount_minor":1,"occurred_on":"2026-01-01","account_id":id(1)}),
        "account_archived",
    )
    .await?;
    let restored = h
        .call("restore_record", json!({"id":id(10),"expected_version":1}))
        .await?;
    h.call(
        "void_record",
        json!({"id":id(10),"expected_version":restored["version"]}),
    )
    .await?;
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn balances_all_directions_voids_starting_balances_and_zero_archive() -> Result<()> {
    let h = LedgerApp::new().await?;
    // Seed expense is -100 in account 1 and purpose 2; the seeded void is excluded.
    let balance = h.call("query_balance", json!({})).await?;
    let values: std::collections::BTreeMap<Uuid, i64> = balance["balances"]
        .as_array()
        .unwrap()
        .iter()
        .map(|v| {
            (
                Uuid::parse_str(v["account_id"].as_str().unwrap()).unwrap(),
                v["balance_minor"].as_i64().unwrap(),
            )
        })
        .collect();
    assert_eq!(values[&id(1)], -100);
    assert_eq!(values[&id(2)], -100);
    h.fail(
        "archive_account",
        json!({"id":id(1),"expected_version":1}),
        "balance_not_zero",
    )
    .await?;
    h.call(
        "create_record",
        json!({"kind":"income","amount_minor":200,"occurred_on":"2026-01-01","account_id":id(1)}),
    )
    .await?;
    h.call("create_record",json!({"kind":"transfer","amount_minor":30,"occurred_on":"2026-01-01","account_id":id(1),"to_account_id":id(7)})).await?;
    h.call("create_record",json!({"kind":"reallocation","amount_minor":20,"occurred_on":"2026-01-01","purpose_id":id(8),"to_purpose_id":id(2)})).await?;
    h.refund(&json!({"id":id(4)}), 10).await?;
    for (n, expected) in [(1, 80), (7, 30), (2, -70), (8, -20)] {
        let b = h.call("query_balance", json!({"account_id":id(n)})).await?;
        assert_eq!(b["balances"][0]["balance_minor"], expected);
    }
    h.call(
        "update_account",
        json!({"id":id(7),"expected_version":1,"opening_balance_minor":-30}),
    )
    .await?;
    h.call("archive_account", json!({"id":id(7),"expected_version":2}))
        .await?;
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn api_idempotency_epoch_authorization_and_noop_status() -> Result<()> {
    let h = LedgerApp::new().await?;
    let request = Uuid::now_v7();
    let args =
        json!({"kind":"income","amount_minor":5,"occurred_on":"2026-01-01","account_id":id(1)});
    assert_eq!(
        h.api("create_record", args.clone(), None, 1, request)
            .await?
            .json()["code"],
        "idempotency_key_required"
    );
    let first = h
        .api("create_record", args.clone(), Some("repeat"), 1, request)
        .await?;
    assert_eq!(first.status, StatusCode::OK);
    let owner = h.app.fixture.owner().await?;
    let before = persisted(&owner).await?;
    assert_eq!(
        first.bytes,
        h.api("create_record", args.clone(), Some("repeat"), 1, request)
            .await?
            .bytes
    );
    assert_eq!(before, persisted(&owner).await?);
    let update_args =
        json!({"id":first.json()["id"],"expected_version":1,"changes":{"amount_minor":9}});
    let updated = h
        .api(
            "update_record",
            update_args.clone(),
            Some("update-repeat"),
            1,
            request,
        )
        .await?;
    assert_eq!(updated.status, StatusCode::OK);
    let after_update = persisted(&owner).await?;
    assert_eq!(
        updated.bytes,
        h.api(
            "update_record",
            update_args,
            Some("update-repeat"),
            1,
            request
        )
        .await?
        .bytes
    );
    assert_eq!(
        first.bytes,
        h.api("create_record", args.clone(), Some("repeat"), 1, request)
            .await?
            .bytes
    );
    assert_eq!(after_update, persisted(&owner).await?);
    let mut different = args.clone();
    different["amount_minor"] = json!(6);
    assert_eq!(
        h.api("create_record", different, Some("repeat"), 1, request)
            .await?
            .json()["code"],
        "idempotency_key_reused"
    );
    assert_eq!(
        h.api("query_balance", json!({}), None, 1, request)
            .await?
            .status,
        StatusCode::OK
    );
    sqlx::query(
        "update space_members set status='left',left_reason='left',left_at=now() where id=$1",
    )
    .bind(h.member().await?.0)
    .execute(&owner)
    .await?;
    assert_eq!(
        h.api("create_record", args.clone(), Some("repeat"), 1, request)
            .await?
            .json()["code"],
        "not_found"
    );
    sqlx::query("update space_members set status='active',left_reason=null,left_at=null,join_epoch=join_epoch+1 where space_id=$1 and user_id=$2").bind(h.app.plan.space_id.0).bind(h.app.plan.user_id.0).execute(&owner).await?;
    assert_eq!(
        h.api("create_record", args.clone(), Some("repeat"), 1, request)
            .await?
            .json()["code"],
        "membership_changed"
    );
    let no_epoch = h
        .app
        .request(
            "POST",
            &format!("/v1/spaces/{}/tools/create_record", h.app.plan.space_id),
            args,
            Some(&h.token),
            &[("idempotency-key", "missing-epoch".into())],
        )
        .await?;
    assert_eq!(no_epoch.status, StatusCode::BAD_REQUEST);
    let void = h
        .api(
            "void_record",
            json!({"id":id(4),"expected_version":1}),
            Some("void"),
            2,
            request,
        )
        .await?;
    let rows = persisted(&owner).await?;
    let noop = h
        .api(
            "void_record",
            json!({"id":id(4),"expected_version":void.json()["version"]}),
            Some("void-again"),
            2,
            request,
        )
        .await?;
    assert_eq!(noop.json(), void.json());
    assert_eq!(rows, persisted(&owner).await?);
    let restored = h
        .api(
            "restore_record",
            json!({"id":id(4),"expected_version":void.json()["version"]}),
            Some("restore"),
            2,
            request,
        )
        .await?;
    assert_eq!(restored.status, StatusCode::OK);
    let rows = persisted(&owner).await?;
    let noop = h
        .api(
            "restore_record",
            json!({"id":id(4),"expected_version":restored.json()["version"]}),
            Some("restore-again"),
            2,
            request,
        )
        .await?;
    assert_eq!(noop.json(), restored.json());
    assert_eq!(rows, persisted(&owner).await?);
    owner.close().await;
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn exposure_status_schemas_and_oneof_are_public_contracts() -> Result<()> {
    let h = LedgerApp::new().await?;
    let status = h
        .app
        .request("GET", "/v1/status", Value::Null, Some(&h.token), &[])
        .await?;
    assert_eq!(
        status.json(),
        json!({"ai_available":false,"ai_reason":"unavailable"})
    );
    let tools = h
        .app
        .request(
            "GET",
            &format!("/v1/spaces/{}/tools", h.app.plan.space_id),
            Value::Null,
            Some(&h.token),
            &[],
        )
        .await?;
    assert_eq!(tools.json()["tools"].as_array().unwrap().len(), 17);
    assert!(!tools.json().to_string().contains("ask_user"));
    assert!(!h.registry.agent_tools().any(|t| t.name() == "delete_tag"));
    assert!(h.registry.agent_tools().any(|t| t.name() == "ask_user"));
    let hidden = h
        .app
        .request(
            "POST",
            &format!("/v1/spaces/{}/tools/ask_user", h.app.plan.space_id),
            json!({}),
            Some(&h.token),
            &[],
        )
        .await?;
    assert_eq!(hidden.status, StatusCode::NOT_FOUND);
    let ctx = ToolCtx::begin(
        &h.db,
        h.principal().await?,
        h.app.plan.space_id,
        None,
        Effect::Read,
        Invocation {
            idempotency_key: None,
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: instant(),
        },
    )
    .await?;
    assert_eq!(
        h.registry
            .invoke("ask_user", json!({}), &ctx)
            .await
            .err()
            .unwrap()
            .code,
        "unavailable"
    );
    let call_schema = serde_json::to_value(schemars::schema_for!(jiabu_tools::ToolCall))?;
    let call_validator = jsonschema::validator_for(&call_schema)
        .map_err(|_| anyhow::anyhow!("bad tagged call schema"))?;
    let doc = serde_json::to_value(crate::openapi())?;
    let public_schema =
        json!({"$ref":"#/components/schemas/ToolCall","components":doc["components"]});
    let public_validator = jsonschema::validator_for(&public_schema)
        .map_err(|_| anyhow::anyhow!("bad public call schema"))?;
    assert!(!public_validator.is_valid(&json!({"tool":"ask_user","args":{}})));
    assert!(!doc.to_string().contains("ask_user"));
    assert!(doc["paths"]["/v1/sync/push"]["post"].is_object());
    assert_eq!(
        doc["components"]["schemas"]["ToolCall"]["oneOf"]
            .as_array()
            .unwrap()
            .len(),
        17
    );
    fn refs(value: &Value, doc: &Value) {
        match value {
            Value::Object(o) => {
                if let Some(Value::String(reference)) = o.get("$ref") {
                    assert!(
                        doc.pointer(reference.trim_start_matches('#')).is_some(),
                        "unresolved {reference}"
                    );
                }
                for child in o.values() {
                    refs(child, doc);
                }
            }
            Value::Array(a) => {
                for child in a {
                    refs(child, doc);
                }
            }
            _ => (),
        }
    }
    refs(&doc, &doc);
    for tool in h
        .registry
        .tools()
        .filter(|t| t.exposure() != Exposure::AgentOnly)
    {
        assert_eq!(
            doc["paths"][tool.api_path()]["post"]["operationId"],
            format!("tool_{}", tool.name())
        );
        tool.validate(tool.example_args())?;
        let invocation = json!({"tool":tool.name(),"args":tool.example_args()});
        let typed: jiabu_tools::ToolCall = serde_json::from_value(invocation.clone())?;
        let serialized = serde_json::to_value(typed)?;
        assert_eq!(serialized["tool"], invocation["tool"]);
        assert!(call_validator.is_valid(&serialized));
        assert!(call_validator.is_valid(&invocation));
        assert!(public_validator.is_valid(&invocation));
        let validator = jsonschema::validator_for(tool.output_schema())
            .map_err(|_| anyhow::anyhow!("bad output schema"))?;
        assert!(
            validator.is_valid(&tool.example_output()),
            "{} output example",
            tool.name()
        );
    }
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn stats_tags_filters_pagination_localized_tags_and_immutable_types() -> Result<()> {
    let h = LedgerApp::new().await?;
    let tag = h.call("create_tag", json!({"name":"示例第二标签"})).await?;
    let expense=h.call("create_record",json!({"kind":"expense","amount_minor":90,"occurred_on":"2026-02-01","account_id":id(1),"purpose_id":id(2),"tag_ids":[id(3),tag["id"]],"note":"示例午饭"})).await?;
    h.call("create_record",json!({"kind":"refund","amount_minor":30,"occurred_on":"2026-02-02","refund_of_id":expense["id"]})).await?;
    for kind in ["transfer", "reallocation"] {
        let mut args = json!({"kind":kind,"amount_minor":500,"occurred_on":"2026-02-01"});
        if kind == "transfer" {
            args["account_id"] = json!(id(1));
            args["to_account_id"] = json!(id(7));
        } else {
            args["purpose_id"] = json!(id(8));
            args["to_purpose_id"] = json!(id(2));
        }
        h.call("create_record", args).await?;
    }
    let stats=h.call("query_stats",json!({"measure":"sum","period":{"from":"2026-02-01","through":"2026-02-28"},"group_by":"tag"})).await?;
    assert_eq!(stats["total"], 60);
    assert_eq!(stats["tag_groups_may_overlap"], true);
    assert_eq!(
        stats["groups"]
            .as_array()
            .unwrap()
            .iter()
            .map(|g| g["value"].as_i64().unwrap())
            .sum::<i64>(),
        120
    );
    let count = h
        .call(
            "query_stats",
            json!({"measure":"count","period":{"from":"2026-02-01","through":"2026-02-28"}}),
        )
        .await?;
    assert_eq!(count["total"], 1);
    let first=h.call("search_records",json!({"filters":{"text":"午饭","tag_id":id(3),"account_id":id(1),"purpose_id":id(2),"member_id":h.member().await?.0},"page":{"limit":1,"offset":0}})).await?;
    assert_eq!(first["records"][0]["id"], expense["id"]);
    assert_eq!(first["has_more"], false);
    let all = h
        .call("search_records", json!({"page":{"limit":1,"offset":0}}))
        .await?;
    let second = h
        .call("search_records", json!({"page":{"limit":1,"offset":1}}))
        .await?;
    assert!(all["has_more"].as_bool().unwrap());
    assert_ne!(all["records"][0]["id"], second["records"][0]["id"]);
    let tags = h.call("list_tags", json!({})).await?;
    let preset = tags["tags"]
        .as_array()
        .unwrap()
        .iter()
        .find(|t| !t["preset_key"].is_null())
        .unwrap();
    assert!(preset["name"].is_null());
    let renamed = h
        .call(
            "rename_tag",
            json!({"id":preset["id"],"expected_version":1,"name":"示例共同名称"}),
        )
        .await?;
    assert_eq!(renamed["preset_key"], preset["preset_key"]);
    h.call("delete_tag", json!({"id":id(3),"expected_version":1}))
        .await?;
    let old = h.call("get_record", json!({"id":expense["id"]})).await?;
    assert_eq!(old["tag_ids"][0], json!(id(3)));
    h.fail(
        "update_record",
        json!({"id":expense["id"],"expected_version":1,"changes":{"kind":"income"}}),
        "validation_failed",
    )
    .await?;
    h.fail(
        "update_account",
        json!({"id":id(1),"expected_version":1,"kind":"purpose"}),
        "validation_failed",
    )
    .await?;
    h.fail(
        "create_record",
        json!({"kind":"allocation","amount_minor":5,"occurred_on":"2026-01-01","purpose_id":id(2)}),
        "validation_failed",
    )
    .await?;
    h.fail(
        "create_record",
        json!({"kind":"income","amount_minor":1.5,"occurred_on":"2026-01-01","account_id":id(1)}),
        "validation_failed",
    )
    .await?;
    h.fail(
        "query_balance",
        json!({"space_id":Uuid::now_v7()}),
        "validation_failed",
    )
    .await?;
    h.fail("create_record",json!({"kind":"income","amount_minor":1,"occurred_on":"2026-01-01","account_id":id(1),"currency":"USD"}),"validation_failed").await?;
    let owner = h.app.fixture.owner().await?;
    sqlx::query("update spaces set currency='JPY' where id=$1")
        .bind(h.app.plan.space_id.0)
        .execute(&owner)
        .await?;
    assert_eq!(h.call("query_balance", json!({})).await?["currency"], "JPY");
    owner.close().await;
    h.db.close().await?;
    Ok(())
}
#[tokio::test]
async fn foreign_entity_references_match_nonexistent_and_audit_rolls_back() -> Result<()> {
    let h = LedgerApp::new().await?;
    let other = h.app.fixture.seed("foreign", "unused").await?;
    let owner = h.app.fixture.owner().await?;
    let other_member: Uuid = sqlx::query_scalar("select id from space_members where space_id=$1")
        .bind(other.space_id.0)
        .fetch_one(&owner)
        .await?;
    let foreign_account = Uuid::now_v7();
    let foreign_purpose = Uuid::now_v7();
    let foreign_record = Uuid::now_v7();
    for (id, kind) in [(foreign_account, "real"), (foreign_purpose, "purpose")] {
        sqlx::query("insert into accounts(id,space_id,kind,name,opening_on,created_by_member_id,change_seq,created_at,updated_at) values($1,$2,$3,'示例外空间账户','2026-01-01',$4,nextval('change_seq'),$5,$5)").bind(id).bind(other.space_id.0).bind(kind).bind(other_member).bind(instant()).execute(&owner).await?;
    }
    sqlx::query("insert into records(id,space_id,kind,amount_minor,occurred_on,account_id,purpose_id,origin,created_by_member_id,change_seq,created_at,updated_at) values($1,$2,'expense',100,'2026-01-01',$3,$4,'api',$5,nextval('change_seq'),$6,$6)").bind(foreign_record).bind(other.space_id.0).bind(foreign_account).bind(foreign_purpose).bind(other_member).bind(instant()).execute(&owner).await?;
    let before = persisted(&owner).await?;
    for foreign in [foreign_record, Uuid::now_v7()] {
        for name in ["get_record", "void_record", "restore_record"] {
            h.fail(
                name,
                json!({"id":foreign,"expected_version":1})
                    .as_object()
                    .map(|v| {
                        let mut v = v.clone();
                        if name == "get_record" {
                            v.remove("expected_version");
                        }
                        Value::Object(v)
                    })
                    .unwrap(),
                "not_found",
            )
            .await?;
        }
        h.fail("create_record",json!({"kind":"refund","amount_minor":1,"occurred_on":"2026-01-01","refund_of_id":foreign}),"not_found").await?;
    }
    for (field, foreign) in [
        ("account_id", foreign_account),
        ("purpose_id", foreign_purpose),
        ("tag_ids", other.presets[0].id),
    ] {
        let mut args = json!({"kind":"expense","amount_minor":1,"occurred_on":"2026-01-01","account_id":id(1),"purpose_id":id(2)});
        args[field] = if field == "tag_ids" {
            json!([foreign])
        } else {
            json!(foreign)
        };
        h.fail("create_record", args, "not_found").await?;
    }
    let missing_blob = "ab".repeat(32);
    h.fail("create_record",json!({"kind":"income","amount_minor":1,"occurred_on":"2026-01-01","account_id":id(1),"attachments":[missing_blob]}),"blob_missing").await?;
    assert_eq!(before, persisted(&owner).await?);
    let stale = h
        .fail(
            "update_record",
            json!({"id":id(4),"expected_version":99,"changes":{"amount_minor":10}}),
            "version_conflict",
        )
        .await?;
    assert_eq!(stale["current"]["version"], 1);
    // Verify metadata and event snapshots using an Agent-like invocation with a run ID.
    let run = Uuid::now_v7();
    let request = Uuid::now_v7();
    let key = Uuid::now_v7();
    let ctx = ToolCtx::begin(
        &h.db,
        h.principal().await?,
        h.app.plan.space_id,
        Some(JoinEpoch(1)),
        Effect::LocalWrite,
        Invocation {
            idempotency_key: Some(key),
            replay_key: None,
            run_id: Some(run),
            request_id: request,
            now: instant(),
        },
    )
    .await?;
    let row = h
        .registry
        .invoke(
            "update_record",
            json!({"id":id(4),"expected_version":1,"changes":{"note":"示例审计"}}),
            &ctx,
        )
        .await?;
    let event: Value = sqlx::query_scalar(
        "select to_jsonb(e) from entity_events e where entity_id=$1 order by id desc limit 1",
    )
    .bind(id(4))
    .fetch_one(&owner)
    .await?;
    let audited: jiabu_domain::ledger::Record = serde_json::from_value(event["after"].clone())?;
    assert_eq!(serde_json::to_value(audited)?, row);
    assert_eq!(event["before"]["note"], Value::Null);
    assert_eq!(event["run_id"], json!(run));
    assert_eq!(event["request_id"], json!(request));
    assert_eq!(event["actor_member_id"], json!(h.member().await?.0));
    assert!(event["via_api_key_id"].is_null());
    assert!(event["via_api_key_name"].is_null());
    assert_ne!(event["change_seq"], row["change_seq"]);
    owner.close().await;
    h.db.close().await?;
    Ok(())
}

fn over_limit_arguments() -> Vec<(&'static str, Value)> {
    let cap = 1_000_000_000_000_i64;
    let record = json!({"kind":"expense","amount_minor":1,"occurred_on":"2026-01-01","account_id":id(1),"purpose_id":id(2)});
    let patch = json!({"id":id(4),"expected_version":1,"changes":{"amount_minor":1}});
    let account = json!({"kind":"real","name":"示例上限账户","opening_on":"2026-01-01"});
    let mut cases = Vec::new();
    for amount in [0, cap + 1, -(cap + 1)] {
        let mut args = record.clone();
        args["amount_minor"] = json!(amount);
        cases.push(("create_record", args));
        let mut args = patch.clone();
        args["changes"]["amount_minor"] = json!(amount);
        cases.push(("update_record", args));
        cases.push((
            "set_allocation_plan",
            json!({"account_id":id(2),"amount_minor":amount,"day_of_month":15,"enabled":true}),
        ));
    }
    for amount in [cap + 1, -(cap + 1)] {
        let mut args = account.clone();
        args["opening_balance_minor"] = json!(amount);
        cases.push(("create_account", args));
        cases.push((
            "update_account",
            json!({"id":id(1),"expected_version":1,"opening_balance_minor":amount}),
        ));
    }
    for field in ["tag_ids", "attachments"] {
        let values = if field == "tag_ids" {
            json!((100..121).map(id).collect::<Vec<_>>())
        } else {
            json!(vec!["ab".repeat(32); 21])
        };
        let mut args = record.clone();
        args[field] = values.clone();
        cases.push(("create_record", args));
        let mut args = patch.clone();
        args["changes"][field] = values;
        cases.push(("update_record", args));
    }
    cases
}

#[test]
fn monetary_and_collection_limits_are_in_schema_and_accept_boundaries() -> Result<()> {
    let registry = jiabu_tools::ToolRegistry::ledger()?;
    for (name, args) in over_limit_arguments() {
        let tool = registry.get(name)?;
        let schema = jsonschema::validator_for(tool.parameters())
            .map_err(|_| anyhow::anyhow!("invalid schema"))?;
        assert!(!schema.is_valid(&args), "{name} schema accepted {args}");
        assert!(
            tool.validate(args).is_err(),
            "{name} accepted out-of-range arguments"
        );
    }
    let cap = 1_000_000_000_000_i64;
    let tags = (100..120).map(id).collect::<Vec<_>>();
    let attachments = vec!["ab".repeat(32); 20];
    registry.get("create_record")?.validate(json!({"kind":"expense","amount_minor":cap,"occurred_on":"2026-01-01","account_id":id(1),"purpose_id":id(2),"tag_ids":tags,"attachments":attachments}))?;
    registry.get("update_record")?.validate(json!({"id":id(4),"expected_version":1,"changes":{"amount_minor":cap,"tag_ids":tags,"attachments":attachments}}))?;
    registry.get("set_allocation_plan")?.validate(
        json!({"account_id":id(2),"amount_minor":cap,"day_of_month":15,"enabled":true}),
    )?;
    for amount in [-cap, cap] {
        registry.get("create_account")?.validate(json!({"kind":"real","name":"示例边界","opening_on":"2026-01-01","opening_balance_minor":amount}))?;
        registry
            .get("update_account")?
            .validate(json!({"id":id(1),"expected_version":1,"opening_balance_minor":amount}))?;
    }
    Ok(())
}

#[tokio::test]
async fn invalid_limits_fail_before_space_write_lock_for_api_and_direct_invoke() -> Result<()> {
    tokio::time::timeout(std::time::Duration::from_secs(20), async {
        let h = LedgerApp::new().await?;
        let owner = h.app.fixture.owner().await?;
        let before = persisted(&owner).await?;
        let blocker = SpaceTx::begin(
            &h.db,
            h.app.plan.user_id,
            &[(h.app.plan.space_id, Some(JoinEpoch(1)))],
            Mode::Write,
        )
        .await?;
        // A write lock is already held. Each invalid call must finish rather than
        // wait for it, proving validation is before lock acquisition in both entrances.
        for (name, args) in over_limit_arguments() {
            let reply = tokio::time::timeout(
                std::time::Duration::from_secs(2),
                h.api(name, args.clone(), Some("invalid-limit"), 1, Uuid::now_v7()),
            )
            .await??;
            assert_eq!(
                reply.status,
                StatusCode::UNPROCESSABLE_ENTITY,
                "{name}: {}",
                reply.json()
            );
            assert_eq!(reply.json()["code"], "validation_failed");
            let error = tokio::time::timeout(
                std::time::Duration::from_secs(2),
                h.direct(name, args, "invalid-direct", Uuid::now_v7()),
            )
            .await?
            .err()
            .ok_or_else(|| anyhow::anyhow!("direct validation accepted {name}"))?;
            assert_eq!(error.status, 422);
            assert_eq!(error.code, "validation_failed");
        }
        assert_eq!(persisted(&owner).await?, before);
        blocker.rollback().await?;
        owner.close().await;
        h.db.close().await?;
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    Ok(())
}

#[tokio::test]
async fn write_rechecks_grants_and_join_epoch_after_read_preflight() -> Result<()> {
    let h = LedgerApp::new().await?;
    let owner = h.app.fixture.owner().await?;
    let make = || Invocation {
        idempotency_key: Some(Uuid::now_v7()),
        replay_key: None,
        run_id: None,
        request_id: Uuid::now_v7(),
        now: instant(),
    };
    let args =
        json!({"kind":"income","amount_minor":1,"occurred_on":"2026-01-01","account_id":id(1)});
    let ctx = ToolCtx::begin(
        &h.db,
        h.principal().await?,
        h.app.plan.space_id,
        Some(JoinEpoch(1)),
        Effect::LocalWrite,
        make(),
    )
    .await?;
    sqlx::query(
        "update space_member_grants set level='none' where member_id=$1 and module='ledger'",
    )
    .bind(h.member().await?.0)
    .execute(&owner)
    .await?;
    assert_eq!(
        h.registry
            .invoke("create_record", args.clone(), &ctx)
            .await
            .err()
            .unwrap()
            .code,
        "not_found"
    );
    sqlx::query(
        "update space_member_grants set level='manage' where member_id=$1 and module='ledger'",
    )
    .bind(h.member().await?.0)
    .execute(&owner)
    .await?;
    let ctx = ToolCtx::begin(
        &h.db,
        h.principal().await?,
        h.app.plan.space_id,
        Some(JoinEpoch(1)),
        Effect::LocalWrite,
        make(),
    )
    .await?;
    sqlx::query("update space_members set join_epoch=join_epoch+1 where id=$1")
        .bind(h.member().await?.0)
        .execute(&owner)
        .await?;
    let before = persisted(&owner).await?;
    assert_eq!(
        h.registry
            .invoke("create_record", args, &ctx)
            .await
            .err()
            .unwrap()
            .code,
        "membership_changed"
    );
    assert_eq!(persisted(&owner).await?, before);
    owner.close().await;
    h.db.close().await?;
    Ok(())
}

#[tokio::test]
async fn refund_stats_use_parent_tags_for_grouping_and_filtering_without_copying() -> Result<()> {
    let h = LedgerApp::new().await?;
    let expense = h.call("create_record",json!({"kind":"expense","amount_minor":100,"occurred_on":"2026-02-01","account_id":id(1),"purpose_id":id(2),"tag_ids":[id(3)]})).await?;
    let refund = h.call("create_record",json!({"kind":"refund","amount_minor":40,"occurred_on":"2026-02-02","refund_of_id":expense["id"]})).await?;
    assert_eq!(refund["tag_ids"], json!([]));
    let mut args = json!({"measure":"sum","period":{"from":"2026-02-01","through":"2026-02-28"},"filters":{"tag_id":id(3)}});
    assert_eq!(h.call("query_stats", args.clone()).await?["total"], 60);
    args["group_by"] = json!("tag");
    let grouped = h.call("query_stats", args.clone()).await?;
    assert_eq!(
        grouped["groups"],
        json!([{"key":id(3).to_string(),"value":60}])
    );
    args["kinds"] = json!(["refund"]);
    assert_eq!(h.call("query_stats", args.clone()).await?["total"], 40);
    args["kinds"] = json!([]);
    args["period"]["from"] = json!("2026-02-02");
    assert_eq!(h.call("query_stats", args.clone()).await?["total"], -40);
    // Parent tags are read at query time, rather than snapshotted onto refunds.
    let other = h
        .call("create_tag", json!({"name":"示例新用途标签"}))
        .await?;
    h.call(
        "update_record",
        json!({"id":expense["id"],"expected_version":1,"changes":{"tag_ids":[other["id"]]}}),
    )
    .await?;
    args["period"]["from"] = json!("2026-02-01");
    assert_eq!(h.call("query_stats", args.clone()).await?["total"], 0);
    args["filters"]["tag_id"] = other["id"].clone();
    assert_eq!(h.call("query_stats", args).await?["total"], 60);
    let current_refund = h.call("get_record", json!({"id":refund["id"]})).await?;
    assert_eq!(current_refund["tag_ids"], json!([]));
    h.db.close().await?;
    Ok(())
}

#[tokio::test]
async fn update_record_rejects_new_inactive_references_but_retains_existing_ones() -> Result<()> {
    let h = LedgerApp::new().await?;
    let expense = h.call("create_record",json!({"kind":"expense","amount_minor":20,"occurred_on":"2026-02-01","account_id":id(1),"purpose_id":id(2),"tag_ids":[id(3)]})).await?;
    let transfer = h.call("create_record",json!({"kind":"transfer","amount_minor":10,"occurred_on":"2026-02-01","account_id":id(1),"to_account_id":id(7)})).await?;
    let reallocation = h.call("create_record",json!({"kind":"reallocation","amount_minor":10,"occurred_on":"2026-02-01","purpose_id":id(2),"to_purpose_id":id(8)})).await?;
    for (n, kind) in [(11, "real"), (12, "purpose")] {
        h.call(
            "create_account",
            json!({"id":id(n),"kind":kind,"name":"示例停用目标","opening_on":"2026-01-01"}),
        )
        .await?;
        h.call("archive_account", json!({"id":id(n),"expected_version":1}))
            .await?;
    }
    let deleted = h
        .call("create_tag", json!({"name":"示例已删目标标签"}))
        .await?;
    for tag in [json!(id(3)), deleted["id"].clone()] {
        h.call("delete_tag", json!({"id":tag,"expected_version":1}))
            .await?;
    }
    for (record, field, target) in [
        (&expense, "account_id", id(11)),
        (&expense, "purpose_id", id(12)),
        (&transfer, "account_id", id(11)),
        (&transfer, "to_account_id", id(11)),
        (&reallocation, "purpose_id", id(12)),
        (&reallocation, "to_purpose_id", id(12)),
    ] {
        let mut changes = json!({});
        changes[field] = json!(target);
        h.fail(
            "update_record",
            json!({"id":record["id"],"expected_version":1,"changes":changes}),
            "account_archived",
        )
        .await?;
    }
    h.fail("update_record",json!({"id":expense["id"],"expected_version":1,"changes":{"tag_ids":[id(3),deleted["id"]]}}),"not_found").await?;
    // Bring all four original accounts to zero and archive through the real tools.
    for n in [1, 7, 2, 8] {
        let balance = h.call("query_balance", json!({"account_id":id(n)})).await?;
        let opening = -balance["balances"][0]["balance_minor"].as_i64().unwrap();
        h.call(
            "update_account",
            json!({"id":id(n),"expected_version":1,"opening_balance_minor":opening}),
        )
        .await?;
        h.call("archive_account", json!({"id":id(n),"expected_version":2}))
            .await?;
    }
    for (record, changes) in [
        (
            &expense,
            json!({"account_id":id(1),"purpose_id":id(2),"tag_ids":[id(3)],"note":"示例历史修订"}),
        ),
        (
            &transfer,
            json!({"account_id":id(1),"to_account_id":id(7),"note":"示例历史修订"}),
        ),
        (
            &reallocation,
            json!({"purpose_id":id(2),"to_purpose_id":id(8),"note":"示例历史修订"}),
        ),
    ] {
        let updated = h
            .call(
                "update_record",
                json!({"id":record["id"],"expected_version":1,"changes":changes}),
            )
            .await?;
        assert_eq!(updated["version"], 2);
        assert_eq!(updated["note"], "示例历史修订");
    }
    let current = h.call("get_record", json!({"id":expense["id"]})).await?;
    assert_eq!(current["tag_ids"], json!([id(3)]));
    h.db.close().await?;
    Ok(())
}
