# Dev Plan: Separate Display Selection, Query, Validity, and Rendering Scores (#60)

## Summary

Make the 84-case evaluator diagnose display failures instead of collapsing tool selection, complete arguments, and call ordering into one exact-trace mismatch. Correct under-specified live cases and establish a new eval-only baseline without changing prompts, tool schemas/descriptions, routing, or deployment.

## Scope

In scope:

- Add independent display-tool-type, normalized-query-semantics, display-argument-validity, block-shape, factual-value, and prose/safety results.
- Treat a direct display query and an equivalent successful `query_stats` / `search_records` followed by `from_call` as the same query semantics.
- Preserve deterministic exact-trace tests where call plumbing itself is under test, but stop using exact trace equality as the only live display score.
- Add sanitized actual display tool names and normalized argument summaries to CSV evidence.
- Add `core`, `integration`, and `stress` evaluation tiers, defaulting existing untagged entries to `core`, and report tier totals separately.
- Correct the specific under-specified display/date cases authorized in Issue #60 while keeping the corpus at 84 entries.

Out of scope:

- Any static-instruction, tool-description, JSON Schema, model-routing, provider, or application behavior change.
- A new live Sol/Terra run or any prompt candidate.
- PR merge or deployment in this slice without a later explicit decision.
- Persisting raw model/user prose, raw tool arguments, URLs, DSNs, upstream errors, credentials, or secrets.

## Development Checklist

- [ ] Add a strict `EvaluationTier` enum (`core`, `integration`, `stress`) to dataset entries with `core` as the backward-compatible default.
- [ ] Tag capability-degradation cases `display-013` through `display-016` as `integration`; tag synthetic ambiguity/instruction-conflict cases `en-ambiguous-008`, `en-ambiguous-009`, and `display-017` as `stress`; leave ordinary behavior cases as `core`.
- [ ] Replace the current exact-trace-only display score with separate counts for:
  - ordered `show_*` tool types;
  - normalized query semantics;
  - delivered display-call argument validity;
  - rendered block shape;
  - rendered factual values;
  - prose safety/style.
- [ ] Build one canonical display-intent representation from both expected and actual calls. Normalize nested `filters` versus flat display filters, resolve synthetic IDs, and dereference only an earlier successful matching `query_stats` / `search_records` call.
- [ ] Make canonical intent ignore transport path (`query` versus equivalent `from_call`) but retain behaviorally material fields: display tool, measure, kinds, period, grouping, filters, text/limit, demo scene, and account identity.
- [ ] Keep non-equivalent sources distinct: wrong query kind, failed/later/missing call reference, wrong period/group/filter/limit/demo/account, or a reference to an incompatible source tool must fail query semantics.
- [ ] Extend the provider audit with an ordered, bounded, sanitized display-call record containing only tool name, validity, and allowlisted normalized display/query fields. Never retain raw arguments; non-display calls retain counts only.
- [ ] Export CSV columns for tier, expected/actual display tool names, sanitized normalized intent summaries, tool-type score, query-semantic score, and display-argument-validity score. Keep existing block/value/prose columns and replace the overloaded reason with layer-specific reasons.
- [ ] Add overall and per-tier summary rows for hard pass count and each new display layer. Preserve the existing business metrics and question metrics.
- [ ] Revise cases without changing the 84-entry count:
  - `display-002`: score direct and `from_call` metric-query paths as semantically equivalent;
  - `display-006`: state the exact six calendar months in the input;
  - `display-008`: explicitly request the metric-card path and no-data fallback;
  - `display-009`: explicitly name metric cards, breakdown, and bar chart;
  - `display-018`: move intentional invalid-call fallback to deterministic fault injection and replace the live entry with a natural, explicitly dated bar-chart comparison.
- [ ] Update eval README/schema documentation so future cases declare whether they test user behavior, integration fallback, or stress behavior and do not pre-register an arbitrary equivalent call path.

## Test Checklist

- [ ] Dataset tests reject unknown tier values and prove omitted tier defaults to `core`; the corpus remains exactly 84 entries.
- [ ] Canonicalization table covers direct query and `from_call` equivalence for metrics and records, nested/flat filters, synthetic ID substitution, demo sources, and account cards.
- [ ] Negative controls independently mutate only the display tool name, period, grouping, filter, limit, demo scene, source-call compatibility/order/status, validity flag, block type, and value; each mutation turns red only in the intended layer(s).
- [ ] A direct query and an equivalent source-query path both pass type/query semantics; an exact-trace plumbing test still distinguishes them where explicitly required.
- [ ] Invalid JSON, unknown tool, invalid schema, and valid-but-business-rejected calls produce bounded sanitized evidence without raw arguments or error prose.
- [ ] `display-018` invalid-call fallback is retained as deterministic fault-injection coverage and is no longer dependent on a live model deliberately making a bad call.
- [ ] Result and summary CSV RFC 4180 tests cover all new columns, tier rows, empty denominators, stable ordering, and escaping.
- [ ] Secret/raw-content negative tests inject URL, DSN, bearer token, note text, and upstream error text into rejected calls and prove none can enter the allowlisted CSV evidence.
- [ ] Deterministic PostgreSQL Mock evaluation remains 84/84 on the revised corpus.
- [ ] Existing scoring, CLI, negative-control, live-feature compile-only, and synthetic credential tests remain green.
- [ ] Full x86 build-host gates pass: format, workspace/live checks, clippy, complete nextest, deny, audit, admin dependency boundary, rules, entities, and OpenAPI checks.

## Assumptions

- [ ] Every valid executed tool call is persisted in journal order with call ID, tool name, and typed arguments; guaranteed by the existing runtime journal.
- [ ] `from_call` may only reuse a successful earlier compatible query; guaranteed at runtime and revalidated by canonicalization tests rather than assumed from position alone.
- [ ] The provider audit observes invalid calls that never reach the journal; guaranteed by `AuditedProvider`, which must store only bounded allowlisted summaries.
- [ ] Display-query semantics can be represented without result values or prose because the server owns query execution and rendered facts; guaranteed by the display tool contracts.
- [ ] UUIDs in eval are synthetic but unstable across runs; CSV summaries therefore use stable aliases/redacted identity slots rather than raw UUIDs.
- [ ] Existing result consumers are internal and can accept additive/replaced display columns in this pre-release evaluator; validate repository consumers before changing the header.
- [ ] This revision establishes a new committed baseline. Scores from the old exact-trace evaluator are historical and must not be compared as if the metric definition were unchanged.

## Acceptance Checklist

- [ ] A failed row states whether the chart type, query meaning, argument validity, final block, factual value, or prose contract failed.
- [ ] `display-002` passes with either equivalent query path, while a wrong month, grouping, filter, or display type fails the correct independent layer.
- [ ] The five corrected live inputs are natural, uniquely specified for what they score, and contain no hidden requirement to make an invalid call.
- [ ] Core, integration, and stress results are separately visible; the overall total remains available but is not the sole decision signal.
- [ ] CSV evidence is sufficient for failure diagnosis and contains no raw prose or sensitive material.
- [ ] Independent plan and code review find no P0/P1/P2 issue.
- [ ] All offline gates and Mock 84/84 pass.
- [ ] No prompt/tool-schema change, live model run, model switch, merge, or deployment occurs in this slice.
