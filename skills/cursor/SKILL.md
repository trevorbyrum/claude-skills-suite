---
name: cursor
description: Driver skill for Cursor Agent CLI (headless) syntax, flags, and modes. Load this before spawning any headless Cursor call. Use when other skills need Cursor or user says "use Cursor".
---

# Cursor Agent CLI Driver

Encode the exact Cursor Agent CLI invocation for a given task type. This is a
utility skill — it provides command templates that other skills compose into
their workflows. It is not triggered directly by the user in most cases.

## PATH & Absolute Paths

`run_in_background` and subagent Bash calls spawn non-interactive subshells
that do NOT source `.zshrc`/`.zprofile`. Custom PATH entries are missing.

**Always resolve the path dynamically:**

```bash
AGENT=$(command -v agent 2>/dev/null)
test -x "$AGENT" || AGENT="$HOME/.local/bin/agent"
test -x "$AGENT" || AGENT="/usr/local/bin/agent"
test -x "$AGENT" || { echo "Cursor Agent CLI unavailable — skipping"; }
```

Use `"$AGENT"` in every invocation. Do not use bare `agent`.

## Timeout Binary

Use the same `$GTIMEOUT` pattern as the Gemini and Codex skills:

```bash
GTIMEOUT="/opt/homebrew/bin/gtimeout"
test -x "$GTIMEOUT" || GTIMEOUT="/opt/homebrew/bin/timeout"
test -x "$GTIMEOUT" || { echo "gtimeout not installed (brew install coreutils)"; exit 1; }
```

Every template below uses `$GTIMEOUT`. Do not use bare `timeout`.

## Availability Check

Before any invocation, verify the CLI is installed and authenticated:

```bash
"$AGENT" status 2>/dev/null | grep -q "Logged in" || {
  echo "Cursor Agent not authenticated — run 'agent login'"
  exit 1
}
```

If unavailable, skip the Cursor portion of the workflow and note
"Cursor Agent unavailable" in output.

## Concurrency Limit (MANDATORY)

Cursor Agent supports a maximum of **3** simultaneous headless processes.
Exceeding this causes API rate limiting and degraded responses. Track active
sessions via a PID file (same pattern as Codex/Gemini):

```bash
PID_FILE=/tmp/cursor-slots.pid

# Prune dead entries
if [ -f "$PID_FILE" ]; then
  while IFS= read -r pid; do
    ps -p "$pid" >/dev/null 2>&1 && echo "$pid"
  done < "$PID_FILE" > "${PID_FILE}.tmp"
  mv "${PID_FILE}.tmp" "$PID_FILE"
fi

# Check slot availability
ACTIVE=$(wc -l < "$PID_FILE" 2>/dev/null || echo 0)
if [ "$ACTIVE" -ge 3 ]; then
  echo "All 3 Cursor Agent slots occupied — queuing"
fi
```

After launching in the background, append its PID:
```bash
echo $! >> /tmp/cursor-slots.pid
```

## Headless Mode Essentials

Cursor Agent headless mode requires `-p` (print) flag. Without it, the CLI
enters interactive TUI mode which hangs in subshells.

**Key flags for headless:**

| Flag | Purpose |
|---|---|
| `-p, --print` | Non-interactive mode (REQUIRED for headless) |
| `--trust` | Trust workspace without prompting (REQUIRED for headless) |
| `-f, --force` / `--yolo` | Allow file modifications without confirmation |
| `--workspace <path>` | Set working directory |
| `--model <id>` | Override model |
| `--mode ask` | Read-only Q&A (no file writes) |
| `--mode plan` | Read-only planning/analysis |
| `--output-format <fmt>` | `text` (default), `json`, `stream-json` |
| `-o <file>` | Write final message to file |

**Without `--force`, headless mode proposes changes but does NOT apply them.**

## Model Selection

Current account has access to these models (use `agent models` to refresh):

| ID | Notes |
|---|---|
| `auto` | Cursor routes to best available |
| `opus-4.6-thinking` | Current default. Strongest reasoning. |
| `sonnet-4.6-thinking` | Good balance of speed and quality |
| `sonnet-4.6` | Fast, no extended thinking |
| `gpt-5.4-high` | Strong alternative for code generation |
| `gpt-5.4-medium` | Faster GPT option |
| `gemini-3.1-pro` | Google's latest |

### Routing by Task Type

| Task | Model | Rationale |
|---|---|---|
| Deep review, architecture analysis | `opus-4.6-thinking` | Maximum reasoning |
| Code generation, refactoring | `sonnet-4.6-thinking` or `gpt-5.4-high` | Good balance |
| Quick lint, simple analysis | `sonnet-4.6` or `gpt-5.4-medium-fast` | Speed over depth |
| Research with web grounding | `gemini-3.1-pro` | Native search |
| Cost-sensitive batch work | `sonnet-4.6` | Lowest per-token |

