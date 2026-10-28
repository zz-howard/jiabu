//! Real executable test: SIGHUP is delivered only to an owned child process.
#![cfg(unix)]
#[path = "../../../tests/support/mod.rs"]
mod support;
use anyhow::{Context, Result, ensure};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    path::Path,
    process::{Child, Command, Stdio},
    time::Duration,
};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use uuid::Uuid;
struct ChildGuard(Child);
impl Drop for ChildGuard {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}
async fn get(address: &str, token: &str) -> Result<Value> {
    tokio::time::timeout(Duration::from_secs(5),async{
        let mut stream=tokio::net::TcpStream::connect(address).await?;
        stream.write_all(format!("GET /v1/templates HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer {token}\r\nConnection: close\r\n\r\n").as_bytes()).await?;
        let mut bytes=Vec::new();stream.read_to_end(&mut bytes).await?;
        let boundary=bytes.windows(4).position(|w|w==b"\r\n\r\n").context("missing HTTP boundary")?;
        ensure!(bytes.starts_with(b"HTTP/1.1 200"),"template request failed");
        Ok::<_,anyhow::Error>(serde_json::from_slice(&bytes[boundary+4..])?)
    }).await?
}
fn custom(id: &str) -> Value {
    let mut body: Value = serde_json::from_str(jiabu_domain::templates::OFFICIAL[0].1).unwrap();
    body["id"] = json!(id);
    body
}
fn write(path: &Path, value: &Value) -> Result<()> {
    std::fs::write(path, serde_json::to_vec_pretty(value)?)?;
    Ok(())
}
#[tokio::test]
async fn sighup_loads_new_files_preserves_bad_updates_and_child_remains_available() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let plan = fixture.seed("sample", "unused-test-hash").await?;
    let owner = fixture.owner().await?;
    sqlx::query("update users set must_change_password=false where id=$1")
        .bind(plan.user_id.0)
        .execute(&owner)
        .await?;
    let token = format!("{}{}", Uuid::now_v7().simple(), Uuid::now_v7().simple());
    sqlx::query("insert into sessions(token_hash,user_id,kind,expires_at) values($1,$2,'full',now()+interval '1 day')").bind(Sha256::digest(token.as_bytes()).to_vec()).bind(plan.user_id.0).execute(&owner).await?;
    let dir = fixture.data_dir();
    let templates = dir.join("templates");
    std::fs::create_dir_all(&templates)?;
    write(&templates.join("good.json"), &custom("myhome.initial"))?;
    std::fs::write(
        templates.join("syntax.json"),
        "{ sentinel-private-template-content",
    )?;
    write(
        &templates.join("schema.json"),
        &json!({"sentinel-private-template-content":true}),
    )?;
    let mut semantic = custom("myhome.semantic");
    semantic["event_date_field"] = json!("sentinel-private-template-content");
    write(&templates.join("semantic.json"), &semantic)?;
    write(&templates.join("reserved.json"), &custom("jiabu.reserved"))?;
    let mut newer = custom("myhome.saved");
    newer["version"] = json!(2);
    sqlx::query("insert into template_snapshots(id,version,body) values('myhome.saved',2,$1)")
        .bind(&newer)
        .execute(&owner)
        .await?;
    write(
        &templates.join("incompatible.json"),
        &custom("myhome.saved"),
    )?;
    let log_path = dir.join("server.log");
    let log = std::fs::File::create(&log_path)?;
    let mut child = ChildGuard(
        Command::new(env!("CARGO_BIN_EXE_server"))
            .current_dir(env!("CARGO_MANIFEST_DIR"))
            .env("JIABU_ENV", "development")
            .env("JIABU_DATABASE_URL", &fixture.app_url)
            .env("JIABU_MIGRATE_ON_START", "false")
            .env("JIABU_DATA_DIR", &dir)
            .env("JIABU_LISTEN_ADDR", "127.0.0.1:0")
            .env("RUST_LOG", "info")
            .stdout(Stdio::from(log.try_clone()?))
            .stderr(Stdio::from(log))
            .spawn()?,
    );
    let address = tokio::time::timeout(Duration::from_secs(30), async {
        loop {
            ensure!(
                child.0.try_wait()?.is_none(),
                "server child exited before ready"
            );
            let logs = std::fs::read_to_string(&log_path)?;
            for line in logs.lines() {
                if let Ok(value) = serde_json::from_str::<Value>(line)
                    && value["message"] == "Public HTTP listener ready"
                    && let Some(address) = value["address"].as_str()
                {
                    return Ok::<_, anyhow::Error>(address.to_owned());
                }
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
    })
    .await??;
    let initial = get(&address, &token).await?;
    assert_eq!(initial["templates"].as_array().unwrap().len(), 5);
    write(&templates.join("new.json"), &custom("myhome.new"))?;
    std::fs::write(
        templates.join("good.json"),
        "{ sentinel-private-template-content broken update",
    )?;
    let status = Command::new("kill")
        .args(["-HUP", &child.0.id().to_string()])
        .status()?;
    ensure!(status.success(), "could not signal child");
    tokio::time::timeout(Duration::from_secs(15), async {
        loop {
            let response = get(&address, &token).await?;
            if response["templates"]
                .as_array()
                .is_some_and(|ts| ts.iter().any(|t| t["id"] == "myhome.new"))
            {
                assert!(
                    response["templates"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .any(|t| t["id"] == "myhome.initial")
                );
                assert_eq!(response["templates"].as_array().unwrap().len(), 6);
                break;
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    ensure!(child.0.try_wait()?.is_none(), "SIGHUP killed server child");
    let logs = std::fs::read_to_string(&log_path)?;
    for category in [
        "json",
        "schema",
        "semantic",
        "reserved_namespace",
        "incompatible",
    ] {
        assert!(
            logs.lines()
                .filter_map(|line| serde_json::from_str::<Value>(line).ok())
                .any(|v| v["category"] == category),
            "missing category {category}"
        );
    }
    assert!(!logs.contains("sentinel-private-template-content"));
    let n: i64 = sqlx::query_scalar(
        "select count(*) from template_snapshots where id in ('myhome.initial','myhome.new')",
    )
    .fetch_one(&owner)
    .await?;
    assert_eq!(n, 2);
    // Drop kills and reaps the child even when any assertion above unwinds.
    drop(child);
    owner.close().await;
    Ok(())
}
