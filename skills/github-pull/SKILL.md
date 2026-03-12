---
name: github-pull
description: "Pulls latest changes from remote. Use at session start or when user says 'pull', 'update', or 'get latest'."
argument-hint: "[--rebase to rebase instead of merge, --stash to auto-stash dirty tree]"
---

# GitHub Pull

Pull latest changes from the remote for the current branch. Designed for session-start sync.

## Instructions

1. **Check prerequisites.** Run `git status` to see if the tree is clean or dirty.
   - If dirty and `--stash` was passed (or invoked by another skill), run `git stash push -m "github-pull auto-stash"` first.
   - If dirty and no `--stash` flag, warn the user and ask whether to stash, commit first, or abort.

2. **Fetch.** Run `git fetch --prune` to get latest refs and clean up deleted remote branches.

3. **Pull.**
   - Default: `git pull --ff-only`. This is the safest — it only succeeds if the local branch can fast-forward.
   - If `--rebase` was passed: `git pull --rebase`.
   - If fast-forward fails (diverged history), report the situation and ask the user: rebase, merge, or abort.

4. **Pop stash.** If changes were stashed in step 1, run `git stash pop`. If the pop conflicts, report it and let the user resolve.

5. **Report.** Show:
   - Branch name and tracking remote
   - Number of new commits pulled (from fetch/pull output)
   - `git log --oneline -5` to show what came in
   - Current `git status`

## Examples

```
User: /github-pull
```
Check tree, fetch, fast-forward pull, report new commits.

```
User: pull latest
```
Same as above.

```
User: /github-pull --rebase --stash
```
Stash dirty tree, fetch, rebase pull, pop stash, report.

```
[Dirty working tree, no flags]
```
Warn user: "You have uncommitted changes. Stash them (`--stash`), commit first (`/github-sync`), or abort?"

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
