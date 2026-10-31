use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

const MAX_HEADER_BYTES: usize = 8 * 1024;
const MAX_SECTIONS: usize = 3;
const MAX_PROTOCOLS: usize = 8;
const MAX_BLOCKS: usize = 64;
const MAX_FEATURES: usize = 32;
const MAX_TOKEN_BYTES: usize = 80;

const BUILTIN_BLOCKS: &[&str] = &[
    "markdown",
    "metric",
    "metric_group",
    "dataset",
    "time_series",
    "comparison",
    "breakdown",
    "category_series",
    "status",
    "choice",
    "confirmation",
    "form_intent",
];
const FEATURES: &[&str] = &[
    "stream.resume",
    "stream.snapshot",
    "stream.activity",
    "stream.steps",
    "action.choice",
    "action.confirmation",
    "action.form",
    "markdown.tables",
];

#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ClientCapabilities {
    pub protocol_versions: BTreeSet<String>,
    pub blocks: BTreeMap<String, u16>,
    pub features: BTreeSet<String>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct CapabilityError;

impl std::fmt::Display for CapabilityError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str("invalid ChatWeave capabilities")
    }
}

impl std::error::Error for CapabilityError {}

impl ClientCapabilities {
    /// Trusted in-process callers (evaluation and server tests) model the
    /// current Jiabu renderer. HTTP callers always supply a parsed declaration.
    pub fn current_jiabu() -> Self {
        let blocks = [
            "markdown",
            "metric",
            "metric_group",
            "dataset",
            "time_series",
            "comparison",
            "breakdown",
            "category_series",
            "status",
            "choice",
            "confirmation",
            "form_intent",
            "x-jiabu.record_card",
            "x-jiabu.document_card",
            "x-jiabu.account_card",
        ]
        .into_iter()
        .map(|block| (block.to_owned(), 1))
        .collect();
        Self {
            protocol_versions: ["0.1".to_owned()].into_iter().collect(),
            blocks,
            features: BTreeSet::new(),
        }
    }

    pub fn parse_header(raw: Option<&str>) -> Result<Self, CapabilityError> {
        let Some(raw) = raw else {
            return Ok(Self::default());
        };
        if raw.trim().is_empty() {
            return Ok(Self::default());
        }
        if raw.len() > MAX_HEADER_BYTES {
            return Err(CapabilityError);
        }
        let sections: Vec<_> = raw.split(';').map(str::trim).collect();
        if sections.len() > MAX_SECTIONS || sections.iter().any(|section| section.is_empty()) {
            return Err(CapabilityError);
        }
        let mut result = Self::default();
        let mut seen = BTreeSet::new();
        for section in sections {
            let (name, value) = section.split_once('=').ok_or(CapabilityError)?;
            let name = name.trim();
            let value = value.trim();
            if !seen.insert(name) {
                return Err(CapabilityError);
            }
            match name {
                "v" => {
                    result.protocol_versions = parse_list(value, MAX_PROTOCOLS, valid_protocol)?;
                    if result.protocol_versions.is_empty() {
                        return Err(CapabilityError);
                    }
                }
                "blocks" => {
                    if value.is_empty() {
                        continue;
                    }
                    for entry in bounded_parts(value, MAX_BLOCKS)? {
                        let (block, version) = entry.split_once(':').ok_or(CapabilityError)?;
                        if !valid_block(block) || !valid_token(block) {
                            return Err(CapabilityError);
                        }
                        let version = version.parse::<u16>().map_err(|_| CapabilityError)?;
                        if !(1..=999).contains(&version)
                            || result.blocks.insert(block.to_owned(), version).is_some()
                        {
                            return Err(CapabilityError);
                        }
                    }
                }
                "features" => {
                    result.features =
                        parse_list(value, MAX_FEATURES, |feature| FEATURES.contains(&feature))?;
                }
                _ => return Err(CapabilityError),
            }
        }
        if !seen.contains("v") {
            return Err(CapabilityError);
        }
        Ok(result)
    }

    pub fn negotiates_v01(&self) -> bool {
        self.protocol_versions.contains("0.1")
    }

    pub fn supports(&self, block: &str, schema_version: u16) -> bool {
        self.negotiates_v01()
            && self
                .blocks
                .get(block)
                .is_some_and(|supported| *supported >= schema_version)
    }

    pub fn feature(&self, feature: &str) -> bool {
        self.negotiates_v01() && self.features.contains(feature)
    }
}

fn bounded_parts(value: &str, maximum: usize) -> Result<Vec<&str>, CapabilityError> {
    if value.is_empty() {
        return Ok(Vec::new());
    }
    let parts: Vec<_> = value.split(',').map(str::trim).collect();
    if parts.len() > maximum || parts.iter().any(|part| part.is_empty()) {
        return Err(CapabilityError);
    }
    Ok(parts)
}

fn parse_list(
    value: &str,
    maximum: usize,
    valid: impl Fn(&str) -> bool,
) -> Result<BTreeSet<String>, CapabilityError> {
    let mut result = BTreeSet::new();
    for entry in bounded_parts(value, maximum)? {
        if !valid_token(entry) || !valid(entry) || !result.insert(entry.to_owned()) {
            return Err(CapabilityError);
        }
    }
    Ok(result)
}

