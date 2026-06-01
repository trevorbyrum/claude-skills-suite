# Execute — Single-WU Mode

Implement one named WU. No wave structure.

## When this mode triggers

- User invoked `/execute WU-N-M`
- User said "implement WU-N-M"
- User asked for "just one piece" of the plan and named it

## Prerequisite check

Before implementing:

1. Look up the WU in `project-plan.md`. If not found, stop and ask the user (typo or wrong WU id?).
2. Read the WU's `Dependencies` field. For each prerequisite WU:
   - Check the verdict log: `db_read 'execute' 'verdict' '<dep-WU-ID>'`
   - OR check the plan file for `[done]` markers on the dep
3. If any prerequisite is unstarted:
   - Surface to the user: "WU-X depends on WU-Y, which isn't done yet."
   - Ask via `AskUserQuestion`: "Implement WU-Y first, switch to linear mode, or skip the dep check and proceed anyway?"
   - Default to "implement WU-Y first" — the user can override.

## Context assembly

Same as linear mode (see `linear.md` § Context assembly per WU):
- WU's Key Files + closest imports
- `project-context.md`
- Recent iterate/save changelog entries
- Skip the rest of the codebase

## Implementation

Claude implements in main thread. Tests go alongside. Run acceptance criteria locally.

If a Sonnet helper is useful (devil's advocate, test coverage scan, doc lookup), spawn one. Otherwise stay in main thread.

## Acceptance verification

Run the WU's acceptance criteria. If pass:

```bash
source references/db.sh
db_write 'execute' 'verdict' '<WU-ID>' "PASS | <details>"
```

## Plan status update

Mark the WU `[done]` in `project-plan.md`. Add a one-line changelog entry.

## End

No wave gate (only one WU). After acceptance:

1. Show the user a single-WU completion summary (files touched, tests added, acceptance pass list).
2. Suggest: `/iterate` for follow-up tweaks, `/review` for a multi-lens check, `/save` (compact) to snapshot, or `/execute` (linear) to continue the plan.

## When to switch modes mid-WU

- WU turns out to be larger than the plan estimated (>5 files, >200 LOC actual): pause, surface to user, suggest re-scoping in `/build-plan` update mode.
- WU's acceptance criteria turn out to be unclear: pause, suggest `/build-plan` update mode to refine before continuing.
- WU is blocked by something not in the plan (env setup, external API): log the blocker, ask the user how to proceed.
