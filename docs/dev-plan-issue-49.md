# Dev Plan: Teach the model when to use display tools (#49)

## Summary

Complete genUI v2 slice S2 by giving the model a concise, test-guarded catalogue of the display tools that are actually registered, and by making structured query output an explicit model choice through those tools. Existing write-result cards remain automatic, while the existing document-metric chart path moves behind `show_trend.from_call` so no user-visible capability is lost.

## Scope

In scope:

- Add a stable `UI` section to the static agent instructions. It lists exactly the registered display tools (`show_metrics`, `show_trend`, and `show_records`) and states the shared source, brevity, demo, and prohibited-output rules from issue #49.
- Keep each display-tool description in the approved `何时用` / `何时别用` / `例` structure, including one concrete argument example that validates against that tool's schema.
- Add registry-derived guards so a future display tool cannot be registered without prompt guidance, a structured description, a valid example, a parameter-schema snapshot, and strict-mode compatibility.
- Stop producing blocks automatically for read/query tools, including `query_balance`, `query_stats`, `search_records`, `document_metric_series`, and `list_accounts`.
- Continue producing automatic cards/blocks for supported write tools.
- Let `show_trend.from_call` adapt either a successful monthly `query_stats` result or a successful `document_metric_series` result from the same run. The latter keeps its fractional `f64` values, dates, metric label, and optional non-currency unit; the model supplies no display numbers.
- Add focused unit and PostgreSQL-backed agent regressions for the prompt/registry contract, rendering boundary, and both `show_trend.from_call` source types.

Out of scope:

- Registering or advertising `show_breakdown`, `show_bar_chart`, or `show_account_card`; those belong to S3/S4.
- Client rendering or Jiabu theme overrides for the future chart/account-card blocks.
- Client capability negotiation or downgrade behavior (S5).
- Live-model evaluation and the S6 evaluation set.
- Changes to retry limits, display telemetry, or the S1 validation framework.
- Deployment.

## Development Checklist

- [ ] Define the concise static `UI` instruction section with one machine-checkable capability-list line and the approved shared rules: server/tool-owned numbers, one-to-two-sentence conclusions without repeating figures, prefer plain text when clearer, demo only on explicit request, and no Mermaid, character/ASCII charts, HTML, code-block charts, or Markdown tables over five rows.
- [ ] Derive the display-tool inventory in tests from the registry via `is_display_tool`; compare it exactly with the prompt capability list so missing and stale prompt entries both fail.
- [ ] Guard every registered display-tool description for all three required sections and validate its concrete JSON example with the registered tool schema.
- [ ] Keep the existing registry-wide parameter-schema and wire strict-flag snapshots as the single snapshot source; add a display-subset assertion that every registered display tool is strict-compatible.
- [ ] Refactor automatic block dispatch so only explicit display tools and supported local writes can render structured blocks; ordinary read/query results remain tool results for the model but do not render blocks.
- [ ] Remove obsolete read/query mapping branches rather than leaving a second dormant rendering policy in `chat::blocks`; retain the supported write-card mappings.
- [ ] Extend `show_trend.from_call` lookup with an explicit allowlist for `query_stats` and `document_metric_series`, while preserving same-run, succeeded-call, matching-journal-result, and malformed-payload rejection.
- [ ] Replace the trend output's ledger-only assumptions with an explicitly discriminated internal trend payload: one branch retains ledger minor-unit/count points and currency/measure semantics; the other carries document measurement points as `date + f64` with an optional unit. Keep metrics and records payloads unchanged, and reject inconsistent branch/field combinations in the chat mapper.
- [ ] Adapt `document_metric_series` deterministically into the measurement branch: use server-returned dates/values/unit/metric, preserve point order and fractional/zero/negative values, return `no_data` for no usable points, reject more than ChatWeave's 500-point maximum instead of silently truncating, and never accept model-supplied points.
- [ ] Update the `show_trend` description/example guidance so the model knows that a successful `document_metric_series` call can be reused.
- [ ] Keep the agent tool list independent of client capability headers; do not branch prompt construction or tool registration on client block support.

## Test Checklist

