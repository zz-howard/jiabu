# Dev Plan: Negotiate Client Block Capabilities (#55)

## Summary

Freeze the client's ChatWeave capability declaration when a message or explicit
retry enters the durable outbox, persist the canonical declaration on the new
agent run before it becomes claimable, and gate every mapped structured block
against that snapshot. Unsupported blocks downgrade without another model turn
to an older supported representation or bounded server-owned Markdown.

The tool registry, tool schemas, prompt instructions, and prompt snapshot remain
identical for every capability set. This slice changes transport and server
presentation only; it has no visual design or deployment work.

## Scope

### In scope

- One bounded capability parser and canonical representation shared by POST and
  stream endpoints.
- A durable client outbox snapshot for new messages and explicit retries.
- Atomic persistence in `agent_runs.client_capabilities` before run notification.
- Conservative, version-aware capability gating for every block returned by
  `jiabu_chat::map_tool_result`.
- Structural downgrade for breakdowns, category series, and account cards;
  Markdown fallback for every other unsupported mapped block.
- Correct validation-failure fallback in both read and local-write execution.
- OpenAPI, transport, database, runtime, mapping, replay, and prompt-stability
  tests.

### Out of scope

- S6 live SIWC evaluation and prompt-quality scoring.
- New renderers, visual states, golden changes, or a ChatWeave protocol upgrade.
- Capability-dependent tool registration, prompts, or model retries.
- Historical-run backfill, deployment, or release-window selection.

## Development Checklist

### 1. Define and parse capabilities once

- [ ] Add a typed canonical capability value in the chat boundary with sorted
  protocol versions, block-version map, and feature set.
- [ ] Parse `v`, `blocks`, and `features` with explicit raw-length, section,
  entry, token-length, and integer bounds before constructing collections.
- [ ] Reject malformed syntax, duplicate sections, duplicate block names,
  duplicate features/protocol versions, conflicting values, unknown 0.1
  feature tokens, zero versions, and integer overflow, matching the pinned
  ChatWeave 0.1 capability schema.
- [ ] Accept bounded syntactically valid host-defined `x-*` block names even
  when Jiabu does not register them; reject unknown bare built-in names per the
  pinned ChatWeave capability schema. Interpret a declared version as the
  highest compatible schema version.
- [ ] Treat absent/empty declarations and valid non-0.1 protocol declarations
  as text-only for blocks and as having no negotiated stream features. Keep
  malformed declarations as HTTP 400.
- [ ] Make stream resume derive only stream features from the shared parser and
  never write capabilities to a run.

### 2. Freeze the client declaration in the outbox

- [ ] At `chat_send` enqueue time, serialize the registry-derived canonical
  header into a reserved outbox-envelope field alongside the request payload.
- [ ] At `chat_retry` enqueue time, snapshot the current conversation's
  capability declaration independently; do not inherit from the old run.
- [ ] Preserve that envelope field through database reload, leasing, retry,
  process restart, and upload after a registry/app upgrade.
- [ ] In `OutboxProcessor`, strip the reserved field from the JSON body and pass
  it as the `ChatWeave-Capabilities` header on message/retry POSTs.
- [ ] Keep actions/stops unchanged because they continue an already-frozen run.

### 3. Persist capabilities atomically with runs

- [ ] Parse the POST header only after identity/membership/join-epoch and
  idempotency prerequisites are established, without leaking cross-space state.
- [ ] Carry the canonical value through `StartMessage`/retry input without
  placing it in message metadata or model input.
- [ ] Extend `enqueue_run` so `client_capabilities` is inserted in the same SQL
  statement as the run and before `pg_notify`.
- [ ] Make response-lost/idempotent replay return the original message/run
  without changing its snapshot.
- [ ] Make explicit retry create or replay exactly one child with the retry
  request's own snapshot; an absent header is an empty/text-only snapshot.
- [ ] Pass the retry `Idempotency-Key` into `ScopedRuns::retry` and persist it as
  `agent_runs.origin_request_id` in the same statement that creates the child
  and capability snapshot. The same key replays that child without mutation;
  a different key after a child exists returns stable 409
  `retry_already_accepted` instead of adopting another device's child.
- [ ] Expose the snapshot on `RunRow` only to presentation mapping; never add it
  to the prompt snapshot.

### 4. Gate every mapped block and downgrade deterministically

- [ ] Separate tool-result normalization from capability selection so one
  validated server-owned result can produce a preferred block, structural
  downgrade, or Markdown fallback without reading model text/tool arguments.
- [ ] Emit a block only when the frozen map declares a version greater than or
  equal to the emitted schema version.
- [ ] Downgrade unsupported `breakdown` to version-1 `metric_group` when
  supported and within 12 metrics; otherwise use existing bounded Markdown.
- [ ] Downgrade unsupported `category_series` to a version-1 `dataset` with
  server-owned labels/values/format when supported; otherwise use Markdown.
- [ ] Downgrade unsupported `x-jiabu.account_card` to one version-1 balance
  `metric` when supported; keep the structured account card reference-only.
- [ ] For unsupported metric, metric-group, time-series, dataset, record-card,
  document-card, and any other mapped kind, emit its bounded Markdown fallback.
- [ ] Validate the selected block before persistence. Unsupported downgrade is
  not an error; unexpected validation failure records server telemetry and
  emits Markdown.
- [ ] Make both read and local-write paths handle `stage.component == false`
  by emitting Markdown, never silently dropping the result.
