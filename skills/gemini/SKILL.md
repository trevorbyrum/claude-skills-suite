---
name: gemini
description: Driver skill for Gemini CLI syntax, flags, and gotchas. Load this before spawning any Gemini call. Use when other skills need Gemini or user says "use Gemini".
disable-model-invocation: true
---

# Gemini CLI Driver

**ALWAYS use the wrapper**: `bash skills/gemini/scripts/gemini-exec.sh <mode> [options] "PROMPT"`

Never construct raw `gemini` commands — the wrapper handles path resolution,
environment safety, MCP stdout filtering, timeout, concurrency, JSON extraction,
and output validation.

## Wrapper Usage

```bash
bash skills/gemini/scripts/gemini-exec.sh <mode> [options] "PROMPT"
bash skills/gemini/scripts/gemini-exec.sh <mode> [options] --stdin /path/to/prompt.md
```

### Modes

| Mode | Gemini Flags | Default Timeout | Use For |
|------|-------------|-----------------|---------|
| `research` | (none) | 300s | Web research, analysis, domain questions |
| `review` | `--approval-mode plan` | 300s | Code review, security audit, architecture feedback |
| `generate` | `-y` (yolo) | 300s | File generation, code writing |

### Options

| Flag | Description |
|------|-------------|
| `--output FILE` | Write extracted response text to file |
| `--output-json FILE` | Write full JSON envelope to file |
| `--timeout SECS` | Override default timeout (default: 300s) |
| `--stdin FILE` | Read prompt from file instead of positional arg |
| `--model MODEL` | Override model (default: `gemini-2.5-flash`) |
| `--sandbox` | Enable sandbox mode (`-s`) |
| `--no-extensions` | Skip loading extensions (`-e ''`) |
| `--skip-concurrency` | Skip PID-based concurrency tracking |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (response extracted and validated) |
| 1 | Gemini unavailable or config error |
| 2 | All concurrency slots occupied (after retries) |
| 3 | Invalid arguments |
| 4 | Empty or too-small response (likely failed) |
| 124 | Timeout (from gtimeout) |

## What the Wrapper Handles

1. **Path resolution**: Finds Gemini binary across NVM, Homebrew, npm-global
2. **Environment safety**: Clears `DEBUG`, `GOOGLE_CLOUD_PROJECT`, `CI` (break auth/flood stderr)
3. **MCP stdout leak**: Gemini CLI v0.34.0 leaks `MCP issues detected...` to stdout before JSON — wrapper strips it via `sed` before `jq` extraction
4. **Timeout**: Default 300s (the old 120s caused timeouts on `gemini-2.5-pro` and marginal results on `flash`)
5. **Concurrency**: Max 2 concurrent Gemini processes via PID file tracking
6. **JSON extraction**: Pipes through `-o json`, extracts `.response` field
7. **Output validation**: Rejects responses under 50 chars with exit code 4
8. **Rate limit detection**: Warns on 429/capacity-exhausted in stderr

## Model Selection

| Model | Speed | Quality | Reliability | Use For |
|-------|-------|---------|-------------|---------|
| `gemini-2.5-flash` | 20-50s | Good | High | **Default.** Reviews, research, analysis |
| `gemini-2.5-flash-lite` | 8-15s | OK | Medium | Fast/simple prompts, batch operations |
| `gemini-2.5-pro` | 3-4 min | Best | Low (429s, timeouts) | Avoid in automation |

Override with `--model`:

```bash
bash skills/gemini/scripts/gemini-exec.sh research --model gemini-2.5-flash-lite "Quick question"
```

## Concurrency Limit (MANDATORY)

Max **2** simultaneous Gemini processes. The wrapper enforces this via PID file
(`/tmp/gemini-slots.pid`). Exceeding this causes rate-limit errors (429).

## Examples

### Research / Analysis

```bash
bash skills/gemini/scripts/gemini-exec.sh research \
  --output /tmp/research-output.md \
  "Research current Kubernetes operator patterns and best practices as of 2026."
```

### Code Review

```bash
bash skills/gemini/scripts/gemini-exec.sh review \
  --output /tmp/gemini-review.md \
  "Review this code for security issues: $(cat src/auth/handler.go)"
```

### Long Prompt via stdin

```bash
bash skills/gemini/scripts/gemini-exec.sh research \
  --stdin /tmp/review-prompt.md \
  --output /tmp/gemini-review-output.md
```

### Fast Batch with flash-lite

```bash
bash skills/gemini/scripts/gemini-exec.sh research \
  --model gemini-2.5-flash-lite \
  --output /tmp/quick-answer.md \
  "What is the OWASP Top 10 #1 vulnerability?"
```

## File Context

Gemini's `@path` syntax cannot read gitignored files. For files in gitignored
directories (e.g., `skills/`), use stdin instead:

```bash
# WRONG — blocked by gitignore:
# gemini -p "Review @skills/gemini/SKILL.md"

# RIGHT — pipe file content via stdin or embed in prompt:
bash skills/gemini/scripts/gemini-exec.sh review \
  --output /tmp/review.md \
  "Review this file: $(cat skills/gemini/SKILL.md)"
```

## Fallback Behavior

**Copilot is Gemini's primary fallback.** When Gemini fails for any reason,
retry with Copilot (`/copilot`) before falling back to WebSearch or skipping.

| Failure | Exit Code | Fallback |
|---------|-----------|----------|
| CLI not installed | 1 | Copilot; then WebSearch (research) or skip (review) |
| Timeout | 124 | Retry once with longer timeout; then Copilot |
| Rate limit / 429 | 0 or 4 | Retry once after 30s; then Copilot |
| Empty output | 4 | Retry with `--model gemini-2.5-flash`; then Copilot |
| All slots full | 2 | Wait and retry; then Copilot |

## Critical Gotchas

1. **Always use the wrapper** — never construct raw `gemini` commands
2. **MCP stdout leak** — Gemini v0.34.0 prints MCP errors to stdout, breaking `jq`. Wrapper handles this
3. **`gemini-2.5-pro` is too slow for automation** — 3-4 min + 429 rate limits. Use `flash`
4. **`@path` blocked by gitignore** — use stdin or embed file content in prompt
5. **Stderr is noisy even on success** — MCP registration, extension loading, etc.
6. **`GOOGLE_CLOUD_PROJECT` breaks auth** — wrapper clears it automatically
7. **Exit code 0 doesn't mean success** — always check response size (wrapper does this)

## Consuming Skills

Skills that use Gemini include wrapper commands as fenced code blocks — this is
calling the API, not violating the driver boundary. The old "Load `/gemini` for
invocation syntax" pattern is replaced with direct wrapper calls.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
