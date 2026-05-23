
# Surgical Remove

Internal skill invoked by meta-pivot's Opus subagent. Executes approved removals
from scope-triage and impact-analysis in four risk-ordered waves, each on its own
git branch, with a human approval gate before merging each wave.

**Context-window strategy**: Read triage and candidate inputs inline. Execute each
wave's file operations and test suite via Bash — never read removed files into
context for comprehension. Write wave logs to temp files; main thread persists
to artifact DB.

```
Wave ordering (lowest → highest risk):
  Wave 1: Dead code      — zero deps, zero refs. File deletes only.
  Wave 2: Orphaned mods  — no inbound deps, has outbound. Delete + clean imports.
  Wave 3: Deprecated     — has deps, flagged for removal. Delete + update importers.
  Wave 4: Restructuring  — live code moving/renaming. Move + rewrite all refs.
```

## Inputs

| Input | Source | Required |
|---|---|---|
| Approved triage | `db_read 'scope-triage' 'triage' 'latest'` | Yes |
| Candidate list | `db_read 'impact-analysis' 'candidates' 'latest'` | Yes |
| pivot-plan.md | `artifacts/general/pivot-plan.md` | Yes |

## Outputs

- Per-wave temp log: `/tmp/pivot-wave-{N}-log.md`
- Artifact DB (written by main thread): `db_upsert 'surgical-remove' 'wave-log' 'wave-{N}' "$CONTENT"`
- Git branches: `pivot/wave-1`, `pivot/wave-2`, `pivot/wave-3`, `pivot/wave-4`
- Pre-prod shortcut branch: `pivot/removal`

## References (on-demand)

Read these only when needed:
- `references/wave-protocol.md` — wave ordering rationale, characterization test strategy,
  rollback decision tree, pre-prod detection checklist, branch naming and merge strategy,
  mid-wave failure handling

## Instructions

### Phase 1: Load Inputs

Source the artifact DB helper and read inputs:

```bash
source artifacts/db.sh
TRIAGE=$(db_read 'scope-triage' 'triage' 'latest')
CANDIDATES=$(db_read 'impact-analysis' 'candidates' 'latest')
```

Read `artifacts/general/pivot-plan.md` for high-level removal context.

If any input is missing or empty, halt and report which input is absent.

### Phase 2: Classify Candidates into Waves

For each candidate in the impact-analysis list, assign it to exactly one wave:

- **Wave 1 (dead code)**: zero callers, zero import references anywhere in the codebase,
  no runtime dynamic references (e.g., `require()` with a variable, reflection, plugin loaders).
  Action: file delete only.

- **Wave 2 (orphaned modules)**: no inbound imports from any other module, but the file
  itself imports other modules. Action: delete file + remove its import statements from
  dependency files it references.

- **Wave 3 (deprecated features)**: at least one inbound dependency exists, but the
  triage or pivot-plan marks it deprecated / scheduled for removal. Action: delete file +
  update every importer to remove the import and any call sites.

- **Wave 4 (restructuring)**: live code that is moving location or being renamed — not
  deleted outright. Action: move/rename + rewrite all references to the new path/name.

Present the classified wave list to the main thread before proceeding. Stop and wait
for acknowledgement.

### Phase 3: Detect Production vs Pre-Production

Read `references/wave-protocol.md` (pre-prod detection checklist section) and check
the project for deploy indicators. If ANY indicator is present, treat as production.

**Pre-production shortcut** (no indicators found):
- Use a single branch `pivot/removal` for all waves
- Skip characterization tests; full test suite is the safety net
- Execute all four waves sequentially on the same branch
- Single human gate after all waves complete

**Production mode** (deploy indicators detected):
- Per-wave branches `pivot/wave-{N}`
- Characterization tests for Waves 3 and 4 (has dependencies or live code)
- Human gate after each wave before proceeding

### Phase 4: Execute Waves

Repeat the following protocol for each wave (or once for the pre-prod shortcut).

#### 4a. Create Branch

```bash
git checkout -b pivot/wave-{N}    # production mode
# OR
git checkout -b pivot/removal     # pre-prod shortcut
```

#### 4b. Characterization Tests (production mode, Waves 3 and 4 only)

For each file being removed or moved in this wave, generate a characterization
test that records current behavior. The goal is a regression safety net, not
completeness — one test per public entry point is sufficient.

Write tests to `tests/characterization/wave-{N}/`. Commit them before any
removals so they exist in history.

Skip if: pre-prod shortcut, Wave 1, Wave 2, or the module has zero callable
public API (pure side-effect files, config-only files).

#### 4c. Execute Removals

**Wave 1**: `git rm` each dead file. No import cleanup needed.

