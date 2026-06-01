# Iterate — Bug-Fix Mode

Default shape for fixing a known bug or regression.

## Goal capture template

Single question, capture in 1-2 sentences. Should include:
- **What's broken** (visible symptom)
- **When it broke** (if known — last working commit, recent change)

Examples:
- "Pagination shows wrong page after deleting an item. Started after PR #142."
- "Email validation rejects valid `+tag` addresses. Always has?"

## Checklist shape (3-5 bullets)

Generated from goal:

1. **Reproduce** — write a minimal repro case (failing test, manual steps, or both)
2. **Locate** — find where the wrong behavior originates (grep, git blame, debugger)
3. **Fix** — apply the change
4. **Verify** — repro now passes
5. **Guard against regression** — add or strengthen a test if one didn't exist

Adapt — small bugs may collapse 1-2 into a single step; subtle bugs may add "isolate by bisect" between 2 and 3.

## Review threshold

Offer `/review tests` or `/review refactor` after **5 file modifications** OR **3 commits** in this iteration.

Rationale: bug fixes that touch >5 files often indicate the original bug was a symptom of structural problem. A review lens at that point catches whether the fix is patching a symptom vs. addressing the cause.

## What goes wrong in bug-fix mode

- **Symptom-fixing**: changing the visible output without understanding why. The changelog should record *why* the original code was wrong, not just what was changed.
- **Scope creep**: noticing "while we're in here" things and fixing them too. Add them to the checklist and finish the bug first, then loop back.
- **No repro**: skipping step 1 because "I see the bug." If there's no test, future regression is invisible.
