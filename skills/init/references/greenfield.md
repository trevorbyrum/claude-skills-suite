# Init — Greenfield Mode

Empty directory → approved plan + repo. The most involved path.

## Phase chain

```
Scaffold → Repo Create → Interview → Context → (optional Research) → Plan → Final Gate
```

## Phase 2a: Scaffold [Sonnet subagent]

Dispatch a Sonnet subagent (`subagent_type: "general-purpose"`) with `agents/scaffold.md` as the prompt template. Fill in:
- `[PROJECT_NAME]`
- `[PROJECT_ROOT]`
- `[PRIMARY_LANGUAGE]` (from user description; ask if unclear)

The subagent creates:
- Standard directories: `src/`, `tests/`, `docs/`, `artifacts/`, `references/` (the project-level shared refs dir)
- Template files: `README.md` (stub), `.gitignore` (language-appropriate), language-specific manifest (`package.json`, `pyproject.toml`, `Cargo.toml`, etc.)
- A copy of `db.sh` from this plugin's `references/db.sh` into the new project's `references/db.sh` so the project has its own local artifact-DB wrapper

The subagent returns a summary. Present to the user. Confirm via `AskUserQuestion`.

## Phase 2b: Repo Create [inline, interactive]

This is interactive — needs the user's input. Don't subagent it.

1. Ask: "Initialize a GitHub repo? Public or private?"
2. If yes:
   - `git init`
   - First commit with the scaffold
   - `gh repo create <name> --<visibility> --source=. --push`
   - Report the URL
3. If no: just `git init` locally. The user can connect a remote later via `/github-sync`.

## Phase 2c-pre: Domain grounding [Sonnet subagent, parallel-OK]

Before the interview, spawn a Sonnet subagent (`subagent_type: "general-purpose"`) using `agents/domain-grounding.md` to build a domain primer. This runs in parallel with anything else you'd normally do here; main thread waits for it before Phase 2c starts the interview.

The primer gives the interviewer:
- Landscape (competitors / prior art)
- Glossary of domain terms
- Common pitfalls
- Regulatory overlay
- Conventional tech stack defaults
- 3-5 sharper questions tailored to the domain

If WebSearch is unavailable, the subagent returns "skipped" and the interview falls back to generic prompts in `agents/questions.md`.

## Phase 2c: Interview [inline, interactive]

Use `agents/questions.md` for the structure, **plus the domain primer from Phase 2c-pre** to sharpen questions. Run the interview inline (asking via `AskUserQuestion`). The interview is the foundation everything downstream depends on. Do not rush.

Topics (in this order):
1. **Problem & users** — what's being built and for whom
2. **Core constraints** — tech stack preferences, deployment target, scale expectations
3. **Out-of-scope** — what this project explicitly will NOT do
4. **Key decisions already made** — anything the user has already locked in
5. **Risks the user is aware of** — surface them before they bite

Aim for 8-15 questions total. Don't over-interview; if a question would be answered by reading the README of a common framework, skip it.

## Phase 2d: Context [inline OR Sonnet subagent]

Two paths:

- **Inline (default)** — Claude drafts `project-context.md` from the interview directly. Faster. Sufficient when the project is straightforward.
- **Subagent** — Spawn with `agents/context-write.md` when the interview produced 20+ pages of notes and synthesis is heavy.

Either way, the final document follows this structure:

```markdown
# Project Context — <project-name>

## Problem
[1-2 paragraphs: what's being solved and why]

## Users / Stakeholders
[Who uses this, in what scenarios]

## Scope
- **In scope**: [bullets]
- **Out of scope**: [bullets — explicit non-goals]

## Tech Stack
[Languages, frameworks, key libraries with one-line rationale each]

## Constraints
[Deployment, scale, regulatory, budget, time]

## Key Decisions
[Decisions locked at init. Includes alternatives considered.]

## Risks
[Known unknowns + mitigation hooks]

## Glossary
[Domain terms the future agent / future-you will need]

## Changelog
[Newest-first; first entry: "Initial context — <date>"]
```

