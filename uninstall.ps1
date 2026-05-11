# claude-monitor uninstaller — Windows (PowerShell)
# Run with: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = "Stop"

$ClaudeDir = "$env:USERPROFILE\.claude"

Write-Host "claude-monitor uninstaller"
Write-Host "=========================="

# Remove scripts
foreach ($f in @("claude-monitor-statusline.sh", "claude-monitor-hook.sh")) {
    $p = "$ClaudeDir\$f"
    if (Test-Path $p) { Remove-Item $p -Force }
}
Write-Host "Scripts removed."

# Remove state files
foreach ($f in @(".agent-state", ".skill-state", ".ctx-prev", ".compaction-count")) {
    $p = "$ClaudeDir\$f"
    if (Test-Path $p) { Remove-Item $p -Force }
}
Write-Host "State files removed."

# Detect python
$Python = $null
foreach ($cmd in @("python", "python3")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python") { $Python = $cmd; break }
    } catch {}
}

if (-not $Python) {
    Write-Warning "Python not found. Please remove the claude-monitor entries from ~/.claude/settings.json manually."
    exit 0
}

$patchScript = @'
import json, os, sys

settings_path = os.path.join(os.environ["USERPROFILE"], ".claude", "settings.json")
if not os.path.exists(settings_path):
    print("settings.json not found, nothing to patch.")
    sys.exit()

with open(settings_path, encoding="utf-8") as f:
    settings = json.load(f)

changed = False

sl = settings.get("statusLine", {})
if isinstance(sl, dict) and "claude-monitor" in sl.get("command", ""):
    del settings["statusLine"]
    changed = True

hooks = settings.get("hooks", {})

session = hooks.get("SessionStart", [])
before = len(session)
hooks["SessionStart"] = [h for h in session if ".agent-state" not in str(h)]
if len(hooks["SessionStart"]) != before:
    changed = True

post = hooks.get("PostToolUse", [])
before = len(post)
hooks["PostToolUse"] = [
    h for h in post
    if not (h.get("matcher") == "Skill" and "claude-monitor-hook" in str(h))
]
if len(hooks["PostToolUse"]) != before:
    changed = True

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
'@

$patchScript | & $Python -
Write-Host ""
Write-Host "Done! Restart Claude Code to apply."
