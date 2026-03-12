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

## AI CLI Delegation

Six CLIs available. **Load the driver skill** (`/gemini`, `/codex`, `/copilot`, `/cursor`, `/vibe`) before invoking any CLI — they are the single source of truth for syntax, path resolution, and gotchas. Do NOT duplicate CLI flags in consuming skills.

### Driver Skill Boundary (MANDATORY)

- Any skill that dispatches **Gemini, Codex, Copilot, Cursor, or Vibe** must reference the corresponding driver skill for invocation details.
- Consuming skills may specify only: task type, prompt contract/template, output file path, concurrency expectations, and fallback behavior.
- Consuming skills must **NOT** embed CLI commands, flags, auth checks, PATH setup, timeout syntax, model-selection syntax, or gotcha lists for those agents.
- If invocation details need to change, update the driver skill only. Do not patch copies of the command in downstream skills.
- For **Vibe specifically**, prompts must be scoped to exact files, directories, or a single work unit with explicit coding instructions and success criteria. Do NOT send broad "analyze the whole project" or "figure out what to change" prompts.

- **Gemini**: web research, devil's advocate, large doc analysis. FREE.
- **Codex**: code review, generation, lint. $20/mo flat.
- **Copilot**: code review, generation, multi-model tasks. Premium request quota.
- **Cursor**: code generation, review, multi-model. Cursor Pro+ (free student).
- **Vibe**: fast code generation via Mistral/Devstral. Free tier.
- **Claude Code**: orchestrator — architecture, debugging, synthesis, final decisions.

Key rules:
- ALWAYS wrap all CLIs with `$GTIMEOUT` (absolute path `/opt/homebrew/bin/gtimeout`). Bare `timeout` does NOT work in subagent/background shells.
- Claude is ALWAYS the orchestrator. Never delegate architecture/security alone.
- Graceful degradation if CLIs unavailable. Check dynamic path resolution in each driver skill.
- Timeouts: 120s research/review, 180s generation, 300s complex tasks.

### Concurrency Hard Limits (MANDATORY — DO NOT OVERRIDE)

- **Codex**: max **5** concurrent processes. Queue any excess.
- **Vibe (Mistral)**: max **3** concurrent processes. Queue any excess.
- **Cursor**: max **3** concurrent processes. Queue any excess.
- **Gemini**: max **2** concurrent processes. Queue any excess.
- **Copilot**: max **2** concurrent processes. Queue any excess.
- **Sonnet subagents**: no hard limit (managed by Claude runtime)
- These limits apply to ALL skills — meta-review, meta-execute, meta-research, etc.
- If a skill says otherwise, THIS FILE wins. Period.

### Parallel Patterns

- **Research**: Gemini web + Codex code + Claude tools simultaneously
- **Review**: 7 Sonnet + 3 Codex + 2 Gemini/Copilot (12 total), synthesize by agreement. Copilot is Gemini's fallback — if Gemini fails, retry with Copilot before skipping.
- **Implementation**: Cross-model Best-of-2 (Vibe + Cursor generate, Codex review+fix), 5-reviewer panel per WU. Claude orchestrates.
- **Pre-commit**: Codex lint via hooks
