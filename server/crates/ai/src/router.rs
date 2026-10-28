use crate::{billing, breaker::Breaker, provider::*, types::*};
use arc_swap::ArcSwap;
use jiabu_domain::ai::AiConfig;
use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
    time::Instant,
};
type Breakers = Arc<Mutex<BTreeMap<String, Breaker>>>;
pub struct AiRouter {
    pub config: AiConfig,
    providers: BTreeMap<String, Arc<dyn ModelProvider>>,
    breakers: Breakers,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AiAvailability {
    pub available: bool,
    pub reason: &'static str,
}
pub struct RouterStore(pub ArcSwap<AiRouter>);
impl Default for RouterStore {
    fn default() -> Self {
        Self(ArcSwap::from_pointee(AiRouter::new(
            AiConfig::default(),
            vec![],
        )))
    }
}
impl AiRouter {
    pub fn new(config: AiConfig, providers: Vec<Arc<dyn ModelProvider>>) -> Self {
        Self {
            config,
            providers: providers
                .into_iter()
                .map(|p| (p.id().to_owned(), p))
                .collect(),
            breakers: Arc::new(Mutex::new(BTreeMap::new())),
        }
    }
    /// Preserve breaker state across ALL config versions, even temporary removal.
    pub fn reloaded(&self, config: AiConfig, providers: Vec<Arc<dyn ModelProvider>>) -> Self {
        let mut next = Self::new(config, providers);
        next.breakers = self.breakers.clone();
        next
    }
    fn candidates(
        &self,
        task: TaskKind,
    ) -> Vec<(&jiabu_domain::ai::ModelConfig, &Arc<dyn ModelProvider>)> {
        let mut routes: Vec<_> = self
            .config
            .routes
            .iter()
            .filter(|r| r.task_kind == task)
            .collect();
        routes.sort_by_key(|r| r.position);
        routes
            .into_iter()
            .filter_map(|r| {
                let m = self
                    .config
                    .models
                    .iter()
                    .find(|m| m.id == r.model_id && m.enabled)?;
                let p = self
                    .config
                    .providers
                    .iter()
                    .find(|p| p.id == m.provider_id && p.enabled)?;
                if !billing::allowed(p.billing, self.config.allow_paid_fallback) {
                    return None;
                }
                let adapter = self.providers.get(&p.id)?;
                if !adapter.credentials_available()
                    || (task == TaskKind::ChatVision
                        && (!m.vision || !adapter.capabilities().vision))
                {
                    return None;
                }
                Some((m, adapter))
            })
            .collect()
    }
    pub fn availability(&self, task: TaskKind) -> AiAvailability {
        let Ok(breakers) = self.breakers.lock() else {
            return AiAvailability {
                available: false,
                reason: "unavailable",
            };
        };
        let available = self.candidates(task).iter().any(|(_, p)| {
            breakers
                .get(p.id())
                .is_none_or(|b| b.available(Instant::now(), &self.config.breaker))
        });
        AiAvailability {
            available,
            reason: if available {
                "available"
            } else {
                "unavailable"
            },
        }
    }
    pub async fn run_turn(
        &self,
        task: TaskKind,
        req: &TurnRequest,
        sink: &mut dyn TurnSink,
        observer: &dyn CallObserver,
    ) -> Result<(), ProviderError> {
        let mut last = ProviderError::Unsupported("no available route");
        for (model, provider) in self.candidates(task) {
            let image_count: usize = req
                .items
                .iter()
                .map(|i| {
                    if let RequestItem::Message { images, .. } = i {
                        images.len()
                    } else {
                        0
                    }
                })
                .sum();
            if image_count > usize::from(provider.capabilities().max_images)
                || (image_count > 0 && !model.vision)
            {
                continue;
            }
            {
                let mut breakers = self.breakers.lock().map_err(|_| ProviderError::Transport)?;
                if !breakers
                    .entry(provider.id().into())
                    .or_default()
                    .claim(Instant::now(), &self.config.breaker)
                {
                    continue;
                }
            }
            let mut request = req.clone();
            request.snapshot.model = model.model.clone();
            let mut retried_blob = false;
            let mut retried_format = false;
            let result = loop {
                let result =
                    measured_attempt(provider.as_ref(), task, &request, sink, observer).await;
                if result == Err(ProviderError::BlobRejected)
                    && !retried_blob
                    && !request.provider_blobs.is_empty()
                {
                    retried_blob = true;
                    request.provider_blobs.clear();
                    sink.emit(TurnEvent::Note(
                        "Encrypted reasoning was unavailable; continuing from recorded results."
                            .into(),
                    ))
                    .await?;
                    request.items.push(RequestItem::Message { role: "developer".into(), text: "Continue using the recorded results; encrypted reasoning was unavailable.".into(), images: vec![] });
                    continue;
                }
                if result == Err(ProviderError::InvalidOutput) && !retried_format {
                    retried_format = true;
                    continue;
                }
                break result;
            };
            self.breakers
                .lock()
                .map_err(|_| ProviderError::Transport)?
                .entry(provider.id().into())
                .or_default()
                .finish(result.is_ok(), Instant::now(), &self.config.breaker);
            match result {
                Ok(()) => return Ok(()),
                Err(e @ (ProviderError::Sink | ProviderError::Meter)) => return Err(e),
                Err(e) => last = e,
            }
        }
        Err(last)
    }
}
