#!/usr/bin/env bash
# claude-monitor uninstaller — Mac / Linux
set -euo pipefail

CLAUDE="$HOME/.claude"
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "")

echo "claude-monitor uninstaller"
echo "=========================="

# Remove scripts
rm -f "$CLAUDE/claude-monitor-statusline.sh"
rm -f "$CLAUDE/claude-monitor-hook.sh"
echo "Scripts removed."

# Remove state files (legacy global + per-session)
rm -f "$CLAUDE/.agent-state" "$CLAUDE/.skill-state" "$CLAUDE/.ctx-prev" "$CLAUDE/.compaction-count"
find "$CLAUDE" -maxdepth 1 -type f \( -name ".agent-state-*" -o -name ".skill-state-*" -o -name ".ctx-prev-*" -o -name ".compaction-count-*" \) -delete 2>/dev/null || true
echo "State files removed."

# Patch settings.json
if [ -z "$PYTHON" ]; then
    echo "WARNING: Python not found. Please remove the claude-monitor entries from ~/.claude/settings.json manually."
    exit 0
fi

"$PYTHON" - <<'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
if not os.path.exists(settings_path):
    print("settings.json not found, nothing to patch.")
    exit()

with open(settings_path, encoding="utf-8") as f:
    settings = json.load(f)

changed = False

# Remove statusLine if it points to claude-monitor
sl = settings.get("statusLine", {})
if isinstance(sl, dict) and "claude-monitor" in sl.get("command", ""):
    del settings["statusLine"]
    changed = True

hooks = settings.get("hooks", {})

# Remove SessionStart entries added by claude-monitor (legacy clear cmd or new cleanup cmd)
session = hooks.get("SessionStart", [])
before = len(session)
hooks["SessionStart"] = [
    h for h in session
    if ".agent-state" not in str(h) and "ctx-prev" not in str(h) and "compaction-count" not in str(h)
]
if len(hooks["SessionStart"]) != before:
    changed = True

# Remove PostToolUse hook added by claude-monitor (matcher Skill legacy or .* current)
post = hooks.get("PostToolUse", [])
before = len(post)
hooks["PostToolUse"] = [
    h for h in post
    if "claude-monitor-hook" not in str(h)
]
if len(hooks["PostToolUse"]) != before:
    changed = True

# Clean up empty lists
for key in ["SessionStart", "PostToolUse"]:
    if key in hooks and not hooks[key]:
        del hooks[key]
if not hooks:
    settings.pop("hooks", None)

if changed:
    with open(settings_path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)
    print("settings.json cleaned up.")
else:
    print("No claude-monitor entries found in settings.json.")
PYEOF

echo ""
echo "Done! Restart Claude Code to apply."
