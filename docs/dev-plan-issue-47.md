# Dev Plan: PDF file attachments in chat (#47)

## Summary

Add a generic, provider-neutral file path for chat attachments, with PDF as the
only v1 type. The server accepts and authorizes content-addressed PDF uploads,
binds ordered file references and display names to a chat message, and loads raw
bytes only while constructing a model request. The existing JPEG/image path is
left intact.

The live SIWC capability has already been verified with synthetic data: an
inline Responses `input_file` containing a valid fake PDF completed on
`gpt-6.1-sol` and returned the exact probe value.

## Scope

### In scope

- `PUT /v1/spaces/{space_id}/files/{sha256}` for a complete PDF body and
  `GET /v1/spaces/{space_id}/files/{sha256}` for an authorized raw download.
- PDF only (`application/pdf`), 10 MiB per file, four files per message, and
  20 MiB combined per message.
- Optional ordered `files: [{"sha256":"…","name":"…"}]` on chat input.
- Canonical server-owned MIME and byte size; the caller supplies only hash and
  display name in the message.
- Durable file references/metadata in the user message and frozen run input,
  with no raw bytes or base64 in PostgreSQL.
- Provider-neutral file capability and request items; SIWC inline
  `input_file` (`filename` + PDF `file_data`) emitted at call time.
- Existing blob lifecycle/retention, OpenAPI, entity generation, and cleanup
  extended to raw PDF objects.

### Out of scope

- Flutter picker/upload/preview/download UI.
- Changes to existing JPEG upload/download or `images` message behavior.
- Non-PDF formats, OCR, local parsing/rendering, thumbnails, antivirus, or
  password-protected-PDF recovery.
- OpenAI Files API / `file_id`.
- Storage-accounting terminology/refactors and deployment.

## Design

### 1. Domain and wire types

- Add a small provider-neutral `FileAttachment` value carrying canonical MIME,
  safe display filename, and an opaque byte source/data URL only after runtime
  loading. Keep it separate from `images` so image limits and PDF limits cannot
  accidentally share semantics.
- Extend `RequestItem::Message` with `files`, defaulting to an empty list for
  backward-compatible deserialization of existing journal/history fixtures.
- Extend adapter `Capabilities` with explicit PDF/file support and a maximum
  file count. SIWC advertises that support; current mocks opt in explicitly.
  Do not add a model-level `files` column: the dedicated route is the
  administrator's per-model allowlist, while adapter capability is the hard
  provider-protocol gate.
- A file-bearing chat uses a new `chat_file` task kind. This is deliberately not
  the smallest code diff: it follows the existing `chat_vision` route model,
  gives waiting/availability and metering a distinct PDF category, and lets an
  administrator choose the ordered models allowed to receive PDFs. Add it
  append-only to both task-kind database checks, admin parsing, routing,
  metering/status/OpenAPI projections, and default configuration.
- When one message contains both images and files, select `chat_file` and also
  apply the existing model/adaptor vision and `max_images` filters. Route
  preflight must evaluate the actual request requirements, not merely the task
  name, so it cannot optimistically report a file route as usable when every
  candidate is eliminated by the images.
- Distinguish route states before waiting: if no configured, enabled, paid-policy
  eligible, credentialed, file-capable candidate satisfies the request, fail the
  run immediately with stable reason `no_available_route`; only candidates that
  exist but are temporarily excluded by an open circuit breaker enter the
  existing `waiting_ai` retry window.

### 2. Storage and database

- Add one append-only migration. Relax `blobs.mime` from JPEG-only to the
  enumerated current set (`image/jpeg`, `application/pdf`) and make image
  dimensions nullable only for non-image rows, enforced by a check constraint.
- Reuse `blobs` and `blob_refs`; add a `chat_file` module/ref kind so generic
  files cannot be mistaken for images by existing document/ledger code.
- Rebuild the two partial uniqueness indexes so `chat` and `chat_file` are both
  member-owned: the member index uses
  `module in ('chat','chat_file')`, and the space/module index excludes both.
  Update every existing module predicate deliberately: the accepted module list
  and member-scoped module lookup include `chat_file`; ledger/document promotion
  continues to accept only the caller's `chat` JPEG ref; the chat-runtime image
  resolver continues to require `module='chat'` and `image/jpeg`.
