//! Display tools: server-filled blocks, the three sources, and the text fallback
//! when a display tool keeps failing. Real PG18, scripted providers.
#[path = "../../../tests/support/mod.rs"]
mod support;
use anyhow::{Context, Result};
use jiabu_agent::StartMessage;
use jiabu_ai::{
    mock::{MockProvider, TurnScript},
    *,
};
use jiabu_domain::JoinEpoch;
use serde_json::{Value, json};
use std::sync::Arc;
use uuid::Uuid;
#[path = "../../../tests/support/agent.rs"]
mod agent_fixture;
use agent_fixture::*;

async fn write(f: &Fixture, tool: &str, args: Value) -> Result<Value> {
    let ctx = jiabu_tools::ToolCtx::begin(
        &f.db,
        f.p.clone(),
        f.space,
        Some(JoinEpoch(1)),
        jiabu_tools::Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(Uuid::now_v7()),
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: chrono::Utc::now(),
        },
    )
    .await?;
    Ok(f.runtime.tools.invoke(tool, args, &ctx).await?)
}
/// Two fictional expenses in October under two purposes.
async fn ledger(f: &Fixture) -> Result<()> {
    let id = |v: Value| v["id"].as_str().map(str::to_owned).context("id");
    let real = id(write(
        f,
        "create_account",
        json!({"kind":"real","name":"虚构钱包","opening_on":"2026-01-01"}),
    )
    .await?)?;
    for (name, amount) in [("虚构餐饮", 4_200), ("虚构交通", 1_800)] {
        let purpose = id(write(
            f,
            "create_account",
            json!({"kind":"purpose","name":name,"opening_on":"2026-01-01"}),
        )
        .await?)?;
        write(f, "create_record", json!({"kind":"expense","amount_minor":amount,"occurred_on":"2026-10-03","account_id":real,"purpose_id":purpose})).await?;
    }
    Ok(())
}
fn script(f: &mut Fixture, scripts: Vec<TurnScript>) {
    let mock = Arc::new(MockProvider::scripted(
        "synthetic",
        Capabilities {
            structured: StructuredMode::ToolCall,
            vision: true,
            max_images: 8,
            context_tokens: 8192,
        },
        scripts,
    ));
    let config = f.runtime.router.0.load().config.clone();
    f.runtime
        .router
        .0
        .store(Arc::new(AiRouter::new(config, vec![mock.clone()])));
    f.mock = mock;
}
fn tool_output(request: &TurnRequest, call_id: &str) -> Result<Value> {
    request
        .items
        .iter()
        .find_map(|item| match item {
            RequestItem::ToolResult {
                call_id: id,
                output,
            } if id == call_id => serde_json::from_str(output).ok(),
            _ => None,
        })
        .context("tool result in request")
}
fn query(group_by: Value) -> Value {
    json!({"measure":"sum","kinds":["expense"],"period":{"from":"2026-10-01","through":"2026-10-31"},"group_by":group_by,"account_id":null,"purpose_id":null,"tag_id":null,"member_id":null})
}
fn metrics(source: Value) -> Value {
    let mut s = json!({"query":null,"from_call":null,"demo":null});
    for (k, v) in source.as_object().into_iter().flatten() {
        s[k] = v.clone();
    }
    json!({"source":s})
}
async fn blocks(f: &Fixture, message: Uuid) -> Result<Vec<Value>> {
    Ok(f.checkpoint(message).await?.message.0["blocks"]
        .as_array()
        .context("blocks")?
        .clone())
}
async fn start(f: &Fixture, text: &str) -> Result<jiabu_agent::StartResponse> {
    Ok(f.runs()
        .start(
            &f.p,
            StartMessage {
                id: Uuid::now_v7(),
                text: Some(text.into()),
                images: vec![],
            },
        )
        .await?)
}

