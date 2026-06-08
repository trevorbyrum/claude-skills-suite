# Meta-Skill Guards

Shared timeout and stall-detection rules for `/init`'s multi-phase paths. These keep long-running interactive flows from deadlocking or losing state.

## Timeout values (subagent dispatch)

| Operation | Timeout | Notes |
|---|---|---|
| Sonnet scaffold subagent | 180s | Scaffolding is bounded — file writes only |
| Sonnet context-write subagent | 240s | Drafting synthesis from interview notes |
| Sonnet adversarial-review subagent (pivot) | 180s | Reading existing docs + categorizing |
| Sonnet research worker subagents | 1200s (20 min) | Time-box each worker; main orchestrator waits |
| Inline interview | No timeout | User-paced |

If a subagent exceeds its timeout, save partial output (if any) to `artifacts/init-<phase>-partial.md` and surface to the user. Don't retry automatically.

## Stall detection (interactive phases)

For inline interviews and approval gates:

- **5 min user-quiet**: continue waiting, no action.
- **30 min user-quiet**: save state, exit. Tell the user "I've saved progress. Resume with `/init` — I'll pick up where we left off."

State save format:
```bash
source references/db.sh
db_upsert 'init' 'partial-state' "$PHASE" "$STATE_JSON"
```

When `/init` runs again and detects existing partial state:
- Read `db_read 'init' 'partial-state' <phase>`
- Ask via `AskUserQuestion`: "Resume from <phase>, or start over?"

## Phase ordering (cross-pathway invariants)

These apply across greenfield, join-existing, sub-project, and pivot:

1. **Vault writes happen AFTER context approval.** Never write a draft context to the vault — only the user-approved version.
2. **DB init happens BEFORE any `db_*` call.** Phase 4 of SKILL.md handles this idempotently.
3. **Final decision gate happens LAST.** No "what next" prompt before plan approval.

## Resume detection

If `/init` runs on a project that already has `project-context.md` but lacks `project-plan.md`:
- It's not exactly any of the four pathways.
- Run `detect-state.sh` returns `ambiguous`.
- Ask via `AskUserQuestion`: "Looks like context exists but no plan. Resume from build-plan, or full re-init?"

If `/init` runs on a project that has both context and plan:
- Detect mode returns `ambiguous` or `pivot` (depending on hints).
- Default: ask whether the user wants pivot mode, or whether they meant `/save` doc-refresh, or `/build-plan` update.

## Cleanup on cancellation

If the user cancels mid-flow (Ctrl-C, exit, etc.):
- Partial files (`artifacts/init-*-partial.md`) stay — they're the resume state.
- Vault writes that happened DON'T get rolled back automatically. The user can manually `rm -rf` the vault folder if they want to start over.
- DB state stays. `db_init` is idempotent so re-running is fine.

Do NOT auto-rollback. The user is the source of truth on whether to keep partial work.
