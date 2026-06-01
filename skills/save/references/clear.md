# Clear Mode

`/github-sync` → snapshot → review → `/clear`. Code gets pushed first so unpushed work doesn't vanish with the context.

## Step 1: Run /github-sync

Invoke `/github-sync` to commit and push all changes in the working tree.

1. Derive a commit message from session work, not "session end":
   - Bad: "session end"
   - Good: "feat: add JWT refresh rotation and Redis token store"
2. If the working tree is already clean and nothing to push, note "tree clean" and continue — don't fail.
3. If the push fails, **stop**. Resolve the issue or surface it to the user. Never `/clear` with unpushed work.

The commit message will be referenced in the snapshot below, so capture it.

## Step 2: Build snapshot

Same template as `references/compact.md` Step 1, with one addition: include the commit hash from Step 1 in "What Was Accomplished" and reference it in "Next Task Context" if relevant.

## Step 3: Write to DB (append-only)

```bash
source references/db.sh
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
db_write 'save' 'compact' "claude/$TIMESTAMP" "$COMPACT_CONTENT"
```

(Clear-mode snapshots live in the same label space as compact-mode snapshots — same `db_read_all 'save' 'compact'` retrieves both. The mode is encoded only in the body's commit-hash reference.)

## Step 4: Subagent review

1. Read the just-written snapshot:
   ```bash
   COMPACT=$(db_read 'save' 'compact' "claude/$TIMESTAMP")
   ```
2. Spawn a Sonnet subagent (`subagent_type: "general-purpose"`) for the compact review. For clear mode, the agent specifically checks:
   - **No references to uncommitted work.** If the snapshot mentions files that weren't in the commit, flag.
   - Resumability + actionable next steps as in compact mode.
3. Revise if needed (append, don't mutate).

## Step 5: Execute

Run `/clear`. The DB snapshot and the pushed commit are what survive.

## Why this order

Code gets pushed **first** because unpushed code in a cleared context is lost code — the next session won't have it in the working tree (different device, fresh clone) and won't know it ever existed.

The snapshot is stored **second** because it references the commit hash from the push.

The review happens **last** because it validates the whole chain — especially that the snapshot doesn't reference work that didn't make it into the push.

## Failure handling

- **Push rejected (non-fast-forward)**: `/github-sync` handles this with `AskUserQuestion`. Don't proceed with `/clear` until resolved.
- **Subagent review unavailable**: skip the review step, note in the snapshot body, proceed with `/clear`. Don't block on the review.
- **No remote configured**: `/github-sync` will surface this. Ask the user whether to skip the push (clear mode becomes snapshot-only) or set up a remote first.
