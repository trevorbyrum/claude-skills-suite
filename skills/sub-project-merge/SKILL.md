---
name: sub-project-merge
description: "Merges a completed sub-project back into its parent. Renumbers research, reconciles docs, merges DB. Invoke with /sub-project-merge."
argument-hint: "[sub-project path or name]"
---

# Sub-Project Merge

Merges a completed sub-project back into its parent project — research artifacts,
documents, artifact DB records, source files, and all. Generates a merge-specific
plan at runtime, presents it for approval, then executes in safety-tiered batches
so nothing is lost or overwritten without confirmation.

This skill exists because sub-projects accumulate their own research numbering,
features, plan entries, and artifact DB records that must be reconciled with the
parent's state. Manual merging is error-prone — renumbering alone requires scanning
both trees, remapping folder names, summary files, internal references, and DB
labels. This skill automates all of it.

**Context-window strategy**: Only Phases 0, 2, 3, and 6 stay inline (detection,
merge plan generation, approval gate, destructive confirmation). All heavy work
delegates to subagents.

## Inputs

| Input | Source | Required |
|---|---|---|
| Sub-project path | User prompt or auto-detect | Yes |
| Parent project root | cwd or inferred from symlinks | Yes |
| Sub-project `architecture.md` | Sub-project root | Yes (Section 11: Parent Modifications) |
| Sub-project `features.md` | Sub-project root | Yes |
| Sub-project `build-plan.md` | Sub-project root | Yes |
| Sub-project `project-context.md` | Sub-project root | No |
| Sub-project `todo.md` | Sub-project root | No |
| Sub-project `cnotes.md` | Sub-project root | No |
| Parent `features.md` | Parent root | Yes |
| Parent `project-plan.md` | Parent root | Yes |
| Parent `project-context.md` | Parent root | No |

## Outputs

- **`merge-plan.md`** in the sub-project directory — runtime-generated merge plan
  with inventory, renumbering map, document diffs, conflict list, risk assessment
- **Updated parent docs**: `features.md`, `project-plan.md`, `project-context.md`,
  `todo.md`, `cnotes.md` — reconciled with sub-project state
- **Renumbered research**: sub-project research artifacts moved to parent with
  correct sequential numbering
- **Merged artifact DB**: sub-project records inserted into parent `project.db`
  with `sub:<name>/` namespace prefix
- **Archived sub-project**: moved to `artifacts/archived-sub-projects/<name>/`
- **DB record**: `db_upsert 'sub-project-merge' 'merge' '<sub-project-name>' "$SUMMARY"`

## Instructions

### Phase 0: Detect Sub-Project [Inline]

Identify the sub-project to merge.

1. If user provided a path, use it directly.
2. If user provided a name, look for:
   - `./<name>/architecture.md` (subdirectory mode)
   - `git worktree list` output matching `sub/<name>` (worktree mode)
3. If neither, scan for sub-project directories (directories containing both
   `architecture.md` and a symlinked `coterie.md`). Present candidates:
   > "Found sub-projects: auth-service/, payment-api/. Which one to merge?"

Detect merge mode:
- **Worktree mode**: `git worktree list` shows the sub-project path → will use
  `git merge` + `git worktree remove`
- **Subdirectory mode**: sub-project is a plain directory → will use file
  copy/move + directory removal

Determine parent root:
- If coterie.md is a symlink, follow it to find the parent root
- Otherwise, use cwd or the parent of the sub-project directory

**Exit condition**: Sub-project path confirmed, parent root identified, merge
mode (worktree vs subdirectory) determined.

### Phase 1: Scan Sub-Project [Subagent]

Dispatch a Sonnet subagent to inventory the sub-project. Read `agents/scanner.md`
for the prompt template — fill in placeholders before spawning.

The scanner:
1. Lists every file in the sub-project, categorized as:
   - **source** — code files to transfer to parent
   - **doc** — project docs (features.md, build-plan.md, etc.)
   - **research** — `artifacts/research/` folders and summaries
   - **artifact-db** — `artifacts/project.db`
   - **symlink** — symlinked files (coterie.md, lint configs, db.sh)
   - **generated** — files to discard (architecture.md, sub-project CLAUDE.md)