#[tokio::test]
async fn metrics_block_shows_names_and_money_from_the_server_query() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    ledger(&f).await?;
    script(
        &mut f,
        vec![
            vec![
                call(
                    "m",
                    "show_metrics",
                    metrics(json!({"query":query(json!("purpose"))})),
                ),
                done(),
            ],
            vec![text("餐饮最多。"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let output = tool_output(&f.mock.requests()[1], "m")?;
    assert_eq!(output["status"], "shown");
    assert_eq!(output["total"], 6_000);
    assert_eq!(output["items"][0]["label"], "虚构餐饮");
    let blocks = blocks(&f, r.message_id).await?;
    let block = blocks
        .iter()
        .find(|b| b["type"] == "metric_group")
        .context("metric_group")?;
    assert_eq!(block["data"]["title"], "2026年10月支出 · 按用途");
    assert_eq!(block["data"]["metrics"][0]["label"], "虚构餐饮");
    assert_eq!(block["data"]["metrics"][0]["value"], 4_200);
    assert_eq!(block["data"]["metrics"][0]["format"]["minorUnits"], true);
    // Names, never internal ids, and no bilingual titles.
    let shown = block["data"].to_string();
    assert!(!shown.contains("-7"), "uuid leaked: {shown}");
    assert!(!shown.contains(" / "), "{shown}");
    Ok(())
}
#[tokio::test]
async fn trend_fills_empty_months_and_records_list_names() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    ledger(&f).await?;
    let mut trend = metrics(json!({"query":query(Value::Null)}));
    trend["source"]["query"]
        .as_object_mut()
        .context("query")?
        .remove("group_by");
    trend["source"]["query"]["period"] = json!({"from":"2026-08-01","through":"2026-10-31"});
    let records = json!({"source":{"query":{"kinds":[],"period":null,"account_id":null,"purpose_id":null,"tag_id":null,"member_id":null,"text":null,"limit":10},"from_call":null,"demo":null}});
    script(
        &mut f,
        vec![
            vec![
                call("t", "show_trend", trend),
                call("r", "show_records", records),
                done(),
            ],
            vec![text("见上。"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let blocks = blocks(&f, r.message_id).await?;
    let series = blocks
        .iter()
        .find(|b| b["type"] == "time_series")
        .context("time_series")?;
    let points = &series["data"]["series"][0]["points"];
    assert_eq!(
        points,
        &json!([{"x":"8月","y":0.0},{"x":"9月","y":0.0},{"x":"10月","y":60.0}])
    );
    let table = blocks
        .iter()
        .find(|b| b["type"] == "dataset")
        .context("dataset")?;
    assert_eq!(table["data"]["title"], "记录明细");
    let rows = table["data"]["rows"].as_array().context("rows")?;
    assert_eq!(rows.len(), 2);
    assert!(rows.iter().all(|r| r["account"] == "虚构钱包"), "{rows:?}");
    Ok(())
}
#[tokio::test]
async fn no_data_is_not_a_mistake_and_shows_no_block() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    let call_metrics = || {
        call(
            "m",
            "show_metrics",
            metrics(json!({"query":query(Value::Null)})),
        )
    };
    script(
        &mut f,
        vec![
            vec![call_metrics(), done()],
            vec![text("这个月还没有记账。"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let output = tool_output(&f.mock.requests()[1], "m")?;
    assert_eq!(output["status"], "no_data");
    assert!(output.get("error").is_none());
    assert!(
        blocks(&f, r.message_id)
            .await?
            .iter()
            .all(|b| b["type"] == "markdown")
    );
    Ok(())
}
#[tokio::test]
async fn demo_only_when_the_user_asked_and_always_marked() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    let demo = || {
        call(
            "d",
            "show_metrics",
            metrics(json!({"demo":"monthly_spending"})),
        )
    };
    script(
        &mut f,
        vec![vec![demo(), done()], vec![text("好的。"), done()]],
    );
    let r = f.start().await?;
    f.work().await?;
    let output = tool_output(&f.mock.requests()[1], "d")?;
    assert_eq!(
        output["errors"],
        json!([{"pointer":"/source/demo","rule":"demo_not_requested: query the ledger instead"}])
    );
    assert!(
        blocks(&f, r.message_id)
            .await?
            .iter()
            .all(|b| b["type"] == "markdown")
    );

    script(
        &mut f,
        vec![vec![demo(), done()], vec![text("这是示意。"), done()]],
    );
    let r = start(&f, "演示一下你能画哪些图").await?;
    f.work().await?;
    let blocks = blocks(&f, r.message_id).await?;
    let block = blocks
        .iter()
        .find(|b| b["type"] == "metric_group")
        .context("metric_group")?;
    assert!(
        block["data"]["title"]
            .as_str()
            .is_some_and(|t| t.starts_with("【演示数据】"))
    );
    assert!(
        block["fallbackText"]
            .as_str()
            .is_some_and(|t| t.starts_with("【演示数据】"))
    );
    Ok(())
}
#[tokio::test]
async fn from_call_reuses_an_earlier_query_and_checks_its_tool() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    ledger(&f).await?;
    let stats = json!({"measure":"sum","period":{"from":"2026-10-01","through":"2026-10-31"},"group_by":"purpose"});
    script(
        &mut f,
        vec![
            vec![call("q", "query_stats", stats), done()],
            vec![
                call(
                    "wrong",
                    "show_records",
                    json!({"source":{"query":null,"from_call":"q","demo":null}}),
                ),
                done(),
            ],
            vec![
                call("m", "show_metrics", metrics(json!({"from_call":"q"}))),
                done(),
            ],
            vec![text("好的。"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let requests = f.mock.requests();
    let wrong = tool_output(&requests[2], "wrong")?;
    assert_eq!(wrong["errors"][0]["pointer"], "/source/from_call");
    let output = tool_output(&requests[3], "m")?;
    assert_eq!(output["total"], 6_000);
    assert_eq!(output["items"][0]["label"], "虚构餐饮");
    Ok(())
}
#[tokio::test]
async fn from_call_reapplies_the_display_period_limit() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    ledger(&f).await?;
    let period = json!({"from":"2024-01-01","through":"2026-01-31"});
    script(
        &mut f,
        vec![
            vec![
                call(
                    "qm",
                    "query_stats",
                    json!({"measure":"sum","period":period,"group_by":"purpose"}),
                ),
                call(
                    "qt",
                    "query_stats",
                    json!({"measure":"sum","period":period,"group_by":"month"}),
                ),
                call(
                    "sr",
                    "search_records",
                    json!({"filters":{"from":"2024-01-01","through":"2026-01-31"},"page":{"limit":10,"offset":0}}),
                ),
                done(),
            ],
            vec![
                call("m", "show_metrics", metrics(json!({"from_call":"qm"}))),
                call("t", "show_trend", metrics(json!({"from_call":"qt"}))),
                call(
                    "r",
                    "show_records",
                    json!({"source":{"query":null,"from_call":"sr","demo":null}}),
                ),
                done(),
            ],
            vec![text("时间范围太长，请缩短。"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let request = &f.mock.requests()[2];
    for call_id in ["m", "t", "r"] {
        let output = tool_output(request, call_id)?;
        assert_eq!(output["errors"][0]["pointer"], "/source/from_call");
        assert_eq!(output["errors"][0]["rule"], "period: at most 24 months");
    }
    Ok(())
}
#[tokio::test]
async fn protocol_invalid_display_block_is_replaced_with_its_full_text_fallback() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    ledger(&f).await?;
    // Historical data can predate today's note limit. Its oversized dataset
    // cell makes ChatWeave reject the structured block, while the display
    // fallback remains small and readable because it summarizes each row.
    sqlx::query("alter table records drop constraint records_note_check")
        .execute(&f.owner)
        .await?;
    sqlx::query("update records set note=$2 where space_id=$1")
        .bind(f.space.0)
        .bind("x".repeat(70 * 1024))
        .execute(&f.owner)
        .await?;
    let records = json!({"source":{"query":{"kinds":[],"period":{"from":"2026-10-01","through":"2026-10-31"},"account_id":null,"purpose_id":null,"tag_id":null,"member_id":null,"text":null,"limit":10},"from_call":null,"demo":null}});
    script(
        &mut f,
        vec![
            vec![call("r", "show_records", records), done()],
            vec![text("以上是本月记录。"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let blocks = blocks(&f, r.message_id).await?;
    assert!(blocks.iter().all(|block| block["type"] != "dataset"));
    let fallback = blocks
        .iter()
        .find(|block| {
            block["type"] == "markdown"
                && block["data"]["text"]
                    .as_str()
                    .is_some_and(|text| text.starts_with("2026年10月记录："))
        })
        .context("display text fallback")?;
    let text = fallback["data"]["text"].as_str().context("fallback text")?;
    assert!(text.contains("¥42.00 虚构餐饮"), "{text}");
    assert!(text.contains("¥18.00 虚构交通"), "{text}");
    Ok(())
}
#[tokio::test]
async fn a_display_tool_that_keeps_failing_falls_back_to_text() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    let bad = || metrics(json!({"query":query(json!("month"))}));
    script(
        &mut f,
        vec![
            vec![call("b1", "show_metrics", bad()), done()],
            vec![call("b2", "show_metrics", bad()), done()],
            vec![call("b3", "show_metrics", bad()), done()],
            vec![
                call(
                    "b4",
                    "show_metrics",
                    metrics(json!({"query":query(Value::Null)})),
                ),
                done(),
            ],
            vec![text("这个月共花了一些钱。"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    assert_eq!(run.status, "completed", "{:?}", run.last_error);
    let requests = f.mock.requests();
    assert_eq!(requests.len(), 5);
    let b1 = tool_output(&requests[1], "b1")?;
    assert_eq!(b1["errors"][0]["pointer"], "/source/query/group_by");
    // After the third failure the model is told to answer in text.
    let note = requests[3].items.iter().any(|i| matches!(i, RequestItem::Message { role, text, .. } if role == "developer" && text.contains("display_unavailable")));
    assert!(note);
    // A further call is refused without running.
    assert_eq!(
        tool_output(&requests[4], "b4")?["error"],
        "display_unavailable"
    );
    Ok(())
}
#[tokio::test]
async fn write_tools_still_fail_the_run_at_the_bound() -> Result<()> {
    // Negative control for the display exemption.
    let mut f = Fixture::new(vec![]).await?;
    let bad = |id: &str| {
        vec![
            call(
                id,
                "create_record",
                json!({"kind":"expense","amount_minor":"x","occurred_on":"2026-01-01"}),
            ),
            done(),
        ]
    };
    script(
        &mut f,
        vec![
            bad("w1"),
            bad("w2"),
            bad("w3"),
            vec![text("不应调用"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(
        f.run(r.message_id).await?.last_error.as_deref(),
        Some("tool_arguments_rejected")
    );
    assert_eq!(f.mock.requests().len(), 3);
    Ok(())
}
#[tokio::test]
async fn preset_tags_show_their_name_and_reused_searches_drop_voided_records() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    ledger(&f).await?;
    // Void one of the two records so a reused unfiltered search contains it.
    let search = json!({"filters":{},"page":{"limit":10}});
    let found = sqlx::query_scalar::<_, Uuid>(
        "select id from records where space_id=$1 order by amount_minor desc limit 1",
    )
    .bind(f.space.0)
    .fetch_one(&f.owner)
    .await?;
    write(&f, "void_record", json!({"id":found,"expected_version":1})).await?;
    let preset: Uuid = sqlx::query_scalar(
        "select id from tags where space_id=$1 and preset_key is not null limit 1",
    )
    .bind(f.space.0)
    .fetch_one(&f.owner)
    .await?;
    let preset_name: String = sqlx::query_scalar("select preset_key from tags where id=$1")
        .bind(preset)
        .fetch_one(&f.owner)
        .await?;
    let mut steps = vec![
        vec![call("s", "search_records", search), done()],
        vec![
            call(
                "r",
                "show_records",
                json!({"source":{"query":null,"from_call":"s","demo":null}}),
            ),
            done(),
        ],
    ];
    let real: Uuid =
        sqlx::query_scalar("select id from accounts where space_id=$1 and kind='real' limit 1")
            .bind(f.space.0)
            .fetch_one(&f.owner)
            .await?;
    let purpose: Uuid =
        sqlx::query_scalar("select id from accounts where space_id=$1 and kind='purpose' limit 1")
            .bind(f.space.0)
            .fetch_one(&f.owner)
            .await?;
    write(&f, "create_record", json!({"kind":"expense","amount_minor":900,"occurred_on":"2026-10-05","account_id":real,"purpose_id":purpose,"tag_ids":[preset]})).await?;
    steps.push(vec![
        call(
            "m",
            "show_metrics",
            metrics(json!({"query":query(json!("tag"))})),
        ),
        done(),
    ]);
    steps.push(vec![text("好的。"), done()]);
    script(&mut f, steps);
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let requests = f.mock.requests();
    let rows = tool_output(&requests[2], "r")?["rows"].clone();
    assert_eq!(rows.as_array().map(Vec::len), Some(2), "{rows}");
    assert!(
        rows.as_array()
            .into_iter()
            .flatten()
            .all(|row| row["amount_minor"] != 4_200),
        "{rows}"
    );
    let zh = jiabu_domain::presets::PRESETS
        .iter()
        .find(|p| p.preset_key == preset_name)
        .map(|p| p.zh)
        .context("preset")?;
    let items = tool_output(&requests[3], "m")?["items"].clone();
    assert!(
        items
            .as_array()
            .into_iter()
            .flatten()
            .any(|i| i["label"] == zh),
        "{items}"
    );
    Ok(())
}
