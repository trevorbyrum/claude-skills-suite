---
name: meta-execute
description: Parallel implementation from a build plan using Codex MCP generation and a 3-4 reviewer panel. Use when an approved project-plan.md exists and multi-unit execution should begin.
---

# meta-execute

Meta-skill that decomposes a build plan into work units and executes them in
parallel using Codex MCP for generation, with a 3-4 reviewer panel
(Codex review+fix, Sonnet subagent rubric, Sonnet subagent architecture,
+ optional Copilot) and Claude as orchestrator.

**Context-window strategy**: Implementation runs in Codex MCP workers.
Reviews run in Codex + Sonnet subagents. The main thread only handles
orchestration (queue management, verdict synthesis, retry decisions) —
never reads full implementation code for comprehension. Exception: the main
thread MAY run mechanical verification commands (lint, type-check, grep for
stubs) via Bash to gate candidate selection.

**Research basis**: Design principles from 002D deep research
(208 cited sources). Key insight: orchestration topology > model selection >
prompt engineering. Per-wave review gate provides stronger convergence than
chasing per-WU model diversity. See
`artifacts/research/summary/002D-meta-execute-quality.md`.

```
Delegation key:
  [S] = subagent     — runs out of main context (Sonnet)
  [I] = inline       — stays in main thread
  [X] = Codex MCP    — codex-mcp generation or review
  [P] = Copilot      — optional 4th reviewer (read-only)

  Decomposition[I] -> Pool Setup[I] ->
    ┌──────────────────── per wave ─────────────────────┐
    │ Context Assembly[I] -> Generation[X]               │
    │   -> Verify[I] -> 3-4 Reviewer Panel[X+S+S(+P)]   │
    │   -> Merge[I] -> github-sync -> meta-review        │
    │   -> User Approval Gate                            │
    └───────────────────────────────────────────────────┘
    -> Completion[I]
```

## Inputs

| Input | Source | Required |
|---|---|---|
| project-plan.md | Project root | Yes |
| project-context.md | Project root | Yes |

**Note**: Workers do NOT receive the full codebase. Each worker gets a curated
context package (10k-50k tokens) assembled in Phase 3. Context stuffing
degrades output quality — less is more.

## Outputs

- Implemented code for each work unit
- Per-unit completion notes in artifact DB (skill=`meta-execute`, phase=`execution-log` or `verdict`, label=`{WU-ID}`)
- Updated `project-plan.md` (work units marked complete as they finish)

## Instructions

### Phase 1: Decomposition [Inline]

Read `project-plan.md` and `project-context.md`. If the plan already has
`LOC Est`, `Key Files`, and `Acceptance Criteria` columns (post-002D
build-plan format), this phase is a **validation and refinement pass** —
verify the estimates and add file ownership details. If the plan uses legacy
columns (`Complexity`, `Agent hint`), do a full re-decomposition.

For each work unit in the plan, determine:

1. **Independence**: Can this unit be implemented without waiting for another
   unit's output? Tag as `parallel` or `sequential`.

2. **Dependencies**: Which other work units must complete first? Build a
   dependency graph. A unit is ready when all its dependencies are satisfied.

3. **LOC estimate**: Estimate lines of code changed/added. Target the
   **50-200 LOC goldilocks zone** across 2-5 files. Units >200 LOC must be
   decomposed further. Units <50 LOC can be batched with related work.
   (Evidence: SWE-bench Pro median ~107 LOC; multi-commit features drop
   success from 74% to 11%.)

4. **File ownership**: List the specific files each unit modifies. Each
   **mutable file is owned by exactly one worker** — no two parallel units
   may modify the same file. Classify shared files:
   - **Read-only**: Type definitions, constants — safe to share freely
   - **Additive-only**: Central export files (index.ts), config arrays —
     safe to share but require **sequential merge lock** (merge these files
     one at a time in Phase 5 to avoid conflict)
   - **Mutable**: Everything else — exclusive ownership required

5. **Independently verifiable**: Each unit must produce at least one new or
   modified export that can be tested with a self-contained test file. If a
   unit can't be independently verified, it's scoped wrong — re-scope it.

