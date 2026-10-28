use jiabu_domain::ai::BreakerConfig;
use std::time::Instant;
#[derive(Default)]
pub struct Breaker {
    failures: u32,
    opened: Option<Instant>,
    probing: bool,
}
impl Breaker {
    pub fn available(&self, now: Instant, config: &BreakerConfig) -> bool {
        !self.probing
            && self
                .opened
                .is_none_or(|t| now.duration_since(t).as_secs() >= config.cool_down_secs)
    }
    pub fn claim(&mut self, now: Instant, config: &BreakerConfig) -> bool {
        if !self.available(now, config) {
            return false;
        }
        if self.opened.is_some() {
            self.probing = true;
        }
        true
    }
    pub fn finish(&mut self, success: bool, now: Instant, config: &BreakerConfig) {
        if success {
            *self = Self::default();
        } else {
            self.failures = self.failures.saturating_add(1);
            if self.probing || self.failures >= config.failures {
                self.opened = Some(now);
            }
            self.probing = false;
        }
    }
}
