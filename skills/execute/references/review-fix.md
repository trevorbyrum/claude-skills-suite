# Execute — Review-Fix Mode

Apply fixes from a review synthesis. The synthesis already enumerated findings; this mode implements them in severity order.

## When this mode triggers

- `/execute fix`
- User says "implement the review findings"
- A recent `artifacts/reviews/review-synthesis-N.md` exists and the user wants to act on it
- `/review` ended with a "want to fix these?" prompt that the user accepted

## Locate the synthesis

```bash
ls artifacts/reviews/review-synthesis-*.md 2>/dev/null | sort -V | tail -1
```

If multiple exist and the user didn't specify, ask via `AskUserQuestion`. Default to latest.

If none exist, stop and tell the user to run `/review` first.

## Parse findings

Read the synthesis. Extract:
- All HIGH confidence findings (priority 1)
- All MEDIUM confidence findings (priority 2)
- All notable LOW confidence findings — usually CRITICAL/HIGH severity from a single model

For each finding, capture:
- Severity (CRITICAL / HIGH / MEDIUM / LOW)
- Lens(es) that flagged it
- File path + line number (if specified)
- Description
- Recommendation

## Build the queue

Order by severity, then by lens count (multi-lens > single-lens), then by confidence:

| Order | Severity | Confidence | Lens count |
|---|---|---|---|
| 1 | CRITICAL | high | any |
| 2 | HIGH | high | multi |
| 3 | HIGH | high | single |
| 4 | HIGH | medium | any |
| 5 | MEDIUM | high | multi |
| 6 | MEDIUM | high | single |
| 7+ | MEDIUM | medium | any |
| Skip | LOW | low | any |

Store the queue:

```bash
source references/db.sh
db_upsert 'execute' 'queue' 'review-fix' "$QUEUE_TABLE"
```

## Present and gate

Present the fix list to the user as a numbered table:

```text
| # | ID | Severity | Confidence | Files | Finding | Fix |
|---|-----|----------|------------|-------|---------|-----|
| 1 | RF-001 | CRITICAL | HIGH | src/auth.ts:42 | SQL injection in login | Use parameterized query |
| 2 | RF-002 | HIGH | HIGH | src/api.ts:15,28 | Missing input validation | Add zod schema validation |
| 3 | RF-003 | MEDIUM | HIGH | src/utils.ts:90 | Unused import | Remove dead import |
```

Summary line:

```text
X findings total: N CRITICAL, N HIGH, N MEDIUM, N LOW
Select fixes to apply: numbers (e.g., 1,2,5), range (1-3), or "all"
```

**STOP and wait for user selection. Do NOT proceed until the user picks which fixes to implement.** The user may also:
- Ask for more detail on a specific finding
- Reject a finding as a false positive
- Modify a finding's fix description
- Add custom fix items not in the review

## Implement (the loop)

For each selected fix in severity order:

1. **Read the affected file(s).** Use the finding's file:line as a starting point.
2. **Understand the actual issue.** A finding is a starting hypothesis, not an instruction. If you read the code and the finding is wrong (false positive), log it and continue.
3. **Apply the fix.** Claude writes the change directly via Edit / Write.
4. **Run the relevant test.** If the lens that flagged the issue has a verification step (security: re-scan with the same regex; tests: rerun the affected test file), do that locally.
5. **Post-fix verification** — dispatch a Sonnet subagent (`subagent_type: "general-purpose"`) using the verifier prompt template below. The verifier returns PASS / PARTIAL / FAIL.
   - **PASS** → proceed to next fix.
   - **PARTIAL** — the finding is partially resolved or a regression was found. Apply targeted edits inline, then re-dispatch the verifier. Retry up to 3 total attempts per cross-cutting rule 9 worker budget.
   - **FAIL** — the fix did not resolve the finding. Re-apply with failure details appended to context. Retry up to 3 total attempts. After 3 failures, log `FAILED` and surface to user.
   - The verifier subagent returns findings as text. **The main thread persists the verdict** via `db_write` (subagents do not write the DB — cross-cutting rule 6).
