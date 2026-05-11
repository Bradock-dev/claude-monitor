#!/usr/bin/env bash
# claude-monitor — statusline script
# https://github.com/BRADOCK-DEV/claude-monitor

input=$(cat)

# --- Detect python ---
PYTHON=""
for _cmd in python python3; do
    _ver=$(command -v "$_cmd" &>/dev/null && "$_cmd" -c "import sys; print(sys.version_info[0])" 2>/dev/null)
    [ "$_ver" = "3" ] && PYTHON="$_cmd" && break
done

# --- Parse JSON ---
json_out=$(echo "$input" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ctx = d.get('context_window', {})
    rl  = d.get('rate_limits', {}).get('five_hour', {})
    print(d.get('cwd', ''))
    print(d.get('model', {}).get('display_name', ''))
    print(str(ctx.get('used_percentage', '')))
    print(str(ctx.get('remaining_percentage', '')))
    print(str(rl.get('used_percentage', '')))
    print(str(rl.get('resets_at', '')))
except:
    for _ in range(6): print('')
" 2>/dev/null)

cwd=$(echo "$json_out"      | sed -n '1p')
model=$(echo "$json_out"    | sed -n '2p')
ctx_used=$(echo "$json_out" | sed -n '3p')
ctx_rem=$(echo "$json_out"  | sed -n '4p')
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

# --- UTF-8 fallback ---
if locale charmap 2>/dev/null | grep -qi 'utf-8\|utf8' || \
   echo "${LANG}${LC_ALL}${LC_CTYPE}" | grep -qi 'utf-8\|utf8'; then
    BF="█" BE="░" PIPE="│" ARROW="↻"
    I_DIR="📁 " I_GIT="🐱 " I_AGT="🤖 " I_SKL="⚡ "
else
    BF="#" BE="-" PIPE="|" ARROW="~"
    I_DIR="dir:" I_GIT="git:" I_AGT="bot:" I_SKL="sk:"
fi

# --- Progress bar ---
make_bar() {
    local pct=${1:-0} width=${2:-10} filled empty bar=""
    filled=$(( pct * width / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    empty=$(( width - filled ))
    for ((i=0; i<filled; i++)); do bar="${bar}${BF}"; done
    for ((i=0; i<empty; i++)); do bar="${bar}${BE}"; done
    printf '%s' "$bar"
}

# 0-33% green · 34-66% yellow · 67-100% red
usage_color() { local p=${1:-0}; [ "$p" -ge 67 ] && printf '%s' "$RED" || { [ "$p" -ge 34 ] && printf '%s' "$YEL" || printf '%s' "$GRN"; }; }

# --- Data ---
dir_name=$(basename "${cwd:-$(pwd)}")
model_short=$(echo "${model:-?}" | sed 's/Claude //')
git_branch=$(git -C "${cwd:-.}" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)

STATE_DIR="$HOME/.claude"
agent=$([ -f "$STATE_DIR/.agent-state" ] && tr -d '[:space:]' < "$STATE_DIR/.agent-state" 2>/dev/null || echo "")
skill=$([ -f "$STATE_DIR/.skill-state" ]  && tr -d '[:space:]' < "$STATE_DIR/.skill-state"  2>/dev/null || echo "")

# --- Context window (used %) ---
ctx_int=0; ctx_disp="?"
if [ -n "$ctx_used" ]; then
    ctx_int=$(printf '%.0f' "$ctx_used"); ctx_disp="${ctx_int}%"
elif [ -n "$ctx_rem" ]; then
    r=$(printf '%.0f' "$ctx_rem"); ctx_int=$(( 100 - r )); ctx_disp="${ctx_int}%"
fi
CTX_C=$(usage_color "$ctx_int")
ctx_bar=$(make_bar "$ctx_int" 10)

# --- Compaction detection ---
# When used% drops 15+ points between turns, the window was compacted.
PREV_CTX_FILE="$STATE_DIR/.ctx-prev"
COMPACT_FILE="$STATE_DIR/.compaction-count"

prev_ctx=0; compact_n=0
[ -f "$PREV_CTX_FILE" ] && prev_ctx=$(tr -d '[:space:]' < "$PREV_CTX_FILE" 2>/dev/null); [ -z "$prev_ctx" ] && prev_ctx=0
[ -f "$COMPACT_FILE"  ] && compact_n=$(tr -d '[:space:]' < "$COMPACT_FILE"  2>/dev/null); [ -z "$compact_n" ] && compact_n=0

if [ "$prev_ctx" -gt 0 ] && [ "$ctx_int" -gt 0 ]; then
    drop=$(( prev_ctx - ctx_int ))
    if [ "$drop" -ge 15 ]; then
        compact_n=$(( compact_n + 1 ))
        echo "$compact_n" > "$COMPACT_FILE"
    fi
fi
[ "$ctx_int" -gt 0 ] && echo "$ctx_int" > "$PREV_CTX_FILE"

# --- 5h rate limit ---
five_int=0; five_disp="?"; reset_str=""
if [ -n "$five_pct" ]; then
    five_int=$(printf '%.0f' "$five_pct"); five_disp="${five_int}%"
    if [ -n "$five_rst" ]; then
        now=$(date +%s); diff=$(( five_rst - now ))
        if [ "$diff" -gt 0 ]; then
            m=$(( diff / 60 )); h=$(( m / 60 )); m=$(( m % 60 )); s=$(( diff % 60 ))
            [ "$h" -gt 0 ] && reset_str=" ${ARROW} ${h}h${m}m" || reset_str=" ${ARROW} ${m}m${s}s"
        fi
    fi
fi
FIVE_C=$(usage_color "$five_int")
five_bar=$(make_bar "$five_int" 10)

# --- Separator ---
S="${GRY} ${PIPE} ${R}"

# === LINE 1: model | dir | branch | agent | skill ===
p1="${CYN}[${model_short}]${R}"
p2="${BLU}${I_DIR}${dir_name}${R}"
[ -n "$git_branch" ] && p3="${YEL}${I_GIT}${git_branch}${R}" || p3="${GRY}${I_GIT}--${R}"
[ -n "$agent" ]      && p4="${MAG}${I_AGT}@${agent}${R}"     || p4="${GRY}${I_AGT}--${R}"
[ -n "$skill" ]      && p5="${MAG}${I_SKL}/${skill}${R}"      || p5="${GRY}${I_SKL}--${R}"

# === LINE 2: context | compact | rate limit ===
q1="${GRY}contexto${R} ${CTX_C}${ctx_bar} ${ctx_disp}${R}"
q2="${GRY}limite de uso${R}  ${FIVE_C}${five_bar} ${five_disp}${R}${GRY}${reset_str}${R}"
[ "$compact_n" -gt 0 ] && q3="${YEL}compact: ${compact_n}x${R}" || q3="${GRY}compact: 0${R}"

printf '%s\n' "${p1}${S}${p2}${S}${p3}${S}${p4}${S}${p5}"
printf '%s\n' "   ${q1}${S}${q3}${S}${q2}"
