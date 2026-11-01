//! Synthetic datasets evaluated through the production Agent loop.
#[path = "../../../tests/support/agent.rs"]
pub mod agent_fixture;
pub mod audit;
pub mod dataset;
pub mod fixture;
pub mod judge;
#[cfg(feature = "live")]
pub mod live;
pub mod mock;
pub mod report;
pub mod scoring;
#[path = "../../../tests/support/mod.rs"]
pub mod support;

pub fn dataset_root() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../eval")
}