6. **Wave assignment**: Group units into dependency waves. Wave 1 = all
   units with zero dependencies. Wave 2 = units whose dependencies are all
   in Wave 1. Wave N = units whose dependencies are all in Waves 1..N-1.
   Units within a wave run in parallel; waves run sequentially with a
   **mandatory review gate** between them (see Phase 3).

Present the decomposition to the user as a table:

```
| Unit | Wave | Status | Type | LOC Est | Dependencies | Owned Files | Shared Reads |
|------|------|--------|------|---------|--------------|-------------|--------------|
| WU-1 | 1    | ready  | parallel | ~80  | none         | src/a.ts    | types/...    |
| WU-2 | 1    | ready  | parallel | ~150 | none         | src/b.ts    | types/...    |
| WU-3 | 2    | blocked| sequential| ~60 | WU-1         | src/a.ts    | src/b.ts     |
```

Store the decomposition in the artifact DB for resume capability:
```bash
source artifacts/db.sh
db_upsert 'meta-execute' 'decomposition' 'table' "$DECOMPOSITION_TABLE"
```

**Exit condition**: User confirms the decomposition table. No file ownership
conflicts within the same wave. All units are in the 50-200 LOC range.
Wave assignments are visible and correct.

### Phase 2: Worker Pool Setup [Inline]

Check availability of external agents:
- **Codex MCP**: call `mcp__codex-mcp__codex_health` with `cwd: <project-root>` and `skip_smoke: true`. REQUIRED.
- If the fast health check passes but a full smoke times out, do not declare Codex unavailable. Launch the first real `codex_start` generation job with the normal task timeout and decide from that result.
- **Copilot** (optional 4th reviewer): load `/copilot` for path resolution.
- **Sonnet subagents**: always available (managed by Claude runtime).

If Codex MCP is unavailable, fall back to Sonnet subagent generation
(see "Fallback Generators" below). Copilot is optional — skip if unavailable.

**Pool limits — generation**:
- Codex MCP: max **5 concurrent** (hard limit from general.md)
- Generation: each WU consumes 1 Codex slot
- Trivial units (<50 LOC, single file): same single-slot Codex generation

**Pool limits — review** (3-4 reviewer panel per WU):
- Codex MCP: review+fix consumes 1 of the 5 Codex slots
- Sonnet subagents: 2 per WU (rubric + architecture lenses), no hard limit
- Copilot: 1 per WU (optional), max 2 concurrent globally
- All 3-4 reviewers for a single WU run in parallel
- **Concurrency budget**: with Codex used by both generation and review, no
  more than 5 Codex jobs total — typically 2 WUs generating + 2 WUs in
  review at a time.

### Phase 3: Context Assembly & Execution Loop [Inline + Workers]

#### Context Assembly (per work unit)

For each work unit, build a **curated context package** of 10k-50k tokens.
Read `agents/worker.md` for the prompt template — fill in all placeholders.

The context package contains:
1. Work unit specification + acceptance criteria (from the plan)
2. **Only the files this unit modifies** (full contents)
3. **Interface signatures** for directly imported modules (NOT implementations)
4. Relevant type definitions, constants, enums
5. Project conventions excerpt from `project-context.md` (keep under 2k tokens)

**Do NOT include**: full codebase, all project docs, change history, other
workers' specs, or unrelated files. Irrelevant context actively degrades
output (AGENTS.md study; SWE-Pruner: 23-54% token reduction with minimal
quality loss).

#### Generation Strategy: Single Codex MCP

For each work unit, generate **one candidate** with Codex MCP. Single-model
generation is simpler than Best-of-N and the post-generation review panel
provides the diversity needed to catch errors. Codex MCP runs in workspace-
write mode and modifies files directly.

1. Dispatch one Codex MCP `generate` job (read the worker prompt from
   `agents/worker.md`, fill placeholders, and pass via the `prompt` field):
   ```json
   {
     "mode": "generate",
     "cwd": "<project-root>",
     "add_dirs": ["<worktree-or-feature-path>"],
     "prompt": "[contents of /tmp/wu-{ID}-prompt.md]",
     "timeout_sec": 300
   }
   ```
   Use `mcp__codex-mcp__codex_start` to launch asynchronously. Do NOT poll —
   use `codex_status`/`codex_result` after notification.