## Execution Modes

### Agent Mode (default) — Full Tool Access

The default mode. Agent can read files, write files, run shell commands, and
use all configured MCP tools. Use `--force` to allow writes without
confirmation.

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --force --workspace /path/to/project \
  "PROMPT" 2>/dev/null
```

### Ask Mode — Read-Only Q&A

Agent can read files and answer questions but cannot modify anything. Best for
analysis and understanding tasks.

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --mode ask --workspace /path/to/project \
  "PROMPT" 2>/dev/null
```

### Plan Mode — Read-Only Planning

Agent analyzes the codebase and proposes a plan without executing. Returns
structured analysis of what it would do.

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --mode plan --workspace /path/to/project \
  "PROMPT" 2>/dev/null
```

## Task-Type Templates

**Every template below includes `--trust`** — required for headless mode to
avoid interactive workspace trust prompts.

### Code Review (Read-Only)

```bash
RESULT=$($GTIMEOUT 120 "$AGENT" -p --trust --mode ask --workspace /path/to/project \
  "Review this codebase for security issues, focusing on input validation and auth." 2>/dev/null)
echo "$RESULT" > OUTPUT_FILE
```

### Code Generation (Write)

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --force --workspace /path/to/project \
  "Add input validation to all API route handlers" 2>/dev/null
```

### Structured JSON Output

Use `--output-format json` for machine-parseable results:

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --mode ask --workspace /path/to/project \
  --output-format json "Analyze the test coverage gaps" 2>/dev/null
```

JSON output shape:
```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "duration_ms": 3723,
  "result": "...",
  "session_id": "...",
  "usage": { "inputTokens": 3, "outputTokens": 23, ... }
}
```

Extract the result with: `jq -r '.result'`

### Long Prompt via File

For prompts too long for a shell argument, put the prompt in a file and
reference it:

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --mode ask --workspace /path/to/project \
  "$(cat /path/to/prompt.md)" 2>/dev/null > OUTPUT_FILE
```

### With Model Override

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --force --model sonnet-4.6-thinking \
  --workspace /path/to/project "PROMPT" 2>/dev/null
```

### Parallel Execution (Background)

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --mode ask --workspace /path/to/project \
  "$(cat /tmp/review-prompt.md)" 2>/dev/null > /tmp/cursor-review-output.md &
echo $! >> /tmp/cursor-slots.pid
CURSOR_PID=$!
# ... launch other reviews ...
wait $CURSOR_PID
```

### Isolated Worktree (Git Projects)

Cursor can spin up an isolated git worktree so headless writes don't collide
with the main working tree:

```bash
$GTIMEOUT 300 "$AGENT" -p --trust --force -w headless-task \
  --workspace /path/to/project "Implement feature X" 2>/dev/null
```

The worktree is created at `~/.cursor/worktrees/<reponame>/headless-task`.
Use `--worktree-base main` to base it on a specific branch.

### Resume a Session

```bash
# Resume by session ID
$GTIMEOUT 120 "$AGENT" -p --trust --resume SESSION_ID \
  "Continue where you left off" 2>/dev/null

# Resume the most recent session
$GTIMEOUT 120 "$AGENT" -p --trust --continue \
  "Continue where you left off" 2>/dev/null
```

## MCP Server Access

Cursor Agent loads MCP servers from `.cursor/mcp.json` in the workspace.
In headless mode, use `--approve-mcps` to auto-approve server connections:

```bash
$GTIMEOUT 120 "$AGENT" -p --trust --force --approve-mcps \
  --workspace /path/to/project "PROMPT" 2>/dev/null
```

To inspect configured MCPs:
```bash
"$AGENT" mcp list
"$AGENT" mcp list-tools SERVER_NAME
```

## Output Validation (MANDATORY)

Same discipline as Codex and Gemini — validate by character count, not lines:

```bash
CHARS=$(wc -c < OUTPUT_FILE 2>/dev/null | tr -d ' ')
if [ "${CHARS:-0}" -lt 50 ]; then
  echo "Cursor output too small (${CHARS} chars) — likely failed"
fi
```

For JSON output, also validate the structure:
```bash
IS_ERROR=$(jq -r '.is_error // false' < OUTPUT_FILE 2>/dev/null)
if [ "$IS_ERROR" = "true" ]; then
  echo "Cursor returned an error"
fi
```

## Critical Gotchas

