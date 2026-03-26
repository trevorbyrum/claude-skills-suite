---
name: vibe
description: Driver skill for Mistral Vibe CLI. Provides vibe-exec.sh wrapper — call the script, not raw CLI. Load before any Vibe invocation.
disable-model-invocation: true
---

# Mistral Vibe CLI Driver

**ALWAYS use the wrapper**: `bash skills/vibe/scripts/vibe-exec.sh <mode> [options] "PROMPT"`

Never construct raw `vibe` commands — the wrapper handles path resolution,
the v2.5.0 stdin-blocking bug, timeout, concurrency, and output validation.

## Wrapper Usage

```bash
bash skills/vibe/scripts/vibe-exec.sh <mode> [options] "PROMPT"
bash skills/vibe/scripts/vibe-exec.sh <mode> [options] --stdin /path/to/prompt.md
```

### Modes

| Mode | Tools Enabled | Default Timeout | Default Turns | Use For |
|------|--------------|-----------------|---------------|---------|
| `review` | read_file, grep | 120s | 5 | Code review, read-only analysis |
| `generate` | all | 180s | 10 | Code generation, file writes |
| `analyze` | read_file, grep, bash | 120s | 10 | Focused read-only analysis, summaries |

### Options

| Flag | Description |
|------|-------------|
| `--workdir DIR` | Working directory for Vibe (`--workdir`) |
| `--output FILE` | Write response text to file |
| `--timeout SECS` | Override default timeout |
| `--stdin FILE` | Read prompt from file instead of positional arg |
| `--max-turns N` | Override max assistant turns |
| `--agent NAME` | Agent profile (`default`, `plan`, `accept-edits`, `auto-approve`, custom) |
| `--json` | Use `--output json` mode (returns full conversation array) |
| `--enabled-tools T` | Additional tool restriction (can repeat) |
| `--skip-concurrency` | Skip PID-based concurrency tracking |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Vibe unavailable or config error |
| 2 | All 3 concurrency slots occupied (after retries) |
| 3 | Invalid arguments |
| 4 | Empty or too-small response (likely failed) |
| 124 | Timeout (from gtimeout) |

## What the Wrapper Handles

1. **Path resolution**: Finds Vibe binary across `command -v`, uv tools, Homebrew, system
2. **stdin redirect**: Adds `</dev/null` to every invocation — v2.5.0 reads stdin even in `-p` mode, causing hangs in background/subagent contexts without this
3. **Timeout**: `$GTIMEOUT` wrapping (120s review/analyze, 180s generate)
4. **Concurrency**: Max 3 via PID file + mkdir-based atomic lock (race-safe)
5. **Output validation**: Rejects suspiciously small responses (10-20 char threshold by mode)
6. **Slot release**: Explicit cleanup via trap on exit

## Examples

### Code Review (most common)

```bash
bash skills/vibe/scripts/vibe-exec.sh review \
  --workdir /path/to/project \
  --output /tmp/vibe-review.md \
  "Read src/auth.ts. Analyze for security issues and code smells."
```

### Code Generation

```bash
bash skills/vibe/scripts/vibe-exec.sh generate \
  --workdir /path/to/project \
  --output /tmp/vibe-generated.md \
  "Read src/session.ts. Implement refresh-token rotation. Return complete replacement code."
```

### Long Prompt via stdin

```bash
bash skills/vibe/scripts/vibe-exec.sh generate \
  --workdir /path/to/project \
  --output /tmp/vibe-output.md \
  --stdin /tmp/generation-prompt.md
```

### Read-Only Analysis

```bash
bash skills/vibe/scripts/vibe-exec.sh analyze \
  --workdir /path/to/project \
  --output /tmp/vibe-analysis.md \
  "Read rules/general.md and references/cross-cutting-rules.md. Summarize the driver-skill boundary in 5 bullets."
```

### Background with Concurrency (meta-execute pattern)

