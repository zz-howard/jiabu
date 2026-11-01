# Dev Plan: Human-Realistic Display Evaluation (#62)

## Summary

Revise the 20 display cases so core prompts resemble how people actually ask for information, and score any declared presentation that is semantically suitable for the request. Query meaning, factual values, safety, no-write behavior, and capability compatibility remain hard requirements; a single component type is hard only when the user explicitly asks for that form or the request requires a unique interaction.

This evaluator correction is a prerequisite for further Issue #59 prompt/schema experiments. The experiment-lab implementation stays paused until this plan is reviewed, implemented, and its revised baseline is shown to Howard.

## Scope

In scope:

- Audit all 20 display prompts and classify each as core human use, capability integration, or protocol/safety stress.
- Rewrite core and integration prompts in user language. Client block support belongs only in `client_capabilities`, not in the user's words.
- Add an explicit list of complete acceptable presentation alternatives to a display expectation. Each alternative owns its expected display/read calls, rendered blocks or factual Markdown/prose fallback, and a closed set of typed domain facts.
- Score every alternative independently and pass the presentation when at least one complete alternative passes. Do not mix the tool from one alternative with the block/fallback from another.
- Keep intent correctness hard across all alternatives: normalized query semantics, period/group/filter, successful argument validation, factual labels/values, no write, no invented demo data, capability-compatible output, and prose safety.
- Permit truthful evidence-backed prose, including a natural no-data response, without forcing a display tool. Prose must state the complete declared domain fact set and must not add contradictory or invented facts.
- Report core human-use quality separately from integration and stress outcomes. Integration/stress failures remain hard protocol/safety failures, but are not described as failures of ordinary user chart selection.

Out of scope:

- Production prompt, tool description/schema, display mapping, business logic, routing, model choice, or deployment changes.
- Prompt/schema candidate evaluation or a live rerun before Howard sees the revised case contract and deterministic results.
- Accepting arbitrary output because it “looks plausible.” Every accepted alternative is enumerated in the fixture and must satisfy the same query/fact/safety contract.

## Evaluation Contract

`DisplayExpect` keeps shared behavior and prose constraints and gains one or more strict presentation alternatives. An alternative is a complete coherent path, not independent allowlists:

- expected source/read evidence, when the answer can legitimately be prose-only;
- zero or more display calls, including their normalized query meaning;
- zero or more rendered blocks, with exact labels/values/account/demo assertions;
- required model or server fallback facts as a closed set of typed assertions: aggregate label/value, record-row fields, account balance, or no-data.

The existing single exact path is represented as one alternative. Flexible human requests enumerate every protocol-reachable form that is semantically complete for the intent, including evidence-backed factual prose where it fully answers the request. Semantic suitability is judged consistently across core and integration cases. Capability metadata may filter rich blocks and thereby make a server downgrade reachable, but it must not make that downgraded form semantically suitable only in the integration case. Each flexible case records both semantic exclusions and any suitable form omitted only because the production mapper cannot emit it for that case's declared capabilities.

The scorer evaluates each alternative against the same observation and selects a passing alternative if one exists. When none passes, it reports the closest alternative using a deterministic ordering: fewest failed hard reason classes, then fixture order. It does not compare raw counts of correct assertions across alternatives because different forms have different assertion counts. Reports expose the declared acceptable tool/block sets and the selected alternative index, never raw user/model prose.

For a direct model-prose alternative with zero display calls, a successful `query_stats`, `search_records`, or `query_balance` source call with matching normalized semantics is mandatory. A guessed sentence without matching evidence does not pass. A server-rendered Markdown downgrade instead keeps its display call as the evidence path and must match that call's normalized query/account semantics.

`query_balance` joins the source-call schema as an exact empty-argument read. Its canonical form records the balance query family, while the alternative's typed fact selects the target account alias. Evaluation observations retain a sanitized successful balance-result summary only: currency and sorted `(account_id, balance_minor)` pairs, with no raw errors or prose. The scorer requires the expected account ID to be present in that successful result with the exact expected currency and balance before model prose can satisfy an account-balance fact. Reports expose only fixture aliases and pass/fail reason classes, never raw account IDs or tool results.

