#!/usr/bin/env bash
# claude-monitor — PostToolUse hook for Skill tracking
# Detects any agent framework (pattern: *:agents:*) and any skill activation.

INPUT=$(cat)
STATE_DIR="$HOME/.claude"

# Use Python to parse JSON reliably (handles spaces after colons in any format).
# Test actual execution — on Windows, python3 may be a dead Store alias.
PYTHON=""
for _cmd in python3 python; do
    if "$_cmd" -c "import sys" 2>/dev/null; then
        PYTHON="$_cmd"
        break
    fi
done

if [ -n "$PYTHON" ]; then
    SKILL=$( printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', d)
    print(ti.get('skill', ''))
except:
    print('')
" 2>/dev/null )
else
    # Fallback: grep handles both 'skill":"' and 'skill": "'
    SKILL=$(echo "$INPUT" | grep -o '"skill" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
fi

SKILL=$(echo "$SKILL" | tr -d '[:space:]')

if [[ "$SKILL" == *:agents:* ]]; then
    # Any framework's agent (AIOX:agents:dev, myfw:agents:qa, etc.)
    AGENT=$(echo "$SKILL" | sed 's/.*:agents://')
    echo "$AGENT" > "$STATE_DIR/.agent-state"
    printf "" > "$STATE_DIR/.skill-state"
elif [[ -n "$SKILL" ]]; then
    echo "$SKILL" > "$STATE_DIR/.skill-state"
fi
