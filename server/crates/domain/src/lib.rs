//! IO-free domain types and fixed catalogs.
pub mod ids;
pub mod money;
pub mod presets;
pub mod space_init;
pub mod spaces;
pub use ids::*;
pub use money::{Currency, Money};

#[derive(Debug, thiserror::Error)]
#[error("not_found")]
pub struct NotFound;
