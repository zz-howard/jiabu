use std::path::PathBuf;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(version, about = "Jiabu administration tools")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Export OpenAPI documents without connecting to a database.
    Openapi {
        #[command(subcommand)]
        command: OpenapiCommand,
    },
}

#[derive(Subcommand)]
enum OpenapiCommand {
    /// Export both documents, or only the admin document with --admin.
    Export {
        #[arg(long)]
        admin: bool,
        #[arg(long)]
        out: Option<PathBuf>,
    },
}

fn main() -> Result<()> {
    let Cli {
        command: Command::Openapi { command },
    } = Cli::parse();
    let OpenapiCommand::Export { admin, out } = command;
    let default_out = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../openapi");
    let out = out.unwrap_or(default_out);
    std::fs::create_dir_all(&out).context("Failed to create OpenAPI output directory")?;
    if !admin {
        write_document(&out.join("openapi.json"), jiabu_api::openapi())?;
    }
    write_document(&out.join("openapi-admin.json"), jiabu_admin_api::openapi())
}

fn write_document(path: &std::path::Path, document: impl serde::Serialize) -> Result<()> {
    // Sort object keys recursively through serde_json::Value for reproducible output.
    let value = serde_json::to_value(document)?;
    let mut bytes = serde_json::to_vec_pretty(&value)?;
    bytes.push(b'\n');
    std::fs::write(path, bytes).with_context(|| format!("Failed to write {}", path.display()))
}
