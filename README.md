# claude-monitor

A live status line for [Claude Code](https://claude.ai/code) that shows your working context at a glance — model, directory, git branch, active agent, active skill, context window usage, and rate limit.

![claude-monitor preview](docs/preview.svg)

```
[Sonnet 4.6] │ 📁 my-project │ 🐱 feature/auth │ 🤖 @dev │ ⚡ /tlc-spec-driven
   contexto ███░░░░░░░ 35% │ compact: 2x │ limite de uso  ██████░░░░ 68% ↻ 1h23m
```

Colors adapt automatically (0–33% green · 34–66% yellow · 67–100% red):
- **Green** → healthy usage
- **Yellow** → moderate usage
- **Red** → critical — approaching limit

---

## What it shows

| Field | Description |
|---|---|
| `[Model]` | Claude model currently in use |
| `📁 dir` | Current working directory (basename) |
| `🐱` | Active git branch, or `--` outside a repo |
| `🤖` | Active agent (any framework using `*:agents:*` skill pattern) |
| `⚡` | Active skill currently loaded |
| `contexto` | Remaining context window with progress bar |
| `limite de uso` | 5-hour usage rate with countdown to reset |

---

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- Bash (Git Bash on Windows, native on Mac/Linux)
- Python 3 (`python3` on Mac/Linux, `python` on Windows)
- Git (optional, for branch display)

---

## Installation

### Mac / Linux

```bash
git clone https://github.com/BRADOCK-DEV/claude-monitor.git
cd claude-monitor
bash install.sh
```

### Windows

```powershell
git clone https://github.com/BRADOCK-DEV/claude-monitor.git
cd claude-monitor
powershell -ExecutionPolicy Bypass -File install.ps1
```

Restart Claude Code after installing.

---

## Agent & Skill tracking

claude-monitor tracks active agents and skills automatically via a `PostToolUse` hook on Claude Code's `Skill` tool.

**Works with any framework** that follows the `namespace:agents:name` skill naming convention (e.g., `AIOX:agents:dev`, `myfw:agents:qa`). Frameworks that don't use this pattern will still show the active skill name.

The `SessionStart` hook clears the state at the beginning of each session so you never see stale data.

---

## How it works

1. `install.sh` / `install.ps1` copies two scripts to `~/.claude/`:
   - `claude-monitor-statusline.sh` — reads the JSON payload Claude Code provides each turn and renders the two-line status
   - `claude-monitor-hook.sh` — PostToolUse hook that writes agent/skill state to `~/.claude/.agent-state` and `~/.claude/.skill-state`

2. `settings.json` is patched to wire up:
   - `statusLine` → runs `claude-monitor-statusline.sh` each turn
   - `PostToolUse` (matcher: `Skill`) → runs `claude-monitor-hook.sh`
   - `SessionStart` → clears state files

---

## Uninstall

### Mac / Linux

```bash
bash uninstall.sh
```

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

Removes all installed scripts, state files, and reverts `~/.claude/settings.json` automatically.

---

## License

MIT