- [ ] Prompt unit test: the static instructions contain the exact three-tool capability list and every approved shared/prohibited-output rule.
- [ ] Inventory negative control: a synthetic mismatch between the registry-derived display names and parsed prompt names fails the comparison helper; the real registry and prompt pass.
- [ ] Description negative controls: omit each required heading in turn and use malformed or schema-invalid example JSON; each mutation is rejected, while all real descriptions pass.
- [ ] Schema tests: the existing registry-wide snapshots continue to cover every display tool; the display subset is explicitly strict-compatible, so adding a non-strict display tool or changing a schema without accepting its existing snapshot fails.
- [ ] Rendering-boundary integration test: table-driven coverage proves each formerly automatic populated read (`query_stats`, `query_balance`, `search_records`, `document_metric_series`, and `list_accounts`) produces no block at either executor dispatch path, while its tool result is still returned to the next model turn.
- [ ] Write regression: table-driven coverage proves every existing mapped write still renders: record create/update/void/restore, document create/update/void/restore, and account create/update. This explicitly protects the mixed account mapping while `list_accounts` is removed.
- [ ] Ledger trend regression: `show_trend.from_call` still accepts a successful monthly `query_stats` call and still enforces the two-to-24-month rules.
- [ ] Document trend integration: a successful `document_metric_series` call with real stored points can be followed by `show_trend.from_call`, producing one validated `time_series` block with the same dates, fractional values (including `62.5`), metric, and optional unit.
- [ ] Document trend value/fallback coverage: unitless metrics omit the unit rather than becoming currency; fractional, zero, and negative values survive exactly; fallback text is readable and exact; ledger money/count trend output remains unchanged.
- [ ] Document trend negative controls: reject a failed call, wrong tool, foreign/unknown call id, malformed result, and more than 500 points; an empty series returns `no_data` without emitting a component.
- [ ] Run formatting, clippy with warnings denied, the full server test suite, dependency/security checks, schema/OpenAPI checks, generated-entity checks, and diff hygiene on `jiabu-build`; do not compile or test on the local host.

## Assumptions

- [x] Display tools are discoverable as registered agent tools for which `jiabu_tools::is_display_tool(name)` is true. This is guaranteed by the current registry boundary and will be checked against the real built-in registry.
- [x] The registered display-tool set is fixed for a request and does not depend on client capability headers. This is the approved cacheability decision and is preserved by keeping the prompt and tool registry capability-independent.
- [x] A `from_call` reference is valid only for a succeeded call in the same run with a matching journaled tool result. This is guaranteed by the S1 lookup path and remains mandatory for both accepted trend sources.
- [x] `document_metric_series` values, dates, metric name, and unit are produced by the server, not by the model. This is guaranteed by its typed query/result contract; S2 only adapts that result into a display output.
- [x] `document_metric_series.points` are returned in deterministic event-date order, with incompatible-unit observations excluded by the document query. This is guaranteed by the database query; the adapter must preserve the returned order and selected unit rather than reinterpret them.
- [x] Document metric values are arbitrary `f64` measurements and the unit is optional; they are not ledger minor units or counts. This is guaranteed by `MetricResult`, so the display output and mapper must keep them on a separate discriminated branch rather than coercing them into `DisplayItem.value`.
- [x] Removing automatic read blocks does not remove the underlying tool result from the model's next turn. This is guaranteed by the executor's journal/tool-result path and will be verified by integration test.
- [x] Existing supported write cards are identified by explicit mappings, not by treating every write output as displayable. This is guaranteed by `map_tool_result`; unmapped writes continue to return no block.
- [x] A display tool may be added in S3/S4 only together with prompt guidance, the three description sections, a valid example, a strict-compatible schema, and an accepted snapshot. The new registry-derived guards make this a CI-enforced requirement.

## Acceptance Checklist

- [ ] The static prompt advertises exactly the three currently registered display tools and contains all approved UI rules and prohibitions.
- [ ] Every registered display tool has the three required description sections and a schema-valid concrete example.
- [ ] Every registered display schema is snapshot-covered and strict-compatible.
- [ ] Read/query tools no longer auto-render blocks, while their results remain available to the model.
- [ ] Existing supported write-result cards/blocks render exactly as before.
- [ ] A successful `document_metric_series` result is explicitly renderable through `show_trend.from_call` without model-supplied dates or numbers, without losing fractional values, and without treating its optional unit as currency.
- [ ] Adding a display tool without updating prompt guidance, description structure, strict compatibility, and snapshots fails tests.
- [ ] Full build-host gates pass on `jiabu-build`, GitHub CI is green, and the PR contains no S3-S6 or deployment changes.
