//! Recorded live SIWC output (crates/ai/tests/fixtures/siwc) through the real SIWC
//! parser and then the real Agent loop, tool validation and PG, without the subscription.
use ai_eval::{dataset, fixture::Scenario};
use anyhow::{Context, Result};
use jiabu_ai::{
    ProviderError, TurnEvent, TurnSink,
    mock::MockStep,
    siwc::stream::{Decoder, TurnState},
};
#[derive(Default)]
struct Collect(Vec<TurnEvent>);
#[async_trait::async_trait]
impl TurnSink for Collect {
    async fn emit(&mut self, event: TurnEvent) -> Result<(), ProviderError> {
        self.0.push(event);
        Ok(())
    }
}
async fn parse(name: &str) -> Result<Vec<TurnEvent>> {
    let path = format!(
        "{}/../ai/tests/fixtures/siwc/{name}",
        env!("CARGO_MANIFEST_DIR")
    );
    let bytes = std::fs::read(path)?;
    let (mut decoder, mut turn, mut sink) =
        (Decoder::default(), TurnState::default(), Collect::default());
    for event in decoder.push(&bytes)? {
        turn.accept(event, &mut sink).await?;
        if turn.completed() {
            turn.finish("chatgpt", "gpt-6.1-sol", "synthetic-account", &mut sink)
                .await?;
            return Ok(sink.0);
        }
    }
    anyhow::bail!("fixture has no response.completed")
}
#[tokio::test]
async fn recorded_ask_user_call_passes_agent_validation_and_pauses_the_run() -> Result<()> {
    // The capture's prompt context is this entry's scenario.
    let root = ai_eval::dataset_root();
    let entry = dataset::load(&root)?
        .into_iter()
        .find(|e| e.id == "zh-single-001")
        .context("entry")?;
    let script = parse("tool_call.response.sse")
        .await?
        .into_iter()
        .map(MockStep::Emit)
        .collect();
    let scratch = std::env::var("DATABASE_URL").context("DATABASE_URL")?;
    let scenario = Scenario::new(&entry, &root, &scratch, None, Some(vec![script])).await?;
    let message = scenario.submit(&entry).await?;
    scenario.drive(message).await?;
    let observed = scenario.observe(message, None, false, 0).await?;
    assert!(
        observed.asked && observed.status == "paused",
        "status {}, asked {}",
        observed.status,
        observed.asked
    );
    Ok(())
}