6. **Log per-fix verdict:**
   ```bash
   db_write 'execute' 'fix-verdict' '<finding-id>' "APPLIED | SKIPPED-FALSE-POSITIVE | DEFERRED | FAILED | <details>"
   ```

### Verifier subagent prompt template

Fill all bracketed placeholders before spawning:

````text
You are verifying that a specific review finding has been fixed.

Fix unit: [FIX-ID] — [finding summary]

Original finding:
[paste the original finding text]

Files modified by the fix:
[list the files that were changed]

## STEP 1: Check the Fix

Read the modified files. Verify:

1. The specific issue described in the original finding is resolved
2. The fix addresses the ROOT CAUSE, not just the symptom
3. The fix doesn't introduce new instances of the same problem

## STEP 2: Regression Check

Look at the modified files for:

- Broken imports or references
- Type errors introduced by the change
- Missing error handling at system boundaries
- Stubs, placeholders, or truncated code (automatic FAIL):

```bash
grep -rn '// \.\.\.\|TODO\|FIXME\|HACK\|XXX\|PLACEHOLDER\|TEMP\|TEMPORARY' [modified-files] || true
grep -rn 'implement later\|not yet implemented\|placeholder\|not implemented' [modified-files] || true
grep -rn 'throw new Error.*not implemented\|raise NotImplementedError\|todo!(\|unimplemented!(' [modified-files] || true
grep -rn 'catch.*{[[:space:]]*}\|except.*pass\|{ }' [modified-files] || true
grep -rn '"changeme"\|"password"\|"secret"\|"foo"\|"bar"\|"asdf"' [modified-files] || true
grep -rn 'console\.log\|console\.debug\|debugger\|alert(' [modified-files] | grep -v '\.test\.\|\.spec\.\|__test' || true
```

## STEP 2b: Wiring Regression Check

Verify the fix didn't break integration:

- New exports introduced by the fix: are they consumed? Unused new exports = PARTIAL.
- New env vars or config keys: documented in `.env.example`? Missing = PARTIAL.
- Resources acquired by new code: cleanup exists in error/shutdown paths? Missing = FAIL.
- Hardcoded placeholder IDs/sessions where dynamic values belong: automatic FAIL.

## STEP 3: Run Verification (if possible)

If a linter, type-checker, or test runner is available:

- Run lint on modified files
- Run type-check on modified files
- Run tests for modified files

Report results.

## STEP 4: Verdict

PASS:

```text
VERDICT: PASS
FINDING_RESOLVED: yes
REGRESSION_CHECK: clean
VERIFICATION: [lint/type-check/test results]
```

PARTIAL:

```text
VERDICT: PARTIAL
FINDING_RESOLVED: partially — [what remains]
ISSUES:
- [file:line] description
VERIFICATION: [results]
```

FAIL:

```text
VERDICT: FAIL
FINDING_RESOLVED: no — [why]
ISSUES:
- [file:line] description
REGRESSION: [any new issues introduced]
VERIFICATION: [results]
```

Report back with ONLY the structured verdict above.
````

## False positives

If a finding turns out to be wrong:

- Don't apply a "fix" that doesn't address a real problem.
- Log as `SKIPPED-FALSE-POSITIVE` with a one-line reason.
- Continue to the next fix.

## Deferrals

If a finding is real but the fix is bigger than expected (touches >5 files, needs design discussion):

- Log as `DEFERRED` with reason.
- Add a TODO to the next `/build-plan` update (mention to the user).
- Continue.

## End

After all fixes are applied (or the user stops):

1. Run the full test suite if the project has one — catch any regressions from cascading fixes.
2. Surface the verdict summary:
   - Applied: N
   - Skipped (false positive): N
   - Deferred: N
3. `/github-sync` to commit the batch.
4. Suggest `/review` again — fix verification. The new review run will catch any regressions and confirm the original findings are gone.
