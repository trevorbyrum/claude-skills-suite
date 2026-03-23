# Sub-Project Merge — Build Plan

> Last updated: 2026-03-22
> Status: planning
> Based on: sub-project/SKILL.md, 008D research, meta-init structure analysis

## Executive Summary

Build a `sub-project-merge` skill that merges completed sub-projects back into their parent project. The skill generates a merge-specific build plan at runtime (what goes where, renumbering, conflict resolution), presents it for approval, then executes in safety-tiered batches. Handles research artifact renumbering, document reconciliation, artifact DB merge, symlink cleanup, git worktree teardown, and parent doc updates.

## Phases

### Phase 1: Core Skill — Discovery & Merge Plan Generation
- **Goal**: Skill can scan a sub-project, analyze what needs merging, and generate a runtime merge plan for user approval
- **Milestone**: Running `/sub-project-merge <path>` on a test sub-project produces a merge-plan.md with renumbering map, document diff preview, and conflict list
- **Dependencies**: None — greenfield

### Phase 2: Document Reconciliation & Research Renumbering
- **Goal**: Agents that merge features.md, project-plan.md, project-context.md, todo.md, cnotes.md into root, and renumber research artifacts
- **Milestone**: Sub-project research `001D` correctly becomes root `010D` (or next available); root features.md contains sub-project features marked done; root project-plan.md reflects completed work units
- **Dependencies**: Phase 1 complete

### Phase 3: Artifact DB Merge, Code Transfer & Cleanup
- **Goal**: Merge artifact DB records, move source files, remove symlinks, tear down worktrees, clean up sub-project directory
- **Milestone**: A full end-to-end merge: sub-project created → worked on → merged back → cleaned up → no orphaned artifacts, broken refs, or stale symlinks
- **Dependencies**: Phase 2 complete

## Technical Approach

### Skill Architecture

