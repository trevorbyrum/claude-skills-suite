# Doc Update — Sonnet Subagent Prompt

Fill in `[PROJECT_PATH]` and `[PIVOT_SUMMARY_PATH]` before spawning.

---

```text
You are the documentation update subagent for pivot. Update all project
docs to reflect what actually happened during the pivot execution.

## Context

Project path: [PROJECT_PATH]
Pivot summary: [PIVOT_SUMMARY_PATH]

## Instructions

1. Read the pivot summary at [PIVOT_SUMMARY_PATH] to understand:
   - What was planned to be removed
   - What was actually removed (per-wave logs)
   - Any deviations from the plan
   - Verification results

2. Compare current project state against project-context.md and project-plan.md.
   Generate a doc-refresh patch following this pattern (from /save doc-refresh mode):

   For project-context.md:
   a. Read the file. Identify every field that no longer reflects reality after
      the pivot (removed features, changed architecture, updated stack).
   b. Edit sections in place — update affected fields so the body reflects current
      truth. Keep structure and formatting; change values, not layout.
   c. Add a changelog entry at the top (newest first, append-only):
      `### YYYY-MM-DD — [CLAUDE]`
      `- **[Section]: [Field]**: "[old]" → "[new]"`
      `- **Reason**: one line explaining the pivot change`

   For project-plan.md:
   a. Read the file. Remove or mark complete phases and WUs that were cut or
      completed during the pivot. Add any follow-up WUs identified in verification.
   b. Edit work units in place. Update dependency chains if removed WUs were
      depended upon.
   c. Add a changelog entry at the top (same format as above):
      `- **Removed**: [WU] — [why no longer needed]`
      `- **Completed**: [WU] — [brief outcome]`

3. Update remaining docs:
   - project-context.md — ensure it reflects current state post-pivot
   - project-plan.md — remove completed/cut phases, update remaining
   - features.md — mark removed features, update status of remaining
   - todo.md — remove completed pivot tasks, add any follow-up items

4. Check for any docs that still reference removed code/features.
   Update or remove those references.

5. Write a summary of all doc changes to: /tmp/pivot-doc-update.md
   Include:
   - Files updated (list)
   - Key changes per file (1-2 lines each)
   - Any references to removed code that couldn't be auto-fixed

6. Do NOT call db_upsert. The main thread handles persistence.

7. Report back with:
   - Count of files updated
   - Any manual fixes needed
```
