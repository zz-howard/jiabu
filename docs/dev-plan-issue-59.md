# Dev Plan: Prompt and Tool-Schema Experiment Lab (#59)

## Summary

Add an evaluator-only experiment path that can load a prompt/tool-schema candidate at runtime and run a validated subset of the existing 84-case corpus. This lets us isolate confirmation, ambiguous-date, and display behavior without rebuilding the server or rerunning the full corpus after every candidate edit; only a frozen winning candidate is later translated into production definitions and put through the normal full gates.

## Scope

In scope:

- Add repeatable `--case <id>` selection to `ai-eval`. The evaluator must load and validate the complete corpus first, then retain the requested cases in corpus order.
- Add `--experiment <json>` to `ai-eval`. The versioned JSON contract may append to the frozen instructions and, for named existing tools, append to the provider-facing description and apply a JSON Merge Patch to the provider-facing parameter schema.
- Apply the candidate only to the scratch database's frozen run definitions after enqueue and before the first worker claim. Tool names, tool versions, executable registry behavior, routing, credentials, source database, and production server behavior remain unchanged.
- Print/store only a SHA-256 candidate identifier in evaluator diagnostics or result metadata. Candidate prompt text, descriptions, schemas, model prose, credentials, and database URLs must not enter logs or CSV reports.
- Document a compile-once experiment procedure with isolated target/control clusters and explicit stop rules.

Out of scope for this lab change:

- Production prompt, tool description, or production schema changes.
- New HTTP/admin surfaces, production environment variables, model/routing changes, corpus/scoring changes, deployment, or writes to the live source database beyond the already documented credential-manager refresh path.
- Automatically promoting an experiment candidate into production.
- Running the full live corpus during lab implementation. Full Mock and paired 84-case Sol/Terra runs happen only after a separate production candidate is frozen and reviewed.

## Experiment Contract

The experiment file is strict JSON with `deny_unknown_fields`, a required `schema_version: 1`, an optional `instructions_suffix`, and an optional map keyed by existing tool name. Each tool override may contain `description_suffix` and/or `parameters_merge_patch`. Empty overrides, unknown tools, duplicate case selectors, unsupported versions, non-object parameter patches/results, invalid resulting JSON Schemas, and candidates over documented size limits are configuration errors.

JSON Merge Patch follows RFC 7396 semantics: objects merge recursively, `null` removes a member, and non-object values replace the addressed value. The resulting tool parameter schema must remain a self-contained object schema that can be compiled by the existing no-network JSON Schema validator. The patch changes only what is shown to the provider; the real tool registry remains the final argument validator and executor.

The evaluator reads and validates the experiment once, computes its identifier from the exact input bytes, and passes the parsed immutable value to each scenario. After `start_at_with_capabilities` has committed a queued run, the evaluator updates only that run's `agent_run_items(kind = 'context')` payload at `definitions.snapshot`; it then re-reads and validates the persisted snapshot before allowing `work()` to claim the run. A no-experiment run does not execute this mutation path.

## Development Checklist

- [ ] Add a small evaluator-only experiment module with strict deserialization, bounded input/suffix/patch sizes, SHA-256 identification, RFC 7396 merge behavior, existing-tool lookup, and resulting-schema validation.
- [ ] Add repeatable `--case <id>` and optional `--experiment <path>` arguments without changing existing defaults.
- [ ] Load and validate all 84 entries before applying case selection; reject blank, duplicate, and unknown IDs; preserve original corpus order rather than command-line order.
- [ ] Load the experiment once before any scenario is created and carry only the parsed immutable candidate plus its identifier through the run.
- [ ] Add the scratch-only post-enqueue/pre-claim snapshot mutation. Require exactly one queued run and one context item, preserve model parameters/tool names/tool versions, and verify the persisted result before worker execution.
- [ ] Keep no-experiment execution on the current code path so existing Mock/live behavior and report schemas remain unchanged.
- [ ] Extend `server/eval/README.md` with the strict file shape, safety boundary, subset semantics, candidate-ID behavior, compile-once commands, cluster composition, and stop rules.
- [ ] Do not change production prompt/schema files, routing, provider configuration, corpus entries, scoring, report columns, or server/API code in this lab PR.

## Test Checklist

