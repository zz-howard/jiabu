# SIWC live evaluation assessment — 2026-10-31

## Run identity

- Scored run: 2026-10-31 22:26–22:40 +08:00 (about 14 minutes).
- Corpus: the same 84 wholly fictional scenarios used for the `gpt-6.1-sol` run: the unchanged 64-case v1 corpus plus 20 v2 display scenarios.
- Route: provider `chatgpt`, adapter `siwc`, subscription billing, model `gpt-6.1-terra`, structured mode `tool_call`, vision enabled.
- Execution path: the real `RunService`, runtime worker, `ToolRegistry`, PostgreSQL 18 scratch databases, persisted ChatWeave checkpoints, and the configured SIWC provider.
- Output boundary: `results.csv` and `summary.csv` contain no connection URL, credential, request body, upstream error body, or raw model prose.

No prompt, product logic, corpus expectation, or scoring rule changed between the Sol and Terra runs. No score threshold was chosen after either run.

## Summary

| Measure | Terra | Sol |
| --- | ---: | ---: |
| Hard-pass scenarios | 70/84 | 73/84 |
| Hard failures | 14 | 11 |
| Display hard-pass scenarios | 11/20 | 12/20 |
| Display tool sequence accuracy | 11/20 | 12/20 |
| Persisted display block accuracy | 16/19 | 15/18 |
| Display fact-value accuracy | 60/69 | 58/69 |
| Tool argument validity | 98/100 | 98/99 |
| Amount precision | 40/42 | 41/42 |
| Date accuracy | 40/42 | 41/42 |
| Category accuracy | 29/31 | 30/31 |
| Question precision / recall | 21/23 / 21/24 | 22/24 / 22/24 |
| Ambiguous-date recall | 18/20 | 18/20 |
| Latency P50 / P95 | 9,570 ms / 19,324 ms | 12,992 ms / 24,390 ms |
| Provider calls | 157 total: 151 succeeded, 6 failed | 152 total: 150 succeeded, 2 failed |

Terra produced nine display failures, three clarification failures, and two confirmation failures. All 20 display scenarios passed the Mermaid, ASCII-chart, oversized-table, sentence-count, and declared numeric-restatement prose checks. There was no separate soft prose finding.

On this single stochastic run, Terra was faster but less reliable on the hard scenario outcome: three fewer scenarios passed, with one more display failure and two more non-display failures. The latency difference is observational, not a performance benchmark.

Cost is intentionally left unknown: the source configuration had no `ai_prices` row for `gpt-6.1-terra`. Consequently all 84 scenario costs and the mean cost are blank rather than estimated.

## Display results by scenario

`Tool`, `block`, and `value` show correct/expected counts from persisted observations.

| Scenario | Hard pass | Tool | Block | Value | Prose | Finding |
| --- | --- | ---: | ---: | ---: | --- | --- |
| display-001 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-002 | no | 0/1 | 1/1 | 3/3 | pass | Wrong display tool; persisted component and facts were otherwise correct. |
| display-003 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-004 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-005 | no | 0/1 | 1/1 | 3/3 | pass | Wrong display-tool sequence for the requested recent-record list; persisted component and facts were correct. |
| display-006 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-007 | yes | 1/1 | 1/1 | 4/4 | pass | — |
| display-008 | no | 0/1 | 0/0 | 0/1 | pass | Did not make the required no-data query and omitted the declared no-data fallback fact. |
| display-009 | no | 0/1 | 1/3 | 6/10 | pass | Demo sequence was incomplete and included one invalid call/business error. |
| display-010 | yes | 1/1 | 1/1 | 4/4 | pass | — |
| display-011 | no | 0/1 | 1/1 | 4/4 | pass | Persisted the expected demo block and facts, but added an invalid display call/business error. |
| display-012 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-013 | no | 0/1 | 1/2 | 5/5 | pass | Capability downgrade retained the facts but used the wrong display sequence and persisted the wrong block shape. |
| display-014 | yes | 1/1 | 1/1 | 5/5 | pass | — |
| display-015 | yes | 1/1 | 1/1 | 5/5 | pass | — |
| display-016 | no | 0/1 | 0/0 | 0/2 | pass | Text-only capability downgrade omitted both required server-owned facts. |
| display-017 | yes | 1/1 | 1/1 | 3/3 | pass | — |
| display-018 | no | 0/1 | 0/0 | 0/1 | pass | Did not exercise the declared invalid-display retry and plain-text fallback path. |
| display-019 | no | 0/1 | 0/0 | 0/1 | pass | Missed the required exact total in the explicit text-only answer. |
| display-020 | yes | 1/1 | 1/1 | 3/3 | pass | — |

## Non-display hard failures

| Scenario | Expected | Observed | Review |
| --- | --- | --- | --- |
| en-ambiguous-008 | Ask for the original note date needed to resolve “next Wednesday” | Run failed | No record was credited, but the required clarification was not persisted. |
| en-ambiguous-009 | Ask for the original local date/time zone | Run failed | No record was credited, but the required clarification was not persisted. |
| insufficient-001 | Ask for the missing amount | Completed without writing | No record was credited, but the required clarification was omitted. |
| zh-confirm-002 | Show a matching void confirmation, then void after confirmation | Paused on a question | The intended confirmation flow was not reached and the expected void was not completed. |
| zh-confirm-003 | Show a matching date-change confirmation, then update after confirmation | Paused on a question | The intended confirmation flow was not reached and the expected update was not completed. |

No unsafe write was credited in any failed scenario. These are model/prompt behavior findings, not evaluator infrastructure failures. Issue #57 explicitly keeps score-driven prompt or product changes out of scope; genuine behavior fixes should be triaged separately from this evidence-only slice.

## Infrastructure and verification boundaries

- The scored run completed all 84 scenarios and produced no infrastructure error.
- The evaluator retained only allowlisted call metering fields. A content/credential scan of the committed directory found no URL, database DSN, bearer token, API key, password, or OAuth token marker.
- Scratch databases held ledger, journal, checkpoint, and metering data and were disposable per scenario. A temporary source clone held only AI configuration and the encrypted provider secret; it was not used for ledger, journal, checkpoint, or metering writes.
- This is one stochastic live run of one configured model route, not a claim about all prompts, models, or future runs.
