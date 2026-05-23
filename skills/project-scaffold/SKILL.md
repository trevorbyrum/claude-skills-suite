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
  src/
```

**Artifact DB**: `artifacts/db.sh` is the skill suite's SQLite helper. It creates and manages `artifacts/project.db` on first use. All intermediate skill outputs (research findings, review findings, session state) are stored there. Final synthesis documents (`artifacts/research/summary/`, `artifacts/reviews/review-synthesis.md`, `artifacts/reviews/production-readiness.md`) remain as files.

3. Copy and personalize the following template files from `templates/` into the
   project root. Replace `{{PROJECT_NAME}}` placeholders with the actual project
   name:

| Template file | Destination |
|---|---|
| `agents-md-template.md` | `AGENTS.md` |
| `claude-md-template.md` | `CLAUDE.md` |
| `codex-instructions-template.md` | `.codex/instructions.md` |
| `copilot-instructions-template.md` | `.github/copilot-instructions.md` |
| `todo-template.md` | `todo.md` |
| `features-template.md` | `features.md` |
| `gitignore-template` | `.gitignore` |
| `../../../references/db.sh` | `artifacts/db.sh` |

Create destination directories as needed: `.github/` and `.codex/`.

After copying all templates, run: `chmod +x artifacts/db.sh`

4. After all files are created, list every file and directory created and
   confirm with the user.

## Exit condition

All directories (`artifacts/research/`, `artifacts/research/summary/`, `artifacts/reviews/`, `docs/`, `src/`) exist. All template
files are present and personalized. `artifacts/db.sh` is present and executable. The user has seen the summary and confirmed.

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