- Keep filename out of global blob metadata because equal content can be sent
  under different names. Filename is message/run metadata.
- Extend object storage with one raw PDF key/suffix. Generic file write uses the
  same put-if-absent and lifecycle lock ordering as JPEGs. Update key creation,
  newest-object lookup, deletion, orphan candidate discovery, and local staging
  cleanup so both committed and interrupted PDF uploads are collectable while
  the three JPEG variants remain unchanged.
- Validate a complete buffered body before the final authorization recheck:
  size, supplied SHA-256, request Content-Type when present, and this exact PDF
  envelope rule: byte offset zero is `%PDF-` followed by one ASCII digit, `.`,
  and one ASCII digit; `%%EOF` occurs within the final 1024 bytes and only ASCII
  whitespace or NUL follows it. V1 deliberately rejects leading garbage bytes.
  It does not parse xref/trailer structures, decrypt, decompress, render, fetch,
  or extract content; encrypted PDFs may upload and later receive the provider's
  existing request-rejection error.

### 3. HTTP authorization and replay

- File upload runs membership, join-epoch, read/write, and chat authorization
  before resource admission/body reading; it rechecks them after the full body
  is read and validated and before adding the reference.
- Repeated uploads still consume and validate the complete body and return the
  same response as a new upload. Global existence is never disclosed.
- PDF envelope mismatch, an empty body, or a present non-`application/pdf`
  request Content-Type maps to the existing 415 `unsupported_media_type`;
  oversize maps to 413 `payload_too_large`; hash mismatch keeps the existing
  `StorageError::Invalid` / validation mapping. Add no new upload error category.
- Download begins through `SpaceTx` and requires a `chat_file` ref owned by the
  requesting member. Cross-space, stale membership, and another member's chat
  attachment all return the same not-found behavior.
- Download returns canonical `application/pdf`, byte length,
  `Content-Disposition: attachment`, and `X-Content-Type-Options: nosniff`.
  The stored message filename is not accepted as a URL parameter and is not
  interpolated into a response header.

### 4. Message and runtime lifecycle

- Validate filenames as display metadata: Unicode text, 1–255 UTF-8 bytes,
  reject control characters, path separators, `.`/`..`, and trim ambiguity.
  Preserve the accepted display value exactly; do not normalize it into an
  object key or log field.
- At message submission, verify every referenced file through `SpaceTx`, resolve
  canonical MIME/size, reject duplicates, enforce count/combined-size limits,
  and store the resolved ordered list with the user message and frozen input.
- Idempotency comparison includes ordered `{sha256,name,mime,bytes}` metadata.
  Exact replay returns the original assistant message; any changed name/order/
  hash conflicts. Authorization and epoch checks remain before replay.
- Retry copies only durable metadata. At each model call the runtime rechecks
  the member-owned reference and loads raw bytes from object storage. The bytes
  are converted to a PDF data URL in memory, substituted into the request, and
  dropped after the provider call.
- File data never enters journal items, `chat_entries`, frozen history,
  prompt-snapshot rows, metering rows, errors, traces, or debug output.
- Files remain available for every provider/tool-loop attempt inside the run
  created by the attaching message. V1 does not automatically resend a PDF in a
  later user message/run: a follow-up such as “第 3 页呢” sees history text but
  not the prior file unless the client attaches it again. This matches current
  image-history behavior and avoids unbounded repeated payload cost; lock it with
  a test and state it in the public contract.

### 5. SIWC mapping

- For non-assistant messages, append each PDF as
  `{type:"input_file", filename, file_data:"data:application/pdf;base64,…"}`
  after the text and image parts, preserving message and attachment order.
- Reject assistant files and unsupported MIME/data URL shapes before network IO.
- Continue using `store:false`, `stream:true`, the existing cache/session key,
  namespace tools, and encrypted reasoning replay. No Files API call is added.

## Development Checklist

- [ ] Add the append-only database migration and regenerate entities on the
      build host.
- [ ] Add raw PDF validation and raw object-store put/get/delete support without
      changing JPEG behavior.
