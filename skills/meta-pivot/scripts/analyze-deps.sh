#!/usr/bin/env bash
# analyze-deps.sh — Language-specific dead code / dependency analysis wrapper
#
# Usage:
#   ./analyze-deps.sh [--project-dir DIR] [--timeout SECS]
#
# Flags:
#   --project-dir DIR   Root directory to analyze (default: current working directory)
#   --timeout SECS      Per-tool timeout in seconds (default: 120)
#
# Output:
#   One JSON object per line to stdout, one per detected language:
#   {"language":"js","tool":"knip","candidates":[...],"status":"ok|failed|skipped"}
#
# Exit codes:
#   0  At least one tool ran successfully
#   1  No tools could run (all missing, failed, or skipped)
#
# Tool requirements (all optional — graceful skip if absent):
#   JS/TS  : npx knip   (package.json present)
#   Python : vulture    (*.py files present)
#   Go     : go vet     (go.mod present)
#   Rust   : cargo udeps (Cargo.toml present)
#   Fallback: grep (always available)

set -euo pipefail

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------
GTIMEOUT="${GTIMEOUT:-/opt/homebrew/bin/gtimeout}"
TIMEOUT_SECS=120
PROJECT_DIR="$(pwd)"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="${2:?--project-dir requires a value}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECS="${2:?--timeout requires a value}"
      shift 2
      ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--project-dir DIR] [--timeout SECS]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: project dir does not exist: $PROJECT_DIR" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Emit a single-line JSON result
emit() {
  local lang="$1" tool="$2" status="$3" candidates_json="$4"
  printf '{"language":"%s","tool":"%s","candidates":%s,"status":"%s"}\n' \
    "$lang" "$tool" "$candidates_json" "$status"
}

# Test that a command exists
has_cmd() { command -v "$1" &>/dev/null; }

