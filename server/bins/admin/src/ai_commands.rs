use anyhow::{Context, Result, ensure};
use clap::Subcommand;
use jiabu_admin::ai::{ConfigWrite, PolicyInput, PriceInput};
use jiabu_db_admin::users::AdminDb;
use jiabu_domain::ai::{ModelConfig, ProviderConfig, TaskKind};
use std::{
    io::{BufRead, Read},
    path::PathBuf,
};
use zeroize::Zeroizing;
#[derive(Subcommand)]
pub enum ProviderCommand {
    List,
    Status {
        id: String,
    },
    Add {
        #[arg(long)]
        file: PathBuf,
    },
    Update {
        #[arg(long)]
        file: PathBuf,
    },
    Enable {
        id: String,
    },
    Disable {
        id: String,
    },
    SetSecret {
        id: String,
        #[arg(long, default_value = "api_key")]
        field: String,
        #[arg(long, conflicts_with = "stdin")]
        file: Option<PathBuf>,
        #[arg(long)]
        stdin: bool,
    },
    ClearSecret {
        id: String,
        #[arg(long, default_value = "api_key")]
        field: String,
    },
    Login {
        #[arg(value_parser=["chatgpt"])]
        id: String,
    },
}
#[derive(Subcommand)]
pub enum ModelCommand {
    List,
    Add {
        #[arg(long)]
        file: PathBuf,
    },
    Update {
        #[arg(long)]
        file: PathBuf,
    },
    Enable {
        id: uuid::Uuid,
    },
    Disable {
        id: uuid::Uuid,
    },
}
#[derive(Subcommand)]
pub enum RouteCommand {
    Show,
    Set {
        task: String,
        #[arg(required = true)]
        models: Vec<uuid::Uuid>,
    },
    Clear {
        task: String,
    },
}
#[derive(Subcommand)]
pub enum PriceCommand {
    List,
    Add {
        #[arg(long)]
        file: PathBuf,
    },
}
#[derive(Subcommand)]
pub enum SettingsCommand {
    Show,
    Set {
        #[arg(long)]
        file: PathBuf,
    },
}
async fn context() -> Result<(AdminDb, String)> {
    use secrecy::ExposeSecret;
    let url = super::env_url("JIABU_ADMIN_DATABASE_URL")?;
    Ok((
        AdminDb::connect(url.expose_secret()).await?,
        std::env::var("USER").unwrap_or_else(|_| "unknown".into()),
    ))
}
fn config<T: serde::de::DeserializeOwned>(path: &PathBuf) -> Result<T> {
    let data = std::fs::read(path).context("cannot read configuration file")?;
    ensure!(data.len() <= 1024 * 1024, "configuration too large");
    serde_json::from_slice(&data).context("invalid configuration JSON")
}
fn output(value: serde_json::Value, json: bool) {
    if json {
        println!("{value}");
    } else {
        println!(
            "{}",
            serde_json::to_string_pretty(&value).unwrap_or_else(|_| "{}".into())
        );
    }
}
async fn write(db: &AdminDb, command: ConfigWrite, actor: &str, json: bool) -> Result<()> {
    jiabu_admin::ai::write(db, command, actor).await?;
    output(serde_json::json!({"ok":true}), json);
    Ok(())
}
pub async fn provider(command: ProviderCommand, json: bool) -> Result<()> {
    let (db, actor) = context().await?;
    match command {
        ProviderCommand::List => output(db.ai_show("provider", None).await?, json),
        ProviderCommand::Status { id } => output(db.ai_show("provider", Some(&id)).await?, json),
        ProviderCommand::Add { file } => {
            write(
                &db,
                ConfigWrite::Provider {
                    config: config::<ProviderConfig>(&file)?,
                    create: true,
                },
                &actor,
                json,
            )
            .await?
        }
        ProviderCommand::Update { file } => {
            write(
                &db,
                ConfigWrite::Provider {
                    config: config::<ProviderConfig>(&file)?,
                    create: false,
                },
                &actor,
                json,
            )
            .await?
        }
        ProviderCommand::Enable { id } => {
            write(
                &db,
                ConfigWrite::ProviderEnabled { id, enabled: true },
                &actor,
                json,
            )
            .await?
        }
        ProviderCommand::Disable { id } => {
            write(
                &db,
                ConfigWrite::ProviderEnabled { id, enabled: false },
                &actor,
                json,
            )
            .await?
        }
        ProviderCommand::ClearSecret { id, field } => {
            jiabu_admin::ai::set_secret(&db, &id, &field, None, &actor).await?;
            output(serde_json::json!({"ok":true}), json);
        }
        ProviderCommand::SetSecret {
            id,
            field,
            file,
            stdin,
        } => {
            ensure!(file.is_some() || stdin, "provide --stdin or --file");
            let mut secret = Zeroizing::new(Vec::new());
            if let Some(file) = file {
                std::fs::File::open(file)?
                    .take(1024 * 1024 + 1)
                    .read_to_end(&mut secret)?;
            } else {
                std::io::stdin()
                    .take(1024 * 1024 + 1)
                    .read_to_end(&mut secret)?;
            }
            ensure!(
                !secret.is_empty() && secret.len() <= 1024 * 1024,
                "invalid secret length"
            );
            if field == "oauth" {
                let _: jiabu_ai::siwc::oauth::OAuthCredentials = serde_json::from_slice(&secret)
                    .map_err(|_| anyhow::anyhow!("invalid OAuth credential JSON"))?;
            }
            while secret.last().is_some_and(|b| matches!(b, b'\n' | b'\r')) {
                secret.pop();
            }
            let key = jiabu_admin::ai_secrets::SecretKey::from_environment()
                .map_err(anyhow::Error::msg)?;
            let sealed = key
                .seal("provider", &id, &field, &secret)
                .map_err(anyhow::Error::msg)?;
            jiabu_admin::ai::set_secret(&db, &id, &field, Some(&sealed), &actor).await?;
            output(serde_json::json!({"ok":true}), json);
        }
        ProviderCommand::Login { id } => {
            if db.ai_show("provider", Some(&id)).await?["items"]
                .as_array()
                .is_some_and(|v| v.is_empty())
            {
                jiabu_admin::ai::write(
                    &db,
                    ConfigWrite::Provider {
                        config: ProviderConfig {
                            id: id.clone(),
                            kind: "siwc".into(),
                            base_url: None,
                            billing: jiabu_domain::ai::Billing::Subscription,
                            secret_source: None,
                            enabled: true,
                            version: 1,
                        },
                        create: true,
                    },
                    &actor,
                )
                .await?;
            }
            let oauth = jiabu_ai::siwc::oauth::OAuthClient::official()?;
            let client = db.ai_login_client(&id).await?;
            let login = oauth.begin(db.ai_host_id().await?, client.as_deref())?;
            // Protocol prompts go to stderr; --json stdout remains machine-readable.
            eprintln!(
                "Open this URL in your browser:\n{}\nPaste the full callback URL:",
                login.authorize_url
            );
            let mut callback = Zeroizing::new(String::new());
            std::io::stdin()
                .lock()
                .take(16385)
                .read_line(&mut callback)?;
            ensure!(callback.len() <= 16384, "callback too long");
            let credentials = oauth.complete(login, &callback).await?;
            let models = jiabu_ai::siwc::SiwcProvider::available_models(&credentials).await?;
            let plain = Zeroizing::new(serde_json::to_vec(&credentials)?);
            let key = jiabu_admin::ai_secrets::SecretKey::from_environment()
                .map_err(anyhow::Error::msg)?;
            let sealed = key
                .seal("provider", &id, "oauth", &plain)
                .map_err(anyhow::Error::msg)?;
            db.ai_save_oauth(
                &id,
                &sealed,
                &credentials.client_id,
                credentials.expires_at,
                &actor,
            )
            .await?;
            output(
                serde_json::json!({"ok":true,"expires_at":credentials.expires_at,"models":models}),
                json,
            );
        }
    }
    Ok(())
}
pub async fn model(command: ModelCommand, json: bool) -> Result<()> {
    let (db, actor) = context().await?;
    match command {
        ModelCommand::List => output(db.ai_show("model", None).await?, json),
        ModelCommand::Add { file } => {
            write(
                &db,
                ConfigWrite::Model {
                    config: config::<ModelConfig>(&file)?,
                    create: true,
                },
                &actor,
                json,
            )
            .await?
        }
        ModelCommand::Update { file } => {
            write(
                &db,
                ConfigWrite::Model {
                    config: config::<ModelConfig>(&file)?,
                    create: false,
                },
                &actor,
                json,
            )
            .await?
        }
        ModelCommand::Enable { id } => {
            write(
                &db,
                ConfigWrite::ModelEnabled { id, enabled: true },
                &actor,
                json,
            )
            .await?
        }
        ModelCommand::Disable { id } => {
            write(
                &db,
                ConfigWrite::ModelEnabled { id, enabled: false },
                &actor,
                json,
            )
            .await?
        }
    }
    Ok(())
}
fn task(value: &str) -> Result<TaskKind> {
    match value {
        "chat" => Ok(TaskKind::Chat),
        "chat_vision" => Ok(TaskKind::ChatVision),
        "probe" => Ok(TaskKind::Probe),
        _ => anyhow::bail!("invalid task kind"),
    }
}
pub async fn route(command: RouteCommand, json: bool) -> Result<()> {
    let (db, actor) = context().await?;
    match command {
        RouteCommand::Show => output(db.ai_show("route", None).await?, json),
        RouteCommand::Set { task: t, models } => {
            write(
                &db,
                ConfigWrite::Route {
                    task: task(&t)?,
                    models,
                },
                &actor,
                json,
            )
            .await?
        }
        RouteCommand::Clear { task: t } => {
            write(
                &db,
                ConfigWrite::Route {
                    task: task(&t)?,
                    models: vec![],
                },
                &actor,
                json,
            )
            .await?
        }
    }
    Ok(())
}
pub async fn price(command: PriceCommand, json: bool) -> Result<()> {
    let (db, actor) = context().await?;
    match command {
        PriceCommand::List => output(db.ai_show("price", None).await?, json),
        PriceCommand::Add { file } => {
            write(
                &db,
                ConfigWrite::Price(config::<PriceInput>(&file)?),
                &actor,
                json,
            )
            .await?
        }
    }
    Ok(())
}
pub async fn settings(command: SettingsCommand, json: bool) -> Result<()> {
    let (db, actor) = context().await?;
    match command {
        SettingsCommand::Show => output(db.ai_show("settings", None).await?, json),
        SettingsCommand::Set { file } => {
            write(
                &db,
                ConfigWrite::Policy(config::<PolicyInput>(&file)?),
                &actor,
                json,
            )
            .await?
        }
    }
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::super::Cli;
    use clap::Parser;
    #[test]
    fn secret_values_are_never_command_line_arguments() {
        assert!(
            Cli::try_parse_from(["admin", "provider", "set-secret", "fake", "--stdin"]).is_ok()
        );
        assert!(
            Cli::try_parse_from([
                "admin",
                "provider",
                "set-secret",
                "fake",
                "synthetic-secret"
            ])
            .is_err()
        );
        assert!(Cli::try_parse_from(["admin", "provider", "login", "chatgpt"]).is_ok());
        assert!(
            Cli::try_parse_from(["admin", "provider", "login", "chatgpt", "--device-code"])
                .is_err()
        );
    }
}
