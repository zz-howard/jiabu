//! Synthetic datasets evaluated through the production Agent loop.
pub mod audit;
pub mod dataset;
pub mod fixture;
pub mod mock;
pub mod report;
pub mod scoring;
#[cfg(feature = "live")]
pub mod live;
#[path = "../../../tests/support/mod.rs"]
pub mod support;
#[path = "../../../tests/support/agent.rs"]
pub mod agent_fixture;

pub fn dataset_root() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../eval")
}
