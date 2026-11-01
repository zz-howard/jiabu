# Eval-only expectation assessment revision (#62)

Howard TG24866 supersedes the prior multidimensional/review design. Assess only whether the reply meets the user's request and fixture facts. Product prompts, tool schemas, provider/model selection and deployment stay unchanged.

- [x] Rules classify pass/fail/needs_judge. Remove prose money/string/style/query-shape matching from core hard decisions. Keep provable safety/protocol violations; a pure protocol-only contract may pass when completely covered, while all current 20 natural-language display requests still require Judge after necessary checks.
- [x] Judge receives fixed date/timezone/as_of, fixture test reference plus synthetic seed/initial records, actual visible prose/full block data/source calls and effective capabilities separately. No expected-as-actual facts or hidden style constraints.
- [x] Judge returns only expectation_met boolean, with three valid independent votes and majority. Missing votes/usage/schema/transport or essential evidence is infrastructure failure, never a product false or default true.
- [x] Report expectation met/not met/incomplete and decision source rule/judge under a new assessment version. Mock is pipeline-only. Preserve old run and 15/20 as historical evidence.
- [ ] Focused positive/negative controls: correct extra differences/percentages, reasonable alternatives, dates/units, wrong amounts/objects, unauthorized writes, invalid tools, missing evidence, missing Judge.
- [ ] Credential-free build-host PG18 Mock and required local checks (fmt/clippy/nextest/deny/audit/admin/rules/entities/OpenAPI); inherited fmt failure is recorded separately and does not skip later checks.
- [ ] Independent review before one same-host ARM64, original environment/provider, jobs2 full display20 run. Retain allowlisted synthetic visible output/blocks/JudgeInput/votes and deidentified report.

No merge/deployment authorization. No unrelated baseline formatting changes. Real database/credentials never cross environments. Ground truth is a test reference, not a claim that expected facts were independently verified from actual candidate output.
