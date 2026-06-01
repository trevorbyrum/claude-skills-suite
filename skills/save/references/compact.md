# Compact Mode

Snapshot → review → `/compact`. No git operations.

## Step 1: Build snapshot

Take stock before writing:
- What task is currently active (or was just completed)
- What step of that task you're on
- What was accomplished this session
- What remains to be done
- Pending decisions, open questions
- Files being worked on (absolute paths)
- Active debugging — error + what you tried + current suspicion

Use this template:

```markdown
# Session State — YYYY-MM-DD HH:MM

## What Was Accomplished
- [Concrete deliverable or milestone, not "worked on X"]
- [Include commit hashes if meaningful]

## Current Task
[What you're working on — specific enough to resume without re-reading the conversation]

## Progress
- [x] Step completed
- [ ] **Current step** — [where you are in this step]
- [ ] Remaining step

## Key Decisions Made
- [Decision]: [rationale] — [alternatives considered if non-obvious]

## Files Created / Modified
- `/absolute/path/to/file.ts` — [what was done to it]

## Active Debugging
[If debugging: the error, what you've tried, what you suspect, reproduction steps]
[If not debugging: omit this section]

## Next Task Context
[What should the next session pick up. Specific WU, first step, any setup needed.]

## Pending / Open Questions
- [Anything unresolved]

## Gotchas Discovered
[API quirks, timing issues, environment-specific behavior worth surfacing]
```

### Be specific, not generic

"Working on auth" is useless. "Implementing JWT refresh rotation in `src/auth/tokens.ts` — access generation works, Redis refresh-token storage not started, blocked on TTL (user leaning 7 days)" lets the next window resume immediately.

Emphasize "What Was Accomplished" over "What Was Attempted." Use absolute paths.

## Step 2: Write to DB (append-only)

```bash
source references/db.sh
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
db_write 'save' 'compact' "claude/$TIMESTAMP" "$COMPACT_CONTENT"
```

The `claude/` prefix scopes user-invoked saves. The PreCompact hook writes to a separate phase (`save/snapshot/<ISO-8601>`) — same DB, different label space.

## Step 3: Subagent review

1. Read the just-written snapshot:
   ```bash
   COMPACT=$(db_read 'save' 'compact' "claude/$TIMESTAMP")
   ```
2. Spawn a Sonnet subagent (`subagent_type: "general-purpose"`) for the compact review with `$COMPACT` as the input. The agent checks:
   - Resumability — can the next window pick up without re-reading the conversation?
   - Actionable next steps — is "Next Task Context" specific enough?
   - No stale file paths or missing context
3. If the review finds gaps, write a **revision** as a new append-only record:
   ```bash
   REVISION_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   db_write 'save' 'compact' "claude/$REVISION_TS" "$REVISED_CONTENT"
   ```
   Never mutate the original. Future "latest snapshot" lookups sort by label and get the revised one.

## Step 4: Execute

Run `/compact`. The DB snapshot is what survives compaction.

## Why append-only

Multiple writers touch this phase (the PreCompact hook, the SessionEnd hook, the user-invoked skill). Overwrites would race and lose context. Append-only with timestamped labels makes "latest" a simple sort.

The audit trail also matters: "what state did the model think it was in three saves ago" is sometimes the only way to debug a session that went off the rails.
