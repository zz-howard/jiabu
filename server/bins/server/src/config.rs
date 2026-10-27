use anyhow::{Context, Result};
use serde::Deserialize;
#[derive(Deserialize)]
pub struct Settings {
    pub listen_addr: String,
    pub migrate_on_start: bool,
    #[serde(default)]
    pub api_keys: jiabu_tools::api_key::ApiKeyLimits,
    pub data_dir: std::path::PathBuf,
    #[serde(default)]
    pub blobs: jiabu_storage::ImageLimits,
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
        if let Ok(value) = std::env::var("JIABU_DATA_DIR") {
            builder = builder.set_override("data_dir", value)?;
        }
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
        let settings: Self = builder
            .build()?
            .try_deserialize()
            .context("Invalid server configuration")?;
        anyhow::ensure!(
            settings.api_keys.read_per_minute > 0
                && settings.api_keys.write_per_minute > 0
                && settings.api_keys.unknown_per_minute > 0,
            "API key rate limits must be positive"
        );
        Ok(settings)
    }
}
#[cfg(test)]
mod tests {
    #[test]
    fn image_limits_are_explicit_in_base_configuration() -> anyhow::Result<()> {
        let settings: super::Settings = ::config::Config::builder()
            .add_source(::config::File::from_str(
                include_str!("../../../config/base.toml"),
                ::config::FileFormat::Toml,
            ))
            .build()?
            .try_deserialize()?;
        assert_eq!(settings.blobs.max_upload_bytes, 20 * 1024 * 1024);
        assert_eq!(settings.blobs.max_pixels, 24_000_000);
        assert_eq!(settings.blobs.max_dimension, 12_000);
        assert_eq!(settings.blobs.max_decode_bytes, 128 * 1024 * 1024);
        assert_eq!(settings.blobs.concurrency, 2);
        assert_eq!(settings.blobs.max_in_flight_uploads, 8);
        assert_eq!(settings.blobs.transfer_timeout_secs, 600);
        settings.blobs.validate()?;
        Ok(())
    }
}