- [ ] Unit-test strict experiment parsing: valid minimal/full files, unknown fields/version/tool, empty override, size limits, invalid JSON, and non-object patches.
- [ ] Unit-test JSON Merge Patch, including recursive merge, array/scalar replacement, `null` deletion, and rejection when the result is not a valid self-contained object schema.
- [ ] Unit-test case selection for one/multiple IDs, corpus-order preservation, blank/duplicate/unknown IDs, and proof that full-corpus validation runs before selection.
- [ ] Integration-test that the candidate is absent before enqueue, is applied to the one queued run after enqueue, and is visible to the provider on the first turn without changing executable registry schemas or tool versions.
- [ ] Integration-test that a missing/duplicate/non-queued run context aborts before any provider call.
- [ ] Verify that no-experiment deterministic Mock output remains identical for the complete 84-case corpus.
- [ ] Run targeted Mock subsets with an experiment and verify only selected IDs execute while the normal result/summary schemas remain valid.
- [ ] Capture CLI stdout/stderr and scan generated CSV/assessment artifacts to prove raw candidate text, URLs, DSNs, credentials, and model prose are absent; only the candidate identifier may be exposed.
- [ ] On `jiabu-build`, generate the fixed receipt fixtures, then run formatting, focused evaluator tests, workspace tests, and full local CI once after implementation is complete.

## Lab Procedure and Stop Rules

- [ ] Compile the live evaluator once on `jiabu-build`; candidate files are data inputs and must not require recompilation.
- [ ] Establish a fresh baseline and one frozen candidate run for each cluster; never edit a candidate file after observing its score.
- [ ] Confirmation cluster: `zh-confirm-001/002/003` as targets, plus ordinary-create and missing-target/insufficient controls. Pass only with real server-owned confirmation, no pre-confirm write, correct post-confirm write, and no control regression.
- [ ] Ambiguous-date cluster: the failing English ambiguous-date cases as targets, plus relative-date and fully specified-date controls. Pass only when ambiguity asks a question without a write and controls still resolve/write as specified.
- [ ] Display cluster: failing component-selection/query/argument cases as targets, plus passing component, explicit-text fallback, no-data, and capability controls. Pass only when query semantics, parameter validity, component/fallback facts, and zero-write safety all hold. For explicit “this month” cases, the fixed 2026-10-21 evaluation date still means the complete calendar month ending 2026-10-31, as committed by the revised corpus.
- [ ] Reject a cluster candidate on any target miss, safety failure, new control failure, or evidence leakage. Do not combine cluster changes until each change passes its own targets and controls.
- [ ] After cluster candidates pass, combine once and run the union of all targets/controls. Freeze the combined candidate before scoring.
- [ ] Only then translate the frozen candidate into production prompt/tool definitions in a separate reviewed change, run focused production tests, full local CI, deterministic Mock 84/84, and one paired full 84-case Sol/Terra evaluation. Reject on aggregate/safety non-regression failure. Do not switch the default model or deploy without a later explicit decision.

## Assumptions

- [ ] Entry IDs are unique and the complete corpus is valid before selection. This is guaranteed by `dataset::validate`; selection must occur only after it succeeds.
- [ ] Enqueue commits one context item at index 1 and one queued run for the returned assistant message before worker execution. This is guaranteed by the current `RunService` transaction, but the evaluator mutation must verify it rather than silently assume it.
- [ ] The evaluator owns each disposable scratch database scenario and no worker races the mutation before `drive()`. This is guaranteed by the current sequential fixture construction; an integration test must pin the ordering.
- [ ] Tool names are unique in a frozen snapshot and tool versions are stored separately in the same context definition. The implementation must validate uniqueness and must not mutate versions.
- [ ] Provider-facing parameter schemas are JSON objects and self-contained. Existing tool definitions guarantee the starting shape; every patched result still needs validation.
- [ ] The production tool registry remains authoritative for executable validation. The experiment changes only the frozen provider-facing definition and therefore cannot broaden what the server actually executes.
- [ ] Candidate contents may be sensitive prompt material. They are allowed only in the local input file and disposable scratch prompt snapshot; reports/logs expose only a hash identifier.
- [ ] A small live subset is directional evidence, not an aggregate quality claim. Promotion still requires the unchanged full-corpus gates described above.

## Acceptance Checklist

- [ ] `ai-eval --case ...` validates the whole corpus, executes exactly the requested unique IDs in corpus order, and rejects invalid selectors before creating scenarios.
- [ ] `ai-eval --experiment ...` changes the first provider request through the persisted frozen snapshot without a rebuild and without changing production source definitions or executable tool validation.
- [ ] Editing only the candidate file and rerunning the already built binary changes the candidate identifier and applied snapshot.
- [ ] Omitting both new arguments preserves the prior 84-case behavior and report formats.
- [ ] Raw candidate contents and sensitive runtime material are absent from terminal output and committed report artifacts.
- [ ] Focused tests, full workspace tests, and local CI pass on `jiabu-build`.
- [ ] Independent code reviews by zylos0t and luna.coco are CLEAN before acceptance.
- [ ] The lab PR contains no production prompt/schema, routing, model, API, corpus, scoring, or deployment changes.