```bash
bash skills/vibe/scripts/vibe-exec.sh generate \
  --workdir /path/to/project \
  --output /tmp/wu-feature-x-vibe.md \
  --stdin /tmp/wu-feature-x-prompt.md &
VIBE_PID=$!
# ... launch more (up to 3 total) ...
wait $VIBE_PID
```

### JSON Output

```bash
bash skills/vibe/scripts/vibe-exec.sh review \
  --workdir /path/to/project \
  --json \
  --output /tmp/vibe-out.json \
  "Review src/handler.ts for performance issues."

jq -r 'map(select(.role == "assistant")) | last.content // empty' /tmp/vibe-out.json
```

## Prompt Scoping (MANDATORY)

Vibe performs best when the prompt is **narrow, concrete, and file/work-unit scoped**.
Do not ask it to "look around the repo", "analyze the whole project", or
"figure out what to change." That pattern burns turns on exploration.

**Always give Vibe all 4 of these:**

1. **Target** — exact file(s), directory, or work unit ID
2. **Task** — what to implement/review/summarize
3. **Output shape** — patch, code block, bullets, test, etc.
4. **Success criteria** — what "done" means for this prompt

**Good examples:**

- `Read src/auth.ts and src/session.ts. Implement refresh-token rotation for WU-3. Return complete replacement code blocks for those files only. Do not inspect unrelated directories.`
- `Read rules/general.md and references/cross-cutting-rules.md. Summarize the driver-skill boundary in 5 bullets. Do not scan the rest of the repo.`

**Bad examples:**

- `Analyze the architecture of this project`
- `Look through the repo and figure out what needs to change`

## Concurrency Limit (MANDATORY)

Max **3** simultaneous Vibe processes. The wrapper enforces this via PID file
(`/tmp/vibe-slots.pid`) with mkdir-based atomic locking.

## Model Selection

Models are configured in `~/.vibe/config.toml`, not via CLI flags:

| Model (alias) | Provider | Use Case |
|---|---|---|
| `devstral-2` | Mistral API | Code generation (default) |
| `devstral-small` | Mistral API | Lighter/cheaper tasks |
| `local` | llamacpp | Offline/local inference |

To use a different model, create a custom agent config at `~/.vibe/agents/NAME.toml`
and invoke with `--agent NAME`.

## Fallback Behavior

**Codex is Vibe's primary fallback.** When Vibe fails for any reason,
retry with Codex before falling back to Claude direct generation.

| Failure | Exit Code | Fallback |
|---------|-----------|----------|
| CLI not installed | 1 | Codex; then Claude direct generation |
| Timeout | 124 | Retry once with `--timeout 240`; then Codex |
| Turn limit reached | 0 (small output) | Tighten prompt, restrict tools; then Codex |
| Empty output | 4 | Retry with more `--max-turns`; then Codex |
| All slots full | 2 | Wait and retry; then Codex |

## Critical Gotchas

1. **Always use the wrapper** — never construct raw `vibe` commands
2. **`-p` + `</dev/null` are mandatory** — wrapper handles both automatically
3. **No `--model` flag** — model selection is config-only (`~/.vibe/config.toml` or `--agent`)
4. **Character count > line count** — Vibe produces compact, dense output
5. **Positional prompt** (without `-p`) enters interactive mode — wrapper prevents this
6. **Broad repo-analysis prompts hit turn limits** — keep prompts narrow and file-scoped
7. **JSON mode is a single array, not JSONL** — use `jq` over the full array
8. **`--agent plan` changes response style** — only use when you want planning-oriented output
9. **Vibe generates text, not file writes** — apply output via Edit/Write or Codex worker

## Consuming Skills

Skills that use Vibe include wrapper commands as fenced code blocks — this is
calling the API, not violating the driver boundary. The old "Load `/vibe` for
invocation syntax" pattern is replaced with direct wrapper calls.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
