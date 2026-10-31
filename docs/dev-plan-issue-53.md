# Dev Plan: genUI S4 account card and account-filtered history (#53)

## Summary

Add the sixth display tool, `show_account_card`, and render its strict
`x-jiabu.account_card` reference block from the active space's live local
ledger. The card shows the current balance, current-month inflow/outflow, and
the newest three related entries; its action reuses the existing History page
and existing account filter.

This is a complex cross-component feature: the server tool contract, persisted
chat protocol, local ledger calculations, reactive Flutter UI, navigation, and
visual/accessibility acceptance must agree. No deployment is part of this
slice.

## Verified baseline

- `show_account_card` is not registered on `origin/master`; the five current
  display tools share prompt/schema alignment guards.
- `client/app/lib/domain/history_filter.dart` already matches an account against
  `account_id`, `to_account_id`, `purpose_id`, and `to_purpose_id`, and the
  History page already exposes an account selector. S4 must reuse this instead
  of creating another filter implementation.
- `LedgerViewModel` is a per-space generated Riverpod provider backed by the
  local repository stream, so the account card can react to local data without
  another network/model request.
- `ledgerBalances` already reproduces the server balance rules for real and
  purpose accounts, includes archived accounts, ignores void records, and uses
  `BigInt` before enforcing the safe integer range.
- `x-jiabu.record_card` provides the existing reference-only block/parser and
  provider-wiring pattern. The account card must remain a distinct business
  block rather than being inferred from Markdown.

## Scope

### In scope

- A direct `show_account_card { account_id }` server display tool for real and
  purpose accounts, including archived accounts retained in history.
- A server-owned result containing the resolved identity/version/name/currency/
  balance needed by the model and future S5 downgrade.
- A persisted `x-jiabu.account_card:1` block containing only `accountId`,
  `versionAtReply`, and `nameSnapshot`.
- A strict Flutter parser and production renderer backed by the active
  space-scoped local ledger snapshot.
- Current balance, current-calendar-month inflow/outflow, and newest three
  active entries calculated relative to the referenced real or purpose account.
- A full-width action that resets stale History filters, applies only the
  account filter, and opens the existing `/history` route.
- The approved named removable History filter, `只看 <账户名> ×` (localized),
  for both real and purpose accounts. The current generic `账户` chip and
  clear-all action do not satisfy this contract by themselves.
- Localized loading, unavailable/permission, archived, changed, and empty
  states; narrow/large-text layout; semantics; reviewed goldens.

### Out of scope

- S5 client capability parsing/persistence and old-client server downgrade.
- S6 live SIWC evaluation and prompt-quality scoring.
- A new account detail page, balance graph, account editing, query/deep-link
  contract, or replacement History filter model.
- Setup wizard and document-card work.
- Deployment.

## Contract and design decisions

1. `show_account_card` does not accept `Source`, `from_call`, demo data, or any
   model-supplied display value. `account_id` is the only argument.
2. Account lookup and balance are space-scoped. Missing and foreign IDs produce
   the same bounded `/account_id` rule feedback; the response reveals no
   cross-space ownership information.
3. The tool result may include server-resolved account metadata and balance so
   the model can summarize it and S5 can later construct a server-owned metric
   fallback. The persisted business block itself is reference-only.
4. The client resolves current data from the active local snapshot. It prefers
   the live account name and uses `nameSnapshot` only if the reference can no
   longer be resolved locally.
5. Current-month totals deliberately reuse Overview's existing device-local
   `ledgerClockProvider` month semantics in this slice. Adding true IANA
   space-timezone conversion is broader work and is not introduced implicitly
   here. Opening balance contributes to the balance but is not a monthly flow.
6. Account-relative movement is one shared domain helper. Destination-side
   transfer/reallocation entries must reverse the sign/direction relative to
   the selected account. Void entries do not contribute; refunds follow the
   same ledger semantics as the existing balance calculation.
