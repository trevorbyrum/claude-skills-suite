---
name: cursor
description: Driver skill for Cursor Agent CLI. Provides cursor-exec.sh wrapper — call the script, not raw CLI. Load before any Cursor invocation.
disable-model-invocation: true
---

# Cursor Agent CLI Driver

**ALWAYS use the wrapper**: `bash skills/cursor/scripts/cursor-exec.sh <mode> [options] "PROMPT"`

Never construct raw `agent` commands — the wrapper handles path resolution,
headless flags, timeout, concurrency, and output validation.

## Wrapper Usage

```bash
bash skills/cursor/scripts/cursor-exec.sh <mode> [options] "PROMPT"
bash skills/cursor/scripts/cursor-exec.sh <mode> [options] --stdin /path/to/prompt.md
```

### Modes

| Mode | Behavior | Default Timeout | Use For |
|------|----------|-----------------|---------|
| `review` | `--mode ask` (analysis) | 120s | Code review, read-only analysis |
| `generate` | `--force` (file writes) | 180s | Code generation, refactoring |
| `plan` | `--mode plan` (planning) | 120s | Architecture planning, proposals |

### Options

| Flag | Description |
|------|-------------|
| `--workspace DIR` | Working directory |
| `--output FILE` | Write response text to file |
| `--timeout SECS` | Override default timeout |
| `--stdin FILE` | Read prompt from file instead of positional arg |
| `--model MODEL` | Override model (e.g. `sonnet-4.6-thinking`, `gpt-5.4-high`) |
| `--worktree NAME` | Isolated git worktree for writes |
| `--worktree-base REF` | Branch/ref to base worktree on |
| `--json` | Use JSON output format (single object, not JSONL) |
| `--with-mcp` | Auto-approve MCP servers |
| `--skip-concurrency` | Skip PID-based concurrency tracking |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Cursor Agent unavailable or not authenticated |
| 2 | All 3 concurrency slots occupied (after retries) |
| 3 | Invalid arguments |
| 4 | Empty or too-small response, or JSON error result |
| 124 | Timeout (from gtimeout) |

## What the Wrapper Handles

1. **Path resolution**: Finds `agent` binary across `command -v`, user-local, system
2. **Headless flags**: Adds `-p --trust` on every call (prevents TUI and trust prompts)
3. **Mode mapping**: `review` → `--mode ask`, `generate` → `--force`, `plan` → `--mode plan`
4. **Timeout**: `$GTIMEOUT` wrapping (120s review/plan, 180s generate)
5. **Concurrency**: Max 3 via PID file + mkdir-based atomic lock (race-safe)
6. **Output validation**: Rejects small responses (10+ chars text, 50+ chars JSON); checks JSON `.is_error`
7. **Slot release**: Explicit cleanup via trap on exit

## Examples

### Code Review (most common)

```bash
bash skills/cursor/scripts/cursor-exec.sh review \
  --workspace /path/to/project \
  --output /tmp/cursor-review.md \
  "Review for security issues. Focus on input validation and auth."
```

### Code Generation

```bash
bash skills/cursor/scripts/cursor-exec.sh generate \
  --workspace /path/to/project \
  --output /tmp/cursor-gen.md \
  "Add input validation to all API route handlers."
```

### Generation in Isolated Worktree

```bash
bash skills/cursor/scripts/cursor-exec.sh generate \
  --workspace /path/to/project \
  --worktree wu-3-auth \
  --worktree-base main \
  --model sonnet-4.6-thinking \
  "Implement JWT refresh token rotation per project-plan.md WU-3."
```

### Long Prompt via stdin

```bash
bash skills/cursor/scripts/cursor-exec.sh review \
  --workspace /path/to/project \
  --output /tmp/cursor-review.md \
  --stdin /tmp/review-prompt.md
```

### With Model Override

```bash
bash skills/cursor/scripts/cursor-exec.sh review \
  --workspace /path/to/project \
  --model sonnet-4.6 \
  --output /tmp/cursor-quick.md \
  "List all exported functions in src/api/ that lack input validation."
```

### Background with Concurrency (meta-review pattern)

```bash
bash skills/cursor/scripts/cursor-exec.sh review \
  --workspace /path/to/project \
  --output /tmp/cursor-security.md \
  --stdin /tmp/security-prompt.md &
CURSOR_PID=$!
# ... launch up to 2 more (3 total) ...
wait $CURSOR_PID
```

### JSON Output

```bash
bash skills/cursor/scripts/cursor-exec.sh review \
  --workspace /path/to/project \
  --json \
  --output /tmp/cursor-out.json \
  "Analyze test coverage gaps."

jq -r '.result' /tmp/cursor-out.json
```

## Model Selection

Default is account setting (currently `opus-4.6-thinking`). Override with `--model`.

| ID | Best For |
|---|---|
| `opus-4.6-thinking` | Deep review, architecture analysis (default) |
| `sonnet-4.6-thinking` | Good balance for generation and review |
| `sonnet-4.6` | Fast, no extended thinking |
| `gpt-5.4-high` | Strong alternative for code generation |
| `gpt-5.4-medium` | Faster GPT option |
| `gemini-3.1-pro` | Large context, web research |

## Concurrency Limit (MANDATORY)

Max **3** simultaneous Cursor processes. The wrapper enforces this via PID file
(`/tmp/cursor-slots.pid`) with mkdir-based atomic locking.

## Write Safety Warning

**`--mode ask` and `--mode plan` are NOT reliably read-only.** On the current
build (`2026.03.11-6dfa30c`), both modes have been observed to modify files.
When the main worktree must stay untouched, use `--worktree` for isolated writes.

## Fallback Behavior

| Failure | Exit Code | Fallback |
|---------|-----------|----------|
| CLI not installed | 1 | Skip, note "Cursor Agent unavailable" |
| Not authenticated | 1 | Skip, note "Cursor Agent not logged in" |
| Timeout | 124 | Retry once with `--timeout 240`; then skip |
| Rate limited | — | Back off 30s, retry; then skip |
| All slots full | 2 | Wait and retry; then skip |
| JSON error result | 4 | Retry once; then skip |

## Critical Gotchas

1. **Always use the wrapper** — never construct raw `agent` commands
2. **`-p` + `--trust` are mandatory** — wrapper handles both. Without them: TUI hang
3. **`--mode ask`/`--mode plan` are NOT safely read-only** — use `--worktree` for isolation
4. **`--force` is not a write gate** — it auto-approves tool execution, doesn't prevent writes
5. **Prompts are positional** — must be LAST arg after all flags. Wrapper handles this
6. **No `-o` output flag** — must redirect stdout. Wrapper handles via `--output`
7. **JSON output is a single object, not JSONL** — use `jq -r '.result'` to extract
8. **Worktrees require a git repo** — `-w` fails in non-git directories
9. **`2>/dev/null` is mandatory** — stderr has ANSI codes, MCP logs, spinners. Wrapper handles this

## Consuming Skills

Skills that use Cursor include wrapper commands as fenced code blocks — this is
calling the API, not violating the driver boundary. The old "Load `/cursor` for
invocation syntax" pattern is replaced with direct wrapper calls.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
