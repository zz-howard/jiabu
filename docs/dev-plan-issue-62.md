# Dev Plan: Human-Realistic Display Evaluation (#62)

## Summary

Revise the 20 display cases so core prompts resemble how people actually ask for information, and score any declared presentation that is semantically suitable for the request. Query meaning, factual values, safety, no-write behavior, and capability compatibility remain hard requirements; a single component type is hard only when the user explicitly asks for that form or the request requires a unique interaction.

This evaluator correction is a prerequisite for further Issue #59 prompt/schema experiments. The experiment-lab implementation stays paused until this plan is reviewed, implemented, and its revised baseline is shown to Howard.

## Scope

In scope:

- Audit all 20 display prompts and classify each as core human use, capability integration, or protocol/safety stress.
- Rewrite core and integration prompts in user language. Client block support belongs only in `client_capabilities`, not in the user's words.
- Add an explicit list of complete acceptable presentation alternatives to a display expectation. Each alternative owns its expected display/read calls, rendered blocks or factual Markdown fallback, and facts.
- Score every alternative independently and pass the presentation when at least one complete alternative passes. Do not mix the tool from one alternative with the block/fallback from another.
- Keep intent correctness hard across all alternatives: normalized query semantics, period/group/filter, successful argument validation, factual labels/values, no write, no invented demo data, capability-compatible output, and prose safety.
- Permit a truthful no-data response with a matching successful read query and factual prose, without forcing a display tool.
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
- required model or server fallback facts.

The existing single exact path is represented as one alternative. Flexible human requests enumerate two or more complete alternatives. The scorer evaluates each alternative against the same observation, selects a passing alternative if one exists, otherwise reports the closest alternative using a deterministic ordering: fewest hard reason classes, then most correct query/fact assertions, then fixture order. Reports expose the declared acceptable tool/block sets and the selected alternative index, never raw user/model prose.

For prose-only alternatives, a successful `query_stats`/`search_records` call with matching normalized semantics is mandatory unless the fact is already server-owned context. A guessed sentence without matching evidence does not pass. A no-data alternative must contain no display block/demo output and must state the expected no-data fact.

Presentation flexibility never weakens tool validation. An alternative is invalid if the chosen call was rejected, returned a business error not declared by the case, used a wrong query, produced wrong facts, emitted an unsupported block, or wrote to the ledger.

## Case Audit and Intended Corrections

| Case | Class | User-language correction | Presentation contract |
|---|---|---|---|
| display-001 | core | “本月的钱主要花在哪些用途上？” | breakdown, bars, or metric group; same purpose query/facts |
| display-002 | core explicit | Keep explicit metric-card request | metric group only; direct and `from_call` query paths equivalent |
| display-003 | core explicit | Keep explicit single metric request | metric only |
| display-004 | core | Keep natural “八月到十月支出趋势” | time-series line or monthly bars; same three-month facts |
| display-005 | core explicit | Keep request for the latest three records | records dataset; a prose list is not accepted because the user asked to list details and three rows fit the component |
| display-006 | core explicit | Keep explicit May–October bar request | monthly bars only |
| display-007 | core interaction | Replace “账户卡” jargon with “看看虚构银行卡余额，并能点进去看流水” | account card; unique clickable interaction makes the form material |
| display-008 | core | Replace fixture instructions with “我 2026 年 10 月花了多少钱？” | no-data factual prose after a matching read, or a metric call that yields the same no-data fallback; no invented component/demo |
| display-009 | stress protocol | Retain explicit three-demo-component request but label it non-representative | exact ordered protocol path; reported only as stress coverage |
| display-010 | core explicit | Keep explicit demo breakdown request | demo breakdown only |
| display-011 | core explicit | Keep explicit demo bar request | demo bars only |
| display-012 | core explicit | Keep explicit English metric-card request | metric group only |
| display-013 | integration | “本月的钱主要花在哪些用途？”; capability metadata remains metric-group-only | suitable request path yielding a supported metric group or truthful server Markdown with the same facts |
| display-014 | integration | “比较本月各用途支出”; capability metadata remains dataset-only | suitable comparison tool yielding dataset downgrade, or truthful server Markdown with the same facts |
| display-015 | integration | “打开虚构银行卡看看余额和流水”; capability metadata remains metric-only | account-card request with metric downgrade and exact balance fact |
| display-016 | integration | “本月各用途花了多少？”; capability metadata remains text-only | suitable grouped query with no component and truthful server Markdown facts |
| display-017 | stress safety | Retain conflicting Mermaid/native-component instruction as an explicit adversarial control | native breakdown only; no Mermaid/ASCII/numeric restatement |
| display-018 | core | “比较一下 2026 年 9 月和 10 月的支出” | monthly bars, line trend, or metric group; same two-month facts |
| display-019 | core explicit | Keep one-line text-only request | no display component, exact factual prose |
| display-020 | core | Remove internal “labels may overlap”; ask “比较本月餐饮和购物支出” | bars or metrics; breakdown is deliberately not accepted because overlapping tags are not parts of one whole |

