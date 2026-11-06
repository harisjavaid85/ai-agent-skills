#!/usr/bin/env bash
# Installed by setup-claude-code. Overwritten on each skill re-run; edit the source in
# the skill's scripts/ folder, not the installed copy at ~/.claude/statusline.sh.
# Claude Code status line: user@host | path (branch) | model (effort) | context used | 5h window used

# Segments in display order: reorder or remove entries to change the line.
SEGMENTS=(user_host repo model context limit_5h)

# Context is yellow from CTX_YELLOW_TOKENS, red above CTX_RED_TOKENS or at CTX_RED_PCT full.
CTX_YELLOW_TOKENS=200000
CTX_RED_TOKENS=500000
CTX_RED_PCT=80
# The 5h limit is yellow from LIMIT_YELLOW_PCT used, red from LIMIT_RED_PCT used.
LIMIT_YELLOW_PCT=50
LIMIT_RED_PCT=80
LIMIT_WINDOW_SECS=18000
# Columns Claude Code keeps for itself at the right edge; lines wrap before reaching them.
WIDTH_MARGIN=4

RESET=$'\033[0m'
DIM=$'\033[2m'
C_USER=$'\033[38;2;255;255;255m'
C_REPO=$'\033[38;2;135;206;250m'
C_MODEL=$'\033[38;2;203;166;247m'
C_OK=$'\033[38;2;149;255;164m'
C_WARN=$'\033[38;2;255;233;170m'
C_HIGH=$'\033[38;2;255;85;85m'
SEP=" ${DIM}|${RESET} "

shopt -s extglob

if ! command -v jq >/dev/null 2>&1; then
  printf "\033[1;31m⚠ statusline needs jq; run in terminal: sudo apt-get install -y jq\033[0m\n"
  exit 0
fi