7. Opening from a chat card deliberately replaces the entire prior History
   filter with `HistoryFilter(account: accountId, labels: ...)`; it does not
   preserve hidden search/date/kind/member/tag constraints.
8. A block version change is represented by a new schema version; fields are
   never silently repurposed.

## Development checklist

### Server: tool and query boundary

- [ ] Add `ShowAccountCard` arguments with `deny_unknown_fields`, strict JSON
      Schema compatibility, and a schema-valid example containing only
      `account_id`.
- [ ] Add `ShowAccountCard` to `DisplayKind`, `StepKind`, tool registration,
      static prompt capability list, and registry/prompt/description guards.
- [ ] Give the tool an explicit `何时用 / 何时别用 / 例` description that tells
      the model to use a context account ID and not invent account data.
- [ ] Resolve the account through `SpaceTx` and query its current balance with
      the existing ledger balance semantics; support real, purpose, and archived
      accounts.
- [ ] Map not-found/foreign-space lookup failures to the same bounded
      `/account_id` validation rule without including IDs, names, or values.
- [ ] Return a discriminated account-card output with server-resolved ID,
      version, name, currency, balance, and archived state as needed; reject
      inconsistent display branches.
- [ ] Add output examples/snapshots and prove the tool remains AgentOnly, Read,
      and exempt from confirmation.

### Server: block mapping and validation

- [ ] Register the strict `x-jiabu.account_card:1` schema in
      `crates/chat`; require UUID `accountId`, positive integer
      `versionAtReply`, non-empty bounded `nameSnapshot`, and no extra fields.
- [ ] Special-case account-card mapping before the generic `show_*` mapper so
      the persisted block has exactly the three reference fields.
- [ ] Validate the mapped block with the pinned ChatWeave validator before
      persistence.
- [ ] Generate the fallback text only from the server-owned result using the
      existing safe money formatter; never read model arguments to build it.
- [ ] Preserve the current behavior for the other five display tools and all
      automatic write-result cards.

### Client: parser and domain calculations

- [ ] Add a typed/strict account-card reference parser or constructor and
      register `x-jiabu.account_card` in `jiabuChatRegistry`.
- [ ] Add a domain helper that returns account-relative signed movement and a
      presentation direction for both real and purpose accounts.
- [ ] Derive current-month inflow/outflow with `BigInt` accumulation and the
      existing safe integer boundary; exclude opening balance and void rows.
- [ ] Derive the newest three active related rows from the same deterministic
      history ordering used by `filterHistory`.
- [ ] Keep destination-side transfers/reallocations, refunds, and same-day
      ordering correct and covered by focused tests.

### Client: reactive card and navigation

- [ ] Add `AccountCardBlock` as a `ConsumerWidget` wired by the space-scoped
      production `chatRegistry` provider.
- [ ] Watch the existing per-space `LedgerViewModel`; render local balance,
      month flows, and recent entries without a network/model refresh.
- [ ] Distinguish loading, permission denied, unresolved/deleted reference,
      archived account, version/name changed since reply, empty recent list,
      and out-of-range aggregate states with localized bounded UI.
- [ ] Prefer the live account name and fall back to `nameSnapshot` only when the
      local account is absent.
- [ ] Add a full-width localized action that replaces stale filters with an
      account-only `HistoryFilter` and then calls `context.go('/history')`.
- [ ] Add the approved named removable History filter (`只看 <账户名> ×`, with
      localized equivalent) for both real and purpose accounts; one tap on its
      remove action clears only the account filter. Keep the generic selector
      available for changing the selected account.
- [ ] Use Jiabu design tokens and existing amount/record primitives; keep
      decorative marks out of semantics and the CTA reachable at 200% text.

### Generated and localized artifacts

- [ ] Add Chinese and English ARB entries for labels, states, summaries, and
      action text, including the named removable History filter; regenerate
      localization outputs on `jiabu-build`.
- [ ] Regenerate Riverpod/codegen only if source annotations change and verify
      the repository's generated checksum/parity guard.
