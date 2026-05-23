# Claude Skills Suite

A production skill suite for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that orchestrates multi-model development workflows. 42 skills, 10 specialized agents, and 7 lifecycle hooks — designed for projects where AI writes, reviews, and ships code with human oversight at every gate.

## What This Does

Instead of using Claude Code as a single-model assistant, this suite turns it into an **orchestration layer** that delegates work across Claude (Opus + Sonnet subagents), Codex MCP, and Copilot, runs parallel review panels, and enforces quality gates before anything ships.

```
You say: "Initialize a new project"
Claude runs: /meta-init
  → Scaffolds project structure
  → Interviews you about goals and constraints
  → Writes project-context.md (the cold-start doc)
  → Fans out research across Sonnet WebSearch subagents + Codex MCP + connector MCPs
  → Produces an approved build plan with dependency-ordered work units

You say: "Build it"
Claude runs: /meta-execute
  → Generates code via Codex MCP (one candidate per work unit)
  → Reviews each unit with a 3-4 reviewer panel (Codex MCP review+fix, Sonnet rubric, Sonnet architecture, optional Copilot)
  → Merges passing units wave-by-wave with review gates between each wave
  → You approve each wave before the next one starts

You say: "Is this ready to ship?"
Claude runs: /meta-production
  → Scores 12 dimensions (SLO/SLI, deployment, observability, security, chaos readiness...)
  → Verdict: READY / CONDITIONAL / NOT READY
```

## Architecture

```
                         ┌─────────────────────────────┐
                         │     Meta-Skills (6)          │
                         │  Orchestrators that chain    │
                         │  atomic skills + models      │
                         └──────────┬──────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  Atomic Skills    │  │  Review Lenses    │  │  Workers          │
   │  (21 skills)      │  │  (8 skills)       │  │                   │
   │                   │  │                   │  │  Codex MCP        │
   │  scaffold, plan,  │  │  security, test,  │  │  broker           │
   │  research, build, │  │  counter, drift,  │  │  /copilot driver  │
   │  sync, release... │  │  refactor, comp-  │  │  Sonnet subagents │
   │                   │  │  leteness, comp-  │  │  (Agent tool with │
   │                   │  │  liance, browser  │  │   WebSearch)      │
   └──────────────────┘  └──────────────────┘  └──────────────────┘
              │                     │                     │
              └─────────────────────┼─────────────────────┘
                                    ▼
                         ┌─────────────────────────────┐
                         │     Infrastructure           │
                         │  hooks, agents, artifact DB, │
                         │  cross-cutting rules         │
                         └─────────────────────────────┘
```

### Progressive Disclosure

Skills load in 3 levels to minimize context window usage:

| Level | What Loads | When |
|-------|-----------|------|
| **1. Metadata** | Frontmatter only (name + description) | Always — part of skill index |
| **2. SKILL.md body** | Full instructions, examples, I/O spec | On trigger — when you invoke the skill |
| **3. References** | Deep catalogs, checklists, agent prompts | On demand — only when a specific section needs it |

This means a 270-line review skill with 6 reference files only loads ~150 chars until triggered, then ~270 lines, and never loads reference material unless it reaches the step that needs it.

## Skill Catalog

### Meta-Skills (Orchestrators)

| Skill | What It Does |
|-------|-------------|
| `/meta-init` | Zero-to-plan: scaffold, interview, research, build plan |
| `/meta-execute` | Parallel implementation with cross-model Best-of-2 generation + 5-reviewer panel |
| `/meta-review` | 7-lens review across 3 model families (12 parallel reviews) |
| `/meta-research` | End-to-end research pipeline with parallel connector fan-out |
| `/meta-deep-research` | Exhaustive research with ~20 workers and adversarial debate |
| `/meta-production` | 12-dimension production readiness scoring |

### Review Lenses

Each lens runs standalone or as part of `/meta-review`:

| Skill | Focus |
|-------|-------|
| `/security-review` | Dependencies, auth, secrets, injection, OWASP Agentic Top 10 |
| `/test-review` | Coverage, mutation testing, PBT, contract tests, LLM anti-patterns |
| `/counter-review` | Adversarial red-team: abuse cases, attack chains, failure scenarios |
| `/refactor-review` | Over-engineering, duplication, bloat, unnecessary abstractions |
| `/drift-review` | Code vs docs drift detection |
| `/completeness-review` | Stubs, TODOs, placeholders, empty bodies |
| `/compliance-review` | Code vs project rules adherence |
| `/browser-review` | Visual QA via Playwright/browser-use |

### Project Lifecycle

| Skill | What It Does |
|-------|-------------|
| `/project-scaffold` | Standard folder structure + templates |
| `/project-questions` | Deep-dive interview before planning |
| `/project-context` | Writes the cold-start handoff doc |
| `/research-plan` | Prioritized research with topic-to-connector mapping |
| `/research-execute` | Parallel research execution across connectors |
| `/build-plan` | Phased implementation plan with work unit decomposition |
| `/meta-join` | Onboard to an existing project (full or quick mode) |
| `/evolve` | Sync project docs to match current code reality |

### Development & Operations

