use crate::{billing, breaker::Breaker, provider::*, types::*};
use arc_swap::ArcSwap;
use jiabu_domain::ai::AiConfig;
use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
    time::Instant,
};
type Breakers = Arc<Mutex<BTreeMap<String, Breaker>>>;
/// Owns the half-open claim across every await, early return and cancellation.
struct ProbePermit {
    breakers: Breakers,
    provider: String,
    generation: u64,
    config: jiabu_domain::ai::BreakerConfig,
    finished: bool,
}
impl ProbePermit {
    fn finish(&mut self, success: bool) {
        if let Ok(mut breakers) = self.breakers.lock() {
            breakers.entry(self.provider.clone()).or_default().finish(
                self.generation,
                success,
                Instant::now(),
                &self.config,
            );
        }
        self.finished = true;
    }
}
impl Drop for ProbePermit {
    fn drop(&mut self) {
        if !self.finished {
            self.finish(false);
        }
    }
}
pub(crate) struct OutputSink<'a> {
    pub(crate) inner: &'a mut dyn TurnSink,
    pub(crate) visible: bool,
}
#[async_trait::async_trait]
impl TurnSink for OutputSink<'_> {
    fn record_usage(&mut self, usage: &Usage) {
        self.inner.record_usage(usage);
    }
    async fn emit(&mut self, event: TurnEvent) -> Result<(), ProviderError> {
        let visible = match &event {
            TurnEvent::TextDelta(text) => !text.is_empty(),
            TurnEvent::ToolCall { .. } | TurnEvent::Note(_) => true,
            _ => false,
        };
        // Mark before awaiting: a sink may publish output and then fail persistence.
        self.visible |= visible;
        self.inner.emit(event).await
    }
}
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
            AiConfig {
                version: -1,
                ..AiConfig::default()
            },
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
    fn request_counts(req: Option<&TurnRequest>) -> (usize, usize) {
        req.map_or((0, 0), |request| {
            request.items.iter().fold((0, 0), |counts, item| {
                if let RequestItem::Message { images, files, .. } = item {
                    (counts.0 + images.len(), counts.1 + files.len())
                } else {
                    counts
                }
            })
        })
    }
    fn static_candidates(
        &self,
        task: TaskKind,
        req: Option<&TurnRequest>,
    ) -> Vec<(&jiabu_domain::ai::ModelConfig, &Arc<dyn ModelProvider>)> {
        let (image_count, file_count) = Self::request_counts(req);
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
                let capabilities = adapter.capabilities();
                if (task == TaskKind::ChatVision && (!m.vision || !capabilities.vision))
                    || (task == TaskKind::ChatFile
                        && (!capabilities.files
                            || file_count > usize::from(capabilities.max_files)
                            || (image_count > 0
                                && (!m.vision
                                    || !capabilities.vision
                                    || image_count > usize::from(capabilities.max_images)))))
                {
                    return None;
                }
                Some((m, adapter))
            })
            .collect()
    }
    fn candidates(
        &self,
        task: TaskKind,
        req: Option<&TurnRequest>,
    ) -> Vec<(&jiabu_domain::ai::ModelConfig, &Arc<dyn ModelProvider>)> {
        self.static_candidates(task, req)
            .into_iter()
            .filter(|(_, adapter)| adapter.credentials_available())
            .collect()
    }
    pub fn availability(&self, task: TaskKind) -> AiAvailability {
        let Ok(breakers) = self.breakers.lock() else {
            return AiAvailability {
                available: false,
                reason: "unavailable",
            };
        };
        let available = self.candidates(task, None).iter().any(|(_, p)| {
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
    pub fn request_availability(&self, task: TaskKind, req: &TurnRequest) -> AiAvailability {
        if task != TaskKind::ChatFile {
            return self.availability(task);
        }
        let static_candidates = self.static_candidates(task, Some(req));
        if static_candidates.is_empty() {
            return AiAvailability {
                available: false,
                reason: "no_available_route",
            };
        }
        let Ok(breakers) = self.breakers.lock() else {
            return AiAvailability {
                available: false,
                reason: "unavailable",
            };
        };
        let available = static_candidates.iter().any(|(_, provider)| {
            provider.credentials_available()
                && breakers
                    .get(provider.id())
                    .is_none_or(|breaker| breaker.available(Instant::now(), &self.config.breaker))
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
        for (model, provider) in self.candidates(task, Some(req)) {
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
                || (image_count > 0 && (!model.vision || !provider.capabilities().vision))
            {
                continue;
            }
            let generation = {
                let mut breakers = self.breakers.lock().map_err(|_| ProviderError::Transport)?;
                let Some(generation) = breakers
                    .entry(provider.id().into())
                    .or_default()
                    .claim(Instant::now(), &self.config.breaker)
                else {
                    continue;
                };
                generation
            };
            let mut permit = ProbePermit {
                breakers: self.breakers.clone(),
                provider: provider.id().into(),
                generation,
                config: self.config.breaker.clone(),
                finished: false,
            };
            let mut output = OutputSink {
                inner: sink,
                visible: false,
            };
            let mut request = req.clone();
            request.snapshot.model = model.model.clone();
            let mut retried_blob = false;
            let mut retried_format = false;
            let deadline = tokio::time::Instant::now() + crate::breaker::CALL_TIMEOUT;
            let result = async {
                loop {
                    let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
                    if remaining.is_zero() {
                        break Err(ProviderError::Timeout);
                    }
                    let result = provider.run_turn_observed(
                        task, &request, &mut output, observer, remaining,
                    ).await;
                    if output.visible && result.is_err() {
                        break result;
                    }
                    if result == Err(ProviderError::BlobRejected)
                        && !retried_blob
                        && request.items.iter().any(|item| matches!(item, RequestItem::ProviderBlob(_)))
                    {
                        retried_blob = true;
                        request.items.retain(|item| !matches!(item, RequestItem::ProviderBlob(_)));
                        output.emit(TurnEvent::Note(
                            "Encrypted reasoning was unavailable; continuing from recorded results."
                                .into(),
                        )).await?;
                        request.items.push(RequestItem::Message {
                            role: "developer".into(),
                            text: "Continue using the recorded results; encrypted reasoning was unavailable.".into(),
                            images: vec![],
                            files: vec![],
                        });
                        continue;
                    }
                    // Stream corruption and unmapped upstream failures get one retry per route.
                    if matches!(
                        result,
                        Err(ProviderError::InvalidOutput
                            | ProviderError::Incomplete { .. }
                            | ProviderError::UpstreamFailed { .. })
                    ) && !retried_format
                    {
                        retried_format = true;
                        continue;
                    }
                    break result;
                }
            }
            .await;
            // A refused request says nothing about provider health, and resending it on
            // another route cannot help, so it neither trips the breaker nor falls back.
            permit.finish(result.is_ok() || matches!(result, Err(ProviderError::Rejected { .. })));
            let result = if output.visible {
                result.map_err(|error| ProviderError::PartialOutput {
                    source: Box::new(error),
                })
            } else {
                result
            };
            match result {
                Ok(()) => return Ok(()),
                Err(
                    e @ (ProviderError::Sink
                    | ProviderError::Meter
                    | ProviderError::Rejected { .. }
                    | ProviderError::PartialOutput { .. }),
                ) => {
                    return Err(e);
                }
                Err(e) => last = e,
            }
        }
        Err(last)
    }
}
