---
name: copilot
description: Driver skill for Copilot CLI. Provides copilot-exec.sh wrapper — call the script, not raw CLI. Load before any Copilot invocation.
disable-model-invocation: true
---

# Copilot CLI Driver

**ALWAYS use the wrapper**: `bash skills/copilot/scripts/copilot-exec.sh <mode> [options] "PROMPT"`

Never construct raw `copilot` commands — the wrapper handles path resolution,
headless flags, timeout, MCP toggling, concurrency, and output validation.

## Wrapper Usage

```bash
bash skills/copilot/scripts/copilot-exec.sh <mode> [options] "PROMPT"
bash skills/copilot/scripts/copilot-exec.sh <mode> [options] --stdin /path/to/prompt.md
```

### Modes

| Mode | Behavior | Default Timeout | Use For |
|------|----------|-----------------|---------|
| `review` | Read-only, MCP disabled | 120s | Code review, analysis, security audit |
| `generate` | Autopilot + file writes, MCP disabled | 180s | Code generation, implementation |
| `full-access` | Autopilot + GitHub MCP enabled | 300s | Tasks needing GitHub context (rare) |

### Options

| Flag | Description |
|------|-------------|
| `--add-dir DIR` | Add directory to allowed access list (can repeat) |
| `--output FILE` | Write response text to file |
| `--timeout SECS` | Override default timeout |
| `--stdin FILE` | Read prompt from file instead of positional arg |
| `--model MODEL` | Override model (e.g. `gpt-5.4`, `claude-sonnet-4.6`) |
| `--reasoning LEVEL` | Reasoning effort: `low`, `medium`, `high`, `xhigh` |
| `--max-continues N` | Cap autopilot continuations (default: 5) |
| `--json` | Use JSONL output format |
| `--with-mcp` | Keep built-in GitHub MCP server enabled |
| `--skip-concurrency` | Skip PID-based concurrency tracking |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Copilot unavailable or config error |
| 2 | All 2 concurrency slots occupied (after retries) |
| 3 | Invalid arguments |
| 4 | Empty or too-small response (likely failed) |
| 124 | Timeout (from gtimeout) |

## What the Wrapper Handles

1. **Path resolution**: Finds Copilot binary across `command -v`, Homebrew, user-local, system
2. **Headless flags**: Adds `--allow-all-tools --no-ask-user --no-color -s` on every call
3. **MCP toggling**: Disables built-in GitHub MCP by default (saves 3-10s); enable with `--with-mcp`
4. **Autopilot**: Adds `--autopilot --max-autopilot-continues 5` for generate/full-access modes
5. **Timeout**: `$GTIMEOUT` wrapping (120s review, 180s generate, 300s full-access)
6. **Concurrency**: Max 2 via PID file + mkdir-based atomic lock (race-safe)
7. **Output validation**: Rejects suspiciously small responses (10+ chars text, 50+ chars JSON)
8. **Rate limit detection**: Warns on 429/quota errors in stderr
9. **Slot release**: Explicit cleanup via trap on exit

## Examples

### Code Review (most common)

```bash
bash skills/copilot/scripts/copilot-exec.sh review \
  --add-dir /path/to/project \
  --output /tmp/copilot-review.md \
  "Review /path/to/project for security issues. Focus on input validation and auth."
```

### Code Generation

```bash
bash skills/copilot/scripts/copilot-exec.sh generate \
  --add-dir /path/to/project \
  --output /tmp/copilot-gen.md \
  "Add input validation to all API route handlers in /path/to/project"
```

### Long Prompt via stdin

```bash
bash skills/copilot/scripts/copilot-exec.sh review \
  --add-dir /path/to/project \
  --output /tmp/copilot-review.md \
  --stdin /tmp/review-prompt.md
```

### With Specific Model

```bash
bash skills/copilot/scripts/copilot-exec.sh review \
  --add-dir /path/to/project \
  --model gpt-5.4 \
  --output /tmp/copilot-review.md \
  "Review for architectural issues."
```

### High Reasoning

```bash
bash skills/copilot/scripts/copilot-exec.sh review \
  --add-dir /path/to/project \
  --reasoning high \
  --output /tmp/copilot-analysis.md \
  "Deep security analysis of the authentication flow."
```

### Background with Concurrency (meta-review pattern)

```bash
bash skills/copilot/scripts/copilot-exec.sh review \
  --add-dir /path/to/project \
  --output /tmp/copilot-security.md \
  --stdin /tmp/security-prompt.md &
COPILOT_PID=$!
# ... launch 1 more (max 2 total) ...
wait $COPILOT_PID
```

### JSONL Output

```bash
bash skills/copilot/scripts/copilot-exec.sh review \
  --add-dir /path/to/project \
  --json \
  --output /tmp/copilot-out.jsonl \
  "Review for code quality issues."

# Extract final assistant message
jq -r 'select(.type=="assistant.message") | .data.content // empty' \
  /tmp/copilot-out.jsonl | tail -1
```

## Model Selection

Do not assume a fixed default model — the CLI auto-routes per task. Pin
`--model` when model choice matters.

| Model | Best For |
|---|---|
| `claude-sonnet-4.6` | Balanced quality and speed (Claude) |
| `claude-opus-4.6` | Highest-quality reasoning, slower |
| `claude-haiku-4.5` | Fast, cheap, simple tasks |
| `gpt-5.4` | Codex-class tasks, structured output |
| `gpt-5.1-codex` | Code generation and review |
| `gemini-3-pro-preview` | Large context, web research |

## Concurrency Limit (MANDATORY)

Max **2** simultaneous Copilot processes. Every invocation consumes one premium
request from GitHub Copilot quota. The wrapper enforces this via PID file
(`/tmp/copilot-slots.pid`) with mkdir-based atomic locking.

## Fallback Behavior

**Codex is Copilot's primary fallback.** Copilot itself is Gemini's fallback —
if both Gemini and Copilot fail, fall back to WebSearch (research) or skip (review).

| Failure | Exit Code | Fallback |
|---------|-----------|----------|
| CLI not installed | 1 | Codex; then Claude direct |
| Timeout | 124 | Retry once with `--timeout 240`; then Codex |
| Quota exhausted | 0 or 4 | Skip and note "Copilot quota exhausted" |
| Empty output | 4 | Retry once; then skip |
| All slots full | 2 | Wait and retry; then skip |
| MCP server hang | — | Retry with `--skip-concurrency` (wrapper disables MCP by default) |

## Critical Gotchas

1. **Always use the wrapper** — never construct raw `copilot` commands
2. **`-p` IS `--prompt`** — unlike Codex where `-p` is `--profile`
3. **No `--cd` or `--workdir` flag** — use `--add-dir` for file access and reference absolute paths in prompt
4. **`--autopilot` without `--max-continues` runs indefinitely** — wrapper caps at 5
5. **JSON output is JSONL** — one JSON object per line, mixed event types. Filter for `assistant.message`
6. **Premium requests** — every call costs one. Batch tasks into single prompts where possible
7. **MCP startup adds 3-10s** — wrapper disables by default; use `--with-mcp` for GitHub-context tasks
8. **`2>/dev/null` is mandatory** — stderr has spinners, MCP logs, ANSI noise. Wrapper handles this
9. **Model auto-routing** — unpinned prompts may route to unexpected models. Pin with `--model` when it matters

## Consuming Skills

Skills that use Copilot include wrapper commands as fenced code blocks — this is
calling the API, not violating the driver boundary. The old "Load `/copilot` for
invocation syntax" pattern is replaced with direct wrapper calls.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
