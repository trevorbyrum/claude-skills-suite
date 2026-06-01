# Dependencies

The skills are bash + Markdown and lean on standard CLI tools. **Only four things are truly required**
(`bash`, `git`, `sqlite3`, `xxd`); everything else is optional and degrades gracefully — each skill
probes PATH and skips what isn't installed.

## Required

| Tool | Why | Install |
|---|---|---|
| `bash` | Skill helper scripts + `references/db.sh` | preinstalled on macOS/Linux; WSL2 on Windows |
| `git` | DB path resolution (`git rev-parse`), `/save`, `/github-sync` | [git-scm.com](https://git-scm.com) / `brew install git` / `apt install git` |
| `sqlite3` | Artifact store (`references/db.sh`) — `/save`, `/execute`, `/review`, `/iterate`, `/research` persist here | macOS: preinstalled · `apt install sqlite3` · `dnf install sqlite` |
| `xxd` | Binary-safe writes in `references/db.sh` | macOS: preinstalled · Linux: `apt install xxd` or `vim-common` |

> Without `sqlite3`/`xxd`, the skills that read/write the artifact DB will error. The rest still run.

## Recommended

| Tool | Why | Install |
|---|---|---|
| `gh` | `/github-sync` push, `/init` greenfield `gh repo create` (falls back to plain `git`) | [cli.github.com](https://cli.github.com) |
| `jq` | JSON parsing in some helper scripts | `brew install jq` / `apt install jq` |
| `python3` | JSON fallback when `jq` is absent | preinstalled on most systems |

## Optional — richer `/review` SAST pre-scan

All skipped gracefully if absent; install whichever match your stack.

| Tool | Lens use | Install |
|---|---|---|
| `gitleaks` | Secret scan (highest priority) | `brew install gitleaks` · `apt install gitleaks` · `cargo install gitleaks` |
| `biome` or `oxlint` | JS/TS lint | `npm i -g @biomejs/biome` · `npm i -g oxlint` |
| `ruff` | Python lint | `pipx install ruff` · `uv tool install ruff` |
| `cargo clippy` | Rust lint | `rustup component add clippy` |
| `semgrep` | Semantic SAST (cross-language) | `pipx install semgrep` |
| `trivy` | Dependency CVE / IaC / secret scan | `brew install trivy` · [trivy docs](https://trivy.dev) |

## Optional — `/init` dependency analysis & `/research`

| Tool | Use | Notes |
|---|---|---|
| `gtimeout` or `timeout` | Per-tool timeout in `/init` dep analysis | macOS: `brew install coreutils` (gtimeout); Linux: `timeout` is built in. Falls back to no wrapper. |
| `dependency-cruiser` / `madge` / `knip` (npx), `vulture`, `go`, `cargo-udeps` | Language-specific dep graphs in `/init` | All optional; `/init` falls back to grep-based import scanning. |
| WebSearch (Claude Code tool) or MCP docs servers (e.g. Context7) | `/research` grounding | Falls back to model knowledge if unavailable. |

## Optional add-on — per-edit Sonnet auto-review (not in this repo)

The packaged `claude_plugin` variant adds a per-edit save-hook (inline formatter/linter chain + a
background **Sonnet** review pass via `claude -p`) and a bundled `mise` toolchain installer. That layer
needs **Node ≥ 22.6**, the **`claude` CLI** (logged in), and `mise`. It's intentionally **not** part of
this skills-only repo; see the `claude_plugin` repo if you want the hooks + installer.

## Platform notes

- **macOS / Linux**: fully supported.
- **Windows**: use **WSL2** — the bash skills behave exactly like Linux. Native-Windows users must
  install **Git Bash** (Git for Windows) for the `.sh` helper scripts to run; WSL2 users do not.