2. Reads `architecture.md` Section 11 ("Parent Modifications") — the explicit
   list of parent files this sub-project intended to modify
3. Reads `features.md` — extracts feature names and statuses
4. Reads `build-plan.md` — extracts work unit completion status
5. Scans for completion signals: stubs, TODOs, in-progress items. Warns if
   sub-project appears incomplete.
6. Writes structured inventory to a temp file.

Read the scanner output when complete.

**Exit condition**: Inventory file exists with all files categorized, parent
modification list extracted, completion status assessed.

### Phase 2: Generate Merge Plan [Inline]

Build `merge-plan.md` in the sub-project directory. This is the plan for THIS
specific merge — not a generic template.

Read `references/merge-checklist.md` for the exhaustive checklist to follow.
Read `references/renumbering-protocol.md` for the research renumbering rules.

#### 2.1 Research Renumbering Map

1. Scan parent `artifacts/research/` for existing numbered folders.
2. Extract the highest number (ignore `D` suffix): e.g., folders `001D`-`009` → max = 9.
3. Scan sub-project `artifacts/research/` for its numbered folders.
4. For each sub-project research folder, in ascending order:
   - Assign next parent number: `sub:001D` → `parent:010D` (preserves D suffix)
   - Next: `sub:002` → `parent:011` (no D stays no D)
5. Build the renumbering map table.

#### 2.2 Document Merge Preview

For each document that will be merged, generate a diff preview:
- **features.md**: List features to append/update, with status reconciliation
- **project-plan.md**: List work units to mark complete, changelog entry preview
- **project-context.md**: List sections to update (Current State, Key Decisions)
- **todo.md**: List items to close and items to add
- **cnotes.md**: Count of notes to append

#### 2.3 Code File Destinations

From scanner's Section 11 extraction, list:
- Source file → parent destination path
- Whether the destination already exists (conflict detection)
- Nature of change (new file, modification, extension)

#### 2.4 Artifact DB Summary

Count records in sub-project DB. List skill/phase namespaces found. Note any
that would collide with parent DB namespaces (after prefixing).

#### 2.5 Cleanup Plan

List all symlinks to remove, the sub-project directory archive path
(`artifacts/archived-sub-projects/<name>/`), and worktree teardown steps if
applicable.

#### 2.6 Risk Assessment

Rate the merge:
- **LOW** — docs only, no source code transfer, no parent modifications
- **MEDIUM** — source code transfer to new parent locations, no existing file modifications
- **HIGH** — modifies existing parent files (shared types, APIs, migrations)

Write all of the above to `<sub-project>/merge-plan.md`.

**Exit condition**: `merge-plan.md` exists with all 6 sections populated.

### Phase 3: User Approval Gate [Inline]

Present the merge plan to the user. Show:

> **Merge Plan: `<name>` → parent**
>
> **Risk**: LOW / MEDIUM / HIGH
> **Research to renumber**: N folders (001D→010D, 002→011, ...)
> **Features to merge**: N (X done, Y in-progress)
> **Code files to transfer**: N files
> **Artifact DB records**: N records
> **Conflicts detected**: N (list if any)
>
> Review the full plan at `<sub-project>/merge-plan.md`.
> Proceed? (yes / modify / abort)

If "modify" — ask what to change, regenerate affected sections.
If "abort" — exit cleanly.
If "yes" — proceed to Phase 4.

**Exit condition**: User explicitly approves the merge.

### Phase 4: Safe Merges — Documents & Research [Subagent + Inline]

This phase makes only additive changes to the parent. Nothing is deleted.

#### 4.1 Document Reconciliation [Subagent]

Dispatch a Sonnet subagent for document merging. Read `agents/doc-merger.md`
for the prompt template.

The doc-merger receives `merge-plan.md` and both project roots. It:

