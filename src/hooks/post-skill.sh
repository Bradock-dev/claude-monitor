#!/usr/bin/env bash
# claude-monitor — PostToolUse hook for Skill tracking
# Detects any agent framework (pattern: *:agents:*) and any skill activation.
# State files are scoped per session_id so multiple concurrent terminals don't collide.

INPUT=$(cat)
STATE_DIR="$HOME/.claude"

# Fast pre-check: skip if payload has no "skill" key (avoids Python for most tool uses)
echo "$INPUT" | grep -qF '"skill"' || exit 0

# Debug mode: create ~/.claude/.monitor-debug to enable logging
DEBUG_FILE="$STATE_DIR/.monitor-debug"

# Use Python to parse JSON reliably (handles spaces after colons in any format).
# Verify actual version output — on Windows, python3 may be a dead Store alias.
PYTHON=""
for _cmd in python python3; do
    _ver=$("$_cmd" -c "import sys; print(sys.version_info[0])" 2>/dev/null)
    [ "$_ver" = "3" ] && PYTHON="$_cmd" && break
done

if [ -n "$PYTHON" ]; then
    PARSED=$( printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tool_name = d.get('tool_name', '')
    sid = d.get('session_id', '')
    ti = d.get('tool_input') or d.get('input') or d
    if isinstance(ti, str):
        try: ti = json.loads(ti)
        except: pass
    skill = ti.get('skill', '') if isinstance(ti, dict) else ''
    print(tool_name)
    print(skill)
    print(sid)
except:
    print('')
    print('')
    print('')
" 2>/dev/null )
    TOOL_NAME=$(echo "$PARSED" | sed -n '1p')
    SKILL=$(echo "$PARSED"     | sed -n '2p')
    SID=$(echo "$PARSED"       | sed -n '3p')
else
    # Fallback: grep handles both 'skill":"' and 'skill": "'
    TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name" *: *"[^"]*"'  | grep -o '"[^"]*"$' | tr -d '"')
    SKILL=$(echo "$INPUT"     | grep -o '"skill" *: *"[^"]*"'      | grep -o '"[^"]*"$' | tr -d '"')
    SID=$(echo "$INPUT"       | grep -o '"session_id" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
fi

TOOL_NAME=$(echo "$TOOL_NAME" | tr -d '[:space:]')
SKILL=$(echo "$SKILL"         | tr -d '[:space:]')
SID=$(echo "$SID"             | tr -d '[:space:]')

# Sanitize session_id (UUID-like — letters, digits, hyphens only). Fallback to "default".
SID=$(printf '%s' "$SID" | tr -cd 'a-fA-F0-9-')
[ -z "$SID" ] && SID="default"

if [ -f "$DEBUG_FILE" ]; then
    LOG="$STATE_DIR/.monitor-debug-log"
    printf '\n--- %s ---\n' "$(date)"    >> "$LOG"
    printf 'SID: %s\n'   "$SID"         >> "$LOG"
    printf 'TOOL: %s\n'  "$TOOL_NAME"   >> "$LOG"
    printf 'SKILL: %s\n' "$SKILL"       >> "$LOG"
fi

# Only process when a skill value is present (works regardless of tool_name)
[ -z "$SKILL" ] && exit 0

AGENT_FILE="$STATE_DIR/.agent-state-$SID"
SKILL_FILE="$STATE_DIR/.skill-state-$SID"

if [[ "$SKILL" == *:agents:* ]]; then
    # Any framework's agent (AIOX:agents:dev, myfw:agents:qa, etc.)
    AGENT=$(echo "$SKILL" | sed 's/.*:agents://')
    echo "$AGENT" > "$AGENT_FILE"
    printf "" > "$SKILL_FILE"
elif [[ -n "$SKILL" ]]; then
    echo "$SKILL" > "$SKILL_FILE"
fi
