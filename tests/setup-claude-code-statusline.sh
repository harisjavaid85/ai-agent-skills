#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
STATUSLINE="$REPO/skills/productivity/setup-claude-code/scripts/statusline.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/work/myrepo/skills/deep/er" "$FAKE_HOME/Downloads/stuff"
git -C "$FAKE_HOME/work/myrepo" init -q -b main

USER_HOST="$(whoami)@$(hostname -s)"

pass_count=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  pass_count=$((pass_count + 1))
  echo "ok $pass_count - $1"
}

# Renders a payload whose cwd is $1; extra jq filter $2 edits the default payload.
# COLUMNS comes from the caller's environment (unset unless a test sets it).
render_raw() {
  local cwd="$1" edit="${2:-.}" now
  now=$(date +%s)
  jq -n --arg cwd "$cwd" --argjson reset "$((now + 7770))" '{
    cwd: $cwd,
    workspace: {current_dir: $cwd},
    model: {display_name: "Opus 5.5"},
    effort: {level: "medium"},
    context_window: {
      context_window_size: 200000,
      used_percentage: 42,
      current_usage: {input_tokens: 4000, cache_creation_input_tokens: 10000, cache_read_input_tokens: 70000}
    },
    rate_limits: {five_hour: {used_percentage: 23, resets_at: $reset}}
  }' | jq "$edit" | HOME="$FAKE_HOME" bash "$STATUSLINE"
}

render() {
  render_raw "$@" | sed $'s/\033\\[[0-9;]*m//g'
}

assert_line() {
  local name="$1" expected="$2" actual="$3"
  [ "$actual" = "$expected" ] || fail "$name
expected: $expected
actual:   $actual"
  pass "$name"
}

assert_line "full line inside a repo" \
  "$USER_HOST | ~/../myrepo (main) | Opus 5.5 (medium) | 84k/200k (42%) | 2h50m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo")"

# Path: only the repo (or current) folder name, with ~/.. or /.. when folders are elided.
LINE_END="Opus 5.5 (medium) | 84k/200k (42%) | 2h50m/5h (23%)"
assert_line "deep inside a repo shows the repo name" \
  "$USER_HOST | ~/../myrepo (main) | $LINE_END" \
  "$(render "$FAKE_HOME/work/myrepo/skills/deep/er")"
assert_line "folder outside a repo" \
  "$USER_HOST | ~/../stuff | $LINE_END" \
  "$(render "$FAKE_HOME/Downloads/stuff")"
assert_line "direct child of home" \
  "$USER_HOST | ~/Downloads | $LINE_END" \
  "$(render "$FAKE_HOME/Downloads")"
assert_line "home itself" \
  "$USER_HOST | ~ | $LINE_END" \
  "$(render "$FAKE_HOME")"
assert_line "direct child of root" \
  "$USER_HOST | /tmp | $LINE_END" \
  "$(render /tmp)"
assert_line "deep outside home" \
  "$USER_HOST | /../$(basename "$TMP") | $LINE_END" \
  "$(render "$TMP")"
mkdir -p "$TMP/elsewhere/proj"
ln -s "$TMP/elsewhere" "$FAKE_HOME/linked"
assert_line "path under a symlink in home goes through the symlink" \
  "$USER_HOST | ~/../proj | $LINE_END" \
  "$(render "$TMP/elsewhere/proj")"
mkdir -p "$TMP/elsewhere2"
assert_line "a sibling sharing the symlink target prefix is not matched" \
  "$USER_HOST | /../elsewhere2 | $LINE_END" \
  "$(render "$TMP/elsewhere2")"

# Branch: detached HEAD falls back to the short commit.
git -C "$FAKE_HOME/work/myrepo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
sha=$(git -C "$FAKE_HOME/work/myrepo" rev-parse --short HEAD)
git -C "$FAKE_HOME/work/myrepo" checkout -q --detach
assert_line "detached HEAD shows the short commit" \
  "$USER_HOST | ~/../myrepo ($sha) | $LINE_END" \
  "$(render "$FAKE_HOME/work/myrepo")"
git -C "$FAKE_HOME/work/myrepo" checkout -q main

LINE_START="$USER_HOST | ~/../myrepo (main)"

# Model and effort.
assert_line "no effort shows the model alone" \
  "$LINE_START | Opus 5.5 | 84k/200k (42%) | 2h50m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" 'del(.effort)')"

# Context formatting and fallbacks.
assert_line "1M window with millions" \
  "$LINE_START | Opus 5.5 (medium) | 1.2M/1M (100%) | 2h50m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.context_window = {context_window_size: 1000000, used_percentage: 100, current_usage: {input_tokens: 1250000}}')"
assert_line "null current_usage derives tokens from the percentage" \
  "$LINE_START | Opus 5.5 (medium) | 84k/200k (42%) | 2h50m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.context_window.current_usage = null')"
assert_line "derived tokens use the unrounded percentage" \
  "$LINE_START | Opus 5.5 (medium) | 85k/200k (43%) | 2h50m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.context_window.current_usage = null | .context_window.used_percentage = 42.6')"
assert_line "a zero window size hides the context" \
  "$LINE_START | Opus 5.5 (medium) | 2h50m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.context_window.context_window_size = 0 | .context_window.used_percentage = null')"
assert_line "null percentage is computed from tokens" \
  "$LINE_START | Opus 5.5 (medium) | 84k/200k (42%) | 2h50m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.context_window.used_percentage = null')"