1. **features.md** — Appends sub-project features to parent table. If a feature
   name matches an existing parent row, updates status (sub-project status wins
   if more advanced: done > in-progress > planned). Adds `[sub:<name>]` in Notes.
2. **project-plan.md** — Marks sub-project-related work units as complete in
   parent plan. Adds new work units discovered during sub-project build (if any).
   Appends changelog entry with today's date.
3. **project-context.md** — Updates "Current State" section. Adds Key Decisions
   from sub-project's `project-context.md`. Updates Tech Stack if sub-project
   introduced new dependencies. Appends changelog entry.
4. **todo.md** — Closes completed items matching sub-project work. Adds any
   remaining uncompleted sub-project items to parent.
5. **cnotes.md** — Appends all sub-project notes to parent, maintaining
   chronological order (newest first). Prefixes each note's `work_scope` with
   `[sub:<name>]`.

All merges are edit-in-place using the Edit tool — never overwrite entire files.

Read the subagent output. Verify each document was updated.

#### 4.2 Research Renumbering [Inline]

Execute the renumbering map from `merge-plan.md`:

1. For each entry in the map (in order):
   - Copy the research folder: `sub/artifacts/research/001D/` → `parent/artifacts/research/010D/`
   - Copy the summary file: `sub/artifacts/research/summary/001D-topic.md` → `parent/artifacts/research/summary/010D-topic.md`
   - Grep all files in the copied folder for references to the old number (e.g., `001D`)
     and replace with the new number (`010D`). Be precise — match `001D` as a
     whole token, not as a substring.
2. Verify: every entry in the renumbering map has a corresponding folder and
   summary in the parent.

**Exit condition**: All parent docs updated. Research artifacts renumbered and
present in parent. No stale references to old numbers.

### Phase 5: Risky Merges — DB & Code Transfer [Subagent + Inline]

#### 5.1 Artifact DB Merge [Subagent]

Dispatch a Sonnet subagent for DB merging. Read `agents/db-merger.md` for the
prompt template.

The db-merger:
1. Opens both databases (parent `artifacts/project.db`, sub-project `artifacts/project.db`)
2. For each record in sub-project DB:
   - Prefixes the `skill` field with `sub:<name>/` (e.g., `research-execute` → `sub:auth-service/research-execute`)
   - Applies renumbering map to `label` field where it contains a research number
   - INSERTs into parent DB (not UPSERT — preserves both records)
3. Rebuilds FTS index: drops and recreates `artifacts_fts` triggers
4. Reports: record count transferred, namespaces created

Read the subagent output. Verify record counts.

#### 5.2 Code File Transfer [Inline]

If the merge plan lists source files to transfer:

1. For each file in the code destinations list:
   - If destination doesn't exist: copy file to parent location
   - If destination exists and content differs: present the conflict to user.
     Options: overwrite / skip / diff-and-decide
   - If destination exists and content matches: skip (already merged)
2. After all transfers, verify: every source file from the plan has a
   corresponding parent file.

For worktree mode, skip this step — code transfer happens via `git merge` in
Phase 6.

**Exit condition**: Artifact DB merged. Source files transferred (or conflicts
resolved). Subagent output verified.

### Phase 6: Destructive Cleanup [Inline — Requires Confirmation]

Present the cleanup plan and get explicit confirmation:

> **Ready to clean up. These actions are destructive:**
>
> **Batch A (safe — no data loss):**
> - Remove symlinks: coterie.md, [lint configs], artifacts/db.sh
>
> **Batch B (archive — data preserved):**
> - Archive sub-project to `artifacts/archived-sub-projects/<name>/`
>
> **Batch C (destructive — worktree only):**
> - `git worktree remove <path>`
> - `git branch -d sub/<name>` (only if fully merged)
>
> Proceed with cleanup? (yes / keep-sub-project / abort)

If "keep-sub-project" — skip Batch B and C, only run Batch A (symlink removal).
If "abort" — leave everything as-is.
If "yes":

**Batch A**: Remove all symlinks in the sub-project directory. These point to
parent files that still exist — removing the link is safe.

