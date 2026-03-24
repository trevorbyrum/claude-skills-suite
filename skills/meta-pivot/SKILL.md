---
name: meta-pivot
description: "Orchestrates project pivot: direction interview, context rewrite, analysis, adversarial triage, wave removal, verification. Invoke with /meta-pivot."
---

# meta-pivot

Meta-skill that helps users pare down projects after direction changes. Performs
deep analysis of the codebase against the new direction, triages what to
keep/cut/simplify with adversarial debate, then executes safe incremental removal
with human gates at every decision point.

**Why this exists**: Direction changes leave codebases polluted with old-direction
code. Manual cleanup is slow, error-prone, and misses external dependencies.
meta-pivot automates the analysis, structures the decisions, and executes removal
in risk-ordered waves — while keeping humans in the loop for every irreversible
choice.

**Context-window strategy**: Main thread handles orchestration + human gates only.
Heavy analysis dispatched to Opus subagent. Adversarial debate via Codex + Gemini
CLIs. Wave execution via Opus subagent per wave. Never load atomic skill files
into main context — subagents read them.

```text
Delegation key:
  [I] = inline     — stays in main thread, user interaction
  [S] = subagent   — Opus or Sonnet, runs out of main context
  [W] = worker     — CLI agent (Codex, Gemini, Copilot)

  Project Review[S:Sonnet] + Mode Detect[I] -> Interview[I]
    -> Context Rewrite[I] -> Deep Analysis[S:Opus]
    -> Adversarial I[W:Codex+Gemini] -> Triage[I] -> Adversarial II[W:Codex+Gemini]
    -> Decision Log[I] -> Wave Execution[S:Opus per wave]
    -> Verification[S:Sonnet] -> meta-review[skill] -> Doc Update[S:Sonnet]
```

## Inputs

| Input | Source | Required |
|---|---|---|
| project-context.md | Project root | Yes |
| project-plan.md | Project root | No (analysis adapts) |
| features.md | Project root | No (used in doc-code diff) |
| todo.md | Project root | No (updated in context rewrite) |
| Full codebase | Project root | Yes |

## Outputs

- `artifacts/general/pivot-plan.md` — What's being removed, in what order, with blast radius
- `artifacts/general/pivot-summary.md` — Append-only audit trail across all phases
- `artifacts/general/decisions/` — ADR files from Phase 7
- Artifact DB entries for intermediate findings (see Data Flow below)

## Data Flow

```text
Subagent → temp file (/tmp/pivot-*) → main thread → db_upsert + pivot-summary append

Key rule: Subagents CANNOT call db_upsert. They write to temp files.
Main thread reads temp files, persists to DB, and appends to pivot-summary.md.
```

| Skill | Phase | Label | Content |
|---|---|---|---|
| impact-analysis | candidates | latest | Ranked removal candidates |
| impact-analysis | dep-graph | latest | Dependency graph summary |
| scope-triage | triage | latest | RICE-scored + MoSCoW table |
| surgical-remove | wave-log | wave-{N} | Per-wave execution log |
| meta-pivot | summary | {timestamp} | Full pivot-summary snapshot |

## Instructions

### Phase 1: Project Review & Mode Detection [S+I]

Before asking any questions, understand the project first.

**Step 1 — Ask one question:**

> "Have you already started pivoting this project, or is this a fresh direction change?"

**Step 2 — Full project analysis (while waiting or after answer):**

Dispatch a Sonnet subagent to review the entire project state. The subagent reads:
- `project-context.md`, `project-plan.md`, `features.md`, `todo.md`, `cnotes.md`
- Scans `src/` (or equivalent) for codebase structure, entry points, module map
- Checks git log for recent direction-suggestive commits
- Reads any existing `artifacts/` for prior review/research findings

The subagent writes a **Current State Summary** to `/tmp/pivot-project-review.md`:
- What the project does (from docs)
- Key modules/features and their apparent status
- Any drift between docs and code it can detect
- If pivot-in-progress: what appears to have changed already vs what hasn't
- Codebase stats: file count, languages, approximate LOC, test coverage indicators

Main thread reads the summary and presents it to the user:

> **Here's what I see:**
>
> [Current state summary — 10-15 bullet points max]
>
> [If pivot already started]: "It looks like you've already started moving
> toward [X] based on [evidence]. Is that right?"
>
> [If fresh pivot]: "The project is currently oriented around [X]. What's the
> new direction?"

**Step 3 — Targeted interview (informed by analysis):**

The questions now stem from what was found:

- **If already pivoting**: Present what Claude thinks the pivot IS based on the
  analysis. User confirms or corrects. Then ask only: "What's still left to
  cut?" and "Anything I'm missing about the new direction?"