Present the draft to the user for review. Get approval before writing the file.

## Phase 2d.5: AGENTS.md auto-generation

After `project-context.md` is approved, generate the project's `AGENTS.md` by filling the template placeholders from the context document:

- `{{STACK_DESCRIPTION}}` ← from context's "Tech Stack" section
- `{{BUILD_COMMAND}}` ← derived from stack (e.g., `npm run build`, `cargo build`, `python -m build`)
- `{{TEST_COMMAND}}` ← from stack (e.g., `npm test`, `pytest`, `cargo test`)
- `{{LINT_COMMAND}}` ← from stack (e.g., `npm run lint`, `ruff check`, `cargo clippy`)
- `{{LANGUAGE_CONVENTIONS}}` ← short bullet list per stack language (e.g., "TypeScript: strict mode, no `any` without justification; ESM imports")

Footer the generated AGENTS.md with a comment line `<!-- Auto-generated from project-context.md on YYYY-MM-DD. Re-run via /init or /save doc-refresh when context changes. -->` so the convention is visible.

If a template doesn't exist in the project (greenfield from a totally empty dir), use this canonical AGENTS.md skeleton (modeled after this plugin's own `AGENTS.md`):

- Project name + one-line description
- `## Stack`
- `## Commands` (build / test / lint)
- `## Code Style`
- `## Boundaries` (ALWAYS / ASK FIRST / NEVER)
- `## Project Context` (pointers to project-context.md, project-plan.md, features.md)
- `## Commit Convention`

Present for user review before writing.

## Phase 2d.6: Schema scaffolding (if context mentions a database)

If `project-context.md`'s "Tech Stack" section names a database (Postgres, MySQL, SQLite, MongoDB, etc.), create:

```text
schema/
├── README.md          ← migration philosophy + how to run
├── tables/            ← one file per logical table
└── migrations/        ← timestamped migration files
```

Copy minimal templates (1-2 example files in each subdir; the user fills in actual schema during execution). If context doesn't mention a DB, skip silently.

## Phase 2d.7: `.gitignore` fallback

If the scaffold subagent (Phase 2a) didn't create a `.gitignore` for any reason (skipped, errored, or returned partial), drop a sensible default:

```text
# OS
.DS_Store
Thumbs.db

# Env
.env
.env.*
!.env.example

# Logs
*.log

# Artifact DB write-ahead state
artifacts/project.db-journal
artifacts/project.db-shm
artifacts/project.db-wal

# Language-common
node_modules/
__pycache__/
*.pyc
.venv/
dist/
build/
target/
```

Append per-language defaults as the project evolves.

## Phase 2e: Research (optional)

Ask via `AskUserQuestion`:

> "Run a research pass before planning? Spawns Sonnet subagents (~10-15 min) to validate tech choices and surface risks. Skip if you've already done your homework."

If yes: spawn Sonnet research subagents to validate tech choices and surface risks (use WebSearch). Synthesis lands locally at `artifacts/research/001-<topic>/synthesis.md`. Return to Phase 2f when complete.

If no: continue to Phase 2f.

## Phase 2f: Plan

Hand off to `/build-plan` from-scratch mode. It reads `project-context.md` (and any research synthesis from `artifacts/research/`) and produces `project-plan.md`. The user approves before this skill writes the file.

After Phase 2f, return to SKILL.md Phase 3 (DB init).

## Phase order rationale

Scaffold first because subsequent phases assume the directory structure exists. Repo create immediately after so the first commit captures the scaffold (audit trail). Interview before context because context comes from the interview. Research optional because not every project needs it. Plan last because plan needs context.

## Error handling

- Scaffold fails or partial: surface, fix manually, then re-run Phase 2a.
- `gh repo create` fails (no `gh` auth): note, continue with local git only. Connect remote later.
- Interview stalls (user goes quiet for 10+ min): save partial answers to `artifacts/init-interview-partial.md`, exit, tell the user to resume with `/init` (which will detect partial state).
- Research subagent times out: present partial findings, continue to plan with what we have.
