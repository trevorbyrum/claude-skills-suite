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

Six CLIs available. Full syntax in `/gemini`, `/codex`, `/copilot`, `/cursor`, and `/vibe` skills.

- **Gemini** (`$GTIMEOUT 120 "$GEMINI" -p "..."`): web research, devil's advocate, large doc analysis. FREE.
- **Codex** (`$GTIMEOUT 120 "$CODEX" exec --ephemeral --sandbox read-only "..."`): code review, generation, lint. $20/mo flat.
- **Copilot** (`$GTIMEOUT 120 "$COPILOT" --allow-all-tools --no-ask-user --no-color -s -p "..."`): code review, generation, multi-model tasks. Premium request quota.
- **Cursor** (`$GTIMEOUT 120 "$AGENT" -p --trust --force --workspace /path "PROMPT"`): code generation, review, multi-model. Cursor Pro+ (free student).
- **Vibe** (`$GTIMEOUT 120 "$VIBE" --headless --no-prompt generate -p "PROMPT"`): fast code generation via Mistral/Codestral. Free tier.
- **Claude Code**: orchestrator — architecture, debugging, synthesis, final decisions.

Key gotchas:
- ALWAYS wrap all CLIs with `$GTIMEOUT` (absolute path `/opt/homebrew/bin/gtimeout`). Bare `timeout` does NOT work in subagent/background shells — it resolves to a perl alarm wrapper that kills Gemini. `unset DEBUG` before Gemini.
- Codex exec default sandbox is READ-ONLY. Use `--sandbox workspace-write` for writes. Only use `--sandbox danger-full-access` when network access is actually required and the outer environment is already sandboxed.
- Copilot requires `--allow-all-tools --no-ask-user` for headless use. `-p` IS the prompt flag (unlike Codex where `-p` is `--profile`). Use `--disable-builtin-mcps` for local tasks.
- Cursor requires `-p --trust` for headless. `-p` means `--print` (headless), NOT prompt — prompt is positional (last arg). `--force` needed for writes; `--mode ask` for read-only.
- Vibe requires `--headless --no-prompt` for headless. Without `--headless`, CLI enters interactive mode and hangs.
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