- **If fresh pivot**: Ask targeted questions informed by the codebase analysis:
  1. **What is the new direction?** (now Claude understands what the OLD one is)
  2. **What triggered this?** Market, technical, scope, capacity?
  3. **Looking at [specific modules from analysis] — which stay, which go?**
  4. **Any external dependencies?** (Claude can pre-populate from external scan hints)

Present the direction summary:

> **Direction Change Summary**
>
> **Current state**: [from project review — what exists now]
> **Old direction**: [summarized from project-context.md]
> **New direction**: [from user answers or detected pivot]
> **Reason for change**: [from interview]
> **Protected items**: [from interview, informed by analysis]
> **Known removals**: [from interview, informed by analysis]
> **External concerns**: [from interview]
> **Already completed**: [if pivot in progress — what's already been done]

Wait for user confirmation: "Does this accurately capture the pivot? (yes/adjust)"

**Exit condition**: User confirms the direction summary.

Create `artifacts/general/` if it doesn't exist. Initialize `artifacts/general/pivot-summary.md`
from `templates/pivot-summary-template.md`. Append Phase 1 results (including the
full project review summary).

### Phase 2: Context Rewrite [I, human-gated]

This phase depoisons all project documentation so downstream agents read the
*new* direction, not the old one.

1. Read current `project-context.md` and `project-plan.md`.
2. Draft specific changes to each file. For each change, provide a **1-2 sentence
   explanation** of why it's changing. Present as a diff-style summary:

   > **project-context.md changes:**
   > - Overview: "Widget marketplace" → "Widget API platform" — *pivoting from consumer marketplace to developer platform*
   > - Architecture: Remove "recommendation engine" section — *no longer in scope*
   > - Constraints: Add "API backward compatibility" — *new direction requires stable API*

3. Wait for user approval: "Approve these doc changes? (yes/adjust)"
4. On approval, write the changes to `project-context.md` and `project-plan.md`.
5. Cascade to secondary docs. For each of these files (if they exist), update
   to reflect the new direction. These updates are autonomous — no per-file gate:
   - `features.md` — mark removed features, add new ones
   - `todo.md` — remove irrelevant tasks, add pivot-related ones
   - `cnotes.md` — add a note logging the direction change (coterie format)
6. Append Phase 2 results to `artifacts/general/pivot-summary.md`.

**Exit condition**: project-context.md and project-plan.md reflect the new direction.
User has approved the changes. Secondary docs are updated.

### Phase 3: Deep Analysis [S, Opus]

Dispatch an Opus subagent using the prompt template in `agents/deep-analysis.md`.
Fill in placeholders: `[PROJECT_PATH]`, `[DIRECTION_SUMMARY]`.

The subagent reads `references/impact-analysis.md` (nested under this skill)
and `skills/clean-project/SKILL.md` (suite-level). It runs:
- Dependency graph construction (all 4 modes including external blast radius)
- Dead code detection
- Doc-code diff against the *updated* docs from Phase 2
- Structural cleanup scan (clean-project)

The subagent writes results to:
- `/tmp/pivot-analysis-candidates.md` — ranked candidate list
- `/tmp/pivot-analysis-depgraph.md` — dependency graph summary
- `/tmp/pivot-analysis-external.md` — external dependency findings

After the subagent completes, main thread:
```bash
source artifacts/db.sh
db_upsert 'impact-analysis' 'candidates' 'latest' "$(cat /tmp/pivot-analysis-candidates.md)"
db_upsert 'impact-analysis' 'dep-graph' 'latest' "$(cat /tmp/pivot-analysis-depgraph.md)"
```

Generate draft `artifacts/general/pivot-plan.md` from `templates/pivot-plan-template.md`
with the candidate list and blast radius data. Append Phase 3 results to pivot-summary.md.

### Phase 3.5: Adversarial Challenge I [W, Codex+Gemini]

Before presenting candidates to the user, challenge them with adversarial reviewers.

Write the debate prompt to `/tmp/pivot-debate-candidates.md` containing:
- The direction summary from Phase 1
- The full candidate list with blast radius from Phase 3
- Instructions: "Challenge these removal candidates. Flag false positives, missed
  dependencies, items that should NOT be removed, and items missing from the list."

Dispatch in parallel (respect concurrency limits — Codex max 5, Gemini max 2):

1. **Codex**: Load `/codex` driver for invocation syntax.
   ```bash
   bash skills/codex/scripts/codex-exec.sh review \
     --output /tmp/pivot-debate-codex.md \
     --timeout 120 \
     --stdin /tmp/pivot-debate-candidates.md
   ```

2. **Gemini**: Load `/gemini` driver for invocation syntax.
   Use the Research / Analysis template with 120s timeout.
   Output to `/tmp/pivot-debate-gemini.md`.

**Fallback chain**:
- Codex fails → Sonnet subagent with same prompt
- Gemini fails → Copilot (load `/copilot`) → Sonnet subagent
- At minimum 2 reviewers must complete

After all return, merge disagreements into the candidate list:
- Items flagged by ≥2 reviewers as false positive → marked `[DISPUTED]`
- Items flagged by 1 reviewer → marked `[FLAGGED]`
- New items suggested by reviewers → added with `[SUGGESTED]` tag

Append adversarial results to pivot-summary.md.

### Phase 4: Triage & Scoring [I, human-gated]

Read the annotated candidate list (with adversarial markers). Dispatch a Sonnet
subagent to run `references/scope-triage.md` (nested under this skill), which:
- Scores each candidate on modified RICE (Usage, Blast, Coverage, LOC)
- Applies MoSCoW categorization against the new direction

The subagent writes results to `/tmp/pivot-triage-results.md`. Main thread:
```bash
source artifacts/db.sh
db_upsert 'scope-triage' 'triage' 'latest' "$(cat /tmp/pivot-triage-results.md)"
```

Present the scored, categorized table to the user with adversarial annotations
visible. `[DISPUTED]` items highlighted — these need explicit user judgment.

User makes final keep/cut/simplify decisions per item. Accept corrections to
both RICE scores and MoSCoW categories.

**Exit condition**: User has approved the triage. Every candidate has a
keep/cut/simplify decision.

### Phase 4.5: Adversarial Challenge II [W, Codex+Gemini]

After triage but before logging, challenge the cut decisions.

Write debate prompt to `/tmp/pivot-debate-triage.md` containing:
- Direction summary
- The approved triage table with keep/cut/simplify decisions
- Instructions: "Attack these decisions. Find: items being cut that have hidden
  dependents, items being kept that contradict the new direction, wave ordering
  errors, and external dependencies that would break."

Same dispatch pattern as Phase 3.5 (Codex + Gemini, same fallback chain).

Present challenges to user. User can:
- **Revise** — go back to Phase 4 with adjustments
- **Confirm** — proceed to logging

Append results to pivot-summary.md.

### Phase 5: Decision Logging [I]

For each "cut" and "simplify" decision, create a lightweight ADR:

```markdown
# ADR-{NNN}: {Decision Title}

- **Date**: {ISO-8601}
- **Status**: Accepted
- **Context**: {Why this item is being cut/simplified — 1-2 sentences}
- **Decision**: {Cut | Simplify} — {one-line description of what happens}
- **Consequences**: {What changes as a result — blast radius, affected modules}
```

Store ADRs in `artifacts/general/decisions/ADR-{NNN}.md`. Append decision
summary to pivot-summary.md.

If the user opts out of individual ADRs, append a consolidated decision table
to pivot-summary.md instead.

**Exit condition**: All cut/simplify decisions are logged.

Update `artifacts/general/pivot-plan.md` with the final approved removal list,
wave assignments, and rollback strategy.

### Phase 6: Wave Execution [S, Opus per wave]

For each wave (1 through 4, or single wave for pre-prod shortcut):

1. Dispatch an Opus subagent using `agents/wave-executor.md`. Fill in:
   `[WAVE_NUMBER]`, `[CANDIDATE_LIST]`, `[PROJECT_PATH]`.
2. The subagent reads `references/surgical-remove.md` (nested) and executes
   the wave protocol.
3. Subagent writes results to `/tmp/pivot-wave-{N}-log.md`.
4. Main thread reads the log and persists:
   ```bash
   source artifacts/db.sh
   db_upsert 'surgical-remove' 'wave-log' "wave-${N}" "$(cat /tmp/pivot-wave-${N}-log.md)"
   ```
5. Present wave results to user:
   > **Wave {N} complete**: {X} files removed, {Y} references updated.
   > Tests: {pass/fail}. Branch: `pivot/wave-{N}`.
   >
   > 1. **Approve** — merge this wave and proceed to next
   > 2. **Rollback** — discard this wave's branch
   > 3. **Pause** — keep branch, stop here for now

6. On approve: merge the wave branch. Proceed to next wave.
7. On rollback: `git branch -D pivot/wave-{N}`. Ask if user wants to retry
   with adjustments or skip this wave.
8. On pause: save state to pivot-summary.md. User can resume later.

Append per-wave results to pivot-summary.md.

**Exit condition**: All approved waves are merged. Or user has paused.

### Phase 7: Verification [S, Sonnet]

Dispatch a Sonnet subagent using `agents/verification.md`. The subagent:
1. Reads drift-review SKILL.md and runs it against the *updated* docs
2. Reads completeness-review SKILL.md and checks for stubs/placeholders
3. Runs full build + test suite + lint

Subagent writes results to `/tmp/pivot-verification.md`. Main thread reads
and presents:
- drift-review findings (should be zero if pivot was clean)
- completeness-review findings
- build/test/lint results

If any findings: present to user for resolution before proceeding.

Append to pivot-summary.md.

**Exit condition**: Verification passes or user acknowledges remaining items.

### Phase 8: Full Project Review [meta-review]

The codebase has been surgically altered — run a full multi-model review to catch
anything the wave execution or verification missed.

Tell the user:

> "Pivot execution and verification complete. Running /meta-review on the
> surviving codebase to catch quality issues introduced during removal."

Invoke `/meta-review`. This dispatches the full review suite (10+ lenses across
3 model families) against the post-pivot codebase. The review reads the *updated*
project docs from Phase 2, so it evaluates against the new direction.

If meta-review surfaces findings:
- **CRITICAL/HIGH**: Present to user. These should be resolved before the final
  doc update. Offer to run `/review-fix` to dispatch fixes.
- **MEDIUM/LOW**: Log in pivot-summary.md for follow-up. Don't block the pivot.

Append meta-review summary to pivot-summary.md.

**Exit condition**: meta-review has run. Critical/high findings resolved or
acknowledged. Results logged.

### Phase 9: Final Doc Update [S, Sonnet]

Dispatch a Sonnet subagent using `agents/doc-update.md`. The subagent reads
evolve SKILL.md and updates all project docs to reflect what actually happened
during execution (the plan rarely survives contact intact).

Subagent writes results to `/tmp/pivot-doc-update.md`. Main thread appends
final section to pivot-summary.md.

Present completion summary to user:
> **Pivot complete.**
> - {N} files removed across {N} waves
> - {N} external dependencies addressed
> - {N} ADRs logged
> - meta-review: {N} findings ({N} critical/high resolved)
> - Documentation updated
> - Full audit trail: `artifacts/general/pivot-summary.md`

**Exit condition**: pivot-summary.md has all sections filled. User has seen
the completion summary.

## Error Handling

- **project-context.md missing**: Tell user to run `/project-context` or `/meta-init` first.
- **Opus subagent fails/times out**: Read whatever temp files exist. Present partial results. Offer to retry or proceed with what's available.
- **Both adversarial reviewers fail**: Fall back to 2 Sonnet subagents. Never skip adversarial review entirely.
- **Wave execution fails mid-wave**: Branch is preserved for inspection. User can rollback, fix manually, or retry.
- **User wants to stop early**: Any phase can be the last. Save state to pivot-summary.md. User can resume with `/meta-pivot --resume`.

## References (on-demand)

Subagent instruction sets (read on demand, not standalone skills):

- `references/scope-triage.md` — Feature/module scoring with RICE + MoSCoW
- `references/triage-framework.md` — RICE formula, MoSCoW definitions, scoring rubric
- `references/impact-analysis.md` — Dependency graph + blast radius + external scan
- `references/tool-matrix.md` — Language→tool mapping, confidence scoring
- `references/external-scan.md` — External dependency scan checklist
- `references/surgical-remove.md` — Wave-ordered removal execution
- `references/wave-protocol.md` — Wave ordering, characterization tests, rollback

Helper scripts:

- `scripts/analyze-deps.sh` — Language-aware dead code detection wrapper (knip, vulture, go vet, cargo udeps)

Agent prompt templates:

- `agents/project-review.md` — Sonnet subagent for Phase 1 project analysis
- `agents/deep-analysis.md` — Opus subagent for Phase 3
- `agents/adversarial-debate.md` — Codex + Gemini debate protocol for Phases 3.5, 4.5
- `agents/wave-executor.md` — Opus subagent for Phase 6
- `agents/verification.md` — Sonnet subagent for Phase 7
- `agents/doc-update.md` — Sonnet subagent for Phase 8

Artifact templates:

- `templates/pivot-plan-template.md` — Schema for pivot-plan.md
- `templates/pivot-summary-template.md` — Schema for pivot-summary.md

## Examples

```
User: "We're pivoting from a marketplace to an API platform. Help me clean up."
→ Full 8-phase flow. Interview captures direction change. Context rewrite updates
  docs. Deep analysis finds marketplace-specific code. Adversarial debate catches
  false positives. User triages. Waves remove marketplace code. Verification
  confirms clean state.
```

```
User: "/meta-pivot"
→ Start with Phase 1 interview. No assumptions about what changed.
```

```
User: "We already know what to cut — skip to execution"
→ Ask user to confirm the cut list. Skip Phases 1-4. Generate ADRs from the
  provided list. Proceed to wave execution.
```

```
User: "Just analyze what we could remove, don't actually delete anything"
→ Run Phases 1-4 only. Present the analysis and triage. Stop before execution.
  User gets the pivot-plan.md and pivot-summary.md with full analysis.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
