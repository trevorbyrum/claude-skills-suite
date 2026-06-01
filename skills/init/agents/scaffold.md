# Sonnet Subagent Prompt — Scaffold

Used by `/init` greenfield mode Phase 2a. Fill in `[PLACEHOLDERS]` before spawning.

```
You are scaffolding a new project at [PROJECT_ROOT].

## Project metadata
- Name: [PROJECT_NAME]
- Primary language: [PRIMARY_LANGUAGE]   (e.g. typescript, python, go, rust)
- Type: [PROJECT_TYPE]   (e.g. library, CLI tool, web service, frontend app)

## What to create

### Directories (mkdir -p, all at the project root)
- `src/`
- `tests/`
- `docs/`
- `artifacts/`            (for the artifact DB and review syntheses)
- `references/`           (project-shared bash refs)

### Files at project root
- `.gitignore` — language-appropriate. For TypeScript: node_modules, dist, .env*, *.tsbuildinfo. For Python: __pycache__, *.pyc, .venv/, .env*, dist/, build/. Etc.
- `README.md` — stub with: project name, one-line description, "## Setup" and "## Usage" placeholders. Don't fabricate content.
- Language manifest:
  - TypeScript/JavaScript: `package.json` with sensible defaults (private: true unless library, "type": "module" for new projects, scripts: build, test, lint), plus `tsconfig.json` if TS
  - Python: `pyproject.toml` with [project] section, no deps yet
  - Go: `go.mod` with `go mod init`
  - Rust: `Cargo.toml` with [package] section
  - Others: simplest equivalent for the language

### Bash references (copy from this skill suite, don't recreate)
- Copy this skill suite's `references/db.sh` to `[PROJECT_ROOT]/references/db.sh`
  Source: [ABSOLUTE_PATH_TO_DB_SH]
- Make executable after copy: `chmod +x [PROJECT_ROOT]/references/db.sh`

All persistent state stays local — `artifacts/project.db` for the SQLite store, `artifacts/research/` for synthesis files. No external sync.

### What NOT to do
- Don't initialize git (the next phase handles that).
- Don't create source files in `src/` — the build plan will dictate what goes there.
- Don't add example/demo code that "feels appropriate." If the user wanted it they'd ask.
- Don't pin dependency versions speculatively. The manifest stays empty of runtime deps until needed.

## Return format

Reply with:
- One paragraph summary of what you created
- A `ls -la` tree of the new structure (one level deep)
- Any decisions you made that the user might want to revisit (e.g. ".gitignore template chosen", "package.json type: module — was this right?")

Do NOT call any `db_*` functions. The main thread handles all stateful side-effects after the scaffold.
```
