# Iterate — Stuck-Recovery Mode

For when you've been chasing the same problem for a while and the loop is tightening rather than converging.

## Goal capture (two questions, not one)

1. **"What's the symptom?"** — the visible problem you're trying to fix.
2. **"What have you tried?"** — at least 3 things, even if vague. The act of listing breaks the tunnel.

Capture both into the changelog GOAL entry. The "tried" list becomes context for Sonnet subagent help if you escalate.

## Checklist shape (4-6 bullets, premortem-heavy)

Generated from goal:

1. **List failed approaches** — write out the attempts; tag each "rejected because" + "rejected based on" (evidence vs guess)
2. **Premortem** — "if my next attempt also fails, what would the cause be?" Answer this BEFORE the next attempt
3. **Pick a fresh angle** — based on (1) and (2), what's a different vector? Examples:
   - Different layer (the bug is in the test setup, not the code)
   - Different assumption (the failing case isn't actually what's failing)
   - Different scope (try a smaller repro and grow it)
4. **Time-box the next attempt** — 30 min or N file edits. If the attempt fails, run a review lens before the next try.
5. **Optional escalation** — spawn a Sonnet subagent (`subagent_type: "general-purpose"`) with the "what have I tried" log as context and ask for a devil's advocate read.

## Review threshold

Lower than other modes: offer `/review` after **3 file modifications** OR **2 commits** in this iteration.

Rationale: in stuck mode, a review lens is most valuable BEFORE the loop tightens further. The threshold drops to catch you at attempt 3 instead of attempt 6.

## What goes wrong in stuck mode

- **More attempts of the same approach**: the symptom is "I tried the thing again with a different parameter." That's not a fresh angle — it's the same angle with noise.
- **Skipping the premortem**: jumping to the next attempt without articulating what would make it fail. The premortem is the discipline.
- **Refusing to escalate**: solo-dev pride. A Sonnet subagent read is cheap and the changelog already has all the context it needs.
- **Hidden assumption**: the bug is actually in a place you've ruled out. The "rejected based on" tag (evidence vs guess) surfaces this — anything rejected on a guess deserves a second look.

## Mid-mode mode-switch

If during stuck mode you realize the original goal was wrong (e.g., "this isn't a bug, the spec is unclear"), don't pretend. Update the checklist, append a changelog entry noting the pivot, and either:
- Continue in `/iterate` with a new goal (re-run Phase 2 in the SKILL.md flow), or
- Exit `/iterate` and run `/build-plan` (update mode) to capture the spec ambiguity.
