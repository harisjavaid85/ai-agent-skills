#!/bin/bash
# Installed by setup-claude-code. Overwritten on each skill re-run; edit the source in
# the skill's scripts/ folder, not the installed copy at ~/.claude/hooks/.
# Blocks dangerous Bash commands at PreToolUse time. Exits 2 to deny.

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  # Fallback when jq isn't installed: extract .tool_input.command with sed.
  # Handles escaped quotes inside the JSON string.
  COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' | sed 's/\\"/"/g; s/\\\\/\\/g')
fi
[ -z "$COMMAND" ] && exit 0

# git destructive ops (push to main/master is blocked; other branches allowed)
GIT_PATTERNS=(
  '(^|[;&|"'"'"'[:space:]])git[[:space:]]+reset[[:space:]]+(--[[:alnum:]-]+[[:space:]]+)*--hard\b'
  '(^|[;&|"'"'"'[:space:]])git[[:space:]]+clean[[:space:]]+(-[[:alnum:]]*f|--force)\b'
  '(^|[;&|"'"'"'[:space:]])git[[:space:]]+branch[[:space:]]+(-[[:alnum:]]*D|--delete[[:space:]]+--force)\b'
  '(^|[;&|"'"'"'[:space:]])git[[:space:]]+(checkout|restore)[[:space:]]+\.'
  '(^|[;&|"'"'"'[:space:]])git[[:space:]]+push.*--force\b'
  '(^|[;&|"'"'"'[:space:]])git[[:space:]]+push.*-f\b'
)

# git push to main/master (other branches allowed)
GIT_PUSH_MAIN_PATTERNS=(
  '(^|[;&|"'"'"'[:space:]])git[[:space:]]+push([[:space:]]+[^[:space:]]+)*[[:space:]]+(main|master)([[:space:]]|$)'
  '(^|[;&|"'"'"'[:space:]])git[[:space:]]+push[[:space:]]+origin[[:space:]]+HEAD:(main|master)\b'
)

# rm -rf detection (used by check_rm_smart, not check_group).
RM_DETECT_PATTERNS=(
  '(^|[;&|"'"'"'[:space:]])rm[[:space:]]+(-[[:alnum:]]*r[[:alnum:]]*f|-[[:alnum:]]*f[[:alnum:]]*r|-r[[:space:]]+-f|-f[[:space:]]+-r|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)\b'
)

# find . -delete
FIND_PATTERNS=(
  '(^|[;&|"'"'"'[:space:]])find[[:space:]]+.*-delete\b'
)

# gh: destructive or identity-mutating operations. Read-only `gh auth status` / `gh auth token`
# are deliberately not matched.
GH_PATTERNS=(
  # auth mutations (swap/refresh/clear the active token)
  '(^|[;&|"'"'"'[:space:]])gh[[:space:]]+auth[[:space:]]+(login|logout|refresh|switch|setup-git)\b'
  # PR approvals; the flag can appear anywhere after `pr review`
  '(^|[;&|"'"'"'[:space:]])gh[[:space:]]+pr[[:space:]]+review([[:space:]]+[^[:space:]]+)*[[:space:]]+(--approve|-a)\b'
  # gh api REST mutating verbs in all three flag forms (-X POST, -XPOST, --method=POST).
  '(^|[;&|"'"'"'[:space:]])gh[[:space:]]+api([[:space:]]+[^[:space:]]+)*[[:space:]]+(-X|--method)[[:space:]]+(POST|PUT|PATCH|DELETE)\b'
  '(^|[;&|"'"'"'[:space:]])gh[[:space:]]+api([[:space:]]+[^[:space:]]+)*[[:space:]]+-X(POST|PUT|PATCH|DELETE)\b'
  '(^|[;&|"'"'"'[:space:]])gh[[:space:]]+api([[:space:]]+[^[:space:]]+)*[[:space:]]+--method=(POST|PUT|PATCH|DELETE)\b'
)

block() {
  local pattern="$1"
  echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
  exit 2
}

# Run all pattern groups against the raw command AND against anything wrapped in `bash -c "..."` or `sh -c '...'`.
# Extract any quoted argument following bash/sh -c so wrappers can't bypass.
EXTRACTED=$(echo "$COMMAND" | grep -oE "(bash|sh)[[:space:]]+-c[[:space:]]+['\"][^'\"]*['\"]" || true)
HAYSTACK="$COMMAND
$EXTRACTED"

check_group() {
  local -n patterns=$1
  for pattern in "${patterns[@]}"; do
    if echo "$HAYSTACK" | grep -qE "$pattern"; then
      block "$pattern"
    fi
  done
}

# Smart rm -rf: when rm -rf is detected, inspect each positional target.
# Allow when every target is a plain relative path under cwd; block escapes.
# Unsafe targets: absolute (/...), home (~ or ~/...), parent (.., ../...),
# anything traversing via .. mid-path (foo/../bar), cwd literal (.), bare glob (*).
rm_target_unsafe() {
  case "$1" in
    /*) return 0 ;;
    '~'|'~/'*) return 0 ;;
    '..'|'../'*) return 0 ;;
    *'/..') return 0 ;;
    *'/../'*) return 0 ;;
    '.') return 0 ;;
    '*') return 0 ;;
    *) return 1 ;;
  esac
}

check_rm_smart() {
  # Split haystack into command segments on ; & | so each rm invocation is isolated.
  local segments
  segments=$(echo "$HAYSTACK" | tr ';&|' '\n')
  while IFS= read -r seg; do
    [ -z "$seg" ] && continue
    local matched=0
    for pat in "${RM_DETECT_PATTERNS[@]}"; do
      if echo "$seg" | grep -qE "$pat"; then matched=1; break; fi
    done
    [ "$matched" -eq 0 ] && continue
    # Strip everything up to and including the rm keyword, then tokenise the rest.
    local after_rm
    after_rm=$(echo "$seg" | sed -E 's/^.*[^[:alnum:]_]rm[[:space:]]+//; s/^rm[[:space:]]+//')
    local -a words=()
    read -ra words <<< "$after_rm"
    for w in "${words[@]}"; do
      case "$w" in -*) continue ;; esac
      if rm_target_unsafe "$w"; then
        block "rm -rf with target outside cwd: $w"
      fi
    done
  done <<< "$segments"
}

check_group GIT_PATTERNS
check_group GIT_PUSH_MAIN_PATTERNS
check_rm_smart
check_group FIND_PATTERNS
check_group GH_PATTERNS

exit 0
