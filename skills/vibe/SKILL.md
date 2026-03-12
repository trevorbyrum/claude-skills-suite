---
name: vibe
description: Driver skill for Mistral Vibe CLI (headless) syntax. Load this before spawning any Vibe call. Use when other skills need fast Mistral/Codestral generation or user says "use Vibe".
---

# Mistral Vibe CLI Driver

Encode the exact Mistral Vibe CLI invocation for code generation and review tasks. This is a
utility skill — it provides command templates that other skills compose into their workflows.

## PATH & Absolute Paths

`run_in_background` and subagent Bash calls spawn non-interactive subshells that do NOT
source `.zshrc`/`.zprofile`. Custom PATH entries are missing.

**Always resolve the path dynamically:**

```bash
VIBE=$(command -v vibe 2>/dev/null)
test -x "$VIBE" || VIBE="$HOME/.local/bin/vibe"
test -x "$VIBE" || VIBE="/usr/local/bin/vibe"
test -x "$VIBE" || { echo "Mistral Vibe CLI unavailable — skipping"; exit 0; }
```

Use `"$VIBE"` in every invocation. Do not use bare `vibe`.

## Timeout Binary (MANDATORY)

```bash
GTIMEOUT="/opt/homebrew/bin/gtimeout"
test -x "$GTIMEOUT" || GTIMEOUT="/opt/homebrew/bin/timeout"
test -x "$GTIMEOUT" || { echo "gtimeout not installed (brew install coreutils)"; exit 1; }
```

Every template below uses `$GTIMEOUT`. Do not use bare `timeout`.

## Headless Mode (MANDATORY)

**Without `--headless --no-prompt`, Vibe CLI enters interactive mode and hangs indefinitely**
in subshells. These flags are required for ALL automated invocations.

```bash
# Minimum viable headless invocation
$GTIMEOUT 120 "$VIBE" --headless --no-prompt generate -p "PROMPT" 2>/dev/null
```

## Task-Type Templates

### Code Generation (Primary Use Case)

```bash
# Fast generation with Codestral (default for code tasks)
$GTIMEOUT 180 "$VIBE" \
  --headless \
  --no-prompt \
  --model codestral-latest \
  generate -p "$(cat /tmp/prompt.md)" 2>/dev/null > /tmp/vibe-generated.ts

# Alternative models
$GTIMEOUT 180 "$VIBE" \
  --headless \
  --no-prompt \
  --model mistral-large-latest \
  generate -p "Write comprehensive documentation for this function" 2>/dev/null > /tmp/vibe-docs.md
```

### Code Review

```bash
# Review single file
$GTIMEOUT 120 "$VIBE" \
  --headless \
  --no-prompt \
  --model codestral-latest \
  review -f "src/complex-module.ts" \
  -p "Analyze for security issues, performance bottlenecks, and code smells" 2>/dev/null > /tmp/vibe-review.md

# Review with specific focus
$GTIMEOUT 120 "$VIBE" \
  --headless \
  --no-prompt \
  --model mistral-large-latest \
  review -f "src/api-handler.ts" \
  -p "Focus on error handling and edge cases" 2>/dev/null > /tmp/vibe-error-review.md
```

### File Context (@-syntax)

```bash
# Include file contents in prompt
$GTIMEOUT 120 "$VIBE" \
  --headless \
  --no-prompt \
  review -f "@src/utils.ts" \
  -p "Review this utility file for best practices" 2>/dev/null > /tmp/vibe-utils-review.md
```

## Model Selection

| Model ID | Use Case | Speed/Quality |
|---|---|---|
| `codestral-latest` | Code generation (default) | ⚡ Fast, 🎯 High accuracy |
| `mistral-large-latest` | Complex reasoning | 🐢 Slower, 🧠 Highest quality |
| `mistral-medium-latest` | Balanced tasks | ⏱️  Medium, ⭐ Good quality |
| `mistral-small-latest` | Simple tasks | 🚀 Fastest, ✅ Adequate quality |

**Best practice:** Use `codestral-latest` for code generation (default in meta-execute).
Use `mistral-large-latest` for complex analysis and documentation tasks.

## Output Validation (MANDATORY)

