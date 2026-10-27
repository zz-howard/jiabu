//! Space-scoped persistence boundary. Database implementation follows in S1.

/// Placeholder for an authorized, space-scoped transaction.
///
/// S1 will set transaction-local space scope and keep the connection private.
pub struct SpaceTx;

/// Placeholder for a background-only transaction used by workers and cleanup.
///
/// Public API code must never name this type. Settings must be transaction-local.
pub struct SystemTx;
