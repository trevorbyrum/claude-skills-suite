
# Scope Triage

Scores each removal candidate from impact-analysis on four code-adapted RICE
dimensions (Usage, Blast, Coverage, LOC), then applies MoSCoW categorization
against the updated project direction. The result is a ranked triage table the
user approves before surgical-remove acts on it. Separates "safe to cut" from
"dangerous to touch" using objective signals rather than intuition.

## Inputs

| Input | Source | Required |
|---|---|---|
| Removal candidates | Artifact DB — `db_read 'impact-analysis' 'candidates' 'latest'` | Yes |
| `project-context.md` | Project root (post-Phase 2 rewrite) | Yes |
| `project-plan.md` | Project root (updated for new direction) | Yes |

## Outputs

- **Artifact DB**: `db_upsert 'scope-triage' 'triage' 'latest' "$CONTENT"`
- Content is a markdown table with columns:
  `| Module/File | Usage | Blast | Coverage | LOC | RICE Score | MoSCoW | Rationale |`

## References (on-demand)

Read these files only when needed:

- `references/triage-framework.md` — Exact RICE weights, per-dimension scoring
  rubric (0-10), MoSCoW definitions adapted for code modules, edge cases for
  shared utilities, test files, and config files.

## Instructions

### Phase 1: Load Candidates

Source the artifact DB helper and load impact-analysis output:

```bash
source artifacts/db.sh
CANDIDATES=$(db_read 'impact-analysis' 'candidates' 'latest')
```

If `$CANDIDATES` is empty, exit with:
> "scope-triage: No impact-analysis candidates found. Run impact-analysis first."

### Phase 2: Load Updated Project Direction

Read `project-context.md` and `project-plan.md` from the project root.
Extract the new project direction — the goal, target users, and explicit
non-goals. This becomes the alignment lens for MoSCoW categorization.

If either file is missing, exit with:
> "scope-triage: project-context.md and project-plan.md must exist (post-Phase 2 rewrite)."

### Phase 3: Score Each Candidate

Read `references/triage-framework.md` for the exact scoring rubric before
scoring. Score every candidate on four dimensions (each 0-10). Do not skip
candidates — if data is ambiguous, use conservative (pessimistic) estimates
and note the uncertainty in the Rationale column.

**Usage (0-10)** — How frequently is this module actually used?
Count import statements, call sites, and test references across the codebase.
High score = high usage = important to keep.

**Blast (0-10)** — How many things break if this is removed?
Use the transitive dependent count from the impact-analysis output.
High score = high blast radius = risky to remove.

**Coverage (0-10)** — How well do existing tests cover this module?
Use coverage data if available; estimate from test file presence and assertion
count if not. High score = well-tested = safer to remove without regression.

**LOC (0-10)** — How much code would need to be removed or rewritten?
Higher LOC means higher removal effort. Scale: <50 LOC = 10 (cheap to cut),
>1000 LOC = 0 (expensive). High score = low effort = easier to remove.

Compute the weighted RICE score per candidate:
```
RICE = (Usage × 0.30) + (Blast × 0.30) + (Coverage × 0.20) + (LOC × 0.20)
```

Low RICE score = safe removal candidate. High RICE score = keep.

### Phase 4: Apply MoSCoW Categorization

For each candidate, evaluate alignment with the new project direction loaded
in Phase 2. Assign one of four categories:

- **Must Keep** — Directly enables the new direction's core capability. Removing
  it blocks the pivot. Treat as untouchable regardless of RICE score.
- **Should Keep** — Supports the new direction but not on the critical path.
  Worth keeping if refactoring cost is low; consider simplifying rather than
  removing.
- **Could Remove** — Not relevant to the new direction AND low blast radius.
  Safe to schedule for removal in the next cleanup pass.
- **Won't Keep** — Actively contradicts the new direction, is dead code, or
  was built for the old direction with no residual value. Prioritize for removal.

When a candidate's RICE score and MoSCoW category conflict (e.g., high RICE
but "Won't Keep"), flag the conflict explicitly in the Rationale column. The
user resolves conflicts at the review step.

### Phase 5: Sort and Assemble Table

Sort candidates: lowest RICE score first (best removal candidates at the top).
Within the same score, sort by MoSCoW priority: Won't Keep > Could Remove >
Should Keep > Must Keep.

Assemble the triage table:

```markdown
| Module/File | Usage | Blast | Coverage | LOC | RICE Score | MoSCoW | Rationale |
|---|---|---|---|---|---|---|---|
| src/legacy/reporter.ts | 2 | 1 | 8 | 9 | 3.8 | Won't Keep | No call sites; built for old CSV export direction |
| ...
```

All scores are integers 0-10. RICE Score is a decimal to one place.

### Phase 6: Present for User Review

Present the full table to the user. Include a summary above the table:

```
Triage Summary:
  Must Keep:    N candidates
  Should Keep:  N candidates
  Could Remove: N candidates
  Won't Keep:   N candidates

  RICE conflicts flagged: N (review Rationale column)
```

Ask:
> "Review the triage table. Reply with any changes (e.g., 'move X to Must Keep',
> 'LOC score for Y is wrong — it's 2000 lines'). When satisfied, say 'approve'
> to store and proceed."

Wait for explicit approval. Do not proceed to Phase 7 without it.

### Phase 7: Store Approved Triage

On user approval, store the final table in the artifact DB:

```bash
source artifacts/db.sh
db_upsert 'scope-triage' 'triage' 'latest' "$TRIAGE_TABLE"
```

Report:
> "Triage stored. N candidates marked Won't Keep / Could Remove are ready for
> surgical-remove. Run `/meta-pivot` to continue to Phase 4."

### Exit Conditions

- **Missing candidates**: Exit early in Phase 1 with instructions to run impact-analysis.
- **Missing project docs**: Exit early in Phase 2.
- **User rejects triage**: Revise scores per feedback and re-present. Loop until approved or user cancels.
- **User cancels**: Exit without storing. Inform meta-pivot orchestrator.

## Examples

```
Invoked by meta-pivot Phase 3 after impact-analysis completes.
→ Load candidates, score all, present table for user review, store on approval.
```

```
User adjusts a score mid-review: "The blast score for auth/middleware.ts is
wrong — only two services depend on it, not twelve."
→ Re-score affected candidate, recompute RICE, re-sort table, re-present.
```

```
Conflict flagged: src/analytics/pipeline.ts has RICE 8.2 (high, keep) but
MoSCoW = Won't Keep (contradicts new direction).
→ Flag clearly: "HIGH RICE / WON'T KEEP conflict — this is deeply embedded
  but no longer needed. Recommend extracting the two dependents before removal."
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
