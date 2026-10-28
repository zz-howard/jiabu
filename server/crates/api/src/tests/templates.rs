use super::documents::harness;
use super::*;
use jiabu_tools::templates::{TemplateFile, TemplateStore, official_files};
use std::sync::{Arc, Mutex};
use tracing::instrument::WithSubscriber;
fn custom() -> Value {
    let mut t: Value = serde_json::from_str(jiabu_domain::templates::OFFICIAL[0].1).unwrap();
    t["id"] = json!("myhome.checkup");
    t
}
fn file(name: &str, body: &Value) -> TemplateFile {
    TemplateFile {
        filename: name.into(),
        body: body.to_string(),
        official: false,
        error: None,
    }
}
fn files(extra: TemplateFile) -> Vec<TemplateFile> {
    let mut files = official_files();
    files.push(extra);
    files
}
#[tokio::test]
async fn templates_etag_is_stable_conditional_and_readonly_key_accessible() -> Result<()> {
    let h = harness().await?;
    let callers = h.key_callers().await?;
    let mut etag = String::new();
    let mut bytes = Vec::new();
    for token in callers {
        let response = h
            .app
            .request("GET", "/v1/templates", Value::Null, Some(&token), &[])
            .await?;
        assert_eq!(response.status, StatusCode::OK);
        assert_eq!(response.json()["templates"].as_array().unwrap().len(), 4);
        let current = response.headers["etag"].to_str()?.to_owned();
        if etag.is_empty() {
            etag = current;
            bytes = response.bytes;
        } else {
            assert_eq!(etag, current);
            assert_eq!(bytes, response.bytes);
        }
        for condition in [etag.clone(), format!("\"another\", W/{etag}"), "*".into()] {
            let cached = h
                .app
                .request(
                    "GET",
                    "/v1/templates",
                    Value::Null,
                    Some(&token),
                    &[("if-none-match", condition)],
                )
                .await?;
            assert_eq!(cached.status, StatusCode::NOT_MODIFIED);
            assert!(cached.bytes.is_empty());
            assert_eq!(cached.headers["etag"].to_str()?, etag);
        }
    }
    h.state
        .templates
        .reload(&h.state.db, official_files())
        .await?;
    assert_eq!(h.state.templates.snapshot().await.etag, etag);
    h.state
        .templates
        .reload(&h.state.db, files(file("good.json", &custom())))
        .await?;
    let changed = h
        .app
        .request(
            "GET",
            "/v1/templates",
            Value::Null,
            Some(&h.token),
            &[("if-none-match", etag)],
        )
        .await?;
    assert_eq!(changed.status, StatusCode::OK);
    assert_eq!(changed.json()["templates"].as_array().unwrap().len(), 5);
    Ok(())
}
#[tokio::test]
async fn bad_files_skip_safely_keep_previous_generation_and_update_good_snapshots() -> Result<()> {
    let h = harness().await?;
    let good = custom();
    h.state
        .templates
        .reload(&h.state.db, files(file("good.json", &good)))
        .await?;
    let previous = h.state.templates.snapshot().await;
    let buffer = Arc::new(Mutex::new(Vec::<u8>::new()));
    let subscriber = tracing_subscriber::fmt()
        .with_writer(LogWriter(buffer.clone()))
        .json()
        .with_ansi(false)
        .finish();
    let mut semantic = good.clone();
    semantic["id"] = json!("myhome.semantic");
    semantic["event_date_field"] = json!("sentinel-secret-content");
    let mut reserved = good.clone();
    reserved["id"] = json!("jiabu.private");
    let mut added = good.clone();
    added["id"] = json!("myhome.added");
    let mut input = official_files();
    input.extend([
        TemplateFile {
            filename: "good.json".into(),
            body: "{ sentinel-secret-content".into(),
            official: false,
            error: None,
        },
        file("schema.json", &json!({"sentinel-secret-content":true})),
        file("semantic.json", &semantic),
        file("reserved.json", &reserved),
        file("new.json", &added),
        TemplateFile {
            filename: "/parent/ctrl\n.json".into(),
            body: "not json sentinel-secret-content".into(),
            official: false,
            error: None,
        },
    ]);
    let report = h
        .state
        .templates
        .reload(&h.state.db, input)
        .with_subscriber(subscriber)
        .await?;
    assert!(report.rejected.iter().any(|r| r.category == "json"));
    assert!(report.rejected.iter().any(|r| r.category == "schema"));
    assert!(report.rejected.iter().any(|r| r.category == "semantic"));
    assert!(
        report
            .rejected
            .iter()
            .any(|r| r.category == "reserved_namespace")
    );
    let next = h.state.templates.snapshot().await;
    assert_eq!(
        next.templates["myhome.checkup"],
        previous.templates["myhome.checkup"]
    );
    assert!(next.templates.contains_key("myhome.added"));
    let logs = String::from_utf8(buffer.lock().unwrap().clone())?;
    assert!(logs.contains("json") && logs.contains("schema") && logs.contains("semantic"));
    assert!(!logs.contains("sentinel-secret-content"));
    assert!(!logs.contains("/parent"));
    assert!(logs.contains("ctrl.json"));
    let owner = h.app.fixture.owner().await?;
    let ids: Vec<String> = sqlx::query_scalar("select id from template_snapshots order by id")
        .fetch_all(&owner)
        .await?;
    assert_eq!(ids.len(), 6);
    assert!(ids.contains(&"myhome.added".into()));
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn compatibility_rejections_preserve_snapshots_and_relaxations_replace_them() -> Result<()> {
    let h = harness().await?;
    let mut good = custom();
    good["version"] = json!(2);
    h.state
        .templates
        .reload(&h.state.db, files(file("custom.json", &good)))
        .await?;
    let owner = h.app.fixture.owner().await?;
    let before: Value =
        sqlx::query_scalar("select body from template_snapshots where id='myhome.checkup'")
            .fetch_one(&owner)
            .await?;
    for mutation in 0..5 {
        let mut bad = good.clone();
        match mutation {
            0 => {
                bad["fields"]
                    .as_array_mut()
                    .unwrap()
                    .retain(|f| f["key"] != "weight");
                for group in bad["layout"].as_array_mut().unwrap() {
                    group["fields"]
                        .as_array_mut()
                        .unwrap()
                        .retain(|k| k != "weight");
                }
            }
            1 => {
                let f = &mut bad["fields"][3];
                *f = json!({"key":"weight","type":"text","label":{"zh-Hans":"体重","en":"Weight"}});
            }
            2 => bad["fields"][3]["metric"] = json!("body.changed"),
            3 => bad["version"] = json!(1),
            _ => bad["fields"][3]["min"] = json!(100),
        }
        let report = h
            .state
            .templates
            .reload(&h.state.db, files(file("custom.json", &bad)))
            .await?;
        assert!(
            report.rejected.iter().any(|r| r.category == "incompatible"),
            "mutation {mutation}"
        );
        let snapshot: Value =
            sqlx::query_scalar("select body from template_snapshots where id='myhome.checkup'")
                .fetch_one(&owner)
                .await?;
        assert_eq!(snapshot, before);
        assert_eq!(
            h.state.templates.snapshot().await.templates["myhome.checkup"].version,
            2
        );
    }
    good["version"] = json!(3);
    good["fields"]
        .as_array_mut()
        .unwrap()
        .push(json!({"key":"extra","type":"text","label":{"zh-Hans":"新增","en":"Extra"}}));
    good["fields"][8]["options"]
        .as_array_mut()
        .unwrap()
        .push(json!({"id":"unknown","label":{"zh-Hans":"未知","en":"Unknown"}}));
    good["name"]["en"] = json!("Updated label");
    good["fields"][3]["min"] = json!(0);
    good["fields"][3]["max"] = json!(500);
    let report = h
        .state
        .templates
        .reload(&h.state.db, files(file("custom.json", &good)))
        .await?;
    assert!(report.rejected.is_empty());
    let snapshot: Value =
        sqlx::query_scalar("select body from template_snapshots where id='myhome.checkup'")
            .fetch_one(&owner)
            .await?;
    assert_eq!(snapshot["version"], 3);
    assert_eq!(snapshot["fields"].as_array().unwrap().len(), 14);
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn official_downgrade_is_incompatible_but_server_state_still_initializes() -> Result<()> {
    let h = harness().await?;
    let mut newer: Value = serde_json::from_str(jiabu_domain::templates::OFFICIAL[0].1)?;
    newer["version"] = json!(2);
    let owner = h.app.fixture.owner().await?;
    sqlx::query("update template_snapshots set version=2,body=$1 where id='jiabu.checkup'")
        .bind(&newer)
        .execute(&owner)
        .await?;
    let store = TemplateStore::empty()?;
    let report = store.reload(&h.state.db, official_files()).await?;
    assert!(
        report
            .rejected
            .iter()
            .any(|r| r.filename == "checkup.json" && r.category == "incompatible")
    );
    assert_eq!(store.snapshot().await.templates.len(), 3);
    assert!(
        !store
            .snapshot()
            .await
            .templates
            .contains_key("jiabu.checkup")
    );
    let state = AppState::with_storage(
        h.state.db.clone(),
        jiabu_storage::BlobStore::local(h.app.fixture.data_dir())?,
        jiabu_storage::ImageLimits::default(),
    )
    .await
    .map_err(anyhow::Error::msg)?;
    assert_eq!(state.templates.snapshot().await.templates.len(), 3);
    let snapshot: Value =
        sqlx::query_scalar("select body from template_snapshots where id='jiabu.checkup'")
            .fetch_one(&owner)
            .await?;
    assert_eq!(snapshot, newer);
    owner.close().await;
    Ok(())
}
#[tokio::test]
async fn duplicate_ids_are_rejected_independent_of_file_order() -> Result<()> {
    let h = harness().await?;
    let mut input = official_files();
    input.push(file("a.json", &custom()));
    input.push(file("b.json", &custom()));
    let report = h.state.templates.reload(&h.state.db, input).await?;
    assert_eq!(
        report
            .rejected
            .iter()
            .filter(|r| r.category == "duplicate_id")
            .count(),
        2
    );
    assert_eq!(h.state.templates.snapshot().await.templates.len(), 4);
    Ok(())
}
