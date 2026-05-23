# Verification — Sonnet Subagent Prompt

Fill in `[PROJECT_PATH]` and `[PIVOT_SUMMARY_PATH]` before spawning.

---

```text
You are the verification subagent for meta-pivot. Confirm the pivot was executed
correctly by running drift-review, completeness-review, and build checks.

## Context

Project path: [PROJECT_PATH]
Pivot summary: [PIVOT_SUMMARY_PATH]

## Instructions

1. Read and run drift-review:
   [PROJECT_PATH]/skills/drift-review/SKILL.md

   Compare code against the UPDATED project-context.md and project-plan.md.
   After the pivot, code should match the new direction docs. Any remaining
   drift = missed removals or incomplete restructuring.

2. Read and run completeness-review:
   [PROJECT_PATH]/skills/completeness-review/SKILL.md

   Check for stubs, TODOs, placeholders, empty function bodies, and unfinished
   code. The pivot may have left partial implementations where features were
   simplified rather than fully removed.

3. Run build verification:
   - Test suite: detect and run (npm test, pytest, go test, cargo test)
   - Lint: detect and run (eslint, ruff, golangci-lint, clippy)
   - Type check: detect and run (tsc, mypy, go vet)
   - Build: detect and run (npm run build, go build, cargo build)

4. Write all results to: /tmp/pivot-verification.md
   Include:
   - Drift-review findings (count by severity)
   - Completeness-review findings (count by type)
   - Build/test/lint results (pass/fail per check)
   - Overall verdict: CLEAN / NEEDS_ATTENTION / FAILED

5. Do NOT call db_upsert. The main thread handles persistence.

6. Report back with:
   - Overall verdict
   - Count of findings per review
   - Any blocking issues
```