**Batch B**:
1. Create `artifacts/archived-sub-projects/` in the parent if it doesn't exist
2. Move the entire sub-project directory to `artifacts/archived-sub-projects/<name>/`
3. Remove `merge-plan.md` from the archive (it was a working document)
4. Remove any remaining symlinks from the archive (they'd be broken)

**Batch C** (worktree mode only):
1. Ensure all changes are committed in the sub-project worktree
2. Switch to main branch in the main worktree
3. `git merge sub/<name>` — if conflicts, present to user for resolution
4. `git worktree remove <path>`
5. `git branch -d sub/<name>` — only if the branch is fully merged

**Exit condition**: Symlinks removed. Sub-project archived (or kept). Worktree
cleaned up (if applicable).

### Phase 7: Validation & Summary [Inline]

Run post-merge validation:

1. **No broken refs**: Grep parent docs for references to the sub-project path —
   should find none (except in cnotes.md history entries, which are fine).
2. **Research continuity**: Parent `artifacts/research/summary/` should have
   continuous numbering (no gaps from renumbering).
3. **Features consistency**: Every feature in parent `features.md` has a valid
   status. No duplicate feature rows.
4. **Plan consistency**: Parent `project-plan.md` has no work units referencing
   the sub-project as a dependency that's still pending.
5. **DB integrity**: `sqlite3 parent/artifacts/project.db "SELECT count(*) FROM artifacts WHERE skill LIKE 'sub:<name>/%';"` returns the expected record count.

Store merge summary in artifact DB:
```bash
source artifacts/db.sh
db_upsert 'sub-project-merge' 'merge' '<sub-project-name>' "$SUMMARY"
```

Present the summary:
> **Merge complete: `<name>` → parent**
>
> - **Research renumbered**: 001D→010D, 002→011 (N folders)
> - **Features merged**: N features (X done, Y in-progress)
> - **Plan updated**: N work units marked complete
> - **DB records transferred**: N records under `sub:<name>/` namespace
> - **Code files transferred**: N files (M conflicts resolved)
> - **Archived to**: `artifacts/archived-sub-projects/<name>/`
>
> Suggested follow-ups:
> - `/compliance-review` — verify parent conventions after merge
> - `/drift-review` — check docs match current code state
> - `/evolve` — update project-context.md if scope changed

Log to `cnotes.md` per cross-cutting rules.

## References (on-demand)

Read these files only when needed for the relevant phase:
- `references/merge-checklist.md` — exhaustive merge checklist with action, risk level, and rollback step for every operation. Used in Phase 2 when generating merge-plan.md.
- `references/renumbering-protocol.md` — step-by-step research artifact renumbering rules including edge cases (no research, gaps, D vs non-D, internal cross-refs). Used in Phase 2.1 and Phase 4.2.

## Examples

```
User: "/sub-project-merge auth-service"
→ Detect auth-service/ subdirectory. Scan. Generate merge plan showing 2 research
  folders to renumber (001D→010D, 002→011), 4 features to merge (3 done, 1 in-progress),
  6 source files to transfer. User approves. Merge docs, renumber research, transfer
  code, archive sub-project.
```

```
User: "Merge the payment sub-project back"
→ Detect payment/ with worktree mode (git worktree list shows sub/payment). Scan.
  Generate merge plan. Execute: doc merge, research renumber, DB merge. Cleanup:
  git merge sub/payment, git worktree remove, git branch -d. Archive.
```

```
User: "/sub-project-merge frontend-redesign --keep"
→ Full merge but skip Batch B/C cleanup. Sub-project directory stays in place.
  Symlinks removed. Useful for long-running sub-projects that aren't done yet
  but have deliverables ready to merge.
```

```
User: "I finished the API rewrite sub-project, merge it in"
→ Auto-detect sub-project. Scanner finds 0 research folders, 8 features all done,
  12 source files, HIGH risk (modifies shared types). Merge plan flags 2 conflicts
  in parent types/. User resolves inline. Clean merge.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