| Skill | What It Does |
|-------|-------------|
| `/github-sync` | Commit and push with conventional commit messages |
| `/github-pull` | Pull latest changes from remote |
| `/review-fix` | Implement fixes from review findings with worker dispatch |
| `/release-prep` | Changelog, version bump, release notes, git tag |
| `/deploy-gateway` | MCP gateway container deployment |
| `/infra-health` | Service health checks across containers and endpoints |
| `/meta-context-save` | Preserve session state before compacting/clearing |
| `/todo-features` | Update project tracking files |
| `/repo-create` | Initialize or connect GitHub repos |
| `/init-db` | Bootstrap SQLite+FTS5 artifact store |

### Tooling

| Skill | What It Does |
|-------|-------------|
| `/skill-forge` | Create or edit skills with template + validation checklist |
| `/skill-doctor` | Self-diagnostic for the skill suite |
| `/quick-plan` | Lightweight in-session planning |
| `/sync-skills` | Inject missing or stale template files into projects |

### Driver Interfaces

These encode the exact syntax, path discovery, and gotchas for each external agent so consuming skills don't have to:

| Interface | Backend | Model |
|-------|-----|-------|
| `codex-mcp` MCP tools | OpenAI Codex CLI via local broker | Subscription-backed Codex |
| `/copilot` skill | GitHub Copilot CLI | Configurable (default: Sonnet 4.5) |
| Sonnet subagents (Agent tool) | Claude runtime — no external CLI | Sonnet 4.6 |

## Multi-Model Orchestration

The suite treats AI models as specialized workers, not interchangeable commodities:

| Role | Worker | Why |
|------|------------|-----|
| **Orchestration** | Claude (Opus) | Architecture decisions, synthesis, final calls |
| **Code generation** | Codex MCP `generate` | Single dedicated coder; diversity comes from the reviewer panel |
| **Code review + fix** | Codex MCP `generate` (review prompt) | Only reviewer that applies fixes in-place |
| **Rubric / architecture review** | Sonnet subagents (Agent tool) | Independent perspectives, no write access |
| **Web research / devil's advocate** | Sonnet subagents with WebSearch | Current sources + adversarial framing |
| **Different-model perspective** | Copilot (optional) | Cross-vendor sanity check |

### Concurrency Limits

Hard limits enforced across all skills:

| Worker | Max Concurrent |
|-----|---------------|
| Codex MCP | 5 |
| Copilot | 2 |
| Sonnet subagents | no hard limit (managed by Claude runtime) |

## Artifact Store

Skills persist intermediate findings in a SQLite + FTS5 database (`artifacts/project.db`), not scattered markdown files. This enables:

- **Fresh-findings check**: Review lenses skip re-scanning if results are <24 hours old
- **Full-text search**: Find findings across all lenses with `db_search`
- **Cross-lens synthesis**: Meta-review reads findings from all lenses via DB queries

```bash
source artifacts/db.sh
db_upsert 'security-review' 'findings' 'standalone' "$CONTENT"
db_read 'security-review' 'findings' 'standalone'
db_search 'SQL injection'
db_age_hours 'security-review' 'findings' 'standalone'
```

## Installation

1. Clone this repo to a shared location:
   ```bash
   git clone https://github.com/trevorbyrum/claude-skills-suite.git ~/shared/claude-skills
   ```

2. Point Claude Code at it. Add to your project's `.claude/settings.json`:
   ```json
   {
     "skills": ["~/shared/claude-skills/skills"]
   }
   ```

   Or for user-wide access, add to `~/.claude/settings.json`.

3. Initialize the artifact store in any project:
   ```
   /init-db
   ```

4. Verify the suite is working:
   ```
   /skill-doctor
   ```

### Optional: External CLIs

The suite works with Claude alone, but multi-model features require external CLIs:

| CLI | Install | Used For |
|-----|---------|----------|
| Codex via `codex-mcp` | Register `/Users/byrum_work/Projects/mcp-servers/codex-mcp` with Claude Code | Review+fix, code generation |
| [Copilot](https://github.com/github/copilot-cli) | `npm install -g @githubnext/github-copilot-cli` | Optional 4th reviewer, different-model perspective |

All CLIs are optional — skills gracefully degrade when a CLI is unavailable, falling back to Sonnet subagents.

> **Removed (2026-05-20)**: The previous Gemini, Cursor, and Vibe driver skills were removed. Anywhere they were used, the suite now dispatches a Sonnet subagent (research, devil's advocate, web grounding via WebSearch) or Codex MCP (code generation, review+fix).

## Creating New Skills

```
/skill-forge my-new-skill
```

This scaffolds the directory, writes SKILL.md from the canonical template, and validates against a 40+ check validation checklist covering structure, anti-patterns, and integration rules.

See [skills/skill-forge/references/skill-template.md](skills/skill-forge/references/skill-template.md) for the full template specification.

## Project Structure

```
├── skills/                    # 42 skill directories, each with SKILL.md
│   ├── meta-*/                # Orchestrators
│   ├── *-review/              # Review lenses (+ references/)
│   ├── copilot/               # CLI driver skill (Copilot only; Codex is MCP-first)
│   └── skill-forge/           # Skill creation/editing tool
├── agents/                    # 10 specialized subagent definitions
├── hooks/                     # 7 lifecycle hooks (session, commit, compact)
├── references/                # Shared references (db.sh, cross-cutting rules)
├── rules/                     # Global rules (general.md)
├── artifacts/                 # Research summaries (DB is gitignored)
└── skill-suite-build-spec.md  # Architecture specification
```

## License

MIT
