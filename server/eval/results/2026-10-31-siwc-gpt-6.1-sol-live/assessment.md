# SIWC live evaluation assessment — 2026-10-31

## Run identity

- Scored run: 2026-10-31 21:54:40–22:14:14 +08:00 (about 19m34s).
- Corpus: 84 wholly fictional scenarios: the unchanged 64-case v1 corpus plus 20 v2 display scenarios.
- Route: provider `chatgpt`, adapter `siwc`, subscription billing, model `gpt-6.1-sol`, structured mode `tool_call`, vision enabled.
- Execution path: the real `RunService`, runtime worker, `ToolRegistry`, PostgreSQL 18 scratch databases, persisted ChatWeave checkpoints, and the configured SIWC provider.
- Output boundary: `results.csv` and `summary.csv` contain no connection URL, credential, request body, upstream error body, or raw model prose.

No score threshold was chosen after the run. Hard requirements are the classifications committed in the corpus before live execution.

## Summary

| Measure | Result |
| --- | ---: |
| Hard-pass scenarios | 73/84 |
| Hard failures | 11 |
| Display hard-pass scenarios | 12/20 |
| Display tool sequence accuracy | 12/20 |
| Persisted display block accuracy | 15/18 |
| Display fact-value accuracy | 58/69 |
| Tool argument validity | 98/99 |
| Amount precision | 41/42 |
| Date accuracy | 41/42 |
| Category accuracy | 30/31 |
| Question precision / recall | 22/24 / 22/24 |
| Ambiguous-date recall | 18/20 |
| Latency P50 / P95 | 12,992 ms / 24,390 ms |
| Provider calls | 152 total: 150 succeeded, 2 failed |

The 11 hard failures split into eight display cases, two ambiguous-date cases, and one confirmation case. All 20 display scenarios passed the Mermaid, ASCII-chart, oversized-table, sentence-count, and declared numeric-restatement prose checks; there was no separate soft prose finding.

Cost is intentionally left unknown: the source configuration had no `ai_prices` row for `gpt-6.1-sol`. Consequently all 84 scenario costs and the mean cost are blank rather than estimated.

## Display results by scenario

`Tool`, `block`, and `value` show correct/expected counts from persisted observations.

| Scenario | Hard pass | Tool | Block | Value | Prose | Finding |
| --- | --- | ---: | ---: | ---: | --- | --- |
| display-001 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-002 | no | 0/1 | 1/1 | 3/3 | pass | Wrong display tool; persisted component and facts were otherwise correct. |
| display-003 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-004 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-005 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-006 | no | 0/1 | 0/1 | 1/3 | pass | Asked a question instead of rendering the requested six-month bar chart. |
| display-007 | yes | 1/1 | 1/1 | 4/4 | pass | — |
| display-008 | no | 0/1 | 0/0 | 0/1 | pass | Did not make the required no-data query and omitted the declared no-data fallback fact. |
| display-009 | no | 0/1 | 1/3 | 6/10 | pass | Demo sequence was incomplete and included one invalid call/business error. |
| display-010 | yes | 1/1 | 1/1 | 4/4 | pass | — |
| display-011 | yes | 1/1 | 1/1 | 4/4 | pass | — |
| display-012 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-013 | yes | 1/1 | 1/1 | 5/5 | pass | — |
| display-014 | yes | 1/1 | 1/1 | 5/5 | pass | — |
| display-015 | yes | 1/1 | 1/1 | 5/5 | pass | — |
| display-016 | no | 0/1 | 0/0 | 0/2 | pass | Text-only capability downgrade omitted both required server-owned facts. |
| display-017 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-018 | no | 0/1 | 0/0 | 0/1 | pass | Did not exercise the declared invalid-display retry and plain-text fallback path. |
| display-019 | no | 0/1 | 0/0 | 0/1 | pass | Ignored the explicit text-only request and missed the required exact total in fallback text. |
| display-020 | no | 0/1 | 1/1 | 3/3 | pass | Correct bar-chart block and facts came from the wrong display-tool sequence. |

## Non-display hard failures

| Scenario | Expected | Observed | Review |
| --- | --- | --- | --- |
| en-ambiguous-006 | Ask which month defines “month end” | Run failed | No record was credited, but the required clarification was not persisted. |
| en-ambiguous-009 | Ask for the original local date/time zone | Run failed | No record was credited, but the required clarification was not persisted. |
| zh-confirm-002 | Show a matching void confirmation, then void after confirmation | Paused on a question | The intended confirmation flow was not reached and the target record remained unmatched. |

These are model/prompt behavior findings, not evaluator infrastructure failures. Issue #57 explicitly keeps score-driven prompt or product changes out of scope; genuine behavior fixes should be triaged separately from this evidence-only slice.

## Infrastructure and verification boundaries

- The scored run completed all 84 scenarios and produced no infrastructure error.
- Before the scored run, an unscored environment preflight was stopped after one timeout exposed a missing build-host proxy. Its row had `calls_json=[]` and blank cost, so it completed no provider call and is excluded from these artifacts.
- The evaluator retained only allowlisted call metering fields. A content/credential scan of the committed directory found no URL, database DSN, bearer token, API key, password, or OAuth token marker.
- Scratch databases held ledger, journal, checkpoint, and metering data and were disposable per scenario. The source database was used only for non-secret provider/model/price configuration and the existing credential manager path.
- This is one stochastic live run of one configured model route, not a claim about all prompts, models, or future runs.
