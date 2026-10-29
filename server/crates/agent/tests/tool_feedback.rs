//! Tool-argument feedback, error classes and output-order replay. Real PG18,
//! scripted providers; never a live model.
#[path = "../../../tests/support/mod.rs"]
mod support;
use anyhow::{Context, Result};
use jiabu_ai::{
    mock::{MockProvider, MockStep, TurnScript},
    *,
};
use jiabu_domain::JoinEpoch;
use serde_json::{Value, json};
use std::sync::Arc;
use uuid::Uuid;
#[path = "../../../tests/support/agent.rs"]
mod agent_fixture;
use agent_fixture::*;

async fn account(f: &Fixture, kind: &str, name: &str) -> Result<Uuid> {
    let id = Uuid::now_v7();
    let ctx = jiabu_tools::ToolCtx::begin(
        &f.db,
        f.p.clone(),
        f.space,
        Some(JoinEpoch(1)),
        jiabu_tools::Effect::LocalWrite,
        jiabu_tools::Invocation {
            idempotency_key: Some(id),
            replay_key: None,
            run_id: None,
            request_id: Uuid::now_v7(),
            now: chrono::Utc::now(),
        },
    )
    .await?;
    f.runtime
        .tools
        .invoke(
            "create_account",
            json!({"kind":kind,"name":name,"opening_on":"2026-01-01"}),
            &ctx,
        )
        .await?;
    Ok(id)
}
/// Replace the scripted provider after accounts exist, so scripts can name their ids.
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
async fn records(f: &Fixture) -> Result<i64> {
    Ok(
        sqlx::query_scalar("select count(*) from records where space_id=$1")
            .bind(f.space.0)
            .fetch_one(&f.owner)
            .await?,
    )
}
async fn call_status(f: &Fixture, run: Uuid, call: &str) -> Result<String> {
    Ok(
        sqlx::query_scalar("select status from agent_tool_calls where run_id=$1 and call_id=$2")
            .bind(run)
            .bind(call)
            .fetch_one(&f.owner)
            .await?,
    )
}
async fn expense(f: &Fixture) -> Result<Value> {
    let real = account(f, "real", "虚构钱包").await?;
    let purpose = account(f, "purpose", "虚构餐饮用途").await?;
    Ok(
        json!({"kind":"expense","amount_minor":1800,"occurred_on":"2026-01-01","account_id":real,"purpose_id":purpose}),
    )
}
fn bad_amount(valid: &Value) -> Value {
    let mut bad = valid.clone();
    bad["amount_minor"] = json!("十八元");
    bad
}