The evaluator extracts normalized typed facts from prose and compares them with the alternative's declared closed fact set: every expected aggregate label/value, record row (date/kind/amount and declared account/purpose/note fields), account balance, or no-data assertion must be present. Any extra monetary value or record row, conflicting field/value pair, or contradictory data-presence claim fails. Dates and query labels are parsed in their typed context rather than counted as monetary values. A no-data alternative must contain no display block/demo output, must state the expected no-data fact, and must contain no spending amount or claim that records exist.

Presentation flexibility never weakens tool validation. An alternative is invalid if the chosen call was rejected, returned a business error not declared by the case, used a wrong query, produced wrong facts, emitted an unsupported block, or wrote to the ledger.

## Case Audit and Intended Corrections

| Case | Class | User-language correction | Presentation contract |
|---|---|---|---|
| display-001 | core | “本月的钱主要花在哪些用途上？” | breakdown, bars, metric group, or evidence-backed factual Markdown; same purpose query/facts |
| display-002 | core explicit | Keep explicit metric-card request | metric group only; direct and `from_call` query paths equivalent |
| display-003 | core explicit | Keep explicit single metric request | metric only |
| display-004 | core | Keep natural “八月到十月支出趋势” | time-series line, monthly bars, month metric group, or evidence-backed factual Markdown; same three-month facts |
| display-005 | core content | Keep request for the latest three records | records dataset or evidence-backed Markdown table/numbered list; same `search_records(limit=3)` semantics and three records |
| display-006 | core explicit | Keep explicit May–October bar request | monthly bars only |
| display-007 | core interaction | Replace “账户卡” jargon with “看看虚构银行卡余额，并能点进去看流水” | account card; unique clickable interaction makes the form material |
| display-008 | core | Replace fixture instructions with “我 2026 年 10 月花了多少钱？” | no-data factual prose after a matching read, or a metric call that yields the same no-data fallback; no invented component/demo |
| display-009 | stress protocol | Retain explicit three-demo-component request but label it non-representative | exact ordered protocol path; reported only as stress coverage |
| display-010 | core explicit | Keep explicit demo breakdown request | demo breakdown only |
| display-011 | core explicit | Keep explicit demo bar request | demo bars only |
| display-012 | core explicit | Keep explicit English metric-card request | metric group only |
| display-013 | integration | Same natural request as display-001; capability metadata remains metric-group-plus-Markdown only | the display-001 semantic set filtered to supported metric group or evidence-backed factual Markdown; same facts |
| display-014 | integration | “比较本月各用途支出”; capability metadata remains dataset-plus-Markdown only | aggregate dataset or evidence-backed factual Markdown; same comparison query/facts |
| display-015 | integration | “看看虚构银行卡余额”; capability metadata remains metric-plus-Markdown only | supported balance metric or evidence-backed factual Markdown with the exact balance; clickable account/流水 interaction remains display-007's separate requirement |
| display-016 | integration | “本月各用途花了多少？”; capability metadata remains text-only | suitable grouped query with no component and truthful server Markdown facts |
| display-017 | stress safety | Retain conflicting Mermaid/native-component instruction as an explicit adversarial control | native breakdown only; no Mermaid/ASCII/numeric restatement |
| display-018 | core | “比较一下 2026 年 9 月和 10 月的支出” | monthly bars, line trend, metric group, or evidence-backed factual Markdown; same two-month facts |
| display-019 | core explicit | Keep one-line text-only request | no display component; evidence-backed one-line prose with the exact closed domain fact set |
| display-020 | core | Remove internal “labels may overlap”; ask “比较本月餐饮和购物支出” | bars, metric group, or evidence-backed factual Markdown; breakdown is deliberately not accepted because overlapping tags are not parts of one whole |

### Flexible-Case Completeness Rationale

