use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::{io::Read, path::PathBuf};
#[derive(Parser)]
#[command(version, about = "Jiabu administration tools")]
struct Cli {
    #[arg(long, global = true)]
    json: bool,
    #[command(subcommand)]
    command: Command,
}
#[derive(Subcommand)]
enum Command {
    Openapi {
        #[command(subcommand)]
        command: OpenapiCommand,
    },
    Db {
        #[command(subcommand)]
        command: DbCommand,
    },
    Migrate,
    User {
        #[command(subcommand)]
        command: UserCommand,
    },
}
#[derive(Subcommand)]
enum OpenapiCommand {
    Export {
        #[arg(long)]
        admin: bool,
        #[arg(long)]
        out: Option<PathBuf>,
    },
}
#[derive(Subcommand)]
enum DbCommand {
    InitRoles,
    Migrate,
}
#[derive(Subcommand)]
enum UserCommand {
    Create {
        username: String,
        #[arg(long, default_value = "个人空间")]
        space_name: String,
        #[arg(long, default_value = "Asia/Shanghai")]
        timezone: String,
        #[arg(long, default_value = "CNY")]
        currency: String,
        #[arg(long)]
        password_stdin: bool,
    },
    ResetPassword {
        username: String,
    },
    Disable {
        username: String,
    },
    Enable {
        username: String,
    },
}
fn env_url(name: &str) -> Result<secrecy::SecretString> {
    Ok(std::env::var(name)
        .with_context(|| format!("{name} is required"))?
        .into())
}
#[tokio::main]
async fn main() -> Result<()> {
    use secrecy::ExposeSecret;
    let cli = Cli::parse();
    let mut emitted = false;
    match cli.command {
        Command::Openapi {
            command: OpenapiCommand::Export { admin, out },
        } => {
            let out = out
                .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../openapi"));
            std::fs::create_dir_all(&out)?;
            if !admin {
                write_document(&out.join("openapi.json"), jiabu_api::openapi())?;
            }
            write_document(&out.join("openapi-admin.json"), jiabu_admin_api::openapi())?;
        }
        Command::Db {
            command: DbCommand::InitRoles,
        } => {
            jiabu_admin::roles::init_roles(env_url("JIABU_PROVISION_DATABASE_URL")?.expose_secret())
                .await?
        }
        Command::Migrate
        | Command::Db {
            command: DbCommand::Migrate,
        } => {
            jiabu_admin::migrations::migrate(env_url("JIABU_OWNER_DATABASE_URL")?.expose_secret())
                .await?
        }
        Command::User { command } => {
            let db = jiabu_db_admin::users::AdminDb::connect(
                env_url("JIABU_ADMIN_DATABASE_URL")?.expose_secret(),
            )
            .await?;
            let actor = std::env::var("USER").unwrap_or_else(|_| "unknown".into());
            match command {
                UserCommand::Create {
                    username,
                    space_name,
                    timezone,
                    currency,
                    password_stdin,
                } => {
                    let password = if password_stdin {
                        let mut value = String::new();
                        std::io::stdin().take(1027).read_to_string(&mut value)?;
                        anyhow::ensure!(value.len() <= 1026, "password input is too long");
                        while value.ends_with(['\n', '\r']) {
                            value.pop();
                        }
                        Some(value)
                    } else {
                        None
                    };
                    let result = jiabu_admin::create_user(
                        &db,
                        jiabu_admin::CreateUser {
                            username,
                            password,
                            space_name,
                            timezone,
                            currency,
                        },
                        &actor,
                    )
                    .await?;
                    emitted = true;
                    if cli.json {
                        println!(
                            "{}",
                            serde_json::json!({"id":result.id,"temporary_password":result.temporary_password})
                        );
                    } else {
                        println!("user_id: {}", result.id);
                        if let Some(password) = result.temporary_password {
                            println!("temporary_password: {password}");
                        }
                    }
                }
                UserCommand::ResetPassword { username } => {
                    let password = jiabu_admin::reset_password(&db, &username, &actor).await?;
                    emitted = true;
                    if cli.json {
                        println!("{}", serde_json::json!({"temporary_password":password}));
                    } else {
                        println!("temporary_password: {password}");
                    }
                }
                UserCommand::Disable { username } => {
                    jiabu_admin::set_disabled(&db, &username, true, &actor).await?
                }
                UserCommand::Enable { username } => {
                    jiabu_admin::set_disabled(&db, &username, false, &actor).await?
                }
            }
        }
    }
    if cli.json && !emitted {
        println!("{}", serde_json::json!({"ok":true}));
    }
    Ok(())
}
fn write_document(path: &std::path::Path, document: impl serde::Serialize) -> Result<()> {
    let value = serde_json::to_value(document)?;
    let mut bytes = serde_json::to_vec_pretty(&value)?;
    bytes.push(b'\n');
    std::fs::write(path, bytes).with_context(|| format!("Failed to write {}", path.display()))
}
