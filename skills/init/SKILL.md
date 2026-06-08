---
name: init
description: Initializes a project from any starting state — greenfield, joining existing code, partitioning a sub-project, or pivoting scope. Auto-detects which path applies. Invoke with /init.
disable-model-invocation: true
argument-hint: "[merge | <project description>]"
---

# Init

Take a project from any starting state to an approved build plan ready for `/execute`. Four pathways share one detection layer; the matching reference drives the actual flow.

- **Greenfield** — empty directory, no git, no docs
- **Join-existing** — code/repo exists, no `project-context.md`, you're onboarding
- **Sub-project** — partition a parent project into a focused sub-workspace
- **Pivot** — direction change in an existing project (scope rewrite)

## Inputs

| Input | Source | Required |
|---|---|---|
| Project name | User prompt or cwd basename | Yes |
| Project root path | User prompt or cwd | Yes |
| Initial description | User prompt | Yes (greenfield) / Optional (others) |

## Outputs

- Repo scaffold (greenfield only — directories, template files, `.gitignore`, `README.md` stub)
- GitHub repo (greenfield, optional — user confirms)
- `project-context.md` in repo root
- `project-plan.md` in repo root (approved)
- `artifacts/project.db` (SQLite + FTS5)

## Instructions

### Phase 0: Detect mode

Run the detection script:

```bash
bash skills/init/scripts/detect-state.sh
```

Output is one of: `greenfield | join-existing | sub-project | pivot | ambiguous`.

A fifth path — **sub-project-merge** — is user-triggered explicitly (`/init merge`, "merge the sub-project back," or "wrap up the sub-project"). The detect script doesn't auto-detect this; the user knows when work is done.

If `ambiguous`, ask via `AskUserQuestion`:
> "I see <observed state>. Which path?
> - Greenfield — start fresh from this empty dir
> - Join existing — there's code, I'm onboarding
> - Sub-project — partition this from a parent project
> - Sub-project merge — fold a completed sub-project back into its parent
> - Pivot — existing project, but the direction changed"

Read the matching reference:
- greenfield → `references/greenfield.md`
- join-existing → `references/join-existing.md`
- sub-project → `references/sub-project.md`
- sub-project-merge → `references/sub-project-merge.md`
- pivot → `references/pivot.md`

### Phase 1: Confirm project name + slug

Used as the project identifier (e.g., for the `artifacts/research/<NNN>-<topic>/` naming and any downstream tooling). Default:

```bash
SLUG=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
```

Confirm with the user via `AskUserQuestion` before continuing. The slug is hard to rename later once research artifacts and DB entries reference it.

### Phase 2: Run the path

Each reference (`greenfield.md`, `join-existing.md`, `sub-project.md`, `pivot.md`) drives its own phase chain. They cover the work, then return here for Phase 3.

Across all paths, certain phases recur — they're documented inline in each reference but follow a common shape:

- **Interview** (inline, interactive) — uses `agents/questions.md` for the prompt structure
- **Write `project-context.md`** (inline OR via `agents/context-write.md` subagent)
- **Research plan** (optional, spawns Sonnet research subagents or skips with a note)
- **Build plan** (calls `/build-plan` from-scratch mode)

See `references/meta-skill-guards.md` for shared timeout and stall-detection rules used across these multi-phase paths.

### Phase 3: Init artifact DB

```bash
source references/db.sh
db_init
```

Creates `artifacts/project.db` with the schema. Idempotent — re-running on a project that already has the DB is safe.

### Phase 4: Final decision gate

Present the user a summary:
- Project name + slug
- Files created (context, plan)
- DB initialized
- Build plan approved with N work units

Ask via `AskUserQuestion`:

> "Project initialized. What next?
> - Start building — run `/execute` to implement the plan
> - Review first — run `/review` to stress-test the plan
> - Done for now — stop here, return later"

## References (on-demand)

- `references/greenfield.md` — scaffold → repo create → interview → context → research → plan
- `references/join-existing.md` — discover → interview (scoped) → context → plan-or-validate
- `references/sub-project.md` — partition from parent → context → plan (linked to parent)
- `references/pivot.md` — adversarial scope rewrite → updated context → updated plan
- `references/meta-skill-guards.md` — shared timeout + stall detection rules

## Agent prompts (on-demand)

- `agents/questions.md` — interview prompt template (used by all paths in different scopes)
- `agents/scaffold.md` — Sonnet subagent for repo scaffolding (greenfield)
- `agents/context-write.md` — Sonnet subagent for drafting `project-context.md`

## Examples

```
User: /init — new project, real-time collab tool called collab-space
→ Phase 0: empty dir, no git → greenfield. Phase 1: slug = "collab-space".
  Phase 2 (greenfield.md): scaffold → repo create → interview → context → research → plan.
  Phase 3: db_init. Phase 4: user picks "Start building" → suggest /execute.
```

```
User: /init — I cloned this repo, never touched it before
→ Phase 0: .git exists, no project-context.md → join-existing.
  Phase 2 (join-existing.md): discover stack, read existing docs, scoped interview,
  draft context, propose initial plan (or validate existing one).
```

```
User: /init — this should be a sub-project of payments-core
→ Phase 0: ambiguous, AskUserQuestion → sub-project.
  Phase 1: slug = "payments-rewrite" (or what user names). Phase 2 (sub-project.md):
  detect parent at ../payments-core, partition scope, write linked context.
```

```
User: /init — we just pivoted from B2C to B2B
→ Phase 0: existing project + pivot cue → pivot.
  Phase 2 (pivot.md): adversarial review of current context vs new direction,
  scoped rewrite of project-context.md, fresh project-plan.md, archive prior plan.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
