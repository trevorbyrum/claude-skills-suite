# Scanner Subagent Prompt

Prompt template for Phase 1 sub-project scanning. Use a Sonnet subagent.
Fill in all [PLACEHOLDERS] before spawning.

---

```
You are scanning a sub-project to build a complete inventory for a merge-back
operation. Your output will be used to generate a merge plan.

## Inputs

- Sub-project name: [SUB_PROJECT_NAME]
- Sub-project path: [SUB_PROJECT_PATH]
- Parent root: [PARENT_ROOT]
- Merge mode: [MERGE_MODE] (worktree or subdirectory)

## Task

Produce a structured inventory of every file in the sub-project, categorized
for the merge process.

### Step 1: File Inventory

List every file in the sub-project (recursively). For each file, categorize as:

- **source** — code files that should transfer to the parent project. These are
  the actual deliverables of the sub-project (not project management docs).
- **doc** — project management documents: features.md, build-plan.md,
  project-context.md, todo.md, cnotes.md
- **research** — anything under `artifacts/research/` (folders and summaries)
- **artifact-db** — `artifacts/project.db` (SQLite artifact store)
- **symlink** — symlinked files (coterie.md, lint configs, db.sh). Note the
  link target for each.
- **generated** — files to discard during merge: architecture.md, sub-project
  CLAUDE.md/rules/, merge-plan.md (if it exists from a prior attempt)

Use Glob and ls to enumerate. Output as a table:

```markdown
| File | Category | Notes |
|------|----------|-------|
| src/auth.ts | source | New file — no parent equivalent |
| features.md | doc | 4 features (3 done, 1 in-progress) |
| coterie.md | symlink | → ../../coterie.md |
| artifacts/research/001D/ | research | Deep research — agent security |
| architecture.md | generated | Discard on merge |
```

### Step 2: Parent Modifications (Section 11)

Read `[SUB_PROJECT_PATH]/architecture.md`. Find Section 11 ("Parent
Modifications"). Extract the explicit list of parent files this sub-project
intended to modify.

For each entry, check whether the parent file actually exists at the stated
path. Report:

```markdown
| Parent File | Modification Type | Exists | Notes |
|-------------|------------------|--------|-------|
| src/types/auth.ts | extend interface | yes | Adding 2 new fields |
| src/api/routes.ts | add endpoints | yes | 3 new routes |
| migrations/005.sql | new file | no | Will be created |
```

If Section 11 is empty or says "purely additive" or "none", report that.

### Step 3: Feature Status

Read `[SUB_PROJECT_PATH]/features.md`. Extract each feature row with its status.

```markdown
| Feature | Status |
|---------|--------|
| JWT authentication | done |
| OAuth2 integration | done |
| Session management | in-progress |
```

### Step 4: Work Unit Status

Read `[SUB_PROJECT_PATH]/build-plan.md`. Extract each work unit with its
completion status.

```markdown
| WU ID | Name | Status |
|-------|------|--------|
| WU-1-01 | Auth middleware | complete |
| WU-1-02 | Token validation | complete |
| WU-2-01 | OAuth flow | in-progress |
```

### Step 5: Completion Assessment

Scan for signs the sub-project is incomplete:

1. Grep for TODO, FIXME, HACK, XXX in source files
2. Check features.md for any status != "done"
3. Check build-plan.md for incomplete work units
4. Check for empty files or stub implementations (files < 10 lines that import
   but don't implement)

Report a completion verdict:
- **COMPLETE** — all features done, all WUs complete, no TODOs in source
- **MOSTLY COMPLETE** — minor items remaining (1-2 TODOs, all features done)
- **INCOMPLETE** — features in-progress or significant TODOs remain

Include the evidence for your verdict.

### Step 6: Research Inventory

List all research folders and summary files:

```markdown
Research folders:
- 001D/ (deep research — 8 files)
- 002/ (regular research — 3 files)

Summary files:
- summary/001D-topic-name.md
- summary/002-other-topic.md
```

If no research artifacts exist, report: "No research artifacts found."

### Step 7: Artifact DB Inventory

If `[SUB_PROJECT_PATH]/artifacts/project.db` exists:

```bash
sqlite3 "[SUB_PROJECT_PATH]/artifacts/project.db" \
  "SELECT skill, phase, count(*) FROM artifacts GROUP BY skill, phase;"
```

Report the namespace summary (skill/phase combinations and record counts).

If no DB exists, report: "No artifact database found."

## Output

Write your complete inventory to:
`/tmp/sub-project-merge-scan-[SUB_PROJECT_NAME].md`

Use the exact section headers above. The merge plan generator will parse this
output by section.
```