# One jq call extracts every field, joined by the unit separator so empty fields survive `read`.
IFS=$'\x1f' read -r cwd model effort ctx_used ctx_size ctx_pct limit_pct limit_secs < <(
  jq -r '
    def iso_or_epoch: if type == "number" then (if . > 1e12 then . / 1000 else . end)
      elif type == "string" then (try (sub("\\.[0-9]+"; "")
        | if test("[+-][0-9]{2}:[0-9]{2}$")
          then (.[0:19] + "Z" | fromdateiso8601)
            - (if .[19:20] == "+" then 1 else -1 end) * ((.[20:22] | tonumber) * 3600 + (.[23:25] | tonumber) * 60)
          else fromdateiso8601 end) catch null)
      else null end;
    (.context_window.context_window_size | if . == 0 then null else . end) as $size
    | .context_window.used_percentage as $pct
    | (.context_window.current_usage
        | if . then (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
          elif $pct != null and $size != null then $pct * $size / 100 | floor
          else null end) as $used
    | [
      (.workspace.current_dir // .cwd),
      .model.display_name,
      .effort.level,
      $used,
      $size,
      (if $pct != null then $pct | round elif $used != null and $size != null then $used * 100 / $size | round else null end),
      (.rate_limits.five_hour.used_percentage | if . == null then null else round end),
      (.rate_limits.five_hour.resets_at | iso_or_epoch | if . == null then null else . - now | floor end)
    ] | map(. // "" | tostring) | join("\u001f")'
)
[ -z "$cwd" ] && cwd=$(pwd)

# 84321 -> 84k, 1000000 -> 1M, 1200000 -> 1.2M
fmt_tokens() {
  local n=$1 tenths
  if (( n < 1000 )); then
    printf '%d' "$n"
  elif (( n < 1000000 )); then
    printf '%dk' $(( n / 1000 ))
  else
    tenths=$(( n / 100000 ))
    if (( tenths % 10 == 0 )); then
      printf '%dM' $(( tenths / 10 ))
    else
      printf '%d.%dM' $(( tenths / 10 )) $(( tenths % 10 ))
    fi
  fi
}

# 7830 -> 2h10m, 18000 -> 5h, 2700 -> 45m, anything under a minute -> 0m
fmt_duration() {
  local s=$1
  if (( s >= 3600 && s % 3600 / 60 == 0 )); then
    printf '%dh' $(( s / 3600 ))
  elif (( s >= 3600 )); then
    printf '%dh%dm' $(( s / 3600 )) $(( s % 3600 / 60 ))
  else
    printf '%dm' $(( s / 60 ))
  fi
}

# Folder name, prefixed with ~/.. or /.. when folders between it and ~ or / are elided.
# A path under a symlink that sits directly in $HOME is shown through that symlink.
short_path() {
  local p=$1 rel="" prefix link target
  [ "$p" = "$HOME" ] && { printf '~'; return; }
  [ "$p" = "/" ] && { printf '/'; return; }
  if [[ "$p" == "$HOME"/* ]]; then
    rel=${p#"$HOME"/}
  else
    while IFS= read -r link; do
      target=$(realpath "$link" 2>/dev/null) || continue
      [[ "$target" == "$HOME" || "$target" == "$HOME"/* ]] && continue
      if [[ "$p" == "$target" || "$p" == "$target"/* ]]; then
        rel="${link#"$HOME"/}${p#"$target"}"
        break
      fi
    done < <(find "$HOME" -maxdepth 1 -type l 2>/dev/null)
  fi
  if [ -n "$rel" ]; then prefix="~/"; else prefix="/"; rel=${p#/}; fi
  if [[ "$rel" == */* ]]; then
    printf '%s../%s' "$prefix" "${rel##*/}"
  else
    printf '%s%s' "$prefix" "$rel"
  fi
}

seg_user_host() {
  printf '%s' "${C_USER}$(whoami)@$(hostname -s)${RESET}"
}

visible_width() {
  local plain=${1//$'\033['*([0-9;])m/}
  printf '%d' "${#plain}"
}

git_cwd() {
  git -C "$cwd" --no-optional-locks "$@" 2>/dev/null
}

# Repo folder (or cwd outside a repo), then the branch in parentheses; detached HEAD shows the short commit.
seg_repo() {
  local dir b=""
  if dir=$(git_cwd rev-parse --show-toplevel); then
    b=$(git_cwd branch --show-current)
    [ -z "$b" ] && b=$(git_cwd rev-parse --short HEAD)
  else
    dir=$cwd
  fi
  printf '%s' "${C_REPO}$(short_path "$dir")${b:+ (${b})}${RESET}"
}

seg_model() {
  [ -z "$model" ] && return 0
  printf '%s' "${C_MODEL}${model}${effort:+ (${effort})}${RESET}"
}

seg_context() {
  local used=$ctx_used pct=$ctx_pct color=$C_OK
  [ -z "$ctx_size" ] || [ -z "$used" ] && return 0
  if (( used > CTX_RED_TOKENS || pct >= CTX_RED_PCT )); then
    color=$C_HIGH
  elif (( used >= CTX_YELLOW_TOKENS )); then
    color=$C_WARN
  fi
  printf '%s' "${color}$(fmt_tokens "$used")/$(fmt_tokens "$ctx_size") (${pct}%)${RESET}"
}

# Time into the 5h window and quota used: 2h50m/5h (23%). Without a reset time: 5h (23%).
seg_limit_5h() {
  local color=$C_OK elapsed text="5h"
  [ -z "$limit_pct" ] && return 0
  if (( limit_pct >= LIMIT_RED_PCT )); then
    color=$C_HIGH
  elif (( limit_pct >= LIMIT_YELLOW_PCT )); then
    color=$C_WARN
  fi
  if [ -n "$limit_secs" ]; then
    elapsed=$(( LIMIT_WINDOW_SECS - limit_secs ))
    (( elapsed < 0 )) && elapsed=0
    (( elapsed > LIMIT_WINDOW_SECS )) && elapsed=$LIMIT_WINDOW_SECS
    text="$(fmt_duration "$elapsed")/5h"
  fi
  printf '%s' "${color}${text} (${limit_pct}%)${RESET}"
}

# Join segments with SEP, starting a new line at a segment boundary when the next one
# would overflow the available width. Without a known width everything stays on one line.
# Inside tmux, COLUMNS holds the window width, so a split pane reports its own.
max_width=""
[[ "${COLUMNS:-}" =~ ^[0-9]+$ ]] && max_width=$COLUMNS
if [ -n "${TMUX_PANE:-}" ]; then
  pane_width=$(tmux display -p -t "$TMUX_PANE" '#{pane_width}' 2>/dev/null)
  [[ "$pane_width" =~ ^[0-9]+$ ]] && { [ -z "$max_width" ] || (( pane_width < max_width )); } && max_width=$pane_width
fi
[ -n "$max_width" ] && max_width=$(( max_width - WIDTH_MARGIN ))
SEP_WIDTH=$(visible_width "$SEP")
line="" width=0
for name in "${SEGMENTS[@]}"; do
  seg=$("seg_$name")
  [ -z "$seg" ] && continue
  seg_width=$(visible_width "$seg")
  if [ -n "$line" ] && ! { [ -n "$max_width" ] && (( width + SEP_WIDTH + seg_width > max_width )); }; then
    line+="${SEP}${seg}" width=$(( width + SEP_WIDTH + seg_width ))
    continue
  fi
  [ -n "$line" ] && printf '%s\n' "$line"
  line=$seg width=$seg_width
done
[ -n "$line" ] && printf '%s\n' "$line"
