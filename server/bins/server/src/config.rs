use anyhow::{Context, Result};
use serde::Deserialize;
#[derive(Deserialize)]
pub struct Settings {
    pub listen_addr: String,
    pub migrate_on_start: bool,
}
impl Settings {
    pub fn load() -> Result<Self> {
        let env = std::env::var("JIABU_ENV").unwrap_or_else(|_| "development".into());
        anyhow::ensure!(
            env.bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_'),
            "Invalid JIABU_ENV"
        );
        let mut builder = ::config::Config::builder()
            .add_source(::config::File::from_str(
                include_str!("../../../config/base.toml"),
                ::config::FileFormat::Toml,
            ))
            .add_source(::config::File::with_name("config/base").required(false))
            .add_source(::config::File::with_name(&format!("config/{env}")).required(false));
        // Read only non-secret settings into config; database URLs use SecretString.
        if let Ok(value) = std::env::var("JIABU_LISTEN_ADDR") {
            builder = builder.set_override("listen_addr", value)?;
        }
        if let Ok(value) = std::env::var("JIABU_MIGRATE_ON_START") {
            builder = builder.set_override(
                "migrate_on_start",
                value
                    .parse::<bool>()
                    .context("Invalid JIABU_MIGRATE_ON_START")?,
            )?;
        }
        builder
            .build()?
            .try_deserialize()
            .context("Invalid server configuration")
    }
}
