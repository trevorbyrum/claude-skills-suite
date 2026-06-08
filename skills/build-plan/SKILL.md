---
name: build-plan
description: Generates or updates project-plan.md with phases, work units, dependencies, and acceptance criteria. Auto-detects whether to create from scratch, update an existing plan, or produce a lightweight in-session plan. Invoke with /build-plan.
disable-model-invocation: true
argument-hint: "[quick | update | rewrite | <scope description>]"
---

# Build Plan

Take project context (and research, if available) and produce a comprehensive plan — or update an existing one when work completes and scope shifts. Three sub-modes share a common shape; differences live in `references/`.

## Inputs

| Input | Source | Required |
|---|---|---|
| `project-context.md` | Project root | Yes (full mode) |
| Research synthesis at `artifacts/research/*/synthesis.md` | Prior research runs (if any) | Optional (improves accuracy) |
| Existing `project-plan.md` | Project root | Required for update mode |
| User's scope description | Prompt | Required for lightweight mode |

## Outputs

- `project-plan.md` in project root (created, updated, or extended)
- Optional `features.md` and `todo.md` updates (update mode only — absorbs former `/todo-features`)

## Instructions

### Phase 0: Detect mode

```bash
PLAN_EXISTS=$(test -f project-plan.md && echo yes || echo no)
```

| Plan exists | User cue | Mode |
|---|---|---|
| no | any | from-scratch (read `references/from-scratch.md`) |
| yes | "update plan", completed WU mentioned, scope change | update (read `references/update.md`) |
| yes | "quick plan", "small plan", or invocation describes <5 file scope | lightweight (read `references/lightweight.md`) |
| yes | "rewrite plan", "redo plan" | from-scratch with `git mv project-plan.md project-plan.<date>.md` archive |

If `yes` plan exists and the user cue is ambiguous → `AskUserQuestion`: "Update existing plan or rewrite from scratch?"

If `no` plan exists and the user explicitly asks for a "lightweight" or "quick" plan with a small scope → run lightweight mode (this is the former `/quick-plan` path).

### Phase 1: Read inputs

1. `project-context.md` — always.
2. Research synthesis (if `artifacts/research/*/synthesis.md` exists) — read the most recent.
3. Existing `project-plan.md` — required for update mode.

### Phase 2: Pre-checks (from-scratch and update modes)

Two checks in parallel:

1. **Competitive landscape.** Spawn a Sonnet subagent (`subagent_type: "general-purpose"`) with WebSearch. Prompt:
   > "You have WebSearch. For a project described as: [one-line summary]. List the top 5 competing or similar projects. For each: name, what it does, strengths, weaknesses, and what this project could learn from it. Cite URLs. Bullets only."

   Write output to `/tmp/competitive-landscape.md`. Read it. Incorporate "lessons" and "differentiation" into the plan.

2. **Technical feasibility.** Spawn a second Sonnet subagent with WebSearch. Prompt:
   > "Given this tech stack: [stack from context]. And this scope: [scope summary]. Flag technical risks: library maturity, scaling problems, integration pain, missing pieces. Be specific. Cite where possible."

   Capture the risk list for Phase 4.

If either subagent fails, skip and note in the plan's "Risks" section.

### Phase 3: Structure the work

Follow the chosen mode reference for the specific work. All modes produce work units with:

| Field | Description |
|---|---|
| ID | `WU-<phase>-<seq>` (e.g., `WU-1-03`) |
| Title | Short descriptive name |
| Description | What this unit delivers (1-3 sentences) |
| Dependencies | List of WU IDs that must complete first |
| Parallelizable | `yes` / `no` — can it run alongside others? |
| LOC estimate | 50-200 LOC across 2-5 files (SWE-bench: success drops 74% → 11% on multi-commit features) |
| Key files | Files created or modified, each tagged with **access class** (see below). Parallel units must NOT both have `mutable` access on the same file. |
| Acceptance criteria | Verifiable pass/fail checks |

**File access classes** (tag each Key File entry):

