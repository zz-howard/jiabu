//! Provider-neutral AI runtime. No database or chat dependency.
pub mod billing;
pub mod breaker;
pub mod credentials;
pub mod mock;
pub mod provider;
pub mod router;
pub mod siwc;
pub mod types;
pub use jiabu_domain::ai::*;
pub use provider::*;
pub use router::{AiAvailability, AiRouter, RouterStore};
pub use types::*;
