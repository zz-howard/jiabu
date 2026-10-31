# Dev Plan: genUI S6 display evaluations and live SIWC report (#57)

## Summary

Extend the existing end-to-end `ai-eval` harness with a versioned display expectation format and roughly 20 fictional genUI scenarios. The evaluator will inspect persisted ChatWeave blocks and final Markdown, compare display values with explicit dataset ground truth derived from seeded records, exercise downgrade paths with frozen client capabilities, and produce a secrets-safe live SIWC report.

## Scope

In scope:

- Mixed v1/v2 evaluation entries: the existing 64 v1 cases remain unchanged; v2 adds optional display and capability expectations.
- All six display tools and their persisted output blocks.
- Positive, negative, fallback, demo, no-data, bilingual, and unsupported-client scenarios.
- Deterministic mock scripts, scorer metrics, focused negative controls, CSV/report output, and one complete live SIWC run.
- Only fictional ledger data and non-secret provider/model identifiers in committed artifacts.

Out of scope:

- Prompt/product tuning in response to the observed live score.
- New HTTP APIs, production telemetry changes, deployment, or release.
- Client visual changes or new goldens.

## Development Checklist

- [ ] Add a v2 dataset form while continuing to accept all existing v1 entries unchanged.
- [ ] Add typed client capability fixtures; default to the current Jiabu capability set and allow an explicit restricted set for downgrade cases.
- [ ] Add typed display expectations covering the exact ordered display-tool and persisted-block sequences, explicit canonical labels and integer/decimal values, account aliases, demo marker, fallback requirement, prose sentence limit, and forbidden Markdown/ASCII patterns. Extra display calls or blocks must fail rather than being ignored.
- [ ] Validate v2 cross-field rules: display expectations require `no_write`, aliases must resolve, demo blocks require explicit demo source, unsupported blocks require a fallback expectation, and safety/numeric assertions declare their hard/soft classification before live execution.
- [ ] Seed every scenario only through the existing `ToolRegistry`; do not add direct database fixtures for ledger facts.
- [ ] Extend mock script generation to issue the expected query/display calls, including `from_call`, validation retry, and fallback sequences.
- [ ] Submit scenarios with `start_at_with_capabilities` so the frozen run snapshot uses the dataset's declared capabilities.
- [ ] Extend observations with the final persisted ChatWeave checkpoint, display tool calls/results, and fallback Markdown. Do not retain raw model prose in committed live artifacts.
- [ ] Normalize each supported block into a small semantic view and compare it to explicit dataset ground truth; avoid deriving expected values through the production block mapper. For `x-jiabu.account_card`, verify the resolved account identity/name in the block and the balance snapshot in server-owned fallback text because the block intentionally carries no balance.
- [ ] Add prose guards for Mermaid fences, three or more consecutive block-chart lines, and Markdown tables over five rows.
- [ ] Add display metrics/reasons to `results.csv` and aggregate counts/rates to `summary.csv` without changing the meaning of existing record metrics. A predeclared per-case `display.hard` flag participates in process exit status; component/style preferences remain soft.
- [ ] Add about 20 cases covering the eight approved examples plus records, trend, account-card routing data, English prompts, capability downgrade, duplicate-display avoidance, invalid-display retry, and server-owned Markdown fallback.
- [ ] Update the evaluator README with v2 format, hard/soft classification, corpus counts, live command, and report boundaries.
- [ ] After offline acceptance, run the full live SIWC corpus once and commit a concise assessment alongside CSV output.

## Test Checklist

- [ ] Dataset parser rejects unknown v2 fields, duplicate aliases, invalid block/tool names, inconsistent demo/fallback/capability declarations, floating numeric ground truth, and display expectations on incompatible behavior.
- [ ] Dataset parser accepts the untouched v1 corpus and the mixed v1/v2 corpus.
- [ ] Existing 64-case mock suite retains its prior behavior and record metrics.
- [ ] New display mock corpus passes through real PostgreSQL 18, runtime worker, ToolRegistry, checkpoint persistence, and scorer.
- [ ] Negative controls independently mutate expected block type, one numeric value, demo marker, capability set/fallback, and each prose guard; every mutation must fail the intended assertion.
- [ ] A duplicate display or extra chart is not ignored by matching.
- [ ] No-data never passes by substituting demo content.
- [ ] Restricted capabilities produce only server-owned Markdown or the exact declared lower block type (`breakdown` to `metric_group`, `category_series` to `dataset`, account card to `metric` where applicable); unsupported blocks never persist.
- [ ] Live feature compiles and live library tests remain network-free.
- [ ] Full server gate passes on `jiabu-build`: format, workspace check, live compile/check, clippy with warnings denied, PostgreSQL 18 nextest, deny, audit, management dependency boundary, transaction rules, generated entities, and OpenAPI snapshot checks.
- [ ] Live output contains no credential, connection URL, raw upstream error, raw request, or model prose.

## Assumptions

- [ ] The persisted checkpoint is the user-visible protocol truth; journal tool calls alone are insufficient. Guaranteed by the current ChatWeave delivery path and verified in agent integration tests.
- [ ] Integer minor units and explicit decimal strings are sufficient ground truth for money/ratio display assertions; floating-point YAML remains forbidden. Needs validation in the v2 parser and block normalizer.
- [ ] Account balances and query results can be deterministically produced from seeded records at the scenario's frozen `today`. Guaranteed by the domain/query tools; verify with focused fixtures.
- [ ] `start_at_with_capabilities` freezes the declared capabilities into the run before execution. Guaranteed by S5 and covered again by a downgrade negative control.
- [ ] Existing v1 results and summary columns are stable consumers. Preserve all current columns and append new display columns only.
- [ ] The existing configured SIWC source database and disposable PG18 build cluster remain available for the final live run. Validate immediately before the live phase; an infrastructure failure is reported separately and is not scored as model behavior.

## Acceptance Checklist

- [ ] Issue #57 required scenarios and all six display tools are represented.
- [ ] Existing v1 corpus remains semantically unchanged.
- [ ] Display block choice, content, demo/fallback behavior, and prose guards are machine-checked from persisted output.
- [ ] Safety and factual-integrity assertions are predeclared hard requirements; model-style preferences remain separately reported soft findings.
- [ ] All focused mutations are killed and restored.
- [ ] Complete local/build-host gates pass before push.
- [ ] Independent whole-change review reports no P0/P1/P2 findings.
- [ ] GitHub client/server CI is green.
- [ ] Live SIWC results and assessment state exact corpus/model/run coverage, all failures, and verification boundaries without exposing sensitive data.
- [ ] No deployment is performed.