- [ ] Preserve parallel read-call order, display telemetry, journal order, and
  checkpoint behavior.

### 5. Preserve prompt-cache stability and public contracts

- [ ] Add capability headers to new-message/retry OpenAPI annotations and
  regenerate the committed OpenAPI snapshot.
- [ ] Prove agent tool names, ordering, descriptions, parameter schemas,
  instructions, and serialized prompt snapshots are byte-identical across
  empty/partial/full capability sets and explicit retry.
- [ ] Keep capabilities out of prompts, tool arguments, logs, model history,
  message metadata, and fallback telemetry values.

## Test Checklist

### Parser and API

- [ ] Canonical order, whitespace/order variants, unknown valid `x-*` names,
  invalid bare built-in names, empty maps, unsupported protocol versions, and
  max-version compatibility (`2` accepts emitted schema `1`).
- [ ] Duplicate sections/entries/features/protocol versions, conflicting
  values, unknown 0.1 features, malformed names/versions, zero/overflow
  versions, oversize headers, and every configured count bound.
- [ ] Stream feature negotiation uses the same parser while a mismatched stream
  block map cannot mutate the stored run.
- [ ] A valid non-0.1 header negotiates neither structured blocks nor stream
  snapshot/activity features.

### Client durability and transport

- [ ] New-message and retry outbox rows contain the enqueue-time snapshot.
- [ ] Restart/offline upload, response loss, and app/registry upgrade between
  enqueue and upload preserve that exact snapshot.
- [ ] POST headers contain the snapshot and POST JSON never contains the
  reserved envelope field.
- [ ] Old locally stored operations without the field upload without a header
  and therefore negotiate text-only.

### Database, replay, and isolation

- [ ] New runs store the canonical object before claim; absent headers store an
  explicit empty/text-only value rather than `all supported`.
- [ ] Same-request replay does not mutate the snapshot.
- [ ] Explicit retry and response-lost retry-child replay are stable; a retry
  without a header never inherits the original run.
- [ ] Concurrent retries from two devices are first-writer-wins: the winning
  key's snapshot is frozen, its same-key replay succeeds, and the losing
  different key receives 409 without reading or reusing the child snapshot.
- [ ] Cross-member, cross-space, and cross-device scenarios cannot read or reuse
  another run's snapshot.

### Mapping and execution

- [ ] Supported and unsupported cases for every mapped block kind.
- [ ] Breakdown, category-series, and account-card downgrade chains cover money,
  count, negative/zero category values, maximum groups/rows, and version bounds.
- [ ] Account-card preferred persistence remains reference-only; its metric and
  Markdown fallbacks use only the server-resolved balance.
- [ ] Empty/unknown clients persist no structured blocks and receive complete
  bounded Markdown.
- [ ] Mixed parallel display calls retain order while taking different downgrade
  paths.
- [ ] Read and local-write validation failures emit Markdown and telemetry.

### Negative controls

- [ ] Tests fail if absent capabilities are treated as all-supported.
- [ ] Tests fail if upload recomputes capabilities from the current registry.
- [ ] Tests fail if retry inherits the original run's capabilities.
- [ ] Tests fail if a downgrade reads model arguments or model text.
- [ ] Tests fail if `x-jiabu.account_card` persists the live balance.
- [ ] Tests fail if unsupported/invalid structured output is silently dropped.
- [ ] Tests fail if capability sets change the agent tool list or prompt bytes.

## Assumptions

- [ ] `ChatWeave-Capabilities` block versions are maximum supported versions,
  so a declaration of 2 accepts emitted schema 1. This is part of the existing
  ChatWeave client contract and will be locked by parser tests.
- [ ] Markdown is the universal fallback and requires no declared block
  capability. This is guaranteed by the message protocol and existing stream
  renderer.
- [ ] The outbox payload JSON is a client-local durable envelope until upload;
  a reserved field can be removed before request serialization. This must be
  verified against leasing/retry code and existing stored-row compatibility.
- [ ] Capability-dependent behavior is presentation-only; the complete tool
  list remains authorized and frozen independently. Existing prompt snapshot
  tests plus new byte comparisons must validate this.
- [ ] Current shipped clients do not send block capabilities on POST. A safe
  rollout therefore requires this client transport change and the server change
  to ship together; no server-first deployment is authorized in this slice.
- [ ] Existing fallback strings are bounded and contain only validated
  server-owned values. Each newly reachable fallback path must re-check that
  invariant in focused tests.

## Acceptance Checklist

- [ ] Every issue #55 functional and compatibility requirement is implemented.
- [ ] Full server gates pass on `jiabu-build`: format, clippy, compile/live-eval,
  PostgreSQL 18 tests, dependency policy, audit, management boundary,
  transaction rules, generated entities, and OpenAPI snapshots.
- [ ] Client code generation/parity, format, fatal-info analysis, rules/icons,
  workspace tests, app non-golden tests, and design-package tests pass on
  `jiabu-build`; no PNG changes exist.
- [ ] Focused negative-control mutations fail for the reason claimed and are
  restored before final verification.
- [ ] Independent whole-PR review covers requirements, data/security,
  architecture, tests, operations/compatibility, and maintainability with no
  unresolved P0/P1/P2.
- [ ] The dev-plan file is removed after acceptance, all final CI checks pass,
  and the PR is squash-merged under the standing review authority.
- [ ] No deployment occurs; bundled rollout remains separately gated.
