#!/bin/bash
# Installed by setup-claude-code. Overwritten on each skill re-run — edit the source in
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

# rm -rf and its syntactic variants
RM_PATTERNS=(
  '(^|[;&|"'"'"'[:space:]])rm[[:space:]]+(-[[:alnum:]]*r[[:alnum:]]*f|-[[:alnum:]]*f[[:alnum:]]*r|-r[[:space:]]+-f|-f[[:space:]]+-r|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)\b'
)

# find . -delete
FIND_PATTERNS=(
  '(^|[;&|"'"'"'[:space:]])find[[:space:]]+.*-delete\b'
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

check_group GIT_PATTERNS
check_group GIT_PUSH_MAIN_PATTERNS
check_group RM_PATTERNS
check_group FIND_PATTERNS

exit 0