#[tokio::test]
async fn invalid_arguments_return_to_the_model_and_the_second_try_records() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    let valid = expense(&f).await?;
    script(
        &mut f,
        vec![
            vec![call("bad", "create_record", bad_amount(&valid)), done()],
            vec![call("good", "create_record", valid), done()],
            vec![text("已记录 / Recorded"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    assert_eq!(run.status, "completed");
    assert_eq!(records(&f).await?, 1);
    let requests = f.mock.requests();
    assert_eq!(requests.len(), 3);
    let output = tool_output(&requests[1], "bad")?;
    assert_eq!(output["error"], "invalid_arguments");
    assert!(
        output["errors"]
            .as_array()
            .context("errors")?
            .iter()
            .any(|e| e["pointer"] == "/amount_minor" && e["rule"] == "type"),
        "{output}"
    );
    // Schema-side names only: the rejected value itself is not echoed back.
    assert!(!output.to_string().contains("十八元"));
    assert_eq!(call_status(&f, run.id, "bad").await?, "rejected");
    assert_eq!(call_status(&f, run.id, "good").await?, "succeeded");
    Ok(())
}
#[tokio::test]
async fn two_corrections_are_allowed_and_a_third_rejection_fails_the_run() -> Result<()> {
    // Negative control first: exactly at the bound the run still completes.
    let mut f = Fixture::new(vec![]).await?;
    let valid = expense(&f).await?;
    script(
        &mut f,
        vec![
            vec![call("bad1", "create_record", bad_amount(&valid)), done()],
            vec![call("bad2", "create_record", bad_amount(&valid)), done()],
            vec![call("good", "create_record", valid.clone()), done()],
            vec![text("已记录 / Recorded"), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    assert_eq!(records(&f).await?, 1);

    let mut f = Fixture::new(vec![]).await?;
    let valid = expense(&f).await?;
    script(
        &mut f,
        vec![
            vec![call("bad1", "create_record", bad_amount(&valid)), done()],
            vec![call("bad2", "create_record", bad_amount(&valid)), done()],
            vec![call("bad3", "create_record", bad_amount(&valid)), done()],
            vec![call("good", "create_record", valid), done()],
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    assert_eq!(run.status, "failed");
    assert_eq!(run.last_error.as_deref(), Some("tool_arguments_rejected"));
    assert_eq!(f.mock.requests().len(), 3, "no fourth model call");
    assert_eq!(records(&f).await?, 0);
    Ok(())
}
#[tokio::test]
async fn execution_validation_names_the_missing_purpose_account() -> Result<()> {
    let mut f = Fixture::new(vec![]).await?;
    let real = account(&f, "real", "虚构现金").await?;
    script(
        &mut f,
        vec![
            vec![
                call(
                    "no_purpose",
                    "create_record",
                    json!({"kind":"expense","amount_minor":1800,"occurred_on":"2026-01-01","account_id":real}),
                ),
                done(),
            ],
            question(),
        ],
    );
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "paused");
    let output = tool_output(&f.mock.requests()[1], "no_purpose")?;
    assert_eq!(output["error"], "validation_failed");
    assert_eq!(
        output["errors"],
        json!([{"pointer":"/purpose_id","rule":"required_for_kind"}])
    );
    assert!(output["note"].is_string());
    Ok(())
}
#[tokio::test]
async fn unknown_tool_and_unparseable_arguments_are_correctable() -> Result<()> {
    let f = Fixture::new(vec![
        vec![
            call("missing", "missing_tool", json!({})),
            MockStep::Emit(TurnEvent::ToolCall {
                call_id: "garbled".into(),
                name: "list_accounts".into(),
                args_raw: "{not json".into(),
            }),
            done(),
        ],
        vec![text("好的 / OK"), done()],
    ])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    assert_eq!(run.status, "completed");
    let requests = f.mock.requests();
    let missing = tool_output(&requests[1], "missing")?;
    assert_eq!(missing["error"], "unknown_tool");
    assert!(
        missing["available"]
            .as_array()
            .context("available")?
            .contains(&json!("list_accounts"))
    );
    let garbled = tool_output(&requests[1], "garbled")?;
    assert_eq!(garbled["error"], "invalid_arguments");
    assert_eq!(garbled["errors"][0]["rule"], "json_object");
    assert_eq!(call_status(&f, run.id, "garbled").await?, "rejected");
    Ok(())
}
#[tokio::test]
async fn duplicate_call_id_is_stream_corruption_not_feedback() -> Result<()> {
    let f = Fixture::new(vec![vec![
        call("same", "list_accounts", json!({})),
        call("same", "list_accounts", json!({})),
        done(),
    ]])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    // The first call already reached the sink, so the turn cannot be retried silently.
    assert_eq!(run.status, "interrupted");
    assert_eq!(run.last_error.as_deref(), Some("partial_output"));
    assert_eq!(f.mock.requests().len(), 1);
    Ok(())
}
#[tokio::test]
async fn upstream_rejection_fails_once_without_retry_or_waiting() -> Result<()> {
    let f = Fixture::new(vec![
        vec![MockStep::Fail(ProviderError::Rejected {
            code: "invalid_function_parameters".into(),
            param: "tools".into(),
            message: "synthetic".into(),
        })],
        vec![text("不应调用 / Unused"), done()],
    ])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    let run = f.run(r.message_id).await?;
    assert_eq!(run.status, "failed");
    assert_eq!(
        run.last_error.as_deref(),
        Some("request_rejected:invalid_function_parameters")
    );
    assert_eq!(f.mock.requests().len(), 1);
    Ok(())
}
#[tokio::test]
async fn stream_corruption_retries_once_then_fails_instead_of_waiting() -> Result<()> {
    // Negative control: one corrupt attempt, then a good one, completes.
    let f = Fixture::new(vec![
        vec![MockStep::Fail(ProviderError::InvalidOutput)],
        vec![text("好的 / OK"), done()],
    ])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    assert_eq!(f.mock.requests().len(), 2);

    for (error, reason) in [
        (ProviderError::InvalidOutput, "invalid_output"),
        (
            ProviderError::Incomplete {
                reason: "max_output_tokens".into(),
            },
            "incomplete:max_output_tokens",
        ),
    ] {
        let f = Fixture::new(vec![
            vec![MockStep::Fail(error.clone())],
            vec![MockStep::Fail(error)],
            vec![text("不应调用 / Unused"), done()],
        ])
        .await?;
        let r = f.start().await?;
        f.work().await?;
        let run = f.run(r.message_id).await?;
        assert_eq!(run.status, "failed");
        assert_eq!(run.last_error.as_deref(), Some(reason));
        assert_eq!(f.mock.requests().len(), 2, "exactly one retry");
        assert!(!f.work().await?, "nothing left queued");
    }
    Ok(())
}
#[tokio::test]
async fn unmapped_upstream_failure_still_waits_for_ai() -> Result<()> {
    let failure = ProviderError::UpstreamFailed {
        code: "server_error".into(),
    };
    let f = Fixture::new(vec![
        vec![MockStep::Fail(failure.clone())],
        vec![MockStep::Fail(failure)],
    ])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "waiting_ai");
    assert_eq!(f.mock.requests().len(), 2);
    Ok(())
}
#[tokio::test]
async fn replay_keeps_output_order_and_phase() -> Result<()> {
    let f = Fixture::new(vec![
        vec![
            text("先查一下账户。"),
            MockStep::Emit(TurnEvent::MessageDone {
                text: "先查一下账户。".into(),
                phase: Some("commentary".into()),
            }),
            call("look", "list_accounts", json!({})),
            done(),
        ],
        vec![text("没有账户 / No accounts"), done()],
    ])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let second = &f.mock.requests()[1];
    let tail: Vec<String> = second
        .items
        .iter()
        .skip_while(|i| !matches!(i, RequestItem::AssistantMessage { .. }))
        .map(|i| match i {
            RequestItem::AssistantMessage { text, phase } => {
                format!("message:{text}:{}", phase.as_deref().unwrap_or("-"))
            }
            RequestItem::ToolCall { call_id, .. } => format!("call:{call_id}"),
            RequestItem::ToolResult { call_id, .. } => format!("result:{call_id}"),
            _ => "other".into(),
        })
        .collect();
    assert_eq!(
        tail,
        vec![
            "message:先查一下账户。:commentary",
            "call:look",
            "result:look"
        ]
    );
    Ok(())
}
#[tokio::test]
async fn undelimited_text_still_replays_before_calls() -> Result<()> {
    let f = Fixture::new(vec![
        vec![
            text("先查。"),
            call("look", "list_accounts", json!({})),
            done(),
        ],
        vec![text("好 / OK"), done()],
    ])
    .await?;
    let r = f.start().await?;
    f.work().await?;
    assert_eq!(f.run(r.message_id).await?.status, "completed");
    let second = &f.mock.requests()[1];
    let position = |pred: &dyn Fn(&RequestItem) -> bool| second.items.iter().position(pred);
    let message = position(
        &|i| matches!(i, RequestItem::AssistantMessage { text, phase: None } if text == "先查。"),
    )
    .context("assistant message")?;
    let call = position(&|i| matches!(i, RequestItem::ToolCall { .. })).context("call")?;
    assert!(message < call);
    Ok(())
}
