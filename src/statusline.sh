#!/usr/bin/env bash
# claude-monitor — statusline script
# https://github.com/BRADOCK-DEV/claude-monitor

input=$(cat)

# --- Detect python ---
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)

# --- Parse JSON ---
json_out=$(echo "$input" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ctx = d.get('context_window', {})
    rl  = d.get('rate_limits', {}).get('five_hour', {})
    print(d.get('cwd', ''))
    print(d.get('model', {}).get('display_name', ''))
    print(str(ctx.get('remaining_percentage', '')))
    print(str(ctx.get('used_percentage', '')))
    print(str(rl.get('used_percentage', '')))
    print(str(rl.get('resets_at', '')))
except:
    for _ in range(6): print('')
" 2>/dev/null)

cwd=$(echo "$json_out"      | sed -n '1p')
model=$(echo "$json_out"    | sed -n '2p')
ctx_rem=$(echo "$json_out"  | sed -n '3p')
ctx_used=$(echo "$json_out" | sed -n '4p')
five_pct=$(echo "$json_out" | sed -n '5p')
five_rst=$(echo "$json_out" | sed -n '6p')

# --- ANSI ---
ESC=$'\033'
R="${ESC}[0m"
RED="${ESC}[38;5;196m"
YEL="${ESC}[38;5;220m"
GRN="${ESC}[38;5;82m"
BLU="${ESC}[38;5;75m"
CYN="${ESC}[38;5;45m"
MAG="${ESC}[38;5;171m"
GRY="${ESC}[38;5;244m"

# --- Progress bar ---
make_bar() {
    local pct=${1:-0} width=${2:-10} filled empty bar=""
    filled=$(( pct * width / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    empty=$(( width - filled ))
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    printf '%s' "$bar"
}

ctx_color()  { local p=${1:-0}; [ "$p" -le 10 ] && printf '%s' "$RED" || { [ "$p" -le 30 ] && printf '%s' "$YEL" || printf '%s' "$GRN"; }; }
rate_color() { local p=${1:-0}; [ "$p" -ge 90 ] && printf '%s' "$RED" || { [ "$p" -ge 60 ] && printf '%s' "$YEL" || printf '%s' "$GRN"; }; }

# --- Data ---
dir_name=$(basename "${cwd:-$(pwd)}")
model_short=$(echo "${model:-?}" | sed 's/Claude //')
git_branch=$(git -C "${cwd:-.}" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)

STATE_DIR="$HOME/.claude"
agent=$([ -f "$STATE_DIR/.agent-state" ] && tr -d '[:space:]' < "$STATE_DIR/.agent-state" 2>/dev/null || echo "")
skill=$([ -f "$STATE_DIR/.skill-state" ]  && tr -d '[:space:]' < "$STATE_DIR/.skill-state"  2>/dev/null || echo "")

# --- Context window ---
ctx_int=0; ctx_disp="?"
if [ -n "$ctx_rem" ]; then
    ctx_int=$(printf '%.0f' "$ctx_rem"); ctx_disp="${ctx_int}%"
elif [ -n "$ctx_used" ]; then
    u=$(printf '%.0f' "$ctx_used"); ctx_int=$(( 100 - u )); ctx_disp="${ctx_int}%"
fi
CTX_C=$(ctx_color "$ctx_int")
ctx_bar=$(make_bar "$ctx_int" 10)

# --- 5h rate limit ---
five_int=0; five_disp="?"; reset_str=""
if [ -n "$five_pct" ]; then
    five_int=$(printf '%.0f' "$five_pct"); five_disp="${five_int}%"
    if [ -n "$five_rst" ]; then
        now=$(date +%s); diff=$(( five_rst - now ))
        if [ "$diff" -gt 0 ]; then
            m=$(( diff / 60 )); h=$(( m / 60 )); m=$(( m % 60 )); s=$(( diff % 60 ))
            [ "$h" -gt 0 ] && reset_str=" ↻ ${h}h${m}m" || reset_str=" ↻ ${m}m${s}s"
        fi
    fi
fi
FIVE_C=$(rate_color "$five_int")
five_bar=$(make_bar "$five_int" 10)

# --- Separator ---
S="${GRY} │ ${R}"

# === LINE 1: model │ dir │ branch │ agent │ skill ===
p1="${CYN}[${model_short}]${R}"
p2="${BLU}📁 ${dir_name}${R}"
[ -n "$git_branch" ] && p3="${YEL}branch: ${git_branch}${R}" || p3="${GRY}branch: --${R}"
[ -n "$agent" ]      && p4="${MAG}agente: @${agent}${R}"      || p4="${GRY}agente: --${R}"
[ -n "$skill" ]      && p5="${MAG}skill: /${skill}${R}"        || p5="${GRY}skill: --${R}"

# === LINE 2: context │ rate limit ===
q1="${GRY}contexto${R} ${CTX_C}${ctx_bar} ${ctx_disp}${R}"
q2="${GRY}limite de uso${R}  ${FIVE_C}${five_bar} ${five_disp}${R}${GRY}${reset_str}${R}"

printf '%s\n' "${p1}${S}${p2}${S}${p3}${S}${p4}${S}${p5}"
printf '%s\n' "   ${q1}${S}${q2}"