2. When the job completes, run **quick verification** via Bash
   commands (mechanical gate-checking, not code comprehension):
   - Lint pass (no errors)
   - Type-check pass (no errors)
   - Unit tests pass (if tests exist)
   - Stub detection: `grep -rn '// \.\.\.\|TODO\|implement later\|placeholder' <files>`
3. Store verification results in the artifact DB for traceability:
   ```bash
   source artifacts/db.sh
   db_write 'meta-execute' 'verification' '{WU-ID}-codex' "$CODEX_RESULTS"
   ```
4. If verification fails, classify the failure (see Retry Logic below) and
   either retry or move on to the review panel — the panel will catch
   what the gates missed.

#### Queue Management (Wave-Gated)

Execution proceeds **one wave at a time**. Do NOT start Wave N+1 until
Wave N completes, passes review, merges, and the user approves.

Maintain a work queue with states: `ready`, `in-progress`, `done`,
`failed`, `blocked`.

**Within a single wave:**

1. Identify all `ready` units in the **current wave only**.
2. Assign ready units to Codex MCP slots (up to 5 concurrent generation jobs,
   but reserve 1-2 slots for in-flight Codex reviews).
3. As each Codex generation completes, run quick verification.
4. Dispatch the 3-4 reviewer panel for the implementation (Phase 4).
5. Assign the next `ready` unit **from this wave** to the freed slot.
6. Repeat until all units in this wave are `done` or `failed`.
7. Track queue state in the artifact DB for resume capability:
   ```bash
   source artifacts/db.sh
   db_upsert 'meta-execute' 'queue-state' 'current' "$QUEUE_JSON"
   ```

**After all units in the current wave complete:**

8. Merge all completed units from this wave (Phase 5 — sequential rebase).
9. Commit & push this wave's changes via `/github-sync`.
10. Run `/meta-review` on the cumulative codebase. This is the **wave gate**
    — a full multi-lens review of the project in its current state.
11. Present the wave summary + meta-review synthesis to the user:
    ```
    Wave N complete.
    - Units completed: X/Y
    - Failed (needs human review): Z [list them]
    - Meta-review findings: [summary from review-synthesis.md]
    - Next wave: Wave N+1 has M units [list them]
    Continue to Wave N+1? (yes / fix issues first / stop)
    ```
12. **STOP and wait for user approval** before starting the next wave.
    Do NOT proceed automatically. The user may want to fix issues,
    adjust the plan, or stop execution entirely.
13. On approval, advance to the next wave. Mark its units as `ready`
    and return to step 1.

#### Generator Invocations

Write the worker prompt (from `agents/worker.md`) to a temp file first:
```bash
cat > /tmp/wu-{ID}-prompt.md << 'PROMPT_EOF'
... filled worker.md template ...
PROMPT_EOF
```

Then dispatch a single Codex MCP `generate` job with the prompt file's
contents in the `prompt` field. Use `mcp__codex-mcp__codex_start` for
asynchronous launch (you will be notified when it completes — do not poll).

Store execution output in the artifact DB after the job finishes:
```bash
source artifacts/db.sh
db_write 'meta-execute' 'execution-log' '{WU-ID}-codex' "$CODEX_FINAL_MESSAGE"
```

#### Fallback Generators

If Codex MCP is unavailable, fall back to Sonnet subagent generation:

1. Each Sonnet subagent receives the same prompt built from `agents/worker.md`.
2. Use `isolation: "worktree"` so parallel subagents do not conflict on files.
3. Subagents have full tool access (Read, Write, Edit, Bash, Grep, Glob).
4. The Codex reviewer slot in Phase 4 is replaced with a second Sonnet
   subagent acting as a critique reviewer (read-only).

### Phase 4: 3-4 Reviewer Panel [Multi-Model]

