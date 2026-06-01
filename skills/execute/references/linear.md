# Execute — Linear Mode

Sequential WU implementation by wave. Default for most plans.

## Wave structure

Read `project-plan.md`'s work-units section. Group unstarted WUs by dependency:

- **Wave 1** — all WUs with zero unstarted dependencies
- **Wave 2** — WUs whose dependencies are all in Wave 1 (now done)
- **Wave N** — WUs whose dependencies are all in Waves 1..N-1

Wave gates between waves enforce the review + approval discipline. **Within a wave, default to parallel dispatch** per cross-cutting rule 11 — fan out via SKILL.md Phase 5 (one Sonnet subagent per independent WU, all in a single message). Only fall back to in-main-thread sequential when same-file collisions remain after clustering, or when an unfinished prereq forces ordering inside the wave.

## Context assembly per WU

For each WU, before implementing:

1. **Read only what's named** in the WU's "Key Files" + the closest 1-2 files those import from.
2. **Read `project-context.md`** for any constraints/decisions that affect this WU.
3. **Read recent context** from `iterate` or `save` changelog if the project is mid-session:
   ```bash
   source references/db.sh
   db_read_all 'iterate' 'changelog' | tail -10
   db_read 'save' 'compact' | head -100
   ```
4. **Skip the rest of the codebase.** Context stuffing degrades output quality.

Aim for 10k-50k tokens of curated context per WU.

## Implementation

Claude writes the code in main thread. Tests go in alongside the code (TDD-preferred for new behavior — write the failing test, then make it pass).

While implementing:
- Use the Edit tool for changes to existing files
- Use the Write tool for new files
- Read related files with the Read tool as needed
- Run tests + lint locally via Bash to verify acceptance criteria

If the WU's acceptance criteria call for a UI check, run the dev server and verify in browser (per CLAUDE.md global rules: "type checking and test suites verify code correctness, not feature correctness").

## When to spawn a Sonnet helper

Inside a single WU, Claude may dispatch a Sonnet subagent (`subagent_type: "general-purpose"`) for:

- **Devil's advocate**: a pre-implementation sanity check ("you're about to write X — is this the right approach?"). Useful for WUs that touch architectural seams.
- **Test coverage scan**: after writing the WU, ask a Sonnet subagent "what test cases is the user likely to ask about that aren't covered?"
- **Lookup**: search docs or examples for a library used in the WU.

These are helpers, not replacements. The Sonnet subagent returns findings as text; Claude integrates them into the implementation.

## Acceptance verification per WU

After implementing, run the WU's acceptance criteria locally:

- **Stub-detection grep gate** (run FIRST — fail fast on placeholders):
  ```bash
  grep -rn -E '// \.\.\.|TODO|FIXME|implement later|placeholder|not yet implemented' <WU's Key Files>
  ```
  Any hit on files this WU created or modified = automatic PARTIAL verdict, fix before moving on.
- Tests pass: `npm test` / `pytest` / `cargo test` / equivalent
- Lint: `npm run lint` / `ruff check` / `cargo clippy`
- Type-check: `tsc --noEmit` / `mypy` / `cargo check`
- Per-criterion checks listed in the WU

If any fail:
1. Try to fix in the same turn (small adjustments).
2. If multiple turns are needed: log `PARTIAL` verdict and continue iterating until PASS, then update the verdict.
3. **Budget cap (cross-cutting rule 10): 5 attempts max per WU.** When hit: log `FAIL` or `PARTIAL` with reason, surface to user. Do not silently retry beyond the cap.
4. If you get stuck before the cap (>3 turns on the same WU without progress), switch to `/iterate` stuck-recovery mode for that WU.

## Retry classification (when an attempt fails)

Before retrying, classify the failure:

- **Transient** — syntax error, type mismatch, missing import, off-by-one in test. The next attempt should include the error message in context and adjust narrowly.
- **Permanent** — architectural mismatch (your approach was wrong), missing prerequisite (the WU is blocked by something not in its dependencies), or acceptance criteria you can't satisfy with the current approach.

**Transient → retry with error context**, same prompt shape, narrowed change.
**Permanent → don't retry the same approach.** Surface to user; either re-scope the WU via `/build-plan` update or skip and continue.

Mixing these (retrying a permanent failure as if it were transient) is how a WU burns through the 5-attempt budget without progress.

## Per-WU verdict

```bash
source references/db.sh
db_write 'execute' 'verdict' '<WU-ID>' "$(cat <<EOF
Status: PASS | FAIL | PARTIAL
Files touched: <list>
Tests added: <count>
Acceptance: <pass/fail per criterion>
Notes: <anything notable>
EOF
)"
```

Append, don't upsert — the history matters for review-fix and resumability.

## Plan status update (in-place, light)

After a WU passes:
- Find the WU's row in `project-plan.md`'s work-units table.
- Append `[done]` to the title or mark the status column.
- Add a one-line entry to the plan's changelog: `- <date>: WU-N-M completed`.

This is an in-place edit. Snapshots happen at session boundaries via `/save`.

## End-of-wave actions

When all WUs in the current wave have a PASS verdict:

1. Move to SKILL.md Phase 4 (wave gate).
2. Don't proceed to the next wave without the user's approval.
