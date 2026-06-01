#!/usr/bin/env bash
# detect-state.sh — Detect which /init pathway applies based on filesystem state.
#
# Outputs ONE of: greenfield | join-existing | sub-project | pivot | ambiguous
# Run from the intended project root.
#
# Exit code 0 on success. Always prints exactly one token on stdout.

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
cd "$PROJECT_ROOT"

# Detect git presence
HAS_GIT=0
[ -d .git ] && HAS_GIT=1

# Detect canonical context doc
HAS_CONTEXT=0
[ -f project-context.md ] && HAS_CONTEXT=1

# Detect parent project (one level up)
HAS_PARENT_PROJECT=0
if [ -f "../project-context.md" ] && [ -d "../.git" ]; then
  HAS_PARENT_PROJECT=1
fi

# Detect non-trivial file presence (anything but the obvious roots)
HAS_CODE=0
if [ -d src ] || [ -d lib ] || [ -d app ] || \
   ls *.{ts,tsx,js,jsx,py,go,rs,java,cpp,c,h,hpp,rb,php,swift,kt,scala,lua,sh,bash,zsh} 2>/dev/null | head -1 | grep -q .; then
  HAS_CODE=1
fi

# Detect pivot cues — the script can't read the user prompt, but a recent
# `.pivot-pending` sentinel or a commit message containing "pivot" is a signal.
# Fall back to AMBIGUOUS for the SKILL.md to ask.
HAS_PIVOT_HINT=0
[ -f .pivot-pending ] && HAS_PIVOT_HINT=1
if [ $HAS_GIT -eq 1 ] && git log -1 --pretty=%B 2>/dev/null | grep -qi "pivot\|scope change\|rewrite" 2>/dev/null; then
  HAS_PIVOT_HINT=1
fi

# Decide
if [ $HAS_GIT -eq 0 ] && [ $HAS_CONTEXT -eq 0 ] && [ $HAS_CODE -eq 0 ]; then
  echo "greenfield"
elif [ $HAS_CONTEXT -eq 0 ] && [ $HAS_CODE -eq 1 ]; then
  echo "join-existing"
elif [ $HAS_PARENT_PROJECT -eq 1 ] && [ $HAS_CONTEXT -eq 0 ]; then
  echo "sub-project"
elif [ $HAS_CONTEXT -eq 1 ] && [ $HAS_PIVOT_HINT -eq 1 ]; then
  echo "pivot"
elif [ $HAS_CONTEXT -eq 1 ]; then
  # Already initialized — could be re-init, pivot, or no-op
  echo "ambiguous"
elif [ $HAS_GIT -eq 1 ] && [ $HAS_CONTEXT -eq 0 ]; then
  # Empty repo, no docs
  echo "greenfield"
else
  echo "ambiguous"
fi
