#!/usr/bin/env bash
# claude-monitor — PostToolUse hook for Skill tracking
# Detects any agent framework (pattern: *:agents:*) and any skill activation.

INPUT=$(cat)
STATE_DIR="$HOME/.claude"

# Extract skill name from JSON
SKILL=$(echo "$INPUT" | grep -o '"skill":"[^"]*"' | cut -d'"' -f4)

if [[ "$SKILL" == *:agents:* ]]; then
    # Any framework's agent (AIOX:agents:dev, myfw:agents:qa, etc.)
    AGENT=$(echo "$SKILL" | sed 's/.*:agents://')
    echo "$AGENT" > "$STATE_DIR/.agent-state"
    printf "" > "$STATE_DIR/.skill-state"
elif [[ -n "$SKILL" ]]; then
    echo "$SKILL" > "$STATE_DIR/.skill-state"
fi
