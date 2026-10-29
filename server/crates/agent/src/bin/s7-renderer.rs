//! Synthetic fixture renderer used by the build host's independent processes.
use jiabu_agent::render::{FrozenPrompt, bytes, segments};
use jiabu_db::chat_runtime::JournalItem;
use std::io::{self, Read, Write};
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;
    let (prompt, journal): (FrozenPrompt, Vec<JournalItem>) = serde_json::from_str(&input)?;
    io::stdout().write_all(&bytes(&serde_json::to_value(segments(&prompt, &journal))?)?)?;
    Ok(())
}
