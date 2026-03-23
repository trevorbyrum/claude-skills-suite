# Research Artifact Renumbering Protocol

Step-by-step protocol for renumbering sub-project research artifacts to fit into
the parent's numbering sequence. Used by Phase 2.1 (map generation) and Phase 4.2
(execution).

## Numbering System

Research artifacts use a `NNNX` format:
- `NNN` = 3-digit zero-padded number (001, 002, ..., 999)
- `X` = optional `D` suffix for deep research (no suffix = regular research)
- Both types share one global sequence within a project
- Examples: `001`, `001D`, `002D`, `003`, `004D`

## Step 1: Scan Parent Research

```bash
# List all numbered research folders in parent
ls -d artifacts/research/[0-9][0-9][0-9]* 2>/dev/null | sort
```

Extract the numeric portion (strip the D suffix):
- `001D` → 1
- `002D` → 2
- `009` → 9

Find the maximum: `PARENT_MAX = 9` (in this example).

**Edge case — no parent research**: `PARENT_MAX = 0`. Sub-project numbers stay
as-is (001D stays 001D).

**Edge case — gaps in parent numbering** (e.g., 001D, 003D, no 002): This is
fine. The renumbering assigns the next number after max, not gap-filling.

## Step 2: Scan Sub-Project Research

```bash
# List all numbered research folders in sub-project
ls -d <sub>/artifacts/research/[0-9][0-9][0-9]* 2>/dev/null | sort
```

Sort numerically. Extract each folder's number and D-suffix status.

**Edge case — no sub-project research**: Skip renumbering entirely. Log: "No
research artifacts to renumber."

## Step 3: Build Renumbering Map

Starting from `PARENT_MAX + 1`, assign new numbers sequentially:

```
Counter = PARENT_MAX + 1

For each sub-project folder (sorted by original number):
  new_number = printf '%03d' $Counter
  if original had D suffix:
    new_name = "${new_number}D"
  else:
    new_name = "${new_number}"

  Add to map: original_name → new_name
  Counter += 1
```

**Example** (parent has 001D through 009, sub has 001D and 002):
```
sub:001D → parent:010D
sub:002  → parent:011
```

**Example** (parent has nothing, sub has 001D, 002D, 003):
```
sub:001D → parent:001D  (stays the same — PARENT_MAX was 0)
sub:002D → parent:002D
sub:003  → parent:003
```

## Step 4: Execute Renumbering

For each entry in the map:

### 4.1 Copy Research Folder

```bash
cp -r "<sub>/artifacts/research/${OLD_NAME}/" "artifacts/research/${NEW_NAME}/"
```

Use `cp -r`, not `mv`. The sub-project originals stay intact until cleanup
(Phase 6). This preserves rollback capability.

### 4.2 Copy Summary File

Find the summary file matching the old name:
```bash
ls <sub>/artifacts/research/summary/${OLD_NAME}-*.md
```

Copy with the new prefix:
```bash
# Example: 001D-topic.md → 010D-topic.md
OLD_SUMMARY="001D-agent-security-gaps.md"
NEW_SUMMARY="010D-agent-security-gaps.md"
cp "<sub>/artifacts/research/summary/${OLD_SUMMARY}" \
   "artifacts/research/summary/${NEW_SUMMARY}"
```

**Edge case — no summary file**: The research folder exists but no summary was
written. Log warning: "Research folder ${OLD_NAME} has no summary file." Copy
the folder anyway.

**Edge case — multiple summary files** for one number: Unlikely but possible.
Copy all of them with the new prefix.

### 4.3 Update Internal References

Within the copied research folder (now at parent path), update references to
the old number:

```bash
# In the NEW parent folder, replace old number with new
# Use word-boundary matching to avoid replacing substrings
grep -rl "${OLD_NAME}" "artifacts/research/${NEW_NAME}/" | while read -r file; do
  sed -i '' "s/\b${OLD_NAME}\b/${NEW_NAME}/g" "$file"
done
```

Also update the copied summary file:
```bash
sed -i '' "s/\b${OLD_NAME}\b/${NEW_NAME}/g" \
  "artifacts/research/summary/${NEW_SUMMARY}"
```

**Important**: Only update the COPIED files, never the sub-project originals.

### 4.4 Update Artifact DB Labels

If the sub-project has an artifact DB, research-related records will have the
old number in their `label` field. The DB merger agent handles this — it applies
the renumbering map to labels during the INSERT phase.

## Step 5: Verify

After all renumbering is complete:

1. **Folder count**: Parent should now have `PARENT_MAX + sub_count` research
   folders.
2. **Summary count**: Each renumbered folder should have a corresponding summary
   (or a logged warning for missing ones).
3. **No stale references**: Grep the new folders for any remaining references to
   old numbers:
   ```bash
   for entry in renumbering_map; do
     grep -r "${OLD_NAME}" "artifacts/research/${NEW_NAME}/" && echo "STALE REF: ${OLD_NAME} in ${NEW_NAME}"
   done
   ```
4. **Numbering sequence**: List all parent research folders sorted numerically.
   Verify no collisions (two folders with the same number).

## Edge Cases Summary

| Scenario | Behavior |
|----------|----------|
| No parent research | Sub-project numbers kept as-is (PARENT_MAX = 0) |
| No sub-project research | Skip renumbering entirely |
| Gaps in parent numbering | Ignored — next number = max + 1, not gap-fill |
| Sub has only D folders | D suffix preserved on all new numbers |
| Sub has only non-D folders | No D suffix on any new numbers |
| Sub has mixed D/non-D | Each preserves its own suffix status |
| Research folder exists but no summary | Copy folder, log warning about missing summary |
| Multiple summaries for one number | Copy all with new prefix |
| Sub-project number matches parent number | Always renumbered (even if same number) — prevents collisions. Exception: PARENT_MAX = 0 case |
