# Dev Plan: Separate Display Selection, Query, Validity, and Rendering Scores (#60)

## Summary

Make the 84-case evaluator diagnose display failures instead of collapsing chart selection, query meaning, complete arguments, and call ordering into one exact-trace mismatch. Correct the under-specified live cases and establish an eval-only baseline without changing prompts, tool schemas/descriptions, routing, or deployment.

## Scope

In scope:

- Score display selection, query semantics, argument validity, rendered block shape, factual values, and prose/safety as separate layers.
- Treat a direct display query and an equivalent successful `query_stats` / `search_records` followed by `from_call` as the same query semantics.
- Preserve deterministic exact-trace tests where call plumbing itself is under test, but stop using exact trace equality as the only live display score.
- Export bounded, allowlisted evidence that is useful for diagnosis without retaining raw user/model/tool content.
- Add `core`, `integration`, and `stress` evaluation tiers, default existing untagged entries to `core`, and report tier totals separately.
- Correct the five case definitions frozen below while keeping the corpus at 84 entries.

Out of scope:

- Any static-instruction, tool-description, JSON Schema, model-routing, provider, or application behavior change.
- A new live Sol/Terra run or any prompt candidate.
- New tier-specific release thresholds, changes to the current hard-pass formula, or changes to CLI exit behavior. This slice only adds diagnostic columns and tier summaries; Howard will decide any future gating policy after seeing the new baseline.
- PR merge or deployment without a later explicit decision.
- Persisting raw model/user prose, raw tool arguments, URLs, DSNs, upstream errors, credentials, or secrets.

## Scoring Model

Use two independent canonical objects rather than one display intent:

