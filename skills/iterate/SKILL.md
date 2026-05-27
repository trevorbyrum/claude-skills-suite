---
name: iterate
description: Lightweight ad-hoc execution loop for tweaking, debugging, small features. Use when meta-execute is overkill but unstructured coding loses context. Invoke with /iterate.
---

# iterate

Append-only execution loop for the "tweaking phase" — the gap between
unstructured ad-hoc coding and a full `/meta-execute` build plan. Session-
aware, lightweight, hook-enforced.

**Research basis**: 014D — every major AI dev tool (Cursor Composer,
Windsurf Cascade, Aider conventions, OpenHands event log) has this mode.
Pattern: append-only changelog as source of truth; 5-field cnotes; review
offer after N changes.

## When to use

| Mode | Use for | Don't use for |
|---|---|---|
| **`/iterate`** | Bug fixes, refactors, ad-hoc UI tweaks, debugging, exploratory changes | Net-new features that need a plan |
| **`/meta-execute`** | Implementing an approved `project-plan.md` | One-off tweaks |
| **Unstructured** | Single one-line change, a question, a read-only exploration | Anything you want recorded |

Triggers `/iterate` directly. The skill does NOT auto-activate from
chat — the user must invoke it. Once active, it stays active across the
session until the user runs `/meta-context-save` or starts a new session.

## Inputs

| Input | Source | Required |
|---|---|---|
| User's iteration goal (1-2 sentences) | User prompt | Yes |
| Last context snapshot | Artifact DB (`meta-context-save`/`compact`/latest) | Optional |
| Current branch + git status | git | Auto |

## Outputs

- **Append-only changelog** in artifact DB (skill=`iterate`, phase=`changelog`, label=`{ISO-8601-timestamp}`)
- **Lightweight checklist** in DB (skill=`iterate`, phase=`checklist`, label=`current`) — updated in place
- **Auto-generated cnotes entries** (via Stop hook, 5-field schema)
- **Review offer** prompted after every 5 file modifications or 3 commits

## Instructions

### Phase 1: Session Wake-Up [Inline]

On first invocation in a session:

1. Read the most recent context snapshot from either of the two
   append-only sources — user-invoked saves (`compact` phase) and
   PreCompact hook auto-snapshots (`snapshot` phase). Take whichever has
   the newer timestamped label:
   ```bash
   source artifacts/db.sh
   LATEST_COMPACT=$(db_read_all 'meta-context-save' 'compact' 2>/dev/null \
     | jq -s 'sort_by(.label) | last | .content // empty' -r)
   LATEST_SNAPSHOT=$(db_read_all 'meta-context-save' 'snapshot' 2>/dev/null \
     | jq -s 'sort_by(.label) | last | .content // empty' -r)
   # Use whichever is more recent (compare label timestamps), or both
   ```
2. Read the last 3 iterate changelog entries to see what was recently done:
   ```bash
   db_read_all 'iterate' 'changelog' | tail -3
   ```
3. Read current git state: branch, uncommitted files, last 3 commits.
4. Summarize for the user in 3-4 lines:
   ```
   Resuming iteration on branch `feature/x`.
   Last activity: 2 file edits to src/api.ts (2026-05-23 14:30).
   Open todos: <count from checklist if present>.
   Uncommitted: 3 files.
   ```

If no prior context exists (fresh start), skip the summary.

### Phase 2: Goal Capture [Inline]

Ask the user (1 question, not a long interview):

> "What are we working on this iteration?"

Capture as a 1-2 sentence goal. Append to changelog with timestamp:
```bash
source artifacts/db.sh
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
db_write 'iterate' 'changelog' "$TIMESTAMP" "GOAL: $GOAL_TEXT"
```

Generate a 3-5 bullet checklist from the goal. Store in DB:
```bash
db_upsert 'iterate' 'checklist' 'current' "$CHECKLIST_BULLETS"
```

Present the checklist to the user. Accept revisions. **No multi-round
planning** — the checklist is a living draft, not a contract. Bullets
are added/removed as the iteration evolves.

### Phase 3: Execution Loop [Inline]

The user drives the loop. For each task:

