use crate::*;
use std::time::Duration;
#[derive(Clone, Copy)]
pub struct RunBudget {
    pub turns: u32,
    pub active: Duration,
    pub waiting_ai: Duration,
    pub model_call: Duration,
    pub model_idle: Duration,
    pub tool: Duration,
}
impl Default for RunBudget {
    fn default() -> Self {
        Self {
            turns: MAX_MODEL_TURNS,
            active: Duration::from_secs(MAX_ACTIVE_SECS),
            waiting_ai: Duration::from_secs(MAX_WAITING_AI_SECS),
            model_call: Duration::from_secs(MODEL_CALL_TIMEOUT_SECS),
            model_idle: Duration::from_secs(60),
            tool: Duration::from_secs(TOOL_TIMEOUT_SECS),
        }
    }
}
impl RunBudget {
    pub fn exhausted(&self, turns: u32, active: Duration, needs_model: bool) -> bool {
        active >= self.active || (needs_model && turns >= self.turns)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn budget_boundaries_and_twentieth_final_answer() {
        let b = RunBudget::default();
        assert!(!b.exhausted(19, Duration::from_secs(599), true));
        assert!(b.exhausted(20, Duration::ZERO, true));
        assert!(!b.exhausted(20, Duration::ZERO, false));
        assert!(b.exhausted(0, Duration::from_secs(600), false));
        assert_eq!(b.waiting_ai, Duration::from_secs(600));
        assert_eq!(b.model_call, Duration::from_secs(300));
        assert_eq!(b.model_idle, Duration::from_secs(60));
        assert_eq!(b.tool, Duration::from_secs(10));
    }
}
