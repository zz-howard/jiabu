//! Process-local rate budgets. No credential validity or source IP is persisted.
use crate::ToolError;
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};
use uuid::Uuid;

pub trait RateClock: Send + Sync {
    fn now(&self) -> Duration;
}
struct MonotonicClock(Instant);
impl RateClock for MonotonicClock {
    fn now(&self) -> Duration {
        self.0.elapsed()
    }
}
#[derive(Clone, Copy, serde::Deserialize)]
#[serde(default)]
pub struct ApiKeyLimits {
    pub read_per_minute: u32,
    pub write_per_minute: u32,
    pub unknown_per_minute: u32,
}
impl Default for ApiKeyLimits {
    fn default() -> Self {
        Self {
            read_per_minute: 60,
            write_per_minute: 20,
            unknown_per_minute: 60,
        }
    }
}
struct Bucket {
    tokens: f64,
    at: Duration,
}
pub struct ApiKeyLimiter {
    limits: ApiKeyLimits,
    clock: Arc<dyn RateClock>,
    buckets: Mutex<HashMap<String, Bucket>>,
}
impl Default for ApiKeyLimiter {
    fn default() -> Self {
        Self::new(
            ApiKeyLimits::default(),
            Arc::new(MonotonicClock(Instant::now())),
        )
    }
}
impl ApiKeyLimiter {
    pub fn configured(limits: ApiKeyLimits) -> Self {
        Self::new(limits, Arc::new(MonotonicClock(Instant::now())))
    }
    pub fn new(limits: ApiKeyLimits, clock: Arc<dyn RateClock>) -> Self {
        Self {
            limits,
            clock,
            buckets: Mutex::default(),
        }
    }
    pub fn check(&self, key: Uuid, writing: bool) -> Result<(), ToolError> {
        let limit = if writing {
            self.limits.write_per_minute
        } else {
            self.limits.read_per_minute
        };
        self.hit(format!("key:{key}:{writing}"), limit)
    }
    pub fn unknown(&self, source: &str) -> Result<(), ToolError> {
        self.hit(format!("unknown:{source}"), self.limits.unknown_per_minute)
    }
    fn hit(&self, key: String, limit: u32) -> Result<(), ToolError> {
        if limit == 0 {
            return Err(ToolError::new(503, "unavailable"));
        }
        let now = self.clock.now();
        let mut buckets = self.buckets.lock().map_err(|_| ToolError::internal())?;
        // Full idle buckets can be reconstructed, including failed-guess sources.
        buckets.retain(|_, bucket| now.saturating_sub(bucket.at) < Duration::from_secs(60));
        let capacity = f64::from(limit);
        let bucket = buckets.entry(key).or_insert(Bucket {
            tokens: capacity,
            at: now,
        });
        bucket.tokens = (bucket.tokens
            + now.saturating_sub(bucket.at).as_secs_f64() * capacity / 60.0)
            .min(capacity);
        bucket.at = now;
        if bucket.tokens < 1.0 {
            let mut error = ToolError::new(429, "rate_limited");
            error.retry_after =
                Some(((1.0 - bucket.tokens) * 60.0 / capacity).ceil().max(1.0) as u64);
            return Err(error);
        }
        bucket.tokens -= 1.0;
        Ok(())
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};
    struct Clock(AtomicU64);
    impl RateClock for Clock {
        fn now(&self) -> Duration {
            Duration::from_millis(self.0.load(Ordering::Relaxed))
        }
    }
    #[test]
    fn independent_budgets_refill_and_retry_after() {
        let clock = Arc::new(Clock(AtomicU64::new(0)));
        let limiter = ApiKeyLimiter::new(ApiKeyLimits::default(), clock.clone());
        let key = Uuid::now_v7();
        for _ in 0..60 {
            assert!(limiter.check(key, false).is_ok());
        }
        assert_eq!(limiter.check(key, false).unwrap_err().retry_after, Some(1));
        for _ in 0..20 {
            assert!(limiter.check(key, true).is_ok());
        }
        assert_eq!(limiter.check(key, true).unwrap_err().retry_after, Some(3));
        assert!(limiter.check(Uuid::now_v7(), true).is_ok());
        for _ in 0..60 {
            assert!(limiter.unknown("example-source").is_ok());
        }
        assert_eq!(limiter.unknown("example-source").unwrap_err().status, 429);
        clock.0.store(3000, Ordering::Relaxed);
        assert!(limiter.check(key, true).is_ok());
        assert!(limiter.check(key, false).is_ok());
        assert!(limiter.unknown("example-source").is_ok());
        clock.0.store(63_000, Ordering::Relaxed);
        for _ in 0..60 {
            assert!(limiter.check(key, false).is_ok());
        }
    }
}
