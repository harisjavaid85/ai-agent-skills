#!/usr/bin/env bash
# Installed by setup-claude-code. Overwritten on each skill re-run — edit the source in
# the skill's scripts/ folder, not the installed copy at ~/.claude/hooks/.
# Claude Code status line - oh-my-posh agnoster style
# Segments: user@host | cwd | git branch | model | context %

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  printf "\033[1;31m⚠ statusline needs jq — run in terminal: sudo apt-get install -y jq\033[0m\n"
  exit 0
fi

# Colors matching agnoster theme palette
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Foreground colors
FG_DARK="\033[38;2;16;14;35m"        # #100e23
FG_WHITE="\033[38;2;255;255;255m"    # #ffffff
FG_NAVY="\033[38;2;25;53;73m"        # #193549

# Background colors (used as fg in dim terminal context)
C_SESSION="\033[38;2;255;255;255m" # #ffffff - session segment
C_PATH="\033[38;2;145;221;255m"    # #91ddff - path segment
C_GIT="\033[38;2;149;255;164m"     # #95ffa4 - git segment
C_PYTHON="\033[38;2;144;108;255m"  # #906cff - python/model segment
C_CTX="\033[38;2;255;233;170m"     # #ffe9aa - context segment

SEP=" ${DIM}|${RESET} "

# --- Segment 1: user@host (session) ---
user=$(whoami)
host=$(hostname -s)
seg_session="${BOLD}${C_SESSION}${user}@${host}${RESET}"

# --- Segment 2: current working directory ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd=$(pwd)

# Shorten home directory to ~ (handles symlink-expanded paths under $HOME)
if [[ "$cwd" == "$HOME"* ]]; then
    cwd_display="~${cwd#$HOME}"
else
    # Check if cwd starts with the resolved target of any symlink directly under $HOME
    cwd_display="$cwd"
    while IFS= read -r _link; do
        _target=$(realpath "$_link" 2>/dev/null) || continue
        [[ "$_target" == "$HOME"* ]] && continue # points back inside HOME, skip
        if [[ "$cwd" == "$_target"* ]]; then
            _rel="${_link#$HOME}${cwd#$_target}"
            cwd_display="~${_rel}"
            break
        fi
    done < <(find "$HOME" -maxdepth 1 -type l 2>/dev/null)
fi

# Shorten to: first2/../second_to_last/last (only when 5+ segments)
IFS='/' read -ra _parts <<< "${cwd_display#/}"
_n="${#_parts[@]}"
if (( _n > 4 )); then
    if [[ "$cwd_display" == /* ]]; then
        _first2="/${_parts[0]}/${_parts[1]}"
    else
        _first2="${_parts[0]}/${_parts[1]}"
    fi
    _last2="${_parts[$((_n-2))]}/${_parts[$((_n-1))]}"
    cwd_display="${_first2}/../${_last2}"
fi
seg_path="${C_PATH}${cwd_display}${RESET}"

# --- Segment 3: git branch ---
git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
if [ -n "$git_branch" ]; then
    seg_git="${C_GIT} ${git_branch}${RESET}"
else
    seg_git=""
fi

# --- Segment 4: model ---
model=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$model" ]; then
    seg_model="${C_PYTHON}${model}${RESET}"
else
    seg_model=""
fi

# --- Segment 5: context window usage ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
    used_int=${used_pct%.*}
    if [ "$used_int" -ge 80 ] 2>/dev/null; then
        ctx_color="\033[38;2;255;128;128m" # red-ish when high
    else
        ctx_color="${C_CTX}"
    fi
    seg_ctx="${ctx_color}Ctx: ${used_pct}%${RESET}"
else
    seg_ctx=""
fi

# --- Assemble line ---
line="${seg_session}${SEP}${seg_path}"
[ -n "$seg_git" ] && line="${line}${SEP}${seg_git}"
[ -n "$seg_model" ] && line="${line}${SEP}${seg_model}"
[ -n "$seg_ctx" ] && line="${line}${SEP}${seg_ctx}"

printf "%b\n" "$line"
