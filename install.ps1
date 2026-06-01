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

# Normalize to LF — bash scripts fail silently with CRLF on Windows
foreach ($f in @("$ClaudeDir\claude-monitor-statusline.sh", "$ClaudeDir\claude-monitor-hook.sh")) {
    $content = [System.IO.File]::ReadAllText($f) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($f, $content, (New-Object System.Text.UTF8Encoding $false))
}

# Remove legacy global state files (replaced by per-session files)
foreach ($f in @(".agent-state", ".skill-state", ".ctx-prev", ".compaction-count")) {
    $p = "$ClaudeDir\$f"
    if (Test-Path $p) { Remove-Item $p -Force }
}

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

cleanup_cmd = "bash -c 'find ~/.claude -maxdepth 1 -type f \\( -name \".agent-state-*\" -o -name \".skill-state-*\" -o -name \".ctx-prev-*\" -o -name \".compaction-count-*\" \\) -mmin +1440 -delete 2>/dev/null || true'"
session_start = hooks.setdefault("SessionStart", [])
# Remove legacy claude-monitor entries (anything that touches .agent-state)
session_start[:] = [h for h in session_start if ".agent-state" not in str(h)]
session_start.append({"hooks": [{"type": "command", "command": cleanup_cmd}]})

post_tool = hooks.setdefault("PostToolUse", [])
hook_cmd = "bash ~/.claude/claude-monitor-hook.sh"
# Remove old "Skill" matcher entries (now handled internally by the hook script)
post_tool[:] = [h for h in post_tool if h.get("matcher") != "Skill"]
existing = next((h for h in post_tool if h.get("matcher") == ".*"), None)
if existing:
    existing["hooks"] = [{"type": "command", "command": hook_cmd}]
else:
    post_tool.append({"matcher": ".*", "hooks": [{"type": "command", "command": hook_cmd}]})

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2)

print("settings.json updated.")
'@

$patchScript | & $Python -
Write-Host ""
Write-Host "Done! Restart Claude Code to activate claude-monitor."