**Context-window strategy**: Dispatch 3-4 reviewers per completed work unit.
Each reviewer scores the code independently. The main thread synthesizes
verdicts — it never reads full implementation code. Codex MCP is the only
reviewer that applies fixes; the other reviewers are read-only advisors.

#### Reviewer Panel Composition

All reviewers launch in parallel for each WU. Read `agents/reviewer.md`
for the shared review prompt template. Fill in [WU-ID], [description],
acceptance criteria, conventions, and the **worktree path or branch name**.

| # | Reviewer | Mode | Role | Invocation |
|---|----------|------|------|------------|
| 1 | **Codex MCP** | review+fix | Reads code, reviews against rubric, applies fixes in-place | `mcp__codex-mcp__codex_run` with `mode: "generate"` and `agents/codex-reviewer.md` prompt |
| 2 | **Sonnet subagent (rubric)** | read-only | Agentic Rubrics — generates checklist from spec BEFORE reading code | `agents/reviewer.md` (rubric pass) |
| 3 | **Sonnet subagent (architecture)** | read-only | Reviews architecture, conventions, integration wiring | `agents/reviewer.md` (architecture pass) |
| 4 | **Copilot** (optional) | read-only | Different model family perspective | Load `/copilot` for syntax |

**Do NOT add reviewers beyond what is listed.** 3-4 is the panel size.

#### Reviewer Invocations

Write the review prompt to a file first (from `agents/reviewer.md`, with
all placeholders filled):
```bash
cat > /tmp/wu-{ID}-review-prompt.md << 'REVIEW_EOF'
... filled reviewer.md template ...
REVIEW_EOF
```
For Codex specifically, pass the filled prompt text in the MCP `prompt` field.

**1. Codex MCP (review+fix)** — the only reviewer that writes files.
Uses the specialized prompt from `agents/codex-reviewer.md` which includes
fix-application instructions.
```json
{
  "mode": "generate",
  "cwd": "<worktree-or-branch-path>",
  "prompt": "[contents of /tmp/wu-{ID}-codex-review-prompt.md]",
  "timeout_sec": 300
}
```

**2. Sonnet subagent (rubric)** — Agentic Rubrics pass.
Spawn via the Agent tool with `subagent_type: "review-lens"` (or
`general-purpose` if review-lens is unavailable). Prompt is the contents of
`agents/reviewer.md` with the **rubric** focus emphasized.

**3. Sonnet subagent (architecture)** — Architecture & integration pass.
Spawn a second Agent subagent with the same `agents/reviewer.md` prompt
but with focus directed at architecture, conventions, integration wiring,
and over-engineering signals. Use `isolation: "worktree"` if the first
subagent is still running.

**4. Copilot (optional)** — load `/copilot` for invocation syntax.
Key params: `--add-dir <worktree-or-branch-path>`, 120s timeout.
Prompt: `$(cat /tmp/wu-{ID}-review-prompt.md)`. Output to
`/tmp/wu-{ID}-review-copilot.md`. If Copilot is unavailable or times out,
proceed with the 3-reviewer panel.

Launch all 3-4 with `run_in_background: true` (or async MCP). Do NOT poll.

#### Verdict Synthesis

After all reviewers return, the main thread synthesizes (NEVER rely on
subagents to write to the DB — extract response text and write via
`db_upsert` in the main thread):

```bash
source artifacts/db.sh
db_write 'meta-execute' 'review' '{WU-ID}-codex' "$CODEX_REVIEW"
db_write 'meta-execute' 'review' '{WU-ID}-sonnet-rubric' "$SONNET_RUBRIC_REVIEW"
db_write 'meta-execute' 'review' '{WU-ID}-sonnet-architecture' "$SONNET_ARCH_REVIEW"
db_write 'meta-execute' 'review' '{WU-ID}-copilot' "$COPILOT_REVIEW"   # if present
```

**Synthesis rules:**
- **All present reviewers ACCEPT** (or MINOR_FIX that Codex already fixed) → **ACCEPT**
- **One reviewer flags REJECT** → Codex applies fixes informed by all
  reviewer perspectives, then one more Sonnet pass to verify the fix