1. Read relevant files. Make the change. Test it.
2. After each meaningful step, append to changelog:
   ```bash
   TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   db_write 'iterate' 'changelog' "$TIMESTAMP" "STEP: <one-line description> | FILES: <a,b,c> | RESULT: <pass|fail|partial>"
   ```
3. Update checklist in place — strike/check completed bullets, add new
   bullets if scope expanded:
   ```bash
   db_upsert 'iterate' 'checklist' 'current' "$UPDATED_CHECKLIST"
   ```

Do NOT batch-commit changelog entries. One entry per step keeps the audit
trail honest. The Stop hook will prompt for cnotes/doc checks at session
end.

### Phase 4: Review Offer [Inline, automatic]

After **5 file modifications** OR **3 git commits** in this iteration
(count via `db_read_all 'iterate' 'changelog' | grep -c "FILES:"`), offer:

> "5 files touched this iteration. Want me to run a review lens before
> continuing? Options: `/refactor-review` (code quality), `/test-review`
> (coverage), `/security-review` (sensitive changes), `/integration-review`
> (wiring), or skip."

The user can accept, pick a different lens, or decline. Track the offer
acknowledgment so it doesn't fire again until the next 5/3 threshold.

### Phase 5: Wrap-Up [User-Initiated]

The user ends the iteration by:
- Running `/meta-context-save` (snapshots + clears),
- Running `/github-sync` (commits + pushes), or
- Just stopping (the Stop hook will prompt for cnotes/doc updates).

No explicit "iterate complete" step. The append-only changelog is the
record. Future `/iterate` sessions resume from where this one left off
via Phase 1's session wake-up.

## Interaction with other skills

| Skill | How `/iterate` interacts |
|---|---|
| `/meta-execute` | Mutually exclusive. If a build plan is active, use meta-execute. If you're tweaking what meta-execute produced, use iterate. |
| `/meta-context-save` | iterate's session wake-up reads the latest meta-context-save snapshot. |
| `/evolve` | iterate does NOT auto-evolve docs. Run `/evolve` explicitly when context/plan needs a refresh. |
| `/github-sync` | iterate does NOT auto-commit. Run `/github-sync` when ready. |
| `/meta-review` | The review offer (Phase 4) points to single-lens reviews, not the full meta-review fan-out. |
| Review lenses | Offered automatically after threshold (Phase 4). User picks. |

## Constraints

- **Append-only changelog.** Never `db_upsert` over a changelog entry. Use
  `db_write` with a unique timestamped label. History matters for this
  skill — it's the audit trail.
- **One-question goal capture.** Do not run a multi-round interview. The
  checklist is a living document, not a spec.
- **No auto-commit, no auto-evolve, no auto-doc-update.** The Stop hook
  handles doc reminders; the user runs `/github-sync` explicitly.
- **Review threshold is automatic, but advisory.** Offer the lens; the
  user decides. Don't force.
- **Stays active across the session.** Once `/iterate` is invoked,
  subsequent user messages stay within iterate's loop until the session
  ends or the user explicitly switches modes (e.g., starts `/meta-execute`).

## Examples

```
User: /iterate — fix the broken pagination in the orders list
Action: Phase 1 reads last snapshot (none), git status (clean on main).
        Phase 2 captures goal, generates 3-bullet checklist
        (reproduce, locate, fix+test). User confirms.
        Phase 3 runs: read OrdersList.tsx, find offset bug, patch, test.
        Each step appended to changelog with timestamp + files + result.
        After file count hits 5, Phase 4 offers /test-review. User accepts.
```

```
User: /iterate
(no goal supplied)
Action: Phase 1 reads last snapshot — "last iteration: auth refactor".
        Reports: "Resuming on auth refactor branch. 4 file edits
        yesterday. Open todos: 2." Asks Phase 2 goal question.
```

```
User: I'm just exploring, don't track anything
Action: Don't invoke /iterate. The user is in unstructured mode by
        choice — iterate would add overhead.
```

```
User: /iterate — small change to add a dark mode toggle
Action: Phase 2 generates checklist. As the user iterates, scope expands
        ("also need theme context", "also update settings page"). User
        updates checklist; changelog records each step. After 5 files
        touched, Phase 4 offers /ui-review. User runs it.
```

---

Before completing, read and follow `references/cross-cutting-rules.md`.
