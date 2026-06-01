---
name: save
description: Saves session state, optionally commits and clears. Refreshes project-plan status and snapshots to the local artifact DB. Invoke with /save or when user says "wrap up", "save session", "done for today", or "compact".
disable-model-invocation: true
argument-hint: "[compact | clear | update docs]"
---

# Save

Preserve session state before compacting or clearing context. Refreshes `project-plan.md` status if work was completed during the session. Two end-states:

- **Compact** (default) — snapshot to DB, then `/compact`
- **Clear** — `/github-sync` → snapshot to DB → `/clear`

A heavy doc-refresh (full evolve-style architecture or scope rewrite) is on-demand only.

## Inputs

- Current session state (what was done, what's open, files touched)
- `project-plan.md`, `project-context.md` in repo root
- Prior `compact` records in artifact DB
- Git working tree state

## Outputs

- `db_write 'save' 'compact' 'claude/<ISO-8601>' "$COMPACT_CONTENT"` — append-only snapshot
- Updated `project-plan.md` status section (light) or both docs (heavy refresh)
- `/compact` or `/clear` executed at the end

## Instructions

### Phase 0: Detect mode

Detect from the user's words:

| Trigger | Mode |
|---|---|
| `/save` (no args) | compact |
| "compact", "save session" | compact |
| "wrap up", "done for today", "switching projects", "clear" | clear |
| "update docs", "sync docs", "evolve" | heavy refresh → ask: compact or clear after? |

If ambiguous → `AskUserQuestion`: "Compact only, or commit + clear?"

> **HARD GATE (clear mode only) — WAIT FOR USER RESPONSE before any /github-sync or /clear.** Clear-mode loses the conversation context; the user must explicitly accept that before any commit or clear runs. Compact mode does not need this gate (recoverable).

### Phase 1: Doc refresh (light by default)

Run the light path inline. Heavy path only if user explicitly asked for doc update.

**Light refresh:**

1. **Detect completed work since last save.** Compare:
   - Latest `db_read_all 'iterate' 'changelog'` entries (if `/iterate` ran)
   - Git log since last `save` compact label timestamp
   - Files modified in this session
2. **Update `project-plan.md` status section.** Mark completed work units; add a one-line changelog entry at top:
   ```
   - YYYY-MM-DD: completed WU-N, WU-N+1; in progress: WU-N+2
   ```
3. **Update `project-context.md` only if** a Key Decision changed in this session (rare). Otherwise leave alone.
4. **Skip if** no work units completed and no decisions changed.

**Heavy refresh** (user asked explicitly): Read `references/doc-refresh.md`.

### Phase 2: Branch to compact or clear

- **Compact mode** → read `references/compact.md`
- **Clear mode** → read `references/clear.md`

Both reference files cover: snapshot template, DB write, subagent review, and the terminal `/compact` or `/clear`.

## DB Namespace Contract

All snapshots written by `/save` and its hooks share the `save` skill namespace:

| Writer | skill | phase | label pattern |
|---|---|---|---|
| User-invoked compact (this skill) | `save` | `compact` | `claude/<ISO-8601>` |
| PreCompact hook | `save` | `snapshot` | `hook/<ISO-8601>` |

`/iterate` Phase 1 reads `save/compact` and `save/snapshot` for session-wake context.

**Legacy backwards-compat:** Sessions saved before the `meta-context-save` → `save` rename are stored under the `meta-context-save` namespace. `/iterate` falls back to that namespace if `save/compact` or `save/snapshot` returns empty — no data loss from the migration.

## References (on-demand)

- `references/compact.md` — snapshot template, DB write, subagent review, `/compact`
- `references/clear.md` — same chain plus prepended `/github-sync`, ends with `/clear`
- `references/doc-refresh.md` — heavy evolve-style refresh (research gate, discussion, cross-check). Use only when the user asks explicitly.

## Examples

```
User: /save
→ Compact mode. Phase 1 light-updates plan status. Phase 2 reads compact.md:
  snapshot, review, /compact.
```

```
User: I'm done for the day
→ Clear mode. Phase 1 light-updates. Phase 2 reads clear.md:
  /github-sync → snapshot → review → /clear.
```

```
User: update docs, we switched from REST to GraphQL
→ Heavy refresh. Phase 1 reads doc-refresh.md: optional research → discussion
  → context update → plan update → cross-check. Then ask: compact or clear?
  Then continue to Phase 2.
```

```
User: switching to a different project
→ Clear mode. Phase 1 light-updates current project (emphasis on
  "Next Task Context" in the changelog entry so returning is seamless).
  Phase 2 reads clear.md.
```

```
User: /save (working tree is clean, no work done)
→ Compact mode. Phase 1 skips (nothing changed). Phase 2 writes a minimal
  snapshot ("session was read-only, no changes"). /compact.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
