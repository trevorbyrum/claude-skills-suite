---
name: codex
description: Driver skill for Codex CLI syntax, flags, and sandbox modes. Load this before spawning any Codex call. Use when other skills need Codex or user says "use Codex".
---

# Codex CLI Driver

Encode the exact Codex CLI invocation for a given task type. This is a
utility skill — it provides command templates that other skills compose into
their workflows. It is not triggered directly by the user in most cases.

## PATH & Absolute Paths

`run_in_background` and subagent Bash calls spawn non-interactive subshells
that do NOT source `.zshrc`/`.zprofile`. Custom PATH entries are missing.

**Always resolve the path dynamically** — Codex may be installed via nvm (node)
or Homebrew depending on system state:

```bash
CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | sort -V | tail -1)
test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
test -x "$CODEX" || { echo "Codex unavailable — skipping"; }
export PATH="$(dirname "$CODEX"):$PATH"
```

Use `"$CODEX"` in every invocation. Do not use bare `codex`. The PATH export
is required for NVM installs because the `codex` wrapper uses `/usr/bin/env node`.

## Timeout Binary

Use the same `$GTIMEOUT` pattern as the Gemini skill for consistency:

```bash
GTIMEOUT="/opt/homebrew/bin/gtimeout"
test -x "$GTIMEOUT" || GTIMEOUT="/opt/homebrew/bin/timeout"
test -x "$GTIMEOUT" || { echo "gtimeout not installed (brew install coreutils)"; exit 1; }
```

Every template below uses `$GTIMEOUT`. Do not use bare `timeout`.

## Availability Check

Before any invocation, verify the CLI is installed using the dynamic path above.
If `"$CODEX"` is empty or not executable, skip the Codex portion of the workflow
and note "Codex unavailable" in output. There is no direct substitute for Codex —
its model is unique to this CLI.

## Concurrency Limit (MANDATORY)

Codex supports a maximum of **5** simultaneous `codex exec` processes. Exceeding
this causes credential contention and silent failures. This limit is set in
`general.md` and applies to ALL skills. Track active sessions via a PID file:

```bash
PID_FILE=/tmp/codex-slots.pid

# Prune dead entries
if [ -f "$PID_FILE" ]; then
  while IFS= read -r pid; do
    ps -p "$pid" >/dev/null 2>&1 && echo "$pid"
  done < "$PID_FILE" > "${PID_FILE}.tmp"
  mv "${PID_FILE}.tmp" "$PID_FILE"
fi

# Check slot availability
ACTIVE=$(wc -l < "$PID_FILE" 2>/dev/null || echo 0)
if [ "$ACTIVE" -ge 5 ]; then
  echo "All 5 Codex slots occupied — queuing"
  # Wait for a slot to free up, or skip
fi
```

After launching a `codex exec` in the background, append its PID:
```bash
echo $! >> /tmp/codex-slots.pid
```

## MCP Server Loading

Codex loads all MCP servers from `~/.codex/config.toml` on every `exec` call.
This adds startup latency (3-10s) and can hang if a server fails to connect.

**To disable MCP servers** for lightweight exec calls (reviews, simple prompts):

```bash
$GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check \
  -c 'mcp_servers.homelab-gateway.enabled=false' \
  -c 'mcp_servers.ssh-tower.enabled=false' \
  -c 'mcp_servers.github.enabled=false' \
  "PROMPT" 2>/dev/null
```

This produces `mcp startup: no servers` — zero MCP overhead.

**When to disable MCP:**
- Review-only tasks that don't need GitHub/SSH context
- Simple prompts (lint, format, quick analysis)
- When MCP servers are causing timeouts

**When to keep MCP enabled:**
- Tasks that need to read GitHub repos or issues
- Tasks that need SSH access to remote servers
- Full-auto code generation that may need external context

## App Server vs Exec

`codex exec` is self-contained. It does **not** require a separate background
daemon to run reliably.

