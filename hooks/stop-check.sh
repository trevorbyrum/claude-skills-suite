#!/usr/bin/env bash
# Stop hook — Ralph-loop pattern
# First stop: block and prompt Claude to check docs + context
# Second stop (stop_hook_active=true): allow through

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

cat <<'EOF'
{
  "decision": "block",
  "reason": "Before stopping: Check if cnotes.md, todo.md, or features.md need updating based on what you just did. If there were notable decisions, context changes, action items, or feature changes — update them. If nothing notable to update, you may stop."
}
EOF