## Development Checklist

- [ ] Add strict display-alternative data types with `deny_unknown_fields`, bounded alternative/call/block counts, and a requirement that every display case has at least one complete alternative.
- [ ] Keep one-alternative cases behaviorally equivalent to the current exact contract.
- [ ] Refactor display scoring into a pure “score one alternative” function plus deterministic alternative selection; do not duplicate or weaken query/argument/block/value/safety checks.
- [ ] For prose-only alternatives, match normalized successful read-query evidence and required fallback facts; reject guessed prose, demo output, display blocks, failed reads, and wrong periods/groups/filters.
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
- [ ] Prose-only no-data tests require matching successful read evidence, accept truthful no-data text, and reject guessed text, a fabricated zero/demo card, or a display block.
- [ ] Capability tests use natural identical user wording and cover supported downgrade plus truthful Markdown fallback without exposing capability jargon in the prompt.
- [ ] Report tests prove core/integration/stress are separate and sanitized evidence contains alternative IDs/enum names only, with no raw user/model prose, prompts, URLs, DSNs, credentials, or errors.
- [ ] Dataset tests pin the 20-case audit classification and exact corpus count of 84.
- [ ] Deterministic Mock remains 84/84; full x86 server gates and independent review pass.

## Assumptions

- [ ] Multiple visual forms can be semantically correct for the same normalized query and facts. This is Howard's product decision and is encoded only through enumerated alternatives, not scorer inference.
- [ ] Explicit user form requests are meaningful and may remain hard. This is guaranteed by the prompt text and reviewed case classification.
- [ ] Client capability is transport metadata, not something ordinary users should state. The fixture already carries `client_capabilities`; integration prompts must not repeat it.
- [ ] A prose-only answer must still have evidence. The production loop records read tool calls and results, so the evaluator can require a successful normalized read.
- [ ] Stress cases are useful but not representative. Reports keep their hard safety/protocol verdict while preventing them from being described as ordinary human-use selection misses.
- [ ] The current canonical query layer correctly equates direct display queries with successful `query_stats/search_records -> from_call`; this change reuses it rather than inventing a second query normalizer.

## Acceptance Checklist

- [ ] Howard can read the 20-row audit table and see which requests are natural, which explicitly constrain form, and which are isolated protocol/safety controls.
- [ ] Core flexible requests accept all and only the enumerated reasonable presentations while preserving exact query/fact/safety checks.
- [ ] Capability integration prompts contain no client/component implementation instructions and still verify compatible output.
- [ ] A model can no longer lose a core case solely because it chose another declared reasonable presentation.
- [ ] A model cannot gain a pass with a plausible-looking but unsupported, factually wrong, invalid, or unevidenced answer.
- [ ] Mock 84/84, focused negative controls, full x86 gates, and independent review are green.
- [ ] Revised case/scoring contract and deterministic results are shown to Howard before any live rerun or Issue #59 prompt/schema implementation resumes.
- [ ] No production prompt/schema/routing/model/deployment change is included.