- [ ] Rebuild member-vs-space blob-ref uniqueness predicates and audit every
      `module='chat'` / `module<>'chat'` decision for intentional PDF behavior.
- [ ] Add file upload/download routes, handlers, service methods, OpenAPI
      annotations, route catalog entries, and isolation-matrix coverage.
- [ ] Add database methods for saving/resolving member-owned `chat_file` refs
      and canonical metadata through `SpaceTx` only.
- [ ] Extend chat input, `StartMessage`, idempotency metadata, frozen input, and
      retry/render logic with resolved ordered files.
- [ ] Add `chat_file` task routing and explicit file capabilities across domain,
      configuration, admin, router, mocks, eval fixtures, and status reporting.
- [ ] Make request-aware route preflight distinguish permanent no-candidate from
      temporary breaker exclusion, including combined image+PDF requirements.
- [ ] Add runtime file loading and SIWC `input_file` request construction with
      redacted debug behavior.
- [ ] Regenerate both OpenAPI documents and update delivery/engineering docs
      only where the public contract changed.

## Test Checklist

### Storage/database

- [ ] Accept a small valid PDF; reject wrong hash, non-PDF signature/MIME,
      missing trailer, empty body, and >10 MiB body.
- [ ] Same bytes produce the same hash/object; separate message filenames do
      not alter global metadata.
- [ ] Existing JPEG original/display/thumb behavior is unchanged.
- [ ] Removing the last ref starts retention; cleanup deletes raw PDF objects;
      a concurrent new ref prevents deletion.
- [ ] An interrupted PDF upload whose transaction never commits is discovered
      and reclaimed by orphan/staging cleanup after the grace period.
- [ ] Migration succeeds on a fresh PostgreSQL 18 database and when upgrading a
      database at migration 0010 that already contains JPEG blob/ref rows;
      generated entities match the resulting schema. The repository has no down
      migrations, so no synthetic down/up claim is made.

### API/security

- [ ] Upload authenticates and checks membership/epoch/authorization before
      capacity/body handling; final commit rechecks after a race barrier.
- [ ] Exact repeated upload consumes the whole body and is indistinguishable
      from first upload.
- [ ] Download works only for the owning chat member and returns PDF headers,
      `attachment`, and `nosniff`.
- [ ] Unknown hash, cross-space, other-member, exited/rejoined member, API key,
      and unauthorized cases are indistinguishable where required.
- [ ] Two members in one space can upload identical PDF bytes, each receives a
      distinct member-owned ref, each can attach/download their own ref, and
      neither can infer or access the other's ref.
- [ ] The legacy JPEG download authorizer rejects the new `chat_file` module by
      default, preventing the old endpoint from exposing raw PDF content.
- [ ] Every space path is in the isolation matrix; OpenAPI examples contain
      fake data only.

### Chat/runtime/provider

- [ ] Text-only and image-only messages remain byte-for-byte compatible in
      durable metadata and provider wire fixtures.
- [ ] Empty text plus one PDF is valid; empty text plus no attachment is invalid.
- [ ] Reject >4 files, duplicates, >20 MiB combined, unsafe filenames, and a
      file ref not owned by the caller.
- [ ] Exact message replay succeeds; changed file hash/name/order conflicts;
      replay after join-epoch change remains rejected.
- [ ] Frozen input and retry preserve resolved metadata, not bytes/base64.
- [ ] Router requires file capability and the `chat_file` route, enforces count,
      and never falls through to a paid provider while paid fallback is off.
- [ ] No configured request-capable candidate fails immediately with
      `no_available_route`; a request-capable candidate excluded only by its
      circuit breaker enters the existing wait/retry path.
- [ ] A combined image+PDF request selects `chat_file`, applies vision and image
      count filters, and fails immediately when those filters remove all routes.
- [ ] SIWC wire fixture contains ordered `input_file` parts with filename and
      PDF data URL; unsupported/assistant files fail before network IO.
- [ ] A runtime test proves bytes are loaded only immediately before a provider
      attempt and a missing object/reference fails without leaking content.
- [ ] A later user message does not silently inherit the earlier run's PDF; the
      same-run tool loop continues to receive it on each provider attempt.
