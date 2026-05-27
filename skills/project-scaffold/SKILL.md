---
name: project-scaffold
description: "Scaffolds a new project with standard folder structure, templates, and config files. Use when the user asks to scaffold or set up a new project."
disable-model-invocation: true
---

# project-scaffold

Create the canonical folder structure and seed files for a new project. Every
project in this suite shares the same skeleton so that any agent (Claude, Codex,
Copilot) can cold-start from any project and immediately know where things live.

## When to use

- User says "new project", "scaffold", "init", or names a project to start.
- A project directory exists but is missing standard files.
- User asks "set up the folder structure" or "create the template files."

## Inputs

| Input | Source | Required |
|---|---|---|
| Project name | User prompt | Yes |
| Project root path | User prompt or cwd | Yes |
| Templates | Bundled in `templates/` beside this skill | Yes |

## Instructions

1. Confirm the project name and root path with the user. Do not assume — ask if
   ambiguous.

2. Create the following directory tree under the project root:

```
<project-root>/
  artifacts/
    research/
      summary/
    reviews/
  docs/
  schema/
    migrations/
  src/
```

**Artifact DB**: `artifacts/db.sh` is the skill suite's SQLite helper. It creates and manages `artifacts/project.db` on first use. All intermediate skill outputs (research findings, review findings, session state) are stored there. Final synthesis documents (`artifacts/research/summary/`, `artifacts/reviews/review-synthesis.md`, `artifacts/reviews/production-readiness.md`) remain as files.

**Schema directory**: `schema/` is the single source of truth for any persistent
data shape — DB tables, key file formats, API contracts. The `breaking-change-review`
skill reads this directory in schema-drift mode to flag code that diverges from
the canonical definitions. Projects that don't use a database can leave the
directory empty (the README still documents the convention for the next agent
that arrives). See the `schema-readme-template.md` for the workflow.

3. Copy and personalize the following template files from `templates/` into the
   project root. Replace `{{PROJECT_NAME}}` placeholders with the actual project
   name:

| Template file | Destination |
|---|---|
| `agents-md-template.md` | `AGENTS.md` (see step 3a for auto-generation when project-context.md already exists) |
| `claude-md-template.md` | `CLAUDE.md` |
| `codex-instructions-template.md` | `.codex/instructions.md` |
| `copilot-instructions-template.md` | `.github/copilot-instructions.md` |
| `todo-template.md` | `todo.md` |
| `features-template.md` | `features.md` |
| `gitignore-template` | `.gitignore` |
| `schema-readme-template.md` | `schema/README.md` |
| `schema-tables-template.sql` | `schema/tables.sql` |
| `schema-migration-template.sql` | `schema/migrations/000_template.sql` (commented placeholder for the first real migration) |
| `../../../references/db.sh` | `artifacts/db.sh` |

Create destination directories as needed: `.github/`, `.codex/`, and `schema/migrations/`.

After copying all templates, run: `chmod +x artifacts/db.sh`

#### 3a. AGENTS.md auto-generation (when project-context.md exists)

`AGENTS.md` is the cross-tool standard read by Claude Code, Codex, Copilot,
and other agents at the start of a session. It encodes the project's
conventions in a concise, agent-friendly format.

If `project-context.md` exists at the project root, **generate** AGENTS.md
from it instead of copying the empty template:

1. Read `project-context.md`. Extract:
   - **Stack** (languages, frameworks, databases) → fills `{{STACK_DESCRIPTION}}`
   - **Commands** (build, test, lint) → fills `{{BUILD_COMMAND}}`, `{{TEST_COMMAND}}`, `{{LINT_COMMAND}}` (search project for package.json scripts, Makefile, justfile)
   - **Coding conventions** → fills `{{LANGUAGE_CONVENTIONS}}` (e.g., "Go: gofmt, no `interface{}`, errors.Is for comparisons"; "TypeScript: strict mode, no `any`, prefer named exports")
2. Apply the values to `agents-md-template.md` and write to `AGENTS.md`.
3. Append a line at the bottom referencing the canonical context:
   ```
   This file is regenerated from project-context.md by /project-scaffold and /sync-skills. Edit project-context.md, then rerun to refresh.
   ```

If `project-context.md` does NOT exist, copy the template verbatim. AGENTS.md
becomes a stub that the user fills in (or that `/meta-init` overwrites when it
later runs `/project-context`).

4. After all files are created, list every file and directory created and
   confirm with the user.

## Exit condition

All directories exist (`artifacts/research/`, `artifacts/research/summary/`,
`artifacts/reviews/`, `docs/`, `schema/migrations/`, `src/`). All template
files are present and personalized. `artifacts/db.sh` is present and
executable. `AGENTS.md` is either generated from project-context.md (if it
existed) or copied as a stub. The user has seen the summary and confirmed.

## Examples

```
User: "Start a new project called nexus-api"
Action: Ask for root path, scaffold all folders and files under that path with
        PROJECT_NAME = nexus-api.
```

```
User: "I have a project at ~/projects/dashboard but it's missing the standard files"
Action: Check which standard files are missing, create only the missing ones.
        Do not overwrite existing files without asking.
```

```
User: "scaffold"
Action: Ask for project name and path, then proceed.
```

## Cross-cutting

Before completing, read and follow `references/cross-cutting-rules.md`.