1. **`-p` is mandatory for headless** — without it, the CLI enters interactive
   TUI mode and hangs indefinitely in subshells. Every headless call MUST
   include `-p`.

2. **`--trust` is mandatory for headless** — without it, the CLI prompts for
   workspace trust interactively and hangs.

3. **`--force` is NOT default** — without it, headless mode proposes changes
   but does not write files. This is correct for review tasks but means
   generation tasks silently do nothing. Always include `--force` for write
   tasks.

4. **`--mode ask` and `--mode plan` are read-only** — they cannot modify files
   even with `--force`. Use the default agent mode (no `--mode` flag) for
   write tasks.

5. **Always wrap with `$GTIMEOUT`** — the CLI can hang on network issues,
   large codebases, or MCP server failures. 120s for reviews, 180s for
   generation, 300s for large refactors.

6. **`2>/dev/null` is mandatory** — stderr contains ANSI escape codes,
   progress indicators, and MCP startup logs that corrupt output and
   inflate context.

7. **JSON output is a single object, not JSONL** — unlike Codex, Cursor's
   `--output-format json` returns one JSON object with a `.result` field.
   Use `jq -r '.result'` to extract.

8. **Prompts are positional** — the prompt is the last argument after all
   flags. Putting flags after the prompt string causes parse errors.

9. **Model defaults to account setting** — currently `opus-4.6-thinking`.
   Override with `--model <id>` when a cheaper or faster model suffices.

10. **Worktrees require a git repo** — `-w` fails silently in non-git
    directories. Only use for git-tracked projects.

11. **Session resume requires the session ID** — get it from JSON output's
    `session_id` field, or use `agent ls` to list recent sessions.

## Flag Reference

| Short | Long | Purpose |
|---|---|---|
| `-p` | `--print` | Headless mode (**REQUIRED**) |
| `-f` | `--force` | Allow file modifications |
| `-c` | `--cloud` | Cloud mode |
| `-w` | `--worktree` | Isolated git worktree |
| `-H` | `--header` | Custom request header |
| — | `--trust` | Trust workspace (**REQUIRED for headless**) |
| — | `--yolo` | Alias for `--force` |
| — | `--workspace` | Working directory |
| — | `--model` | Model override |
| — | `--mode` | `ask` (read-only) or `plan` (read-only) |
| — | `--output-format` | `text`, `json`, `stream-json` |
| — | `--approve-mcps` | Auto-approve MCP servers |
| — | `--resume` | Resume a session by ID |
| — | `--continue` | Resume most recent session |
| — | `--sandbox` | `enabled` or `disabled` |

## Fallback Behavior

| Failure Mode | Action |
|---|---|
| CLI not installed | Skip, note "Cursor Agent unavailable" |
| Not authenticated | Skip, note "Cursor Agent not logged in" |
| Timeout (exit 130/137) | Retry once with 180s; then skip |
| Rate limited | Back off 30s, retry; then skip |
| All 3 slots occupied | Queue and retry after 30s; skip after 3 attempts |
| MCP server hang | Timeout catches it; consider `--approve-mcps` |

## Examples

```
Skill (counter-review): Needs Cursor to review project for completeness issues.
--> RESULT=$($GTIMEOUT 120 "$AGENT" -p --trust --mode ask --workspace /path/to/project \
      "Scan for stubs, TODOs, placeholder values, empty catch blocks, and functions with no real implementation. Report each with file path and line number." 2>/dev/null)
    echo "$RESULT" > /tmp/cursor-completeness-review.md
```

```
Skill (meta-review): Firing Cursor alongside Codex and Gemini in parallel.
--> $GTIMEOUT 120 "$AGENT" -p --trust --mode ask --workspace /path/to/project \
      "$(cat /tmp/review-prompt.md)" 2>/dev/null > /tmp/cursor-review-output.md &
    echo $! >> /tmp/cursor-slots.pid
    CURSOR_PID=$!
    # ... launch other reviews ...
    wait $CURSOR_PID
```

```
Skill (meta-execute): Cursor writes code in an isolated worktree.
--> $GTIMEOUT 300 "$AGENT" -p --trust --force -w wu-3-auth \
      --model sonnet-4.6-thinking --workspace /path/to/project \
      "Implement JWT refresh token rotation per the spec in project-plan.md WU-3" 2>/dev/null
```

```
Skill (quick analysis): Fast read-only check with a cheap model.
--> $GTIMEOUT 60 "$AGENT" -p --trust --mode ask --model sonnet-4.6 \
      --workspace /path/to/project \
      "List all exported functions in src/api/ that lack input validation" 2>/dev/null
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
