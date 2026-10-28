use anyhow::{Context, Result};
use serde_json::json;
use std::{
    io::Write,
    process::{Command, Stdio},
};
#[test]
fn prefix_bytes_equal_across_process_restart() -> Result<()> {
    let input = json!([{
        "snapshot":{"instructions":"Synthetic bilingual instructions / 虚构指令","tools":[],"model":"fake-model","parameters":{}},
        "context":{"timezone":"Asia/Shanghai","currency":"CNY","accounts":[]},
        "input":{"text":"虚构午饭 / Fake lunch","images":[],"locale":"zh-CN","submitted_at":"2026-01-01T00:00:00Z"},
        "history":[],"permissions":{},"tool_versions":{}
    },[{"idx":1,"kind":"model_turn","call_id":null,"payload":{"calls":[],"items":[{"kind":"tool_call","call_id":"a","name":"fake","args_raw":"{  \"value\" : 1 }"}]},"provider_blob":null}]]);
    let render = || -> Result<Vec<u8>> {
        let mut child = Command::new(env!("CARGO_BIN_EXE_s7-renderer"))
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()?;
        child
            .stdin
            .take()
            .context("stdin")?
            .write_all(&serde_json::to_vec(&input)?)?;
        let result = child.wait_with_output()?;
        anyhow::ensure!(result.status.success(), "renderer failed");
        Ok(result.stdout)
    };
    let first = render()?;
    let second = render()?;
    assert_eq!(first, second);
    assert!(!first.is_empty());
    Ok(())
}