**Wave 2**: `git rm` each orphaned file. Then locate and delete the import
statements this file contributed to other modules (its outbound imports become
dangling; remove the `import X from './orphaned'` lines in any files that
imported shared utilities through this module).

**Wave 3**: `git rm` each deprecated file. For every file that imports it
(from the impact-analysis candidate list), remove the import and all call sites
that reference the removed export. Verify no TypeScript/ESLint/compiler errors
from the edits before moving on.

**Wave 4**: `git mv OLD_PATH NEW_PATH` (or rename). Update every reference in
the codebase to the new path and new export name. Verify with a grep that no
old path string remains (excluding git history and lockfiles).

Commit after all removals in the wave are complete:

```bash
git add -A
git commit -m "pivot(wave-{N}): remove {short description of what was removed}"
```

#### 4d. Run Test Suite

```bash
# Detect and run appropriate test runner
if [ -f package.json ]; then
  npm test 2>&1 | tail -40
elif [ -f pyproject.toml ] || [ -f setup.py ]; then
  python -m pytest 2>&1 | tail -40
elif [ -f go.mod ]; then
  go test ./... 2>&1 | tail -40
elif [ -f Cargo.toml ]; then
  cargo test 2>&1 | tail -40
fi
```

Also run lint and type-check if configured:

```bash
npm run lint 2>&1 | tail -20
npm run typecheck 2>&1 | tail -20   # or tsc --noEmit
```

Record: pass/fail counts, any unexpected failures, test runtime.

**Exit condition**: If tests fail on code that was NOT touched by this wave,
read `references/wave-protocol.md` (mid-wave failure section) before
deciding whether to halt, rollback, or continue.

#### 4e. Write Wave Log

Write to `/tmp/pivot-wave-{N}-log.md`:

```markdown
# Wave {N} Log — {wave name}

**Branch**: pivot/wave-{N}
**Date**: {ISO date}
**Files removed/moved**: {count}
**File list**: {paths}
**Characterization tests written**: {count or "n/a"}
**Test result**: {PASS N / FAIL N}
**Lint**: {PASS / FAIL / skipped}
**Type-check**: {PASS / FAIL / skipped}
**Unexpected breakage**: {description or "none"}
**Commit**: {git hash}
```

#### 4f. Report to Main Thread for Human Gate

Report the wave summary from the temp log. Present:
- Files removed/moved
- Test pass/fail
- Any unexpected breakage
- Rollback command if needed

Ask the user:
> "Wave {N} complete. Tests: {result}. Merge this wave and continue to Wave {N+1}?"
> Options: **merge + continue** / **rollback wave** / **pause here**

Wait for explicit answer. Do NOT proceed to the next wave without approval.

On **merge + continue**: merge `pivot/wave-{N}` into the working base branch,
then proceed to Wave {N+1}. Main thread persists the log to artifact DB:
`db_upsert 'surgical-remove' 'wave-log' 'wave-{N}' "$CONTENT"`.

On **rollback wave**: `git checkout {base-branch} && git branch -D pivot/wave-{N}`.
Report rollback complete. Do not continue.

On **pause**: report current state, leave branch intact, stop.

### Phase 5: Final Merge

After all waves are approved:

```bash
git checkout {base-branch}
git merge --no-ff pivot/wave-4   # or pivot/removal for pre-prod
git log --oneline -10
```

Report total files removed, total tests passing, and any deferred items.

## Error Handling

- **Missing input**: Halt immediately. Report which artifact DB read returned empty.
- **Dirty working tree at start**: Run `git status --porcelain`. If dirty, ask user
  to commit or stash before proceeding.
- **Test failure mid-wave**: Read `references/wave-protocol.md` rollback decision tree.
  Never auto-proceed past a red test suite in production mode.
- **No test runner detected**: Warn the user. Run lint and type-check only. Ask
  whether to proceed without test coverage.
- **Wave 4 grep finds remaining old-path references**: Do not commit. Fix the
  remaining references first, then re-verify.

## Examples

```
meta-pivot subagent: Approved triage loaded. Candidate list has 18 files.
→ Classify into waves, present classification, await acknowledgement, then
  execute Wave 1 (5 dead files deleted, 0 test failures), present human gate.
```

```
Project has no Dockerfile, no CI deploy stage, no published package.
→ Pre-prod shortcut: single branch pivot/removal, no characterization tests,
  all four waves sequential, one human gate at the end.
```

```
Wave 3 test suite: 3 unexpected failures in unrelated module.
→ Read wave-protocol.md rollback section. Report failures with details.
  Ask: "Unexpected failures in auth.test.ts (unrelated to removals). Rollback
  Wave 3 or investigate before continuing?"
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
