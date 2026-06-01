---
name: execute
description: Implements work units from project-plan.md. Claude generates the code in main thread; Sonnet subagents handle parallel WUs when waves are wide. Reviews are user-triggered via /review. Invoke with /execute.
disable-model-invocation: true
argument-hint: "[WU-N-M | fix]"
---

# Execute

Implement work units from an approved `project-plan.md`. Three sub-paths share one orchestration shell:

- **Linear** — Claude implements WUs one at a time in main thread (default for most plans)
- **Single-WU** — Claude implements one named WU (the user passed a WU ID)
- **Review-fix** — apply fixes from a review synthesis (`artifacts/reviews/review-synthesis-N.md`)

Per cross-cutting rule 3: Claude generates; Sonnet subagents help when warranted; multi-lens review is user-triggered via `/review` between waves or after milestones.

## Inputs

| Input | Source | Required |
|---|---|---|
| `project-plan.md` | Project root | Yes (linear / single-wu) |
| `project-context.md` | Project root | Yes |
| Review synthesis | `artifacts/reviews/review-synthesis-N.md` | Required for review-fix mode |
| WU id (e.g., `WU-2-03`) | User prompt | Optional (single-wu mode triggers if present) |

## Outputs

- Implemented code per WU (committed via `/github-sync` at wave boundaries)
- Per-WU completion log: `db_write 'execute' 'verdict' '<WU-ID>' "<verdict-content>"`
- Updated `project-plan.md` status (WUs marked done; `/save` snapshots the session)

## Instructions

### Phase 0: Detect mode

Detect from user prompt + project state:

| Trigger | Mode |
|---|---|
| `/execute WU-N-M` (specific id) | single-wu |
| `/execute` with no args, plan has unstarted WUs | linear |
| `/execute fix` or recent `artifacts/reviews/review-synthesis-N.md` exists | review-fix |
| User says "implement the review findings" | review-fix |

If ambiguous → `AskUserQuestion`: "Full linear pass, a single WU, or fix review findings?"

Read the matching reference:
- linear → `references/linear.md`
- single-wu → `references/single-wu.md`
- review-fix → `references/review-fix.md`

### Phase 1: Verify inputs

1. **Linear / single-wu**: confirm `project-plan.md` exists. If missing, stop and tell the user to run `/build-plan` first.
2. **Review-fix**: confirm the review synthesis exists. If multiple exist, ask which one (default to latest by N).
3. For **single-wu**: confirm the WU id is in the plan and not already marked done.

### Phase 1.5: Decomposition validation (linear mode only)

Before building the queue for a **linear** execution, validate the plan's work units and confirm the decomposition with the user. Full detail in `references/decomposition.md`.

Summary of steps:

1. **Per-WU LOC check** — validate each unstarted WU is in the 50-200 LOC range. Warn outside that range; do not block.
2. **Access-class tagging** — confirm each Key File is tagged `read-only`, `additive-only`, or `mutable`. Default untagged files to `mutable`.
3. **File-ownership map** — for every `mutable` file, map it to the (wave, WU) that owns it. If two WUs in the same wave both have `mutable` on the same file, that is a **conflict** — surface to user, do NOT auto-resolve.
4. **Decomposition table** — present:

   ```
   | Wave | WU ID | LOC Est | Key Files (access class) | Parallelizable? | Notes |
   ```

5. **HARD GATE** — `AskUserQuestion`: "Proceed with this decomposition? (yes / adjust / stop)". Do NOT continue to Phase 2 until the user approves.

> Skip Phase 1.5 for **single-wu** and **review-fix** modes — they have their own gates.

### Phase 2: Build the queue

Per the mode reference, produce a queue:
- **Linear**: all unstarted WUs, grouped by dependency wave.
- **Single-wu**: just the one WU, with its prerequisite chain noted (if any prerequisite is unstarted, stop and surface).
- **Review-fix**: an ordered list of fixes from the synthesis (prioritized by severity).

Store the queue in the DB for resumability:

```bash
source references/db.sh
db_upsert 'execute' 'queue' '<mode>' "$QUEUE_TABLE"
```

### Phase 3: Implement (the loop)

For each item in the queue:

1. **Context assembly** — Claude reads only what's needed for this item: relevant files (named in the WU's Key Files), `project-context.md`, recent decisions from the iterate or save changelogs. Do NOT load the full codebase. Aim for 10k-50k tokens of curated context.

2. **Pre-implementation check** — quickly verify the WU's acceptance criteria are still relevant (project state may have shifted). If they're stale, surface to the user.

3. **Implementation** — Claude writes the code directly. Tests too — TDD-style is preferred for new behavior.

4. **Acceptance verification** — run the WU's acceptance criteria. For code WUs: run tests, lint, type-check. For doc WUs: visual check + Sonnet rubric subagent (`subagent_type: "general-purpose"`) for clarity review.

5. **Per-WU verdict**:

   ```bash
   db_write 'execute' 'verdict' '<WU-ID>' "PASS | FAIL | PARTIAL | <details>"
   ```

6. **Mark in plan** — update `project-plan.md` status (the actual file write happens through `/save` doc-refresh, but reflect the WU's done-state locally for the next iteration's context). Or: do a light inline update in-place — add `[done]` to the WU title, append a one-line note in the changelog section.

### Phase 4: Wave gate (linear mode only)

At the end of each wave (when all WUs in that wave have a verdict):

