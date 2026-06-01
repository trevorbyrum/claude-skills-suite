---
name: github-sync
description: Syncs working tree with GitHub remote. Detects whether to pull, push, or both from git state and acts accordingly. Invoke with /github-sync or when user says "commit", "push", "pull", or "sync to GitHub".
argument-hint: "[<commit message>]"
---

# GitHub Sync

Commit and push local changes, pull remote changes, or both — auto-detected from the current git state. No flags. The working tree is left clean and in sync with origin.

## Inputs

- Current git working tree (status, diff, branch, remote)
- User-provided commit message (optional, parsed from invocation)

## Outputs

- Clean working tree, synced with origin
- Commit hash + branch + remote URL reported to user

## Instructions

### Phase 0: Detect mode

Run these in parallel:

```bash
git status --porcelain                              # any local changes?
git fetch --prune --quiet 2>/dev/null               # --prune removes deleted remote-tracking branches
git rev-list --left-right --count @{u}...HEAD 2>/dev/null   # remote-ahead / local-ahead counts
```

Branch on the result:

| Local dirty | Local ahead | Remote ahead | Mode | Action |
|---|---|---|---|---|
| no | 0 | 0 | clean | Report "already in sync" and exit |
| no | 0 | >0 | pull-only | Go to Phase 3 |
| yes | * | 0 | push-only | Phases 1, 2, 3 |
| yes | * | >0 | both | Ask user via `AskUserQuestion`: "Local and remote both have changes. Rebase local on remote then push, OR pull --no-rebase merge then push?" |
| no | >0 | 0 | push-only | Phases 2, 3 (no staging needed) |
| no | >0 | >0 | both | Same `AskUserQuestion` as above |

If branch has no upstream (`@{u}` resolution fails), treat as push-only and set upstream during Phase 3.

### Phase 1: Stage and commit (if local dirty)

1. Run `git add -A`. If the user specified files in their invocation, stage only those.
2. Run `git diff --cached --stat`. If >20 files or >500 lines, show the summary and confirm via `AskUserQuestion` before continuing.
3. Determine commit message:
   - If user passed one in the invocation, use it verbatim.
   - Otherwise generate a conventional-commit message (`feat:` / `fix:` / `chore:` / `docs:` / `refactor:` / `test:`) from the staged diff. Keep subject ≤ 72 chars.
   - Show the message and ask via `AskUserQuestion`: "Use this message, or rewrite?" — three options: accept / edit / cancel.
4. Run `git commit -m "<message>"`.

### Phase 2: Push

1. If the current branch has no upstream: `git push -u origin <branch>`.
2. Otherwise: `git push`.
3. If push is rejected (non-fast-forward): ask via `AskUserQuestion` how to proceed — rebase, merge, or cancel. **Never force-push without explicit confirmation.**

**On `--amend` requests**: If the user explicitly asks to amend (e.g., "amend the last commit"), only proceed if the previous commit has NOT been pushed (check `git log @{u}..HEAD` — if non-empty, amending is local-only and safe). If the commit IS already on the remote, refuse and explain: amending pushed commits requires force-push, which the cross-cutting rules (and global CLAUDE.md) flag as needing explicit user authorization. Surface the choice; never force-push unprompted.

### Phase 3: Pull (if remote ahead and local clean — or after rebase/merge resolution)

1. **Auto-stash dirty tree (pull-only edge case)**: If the user explicitly invoked a pull but the working tree has uncommitted changes (e.g., they meant `pull --rebase` but forgot to commit first), auto-stash:
   ```bash
   git stash push -m "github-sync auto-stash $(date -u +%Y-%m-%dT%H:%M:%SZ)"
   ```
   Pop after the pull (`git stash pop`); if the pop has conflicts, surface them and tell the user where the stash lives (`git stash list`).
2. Run `git pull --rebase` (default) or `git pull --no-rebase` if the user chose merge in Phase 0.
3. If conflicts surface: stop and surface them. Don't attempt automatic resolution.
4. After resolving + committing, return to Phase 2 if local is now ahead.

### Phase 4: Verify and report

1. Run `git status` — working tree must be clean.
2. Report:
   - Commit hash (if a new commit was made)
   - Branch
   - Remote URL
   - Direction synced (pushed N commits / pulled N commits / both)

### Phase 5: Memory sync (cross-cutting rule 5)

After a successful push (pulls do not trigger memory writes), write a commit-log entry to the local memory store:

```bash
source references/db.sh
PROJECT=$(basename "$(git rev-parse --show-toplevel)")
COMMIT=$(git rev-parse --short HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
FILES=$(git diff --stat HEAD~1 HEAD | tail -1 | awk '{print $1}')
SUMMARY="Pushed ${COMMIT} on ${BRANCH}: ${FILES} files changed. $(git log -1 --pretty=%s)"
db_write 'memory' 'github-sync' "commit-log,${PROJECT}" "$SUMMARY"
```

**Dedup**: if a fresh entry (<24h) exists for the same project/branch, `db_upsert` instead of `db_write` to update rather than duplicate.

**Optional MCP mirror**: if a memory MCP is configured in this session, the main thread may also call its `store_memory` (or `memory_call` gateway) tool with the same payload — best-effort, silent on failure.

## Examples

```
User: /github-sync
→ Phase 0 detects: local dirty, remote up-to-date.
  Phase 1 generates "feat: add /github-sync skill", asks to confirm message.
  Phase 2 pushes. Phase 4 reports clean tree and commit hash.
```

```
User: pull latest from origin
→ Phase 0 detects: clean tree, remote 3 commits ahead.
  Phase 3 runs `git pull --rebase`. Phase 4 reports 3 commits pulled.
```

```
User: sync
→ Phase 0 detects: local 2 ahead, remote 1 ahead.
  AskUserQuestion → user picks "rebase".
  Phase 3 rebases, Phase 2 pushes.
```

```
User: commit "fix: null deref in auth handler" and push
→ Phase 1 uses provided message verbatim, no AskUserQuestion for confirmation.
  Phase 2 pushes.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
