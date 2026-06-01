# Execute — Phase 1.5: Decomposition Validation

Full detail for the decomposition ceremony. Called from SKILL.md Phase 1.5.

## Step 1: Read unstarted WUs

Read `project-plan.md`. Identify every WU whose status is not `done` / `[done]` / `in-progress`. These are candidates for the decomposition table.

## Step 2: Per-WU validation

For each unstarted WU, validate:

1. **LOC estimate** — must be in the 50-200 LOC goldilocks zone.
   - < 50 LOC: warn "consider batching with a related WU"; do NOT block.
   - > 200 LOC: warn "consider decomposing further"; do NOT block.
   - Missing estimate: warn "no LOC estimate — add one in `project-plan.md`".

2. **Key Files access classification** — each file listed in the WU's Key Files must carry one of:
   - `read-only` — type definitions, constants, interfaces — safe to share freely.
   - `additive-only` — central export/config files (`index.ts`, config arrays) — safe to share but require sequential merge lock.
   - `mutable` — everything else — exclusive ownership, only one WU per wave may list this file as mutable.

   If no access class is present in the plan, default to `mutable` (conservative) and note it in the table.

## Step 3: Build the cross-wave file-ownership map

For every `mutable` file across all unstarted WUs, build a map:

```
mutable-file-ownership:
  src/auth.ts → Wave 1 / WU-1-02
  src/api.ts  → Wave 1 / WU-1-03
  src/db.ts   → Wave 2 / WU-2-01
```

**Conflict rule**: if two WUs in the SAME wave both list the same file as `mutable`, that is a conflict. Conflicts must be resolved before proceeding:
- Option A: Cluster both WUs into one Sonnet subagent that handles them in dependency order (preferred — preserves parallelism for the rest of the wave).
- Option B: Move one WU to the next wave.
- Option C: Re-classify one WU's access to `additive-only` if that is accurate.

Present conflicts to the user — do NOT silently choose an option. Surface each conflict by name:
> "WU-1-02 and WU-1-03 both list `src/api.ts` as mutable in Wave 1. How should this be resolved? (A) cluster them, (B) move one to Wave 2, (C) re-classify?"

## Step 4: Build the decomposition table

Present this table to the user:

```
| Wave | WU ID | LOC Est | Key Files (access class) | Parallelizable? | Notes |
|------|-------|---------|--------------------------|-----------------|-------|
| 1    | WU-1-01 | ~80   | src/models.ts (mutable)  | yes             |       |
| 1    | WU-1-02 | ~120  | src/auth.ts (mutable)    | yes             |       |
| 2    | WU-2-01 | ~60   | src/db.ts (mutable)      | yes (after W1)  |       |
```

**Parallelizable?** is `yes` when:
- No same-wave dependency on an unfinished WU
- No `mutable` file collision with any other same-wave WU (after conflict resolution above)

## Step 5: User confirmation gate (HARD GATE)

Present the full table, then ask via `AskUserQuestion`:

> "Proceed with this decomposition? (yes / adjust / stop)"

**HARD GATE — do NOT proceed until the user responds with approval.**

- `yes` → continue to SKILL.md Phase 2 (build queue).
- `adjust` → re-open the specific adjustment (LOC, access class, wave assignment) and re-present the updated table.
- `stop` → halt. Tell the user to update `project-plan.md` and re-run `/execute`.

Conflicts flagged in Step 3 must be resolved before the gate can be passed. If any unresolved conflict remains in the table, re-surface it and block.

---

Before completing, read and follow cross-cutting-rules.md.