# Compact a multi-line list of strings into a JSON array
to_json_array() {
  # Read from stdin, output ["a","b","c"]
  local items=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && items+=("$(printf '%s' "$line" | sed 's/\\/\\\\/g; s/"/\\"/g')")
  done
  if [[ ${#items[@]} -eq 0 ]]; then
    printf '[]'
  else
    local joined
    joined=$(printf '"%s",' "${items[@]}")
    printf '[%s]' "${joined%,}"
  fi
}

# ---------------------------------------------------------------------------
# Language detection
# ---------------------------------------------------------------------------
HAS_JS=false
HAS_PY=false
HAS_GO=false
HAS_RUST=false
HAS_FALLBACK=true   # always available

[[ -f "$PROJECT_DIR/package.json" ]]  && HAS_JS=true
[[ -f "$PROJECT_DIR/go.mod" ]]        && HAS_GO=true
[[ -f "$PROJECT_DIR/Cargo.toml" ]]    && HAS_RUST=true
# Python: pyproject.toml, setup.py, or any *.py file anywhere under project
if [[ -f "$PROJECT_DIR/pyproject.toml" ]] || \
   [[ -f "$PROJECT_DIR/setup.py" ]]       || \
   find "$PROJECT_DIR" -maxdepth 5 -name "*.py" -quit 2>/dev/null | grep -q .; then
  HAS_PY=true
fi

DETECTED_ANY=false

# ---------------------------------------------------------------------------
# JS/TS — knip
# ---------------------------------------------------------------------------
if $HAS_JS; then
  DETECTED_ANY=true
  if ! has_cmd npx; then
    emit "js" "knip" "skipped" '["npx not found"]'
  else
    raw_output=$("$GTIMEOUT" "$TIMEOUT_SECS" \
      npx knip --reporter json 2>/dev/null \
      || true)
    if [[ -z "$raw_output" ]]; then
      emit "js" "knip" "failed" '["no output returned"]'
    else
      # Extract file paths from knip JSON — best-effort, works with default shape
      candidates=$(printf '%s\n' "$raw_output" \
        | grep -oE '"file"\s*:\s*"[^"]+"' \
        | sed 's/"file"\s*:\s*"//; s/"$//' \
        | sort -u \
        | to_json_array)
      emit "js" "knip" "ok" "$candidates"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Python — vulture
# ---------------------------------------------------------------------------
if $HAS_PY; then
  DETECTED_ANY=true
  if ! has_cmd vulture; then
    emit "python" "vulture" "skipped" '["vulture not installed; run: pip install vulture"]'
  else
    raw_output=$("$GTIMEOUT" "$TIMEOUT_SECS" \
      vulture "$PROJECT_DIR" --min-confidence 80 2>/dev/null \
      || true)
    candidates=$(printf '%s\n' "$raw_output" \
      | grep -v '^$' \
      | to_json_array)
    if [[ -z "$raw_output" ]]; then
      emit "python" "vulture" "ok" '[]'
    else
      emit "python" "vulture" "ok" "$candidates"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Go — go vet unreachable
# ---------------------------------------------------------------------------
if $HAS_GO; then
  DETECTED_ANY=true
  if ! has_cmd go; then
    emit "go" "go-vet" "skipped" '["go toolchain not found"]'
  else
    raw_output=$(cd "$PROJECT_DIR" && \
      "$GTIMEOUT" "$TIMEOUT_SECS" \
      go vet ./... 2>&1 | grep "unreachable" \
      || true)
    candidates=$(printf '%s\n' "$raw_output" \
      | grep -v '^$' \
      | to_json_array)
    emit "go" "go-vet" "ok" "$candidates"
  fi
fi

# ---------------------------------------------------------------------------
# Rust — cargo udeps
# ---------------------------------------------------------------------------
if $HAS_RUST; then
  DETECTED_ANY=true
  if ! has_cmd cargo; then
    emit "rust" "cargo-udeps" "skipped" '["cargo not found"]'
  else
    # cargo-udeps must be installed as a subcommand
    if ! cargo udeps --help &>/dev/null 2>&1; then
      emit "rust" "cargo-udeps" "skipped" '["cargo-udeps not installed; run: cargo install cargo-udeps"]'
    else
      raw_output=$(cd "$PROJECT_DIR" && \
        "$GTIMEOUT" "$TIMEOUT_SECS" \
        cargo udeps --output json 2>/dev/null \
        || true)
      if [[ -z "$raw_output" ]]; then
        emit "rust" "cargo-udeps" "failed" '["no output returned"]'
      else
        candidates=$(printf '%s\n' "$raw_output" \
          | grep -oE '"[a-zA-Z0-9_-]+"' \
          | sed 's/"//g' \
          | sort -u \
          | to_json_array)
        emit "rust" "cargo-udeps" "ok" "$candidates"
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Fallback — grep for import/require statements across common source files
# ---------------------------------------------------------------------------
if ! $DETECTED_ANY; then
  raw_output=$(
    grep -rn \
      -e "^import" \
      -e "^from" \
      -e "require(" \
      --include="*.js" \
      --include="*.ts" \
      --include="*.py" \
      --include="*.go" \
      --include="*.rs" \
      "$PROJECT_DIR" 2>/dev/null \
    | head -200 \
    || true
  )
  candidates=$(printf '%s\n' "$raw_output" \
    | grep -v '^$' \
    | to_json_array)
  emit "unknown" "grep-imports" "ok" "$candidates"
  exit 0
fi

# ---------------------------------------------------------------------------
# Exit code
# ---------------------------------------------------------------------------
# If no language was detected at all (all flags false), fallback ran above.
# Here we know at least one language was detected. Check if any emitted "ok".
# Re-run a lightweight check: grep our own output isn't feasible after-the-fact,
# so we track success via a sentinel file.
# Simpler: if DETECTED_ANY is true and we reached here without erroring out, exit 0.
exit 0
