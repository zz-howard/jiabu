//! Management service, shared by the CLI and future management HTTP adapters.
#[path = "../../../support/credentials.rs"]
pub mod credentials;
use anyhow::{Result, anyhow, ensure};
use jiabu_db_admin::users::AdminDb;
pub use jiabu_db_admin::{migrations, roles};
use jiabu_domain::{
    SpaceId, UserId,
    presets::PRESETS,
    space_init::{DEFAULT_ACCENT, PresetSeed, SpaceInit},
};
use uuid::Uuid;
pub struct CreateUser {
    pub username: String,
    pub password: Option<String>,
    pub space_name: String,
    pub timezone: String,
    pub currency: String,
}
pub struct CreatedUser {
    pub id: UserId,
    pub temporary_password: Option<String>,
}
pub async fn create_user(db: &AdminDb, args: CreateUser, actor: &str) -> Result<CreatedUser> {
    ensure!(
        !args.username.trim().is_empty() && args.username.chars().count() <= 20,
        "username must be 1-20 characters"
    );
    let generated = args.password.is_none();
    let password = args.password.unwrap_or_else(credentials::random_secret);
    ensure!(
        (8..=1024).contains(&password.len()),
        "password must be 8-1024 bytes"
    );
    let hash = tokio::task::spawn_blocking({
        let password = password.clone();
        move || credentials::hash_password(&password)
    })
    .await?
    .map_err(|e| anyhow!(e))?;
    let plan = SpaceInit {
        space_id: SpaceId(Uuid::now_v7()),
        user_id: UserId(Uuid::now_v7()),
        name: args.space_name,
        accent: DEFAULT_ACCENT.into(),
        currency: args.currency,
        timezone: args.timezone,
        is_default: true,
        display_name: args.username.trim().into(),
        presets: PRESETS
            .iter()
            .map(|p| PresetSeed {
                id: Uuid::now_v7(),
                preset_key: p.preset_key.into(),
            })
            .collect(),
    };
    let id = db.create(args.username.trim(), &hash, &plan, actor).await?;
    Ok(CreatedUser {
        id,
        temporary_password: generated.then_some(password),
    })
}
pub async fn reset_password(db: &AdminDb, username: &str, actor: &str) -> Result<String> {
    let password = credentials::random_secret();
    let hash = tokio::task::spawn_blocking({
        let p = password.clone();
        move || credentials::hash_password(&p)
    })
    .await?
    .map_err(|e| anyhow!(e))?;
    db.reset_password(username, &hash, actor).await?;
    Ok(password)
}
pub async fn set_disabled(db: &AdminDb, username: &str, disabled: bool, actor: &str) -> Result<()> {
    db.set_disabled(username, disabled, actor).await
}