- [ ] Add no dependency unless the implementation proves one is necessary;
      manually review any allowed-dependency change.

## Test checklist

### Server focused tests

- [ ] Strict parameter schema accepts only one valid `account_id`; missing,
      malformed, and extra fields fail.
- [ ] Prompt list, three-part description, example, registry, schema snapshot,
      and strict-mode guards include all six display tools exactly once.
- [ ] Real, purpose, and archived accounts return the correct server metadata
      and balance.
- [ ] Missing and foreign account IDs return indistinguishable bounded
      `/account_id` feedback and leak no private value.
- [ ] Mapper persists exactly `accountId`, `versionAtReply`, and `nameSnapshot`;
      all extra/missing/wrong-typed fields are rejected by block validation.
- [ ] Fallback amount/name come from the result and format correctly for CNY and
      a non-CNY currency.
- [ ] Other display tools, fallback behavior, and write-card auto-rendering are
      unchanged.

### Client domain and parser tests

- [ ] Data parser accepts the exact v1 reference and rejects missing, extra,
      wrong-typed, and invalid-ID fields.
- [ ] A registry/render-boundary test proves `schemaVersion > 1` is rejected by
      ChatWeave before the data parser, uses the unsupported-version fallback,
      and reports the bounded render error.
- [ ] Real-account expense/income/refund/outgoing transfer/incoming transfer
      produce the correct relative flow.
- [ ] Purpose-account allocation/expense/refund/outgoing reallocation/incoming
      reallocation produce the correct relative flow.
- [ ] Void rows, opening balance, nonmatching accounts, month boundaries,
      current-calendar-month selection, safe-range overflow, and same-day newest
      ordering are explicit cases.
- [ ] Recent rows include destination-side transfer/reallocation matches and are
      capped at three after deterministic sorting.

### Client widget/provider/navigation tests

- [ ] Live local ledger updates change the card without rebuilding the chat
      message or querying the model.
- [ ] Live name wins over `nameSnapshot`; missing reference uses the snapshot
      without exposing unrelated account data.
- [ ] Loading, permission loss, archived/changed, empty recent, unresolved, and
      out-of-range states render their expected localized UI.
- [ ] CTA navigation sets an account-only filter, clears every stale filter,
      opens `/history`, and returns records matching source and destination real/
      purpose fields.
- [ ] The route-transition test uses the real `context.go('/history')` handoff
      and proves the account filter survives the source widget unmount; if the
      current auto-dispose provider loses it, add the narrowest explicit handoff
      state rather than making every space ledger provider permanent.
- [ ] The named `只看 <账户名> ×` filter renders the resolved account name; its
      remove action clears only the account constraint, while the existing
      clear-all action still returns History to all records.
- [ ] Semantics expose account name, balance/month summary, recent entries, and
      the navigation action once, without reading decorative elements.

### Visual acceptance

- [ ] Capture real Jiabu chat-page goldens at 360px/100% and 430px/200%.
- [ ] Cover populated real account, populated purpose account, archived/changed,
      empty recent, loading/skeleton, and the named removable History filter
      states.
- [ ] Inspect PNGs directly for clipping, overflow, hierarchy, CTA reachability,
      deterministic decoration geometry, and accurate amount signs.
- [ ] Attach reviewed before/after screenshots to the PR and apply the
      `visual-change` label.

### Negative controls

- [ ] Add an amount field to the persisted block; the reference-boundary test
      must fail.
- [ ] Remove destination-side matching; the transfer/reallocation test must
      fail.
- [ ] Include an adjacent-month row; the month-boundary test must fail.
- [ ] Preserve a stale History constraint during CTA navigation; the navigation
      test must fail.

## Build-host gates

All compilation, tests, code generation, and goldens run on `jiabu-build` under
`~/.jiabu-build.lock`; this machine is edit/review only. Start the development
PostgreSQL service before acquiring the lock so the database process cannot
inherit the lock descriptor.

### Server

