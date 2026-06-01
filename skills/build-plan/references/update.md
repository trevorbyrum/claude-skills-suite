# Build Plan — Update Mode

For incremental updates to an existing `project-plan.md`.

## Three-lens framing (why /build-plan touches plan.md / todo.md / features.md)

`project-plan.md`, `todo.md`, and `features.md` are **three different views** of the same project state, each for a different audience:

| File | Audience | What it answers |
|---|---|---|
| `project-plan.md` | **Builder** (you / Claude / future agents) | "What's the next WU, what depends on what, what's the critical path?" — work-unit decomposition with acceptance criteria |
| `todo.md` | **Operator** (running the project day-to-day) | "What's actively in flight right now? What's blocked? What just landed?" — short-term running list, Now / Next / Later / Done |
| `features.md` | **Product** (you-as-PM, or external stakeholders) | "What can users actually do? What's shipped vs planned vs cut?" — capability inventory, Shipped / In Progress / Planned / Deferred |

Update mode keeps all three coherent. A completed WU often surfaces in all three:
- Plan: WU marked `[done]` in the table + changelog entry
- Todo: line moves from "Next" or "Now" to "Done"
- Features: associated feature flips to `Shipped` if all its WUs are done

## Identify what changed

Cross-reference these inputs:
- Latest `iterate` changelog entries: `db_read_all 'iterate' 'changelog' | tail -20`
- Latest `execute` status records: `db_read_all 'execute' 'status'`
- Git log since the plan's last changelog entry
- The user's prompt — they often name a specific WU

Classify the changes:
- **Completed**: WUs whose acceptance criteria have been met (tests pass, files committed, integration verified)
- **Added**: new WUs the user is requesting or that surfaced during execution
- **Removed**: WUs no longer needed (scope cut, alternative solved the problem)
- **Re-scoped**: WUs whose description or acceptance criteria changed
- **Dependency shifts**: WUs whose order or blockers changed

## Edit in place

Update work units directly in the plan file. Keep the same structure and formatting — change values, not layout.

For **completed** work units:
- Mark status (add a `[done]` tag in the title, or add a checkmark column)
- Leave the WU in the plan (don't delete) — the plan is a history doc

For **added** work units:
- Insert in the appropriate phase
- Assign a new WU ID (`WU-<phase>-<next-seq>`)
- Fill all required fields per SKILL.md Phase 3
- Run the no-placeholders rule + integration wiring audit (SKILL.md Phase 4) on the new unit

For **removed** work units:
- Don't delete — strike through (or add a `[removed]` tag) and add a note explaining why
- Update any other WUs that depended on it (either remove the dependency or note the alternative)

For **re-scoped** work units:
- Update the affected fields in place
- The changelog entry captures the old → new diff

For **dependency shifts**:
- Update the Dependencies column
- Re-check the critical path; note if it changed

## Changelog entry

Append a new entry at the top of the plan's "Changelog" section (newest first). Format:

```markdown
## <date> — <one-line summary of the update>

- Completed: WU-1-03 — auth middleware tested, integrated
- Completed: WU-1-04 — login form, dashboard route
- Added: WU-2-07 — migration script for legacy user table
- Re-scoped: WU-2-03 — "OAuth via Google" → "OAuth via Google + GitHub"
- Removed: WU-3-02 — admin panel cut from MVP per scope decision
- Dependency: WU-2-07 → WU-2-03 (new) — migration must run before OAuth switch

Reason: WU-1 complete (auth shipped), scope decision on admin panel, legacy data migration surfaced.
```

## Companion docs (SKILL.md Phase 7)

After updating the plan, sync companion docs (`features.md`, `todo.md`):

**`features.md`** — three-lens companion to project-plan.md. Update the status of each feature based on which WUs land in which state:
- Feature has all WUs done → mark `done`
- Feature has at least one WU in progress (or completed in this update) → mark `in progress`
- Feature has any added WUs → mark `planned`

**`todo.md`** — append new TODOs for newly added WUs that don't have an obvious owner / next step.

**todo.md format spec (required):**

```markdown
# Todo

## Now (current sprint / immediate)
- [ ] Actionable item with enough context to act without re-reading the plan (WU-N if applicable)

## Next (queued, unblocked)
- [ ] Item

## Later (blocked or low priority)
- [ ] Item — blocked by [what]
- [ ] Item — low priority, revisit after [milestone]

## Done (recent, for context)
- [x] Item — completed YYYY-MM-DD
```

- Each item must be **actionable** — include WU ID where applicable. "Fix auth" is too vague; "Add JWT expiry validation to auth middleware (WU-3)" is correct.
- **Done section pruning rule:** Keep only the last 5-10 completed items. Older items are removed — the plan changelog is the permanent record.

Both files are optional. Skip silently if missing.

## Wiring audit (only on changes)

Run SKILL.md Phase 4 only against changed and added units. Don't re-audit the whole plan — that's a heavy operation and the un-touched WUs already passed.

## Present diff

Show the user only what changed:
- Completed: <list>
- Added: <list with summaries>
- Re-scoped: <list with old → new>
- Removed: <list with reasons>
- Dependency shifts: <list>

Ask via `AskUserQuestion`: "Apply these changes, or adjust?"
