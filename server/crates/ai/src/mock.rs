//! Scripted fault injection. Captures are test-only caller-owned data, never logged.
use crate::{provider::*, types::*};
use async_trait::async_trait;
use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::sync::Barrier;
#[derive(Clone)]
pub enum MockStep {
    Emit(TurnEvent),
    Fail(ProviderError),
    Delay(Duration),
    Barrier(Arc<Barrier>),
}
pub type TurnScript = Vec<MockStep>;
pub struct MockProvider {
    id: String,
    capabilities: Capabilities,
    scripts: Mutex<VecDeque<TurnScript>>,
    requests: Mutex<Vec<TurnRequest>>,
}
impl MockProvider {
    pub fn scripted(
        id: impl Into<String>,
        capabilities: Capabilities,
        scripts: Vec<TurnScript>,
    ) -> Self {
        Self {
            id: id.into(),
            capabilities,
            scripts: Mutex::new(scripts.into()),
            requests: Mutex::new(vec![]),
        }
    }
    pub fn requests(&self) -> Vec<TurnRequest> {
        self.requests.lock().map(|r| r.clone()).unwrap_or_default()
    }
}
#[async_trait]
impl ModelProvider for MockProvider {
    fn id(&self) -> &str {
        &self.id
    }
    fn capabilities(&self) -> &Capabilities {
        &self.capabilities
    }
    async fn run_turn(
        &self,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
    ) -> Result<(), ProviderError> {
        self.requests
            .lock()
            .map_err(|_| ProviderError::Transport)?
            .push(req.clone());
        let script = self
            .scripts
            .lock()
            .map_err(|_| ProviderError::Transport)?
            .pop_front()
            .ok_or(ProviderError::InvalidOutput)?;
        let mut done = false;
        for step in script {
            match step {
                MockStep::Emit(e) => {
                    done |= matches!(&e, TurnEvent::Done { .. });
                    sink.emit(e).await?;
                }
                MockStep::Fail(e) => return Err(e),
                MockStep::Delay(d) => tokio::time::sleep(d).await,
                MockStep::Barrier(b) => {
                    b.wait().await;
                }
            }
        }
        if done {
            Ok(())
        } else {
            Err(ProviderError::InvalidOutput)
        }
    }
}
