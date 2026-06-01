# claude-skills-suite

A 9-skill lifecycle suite for [Claude Code](https://claude.com/claude-code) — takes a project from
"empty directory" to "shipped" without leaving the CLI. **Skills only**: no plugin packaging, no
required external services, no homelab dependencies. Every model call goes through your own Claude
subscription (main-thread Claude + Sonnet subagents); there are **no third-party AI drivers** (no
Codex / Copilot / Gemini).

> Looking for the packaged plugin (with the per-edit auto-review hooks + bundled CLI installer)?
> That's the `claude_plugin` variant. This repo is the skills + shared infra on their own.

## The skills

**Lifecycle (7)** — user-triggered:

| Skill | What it does |
|---|---|
| `/init` | Initialize a project from any starting state (greenfield, existing code, sub-project, pivot). Auto-detects which path applies. |
| `/research` | Parallel Sonnet subagent workers research a topic; writes a structured synthesis. |
| `/build-plan` | Decompose the project into phases / milestones / work units with explicit dependencies. |
| `/execute` | Implement work units from the plan (linear, single-WU, or review-fix modes). |
| `/iterate` | Lightweight ad-hoc loop with append-only changelog (bug-fix / stuck / TDD). |
| `/review` | 12-lens parallel Sonnet review + SAST pre-scan (gitleaks + linters + semgrep/trivy when present). |
| `/save` | Snapshot session state, refresh plan status, optionally compact/clear. |

**Action (2)** — auto-invocable:

| Skill | What it does |
|---|---|
| `/github-sync` | Detects pull / push / both from git state; auto-generates conventional-commit messages. |
| `/skill-forge` | Create or edit a skill against the canonical template + validation checklist. |

All branching is auto-detected or `AskUserQuestion`-driven — **no `--flag` arguments anywhere**.

## Layout

```
skills/<name>/          # SKILL.md + optional references/, agents/, scripts/, templates/
references/
  ├── db.sh             # SQLite + FTS5 artifact store (skills source this)
  └── cross-cutting-rules.md
```

The skills reference shared infra by relative path (`../../references/…`), so **`skills/` and
`references/` must keep their relative layout** — install them together, not `skills/` alone.

## Install

```bash
git clone https://github.com/trevorbyrum/claude-skills-suite.git
```

Then make the skills discoverable to Claude Code, preserving the `skills/ ↔ references/` relationship:

- **As a project's skills**: copy `skills/` and `references/` into the project root (or a subdir you
  point Claude at). The `../../references/` paths resolve from `skills/<name>/`.
- **User-wide**: copy `skills/*` into `~/.claude/skills/` **and** `references/` into `~/.claude/references/`
  so `skills/<name>/../../references/` resolves to `~/.claude/references/`.

> ⚠️ If `references/` isn't reachable at `skills/<name>/../../references/`, the skills that persist to
> the artifact DB (`/save`, `/execute`, `/review`, `/iterate`, `/research`) will fail to read/write state.

## Dependencies

See **[DEPENDENCIES.md](DEPENDENCIES.md)** for the full list with per-OS install commands. In short:

- **Required**: `bash`, `git`, `sqlite3`, `xxd` (the last two back the artifact store in `references/db.sh`).
- **Recommended**: `gh` (GitHub flows), `jq`, `python3`.
- **Optional, for richer `/review`** (skipped gracefully if absent): `gitleaks`, `biome`/`oxlint`, `ruff`,
  `cargo clippy`, `semgrep`, `trivy`.
- **Optional, for `/init` dep-analysis & `/research`**: `gtimeout`/`timeout`, language dep tools, WebSearch.

Everything optional degrades gracefully — the skills detect what's on PATH and skip what isn't.

## Platform

macOS and Linux are first-class. On **Windows, use WSL2** (run Claude Code inside your WSL distro; the
bash-based skills behave exactly like Linux). Native-Windows users need **Git Bash** for the `.sh`
helper scripts; WSL2 users do not.

## License

MIT — see [LICENSE](LICENSE).