1. **Run `/github-sync`** — commit and push. This makes the wave's work durable before the next wave begins.

2. **Spawn a Sonnet rubric subagent** (`subagent_type: "general-purpose"`) for cross-WU consistency: does the wave produce a coherent slice? Did any WUs leak into each other's scope?

3. **User approval gate** — present:
   - Wave summary (WUs done, files touched, tests added)
   - Rubric subagent verdict
   - Ask via `AskUserQuestion`: "Continue to next wave, run `/review` first, or stop?"

   > **HARD GATE — WAIT FOR USER RESPONSE.** Do not start the next wave on silence. The wave gate is the primary checkpoint to catch drift before more work piles on.

4. **Memory sync (cross-cutting rule 5)** — Always write the wave summary to the local memory log:

   ```bash
   source references/db.sh
   PROJECT=$(basename "$(git rev-parse --show-toplevel)")
   SUMMARY="Wave <N> complete: <units done>/<failed>/<blocked>. Files: <count>. Tests added: <count>. Confidence: <high|medium|low>."
   db_write 'memory' 'execute' "wave-<N>,${PROJECT}" "$SUMMARY"
   ```

   If a memory MCP is available in this session (e.g., `mcp__qdrant-memory__store_memory` or any `mcp__<name>__memory_call`), the main thread may *also* mirror the entry — best-effort, silent on failure. The local DB row is the source of truth; the mirror is a convenience for cross-project access.

### Phase 5: Sonnet parallelism (default for independent WUs — see cross-cutting rule 11)

**This is the default execution path for any wave whose WUs are independent.** A WU is independent when:
- All its dependencies (from `project-plan.md` `Depends on` column) are done.
- It shares no `mutable` file with any other unstarted WU in the same wave.

For an independent wave, fan out automatically — do NOT ask the user for parallel-opt-in. Only fall back to sequential (Phase 3 main-thread loop) when at least one of those conditions fails for every WU in the wave.

If two WUs would collide on a `mutable` file, prefer **clustering** per rule 11 — bundle the colliders into one subagent that handles them in dependency order — over serializing the whole wave.

Parallel wave procedure:

1. Spawn one Sonnet subagent per WU using `subagent_type: "general-purpose"`, `isolation: "worktree"`. Each gets its own branch named `wu/<WU-ID>` off the current HEAD.
2. Each subagent receives the curated context for its WU + acceptance criteria.
3. Wait for all to return.
4. **Sequential rebase merge** in WU-ID order (lexicographic — `WU-2-01` before `WU-2-02`):
   ```bash
   for WU in $(echo "$WAVE_WUS" | sort); do
     git checkout main && git pull --rebase
     git checkout "wu/$WU"
     git rebase main      # rebase onto latest main; resolve conflicts if any
     git checkout main
     git merge --ff-only "wu/$WU"   # fast-forward; rebase guarantees this works
   done
   ```
   Sequential matters — files tagged `additive-only` in the plan need one-at-a-time merges so additions don't trample each other.
5. Run acceptance verification per WU on the merged main (lint, type-check, tests). If a WU's verification fails post-merge, log PARTIAL and surface — its commits stay on main but the WU is flagged for follow-up.
6. **Worktree cleanup**:
   ```bash
   for WU in $(echo "$WAVE_WUS" | sort); do
     git worktree remove "../$(basename $PWD)-wu-$WU" 2>/dev/null
     git branch -d "wu/$WU"
   done
   ```
7. Continue to Phase 4 (wave gate).

Default for independent WUs is **parallel** per cross-cutting rule 11. Sequential (main-thread Phase 3 loop) is used only when dependency chains or shared-file collisions force it. Same-file colliders are clustered into one subagent rather than serialized across the wave.

### Phase 6: Completion

After all WUs are done (or the user stops):

1. Run `/save` (compact mode) to snapshot the session.
2. Suggest `/review` for a milestone-level multi-lens review before declaring the project shipped.

## References (on-demand)

- `references/linear.md` — sequential WU implementation, wave structure, context assembly
- `references/single-wu.md` — single-WU mode (prerequisite chain check, narrower acceptance gate)
- `references/review-fix.md` — applying fixes from a review synthesis (severity-ordered queue)

## Examples

```
User: /execute
→ Phase 0: linear mode. Phase 1 confirms plan. Phase 2 builds 3-wave queue.
  Phase 3 implements WU-1-01 → WU-1-02 in main thread; verifies each.
  Phase 4 wave gate: github-sync, Sonnet rubric, user approves. Repeat for Wave 2.
```

```
User: /execute WU-2-03
→ single-wu mode. Phase 2 confirms WU-2-03 in plan, prereqs done.
  Phase 3 implements + tests. Phase 4 light wave-gate (just this WU).
  Phase 6 offers /save.
```

```
User: implement the review findings
→ review-fix mode. Phase 1 finds the latest review-synthesis-3.md.
  Phase 2 builds a severity-ordered fix queue (CRITICAL → HIGH → MEDIUM).
  Phase 3 applies each fix, runs tests. Phase 4 wave-gate at the end.
```

```
User: /execute, wave 2 has 3 independent WUs
→ linear mode. At Wave 2, Phase 1.5 confirms no mutable-file collisions.
  Phase 5 fans out automatically — 3 Sonnet subagents with worktree isolation.
  Merge in WU-ID order. Verify. Wave gate.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