- [ ] Sentinel filename/content/base64 strings are absent from captured logs,
      journal/history/chat rows, prompt snapshots, metering rows, and errors.
- [ ] Synthetic online SIWC smoke reads a fake PDF and returns its probe value.
- [ ] Before release, an online synthetic PDF near the 10 MiB per-file limit
      confirms the provider/request-body limit and records peak request memory;
      four files/20 MiB raw expands to roughly 27 MiB of base64 before JSON and
      is reconstructed on each model attempt.

### Full verification

- [ ] On `jiabu-build`: `cargo fmt --all -- --check`.
- [ ] On `jiabu-build`: `cargo clippy --workspace --all-targets -- -D warnings`.
- [ ] On `jiabu-build`: `cargo nextest run --workspace` against PostgreSQL 18.
- [ ] On `jiabu-build`: `cargo deny check`, `cargo audit`, and every
      `tool/check-*.sh` script, including entity/OpenAPI checks.
- [ ] Review exported public/admin OpenAPI diffs and `git diff --check`.

## Security Matrix

| Boundary | Allowed | Rejected / hidden | Evidence |
|---|---|---|---|
| Upload | active RW session member, current epoch | key, stale/absent member, wrong space | preflight + post-body race tests |
| Download | same member owns `chat_file` ref | other member/space, absent ref | identical 404 tests |
| Message submit | ordered owned refs within limits | forged/unowned refs, unsafe names | API + DB assertions |
| Replay | exact durable input and current epoch | changed name/order/hash, rejoin | idempotency tests |
| Provider | capable routed model | missing route/capability/type | router/wire negative controls |
| Observability | hashes, counts, MIME, byte totals | name/content/base64/message/token | sentinel log/row sweep |

## Acceptance Matrix

| Requirement | Automated evidence | Manual/online evidence |
|---|---|---|
| Valid PDF upload/download | API/storage integration tests | curl headers + SHA-256 on fake PDF |
| Isolation and epoch safety | cross-member/space/rejoin tests | none |
| Exact idempotency | replay mutation table tests | none |
| Durable metadata only | database/log sentinel sweep | inspect one fake run |
| SIWC reads PDF | request-wire test | live fake-PDF probe |
| No image regression | existing blob/chat suites | none |
| Release eligibility | full build-host CI + independent whole-PR review | no deployment |

## Assumptions

- [x] A blob SHA-256 is globally content-addressed, while authorization is
      carried by `blob_refs`; this is guaranteed by the current schema and
      services.
- [x] `blob_refs` lifecycle triggers can cover PDF refs without a parallel
      retention system; current triggers operate by hash, not MIME.
- [x] SIWC accepts inline PDF `input_file`; verified live with fake content on
      the configured account/model before implementation.
- [x] The upstream request does not require the OpenAI Files API for this path;
      verified by the same inline-data probe.
- [x] `chat_file` is the chosen routing extension even though a generic
      capability filter would touch less code: it follows `chat_vision`, keeps
      availability/waiting and metering explicit, and makes route configuration
      the per-model PDF allowlist without adding a model-level files column.
- [x] Minimal PDF envelope validation is sufficient for v1 because the server
      does not parse/render the document: strict offset-zero version header plus
      final-1024-byte `%%EOF` with only whitespace/NUL after it; upload failures
      reuse the existing 415/413/validation mappings.
- [x] Client work can follow independently because the new fields are optional
      and existing image contracts remain unchanged.

## Acceptance Checklist

- [ ] Every functional and security row above has passing evidence.
- [ ] Existing JPEG and chat/image behavior has no regression.
- [ ] Full build-host checks pass and OpenAPI/entity outputs are current.
- [ ] Independent whole-PR review covers correctness, acceptance-linked tests,
      isolated environment, reviewer-owned negative controls, whole-PR
      complexity, and trial merge/base verification.
- [ ] All P0/P1 findings are fixed; each P2/P3 is fixed or tracked explicitly.
- [ ] Dev plan is removed before final merge ceremony.
- [ ] CI is green; merge may proceed under the standing Jiabu authority, but no
      deployment occurs without separate authorization.
