---
name: meta-context-save
description: "Save session state and optionally commit+clear. Use when the user asks to wrap up, save session, compact context, or end for the day."
argument-hint: "[--compact to compact only (default), --clear to commit+compact+clear]"
---

# Meta Context Save

Preserve session state before compacting or clearing context. Two modes:

- **Compact mode** (default / `--compact`): Assess state → store compact state → subagent review → correct → `/compact`
- **Clear mode** (`--clear`): GitHub sync → store compact state → subagent review → correct → `/clear`

## Mode Selection

| Trigger | Mode |
|---|---|
| `/meta-context-save` | Compact |
| `/meta-context-save --compact` | Compact |
| `/meta-context-save --clear` | Clear |
| "wrap up", "done for today" | Clear |
| "save session", "compact" | Compact |
| "start fresh", "new session" | Clear |

## Instructions

### Phase 0: GitHub Sync (Clear mode only)

1. **Invoke github-sync.** Commit and push all changes in the working tree.
2. **Derive the commit message from the session.** Summarize actual work — not "session end" but "feat: add JWT refresh rotation and Redis token store".
3. **Confirm the push succeeded** and the tree is clean before proceeding. If the push fails, resolve or report before continuing — do not clear context with unpushed work.

### Phase 1: Assess Current State

Before writing anything, take stock of:
- What task is currently active (or was just completed)
- What step of that task you're on
- What has been accomplished so far
- What remains to be done
- Any pending decisions or open questions
- Files currently being worked on (with absolute paths)
- Errors being debugged, including reproduction steps
- Any important context that would be expensive to re-derive

### Phase 2: Write Compact File (Append-Only)

Store the compact state in the artifact DB as an **append-only** record.
Each save is a snapshot — never overwrite previous snapshots. The PreCompact
hook also writes here, so multiple records accumulate per session.

```bash
source artifacts/db.sh
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
db_write 'meta-context-save' 'compact' "claude/$TIMESTAMP" "$COMPACT_CONTENT"
```

where `$COMPACT_CONTENT` is the full markdown compact state following the
template above. The `claude/` prefix scopes user-invoked saves; the
PreCompact hook writes lightweight git snapshots to a separate phase
(`meta-context-save/snapshot/{project}/{ISO-8601}`) — see
`hooks/pre-compact-save.sh`.

**Latest-snapshot lookup** (for tools that need to read the most recent
save instead of the full history):

```bash
LATEST_COMPACT=$(db_read_all 'meta-context-save' 'compact'  | jq -s 'sort_by(.label) | last | .content // empty' -r)
LATEST_HOOK=$(db_read_all 'meta-context-save' 'snapshot' | jq -s 'sort_by(.label) | last | .content // empty' -r)
```

`/iterate`'s Phase 1 session wake-up reads both and prefers the most
recent timestamp.

Construct `$COMPACT_CONTENT` using this template:

```markdown
# Session State — YYYY-MM-DD HH:MM

## What Was Accomplished
- [Concrete deliverable or milestone, not "worked on X"]
- [Include commit hashes if meaningful]

## Current Task
[What you're working on — specific enough to resume without re-reading the conversation]

## Progress
- [x] Step completed
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
[What should the next session pick up. Be specific: which work unit, what the first step is, any setup needed.]

## Pending / Open Questions
- [Anything unresolved that the user or next session needs to address]

## Gotchas Discovered
[Anything surprising that future sessions should know — API quirks, timing issues, environment-specific behavior]
```

### Be Specific, Not Generic

"Working on auth" is useless. "Implementing JWT refresh token rotation in `/opt/homelab-mcp-gateway/src/auth/tokens.ts` — access token generation works, refresh token storage in Redis not yet started, blocked on deciding TTL (user leaning toward 7 days)" lets the next window continue immediately.

Emphasize "What Was Accomplished" over "What Was Attempted." The next context window needs to know the current state, not the journey. If something was attempted and failed, note the failure and current state, not the attempt history.

Include absolute file paths. The next session may start in a different working directory.

### Phase 3: Subagent Review

1. **Read the just-written snapshot** before passing it to the subagent:

```bash
source artifacts/db.sh
COMPACT=$(db_read 'meta-context-save' 'compact' "claude/$TIMESTAMP")
```

**Spawn the `compact-reviewer` agent** (`subagent_type: "compact-reviewer"`) to review the compact state. Pass `$COMPACT` as the compact file contents in the prompt. The agent verifies:
   - Resumability — can the next context window pick up without re-reading the conversation?
   - Actionable next steps — is "Next Task Context" specific enough?
   - No references to uncommitted work (Clear mode)
   - No stale file paths or missing context

2. **Correct based on review.** If the snapshot has gaps, write a **revision**
   as a new append-only record — do NOT mutate the original timestamped record:

   ```bash
   REVISION_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   db_write 'meta-context-save' 'compact' "claude/$REVISION_TS" "$REVISED_CONTENT"
   ```

   The history is now: original snapshot → reviewer feedback → revised
   snapshot. Future sessions reading "latest" will get the revised one.

### Phase 4: Execute

- **Compact mode**: Execute `/compact`. The compact state in the DB is what survives.
- **Clear mode**: Execute `/clear`. The compact state in the DB and pushed code are what survive.

## Why Append-Only

Compact records are immutable snapshots, written with `db_write` and
timestamped labels (`claude/{ISO-8601}`, `hook/{ISO-8601}`,
`session-end/{ISO-8601}`).

Reasons (per 014D research):

- **Multiple writers**: the PreCompact hook, the SessionEnd hook (once
  shipped), and the user-invoked skill all write here. Overwrites would
  race and lose context.
- **Audit trail**: knowing what state the model thought it was in 3
  saves ago is sometimes the only way to debug a session that went off
  the rails.
- **Cheap**: SQLite + FTS5 makes per-snapshot rows trivial. Retention
  policy (drop snapshots >30 days, keep the last 10 regardless) is a
  later concern, not a write-time one.

Tools that want "the current state" read the latest label by sorting.
Tools that want "what happened this session" read all records since the
session-start timestamp.

## Why This Order (Clear mode)

Code gets pushed first because unpushed code in a cleared context is lost code — the next session won't have it in the working tree (if on a different device) and won't know it existed. The compact state is stored second because it needs to reference the commit. The review happens last because it validates everything.

## Examples

```
User: I'm done for today, wrap up
```
Clear mode. GitHub sync (commit and push). Store compact state in DB. Subagent review. Correct. Execute /clear.

```
User: /meta-context-save
```
Compact mode. Assess state, store compact state in DB, subagent review, correct, execute /compact.

```
User: /meta-context-save --clear
```
Clear mode. Full chain: github-sync → store compact state in DB → review → /clear.

```
User: switching to a different project
```
Clear mode. GitHub sync for current project. Store compact state in DB with emphasis on "Next Task Context" so returning is seamless. Review. Clear.

```
[Working tree is already clean, nothing to push — Clear mode]
```
Skip the push (note "working tree clean"). Store compact state in DB. Review. Clear. Do not fail just because there's nothing to commit — the session state still needs preserving.

---

Before completing, read and follow `references/cross-cutting-rules.md`.
