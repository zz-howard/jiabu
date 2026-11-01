# Dev plan: issue #70, load chat history in pages

## Summary

`LocalChatSession._reload()` reads every local `chat_entry` of the space, then
queries `chatEntry` and `chatClientState` once per message and decodes each
message, on open and again on every local chat change. Opening cost grows
linearly with history (about 2 ms per message on the build host).

The chat now opens with the most recent window of 40 messages, loads older
pages when the list nears its top and newer pages when it nears its bottom
after a jump, and applies live changes only to rows that changed.

## Scope

- DAO (`local_store.dart`): batched, member- and space-scoped page queries
  ordered by `(created_at, id)`, batched client-state reads (IN lists), a
  changed-rows query driven by a per-row local revision, in-flight (streaming
  or paused) rows, and reply lookups for delivery state.
- Schema v3 (hand-written migration, like `chat_v2.dart`): `local_revision`
  on `chat_entries` and `chat_client_states`, plus indexes for the member
  timeline, revision scans, reply lookups and in-flight rows. Regenerate the
  schema dump and the generated migration helpers.
- `LocalChatSession`: a window `[oldest..newest]`; `loadOlder()`,
  `loadNewer()` and `jumpTo()`; live changes applied by revision; all
  existing guarantees kept.
- Domain: `ChatConversation` exposes the window (`history`) and the paging
  calls. The view model forwards them.
- UI: the list asks for older pages near its top (and newer pages near its
  bottom when the window does not reach the latest message), shows the thinking
  dots inline while a page loads, keeps the visible position, and keeps the
  date tape correct at a page boundary.

Out of scope: evicting pages from memory (ChatWeave's `BlockStore` has no
removal), a jump entry point in the UI (none exists yet).

## Dev checklist

- [ ] Schema v3 migration, `schemaVersion = 3`, regenerated dumps/helpers.
- [ ] DAO queries and revision stamping on every chat entry / client state
      write.
- [ ] Session window, paging, change-driven reloads, in-flight pinning,
      conversation inference, delivery, stop, receipts, restore, resets.
- [ ] Domain `ChatHistory` + `ChatConversation` paging API; view model calls.
- [ ] Chat screen: scroll-triggered paging, inline loading row, stable
      position, ChatWeave "new messages" pill not counting history pages,
      day tape at the window's oldest message.
- [ ] ARB string for the loading row's semantics label.

## Test checklist

- [ ] DAO: page ordering with `created_at` ties, limits, member and space
      isolation, changed-rows query, client-state batches, replies.
- [ ] Migration v2 → v3 (generated verifier and data-preserving test).
- [ ] Session: first window, `loadOlder`/`loadNewer`, live update inside the
      window, new message newer than the window, change older than the window
      ignored, paused message outside the first window is loaded and resumed,
      conversation inference with paging, delivery across a page boundary.
- [ ] Widget: scrolling up loads the older page with the inline indicator and
      keeps the visible message in place; no "new messages" pill.
- [ ] Day tape suppressed/kept correctly at the page boundary.
- [ ] Benchmark (tagged `benchmark`): `initialize()` and `loadOlder()` with
      50 / 500 / 5000 local messages, before and after.

## Assumptions

- Page size 40: two to four phone screens of chat, inside the owner's 30–50
  band, enough that the first scroll-up has content while the next page loads.
- `created_at` is set on every chat row (the ChatWeave list already requires
  `createdAt`); ties are broken by `id`.
- Rows changed while they are older than the window are not applied; they are
  read fresh when their page loads.
- A message streaming or paused is always in memory, even outside the window,
  so stop, resume and interrupt answering keep working.

## Acceptance

- Open time roughly constant for 50 / 500 / 5000 messages; page load bounded
  by the page size.
- Full client CI sequence green on the build host and on GitHub.