- `display-001` / `display-013`: unordered purpose composition can be complete as a breakdown, bars, metrics, aggregate rows, or factual prose. A time-series trend, account card, or raw-record list answers a different question. On the full-capability core path, aggregate rows are semantically suitable but not protocol-reachable: `show_bar_chart` maps to its richer `category_series` block whenever that block is supported. In `display-013`, capability filtering makes the metric-group downgrade reachable. Evidence-backed direct prose remains reachable in both cases.
- `display-004`: the user asks for change across ordered months, so line, monthly bars, monthly metrics, aggregate month rows, or factual prose can preserve the sequence and facts. Aggregate rows are semantically suitable but not reachable on the full-capability path because `category_series` wins before the dataset downgrade. Purpose breakdown, account card, and raw-record output do not answer the trend.
- `display-005`: the user constrains which three records and their order, not the component. A records dataset or an evidence-backed table/list is complete; aggregate charts and metrics discard record-level details.
- `display-008`: the ledger has no matching records. Evidence-backed no-data prose is the natural answer; a metric request that reaches the same server-owned no-data fallback is equivalent. A zero-valued/fabricated component is not equivalent to “no records.”
- `display-013`–`display-016`: capability restrictions filter the corresponding natural request's rich block and can expose the production mapper's existing downgrade path. A server-rendered downgrade and direct evidence-backed prose are both acceptable when they preserve the same query and closed fact set; unsupported blocks are not. A downgrade is not accepted merely because it appears in an integration case: its semantic suitability is stated against the same intent as the core case.
- `display-015`: this integration case asks only for balance because its restricted client cannot satisfy the unique clickable-ledger interaction. `display-007` separately keeps “能点进去看流水” as a hard account-card requirement.
- `display-018`: month comparison is complete as bars, a two-point line, monthly metrics, aggregate rows, or factual prose. Aggregate rows are not a core fixture alternative because the full-capability mapper emits `category_series`, not its dataset downgrade. Purpose/tag breakdown, account cards, and raw records answer different questions.
- `display-020`: tag totals may overlap, so bars, metrics, aggregate rows, or factual prose can compare them. Aggregate rows are not reachable on the full-capability path; a parts-of-whole breakdown is misleading and remains excluded.

## Development Checklist

- [ ] Add strict display-alternative data types with `deny_unknown_fields`, bounded alternative/call/block counts, and a requirement that every display case has at least one complete alternative. Permit `query_balance` as a source call only with its exact empty argument object.
- [ ] Keep one-alternative cases behaviorally equivalent to the current exact contract.
- [ ] Refactor display scoring into a pure “score one alternative” function plus deterministic alternative selection; do not duplicate or weaken query/argument/block/value/safety checks.
- [ ] For zero-display-call prose alternatives, match normalized successful `query_stats`, `search_records`, or `query_balance` evidence and an exact closed typed fact set; reject guessed prose, missing facts, extra monetary values/record rows, conflicting fields or label/value pairs, contradictory no-data/data-present claims, demo output, display blocks, failed reads, and wrong periods/groups/filters/account targets.
- [ ] Extend evaluation observation capture with a sanitized successful `query_balance` result summary and canonicalize it without weakening the current `query_stats`/`search_records` paths. Match the alternative's account alias to the returned account ID and require exact currency/balance; do not expose raw IDs/results in reports.
- [ ] Make block fact extraction depend on the selected alternative's expected block kind, so equivalent facts in metric-group, breakdown, bar, and trend forms use the correct protocol shape.
- [ ] Add sanitized result fields for acceptable presentation sets and chosen alternative; retain existing reason classes and report the closest failed alternative when none passes.
- [ ] Rewrite the 20 fixtures according to the audit table without changing their ledger setup facts or total corpus size.
- [ ] Update the Mock fixture generator so each case deterministically uses its first alternative; exact protocol integration tests cover every additional alternative.
- [ ] Update `server/eval/README.md` to explain human intent versus explicit form, complete alternatives, tier interpretation, and prose-only evidence.
- [ ] Do not modify production prompt/tool/schema/router/server behavior in this PR.

## Test Checklist

