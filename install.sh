#!/usr/bin/env bash
# claude-monitor installer — Mac / Linux
set -euo pipefail

CLAUDE="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON=""
for _cmd in python3 python; do
    if "$_cmd" -c "import sys" 2>/dev/null; then PYTHON="$_cmd"; break; fi
done

echo "claude-monitor installer"
echo "========================"

if [ -z "$PYTHON" ]; then
    echo "ERROR: python3 or python is required. Please install Python first."
    exit 1
fi

mkdir -p "$CLAUDE"

# Copy scripts
cp "$SCRIPT_DIR/src/statusline.sh"       "$CLAUDE/claude-monitor-statusline.sh"
cp "$SCRIPT_DIR/src/hooks/post-skill.sh" "$CLAUDE/claude-monitor-hook.sh"
# Normalize to LF — bash scripts fail silently with CRLF (sed -i differs on macOS vs Linux)
if sed --version 2>/dev/null | grep -q GNU; then
    sed -i 's/\r//' "$CLAUDE/claude-monitor-statusline.sh" "$CLAUDE/claude-monitor-hook.sh"
else
    sed -i '' 's/\r//' "$CLAUDE/claude-monitor-statusline.sh" "$CLAUDE/claude-monitor-hook.sh"
fi
chmod +x "$CLAUDE/claude-monitor-statusline.sh" "$CLAUDE/claude-monitor-hook.sh"

# Init state files
touch "$CLAUDE/.agent-state" "$CLAUDE/.skill-state" "$CLAUDE/.ctx-prev" "$CLAUDE/.compaction-count"

echo "Scripts installed."

# Patch settings.json
"$PYTHON" - <<'PYEOF'
import json, os, sys

settings_path = os.path.expanduser("~/.claude/settings.json")

if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

# statusLine
settings["statusLine"] = {
    "type": "command",
    "command": "bash ~/.claude/claude-monitor-statusline.sh"
}

hooks = settings.setdefault("hooks", {})

# SessionStart — clear state files
session_start = hooks.setdefault("SessionStart", [])
clear_cmd = "bash -c 'printf \"\" > ~/.claude/.agent-state && printf \"\" > ~/.claude/.skill-state && printf \"\" > ~/.claude/.ctx-prev && printf \"\" > ~/.claude/.compaction-count'"
if not any(clear_cmd in str(h) for h in session_start):
    session_start.append({"hooks": [{"type": "command", "command": clear_cmd}]})

# PostToolUse — track skill/agent (always set correct command path)
post_tool = hooks.setdefault("PostToolUse", [])
hook_cmd = "bash ~/.claude/claude-monitor-hook.sh"
existing = next((h for h in post_tool if h.get("matcher") == "Skill"), None)
if existing:
    existing["hooks"] = [{"type": "command", "command": hook_cmd}]
else:
    post_tool.append({"matcher": "Skill", "hooks": [{"type": "command", "command": hook_cmd}]})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("settings.json updated.")
PYEOF

echo ""
echo "Done! Restart Claude Code to activate claude-monitor."
