# Doc Merger Subagent Prompt

Prompt template for Phase 4.1 document reconciliation. Use a Sonnet subagent.
Fill in all [PLACEHOLDERS] before spawning.

---

```
You are merging sub-project documents back into the parent project. Every merge
is an edit-in-place operation — you never overwrite entire files, only update
specific sections.

## Inputs

- Sub-project name: [SUB_PROJECT_NAME]
- Sub-project path: [SUB_PROJECT_PATH]
- Parent root: [PARENT_ROOT]
- Merge plan: [MERGE_PLAN_CONTENT]

Read these files:
- [PARENT_ROOT]/features.md
- [PARENT_ROOT]/project-plan.md
- [PARENT_ROOT]/project-context.md (if exists)
- [PARENT_ROOT]/todo.md (if exists)
- [PARENT_ROOT]/cnotes.md (if exists)
- [SUB_PROJECT_PATH]/features.md
- [SUB_PROJECT_PATH]/build-plan.md
- [SUB_PROJECT_PATH]/project-context.md (if exists)
- [SUB_PROJECT_PATH]/todo.md (if exists)
- [SUB_PROJECT_PATH]/cnotes.md (if exists)

## Merge Rules

### 1. features.md

Append sub-project features to the parent features table.

**Status reconciliation**: If a feature name matches an existing parent row,
update the status using this precedence: done > in-progress > planned. The
more advanced status wins.

**Format for appended rows**:
```
| Feature Name | status | Description from sub-project | YYYY-MM-DD | [sub:<name>] |
```

The `[sub:<name>]` tag in Notes indicates provenance.

**Duplicate detection**: Before appending, check if a feature with the same name
already exists in the parent table. If it does:
- Update status (if sub-project status is more advanced)
- Append `[sub:<name>]` to Notes if not already present
- Do NOT create a duplicate row

Use the Edit tool to modify [PARENT_ROOT]/features.md.

### 2. project-plan.md

**Mark completed work**: If the parent plan has work units that correspond to
the sub-project's scope, mark them as complete. Look for work units whose
names or descriptions match the sub-project's deliverables.

**Add new work units**: If the sub-project discovered new work during its build
(items in sub-project build-plan.md that don't correspond to any parent plan
entry), add them to the parent plan as new work units in the appropriate phase.

**Changelog entry**: Append a changelog entry at the top of the Changelog
section:

```markdown
### YYYY-MM-DD — CLAUDE
- Merged sub-project `<name>`: [brief summary of what was completed]
- Completed: [list WU IDs marked done]
- Added: [list new WU IDs if any]
- Reason: Sub-project merge via /sub-project-merge
```

Use the Edit tool to modify [PARENT_ROOT]/project-plan.md.

### 3. project-context.md

If the parent has project-context.md, update these sections:

**Current State**: Update the "Done" and "In Progress" lists to reflect the
sub-project's completed work.

**Key Decisions**: If the sub-project's project-context.md has Key Decisions
not present in the parent, append them to the parent's Key Decisions table.
Add `[sub:<name>]` in the rationale.

**Tech Stack**: If the sub-project introduced new dependencies not in the
parent's Tech Stack, add them.

**Changelog**: Append entry following the format in
`../../references/evolve-context-diff.md` (if available) or use:

```markdown
### YYYY-MM-DD — CLAUDE
- **Current State**: Updated with sub-project `<name>` deliverables
- Reason: Sub-project merge
```

Use the Edit tool. If project-context.md doesn't exist in the parent, skip
this step and log: "Skipped project-context.md — file not found in parent."

### 4. todo.md

If both parent and sub-project have todo.md:

**Close completed items**: For each completed item in the sub-project todo,
find the matching item in the parent todo (by task description) and mark it
as done/closed.

**Add remaining items**: For each uncompleted item in the sub-project todo
that has no match in the parent, append it to the parent todo table. Add
`[sub:<name>]` in the Notes column.

Use the Edit tool. If either todo.md doesn't exist, skip and log.

### 5. cnotes.md

If both parent and sub-project have cnotes.md:

Append ALL sub-project notes to the parent cnotes.md. Notes go below the
parent's existing most recent note (newest first ordering).

For each appended note, prefix the `work_scope:` field with `[sub:<name>]`
to indicate provenance:

```
work_scope: [sub:auth-service] JWT token validation
```

Do NOT modify existing parent notes. Only append.

Use the Edit tool. If sub-project cnotes.md is empty or doesn't exist, skip.

## Output

After completing all merges, report what was changed:

```markdown
## Doc Merge Results

### features.md
- Appended: N new features
- Updated: N existing features (status changes)
- Unchanged: N features

### project-plan.md
- Completed: WU-X-XX, WU-X-XX (N work units)
- Added: WU-X-XX (N new work units)
- Changelog entry added

### project-context.md
- Updated sections: Current State, Key Decisions
- New Key Decisions: N
- Changelog entry added

### todo.md
- Closed: N items
- Added: N items

### cnotes.md
- Appended: N notes with [sub:<name>] tag
```

Write this report to: `/tmp/sub-project-merge-docs-[SUB_PROJECT_NAME].md`
```