- `DisplaySelection`: the ordered display-tool enum only (`show_metrics`, `show_breakdown`, `show_bar_chart`, `show_trend`, `show_records`, `show_account_card`; extend only from the repository's fixed display-tool allowlist). The display tool is never part of query comparison.
- `CanonicalQuery`: source family (`stats`, `records`, `demo`, or `account`), plus only the behaviorally material query fields for that family. Stats retain measure, kinds, period, grouping, filters, and account alias. Records retain structured filters, ordering, limit, and a `text_present` boolean. When search text is present, compare normalized actual text to expected text transiently while the journal value is in scope, retain only a non-content `text_equal` result, and never copy the text into canonical/audit/report structures. Demo retains an allowlisted scene enum. Account retains a stable fixture alias, never a UUID.

Pair expected and actual display calls by display-call ordinal. Missing, extra, or reordered display calls fail display-selection cardinality/order. For a paired call:

- Display selection is pass/fail from the tool enum alone, even when its arguments are invalid.
- Argument validity is pass/fail only from provider/tool-schema validation (including tool-specific argument checks). A schema-valid call remains valid if execution later returns a business/runtime error. Execution outcome is a separate internal fact used for `from_call` resolution and the preserved legacy business-error check.
- Query semantics is tri-state: `pass`, `fail`, or `not_assessable`. It is `not_assessable` when an expected call is missing, arguments cannot be parsed, a `from_call` reference is absent/later/failed, or the source family cannot be resolved. Query pass rate uses only pass+fail as its denominator, while reports must show the `not_assessable` count separately. A required row with `not_assessable` still fails the unchanged row hard-pass result through the missing/invalid display layer; it can never become green by leaving the query denominator.
- Block shape, factual values, and prose/safety continue to score from delivered output, independently of the three call layers.

Direct-query and `from_call` paths compare equal only after both resolve to the same `CanonicalQuery`. Build a journal result map keyed by call ID containing tool, typed arguments, ordinal, and actual success/failure outcome; never infer success from call presence or order. A reference is eligible only when it points to an earlier successful compatible source call (`query_stats` for stats displays, `search_records` for record-list displays).

Preserve the two existing row invariants exactly: global provider-invalid count (`tool_total - tool_valid`) must equal `expected_invalid_calls`, and global journal business-error count must equal `expected_business_errors`. Mismatches keep the existing `display_invalid_call_mismatch` / `display_business_error_mismatch` reasons and continue to feed `display_pass` and therefore `hard_pass`. These legacy whole-run checks include non-display calls and are reported separately from the new per-display argument-validity layer. `display-018` removes its nonzero expectations as frozen below; all other entries retain their current values/defaults.

## Frozen Case Revisions

The implementation must use these definitions rather than choosing wording or intent later:

- `display-002` (`core`): keep input and setup unchanged. Expected selection is one `show_metrics`. Expected canonical stats query is `sum`, `expense`, `2026-10-01..2026-10-31`, grouped by purpose, with no filters. Either a direct query or a successful earlier equivalent `query_stats` reference passes query semantics. Keep the two existing purpose labels and values.
- `display-006` (`core`): replace the input with `2026年5月到10月每个月分别花了多少？请用柱状图比较。` Keep the six existing records. Expected selection is one `show_bar_chart`; expected canonical stats query is `sum`, `expense`, `2026-05-01..2026-10-31`, grouped by month, with no filters. Keep the existing six labels and values.
- `display-008` (`core`): replace the input with `请用指标卡汇总2026年10月的支出；如果没有记录，就只如实说明“本月没有记录”，不要编造图表。` Keep the empty setup. Expected selection is one `show_metrics`; expected canonical stats query is `sum`, `expense`, `2026-10-01..2026-10-31`, ungrouped, with no filters. Expected blocks remain empty and the fallback is exactly the existing substring `本月没有记录`.
- `display-009` (`stress`): replace the input with `请用固定演示数据依次展示三种组件：月度支出指标卡、月度支出分类占比、半年支出柱状图。` Keep the empty setup. Freeze the ordered selections and demo scenes as `show_metrics(monthly_spending)`, `show_breakdown(monthly_spending)`, and `show_bar_chart(half_year_trend)`. Keep the existing three blocks, their values, and `【演示数据】` server marker.
- `display-018` (`core`): replace the live invalid-call instruction with `比较2026年9月和10月的支出，请用柱状图展示；如果这两个月都没有记录，就用一句普通文字说明，不要编造图表。` Replace setup records with September expense 5000 minor units on `2026-09-03` and October expense 6800 minor units on `2026-10-03`, using the existing bank/purpose fixtures. Remove live `expected_invalid_calls` and `expected_business_errors`. Expected selection is one `show_bar_chart`; expected canonical stats query is `sum`, `expense`, `2026-09-01..2026-10-31`, grouped by month, with no filters. Expected block is `category_series`, labels `9月`, `10月`, values `[5000, 6800]`, no account, `demo: false`; normal fallback list is empty. Preserve the old invalid-call-to-one-sentence-fallback behavior in a deterministic fault-injection test, where the injected invalid display call must yield no block and a one-sentence ordinary-text fallback.

Tier assignments outside those five cases are also frozen: `display-013` through `display-016` are `integration`; `en-ambiguous-008`, `en-ambiguous-009`, and `display-017` are `stress`; all other omitted tiers default to `core`.

## Development Checklist

- [ ] Add a strict `EvaluationTier` enum (`core`, `integration`, `stress`) to dataset entries with `core` as the backward-compatible default, and apply the frozen tags above.
- [ ] Introduce separate `DisplaySelection` and `CanonicalQuery` types and the ordered pairing/tri-state rules from the scoring model.
- [ ] Normalize nested versus flat filters and fixture IDs to stable aliases. Do not retain display tool type inside `CanonicalQuery`.
- [ ] Build the per-call journal result map keyed by call ID and dereference only earlier, successful, compatible source calls.
- [ ] Keep non-equivalent queries distinct: wrong source family, measure/kind, period, grouping, filter, record ordering/limit/text equality, demo scene, account alias, or unresolved/incompatible `from_call` must not pass query semantics. Compare search text transiently and retain/export only presence/equality signals.
- [ ] Extend the provider audit with a bounded display-call record. Tool names serialize only as a fixed known-tool enum or `<unknown>`; arbitrary names are never copied. Arguments serialize only through allowlisted typed fields. Record-search text becomes presence/equality signals only, never text. UUIDs become fixture aliases or `<redacted-id>`.
- [ ] Cap audited display calls at 16 per case and every list at 16 items; cap allowlisted labels/enum-like strings at 64 UTF-8 bytes. On overflow, retain the prefix, set an explicit `audit_complete: false`, `truncated: true` marker and discarded count, and never append discarded content. Audit completeness is a separate diagnostic: overflow does not turn individually schema-valid calls into invalid calls and does not alter the preserved hard-pass formula.
- [ ] Export CSV columns for tier, expected/actual display selections, bounded canonical-query summaries, display-selection score, query-semantic tri-state, query `not_assessable` count, and argument-validity score. Keep existing block/value/prose columns and replace the overloaded reason with layer-specific allowlisted reason codes.
- [ ] Add overall and per-tier summary rows for the unchanged hard-pass count and each new display layer. Preserve existing business and question metrics, existing CLI exit codes, current hard-pass behavior, and the exact global invalid-call/business-error comparisons described above.
- [ ] Apply the exact five case revisions above without changing the 84-entry count.
- [ ] Update eval README/schema documentation so future cases declare whether they test user behavior, integration fallback, or stress behavior and do not pre-register an arbitrary equivalent transport path.
- [ ] Check all repository consumers of result CSV before changing the header; update only in-repository consumers in this slice.

## Test Checklist

- [ ] Dataset tests reject unknown tier values, prove omitted tier defaults to `core`, verify every frozen tier assignment, and keep the corpus at exactly 84 entries.
- [ ] Canonicalization tables cover direct query versus `from_call` equivalence for stats and records, nested/flat filters, stable fixture aliases, demo sources, and account cards.
- [ ] Pairing tests cover missing, extra, and reordered display calls. Tri-state tests prove invalid/missing/unresolved calls are reported as `not_assessable`, excluded only from the query denominator, counted explicitly, and still fail the unchanged row hard pass.
- [ ] Journal tests prove `from_call` resolution uses the actual result mapped by call ID; present-but-failed, later, missing, and source-incompatible references cannot pass.
- [ ] Negative controls independently mutate only display tool, query period, grouping, filter, limit, demo scene, source-call compatibility/order/outcome, validity, block type, and value. Each mutation turns red only in its intended layer, except the documented hard-pass consequence.
- [ ] A direct query and an equivalent source-query path both pass selection/query semantics; an exact-trace plumbing test still distinguishes them where explicitly required.
- [ ] Invalid JSON, unknown tool, invalid schema, valid-but-business-rejected calls, and 17+ repeated calls produce bounded sanitized evidence. A valid-but-business-rejected call remains argument-valid; repeated individually valid calls remain valid. Overflow only makes `audit_complete` false, sets truncation/count fields, and never emits discarded content.
- [ ] Malicious unknown tool names, record-search text, labels, URLs, DSNs, bearer tokens, note text, upstream errors, and UUIDs cannot enter CSV evidence. Tests assert `<unknown>`, presence/equality signals, stable aliases/redaction, byte caps, and RFC 4180 escaping instead of raw content.
- [ ] The old `display-018` invalid-call fallback remains covered by deterministic fault injection and no live case asks a model to make a bad call.
- [ ] Result and summary CSV tests cover all new columns, tier rows, empty query denominators, explicit `not_assessable`, stable ordering, caps, overflow, and escaping.
- [ ] Regression tests retain whole-run `expected_invalid_calls` and `expected_business_errors` behavior, including invalid non-display calls, the existing reason codes, and their current effect on `display_pass`, `hard_pass`, and CLI exit code.
- [ ] Deterministic PostgreSQL Mock evaluation remains 84/84 on the revised corpus.
- [ ] Existing scoring, CLI, negative-control, live-feature compile-only, and synthetic credential tests remain green.
- [ ] Full x86 build-host gates pass: format, workspace/live checks, clippy, complete nextest, deny, audit, admin dependency boundary, rules, entities, and OpenAPI checks.

## Assumptions

- [ ] Executed tool calls can be joined to journal results by call ID. Verify this in code before implementation; if the runtime does not expose a reliable result outcome, stop and revise the design instead of inferring success from position.
- [ ] The provider audit observes invalid calls that never reach the journal. Verify the current `AuditedProvider` boundary and store only the bounded allowlisted summary defined above.
- [ ] Display-query semantics can be represented without result values or prose because query execution and rendered-fact scoring are separate layers; verify against every current display tool contract.
- [ ] Existing result consumers are internal and can accept additive/replaced display columns in this pre-release evaluator; validate repository consumers before changing the header.
- [ ] This revision establishes a new committed baseline. Scores from the old exact-trace evaluator are historical and must not be compared as if the metric definition were unchanged.

## Acceptance Checklist

- [ ] A failed row states independently whether display selection, query meaning, argument validity, final block, factual value, or prose contract failed.
- [ ] `display-002` passes with either equivalent query path, while a wrong display type fails only selection and a wrong month/group/filter fails query semantics.
- [ ] The five corrected live inputs, setups, canonical queries, tiers, outputs, and fallbacks match the frozen definitions above and contain no hidden requirement to make an invalid call.
- [ ] Evidence contains only known enums/`<unknown>`, stable aliases/redactions, bounded allowlisted fields, and non-content presence/equality signals; differently worded non-empty record searches fail query semantics without either text entering CSV.
- [ ] Core, integration, and stress results are separately visible; the unchanged overall total and CLI behavior remain available, and no new tier gate is introduced.
- [ ] Independent plan and code review find no P0/P1/P2 issue.
- [ ] All offline gates and Mock 84/84 pass.
- [ ] No prompt/tool-schema change, live model run, model switch, merge, or deployment occurs in this slice.
