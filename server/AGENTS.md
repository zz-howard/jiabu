# Jiabu Rust server — rules for coding agents

Use fake data only. Never print or commit secrets. Build and test only on the
x86_64 Linux build host; release CI also uses a native ARM runner.

- Run `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`,
  `cargo nextest run --workspace`, `cargo deny check`, `cargo audit`, and all three
  `tool/check-*.sh` scripts. Tests require `DATABASE_URL` and real PostgreSQL 18.
- For evaluation, prompt, or tool-schema optimization, use a fast effect loop first:
  run only the isolated evaluation slice changed by the candidate and report its
  before/after result. Do not block that effect check on full-workspace gates,
  unrelated test matrices, or extra review rounds. When the isolated test passes
  and the effect meets the agreed target, promote the candidate into product code;
  run the normal full server gates afterward, before merge or deployment.
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

S1 clarifications (approved for this slice):
- Login creates a new session on retry and never caches its token. PATCH /me sets
  locale idempotently; POST /me/password validates the current password. These
  identity writes and logout do not require Idempotency-Key in S1. Space content
  idempotency is implemented in S3/S4.
- Mount public routes only through crates/api/src/route_catalog.rs. Every route
  with a space path parameter must be present in the isolation matrix.
- Run tool/check-entities.sh in addition to the original three check scripts.
  Never handwrite generated entities or fabricate lockfile checksums.
- Client log upload deliberately accepts client crash message/stack text; never
  log the upload Authorization header or a complete HTTP request body.
