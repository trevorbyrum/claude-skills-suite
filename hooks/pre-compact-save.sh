#!/usr/bin/env bash
# PreCompact hook — Context snapshot
# Captures a lightweight snapshot of working state before Claude compacts the context window.
# If meta-compact ran recently (compact file < 5 min old), skip to avoid duplicate writes.
# If artifacts/db.sh is present, stores the snapshot via db_write (append-only).
# Falls back to a flat markdown file in artifacts/compact/ when no DB is available.
# Cannot block compaction — always exits 0.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")
PROJECT="$CWD"

# --- Skip if meta-compact ran recently ---
COMPACT_FILE="$CWD/artifacts/compact/claude-compact.md"
# Also check legacy path used by older hooks
LEGACY_COMPACT="$CWD/compact/claude-compact.md"
for CF in "$COMPACT_FILE" "$LEGACY_COMPACT"; do
  if [ -f "$CF" ]; then
    NOW=$(date +%s)
    MTIME=$(stat -f %m "$CF" 2>/dev/null)
    [ -z "$MTIME" ] && MTIME=$(stat -c %Y "$CF" 2>/dev/null)
    if [ -n "$MTIME" ]; then
      AGE=$(( NOW - MTIME ))
      if [ "$AGE" -lt 300 ]; then
        # meta-compact ran within 5 minutes — snapshot already captured
        exit 0
      fi
    fi
  fi
done

# --- Gather snapshot data ---
SNAP_CWD="$CWD"
GIT_BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)")
GIT_LOG=$(git -C "$CWD" log --oneline -5 2>/dev/null || echo "(unavailable)")
GIT_STATUS=$(git -C "$CWD" status --short 2>/dev/null || echo "(unavailable)")
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

CONTENT="# Pre-Compact Snapshot — $TIMESTAMP

## Working Directory
$SNAP_CWD

## Git Branch
$GIT_BRANCH

## Recent Commits (last 5)
$GIT_LOG

## Modified Files
${GIT_STATUS:-(none)}
"

# --- Store snapshot ---
DB_SCRIPT="$CWD/artifacts/db.sh"

if [ -f "$DB_SCRIPT" ]; then
  # shellcheck source=/dev/null
  source "$DB_SCRIPT"
  db_write "meta-context-save" "snapshot" "$PROJECT/$TIMESTAMP" "$CONTENT"
else
  # Fallback: write to flat file
  mkdir -p "$CWD/artifacts/compact"
  FALLBACK_FILE="$CWD/artifacts/compact/pre-compact-${TIMESTAMP}.md"
  printf '%s' "$CONTENT" > "$FALLBACK_FILE"
fi

exit 0
