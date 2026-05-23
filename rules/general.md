# General Development Rules

## Communication Style

- **Answer questions first** — don't start building until told to. Present analysis, then wait.
- Concise and direct. Bullet points over prose. No box formatting.

## Approach Selection

- **Before implementing anything non-trivial**, present 2-3 approaches (name, how, limitations, confidence). Wait for pick.
- For infrastructure/deployment especially, propose before executing.

## Plan Mode

- Do NOT exit plan mode until user explicitly approves ("approve", "implement", "go").
- Track change requests as numbered checklist. Re-read before finalizing.

## Account Setup

- Admin accounts: `tbyrum@8-bit-byrum.com`. Credentials in Vault `services/<name>`.

## Security

- NEVER hardcode secrets. Use env vars + empty-string fallbacks.
- `.env` (gitignored) for runtime, `.env.example` (committed) for docs.
- Secret scan before any public/shared commit.

## Design Philosophy

- Sleek, minimal, "holy shit this is nice" — Steve Jobs taste
- UI: glassmorphism, liquidmorphism, neomorphism (mix per project)
- Documents: Fortune 500 consulting quality. Present 3 style options first.
- Details: see auto-memory topic file [design-philosophy.md]

## Model Delegation & Cost

- **Opus**: orchestration, architecture, debugging, multi-step reasoning
- **Sonnet subagents**: implementation, tests, exploration, repetitive edits
- **Haiku**: file searches, simple transforms, status checks
- Context >200K tokens = input cost doubles — fork/compact proactively
- Prefer Task tool with model delegation over doing everything in main context

### Polling (MANDATORY)

- **NEVER sleep+poll loops** — burns context tokens per round trip
- Use `run_in_background: true` on Bash, `TaskOutput` for status checks
- Only background fire-and-forget work; inline if output needed for next step

### Large Output Management

- Pipe 50KB+ responses to files, summarize. Use `head_limit` on Grep/Glob.
- Redirect stdout to files (`> /private/tmp/output.json`) and read selectively.

## Infrastructure

- Tower (Unraid) via SSH MCP. Docker on `traefik_proxy`. Cloudflare DNS+SSL.
- GitLab CE = source of truth. GitHub = public mirror. Mattermost = notifications (ntfy dead).
- Vault for credentials.

## AI Delegation

External agents are available through driver interfaces. **Codex is MCP-first**:
call the `codex-mcp` tools directly. For Copilot, load the `/copilot` driver
skill before invoking the CLI. The Gemini, Cursor, and Vibe driver skills
have been removed — anywhere they used to be invoked, use Codex MCP
(code-centric work) or a Sonnet subagent (research, devil's advocate, web
grounding via WebSearch). Do NOT duplicate CLI flags in consuming skills.

### Driver Boundary (MANDATORY)

- Any skill that dispatches **Codex** must call `mcp__codex-mcp__codex_health`,
  `mcp__codex-mcp__codex_run`, or the async `codex_start`/`codex_status`/`codex_result`
  MCP flow. Never call raw `codex exec` or any legacy Codex shell wrapper.
- Any skill that dispatches **Copilot** must reference the `/copilot` driver skill for invocation details.
- Any skill that needs **research, devil's advocate, web grounding, or large-doc analysis** spawns a **Sonnet subagent** via the Agent tool (use `subagent_type: "general-purpose"` with WebSearch when web grounding is needed).
- Consuming skills may specify only: task type, prompt contract/template, output file path, concurrency expectations, and fallback behavior.
- Consuming skills must **NOT** embed CLI commands, flags, auth checks, PATH setup, timeout syntax, model-selection syntax, or gotcha lists for those agents.
- If Codex invocation details need to change, update the `codex-mcp` server and shared MCP guidance. If Copilot invocation details need to change, update `/copilot` only.

- **Codex MCP**: code review, generation, lint. $20/mo flat. Primary code-centric worker.
- **Copilot**: code review, generation, multi-model tasks. Premium request quota.
- **Sonnet subagents**: research, devil's advocate, web grounding, architecture/strategy reviews, doc generation. Managed by Claude runtime.
- **Claude Code (Opus)**: orchestrator — architecture, debugging, synthesis, final decisions.

Key rules:
- ALWAYS wrap non-Codex CLI calls (e.g., Copilot) with `$GTIMEOUT` (absolute path `/opt/homebrew/bin/gtimeout`). Codex uses MCP `timeout_sec` instead.
- Claude is ALWAYS the orchestrator. Never delegate architecture/security alone.
- Graceful degradation if external agents are unavailable. For Codex, check `mcp__codex-mcp__codex_health`; for Copilot, check dynamic path resolution in `/copilot`.
- Timeouts: 120s research/review, 180s generation, 300s complex tasks. For Codex MCP, set `timeout_sec`.

### Concurrency Hard Limits (MANDATORY — DO NOT OVERRIDE)

- **Codex MCP**: max **5** concurrent jobs. Queue any excess.
- **Copilot**: max **2** concurrent processes. Queue any excess.
- **Sonnet subagents**: no hard limit (managed by Claude runtime).
- These limits apply to ALL skills — meta-review, meta-execute, meta-research, etc.
- If a skill says otherwise, THIS FILE wins. Period.

### Parallel Patterns

- **Research**: Sonnet subagent w/ WebSearch + Codex MCP code research + Claude tools simultaneously.
- **Review**: 12-13 Sonnet lenses + 8-9 Codex MCP code-centric pairs in meta-review. Synthesize by agreement.
- **Implementation**: Single Codex MCP generation per WU + 3-4 reviewer panel (Codex MCP review+fix, Sonnet rubric subagent, Sonnet architecture subagent, optional Copilot). Claude orchestrates.
- **Pre-commit**: Codex MCP lint or project hooks.