- **Disagreement (mixed verdicts)** → Claude reads the reviewer summaries
  (NOT the code) and makes the call. Escalate to user if uncertain.
- **Unanimous REJECT** → classify failure type and retry (see below)

Store the synthesized verdict:
```bash
db_upsert 'meta-execute' 'verdict' '{WU-ID}' "$SYNTHESIZED_VERDICT"
```

**Confidence scoring** (for the completion summary):
- 4/4 agree: HIGH confidence
- 3/4 or 3/3 agree: HIGH confidence
- 2/3 agree: MEDIUM confidence
- Disagreement requiring Claude synthesis: LOW confidence (flag for user)

#### Processing Verdicts

Based on the synthesized verdict:

- **ACCEPT**: Mark the unit as `done`. Update `project-plan.md` via the
  evolve-plan pattern (mark complete, append changelog).
- **MINOR_FIX**: If Codex already applied fixes during its review pass,
  verify with one more Sonnet pass. If clean, mark `done`.
- **REJECT**: Mark as `failed`. Classify the failure type (see retry logic).
  The unit goes back in the queue for retry.

#### Retry Logic: Failure Classification

**Transient errors** (syntax, import, type errors — the code approach is
sound but has mechanical bugs):
- Retry by re-dispatching Codex MCP with the error output appended to context. Max 3 retries.
- Codex can often fix these directly during its review+fix pass.

**Permanent errors** (logic gaps, architectural misunderstanding, wrong
approach — the fundamental strategy is flawed):
- Do NOT retry the same approach. This wastes tokens without progress.
- Generate a **fresh attempt with a different approach** — re-dispatch
  Codex MCP with a reformulated prompt that explicitly rules out the
  failed strategy. Optionally raise `reasoning: "high"`.
- If the 2nd fresh attempt also fails: escalate to Opus review for feedback,
  then one more Codex MCP attempt with that feedback included in the prompt.
- 3rd failure on permanent errors: flag for human review. Move to `blocked`.

How to classify: If the rejection mentions wrong logic, missing understanding,
architectural mismatch, or wrong API usage → permanent. If it mentions
syntax, missing import, wrong type, formatting → transient.

#### Pipeline Optimization

Generation and review run in parallel across the wave. While WU-1 is in
review, WU-2 generation can be in-flight in another Codex slot. Maintain
the 5-concurrent ceiling across all Codex MCP jobs (generation + review
combined). Typical saturation: 2 WUs generating + 2 WUs reviewing.

### Phase 5: Merge Strategy [Inline]

After units pass review, merge using **sequential rebase** in dependency
order (not all-at-once):

1. Merge the first completed unit's changes to the main working branch.
2. Rebase subsequent branches onto the updated main. Each merge gets the
   latest repository context.
3. For trivial conflicts (shared list entries, import additions), resolve
   automatically. For non-trivial conflicts, flag for human review.

4. After successful merge, **clean up the worktree**:
   ```bash
   git worktree remove <worktree-path> 2>/dev/null || true
   git branch -d wu-{ID} 2>/dev/null || true
   ```

This approach keeps <3 merge conflicts over extended work sessions when
file ownership is properly partitioned in Phase 1.

### Phase 6: Completion [Inline]

