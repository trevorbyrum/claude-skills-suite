# DB Merger Subagent Prompt

Prompt template for Phase 5.1 artifact database merge. Use a Sonnet subagent.
Fill in all [PLACEHOLDERS] before spawning.

---

```
You are merging a sub-project's artifact database into the parent project's
artifact database. Every record gets namespaced to preserve provenance.

## Inputs

- Sub-project name: [SUB_PROJECT_NAME]
- Sub-project DB path: [SUB_PROJECT_PATH]/artifacts/project.db
- Parent DB path: [PARENT_ROOT]/artifacts/project.db
- Renumbering map: [RENUMBERING_MAP]

The renumbering map is a list of old→new research number mappings:
```
001D → 010D
002 → 011
```

## Task

### Step 1: Verify Databases

Check both databases exist and are valid SQLite:

```bash
sqlite3 "[SUB_PROJECT_PATH]/artifacts/project.db" ".tables"
sqlite3 "[PARENT_ROOT]/artifacts/project.db" ".tables"
```

Both should have at minimum an `artifacts` table. If the sub-project DB doesn't
exist, report: "No sub-project artifact DB found. Skipping DB merge." and exit.

If the parent DB doesn't exist, initialize it:
```bash
source "[PARENT_ROOT]/artifacts/db.sh"
db_init
```

### Step 2: Export Sub-Project Records

Dump all records from the sub-project DB:

```bash
sqlite3 "[SUB_PROJECT_PATH]/artifacts/project.db" \
  "SELECT skill, phase, label, content, created_at FROM artifacts;"
```

Count the total records:
```bash
sqlite3 "[SUB_PROJECT_PATH]/artifacts/project.db" \
  "SELECT count(*) FROM artifacts;"
```

### Step 3: Transform Records

For each record from the sub-project DB, apply two transformations:

**3.1 Namespace the skill field**:
Prefix with `sub:[SUB_PROJECT_NAME]/`:
```
research-execute → sub:[SUB_PROJECT_NAME]/research-execute
meta-deep-research-execute → sub:[SUB_PROJECT_NAME]/meta-deep-research-execute
clean-project → sub:[SUB_PROJECT_NAME]/clean-project
```

**3.2 Apply renumbering to label field**:
If the label contains a research number that appears in the renumbering map,
replace it:
```
001D → 010D          (simple label)
001D/codex → 010D/codex  (composite label — only replace the number portion)
001D/position-claude → 010D/position-claude
```

Use exact matching on the number portion (before any `/` delimiter).

### Step 4: Insert Into Parent DB

Insert each transformed record into the parent DB. Use INSERT, not UPSERT —
we want to preserve both parent and sub-project records even if they have
similar skill/phase combinations.

```bash
sqlite3 "[PARENT_ROOT]/artifacts/project.db" \
  "INSERT INTO artifacts (skill, phase, label, content, created_at) \
   VALUES ('$SKILL', '$PHASE', '$LABEL', '$CONTENT', '$CREATED_AT');"
```

**Important**: Escape single quotes in content fields. Use parameterized
inserts or proper quoting to avoid SQL injection from content that contains
quotes.

For bulk inserts, consider using a transaction for performance:
```bash
sqlite3 "[PARENT_ROOT]/artifacts/project.db" <<'SQL'
BEGIN TRANSACTION;
INSERT INTO artifacts (skill, phase, label, content, created_at)
  VALUES (...), (...), (...);
COMMIT;
SQL
```

### Step 5: Rebuild FTS Index

The parent DB has an FTS5 full-text search table (`artifacts_fts`) with
triggers for automatic indexing. After bulk inserting, rebuild the index:

```bash
sqlite3 "[PARENT_ROOT]/artifacts/project.db" \
  "INSERT INTO artifacts_fts(artifacts_fts) VALUES('rebuild');"
```

If this fails (FTS table might not exist in older DBs), log a warning and
continue — the triggers will handle future inserts.

### Step 6: Verify

Count records in parent DB with the sub-project namespace:
```bash
sqlite3 "[PARENT_ROOT]/artifacts/project.db" \
  "SELECT count(*) FROM artifacts WHERE skill LIKE 'sub:[SUB_PROJECT_NAME]/%';"
```

This should match the count from Step 2.

List the namespaces created:
```bash
sqlite3 "[PARENT_ROOT]/artifacts/project.db" \
  "SELECT skill, count(*) FROM artifacts WHERE skill LIKE 'sub:[SUB_PROJECT_NAME]/%' GROUP BY skill;"
```

## Output

Report the merge results:

```markdown
## DB Merge Results

- **Source DB**: [SUB_PROJECT_PATH]/artifacts/project.db
- **Target DB**: [PARENT_ROOT]/artifacts/project.db
- **Records exported**: N
- **Records inserted**: N
- **Namespace prefix**: sub:[SUB_PROJECT_NAME]/
- **Renumbering applied**: N labels updated
- **FTS index rebuilt**: yes/no

### Namespaces Created
| Skill (namespaced) | Phase | Record Count |
|--------------------|-------|-------------|
| sub:[SUB_PROJECT_NAME]/research-execute | findings | 5 |
| sub:[SUB_PROJECT_NAME]/clean-project | findings | 2 |
```

Write this report to: `/tmp/sub-project-merge-db-[SUB_PROJECT_NAME].md`
```
