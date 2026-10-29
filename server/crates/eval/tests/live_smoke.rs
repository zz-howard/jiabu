#![cfg(feature = "live")]
use ai_eval::{dataset::{self,Behavior,RecordSpec},fixture::Scenario,scoring};
use anyhow::{Context,Result,ensure};
use serde_json::json;
async fn smoke(id:&str,answer:Option<&str>)->Result<()> {
    let root=ai_eval::dataset_root();let entries=dataset::load(&root)?;
    let mut entry=entries.into_iter().find(|e|e.id==id).context("smoke entry")?;
    let source=std::env::var("DATABASE_URL").context("DATABASE_URL")?;
    let scratch=std::env::var("EVAL_DATABASE_URL").context("EVAL_DATABASE_URL")?;
    ensure!(source!=scratch,"source and scratch must differ");
    let providers=ai_eval::live::load(&source).await?;
    let scenario=Scenario::new(&entry,&root,&scratch,Some(&providers),None).await?;
    let message=scenario.submit(&entry).await?;scenario.drive(message).await?;
    if let Some(answer)=answer {
        let first=scenario.observe(message,None,false,0).await?;
        let result=scoring::score(&entry,&scenario.ids,&first);
        ensure!(result.hard_pass && first.asked && first.status=="paused","expected question without writes");
        scenario.answer(message,json!({"freeText":answer})).await?;
        scenario.drive(message).await?;
        entry.expect.behavior=Behavior::Write;entry.expect.hard=false;
        entry.expect.records=vec![RecordSpec{operation:"create".into(),kind:Some("expense".into()),amount_minor:Some(1800),currency:Some("CNY".into()),occurred_on:Some(entry.today-chrono::Duration::days(1)),preset_key:Some("dining".into()),account:Some("cash".into()),purpose:Some("daily".into()),..RecordSpec::default()}];
    }
    let observation=scenario.observe(message,None,false,0).await?;
    let result=scoring::score(&entry,&scenario.ids,&observation);
    for (index,call) in observation.calls.iter().enumerate() {
        let kind=call["call_kind"].as_str().unwrap_or("unknown");
        let label=match kind {"continue"=>"运行内续调","resume"=>"暂停后恢复","first"=>"首次调用","retry"=>"显式重试",_=>"未知"};
        // Print only allowlisted metering fields, never arbitrary errors/content.
        println!("{} call={} kind={} ({}) cached_read={} cache_write={} uncached_input={}",entry.id,index+1,kind,label,call["cached_input_tokens"],call["cache_write_tokens"],call["uncached_input_tokens"]);
    }
    ensure!(observation.status=="completed" && result.records_pass,"smoke final ledger mismatch");
    if answer.is_some() {ensure!(observation.calls.iter().any(|c|c["call_kind"]=="resume"),"missing resume call");}
    Ok(())
}
// A static error protects the test harness's own Result printer from exposing a
// database connection URL or upstream body if an underlying dependency fails.
#[tokio::test]
#[ignore = "requires configured SIWC credentials and disposable PG18"]
async fn live_text_entry()->Result<()> {smoke("zh-single-001",None).await.map_err(|_|anyhow::anyhow!("live text smoke failed (private diagnostics suppressed)"))}
#[tokio::test]
#[ignore = "requires configured SIWC credentials and generated receipt JPEG"]
async fn live_receipt_entry()->Result<()> {smoke("zh-receipt-001",None).await.map_err(|_|anyhow::anyhow!("live receipt smoke failed (private diagnostics suppressed)"))}
#[tokio::test]
#[ignore = "requires configured SIWC credentials and disposable PG18"]
async fn live_question_answer_then_write()->Result<()> {smoke("insufficient-001",Some("午饭18元，用虚构零钱和日常用途，餐饮分类。")).await.map_err(|_|anyhow::anyhow!("live question smoke failed (private diagnostics suppressed)"))}
