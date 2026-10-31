# Dev Plan: Tighten Prompt Rules from Live genUI Evaluation (#59)

## Summary

Make one concise prompt-only adjustment for the three behavior clusters observed in the committed Sol/Terra baselines: display selection/fallback, missing-information clarification, and server-owned confirmation. Keep the configured default unchanged during this slice and validate both models against the unchanged 84-case corpus.

## Scope

In scope:

- Extend the static agent instructions with explicit rules for display intent, server-owned capability downgrade, required-information clarification, and guarded business-tool confirmation.
- Add deterministic prompt-contract tests for each rule and a negative control that prevents telling the model to ask for confirmation itself.
- Run the existing offline gates and one complete live comparison per model against the committed Sol 73/84 and Terra 70/84 baselines.
- Treat Sol/Terra as the standing paired comparison for prompt changes and report whether Terra is ready to replace Sol.
- Commit only allowlisted, reviewed live artifacts if the candidate satisfies the acceptance boundary.

Out of scope:

- Tool schema or description changes, business logic, evaluator expectations, dataset edits, model routing, UI behavior, or deployment.
- Case-by-case prompt edits after seeing the candidate live score.
- A claim that one stochastic run proves a general model-quality improvement.

## Development Checklist

- [ ] Add a short `BEHAVIOR_RULES` section to `static_instructions` without duplicating the detailed display-tool descriptions.
- [ ] State that explicit text-only requests use factual read/query tools and no display tool.
- [ ] State that otherwise the semantically correct display tool is chosen even when the server later downgrades its block, and required facts must survive text fallback.
- [ ] Require `ask_user` before acting when amount or the original date/time-zone reference is missing.
- [ ] Require direct use of guarded update/void/archive tools so the server owns confirmation; forbid substituting `ask_user` for confirmation.
- [ ] Add prompt-contract tests and a focused negative assertion.

## Test Checklist

- [ ] Prompt unit tests assert every new invariant and the confirmation negative control.
- [ ] `cargo fmt --check`, workspace check, live eval compile, clippy, full nextest, deny, audit, dependency/rules/entities/OpenAPI gates pass on `jiabu-build`.
- [ ] Existing 84-case PostgreSQL Mock evaluation remains 84/84.
- [ ] Complete live SIWC evaluation runs once each on `gpt-6.1-sol` and `gpt-6.1-terra`, using the unchanged corpus and evaluator.
- [ ] Recompute both report totals independently, review every hard failure, and scan artifacts for secrets/raw prose/URLs.

## Assumptions

- [ ] `static_instructions` is frozen into each new run and is the only prompt surface changed by this slice; guaranteed by the current runtime composition path.
- [ ] Guarded tools already produce confirmation UI when called; guaranteed by the tool registry and runtime tests, so the prompt must not manufacture confirmation itself.
- [ ] Capability downgrade and text fallback are server-owned; guaranteed by the current capability gate/runtime, so the model should select tools by semantic intent.
- [ ] The committed Sol 73/84 and Terra 70/84 runs are the comparison baselines; guaranteed by the reviewed artifacts on master.
- [ ] A single live run is stochastic; therefore acceptance uses a non-regression boundary and failure review, not a claim of statistical significance.

## Acceptance Checklist

- [ ] Diff is limited to static prompt text, prompt-contract tests, this temporary plan, and (only after acceptance) reviewed live result artifacts.
- [ ] Prompt rules are concise, non-conflicting, and do not encode fixture-specific wording or values.
- [ ] All offline gates pass and Mock remains 84/84.
- [ ] Candidate Sol is at least 73/84 and candidate Terra is at least 70/84 overall; neither has a new safety/confirmation regression, and both failure distributions are reviewed rather than score-chased.
- [ ] The acceptance report compares both models and gives an explicit recommendation on whether Terra is ready to become the default; this slice does not silently change routing.
- [ ] Completed plan is removed before merge.
- [ ] CI is green; no deployment is performed.