Standard suite pattern:
- **SKILL.md**: Main instructions (~350 lines, 7 phases)
- **references/**: merge-checklist.md (exhaustive checklist), renumbering-protocol.md (research artifact renumbering rules)
- **agents/**: scanner.md (discovery), doc-merger.md (document reconciliation), db-merger.md (artifact DB merge)

### Context-Window Strategy

Maximize subagent delegation. Only Phase 3 (merge plan approval) and Phase 6 (destructive confirmation) stay inline:

```
Phase 0: Detect sub-project       [I]  — identify path, mode (directory vs worktree)
Phase 1: Scan sub-project         [S]  — Sonnet inventories everything
Phase 2: Generate merge plan      [I]  — build merge-plan.md, present for approval
Phase 3: User approval gate       [I]  — user reviews and approves/modifies
Phase 4: Safe merges              [S]  — document reconciliation, research renumbering
Phase 5: Risky merges             [S]  — artifact DB merge, code file transfer
Phase 6: Destructive cleanup      [I]  — confirm, then remove symlinks/dirs/worktrees
```

### Runtime Merge Plan (Key Design Decision)

The skill does NOT blindly merge. It generates a `merge-plan.md` at runtime that is specific to THIS merge operation, containing:

1. **Inventory** — every file in the sub-project, categorized (source code, docs, research, artifacts, symlinks, generated)
2. **Research renumbering map** — `sub:001D → root:010D`, `sub:002 → root:011`
3. **Document merge diffs** — preview of what will change in root features.md, project-plan.md, project-context.md, todo.md
4. **Code file destinations** — where each source file lands in the parent (from architecture.md Section 11: "Parent Modifications")
5. **Conflict detection** — files that exist in both sub-project and parent with different content
6. **Artifact DB records** — count of records to merge, namespace conflicts
7. **Cleanup plan** — symlinks to remove, directories to delete, worktree teardown steps
8. **Estimated risk** — LOW (docs only), MEDIUM (code + docs), HIGH (shared types/APIs modified)

User approves this plan before any changes happen. This IS the build plan the skill creates for the merge itself.

### Research Artifact Renumbering Protocol

This is the trickiest part. Rules:

1. Scan root `artifacts/research/` for all existing numbered folders (e.g., `001D` through `009`)
2. Extract the highest number (ignoring `D` suffix): `max = 9`
3. Scan sub-project `artifacts/research/` for its numbered folders (e.g., `001D`, `002`)
4. For each sub-project research folder, in order:
   - Assign next root number: `sub:001D` → `root:010D` (preserves D suffix)
   - Assign next: `sub:002` → `root:011` (no D = no D)
5. Renumber:
   - Rename folder: `sub-project/artifacts/research/001D/` content → `root/artifacts/research/010D/`
   - Rename summary: `sub-project/artifacts/research/summary/001D-topic.md` → `root/artifacts/research/summary/010D-topic.md`
   - Update internal references within the research files (grep for old number, replace)
6. Update artifact DB records: change `label` field from `001D` to `010D` for all matching records

### Document Reconciliation Rules

Each root document has specific merge behavior:

| Document | Merge Strategy |
|----------|---------------|
| `features.md` | Append sub-project features to root table. Status from sub-project wins (if sub says "done", root says "planned" → becomes "done"). Add "from sub-project: X" in Notes column |
| `project-plan.md` | Mark sub-project-related work units as complete in root plan. Add changelog entry. If sub-project created new work (discovered during build), add those as new WUs |
| `project-context.md` | Update "Current State" section. Add Key Decisions from sub-project. Update Tech Stack if sub-project introduced new deps. Append changelog |
| `todo.md` | Merge: completed items from sub-project close matching root items. New uncompleted items from sub-project get added to root |
| `cnotes.md` | Append all sub-project notes to root cnotes.md (maintain chronological order, newest first). Prefix with `[sub:<name>]` tag |
| `coterie.md` | No merge — it's a symlink. Just remove the symlink |
| `architecture.md` | Sub-project's is discarded (it was a distillation). No merge needed |
| `build-plan.md` | Sub-project's is discarded (it was sub-project-scoped). Completion logged in root project-plan.md |
| `CLAUDE.md` / `rules/` | Sub-project's is discarded unless user flags rules to promote to root |

### Artifact DB Merge

1. Open both databases: root `artifacts/project.db` and sub-project `artifacts/project.db`
2. For each record in sub-project DB:
   - Prefix the `skill` field with `sub:<name>/` to maintain provenance (e.g., `research-execute` → `sub:auth-service/research-execute`)
   - Apply research renumbering to `label` field where applicable
   - INSERT into root DB (no UPSERT — preserve sub-project records alongside root records)
3. Rebuild FTS index on root DB

### Symlink & Cleanup Protocol

Safety-tiered:

**Batch A (Safe — no data loss):**
- Remove symlinks: coterie.md, .eslintrc, .prettierrc, .editorconfig, design tokens, artifacts/db.sh
- These point to parent files that still exist — removing the symlink is safe

**Batch B (Moderate — data moved, not deleted):**
- Move source files to parent destinations (per merge plan)
- Move research artifacts (renumbered) to parent
- Merge artifact DB records

**Batch C (Destructive — requires confirmation):**
- Delete sub-project directory
- Remove git worktree: `git worktree remove <path>`
- Delete branch: `git branch -d sub/<name>` (only if merged)

### Git Worktree Handling

If sub-project uses worktree mode:
1. Ensure all sub-project changes are committed
2. Switch to main branch in main worktree
3. Merge: `git merge sub/<name>` (or rebase if user prefers)
4. Resolve conflicts if any (present to user)
5. Remove worktree: `git worktree remove <path>`
6. Delete branch: `git branch -d sub/<name>`

If subdirectory mode:
1. Move files to final parent locations (per merge plan)
2. `git add` the moved files
3. Commit the merge

## Work Unit Decomposition

| ID | Unit | Phase | Parallel? | LOC Est | Key Files | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|---------|-----------|--------------|---------------------|
| WU-1-01 | Skill directory scaffold | 1 | yes | ~40 | `skills/sub-project-merge/SKILL.md` (skeleton), `skills/sub-project-merge/references/`, `skills/sub-project-merge/agents/` | none | Directory tree exists; SKILL.md has valid frontmatter |
| WU-1-02 | Merge checklist reference | 1 | yes | ~100 | `skills/sub-project-merge/references/merge-checklist.md` | none | Exhaustive checklist covering: inventory, renumbering, doc merge, DB merge, code transfer, symlink cleanup, worktree teardown, validation. Each item has action, risk level, and rollback step |
| WU-1-03 | Renumbering protocol reference | 1 | yes | ~80 | `skills/sub-project-merge/references/renumbering-protocol.md` | none | Step-by-step protocol for research artifact renumbering. Covers: folder scan, number calculation, folder rename, summary rename, internal ref update, DB label update. Includes edge cases (no research, gaps in numbering, D vs non-D) |
| WU-1-04 | Scanner agent prompt | 1 | yes | ~120 | `skills/sub-project-merge/agents/scanner.md` | none | Sonnet subagent prompt; scans sub-project directory tree; categorizes every file (source, doc, research, artifact, symlink, generated); reads architecture.md Section 11 for parent modifications; reads features.md for completion status; outputs structured inventory JSON to temp file |
| WU-1-05 | SKILL.md Phases 0-3 (Discovery → Approval) | 1 | no | ~200 | `skills/sub-project-merge/SKILL.md` | WU-1-01 thru WU-1-04 | Phase 0 detects sub-project path and mode. Phase 1 dispatches scanner [S]. Phase 2 generates merge-plan.md from scan results (inline). Phase 3 presents plan, gets user approval [I]. merge-plan.md contains renumbering map, doc diffs, code destinations, conflicts, risk level |
| WU-2-01 | Doc merger agent prompt | 2 | yes | ~150 | `skills/sub-project-merge/agents/doc-merger.md` | WU-1-05 | Sonnet subagent prompt; receives merge-plan.md + both project roots; merges features.md (append rows, status reconciliation), project-plan.md (mark WUs complete, add changelog), project-context.md (update state, add decisions, append changelog), todo.md (close completed, add new), cnotes.md (chronological append with sub-project tag). Each merge is edit-in-place, not overwrite |
| WU-2-02 | Research renumbering logic | 2 | yes | ~100 | `skills/sub-project-merge/SKILL.md` (Phase 4 section) | WU-1-03 | Inline implementation following renumbering-protocol.md. Scans both research dirs, builds renumbering map, moves folders, renames summaries, updates internal refs via grep/sed, updates artifact DB labels. Validates: no number collisions, all summaries renamed, no broken cross-refs |
| WU-2-03 | SKILL.md Phase 4 (Safe Merges) | 2 | no | ~100 | `skills/sub-project-merge/SKILL.md` | WU-2-01, WU-2-02 | Phase 4 dispatches doc-merger [S] then runs research renumbering [I]. Presents diff summary to user. All operations are additive (no deletions). Validates: root features.md has sub-project features, root plan has completion entries, research artifacts renumbered correctly |
| WU-3-01 | DB merger agent prompt | 3 | yes | ~80 | `skills/sub-project-merge/agents/db-merger.md` | WU-2-03 | Sonnet subagent prompt; merges sub-project artifact DB into root DB. Prefixes skill field with `sub:<name>/`. Applies renumbering to labels. INSERT (not UPSERT). Rebuilds FTS index. Reports record counts |
| WU-3-02 | SKILL.md Phases 5-6 (Risky + Cleanup) | 3 | no | ~120 | `skills/sub-project-merge/SKILL.md` | WU-3-01 | Phase 5 dispatches DB merger [S], moves source files per merge plan. Phase 6 [I] confirms destructive steps with user, removes symlinks (Batch A), deletes sub-project dir (Batch C), tears down worktree if applicable. Logs to cnotes.md |
| WU-3-03 | SKILL.md Phase 7 (Validation & Summary) | 3 | no | ~60 | `skills/sub-project-merge/SKILL.md` | WU-3-02 | Runs validation: no broken refs in root docs, no orphaned files, artifact DB consistent, features.md/plan consistent. Presents summary: files merged, research renumbered, records transferred, cleanup completed. Suggests `/compliance-review` or `/drift-review` as follow-up |
| WU-3-04 | Cross-cutting compliance & registration | 3 | no | ~30 | `skills/sub-project-merge/SKILL.md` (final) | WU-3-03 | Follows cross-cutting-rules.md. Logs to cnotes.md. Homelab memory sync. Description ≤150 chars. No bare `timeout`. No hardcoded secrets. Skill-forge validation checklist passes |

## Dependency Graph

```
Wave 1:  WU-1-01  WU-1-02  WU-1-03  WU-1-04    (4 parallel)
Wave 2:  WU-1-05                                  (needs all Phase 1)
Wave 3:  WU-2-01  WU-2-02                         (2 parallel)
Wave 4:  WU-2-03                                  (needs 2-01, 2-02)
Wave 5:  WU-3-01                                  (needs 2-03)
Wave 6:  WU-3-02                                  (needs 3-01)
Wave 7:  WU-3-03                                  (needs 3-02)
Wave 8:  WU-3-04                                  (needs 3-03)
```

**Critical path**: 8 waves. Wave 1 runs 4 units in parallel. Wave 3 runs 2 in parallel.
**Total LOC estimate**: ~1,180 across SKILL.md (~510), agents (~350), references (~180), plus merge-plan.md template.

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Research renumbering breaks internal cross-references | Medium | Medium | Grep-based ref update after rename; validation step checks for stale NNN references in all moved files |
| Artifact DB merge creates duplicate records | Low | Low | Prefix sub-project records with `sub:<name>/` namespace; no UPSERT means no overwrites |
| Features.md merge creates duplicate rows | Medium | Medium | Match on feature name before appending; if match found, update status instead of adding new row |
| Worktree merge conflicts | High | Medium | Present conflicts to user inline; do not auto-resolve. Offer `git merge --abort` as escape hatch |
| Sub-project modified parent files not tracked in Section 11 | Medium | Low | Scanner agent also diffs sub-project tree against parent tree to catch untracked modifications |
| User runs merge on incomplete sub-project | Medium | Medium | Phase 1 scanner checks for stubs/TODOs/in-progress features; warns user with option to proceed anyway |
| Merge plan is too large for user to review | Low | Low | Merge plan has executive summary at top; detailed sections are expandable. User can approve summary-level |

## Open Questions

1. **Should merged sub-project directory be archived or deleted?** Current plan: delete after merge (Batch C). Alternative: move to `artifacts/archived-sub-projects/<name>/` for reference. Recommend: archive by default, `--delete` flag to remove.
2. **Should the skill update the sub-project's `build-plan.md` to reference where to find its results in root?** Useful if archiving. Unnecessary if deleting.
3. **Should `/sub-project-merge` be invocable from within the sub-project or only from root?** Recommend: both. If invoked from sub-project, auto-detect parent root via symlink targets or git worktree list.

## Changelog
<!-- Append-only. Use changelog-as-diff format. -->
