//! Management validation. No dependency on AI runtime/public DB/chat/agent.
use anyhow::{Result, ensure};
pub use jiabu_db_admin::ai_configuration::{ConfigWrite, PolicyInput, PriceInput};
use jiabu_db_admin::users::AdminDb;
use jiabu_domain::ai::EncryptedSecret;
pub async fn write(db: &AdminDb, write: ConfigWrite, actor: &str) -> Result<()> {
    match &write {
        ConfigWrite::Provider { config: p, .. } => {
            ensure!(
                identifier(&p.id) && identifier(&p.kind),
                "invalid provider identifier"
            );
            if p.kind == "siwc" {
                ensure!(
                    p.base_url
                        .as_deref()
                        .is_none_or(|u| u == "https://api.openai.com/v1"),
                    "SIWC must use the official endpoint"
                );
            }
            ensure!(
                p.secret_source.as_deref().is_none_or(|s| s == "db"
                    || s.strip_prefix("file:").is_some_and(|v| !v.is_empty())
                    || s.strip_prefix("env:").is_some_and(|v| !v.is_empty()
                        && v.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_'))),
                "invalid secret source"
            );
        }
        ConfigWrite::Model { config: m, .. } => {
            ensure!(
                identifier(&m.provider_id) && !m.model.trim().is_empty() && m.model.len() <= 200,
                "invalid model"
            );
            ensure!(
                m.context_tokens
                    .is_none_or(|n| n > 0 && n <= i32::MAX as u32),
                "invalid context budget"
            );
        }
        ConfigWrite::Route { models, .. } => {
            ensure!(models.len() <= i16::MAX as usize, "route too long");
            let unique: std::collections::BTreeSet<_> = models.iter().collect();
            ensure!(unique.len() == models.len(), "duplicate route model");
        }
        ConfigWrite::Price(p) => {
            ensure!(
                identifier(&p.provider_kind)
                    && !p.model.is_empty()
                    && p.currency == "USD"
                    && p.source.starts_with("https://"),
                "invalid price metadata"
            );
            ensure!(
                decimal(&p.input)
                    && decimal(&p.output)
                    && p.cached_input.as_deref().is_none_or(decimal),
                "prices must be nonnegative decimal strings with at most 6 fractional digits"
            );
            if let Some(cache) = &p.cache_write {
                let obj = cache
                    .as_object()
                    .ok_or_else(|| anyhow::anyhow!("invalid cache tariff"))?;
                for (key, value) in obj {
                    ensure!(
                        !key.is_empty() && value.as_str().is_some_and(decimal),
                        "cache tariffs use decimal strings"
                    );
                }
            }
            if let Some(long) = &p.long_context {
                let obj = long
                    .as_object()
                    .ok_or_else(|| anyhow::anyhow!("invalid long-context tariff"))?;
                ensure!(
                    obj.get("above_tokens")
                        .and_then(|v| v.as_u64())
                        .is_some_and(|n| n > 0 && n <= i32::MAX as u64),
                    "invalid long-context threshold"
                );
                for key in ["input", "cached_input", "output"] {
                    ensure!(
                        obj.get(key).and_then(|v| v.as_str()).is_some_and(decimal),
                        "long-context rates use decimal strings"
                    );
                }
            }
        }
        ConfigWrite::Policy(p) => ensure!(
            p.breaker.failures > 0
                && p.breaker.cool_down_secs > 0
                && p.retry_initial_secs > 0
                && p.retry_max_secs >= p.retry_initial_secs
                && p.waiting_timeout_secs > 0
                && p.waiting_timeout_secs <= 600,
            "invalid AI policy"
        ),
        _ => {}
    }
    db.ai_write(write, actor).await
}
fn identifier(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 100
        && s.bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_'))
}
fn decimal(s: &str) -> bool {
    let mut parts = s.split('.');
    let integer = parts.next().unwrap_or("");
    !integer.is_empty()
        && integer.len() <= 6
        && integer.bytes().all(|b| b.is_ascii_digit())
        && parts
            .next()
            .is_none_or(|f| !f.is_empty() && f.len() <= 6 && f.bytes().all(|b| b.is_ascii_digit()))
        && parts.next().is_none()
}
pub async fn set_secret(
    db: &AdminDb,
    provider: &str,
    field: &str,
    secret: Option<&EncryptedSecret>,
    actor: &str,
) -> Result<()> {
    ensure!(
        identifier(provider) && matches!(field, "oauth" | "api_key"),
        "invalid secret owner"
    );
    db.ai_set_secret(provider, field, secret, actor).await
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn decimal_prices_never_use_floats() {
        for s in ["0", "1.25", "999999.999999"] {
            assert!(decimal(s));
        }
        for s in ["-1", "NaN", "1e3", "1.0000001", ".1", "1.", "1.2.3"] {
            assert!(!decimal(s));
        }
    }
}