When all waves are done (the last wave's gate was approved):

1. **Tally results** across all waves:
   - Units completed successfully (and which wave each was in)
   - Units that required retries (note how many attempts, transient vs permanent)
   - Units that failed and are flagged for human review
   - Units still blocked (and what blocks them)
   - Number of waves executed, and meta-review findings per wave

2. **Update project-plan.md**: Run evolve-plan to mark all completed units
   and note any new work discovered during implementation.

3. **Present final summary** to the user:
   ```
   Execution complete.
   - Waves executed: W (with meta-review gate after each)
   - Completed: X/Y work units
   - Retried: R units (T transient, P permanent reclassified)
   - Failed (needs human review): Z units [list them]
   - Blocked: W units [list blockers]
   - New work discovered: N items [list them]
   ```

4. **Logging pass (optional)**: If the meta-review from any wave flagged
   log-review findings, suggest running `/log-gen` as a post-implementation
   pass to add logging instrumentation to the newly generated code. LLM-
   generated code almost never includes adequate logging — this catches it
   before the first production incident.

5. **Homelab Tools memory sync (MANDATORY)**: Store the execution summary
   in Qdrant so home Claude stays current. Per cross-cutting rule 7:
   ```
   mcp__claude_ai_Homelab_Tools__memory_call with tool: 'store_memory'
   Content: execution summary (waves, units completed/failed/blocked,
            retry counts, confidence scores, new work discovered)
   Tags: meta-execute, execution-summary, {project-name}
   ```
   Search first to avoid duplicating a recent entry for this project.

Note: each wave was already committed & pushed via `/github-sync` at its
gate, and each wave already received a `/meta-review`. No additional
push or review is needed at this stage unless the user requests one.

## Error Handling

### Timeout Guards

- Set a mental time limit of 5 minutes per phase. If a phase has not produced output in 5 minutes, check if the subprocess is still running.
- For Codex MCP calls: set `timeout_sec` explicitly when the default is not enough. A health smoke timeout is only degraded signal; skip Codex only after the real task reports `timed_out`/failed or the broker reports a hard config error.
- For Copilot CLI calls: always use `$GTIMEOUT` with skill-appropriate values (120s read-only review). If it times out, skip and note "Copilot timed out — skipping."
- If a subagent has been running for more than 10 minutes with no output, consider it stalled and move on.
- Report any timeouts in the completion summary so the user knows what was skipped.

### Budget Cap

Each work unit gets a maximum of **5 worker invocations** (1 initial Codex
generation + up to 4 retries across transient/permanent paths). If a
unit exhausts its budget, it moves to `blocked` for human review regardless
of failure type. This prevents cost spirals on intractable problems.

## Constraints

- **Claude is the orchestrator, not the implementer.** Claude reads plans,
  assigns work, synthesizes verdicts, manages the queue. Claude does NOT
  write application code directly except for trivial merge-conflict fixes.
- **Workers are disposable.** Each Codex MCP / Sonnet subagent invocation
  is stateless and ephemeral. All context must be passed in the prompt — do
  not assume workers remember previous invocations.
- **Concurrency ceilings.** Codex MCP: 5 concurrent total (across generation
  and review). Copilot: 2. Sonnet subagents: no hard limit.
- **3-4 reviewer panel is mandatory.** No work unit is marked `done` without
  the panel scoring it. Codex MCP reviews+fixes; Sonnet subagents and
  Copilot provide read-only perspectives. Majority agreement required for
  ACCEPT. Unreviewed code is untrusted code.
- **Codex MCP is editor and coder.** Codex MCP handles both generation and
  review+fix in this design. Per-WU diversity comes from the multi-reviewer
  panel, not from multiple generators.
- **No context stuffing.** Workers receive curated 10-50k token packages.
  Never pass the full codebase, full docs, or other workers' specifications.
- **Outcome > process.** Specify WHAT to build precisely. Leave HOW to the
  model. Over-specifying reasoning degrades performance.

## Examples

```
User: "Plan is approved. Let's build it."
Action: Read project-plan.md. Decompose into work units. Present the table.
        On confirmation, assemble context packages, dispatch Codex MCP
        generators, and start the execution loop.
```

```
User: "/meta-execute"
Action: Same as above. Check that project-plan.md exists and is approved.
        If no plan exists, tell the user to run /meta-init first.
```

```
User: "Start building. Codex isn't working today."
Action: Check Codex availability — confirm unavailable. Fall back to Sonnet
        subagents with worktree isolation for generation, and use two Sonnet
        subagents in the review panel (one rubric, one critique).
        Inform the user. Proceed with the same execution pattern.
```

```
User: "Resume execution — we stopped after WU-4 yesterday."
Action: Read project-plan.md. Identify which units are already marked done.
        Resume from the next ready unit. Do not re-execute completed work.
```

---

Before completing, read and follow `references/cross-cutting-rules.md`.