assert_line "no usage data hides the context" \
  "$LINE_START | Opus 5.5 (medium) | 2h50m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.context_window.used_percentage = null | .context_window.current_usage = null')"

# 5h limit.
assert_line "no rate limits hides the 5h segment" \
  "$LINE_START | Opus 5.5 (medium) | 84k/200k (42%)" \
  "$(render "$FAKE_HOME/work/myrepo" 'del(.rate_limits)')"
assert_line "no reset time shows the window without elapsed time" \
  "$LINE_START | Opus 5.5 (medium) | 84k/200k (42%) | 5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" 'del(.rate_limits.five_hour.resets_at)')"
assert_line "ISO reset time under an hour" \
  "$LINE_START | Opus 5.5 (medium) | 84k/200k (42%) | 4h15m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.rate_limits.five_hour.resets_at = (now + 2670 | todate | sub("Z$"; ".000Z"))')"
assert_line "ISO reset time with a UTC offset" \
  "$LINE_START | Opus 5.5 (medium) | 84k/200k (42%) | 4h15m/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.rate_limits.five_hour.resets_at = (now + 2670 + 7200 | todate | sub("Z$"; "+02:00"))')"
assert_line "past reset time shows the full window" \
  "$LINE_START | Opus 5.5 (medium) | 84k/200k (42%) | 5h/5h (23%)" \
  "$(render "$FAKE_HOME/work/myrepo" '.rate_limits.five_hour.resets_at = 1000')"

# Colors.
GREEN=$'\033[38;2;149;255;164m'
YELLOW=$'\033[38;2;255;233;170m'
RED=$'\033[38;2;255;85;85m'

assert_color() {
  local name="$1" color="$2" text="$3" edit="$4"
  render_raw "$FAKE_HOME/work/myrepo" "$edit" | grep -qF "${color}${text}" \
    || fail "$name: expected '$text' in that color"
  pass "$name"
}

ctx_filter() {
  printf '.context_window = {context_window_size: %s, used_percentage: %s, current_usage: {input_tokens: %s}}' "$1" "$2" "$3"
}
assert_color "context under 200k is green" "$GREEN" "150k/200k" "$(ctx_filter 200000 75 150000)"
assert_color "context at 80% full is red" "$RED" "170k/200k" "$(ctx_filter 200000 85 170000)"
assert_color "context from 200k to 500k is yellow" "$YELLOW" "300k/1M" "$(ctx_filter 1000000 30 300000)"
assert_color "context above 500k is red" "$RED" "600k/1M" "$(ctx_filter 1000000 60 600000)"
assert_color "5h at 23% used is green" "$GREEN" "2h50m/5h (23%)" '.'
assert_color "5h at 65% used is yellow" "$YELLOW" "2h50m/5h (65%)" '.rate_limits.five_hour.used_percentage = 65'
assert_color "5h at 90% used is red" "$RED" "2h50m/5h (90%)" '.rate_limits.five_hour.used_percentage = 90'

# Wrapping: never drops segments, breaks at a boundary only when COLUMNS is too narrow.
wrapped=$(COLUMNS=60 render "$FAKE_HOME/work/myrepo")
[ "$(printf '%s\n' "$wrapped" | wc -l)" -ge 2 ] || fail "COLUMNS=60 should wrap: $wrapped"
assert_line "wrapped lines carry every segment in order" \
  "$USER_HOST | ~/../myrepo (main) | Opus 5.5 (medium) | 84k/200k (42%) | 2h50m/5h (23%)" \
  "$(printf '%s\n' "$wrapped" | awk 'NR > 1 { printf " | " } { printf "%s", $0 }')"
while IFS= read -r l; do
  [ "${#l}" -le 56 ] || fail "wrapped line reaches the right margin: $l"
  [[ "$l" != " | "* ]] || fail "wrapped line starts with a separator: $l"
done <<< "$wrapped"
pass "wrapped lines stay clear of the right margin"
assert_line "wide COLUMNS keeps one line" \
  "$USER_HOST | ~/../myrepo (main) | $LINE_END" \
  "$(COLUMNS=300 render "$FAKE_HOME/work/myrepo")"

# Inside tmux, the pane width wins over COLUMNS (which holds the whole window width).
mkdir -p "$TMP/faketmux"
printf '#!/usr/bin/env bash\necho 70\n' > "$TMP/faketmux/tmux"
chmod +x "$TMP/faketmux/tmux"
pane_wrapped=$(COLUMNS=300 TMUX_PANE=%1 PATH="$TMP/faketmux:$PATH" render "$FAKE_HOME/work/myrepo")
[ "$(printf '%s\n' "$pane_wrapped" | wc -l)" -ge 2 ] || fail "a 70-column tmux pane should wrap: $pane_wrapped"
pass "a narrow tmux pane wraps even when COLUMNS is wide"

# Without jq the script prints an install hint instead of a broken line.
mkdir -p "$TMP/nojq"
for tool in bash cat; do ln -s "$(command -v "$tool")" "$TMP/nojq/$tool"; done
out=$(echo '{}' | PATH="$TMP/nojq" bash "$STATUSLINE")
[[ "$out" == *"statusline needs jq"* ]] || fail "missing jq should print a hint: $out"
pass "missing jq prints an install hint"

echo "all $pass_count passed"
