//! Closed diagnostic labels only. Never format an error or its source chain.
use anyhow::Error;
use jiabu_ai::ProviderError;

#[derive(Clone, Copy, Debug)]
pub enum Stage {
    Submit,
    Drive,
    Observe,
}
impl std::fmt::Display for Stage {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::Submit => "actor-submit",
            Self::Drive => "actor-drive",
            Self::Observe => "actor-observe",
        })
    }
}
impl std::error::Error for Stage {}

pub fn class(error: &Error) -> &'static str {
    if let Some(provider) = error.downcast_ref::<ProviderError>() {
        return provider.kind();
    }
    if error.is::<tokio::time::error::Elapsed>() {
        return "timeout";
    }
    if error.is::<sqlx::Error>() {
        return "database";
    }
    if error.is::<serde_json::Error>() {
        return "json-schema";
    }
    if error.is::<std::io::Error>() {
        return "io";
    }
    // Only exact literals already produced by the evaluator are accepted.
    match error.downcast_ref::<&'static str>().copied() {
        Some("judge response missing completion") => "judge-completion",
        Some("judge response missing usage") => "judge-usage",
        Some("judge emitted prose") => "judge-prose",
        Some("judge must call exactly once") => "judge-call-count",
        Some("judge called an unknown tool") => "judge-tool-name",
        Some("inconsistent judge verdict") => "judge-verdict",
        Some("inconsistent judge reason") => "judge-reason",
        _ => "unknown",
    }
}

pub fn stage(error: &Error, fallback: &'static str) -> String {
    error
        .downcast_ref::<Stage>()
        .map_or_else(|| fallback.to_owned(), ToString::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn diagnostic_labels_preserve_typed_errors_and_never_render_secret_payloads() {
        let provider = Error::new(ProviderError::Rejected {
            code: "private-code".into(),
            param: "private-param".into(),
            message: "SECRET_PAYLOAD".into(),
        })
        .context(Stage::Drive);
        assert_eq!(class(&provider), "request_rejected");
        assert_eq!(stage(&provider, "fallback"), "actor-drive");
        let arbitrary = anyhow::anyhow!("SECRET_PAYLOAD");
        assert_eq!(class(&arbitrary), "unknown");
        assert_eq!(stage(&arbitrary, "fixture-init"), "fixture-init");
        assert_eq!(
            class(&anyhow::anyhow!("judge emitted prose")),
            "judge-prose"
        );
        assert_eq!(class(&Error::new(sqlx::Error::PoolClosed)), "database");
        assert_eq!(
            class(&Error::new(
                serde_json::from_str::<serde_json::Value>("not-json").unwrap_err()
            )),
            "json-schema"
        );
    }
}
