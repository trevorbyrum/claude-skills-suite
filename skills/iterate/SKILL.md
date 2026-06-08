---
name: iterate
description: Lightweight ad-hoc execution loop for bug fixes, debugging, small features, or recovery from a stuck state. Invoke with /iterate when /execute is overkill but unstructured coding loses context.
disable-model-invocation: true
argument-hint: "[bug-fix | stuck | tdd | <iteration goal>]"
---

# Iterate

Append-only execution loop for the "tweaking phase" — the gap between unstructured ad-hoc coding and a full `/execute` build plan. Session-aware and lightweight.

Three sub-modes share the same core loop. Differences are in goal capture and review thresholds.

## When to use

| Mode | Use for | Don't use for |
|---|---|---|
| `/iterate` | Bug fixes, refactors, ad-hoc tweaks, debugging, exploratory changes | Net-new features that need a plan |
| `/execute` | Implementing an approved `project-plan.md` | One-off tweaks |
| Unstructured | Single-line change, a question, read-only exploration | Anything you want recorded |

`/iterate` does NOT auto-activate. The user invokes it explicitly. Once active, it stays active for the session until `/save` runs or the user switches modes.

## Inputs

| Input | Source | Required |
|---|---|---|
| Iteration goal (1-2 sentences) | User prompt | Yes |
| Last context snapshot | Artifact DB (`save/compact/*` or `save/snapshot/*`) | Optional |
| Current branch + git status | git | Auto |

## Outputs

- **Append-only changelog** in DB: `db_write 'iterate' 'changelog' '<ISO-8601>' "$ENTRY"`
- **Lightweight checklist** in DB: `db_upsert 'iterate' 'checklist' 'current' "$CHECKLIST"` (updated in place)
- **Review offer** prompted after threshold per mode (see below)

## Instructions

### Phase 0: Mode detection

Detect from user words if possible:

| User says | Mode |
|---|---|
| "fix the X bug", "debug Y" | bug-fix |
| "I'm stuck", "this isn't working", "I keep going in circles" | stuck |
| "TDD", "write tests first" | tdd |

If ambiguous → `AskUserQuestion`: "Which iteration mode? Bug-fix, stuck-recovery, or TDD-loop?"

Read the matching reference for mode-specific guidance:
- bug-fix → `references/bug-fix.md`
- stuck → `references/stuck.md`
- tdd → `references/tdd.md`

### Phase 1: Session wake-up

On first invocation in a session:

1. Read the most recent context snapshot — prefer the newer of:
   ```bash
   source references/db.sh
   LATEST_COMPACT=$(db_read_all 'save' 'compact' 2>/dev/null \
     | jq -s 'sort_by(.label) | last | .content // empty' -r)
   # Legacy backwards-compat: sessions saved before the meta-context-save → save rename
   if [ -z "$LATEST_COMPACT" ]; then
     LATEST_COMPACT=$(db_read_all 'meta-context-save' 'compact' 2>/dev/null \
       | jq -s 'sort_by(.label) | last | .content // empty' -r)
   fi
   LATEST_SNAPSHOT=$(db_read_all 'save' 'snapshot' 2>/dev/null \
     | jq -s 'sort_by(.label) | last | .content // empty' -r)
   # Legacy backwards-compat: snapshot namespace fallback
   if [ -z "$LATEST_SNAPSHOT" ]; then
     LATEST_SNAPSHOT=$(db_read_all 'meta-context-save' 'snapshot' 2>/dev/null \
       | jq -s 'sort_by(.label) | last | .content // empty' -r)
   fi
   ```
2. Read the last 3 `iterate` changelog entries:
   ```bash
   db_read_all 'iterate' 'changelog' | tail -3
   ```
3. Read git state: branch, uncommitted files, last 3 commits.
4. Summarize for the user in 3-4 lines:
   ```
   Resuming iteration on branch `feature/x`.
   Last activity: 2 file edits to src/api.ts (2026-05-23 14:30).
   Open todos: <count from checklist if present>.
   Uncommitted: 3 files.
   ```

If no prior context exists, skip the summary.

