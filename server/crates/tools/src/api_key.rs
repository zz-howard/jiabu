//! Process-local rate budgets. No credential validity or source IP is persisted.
use crate::ToolError;
use std::{
    collections::{HashMap, VecDeque},
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
// One queue entry per bucket. Cleanup work has a fixed per-call ceiling.
const CLEANUP_EVERY: usize = 64;
const CLEANUP_BATCH: usize = 64;
#[derive(Default)]
struct BucketStore {
    entries: HashMap<String, Bucket>,
    cleanup: VecDeque<String>,
    hits: usize,
}
impl BucketStore {
    fn maintain(&mut self, now: Duration) {
        self.hits = (self.hits + 1) % CLEANUP_EVERY;
        if self.hits != 0 {
            return;
        }
        let count = self.cleanup.len().min(CLEANUP_BATCH);
        for _ in 0..count {
            let Some(key) = self.cleanup.pop_front() else {
                break;
            };
            if self
                .entries
                .get(&key)
                .is_some_and(|bucket| now.saturating_sub(bucket.at) >= Duration::from_secs(60))
            {
                self.entries.remove(&key);
            } else if self.entries.contains_key(&key) {
                self.cleanup.push_back(key);
            }
        }
    }
}
pub struct ApiKeyLimiter {
    limits: ApiKeyLimits,
    clock: Arc<dyn RateClock>,
    buckets: Mutex<BucketStore>,
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
    /// Check an already exhausted guessing source before any identity SQL. Only
    /// failed lookups debit this bucket; inspecting it does not debit valid keys.
    pub fn check_unknown(&self, source: &str) -> Result<(), ToolError> {
        let limit = self.limits.unknown_per_minute;
        if limit == 0 {
            return Err(ToolError::new(503, "unavailable"));
        }
        let now = self.clock.now();
        let buckets = self.buckets.lock().map_err(|_| ToolError::internal())?;
        if let Some(bucket) = buckets.entries.get(&format!("unknown:{source}")) {
            let tokens = Self::refilled(bucket, now, limit);
            if tokens < 1.0 {
                return Err(Self::limited(tokens, limit));
            }
        }
        Ok(())
    }
    fn refilled(bucket: &Bucket, now: Duration, limit: u32) -> f64 {
        let capacity = f64::from(limit);
        (bucket.tokens + now.saturating_sub(bucket.at).as_secs_f64() * capacity / 60.0)
            .min(capacity)
    }
    fn limited(tokens: f64, limit: u32) -> ToolError {
        let mut error = ToolError::new(429, "rate_limited");
        error.retry_after = Some(((1.0 - tokens) * 60.0 / f64::from(limit)).ceil().max(1.0) as u64);
        error
    }
    fn hit(&self, key: String, limit: u32) -> Result<(), ToolError> {
        if limit == 0 {
            return Err(ToolError::new(503, "unavailable"));
        }
        let now = self.clock.now();
        let mut buckets = self.buckets.lock().map_err(|_| ToolError::internal())?;
        buckets.maintain(now);
        // Accessing an idle bucket refills it lazily; unrelated buckets are not scanned.
        if !buckets.entries.contains_key(&key) {
            buckets.cleanup.push_back(key.clone());
        }
        let bucket = buckets.entries.entry(key).or_insert(Bucket {
            tokens: f64::from(limit),
            at: now,
        });
        bucket.tokens = Self::refilled(bucket, now, limit);
        bucket.at = now;
        if bucket.tokens < 1.0 {
            return Err(Self::limited(bucket.tokens, limit));
        }
        bucket.tokens -= 1.0;
        Ok(())
    }
}

/// Admission for one authenticated HTTP request, shared by extraction and batch
/// dispatch. The first batch item uses the request's debit; further items debit
/// once each. Even an empty/invalid batch costs the initial request token.
pub struct KeyRequestBudget {
    limiter: Arc<ApiKeyLimiter>,
    key: Uuid,
    writing: bool,
    first_item: bool,
}
impl KeyRequestBudget {
    pub fn admit(limiter: Arc<ApiKeyLimiter>, key: Uuid, writing: bool) -> Result<Self, ToolError> {
        limiter.check(key, writing)?;
        Ok(Self {
            limiter,
            key,
            writing,
            first_item: true,
        })
    }
    pub fn admit_item(&mut self, key: Uuid) -> Result<(), ToolError> {
        if self.key != key {
            return Err(ToolError::internal());
        }
        if self.first_item {
            self.first_item = false;
            return Ok(());
        }
        self.limiter.check(self.key, self.writing)
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

    #[test]
    fn unknown_preflight_does_not_debit_and_blocks_until_refill() {
        let clock = Arc::new(Clock(AtomicU64::new(0)));
        let limiter = ApiKeyLimiter::new(
            ApiKeyLimits {
                unknown_per_minute: 2,
                ..Default::default()
            },
            clock.clone(),
        );
        for _ in 0..128 {
            assert!(limiter.check_unknown("source").is_ok());
        }
        assert!(limiter.unknown("source").is_ok());
        assert!(limiter.check_unknown("source").is_ok());
        assert!(limiter.unknown("source").is_ok());
        assert_eq!(
            limiter.check_unknown("source").unwrap_err().retry_after,
            Some(30)
        );
        clock.0.store(30_000, Ordering::Relaxed);
        assert!(limiter.check_unknown("source").is_ok());
        assert!(limiter.unknown("source").is_ok());
        assert_eq!(limiter.check_unknown("source").unwrap_err().status, 429);
    }

    #[test]
    fn batch_budget_counts_items_without_an_extra_request_debit() {
        let limiter = Arc::new(ApiKeyLimiter::new(
            ApiKeyLimits {
                write_per_minute: 3,
                ..Default::default()
            },
            Arc::new(Clock(AtomicU64::new(0))),
        ));
        let key = Uuid::now_v7();
        let mut budget = KeyRequestBudget::admit(limiter.clone(), key, true).unwrap();
        for _ in 0..3 {
            assert!(budget.admit_item(key).is_ok());
        }
        assert_eq!(budget.admit_item(key).unwrap_err().status, 429);
        assert_eq!(
            KeyRequestBudget::admit(limiter, key, true)
                .err()
                .unwrap()
                .status,
            429
        );
    }

    #[test]
    fn cleanup_is_bounded_and_idle_buckets_refill_lazily() {
        let clock = Arc::new(Clock(AtomicU64::new(0)));
        let limiter = ApiKeyLimiter::new(
            ApiKeyLimits {
                unknown_per_minute: 1,
                ..Default::default()
            },
            clock.clone(),
        );
        for index in 0..4096 {
            assert!(limiter.unknown(&format!("source-{index}")).is_ok());
        }
        assert_eq!(limiter.unknown("source-0").unwrap_err().status, 429);
        clock.0.store(61_000, Ordering::Relaxed);
        assert!(limiter.unknown("source-0").is_ok());
        // A single access cannot remove the whole stale map. Replacing this with
        // retain over every bucket makes this assertion fail.
        assert!(limiter.buckets.lock().unwrap().entries.len() >= 4096 - CLEANUP_BATCH);
        assert_eq!(limiter.unknown("source-0").unwrap_err().status, 429);
        for _ in 0..(4096 + CLEANUP_EVERY) {
            let _ = limiter.unknown("live-source");
        }
        let buckets = limiter.buckets.lock().unwrap();
        assert!(buckets.entries.len() <= 2);
        assert_eq!(buckets.cleanup.len(), buckets.entries.len());
    }
}
