# Merge Checklist

Exhaustive checklist for sub-project merge operations. Each item has an action,
risk level, and rollback step. Used by Phase 2 when generating `merge-plan.md`.

## Pre-Merge Validation

| # | Check | Risk | Action | Rollback |
|---|-------|------|--------|----------|
| V1 | Sub-project has `architecture.md` | — | Read Section 11 (Parent Modifications) | Cannot proceed without it — ask user for modification list |
| V2 | Sub-project has `features.md` | — | Read feature names and statuses | Skip feature merge — log warning |
| V3 | Sub-project has `build-plan.md` | — | Read work unit statuses | Skip plan update — log warning |
| V4 | Parent has `features.md` | — | Read current feature table | Create features.md from template if missing |
| V5 | Parent has `project-plan.md` | — | Read current work units | Create project-plan.md from template if missing |
| V6 | No uncommitted changes in sub-project | LOW | `git status` in sub-project path | Prompt user to commit or stash first |
| V7 | No uncommitted changes in parent | LOW | `git status` in parent root | Prompt user to commit or stash first |
| V8 | Sub-project appears complete | — | Scanner checks for stubs, TODOs, in-progress features | Warn user, let them decide to proceed |

## Document Merge Operations

| # | Operation | Risk | Action | Rollback |
|---|-----------|------|--------|----------|
| D1 | Merge features.md | LOW | Append sub-project features; reconcile statuses | `git checkout -- features.md` |
| D2 | Update project-plan.md | LOW | Mark work units complete; add changelog | `git checkout -- project-plan.md` |
| D3 | Update project-context.md | LOW | Update Current State, Key Decisions, Tech Stack | `git checkout -- project-context.md` |
| D4 | Merge todo.md | LOW | Close completed items; add remaining | `git checkout -- todo.md` |
| D5 | Append cnotes.md | LOW | Chronological insert with `[sub:<name>]` tag | `git checkout -- cnotes.md` |

## Research Renumbering Operations

| # | Operation | Risk | Action | Rollback |
|---|-----------|------|--------|----------|
| R1 | Scan parent research folders | — | List `artifacts/research/[NNN]*` folders | — |
| R2 | Scan sub-project research folders | — | List `<sub>/artifacts/research/[NNN]*` folders | — |
| R3 | Calculate renumbering map | — | max(parent numbers) + 1, sequential | — |
| R4 | Copy research folders to parent | MEDIUM | Copy (not move) folder with new number | `rm -rf artifacts/research/<new-number>/` |
| R5 | Copy summary files to parent | MEDIUM | Copy with new number prefix | `rm artifacts/research/summary/<new-number>-*.md` |
| R6 | Update internal references | MEDIUM | Grep+replace old number → new number in copied files | Re-copy from sub-project (originals untouched) |
| R7 | Verify no gaps in parent numbering | — | List parent research folders after renumber | — |

## Artifact DB Operations

| # | Operation | Risk | Action | Rollback |
|---|-----------|------|--------|----------|
| A1 | Read sub-project DB schema | — | `sqlite3 <sub>/artifacts/project.db ".schema"` | — |
| A2 | Verify schema compatibility | LOW | Compare table structure with parent DB | Skip DB merge if incompatible — log warning |
| A3 | Prefix skill field | — | `sub:<name>/` prepended to every skill value | — |
| A4 | Apply renumbering to labels | — | Replace research numbers in label field per map | — |
| A5 | INSERT records into parent DB | MEDIUM | Bulk INSERT, not UPSERT | `DELETE FROM artifacts WHERE skill LIKE 'sub:<name>/%'` |
| A6 | Rebuild FTS index | LOW | Drop+recreate triggers and FTS table | Re-run `db_init` from `artifacts/db.sh` |

## Code Transfer Operations

| # | Operation | Risk | Action | Rollback |
|---|-----------|------|--------|----------|
| C1 | Copy new files to parent | MEDIUM | Copy files to destinations from Section 11 | `rm` the copied files |
| C2 | Modify existing parent files | HIGH | Apply sub-project changes to existing files | `git checkout -- <file>` |
| C3 | Resolve conflicts | HIGH | Present to user for manual resolution | `git checkout -- <file>` |

## Cleanup Operations

| # | Operation | Risk | Action | Rollback |
|---|-----------|------|--------|----------|
| K1 | Remove symlinks | LOW | `rm` each symlink (targets in parent are untouched) | Re-create symlinks (but why?) |
| K2 | Archive sub-project | LOW | `mv <sub>/ artifacts/archived-sub-projects/<name>/` | `mv` it back |
| K3 | Remove broken symlinks from archive | LOW | `find artifacts/archived-sub-projects/<name>/ -type l -delete` | — |
| K4 | Remove worktree | MEDIUM | `git worktree remove <path>` | `git worktree add <path> sub/<name>` |
| K5 | Delete branch | MEDIUM | `git branch -d sub/<name>` (safe — only if merged) | `git branch sub/<name> <commit-hash>` |

## Post-Merge Validation

| # | Check | Action |
|---|-------|--------|
| P1 | No broken refs to sub-project path | Grep parent docs for sub-project directory name |
| P2 | Research numbering is continuous | List parent research folders, check sequence |
| P3 | No duplicate feature rows | Check features.md for duplicate names |
| P4 | No stale plan dependencies | Check project-plan.md for refs to sub-project |
| P5 | DB record count matches | Compare expected vs actual `sub:<name>/%` records |
| P6 | No orphaned files | Glob for files referencing sub-project that shouldn't |
