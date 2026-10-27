//! Shared fake fixtures for S4 integration tests, all persisted in PostgreSQL 18.
use super::*;
use chrono::{DateTime, Utc};
use jiabu_db::{Principal, Via, ledger::Clock};
use jiabu_domain::{
    SpaceId, UserId,
    spaces::{Change, CreateSpace, Decision},
};
use jiabu_storage::{BlobHash, BlobStore, ImageLimits};
use sha2::{Digest, Sha256};
use std::sync::Arc;

#[derive(Clone)]
pub(super) struct Fixed(pub DateTime<Utc>);
impl Clock for Fixed {
    fn now(&self) -> DateTime<Utc> {
        self.0
    }
}
pub(super) fn now() -> DateTime<Utc> {
    DateTime::parse_from_rfc3339("2026-10-28T00:00:00Z")
        .unwrap()
        .with_timezone(&Utc)
}
pub(super) fn jpeg(width: u32, height: u32) -> Vec<u8> {
    let image = image::RgbImage::from_fn(width, height, |x, y| {
        image::Rgb([(x % 251) as u8, (y % 251) as u8, 80])
    });
    let mut bytes = Vec::new();
    image::codecs::jpeg::JpegEncoder::new_with_quality(&mut bytes, 90)
        .encode_image(&image)
        .unwrap();
    bytes
}
pub(super) fn hash(bytes: &[u8]) -> BlobHash {
    BlobHash::from_bytes(Sha256::digest(bytes).into())
}
pub(super) fn op(space: Uuid, tool: &str, args: Value) -> Value {
    json!({"op_id":Uuid::now_v7(),"space_id":space,"join_epoch":1,"request_id":Uuid::now_v7(),"tool":tool,"args":args})
}
pub(super) struct Actor {
    pub user: UserId,
    pub member: Uuid,
    pub token: String,
    pub username: String,
}
pub(super) struct S4App {
    pub app: TestApp,
    pub state: AppState,
    pub token: String,
    pub space: Uuid,
    pub member: Uuid,
}
struct FrozenRate;
impl jiabu_tools::api_key::RateClock for FrozenRate {
    fn now(&self) -> std::time::Duration {
        std::time::Duration::ZERO
    }
}
impl S4App {
    pub fn key_limits(&mut self, read: u32, write: u32) -> Result<()> {
        self.state = self
            .state
            .clone()
            .with_api_key_limiter(Arc::new(jiabu_tools::api_key::ApiKeyLimiter::new(
                jiabu_tools::api_key::ApiKeyLimits {
                    read_per_minute: read,
                    write_per_minute: write,
                    unknown_per_minute: 60,
                },
                Arc::new(FrozenRate),
            )))
            .map_err(anyhow::Error::msg)?;
        assert!(Arc::ptr_eq(
            &self.state.api_keys,
            &self.state.tools.api_keys
        ));
        self.app.router = crate::router(self.state.clone());
        Ok(())
    }
    pub async fn key_callers(&self) -> Result<Vec<String>> {
        let (_, read) = super::api_keys::issue(&self.app, &self.token, "read").await?;
        let (_, write) = super::api_keys::issue(&self.app, &self.token, "read_write").await?;
        Ok(vec![self.token.clone(), read, write])
    }
    pub async fn new() -> Result<Self> {
        Self::with_limits(ImageLimits::default()).await
    }
    pub async fn with_limits(limits: ImageLimits) -> Result<Self> {
        let mut app = TestApp::new(false).await?;
        let db = AppDb::connect(&app.fixture.app_url).await?;
        let mut state =
            AppState::with_storage(db, BlobStore::local(app.fixture.data_dir())?, limits)
                .await
                .map_err(anyhow::Error::msg)?;
        state.clock = Arc::new(Fixed(now()));
        app.router = crate::router(state.clone());
        let token = app.token().await?;
        let space = app.plan.space_id.0;
        let owner = app.fixture.owner().await?;
        let member =
            sqlx::query_scalar("select id from space_members where space_id=$1 and user_id=$2")
                .bind(space)
                .bind(app.plan.user_id.0)
                .fetch_one(&owner)
                .await?;
        owner.close().await;
        Ok(Self {
            app,
            state,
            token,
            space,
            member,
        })
    }
    pub async fn principal(&self, token: &str) -> Result<Principal> {
        let auth = self
            .state
            .db
            .authenticate(crate::credentials::token_hash(token))
            .await?;
        Ok(Principal {
            user_id: UserId(auth.user.id),
            via: Via::Session {
                session_id: auth.session_id,
                kind: auth.kind,
            },
            user: auth.user,
        })
    }
    pub async fn new_space(&self) -> Result<Uuid> {
        let id = Uuid::now_v7();
        self.state
            .db
            .create_space(
                self.app.plan.user_id,
                "sample",
                CreateSpace {
                    id,
                    name: "示例共享空间".into(),
                    accent_color: "pine".into(),
                    currency: "CNY".into(),
                    timezone: "UTC".into(),
                },
                &key(),
                Uuid::now_v7(),
            )
            .await?;
        Ok(id)
    }
    pub async fn actor(&self, name: &str, space: Uuid) -> Result<Actor> {
        let plan = self.app.fixture.seed(name, "unused-test-hash").await?;
        let token = format!("{}{}", Uuid::now_v7().simple(), Uuid::now_v7().simple());
        let owner = self.app.fixture.owner().await?;
        sqlx::query("update users set must_change_password=false where id=$1")
            .bind(plan.user_id.0)
            .execute(&owner)
            .await?;
        sqlx::query("insert into sessions(token_hash,user_id,kind,expires_at) values($1,$2,'full',now()+interval '1 day')").bind(crate::credentials::token_hash(&token)).bind(plan.user_id.0).execute(&owner).await?;
        owner.close().await;
        let member = self.join(plan.user_id, name, space).await?;
        Ok(Actor {
            user: plan.user_id,
            member,
            token,
            username: name.into(),
        })
    }
    pub async fn join(&self, user: UserId, name: &str, space: Uuid) -> Result<Uuid> {
        let tx = SpaceTx::begin(
            &self.state.db,
            self.app.plan.user_id,
            &[(SpaceId(space), None)],
            Mode::Write,
        )
        .await?;
        let reply = tx
            .apply_change(
                SpaceId(space),
                Change::Invite {
                    username: name.into(),
                },
                Uuid::now_v7(),
            )
            .await?;
        tx.commit().await?;
        let invitation = serde_json::from_value(reply.body["id"].clone())?;
        let reply = self
            .state
            .db
            .decide_invitation(user, invitation, Decision::Accept, &key(), Uuid::now_v7())
            .await?;
        Ok(serde_json::from_value(reply.body["member_id"].clone())?)
    }
    pub async fn push(&self, ops: Vec<Value>, token: &str) -> Result<Value> {
        let reply = self
            .app
            .request(
                "POST",
                "/v1/sync/push",
                json!({"ops":ops}),
                Some(token),
                &[],
            )
            .await?;
        ensure!(reply.status == StatusCode::OK, "push: {}", reply.json());
        Ok(reply.json())
    }
    pub async fn call(&self, space: Uuid, tool: &str, args: Value) -> Result<Value> {
        let response = self.push(vec![op(space, tool, args)], &self.token).await?;
        ensure!(response["results"][0]["status"] == "ok", "tool: {response}");
        Ok(response["results"][0]["result"].clone())
    }
    pub async fn pull(&self, space: Uuid, cursor: i64, limit: u32, token: &str) -> Result<Value> {
        let reply = self
            .app
            .request(
                "POST",
                "/v1/sync/pull",
                json!({"spaces":{(space.to_string()):cursor},"limit":limit}),
                Some(token),
                &[],
            )
            .await?;
        ensure!(reply.status == StatusCode::OK, "pull: {}", reply.json());
        Ok(reply.json())
    }
    pub async fn accounts(&self, space: Uuid) -> Result<(Uuid, Uuid)> {
        let real = self
            .call(
                space,
                "create_account",
                json!({"kind":"real","name":"示例现金","opening_on":"2026-10-01"}),
            )
            .await?;
        let purpose = self
            .call(
                space,
                "create_account",
                json!({"kind":"purpose","name":"示例用途","opening_on":"2026-10-01"}),
            )
            .await?;
        Ok((
            serde_json::from_value(real["id"].clone())?,
            serde_json::from_value(purpose["id"].clone())?,
        ))
    }
    pub async fn upload(
        &self,
        space: Uuid,
        module: &str,
        bytes: Vec<u8>,
        token: &str,
        epoch: i32,
    ) -> Result<Reply> {
        self.app
            .raw_request(
                "PUT",
                &format!("/v1/spaces/{space}/blobs/{}?module={module}", hash(&bytes)),
                bytes,
                "image/jpeg",
                Some(token),
                &[
                    ("x-jiabu-join-epoch", epoch.to_string()),
                    (
                        "x-request-id",
                        "00000000-0000-7000-8000-000000000001".into(),
                    ),
                ],
            )
            .await
    }
    pub async fn get(
        &self,
        space: Uuid,
        hash: BlobHash,
        variant: &str,
        token: &str,
    ) -> Result<Reply> {
        self.app
            .raw_request(
                "GET",
                &format!("/v1/spaces/{space}/blobs/{hash}?variant={variant}"),
                vec![],
                "image/jpeg",
                Some(token),
                &[(
                    "x-request-id",
                    "00000000-0000-7000-8000-000000000001".into(),
                )],
            )
            .await
    }
}
pub(super) fn key() -> jiabu_db::Idempotency {
    jiabu_db::Idempotency {
        key: Uuid::now_v7().to_string(),
        hash: vec![7],
    }
}
