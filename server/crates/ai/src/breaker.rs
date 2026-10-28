use jiabu_domain::ai::BreakerConfig;
use std::time::{Duration, Instant};
/// Matches the router's total provider-call deadline, including local retries.
pub const CALL_TIMEOUT: Duration = Duration::from_secs(300);
#[derive(Default)]
pub struct Breaker {
    failures: u32,
    opened: Option<Instant>,
    probing: Option<(u64, Instant)>,
    generation: u64,
    retired_probe: u64,
}
impl Breaker {
    pub fn available(&self, now: Instant, config: &BreakerConfig) -> bool {
        if let Some((_, deadline)) = self.probing {
            // An abandoned/overdue probe counts as failed at its deadline.
            return now >= deadline + Duration::from_secs(config.cool_down_secs);
        }
        self.opened
            .is_none_or(|t| now.saturating_duration_since(t).as_secs() >= config.cool_down_secs)
    }
    pub fn claim(&mut self, now: Instant, config: &BreakerConfig) -> Option<u64> {
        if !self.available(now, config) {
            return None;
        }
        if let Some((generation, _)) = self.probing {
            self.retired_probe = generation;
        }
        self.generation = self.generation.checked_add(1)?;
        if self.opened.is_some() {
            self.probing = Some((self.generation, now + CALL_TIMEOUT));
        }
        Some(self.generation)
    }
    pub fn finish(&mut self, generation: u64, success: bool, now: Instant, config: &BreakerConfig) {
        // An expired permit must never finish a replacement probe.
        if self
            .probing
            .is_some_and(|(current, _)| current != generation)
        {
            return;
        }
        if generation <= self.retired_probe {
            return;
        }
        if self.probing.is_some() {
            self.retired_probe = generation;
        }
        if success {
            self.failures = 0;
            self.opened = None;
        } else {
            self.failures = self.failures.saturating_add(1);
            if self.probing.is_some() || self.failures >= config.failures {
                self.opened = Some(now);
            }
        }
        self.probing = None;
    }
}