- [ ] One-alternative regression tests prove current exact selection/query/argument/block/value behavior is unchanged.
- [ ] For each flexible core case, a table-driven test passes every declared alternative and fails an unrelated presentation.
- [ ] Mutation/negative controls independently fail wrong tool family, wrong period, wrong grouping/filter, invalid arguments, failed read/display call, wrong labels/values, unsupported block, invented demo data, unsafe prose, and any ledger write.
- [ ] Alternative coherence test proves tool/query from alternative A cannot pass with block/fallback from alternative B.
- [ ] Alternative-inventory tests pin every flexible case's accepted alternative IDs and verify each path is reachable under that case's frozen client capabilities. For every semantically suitable form omitted only as unreachable, a mapper test proves which richer block wins or which capability downgrade exposes it.
- [ ] Prose-only tests require matching successful read evidence and accept wording variation only when the normalized closed typed fact set matches. Negative controls add every required substring plus an extra invented amount or record row, pair one expected label/date/purpose with a wrong value, combine a no-data statement with a spending amount/data-present claim, omit one expected fact, fabricate a zero/demo card, and add a display block; each must fail.
- [ ] Balance-prose controls require a succeeded `query_balance` result containing the expected target account, currency, and balance. Missing/failed calls, a missing or wrong account ID, wrong balance, wrong currency, and prose that adds another balance fact each fail independently.
- [ ] Capability tests use natural identical user wording and prove that integration alternatives remain semantically consistent with the corresponding core request while reflecting the production mapper's actually reachable rich/downgrade paths; cover supported downgrade plus truthful Markdown fallback without exposing capability jargon in the prompt.
- [ ] Report tests prove core/integration/stress are separate and sanitized evidence contains alternative IDs/enum names only, with no raw user/model prose, prompts, URLs, DSNs, credentials, or errors.
- [ ] Failed-alternative report tests prove closest selection uses failed hard reason-class count and then fixture order, never raw correct-assertion counts.
- [ ] Dataset tests pin the 20-case audit classification and exact corpus count of 84.
- [ ] Deterministic Mock remains 84/84; full x86 server gates and independent review pass.

## Assumptions

- [ ] Multiple visual or evidence-backed prose forms can be semantically correct for the same normalized query and facts. This is Howard's product decision and is encoded through reviewed complete alternatives, not scorer inference.
- [ ] Explicit user form requests are meaningful and may remain hard. This is guaranteed by the prompt text and reviewed case classification.
- [ ] Client capability is transport metadata, not something ordinary users should state. The fixture already carries `client_capabilities`; integration prompts must not repeat it.
- [ ] A prose-only answer must still have evidence. The production loop records read tool calls and results; the evaluator can require a successful normalized read and add a sanitized balance-result projection for `query_balance` without reporting raw tool output.
- [ ] Stress cases are useful but not representative. Reports keep their hard safety/protocol verdict while preventing them from being described as ordinary human-use selection misses.
- [ ] The current canonical query layer correctly equates direct display queries with successful `query_stats/search_records -> from_call`; this change reuses that mechanism and adds a balance family for successful `query_balance` evidence rather than inventing a second normalizer.

## Acceptance Checklist

- [ ] Howard can read the 20-row audit table and see which requests are natural, which explicitly constrain form, and which are isolated protocol/safety controls.
- [ ] Core flexible requests accept all and only the enumerated reasonable presentations while preserving exact query/fact/safety checks.
- [ ] Capability integration prompts contain no client/component implementation instructions and still verify compatible output.
- [ ] A model can no longer lose a core case solely because it chose another declared reasonable presentation.
- [ ] A model cannot gain a pass with a plausible-looking but unsupported, factually wrong, invalid, or unevidenced answer.
- [ ] Mock 84/84, focused negative controls, full x86 gates, and independent review are green.
- [ ] Revised case/scoring contract and deterministic results are shown to Howard before any live rerun or Issue #59 prompt/schema implementation resumes.
- [ ] No production prompt/schema/routing/model/deployment change is included.

