# claude-monitor

A live status line for [Claude Code](https://claude.ai/code) that shows your working context at a glance — model, directory, git branch, active agent, active skill, context window usage, and rate limit.

```
[Sonnet 4.6] │ 📁 my-project │ 🐱 main │ 🤖 @dev │ ⚡ /tlc-spec-driven
   contexto ███████░░░ 74% │ limite de uso  ███░░░░░░░ 35% ↻ 2h43m │ compact: 0
```

Colors adapt automatically:
- **Green** → healthy
- **Yellow** → warning (context below 30% / rate limit above 60%)
- **Red** → critical (context below 10% / rate limit above 90%)

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

Remove the installed files and revert the settings entries manually:

```bash
rm ~/.claude/claude-monitor-statusline.sh
rm ~/.claude/claude-monitor-hook.sh
rm ~/.claude/.agent-state
rm ~/.claude/.skill-state
```

Then remove the `statusLine` key and the claude-monitor entries from `hooks` in `~/.claude/settings.json`.

---

## License

MIT