- [ ] `cargo fmt --all -- --check`
- [ ] `cargo clippy --workspace --all-targets -- -D warnings`
- [ ] `cargo nextest run --workspace`
- [ ] `cargo deny check`
- [ ] `cargo audit`
- [ ] admin-boundary, dependency/rules, entity, schema, and both OpenAPI checks
- [ ] focused mutation controls and live-eval regression gate if touched

### Client

- [ ] generated checksum/codegen parity as applicable
- [ ] `dart format --set-exit-if-changed .`
- [ ] `flutter analyze --fatal-infos`
- [ ] repository rules and icon checks
- [ ] workspace, app, and `jiabu_design` tests separately
- [ ] fixed-image golden verification and direct PNG review

## Independent plan review gate

Before implementation, review this plan against issue #53 and `origin/master`:

- [ ] Every issue decision is represented without reopening settled product
      choices.
- [ ] Each assumption is proven by the current code or has a test/validation.
- [ ] Security/isolation, correctness, compatibility, UI, and failure states are
      covered.
- [ ] No S5/S6 behavior has leaked into this slice.
- [ ] Review result is CLEAN with no unresolved P0/P1 and every P2/P3 explicitly
      resolved or tracked.

## Whole-PR review and acceptance

- [ ] Review all six crew-playbook areas with file/line evidence or explicit
      `not applicable` reasoning: correctness, tests-to-acceptance, isolated
      environment, reviewer negative controls, whole-PR complexity, and trial
      merge/base verification.
- [ ] Confirm P0/P1 are absent; fix or track every P2/P3 before merge.
- [ ] Trial-merge the final head into the then-current `origin/master` and rerun
      the proportionate gates if the base changed.
- [ ] Delete this temporary dev plan at acceptance closeout, commit, and push.
- [ ] Open/update the PR with gate results, reviewed screenshots, mutations, and
      no-deployment statement; monitor both GitHub CI jobs to green.
- [ ] Merge under the standing Jiabu authority only after review and acceptance
      are release-eligible, report the milestone, and continue directly to S5.

## Assumptions and validation

- [x] Account filtering already covers both sides of real transfers and purpose
      reallocations. Guaranteed by `filterHistory`; retain regression tests.
- [x] The local snapshot contains archived accounts and active/void record state.
      Guaranteed by the existing sync/domain model and balance tests; add card
      cases rather than changing sync scope.
- [x] Balance semantics are already shared conceptually between server SQL and
      client `ledgerBalances`. Reuse them and test the card's flow helper against
      the same record-kind matrix.
- [ ] Navigation can set a per-space provider filter before `/history` without a
      query parameter. This is unverified because `LedgerViewModel` is
      auto-dispose; prove the real route transition first and introduce only a
      narrow handoff mechanism if the provider loses state.
- [x] Current-month selection reuses Overview's existing device-local
      `ledgerClockProvider` semantics. Test both surfaces against the same clock
      override and the last/first day boundary; do not add space-timezone
      conversion in S4.
- [ ] The best localized presentation for an unresolved reference versus a
      transient loading snapshot can be expressed without new product behavior.
      Validate against existing record-card states and keep both states bounded.

## Acceptance checklist

- [ ] `show_account_card` is the sixth registered display tool and its contract
      cannot accept model-supplied display values.
- [ ] Persisted account-card blocks contain references only and validate before
      storage.
- [ ] The client renders correct live local balance, month flows, and newest
      three entries for real, purpose, and archived accounts.
- [ ] Card navigation opens existing History with only the intended account
      filter, includes source/destination ledger entries, and shows the approved
      named one-tap-removable filter.
- [ ] Permission, loading, missing/changed, empty, overflow, localization,
      accessibility, narrow-width, and 200% text states are covered.
- [ ] Focused negative controls fail for the intended reasons.
- [ ] Full server/client build-host gates, goldens, independent whole-PR review,
      trial merge, and GitHub CI pass.
- [ ] Temporary plan is removed, PR is merged, no deployment occurs, and S5
      starts immediately.