### Phase 2: Goal capture (one question)

Ask:

> "What are we working on this iteration?"

Capture as a 1-2 sentence goal. Append to changelog:

```bash
source references/db.sh
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
db_write 'iterate' 'changelog' "$TIMESTAMP" "GOAL ($MODE): $GOAL_TEXT"
```

Generate a 3-5 bullet checklist tailored to the mode (see references for shape):

```bash
db_upsert 'iterate' 'checklist' 'current' "$CHECKLIST_BULLETS"
```

Present to the user. Accept revisions. **No multi-round planning** — the checklist is a living draft.

### Phase 3: Execution loop

The user drives the loop. For each task:

1. Read relevant files. Make the change. Test it.
2. After each meaningful step, append to changelog:
   ```bash
   TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   db_write 'iterate' 'changelog' "$TIMESTAMP" "STEP: <description> | FILES: <a,b,c> | RESULT: <pass|fail|partial>"
   ```
3. Update the checklist in place — strike/check completed bullets, add new ones if scope expanded.

Do NOT batch changelog entries. One entry per step keeps the audit trail honest.

### Phase 4: Review offer (automatic)

After the mode's threshold (see references), offer:

> "$N files touched this iteration. Want me to run a review lens before continuing? Options: `/review refactor` (code quality), `/review tests` (coverage), `/review security` (sensitive changes), `/review integration` (wiring), or skip."

The user can accept, pick a different lens, or decline. Track the offer ack so it doesn't fire again until the next threshold.

### Phase 5: Wrap-up (user-initiated)

The user ends the iteration by:
- Running `/save` (snapshots; or `/save` clear-mode commits + clears),
- Running `/github-sync` (commits + pushes), or
- Just stopping.

No explicit "iterate complete" step. The append-only changelog is the record.

**Pattern E terminal handoff (intentional skip).** Most lifecycle skills end by naming the next skill (Pattern E). `/iterate` deliberately doesn't — it's a loop, not a phase in a chain. The user picks the exit (`/save`, `/github-sync`, `/review`, or just leave the session). The review-offer at Phase 4 is the closest thing to a Pattern E nudge.

## References (on-demand)

Read the matching mode reference at Phase 0 for goal-capture and threshold details:

- `references/bug-fix.md` — reproduce-locate-fix-verify checklist shape; review threshold 5 files
- `references/stuck.md` — explicit "what have I tried" log, premortem prompt; review threshold 3 files (lower bar to break the loop)
- `references/tdd.md` — red-green-refactor; review threshold every commit on the test file

## Constraints

- **Append-only changelog.** Never `db_upsert` over a changelog entry. Use `db_write` with a unique timestamped label.
- **One-question goal capture.** No multi-round interview. The checklist is a living document.
- **No auto-commit, no auto-doc-update.** The user runs `/github-sync` and `/save` explicitly when ready.
- **Review threshold is automatic but advisory.** Offer the lens; the user decides.
- **Stays active across the session.** Subsequent user messages stay within iterate's loop until the user explicitly switches modes (e.g., starts `/execute`).

## Examples

```
User: /iterate — fix the broken pagination in the orders list
→ Mode = bug-fix. Phase 1 reads last snapshot (none), git status (clean on main).
  Phase 2 captures goal, generates 3-bullet checklist (reproduce, locate, fix+test).
  Phase 3 runs: read OrdersList.tsx, find offset bug, patch, test.
  Each step appended to changelog. After 5 files, Phase 4 offers /review tests.
```

```
User: /iterate — I keep changing the auth middleware and breaking the same tests
→ Mode = stuck. Reads `stuck.md`. Goal capture also asks for "what have you tried?".
  Generates a checklist that includes a premortem: "what would make this fail again?".
  Lower review threshold (3 files) so a lens runs before the loop tightens further.
```

```
User: /iterate write tests for the rate limiter first
→ Mode = tdd. Reads `tdd.md`. Generates red-green-refactor checklist.
  Each commit on the spec file triggers a /review tests offer.
```

```
User: I'm just exploring, don't track anything
→ Don't invoke /iterate. The user is in unstructured mode by choice.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
