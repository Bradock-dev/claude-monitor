#!/usr/bin/env bash
# claude-monitor — UserPromptSubmit hook for agent activation via slash command
# Agents activated by typing "/namespace:agents:name" load a slash command, which
# does NOT invoke the Skill tool — so the PostToolUse:Skill hook never fires and the
# active agent goes undetected. This hook parses the submitted prompt for the
# "*:agents:name" pattern and records the active agent directly.
# State files are scoped per session_id so multiple concurrent terminals don't collide.

INPUT=$(cat)
STATE_DIR="$HOME/.claude"
DEBUG_FILE="$STATE_DIR/.monitor-debug"

# Fast pre-check: skip unless the prompt mentions an agent activation
echo "$INPUT" | grep -qF ':agents:' || exit 0

# Use Python to parse JSON reliably (handles spaces after colons in any format).
# Verify actual version output — on Windows, python3 may be a dead Store alias.
PYTHON=""
for _cmd in python python3; do
    _ver=$("$_cmd" -c "import sys; print(sys.version_info[0])" 2>/dev/null)
    [ "$_ver" = "3" ] && PYTHON="$_cmd" && break
done

if [ -n "$PYTHON" ]; then
    PARSED=$( printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    prompt = d.get('prompt', '') or ''
    sid = d.get('session_id', '')
    # Match an activation like /AIOX:agents:dev or AIOX:agents:dev
    m = re.search(r'[A-Za-z0-9._-]+:agents:([A-Za-z0-9._-]+)', prompt)
    print(m.group(1) if m else '')
    print(sid)
except:
    print('')
    print('')
" 2>/dev/null )
    AGENT=$(echo "$PARSED" | sed -n '1p')
    SID=$(echo "$PARSED"   | sed -n '2p')
else
    # Fallback: grep the first "*:agents:name" occurrence in the raw payload
    AGENT=$(echo "$INPUT" | grep -o '[A-Za-z0-9._-]*:agents:[A-Za-z0-9._-]*' | head -1 | sed 's/.*:agents://')
    SID=$(echo "$INPUT"   | grep -o '"session_id" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
fi

AGENT=$(echo "$AGENT" | tr -d '[:space:]')
SID=$(echo "$SID"     | tr -d '[:space:]')

# Sanitize session_id (UUID-like — letters, digits, hyphens only). Fallback to "default".
SID=$(printf '%s' "$SID" | tr -cd 'a-fA-F0-9-')
[ -z "$SID" ] && SID="default"

if [ -f "$DEBUG_FILE" ]; then
    LOG="$STATE_DIR/.monitor-debug-log"
    printf '\n--- %s (UserPromptSubmit) ---\n' "$(date)" >> "$LOG"
    printf 'SID: %s\n'   "$SID"   >> "$LOG"
    printf 'AGENT: %s\n' "$AGENT" >> "$LOG"
fi

# No agent name resolved — nothing to record
[ -z "$AGENT" ] && exit 0

echo "$AGENT" > "$STATE_DIR/.agent-state-$SID"
# Switching agents clears the previously active skill (mirrors post-skill.sh)
printf "" > "$STATE_DIR/.skill-state-$SID"
exit 0
