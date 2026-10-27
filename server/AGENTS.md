# Jiabu Rust server — rules for coding agents

Use fake data only. Never print or commit secrets. Build and test only on the
x86_64 Linux build host; release CI also uses a native ARM runner.

- Run `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`,
  `cargo nextest run --workspace`, `cargo deny check`, `cargo audit`, and all three
  `tool/check-*.sh` scripts. Tests require `DATABASE_URL` and real PostgreSQL 18.
- Mutating requests require idempotency keys. Check identity, active membership,
  join epoch, and authorization before any idempotency replay.
- Access space data only through `SpaceTx`; never expose raw connection pools.
  Never name `SystemTx` in `crates/api`. Background code must use transaction-local
  settings. Session-scoped settings are forbidden, including set_config with false.
- Business queries must include space scope. Keep authorization in its one entry point.
- Space content writes go through `ToolRegistry::invoke`; add no record REST writes.
- No `unwrap` or `expect` on request paths. New handlers need utoipa annotations,
  response examples, and integration tests. Export and review both OpenAPI documents.
- Money is `i64` minor units (fen); timestamps use PostgreSQL `timestamptz`.
- Logs never contain tokens, passwords, user messages, or private content.
- Only `crates/chat` maps tool results into validated chat blocks. Never extract UI
  components from model text. Action handlers implement authorization and have
  tests for unauthorized requests.
- Keep domain free of IO. Keep admin/admin-api free of db, chat, agent, storage,
  and api dependencies. SQL migrations are the only schema source; append new
  migrations and never edit released ones. Entity generation starts in S1.
- ChatWeave Rust dependencies start after CW1, pinned to a reviewed commit.