**Vibe produces concise output** — expect 50-500 characters for typical responses.

```bash
# Validate output file
if [ ! -s /tmp/vibe-output.md ]; then
  echo "ERROR: Vibe produced empty output" >&2
  exit 1
fi

# Check character count (expect ≥ 50 chars for real response)
CHARS=$(wc -c < /tmp/vibe-output.md 2>/dev/null | tr -d ' ')
if [ "${CHARS:-0}" -lt 50 ]; then
  echo "ERROR: Vibe output too small (${CHARS} chars)" >&2
  exit 1
fi
```

## Critical Gotchas

1. **`--headless --no-prompt` are MANDATORY** — without them, CLI hangs indefinitely
2. **Always wrap with `$GTIMEOUT`** — CLI hangs on tool call failures
3. **Character count > line count** — Vibe produces compact, dense output
4. **Exit codes**: `0` = success, `1` = error, `130` = timeout
5. **`2>/dev/null` is mandatory** — stderr contains progress artifacts
6. **Model defaults**: No `--model` flag uses Mistral's default (usually `mistral-medium`)
7. **Concurrency**: Max 3 simultaneous Vibe processes (track with PID file)

## Concurrency Limit (MANDATORY)

```bash
PID_FILE=/tmp/vibe-slots.pid

# Prune dead entries
if [ -f "$PID_FILE" ]; then
  while IFS= read -r pid; do
    ps -p "$pid" >/dev/null 2>&1 && echo "$pid"
  done < "$PID_FILE" > "${PID_FILE}.tmp"
  mv "${PID_FILE}.tmp" "$PID_FILE"
fi

# Check slot availability (max 3)
ACTIVE=$(wc -l < "$PID_FILE" 2>/dev/null || echo 0)
if [ "$ACTIVE" -ge 3 ]; then
  echo "All 3 Vibe slots occupied — queuing or skipping"
  # Queue or exit based on your workflow
fi

# After launching, append PID
echo $! >> /tmp/vibe-slots.pid
```

## Fallback Behavior

| Failure Mode | Fallback |
|---|---|
| CLI not installed | Try Codex (`/codex`); then Claude direct generation |
| Timeout (exit 130) | Retry once with 240s; then try Codex |
| Empty output | Try different model; then try Codex |
| Rate limit | Queue and retry after 60s; then try Codex |

## Real-World Examples (From meta-execute)

```bash
# Generation work unit (meta-execute pattern)
$GTIMEOUT 180 "$VIBE" \
  --headless \
  --no-prompt \
  --model codestral-latest \
  generate -p "$(cat /tmp/wu-feature-x-prompt.md)" 2>/dev/null > /tmp/wu-feature-x-vibe.md

# Parallel generation with Codex
$GTIMEOUT 180 "$VIBE" \
  --headless \
  --no-prompt \
  --model codestral-latest \
  generate -p "$(cat /tmp/prompt.md)" 2>/dev/null > /tmp/vibe-output.md &
VIBE_PID=$!

$GTIMEOUT 180 "$CODEX" exec --ephemeral -c "$(cat /tmp/prompt.md)" 2>/dev/null > /tmp/codex-output.md &
CODEX_PID=$!

wait $VIBE_PID $CODEX_PID

# Compare outputs and select best
if [ -s /tmp/vibe-output.md ] && [ -s /tmp/codex-output.md ]; then
  # Implementation selection logic here
fi
```

## Performance Characteristics

**Benchmark (from meta-execute usage):**
- **Cold start**: ~2-3s (CLI load time)
- **Typical generation**: 5-15s for 50-200 LOC
- **Complex analysis**: 15-45s for architecture reviews
- **Concurrency**: 3 parallel processes optimal
- **Token efficiency**: ~2-3x more efficient than Codex for code tasks

**When to use Vibe:**
- ✅ Fast code generation (primary use case)
- ✅ Code review and analysis
- ✅ Simple refactoring suggestions
- ✅ Documentation generation

**When to avoid Vibe:**
- ❌ Complex multi-step workflows
- ❌ Web research (no grounding)
- ❌ Architecture decisions (use Claude)
- ❌ Security-critical code (use multiple reviewers)

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
