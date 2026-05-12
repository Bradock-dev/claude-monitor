# claude-monitor installer — Windows (PowerShell)
# Run with: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$ClaudeDir = "$env:USERPROFILE\.claude"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "claude-monitor installer"
Write-Host "========================"

# Detect python
$Python = $null
foreach ($cmd in @("python", "python3")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python") { $Python = $cmd; break }
    } catch {}
}

if (-not $Python) {
    Write-Error "Python is required. Please install Python from https://python.org"
    exit 1
}

# Create .claude dir if needed
if (-not (Test-Path $ClaudeDir)) { New-Item -ItemType Directory -Path $ClaudeDir | Out-Null }

# Copy scripts (use bash-compatible paths via Git Bash)
$bashAvailable = $null
foreach ($cmd in @("bash", "C:\Program Files\Git\bin\bash.exe")) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) { $bashAvailable = $cmd; break }
}

Copy-Item "$ScriptDir\src\statusline.sh"       "$ClaudeDir\claude-monitor-statusline.sh" -Force
Copy-Item "$ScriptDir\src\hooks\post-skill.sh" "$ClaudeDir\claude-monitor-hook.sh"       -Force

# Init state files
"" | Out-File "$ClaudeDir\.agent-state"       -Encoding utf8 -NoNewline
"" | Out-File "$ClaudeDir\.skill-state"       -Encoding utf8 -NoNewline
"" | Out-File "$ClaudeDir\.ctx-prev"          -Encoding utf8 -NoNewline
"" | Out-File "$ClaudeDir\.compaction-count"  -Encoding utf8 -NoNewline

Write-Host "Scripts installed."

# Patch settings.json
$patchScript = @'
import json, os, sys

settings_path = os.path.join(os.environ["USERPROFILE"], ".claude", "settings.json")

if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as f:
        settings = json.load(f)
else:
    settings = {}

settings["statusLine"] = {
    "type": "command",
    "command": "bash ~/.claude/claude-monitor-statusline.sh"
}

hooks = settings.setdefault("hooks", {})

clear_cmd = "bash -c 'printf \"\" > ~/.claude/.agent-state && printf \"\" > ~/.claude/.skill-state && printf \"\" > ~/.claude/.ctx-prev && printf \"\" > ~/.claude/.compaction-count'"
session_start = hooks.setdefault("SessionStart", [])
if not any(clear_cmd in str(h) for h in session_start):
    session_start.append({"hooks": [{"type": "command", "command": clear_cmd}]})

post_tool = hooks.setdefault("PostToolUse", [])
hook_cmd = "bash ~/.claude/claude-monitor-hook.sh"
existing = next((h for h in post_tool if h.get("matcher") == "Skill"), None)
if existing:
    existing["hooks"] = [{"type": "command", "command": hook_cmd}]
else:
    post_tool.append({"matcher": "Skill", "hooks": [{"type": "command", "command": hook_cmd}]})

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2)

print("settings.json updated.")
'@

$patchScript | & $Python -
Write-Host ""
Write-Host "Done! Restart Claude Code to activate claude-monitor."