- `codex app-server` is for tooling that speaks the Codex app-server protocol
- `codex mcp-server` exposes Codex as an MCP server for other clients
- `codex app` launches the desktop app

Do **not** try to fix headless `exec` failures by launching `codex app server`
or `codex app-server` in the background. Fix the CLI invocation instead.

## Approval Flag Reality Check

On this machine's `codex-cli 0.104.0`, `codex exec` accepts `--full-auto` but
rejects `-a/--ask-for-approval`. Older docs and examples may still mention
approval flags, but for this repo's headless `exec` templates, treat the local
CLI help as the source of truth.

## Task-Type Templates

**Every template below includes `--skip-git-repo-check`** — it's harmless in
git repos and required outside them.

### Code Review (Read-Only)

The default sandbox is read-only, which is correct for review tasks.
`--ephemeral` prevents session state from persisting.

```bash
RESULT=$($GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check --sandbox read-only -C /path/to/project "Review this codebase for security issues, focusing on input validation and auth." 2>/dev/null)
echo "$RESULT" > OUTPUT_FILE
```

### Code Review with High Reasoning

For deeper analysis, increase reasoning effort:

```bash
RESULT=$($GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check --sandbox read-only -c model_reasoning_effort="high" -C /path/to/project "Analyze the architecture for scaling bottlenecks." 2>/dev/null)
echo "$RESULT" > OUTPUT_FILE
```

### Code Generation (Workspace Write)

When Codex needs to write files in headless mode, prefer an explicit sandbox
mode over `--full-auto` so the write policy is obvious:

```bash
$GTIMEOUT 180 "$CODEX" exec --ephemeral --skip-git-repo-check \
  -c 'mcp_servers.homelab-gateway.enabled=false' \
  -c 'mcp_servers.ssh-tower.enabled=false' \
  -c 'mcp_servers.github.enabled=false' \
  --sandbox workspace-write -C /path/to/project "Add input validation to all API route handlers" 2>/dev/null
```

### Structured Output

Pass a JSON schema to get structured responses:

```bash
$GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check --output-schema /path/to/schema.json -o OUTPUT_FILE "Analyze the test coverage gaps in this project" 2>/dev/null
```

### Write Final Message to File

Use `-o` to direct the final agent message to a file:

```bash
$GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check -o OUTPUT_FILE "Summarize the dependencies in this project" 2>/dev/null
```

### Long Prompt via stdin

For prompts too long for a shell argument, pipe from a file using `-`:

```bash
$GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check - < /path/to/prompt.md 2>/dev/null
```

### With Additional Directories

When Codex needs access to shared libraries or config outside the project root:

```bash
$GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check -C /path/to/project --add-dir /shared/libs "Check for API contract mismatches between the project and shared library types" 2>/dev/null
```

## Critical Gotchas

1. **Always wrap with `$GTIMEOUT`** — the CLI hangs indefinitely on credit
   exhaustion or network issues. Use 120s for reviews, 180s for generation,
   and 300s for unusually large multi-file prompts. Reserve 30s only for
   tiny lint-style checks.

2. **`-p` is `--profile`, NOT prompt** — the prompt is a **positional argument**
   (last arg after all flags). Using `-p "some text"` causes
   `Error: config profile 'some text' not found`. NEVER use `-p` to pass a prompt.

3. **Default sandbox is READ-ONLY** — `codex exec` without
   `--sandbox workspace-write`, `--full-auto`, or `--sandbox danger-full-access`
   cannot modify files. This is intentional for review tasks, but forgetting it
   for generation tasks means silent no-ops.

4. **`--full-auto` is not "network on"** — on current Codex CLI builds it is a
   convenience shortcut around workspace-write behavior. Do not assume it enables
   network access. If a task truly needs network, use `--sandbox danger-full-access`
   only inside an already sandboxed environment.

5. **Always include `--skip-git-repo-check`** — running in a non-repo directory
   fails with exit code 1 and no output. This flag is harmless in git repos.

