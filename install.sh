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

# Remove legacy global state files (replaced by per-session files)
rm -f "$CLAUDE/.agent-state" "$CLAUDE/.skill-state" "$CLAUDE/.ctx-prev" "$CLAUDE/.compaction-count"

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

# SessionStart — garbage-collect orphan per-session state files (>24h since last write)
session_start = hooks.setdefault("SessionStart", [])
cleanup_cmd = "bash -c 'find ~/.claude -maxdepth 1 -type f \\( -name \".agent-state-*\" -o -name \".skill-state-*\" -o -name \".ctx-prev-*\" -o -name \".compaction-count-*\" \\) -mmin +1440 -delete 2>/dev/null || true'"
# Remove legacy claude-monitor entries (anything that touches .agent-state)
session_start[:] = [h for h in session_start if ".agent-state" not in str(h)]
session_start.append({"hooks": [{"type": "command", "command": cleanup_cmd}]})

# PostToolUse — track skill/agent (always set correct command path)
post_tool = hooks.setdefault("PostToolUse", [])
hook_cmd = "bash ~/.claude/claude-monitor-hook.sh"
# Remove old "Skill" matcher entries (now handled internally by the hook script)
post_tool[:] = [h for h in post_tool if h.get("matcher") != "Skill"]
existing = next((h for h in post_tool if h.get("matcher") == ".*"), None)
if existing:
    existing["hooks"] = [{"type": "command", "command": hook_cmd}]
else:
    post_tool.append({"matcher": ".*", "hooks": [{"type": "command", "command": hook_cmd}]})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("settings.json updated.")
PYEOF

echo ""
echo "Done! Restart Claude Code to activate claude-monitor."
