# Dev Plan: Guarded Confirmation Few-Shot Only (#59)

## Summary

Run one pre-registered prompt experiment that adds worked examples only for server-owned guarded confirmation. Preserve the current date and display instructions byte-for-byte, compare Sol and Terra once each on the unchanged 84-case corpus, and reject the candidate if either model misses the fixed non-regression boundary.

## Scope

In scope:

- Insert one compact `GUARDED_CONFIRMATION_EXAMPLES` block immediately after the existing opening line and before `UI`.
- Show five positive trajectories: record update, record void, record restore, zero-balance account archive, and document update.
- Show two negative trajectories: an unresolved target/version must be read or clarified without a write; a fully specified new expense uses `create_record` without extra confirmation.
- Add an exact rendered-prompt golden plus focused contract tests for the guarded and unguarded boundaries.
- Run the unchanged offline gates, deterministic Mock corpus, and one live SIWC pass each for Sol and Terra.

Out of scope:

- Any edit to `Ask about ambiguous dates.`, the rest of the opening line, the `UI` section, display policy, tool schemas/descriptions, business logic, evaluator, corpus, model routing, or deployment.
- Reusing the rejected branch's `BEHAVIOR_RULES` block or its date/display/fixture-specific wording.
- A second prompt edit after seeing live scores. A failed candidate is recorded and abandoned.

## Frozen Prompt Candidate

The following block is frozen before implementation and live scoring. Angle-bracket fields mean the actual ID/version already obtained from context or a read tool; they are not literal values to invent.

```text
GUARDED_CONFIRMATION
Known means the target id and expected_version came from context or a read result. For a guarded tool, call it now; the server pauses before any write and presents confirmation. Never call ask_user merely to ask “confirm?”. Only these tools are guarded: update_record, void_record, restore_record, archive_account, update_document, void_document.
EXAMPLES
P1 “把这笔金额改为42.50元 / Change this record to CNY 42.50” + known record => update_record(id=<id>, expected_version=<version>, changes.amount_minor=4250)
P2 “撤销这笔 / Void this record” + known record => void_record(id=<id>, expected_version=<version>)
P3 “恢复这笔 / Restore this record” + known record => restore_record(id=<id>, expected_version=<version>)
P4 “归档这个零余额账户 / Archive this zero-balance account” + known account => archive_account(id=<id>, expected_version=<version>)
P5 “把这份资料标题改为体检 / Change this document title to Checkup” + known document => update_document(id=<id>, expected_version=<version>, changes.title="Checkup")
N1 “改那条 / Change that one” without a unique target or version => search/read; if still ambiguous, ask_user. Never invent id/version or call a write.
N2 “2026-01-15午餐18元，现金/日常 / CNY 18 lunch, Cash/Daily” + known IDs => create_record(kind=expense, amount_minor=1800, occurred_on=2026-01-15, account_id=<cash_id>, purpose_id=<daily_id>). Do not ask for confirmation or replace it with a guarded tool.
```

`void_document` is named in the exhaustive guarded list and covered by focused tests but is not given a sixth positive example. `restore_document` is deliberately absent because its current schema is unguarded.

## Development Checklist

- [ ] Preserve the existing opening sentence and full `UI` section exactly.
- [ ] Insert exactly one copy of the frozen block between the opening line and `UI`.
- [ ] Add an exact golden for the fully rendered static prompt with a nonempty fake catalog, so the prompt/template boundary is frozen too.
- [ ] Add focused contract assertions for all six guarded tools: `update_record`, `void_record`, `restore_record`, `archive_account`, `update_document`, and `void_document`.
- [ ] Add negative assertions that `restore_document`, read-only tools, `create_record`, and `update_account` are not described as guarded, and that the block forbids `ask_user` confirmation substitution and invented IDs/versions.
- [ ] Keep implementation changes limited to prompt text and prompt-contract/golden tests.

## Test Checklist

- [ ] Exact rendered-prompt golden passes and proves: original opening sentence unchanged, original `UI` suffix unchanged, one example block only, and no rejected `BEHAVIOR_RULES` text.
- [ ] The extracted block has exactly five `P` lines, two `N` lines, and at most 1,450 characters.
- [ ] A registry-derived assertion compares the exhaustive guarded-tool line with live `requires_confirmation` results, rejecting drift or accidental inclusion of `restore_document`, `update_account`, reads, or creates.
- [ ] Per-line checks cover record update/void/restore, account archive, document update, complete create, unresolved reference/version, and absence of `ask_user` from positive trajectories.
- [ ] All required x86 build-host gates pass: format, clippy, full nextest, deny, audit, dependency/rules/entities/OpenAPI checks, and the repository's complete server gate set.
- [ ] Deterministic PostgreSQL Mock evaluation remains 84/84 on the unchanged corpus.
- [ ] Live SIWC runs exactly once each for `gpt-6.1-sol` and `gpt-6.1-terra` with the same unchanged 84 cases and scorer.
- [ ] Independently recompute totals, inspect every hard failure, compare confirmation and clarification subsets, record prompt-token/latency deltas, and scan allowlisted artifacts for secrets/raw prose/URLs.

## Assumptions

- [ ] The runtime freezes `static_instructions` per run; guaranteed by the existing prompt snapshot path.
- [ ] `update_record`, `void_record`, `restore_record`, `archive_account`, `update_document`, and `void_document` are guarded by the current registry; verified from the tool inventories and existing inventory tests.
- [ ] `restore_document`, `update_account`, reads, and creates are unguarded; verified from the same inventories. The examples must not broaden confirmation policy.
- [ ] A guarded call pauses before execution and the server renders confirmation; guaranteed by the existing runtime/scoring path. A model-side `ask_user` is not equivalent.
- [ ] Live runs are stochastic; this slice is a fixed non-regression check, not a statistical claim.

## Acceptance Checklist

- [ ] Offline gates are green and Mock remains 84/84.
- [ ] Sol is at least 73/84 and Terra is at least 70/84.
- [ ] All three existing confirmation cases pass for both models.
- [ ] Neither model uses `ask_user` as confirmation, performs a pre-confirm write, or invents a target ID/version.
- [ ] Outside the confirmation subset, neither model adds a confirmation/clarification regression versus its committed baseline.
- [ ] Prompt-token and latency changes are reported; no after-score prompt tuning occurs.
- [ ] Independent review finds the candidate aligned with this frozen contract.
- [ ] If any gate fails: no PR, merge, model switch, or deployment. If all pass: remove this temporary plan before PR and still make no routing or deployment change in this slice.