6. **Flag placement matters** — the prompt goes last:
   `codex exec --ephemeral --sandbox read-only "prompt"`. Putting flags after
   the prompt string causes parse errors or turns those flags into prompt text.

7. **`--json` outputs JSONL, not a single JSON object** — each line is a
   separate event (message, tool call, result). Parse line-by-line, not as
   a single `jq` input. Use `jq -s` or process per-line.

8. **All elicitation requests are auto-cancelled in exec mode** — the CLI
   cannot ask clarifying questions. Prompts need to be self-contained and
   unambiguous.

9. **Model**: Reads from `~/.codex/config.toml` (currently `gpt-5.4`). No need
   to specify `-m` unless overriding. Override: `-m o3` or `-m gpt-5.4`.

10. **`2>/dev/null` is mandatory** — stderr contains progress indicators,
    MCP server startup logs, and ANSI codes that inflate context and corrupt
    file output.

11. **`-C` is valid** — short form for `--cd <DIR>`. Both work.

12. **Validate output by character count, not line count** — Codex sometimes
    produces few lines with very long content. Check `wc -c` (expect ≥ 100
    chars for a real response) rather than `wc -l`.

## Short Flag Reference

| Short | Long | Purpose |
|---|---|---|
| `-c` | `--config` | Override config key=value |
| `-C` | `--cd` | Working directory |
| `-i` | `--image` | Attach image(s) |
| `-m` | `--model` | Model override |
| `-o` | `--output-last-message` | Write final message to file |
| `-p` | `--profile` | Config profile (**NOT prompt**) |
| `-s` | `--sandbox` | Sandbox mode |
| `-V` | `--version` | Print version |
| — | `--full-auto` | Convenience shortcut for automatic workspace-write runs |
| — | `--dangerously-bypass-approvals-and-sandbox` | Disable sandbox and approvals |
| — | `--search` | Enable native web search for the agent |

## Sandbox Mode Reference

| Mode | Files | Network | Use Case |
|---|---|---|---|
| `read-only` (default) | Read only | Blocked | Code review, analysis |
| `workspace-write` | Read + Write | Blocked | Local code generation |
| `danger-full-access` | Read + Write | Allowed | Generation needing deps/APIs |

Note: prefer explicit `--sandbox workspace-write` in this repo's headless
templates. For full network access, use `--sandbox danger-full-access`.

## Fallback Behavior

| Failure Mode | Action |
|---|---|
| CLI not installed | Skip, note "Codex unavailable" |
| Timeout (exit 124) | Retry once with 180s; then skip |
| Credit exhaustion (hang) | Timeout catches it; skip |
| All 5 slots occupied | Queue and retry after 30s; skip after 3 attempts |
| MCP server hang | Timeout catches it; consider checking config |

## Examples

```
Skill (counter-review): Needs Codex to review project for completeness issues.
--> RESULT=$($GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check --sandbox read-only -C /path/to/project \
      "Scan for stubs, TODOs, placeholder values, empty catch blocks, and functions with no real implementation. Report each with file path and line number." 2>/dev/null)
    echo "$RESULT" > /tmp/codex-completeness-review.md
```

```
Skill (meta-review): Firing Codex alongside Gemini and Claude in parallel.
--> $GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check --sandbox read-only -C /path/to/project \
      "$(cat /tmp/review-prompt.md)" 2>/dev/null > /tmp/codex-review-output.md &
    echo $! >> /tmp/codex-slots.pid
    CODEX_PID=$!
    # ... launch other reviews ...
    wait $CODEX_PID
```

```
Skill (pre-commit): Quick lint check before committing.
--> $GTIMEOUT 30 "$CODEX" exec --ephemeral --skip-git-repo-check --sandbox read-only -C /path/to/project \
      "Check the staged diff for obvious bugs, typos, and style issues. Be concise." 2>/dev/null
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