fn valid_token(value: &str) -> bool {
    !value.is_empty() && value.len() <= MAX_TOKEN_BYTES && value.is_ascii()
}

fn valid_protocol(value: &str) -> bool {
    let Some((major, minor)) = value.split_once('.') else {
        return false;
    };
    !major.is_empty()
        && !minor.is_empty()
        && major.bytes().all(|byte| byte.is_ascii_digit())
        && minor.bytes().all(|byte| byte.is_ascii_digit())
}

fn valid_block(value: &str) -> bool {
    BUILTIN_BLOCKS.contains(&value) || valid_custom_block(value)
}

fn valid_custom_block(value: &str) -> bool {
    let Some((host, name)) = value
        .strip_prefix("x-")
        .and_then(|value| value.split_once('.'))
    else {
        return false;
    };
    let host_parts: Vec<_> = host.split('-').collect();
    !host_parts.is_empty()
        && host_parts.iter().all(|part| {
            !part.is_empty()
                && part
                    .bytes()
                    .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit())
        })
        && name.len() <= 64
        && name.as_bytes().first().is_some_and(u8::is_ascii_lowercase)
        && name
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'_')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_canonical_capabilities_and_max_versions() {
        let parsed = ClientCapabilities::parse_header(Some(
            "v=0.1; blocks=x-future.card:7,metric:2; features=stream.snapshot,stream.activity",
        ))
        .unwrap_or_else(|_| panic!("valid capabilities"));
        assert!(parsed.supports("metric", 1));
        assert!(parsed.supports("metric", 2));
        assert!(!parsed.supports("metric", 3));
        assert!(parsed.supports("x-future.card", 1));
        assert!(parsed.feature("stream.snapshot"));
        assert_eq!(
            serde_json::to_value(parsed).ok(),
            Some(serde_json::json!({
                "protocolVersions":["0.1"],
                "blocks":{"metric":2,"x-future.card":7},
                "features":["stream.activity","stream.snapshot"]
            }))
        );
    }

    #[test]
    fn absent_empty_and_other_protocol_are_text_only() {
        let absent = ClientCapabilities::parse_header(None)
            .unwrap_or_else(|_| panic!("absent capabilities"));
        assert!(!absent.supports("metric", 1));
        let blank = ClientCapabilities::parse_header(Some(" \t "))
            .unwrap_or_else(|_| panic!("blank capabilities"));
        assert_eq!(blank, ClientCapabilities::default());
        let empty = ClientCapabilities::parse_header(Some("v=0.1; blocks=; features="))
            .unwrap_or_else(|_| panic!("empty capabilities"));
        assert!(!empty.supports("metric", 1));
        let other = ClientCapabilities::parse_header(Some(
            "v=0.2; blocks=metric:9; features=stream.snapshot",
        ))
        .unwrap_or_else(|_| panic!("future capabilities"));
        assert!(!other.supports("metric", 1));
        assert!(!other.feature("stream.snapshot"));
    }

    #[test]
    fn rejects_duplicates_invalid_names_features_and_bounds() {
        for raw in [
            "blocks=metric:1",
            "v=",
            "v=0.1; v=0.1",
            "v=0.1,0.1",
            "v=0.1; blocks=metric:1,metric:2",
            "v=0.1; blocks=unknown:1",
            "v=0.1; blocks=x-Bad.card:1",
            "v=0.1; blocks=metric:0",
            "v=0.1; blocks=metric:1000",
            "v=0.1; blocks=metric:65536",
            "v=0.1; features=stream.snapshot,stream.snapshot",
            "v=0.1; features=future.unknown",
            "v=0.1; extra=value",
        ] {
            assert!(
                ClientCapabilities::parse_header(Some(raw)).is_err(),
                "{raw}"
            );
        }
        let oversized = format!("v=0.1; blocks={}", "x".repeat(MAX_HEADER_BYTES));
        assert!(ClientCapabilities::parse_header(Some(&oversized)).is_err());

        let protocols = (0..=MAX_PROTOCOLS)
            .map(|minor| format!("0.{minor}"))
            .collect::<Vec<_>>()
            .join(",");
        assert!(ClientCapabilities::parse_header(Some(&format!("v={protocols}"))).is_err());

        let blocks = (0..=MAX_BLOCKS)
            .map(|index| format!("x-test.block_{index}:1"))
            .collect::<Vec<_>>()
            .join(",");
        assert!(
            ClientCapabilities::parse_header(Some(&format!("v=0.1; blocks={blocks}"))).is_err()
        );

        let features = std::iter::repeat_n("stream.resume", MAX_FEATURES + 1)
            .collect::<Vec<_>>()
            .join(",");
        assert!(bounded_parts(&features, MAX_FEATURES).is_err());

        let overlong_token = format!("0.{}", "1".repeat(MAX_TOKEN_BYTES));
        assert!(ClientCapabilities::parse_header(Some(&format!("v={overlong_token}"))).is_err());
        assert!(
            ClientCapabilities::parse_header(Some("v=0.1; blocks=; features=; extra=value"))
                .is_err()
        );
    }
}
