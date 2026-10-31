# Dev Plan: genUI S3 breakdown and category-series charts (#51)

## Summary

Implement genUI v2 S3 across the Rust server and Flutter client. Jiabu will expose server-owned `show_breakdown` and `show_bar_chart` display tools, map them to ChatWeave's merged `breakdown` and `category_series` blocks, and render both with Jiabu-specific notebook-style overrides without adding a chart dependency.

## Scope

In scope:

- Pin all server and client ChatWeave references to merged commit `acd253a` and update generated/locked dependency state.
- Register the two display tools with direct query, same-run `query_stats` reuse, and explicit fixed demos.
- Enforce the breakdown and category-series suitability, ordering, merging, naming, formatting, and point-count rules from issue #51.
- Extend the prompt capability inventory and three-section descriptions while preserving registry-derived strict/schema guards.
- Add discriminated display output branches and defensive chat-block mapping for the two ChatWeave built-ins.
- Register Jiabu Flutter overrides with notebook visuals, table toggles, skeletons, accessibility semantics, and approved golden coverage.
- Verify server and client suites only on `jiabu-build`, review all changed goldens, and attach visual comparisons to the PR.

Out of scope:

- Account cards, account-filtered history, and navigation (S4).
- Client-capability parsing or server-side downgrade (S5).
- Live SIWC display evaluation and prompt scoring (S6).
- Changes to ChatWeave's generic built-in renderers or their follow-up issue.
- Setup/document-card components, deployment, or a new chart package.

## Development Checklist

### Dependency and registry

- [ ] Update every Rust and Dart ChatWeave revision from the old pins to `acd253a`; regenerate lockfiles through the normal tools.
- [ ] Confirm the client block registry advertises `breakdown:1` and `category_series:1` after override registration.
- [ ] Keep prompt construction and server tool registration independent of client capability headers.

### Server display tools

- [ ] Register agent-only read tools `show_breakdown` and `show_bar_chart` using the existing strict-compatible source contract.
- [ ] For each tool, support direct query, successful same-run `query_stats` reuse, and only its approved fixed demo after explicit user request.
- [ ] Resolve purpose/account/member/tag IDs to names through the existing server query path; never expose IDs as labels.
- [ ] Add explicit discriminated output payloads for breakdown and category series rather than overloading metric/trend fields.
- [ ] Keep fallbacks complete enough to preserve all material values while bounded by ChatWeave limits.

### Breakdown rules

- [ ] Require grouping by purpose/account/member/tag and reject month.
- [ ] Reject tag results when the query reports overlapping groups.
- [ ] Drop zero groups, reject negative groups, return `no_data` for no non-zero groups, and reject a single non-zero group.
- [ ] Assert that source groups and emitted parts preserve the exact query total.
- [ ] Sort descending; merge every part below 3% plus overflow beyond the five largest named parts into one `其他（N 项）` part.
- [ ] Emit at most six parts and set `mergedCount` only when two or more source groups were merged.
- [ ] Preserve minor-unit money for `sum` and integer semantics for `count`; unsuitable data returns field/rule-only guidance, never a fabricated chart.

### Category-series rules

- [ ] Require grouping by month/purpose/account/member/tag.
- [ ] For month: accept 2–12 calendar months, fill missing months with zero, and preserve chronological order.
- [ ] For non-month: sort descending, keep the first 11 groups, and merge overflow into a final `其他（N 项）` point.
- [ ] Preserve signed values and allow overlapping tag groups because the chart compares values rather than claiming a whole.
- [ ] Return `no_data` for no usable points and reject a one-point result as better expressed by metrics/plain text.
- [ ] Emit at most 12 points with exact currency/minor-unit or integer formatting.
- [ ] Let the client render protocol-provided optional reference/assessment fields without synthesizing them on the server in S3.

### Prompt, schemas, and chat mapping

- [ ] Extend `DISPLAY_TOOLS` to exactly the five registered display tools.
- [ ] Give both new descriptions exactly one `何时用` / `何时别用` / schema-valid `例` section.
- [ ] Accept the intentional parameter-schema and wire strict-flag snapshots; retain negative alignment/strict controls.
- [ ] Map only the matching discriminated payload to `breakdown` or `category_series`; reject inconsistent branch fields, invalid counts, or malformed values.
- [ ] Run every mapped block through the pinned ChatWeave validator before persistence; protocol failure remains a host-bug fallback, not a model retry.
- [ ] Preserve all existing display tools and automatic write-card mappings unchanged.

### Jiabu client overrides