- **read-only** — type definitions, constants, schemas. Safe to share freely across parallel units.
- **additive-only** — central exports (`index.ts`), config arrays, route registrations. Parallel units may add to these, but the merge requires a **sequential merge lock** at wave end (merge one WU's additions at a time to avoid conflicts).
- **mutable** — everything else. Exclusive ownership required; only one WU per wave may touch a `mutable` file.

Example: `Key files: src/auth/jwt.ts [mutable], src/types/auth.d.ts [read-only], src/index.ts [additive-only]`.

**Sizing rule.** If a unit can't be described in 1-3 sentences with clear acceptance criteria, it's too big. Split. If it touches >5 files, narrow.

**No-placeholders rule (MANDATORY).** Reject any unit that:
- Uses "wire up later", "placeholder for now", "TBD"
- Defers integration without naming the consuming unit by ID
- Describes output without specifying who consumes it
- Creates exports, env vars, config keys without stating where they're read
- Acquires resources (DB, PTY, WebSocket) without specifying cleanup

If a unit can't be fully wired in isolation, split differently or merge with the consumer.

### Phase 4: Integration wiring audit

Before presenting:
- Every WU that creates an export names the consuming unit(s) by ID.
- Every env var / config key introduced by a unit is consumed within the same wave or explicitly carried forward as a dependency.
- Every resource opened (DB, PTY, event bus, WebSocket) has cleanup specified in acceptance criteria.
- No "placeholder", "TBD", "wire later" language.

Fix violations before presenting.

### Phase 5: Present for approval

Show the user the plan summary:
- Phases + milestones
- Work-unit count
- Critical path length
- Top 3 risks

Ask via `AskUserQuestion` if priorities are correct, anything missing, effort feels right. The user knows their domain — their calibration matters.

> **HARD GATE — WAIT FOR USER RESPONSE.** Do not write `project-plan.md` until the user explicitly approves. Do not auto-proceed to Phase 6 on silence; treat unanswered AskUserQuestion as "pause until answered."

### Phase 6: Revise if needed

If the user requests changes, update and re-present. Re-run the wiring audit (Phase 4) after revisions. Do not write the final `project-plan.md` until approved.

### Phase 7: Update companion docs (update mode only)

If a `features.md` or `todo.md` exists, update them to reflect plan changes:
- `features.md`: mark features as planned / in-progress / done based on which WUs land in which state
- `todo.md`: append new TODO bullets for any newly added WUs that don't have a clear owner

**First-run path (neither file exists):** If neither `todo.md` nor `features.md` exists, SEED both from the project context + plan:
1. Read `project-context.md` and `project-plan.md`.
2. Derive the initial todo list from the plan's first phase and any prerequisites. Use the Now / Next / Later / Done format (see `references/update.md` for the spec). Items must reference WU IDs and be actionable.
3. Derive the initial feature list from the project scope and planned capabilities. Use the Shipped / In Progress / Planned / Deferred format. Write from the user's perspective — describe what the product does, not how the code works.
4. Write both files.

### Phase 7.5: Skeleton generation (optional)

After the plan is approved, offer:

> "Plan approved. Want me to scaffold skeleton files (interfaces, types, module stubs, empty function bodies with TODOs) for the work units? This gives implementation a head start without committing to logic."

If yes — spawn a Sonnet subagent (`subagent_type: "general-purpose"`) per WU that creates new files. Each subagent gets:
- The WU's Description, Key Files (with access class), and Acceptance criteria
- Project-context.md's tech stack section
- Instruction to create the file structure with: interfaces, type definitions, function signatures (with `TODO: implement` bodies), and module exports
- Explicit: do NOT implement business logic, only structure

If the user declines, skip. If they accept and the subagent fails, log the failure and continue — skeleton gen is convenience, not blocking.

### Phase 8: Terminal handoff

After the plan is approved and written (and optionally skeletoned):
- From-scratch / update mode: suggest `/execute` (linear) to start building, or `/review` if you want a sanity check first.
- Lightweight mode: suggest `/iterate` to start immediately — the lightweight plan is a checklist, not a build doc.

## References (on-demand)

- `references/from-scratch.md` — full plan generation, phases, executive summary, plan template
- `references/update.md` — incremental plan update, work-unit reconciliation, changelog format
- `references/lightweight.md` — small-scope in-session plan (former `/quick-plan`), no phases, just goal + checklist + risks

## Examples

```
User: /build-plan
→ Phase 0: project-plan.md missing → from-scratch. Reads context + research.
  Pre-checks fan out (Sonnet × 2). Phases, WUs, audit, present, write.
  Handoff: /execute.
```

```
User: WU-3 done, add a migration WU
→ Phase 0: plan exists, user mentioned completed WU → update mode.
  Reads existing plan. Marks WU-3 done. Adds new migration WU.
  Updates features.md + todo.md. Re-runs wiring audit on the new WU.
```

```
User: quick plan to add a dark mode toggle
→ Phase 0: plan exists, scope small + "quick" cue → lightweight mode.
  Reads lightweight.md. Goal + 3-5 bullet checklist + risks.
  Does NOT modify project-plan.md (lightweight plans live in the iterate
  changelog or as a transient `/tmp/lightweight-plan.md`).
  Handoff: /iterate.
```

```
User: rewrite the plan, scope changed completely
→ Phase 0: plan exists + "rewrite" cue. Archive existing as
  project-plan.<date>.md. Run from-scratch flow.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