- [ ] Register explicit overrides for both built-ins through the existing ChatWeave `BlockRegistry` path.
- [ ] Implement breakdown as a level paper card without tape, a `CustomPainter` donut, server-derived center total, token palette, formatted legend, percentages, and table toggle.
- [ ] Implement category series with hand-drawn bars, a visible zero axis, deterministic vertical vs overflow-safe horizontal layout, optional reference line, assessment highlight, and table toggle.
- [ ] Use only `jiabu_design` tokens/current fonts; add no chart dependency, UI literals, or business state in `setState`.
- [ ] Add type-specific pending skeletons.
- [ ] Expose one semantic summary based on the server fallback and exclude decorative painter nodes from accessibility.
- [ ] Keep both renderers usable at 200% text scale and maximum protocol inputs; Jiabu remains light-only.

## Test Checklist

### Server

- [ ] Direct-query, `from_call`, and explicit-demo integration paths pass for both tools; raw `query_stats` still does not auto-render.
- [ ] Breakdown negative controls cover month grouping, overlapping tags, negative values, zero/one usable part, failed/wrong/foreign/mismatched call results, inconsistent totals, and malformed payloads.
- [ ] Breakdown boundaries cover exactly 3%, five/six emitted parts, more than six source groups, stable ties, and correct `mergedCount`.
- [ ] Category-series boundaries cover one, 2/12/13 months, missing-month zero fill, signed values, overlapping tags, 11/12/13 categories, stable ties, and correct overflow merging.
- [ ] Mapper mutations prove branch/field mismatch, point-limit overflow, invalid values, and invalid format combinations are rejected.
- [ ] Prompt inventory, description contract, schema snapshots, and strict compatibility include both new tools and retain their negative controls.
- [ ] Existing three display tools and all ten automatic write cards regress cleanly.

### Client

- [ ] Widget tests cover registry capabilities, parsing, exact money/count formatting, table toggles, semantics, negative values, optional reference, and assessment.
- [ ] Geometry/overflow tests cover long labels, maximum protocol inputs, 200% text, and both supported widths.
- [ ] Golden matrix includes both chart types at 360/100% and 430/200%, long labels, maximum input, chart/table states, and type-specific skeletons.
- [ ] Review generated PNGs visually on the build host and attach before/after comparisons to the PR.

### Full gates

- [ ] On `jiabu-build`, run server fmt, clippy with warnings denied, full nextest workspace, deny, audit, admin-dependency, rules, entities, and OpenAPI checks.
- [ ] On `jiabu-build`, run client pub get/code generation as required, format, fatal analyze, repository rules, root/app/design tests, and golden verification.
- [ ] Run git diff hygiene and confirm no generated/build-host artifacts or real data entered the branch.
- [ ] Independent whole-PR review covers the six crew-playbook areas and returns no unresolved P0/P1; every P2/P3 is fixed or explicitly tracked.

## Assumptions

- [x] ChatWeave commit `acd253a` contains typed Rust/Dart protocol support, neutral default renderers, skeletons, table fallback, and capability declarations for both built-ins. This is guaranteed by merged ChatWeave PR #4 and must be verified after pinning.
- [x] Jiabu server emits at most six breakdown parts although the protocol accepts 12; the client override must still render all 12 because it consumes general valid ChatWeave blocks.
- [x] Jiabu server emits at most 12 category points although the protocol accepts 24; the client override must still render all 24.
- [x] `query_stats` reports whether tag groups may overlap. Breakdown must reject overlap; category-series may display it because it makes no whole/percentage claim.
- [x] Stats totals and values are `i64`, so exact breakdown sum checks and minor-unit money require no floating-point arithmetic.
- [x] Group-name resolution, same-run succeeded-call binding, explicit demo authorization, correction fallback, and telemetry already exist from S1/S2 and should be extended rather than duplicated.
- [x] The long-label horizontal-layout threshold is an implementation decision chosen from measured overflow and golden evidence, not a new product decision.
- [x] Jiabu is light-only, so S3 adds no dark-theme override goldens even though ChatWeave's neutral renderer supports dark mode.

## Acceptance Checklist

- [ ] Both tools are callable, strict-compatible, prompt-guided, and render only server-owned results.
- [ ] Breakdown never represents overlapping/negative/one-part data as a whole and preserves exact totals through deterministic merging.
- [ ] Category series preserves ordering, signs, missing-month zeros, and deterministic overflow merging.
- [ ] Mapped blocks validate as ChatWeave `breakdown` / `category_series`; malformed internal payloads degrade safely as host bugs.
- [ ] Jiabu overrides match the approved notebook design, remain readable at 200% text and maximum inputs, toggle to accessible tables, and add no chart dependency.
- [ ] Existing display/write behavior has no regression.
- [ ] Server and client full build-host gates, reviewed goldens/screenshots, independent review, and GitHub CI all pass.
- [ ] The PR contains no S4–S6 or deployment changes.
