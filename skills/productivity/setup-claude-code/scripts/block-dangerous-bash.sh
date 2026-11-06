#!/bin/bash
# Installed by setup-claude-code. Overwritten on each skill re-run; edit the source in
# the skill's scripts/ folder, not the installed copy at ~/.claude/hooks/.
# Blocks dangerous Bash commands at PreToolUse time. Exits 2 to deny.
#
# The goal is catching destructive commands as agents commonly write them, so an agent
# gets the BLOCKED message and stops there. It is not meant to stop deliberate evasion.
# All matching uses bash's built-in [[ =~ ]], so the only processes started are jq and,
# for a plain `git push`, one git call.

INPUT=$(cat)
CWD=""
if command -v jq >/dev/null 2>&1; then
  # First line: the session's cwd; the rest: the command (which may span lines).
  PARSED=$(jq -r '(.cwd // ""), (.tool_input.command // "")' <<< "$INPUT")
  CWD="${PARSED%%$'\n'*}"
  COMMAND="${PARSED#*$'\n'}"
else
  # Fallback when jq isn't installed: extract .tool_input.command with sed.
  # Handles escaped quotes inside the JSON string.
  COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' | sed 's/\\"/"/g; s/\\\\/\\/g')
fi
[ -z "$COMMAND" ] && exit 0
CWD="${CWD:-$PWD}"
CWD="${CWD%/}"

# block <pattern> [recommendation]: the recommendation, when given, follows the refusal.
block() {
  echo "BLOCKED: '$COMMAND' matches dangerous pattern '$1'. The user has prevented you from doing this.${2:+ $2}" >&2
  exit 2
}

# Start of a command word: string start, a separator, a quote, or whitespace.
S='(^|[;&|"'"'"'[:space:]])'
# End of a word (portable stand-in for \b).
E='([^[:alnum:]_-]|$)'
# One argument: "double-quoted", 'single-quoted', or a plain word.
ARG='("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)'
# `git` plus any -C <path> / -c <key=value> global options, up to the subcommand.
G="${S}git([[:space:]]+(-C|-c)[[:space:]]+${ARG})*[[:space:]]+"

PATTERNS=(
  # git destructive ops
  "${G}reset[^;&|]*[[:space:]]--hard${E}"
  "${G}clean([[:space:]]+[^[:space:]]+)*[[:space:]]+(-[[:alnum:]]*f[[:alnum:]]*|--force)${E}"
  "${G}branch([[:space:]]+[^[:space:]]+)*[[:space:]]+(-[[:alnum:]]*D[[:alnum:]]*|--delete[[:space:]]+--force)${E}"
  # discarding all changes: git checkout ., git restore ., and the -- / <ref> -- forms
  "${G}(checkout|restore)[[:space:]]+(--[[:space:]]+)?\\."
  "${G}checkout[[:space:]]+[^-[:space:]][^[:space:]]*[[:space:]]+--[[:space:]]+\\.([[:space:]]|$)"
  # force pushes; --force-with-lease is checked per command below
  "${G}push[^;&|]*[[:space:]](--force|-f)${E}"
  # skipping client-side hooks: --no-verify on any git command, and commit's short form -n
  "${S}git[[:space:]][^;&|]*--no-verify${E}"
  "${G}commit([[:space:]]+[^[:space:]]+)*[[:space:]]+-[[:alnum:]]*n[[:alnum:]]*${E}"
  # git push to main/master: main, +main, HEAD:main, feature:main, refs/heads/main
  "${G}push([[:space:]]+[^[:space:]]+)*[[:space:]]+([^[:space:]:]*:)?\\+?(refs/heads/)?(main|master)([[:space:]]|$)"
  # find . -delete
  "${S}find[[:space:]][^;&|]*-delete${E}"
  # gh auth mutations (read-only `gh auth status` / `gh auth token` stay allowed)
  "${S}gh[[:space:]]+auth[[:space:]]+(login|logout|refresh|switch|setup-git)${E}"
  # PR approvals; the flag can appear anywhere after `pr review`
  "${S}gh[[:space:]]+pr[[:space:]]+review([[:space:]]+[^[:space:]]+)*[[:space:]]+(--approve|-a)${E}"
  # admin merges, which bypass branch protection and required checks
  "${S}gh[[:space:]]+pr[[:space:]]+merge([[:space:]]+[^[:space:]]+)*[[:space:]]+--admin${E}"
  # gh api REST writes with an explicit method: -X POST, -XPOST, --method POST, --method=POST
  "${S}gh[[:space:]]+api[^;&|]*[[:space:]](-X[[:space:]]*|--method[[:space:]=])[\"']?(POST|PUT|PATCH|DELETE)${E}"
)

# Join backslash-newline continuations so a command split over lines is checked whole.
JOINED="${COMMAND//$'\\\n'/ }"

# The one gh REST write allowed through: editing a single issue or PR comment in place
# (`gh api -X PATCH repos/<o>/<r>/issues/comments/<id> -F body=@<file>`). It must be the
# whole command, optionally after one `cd <dir> &&` (gh picks its account from the repo
# it runs in), with only field arguments and the output-only options --jq/-q,
# --template/-t, --silent. A value may be plain,
# "double-quoted" (no $, backtick, or backslash), or 'single-quoted', with an optional @.
CE_VAL='([[:alnum:]_.@/~:,+=-]+|@?"[^"$`\]*"|@?'"'"'[^'"'"']*'"'"')'
CE_OUT_VAL='([^[:space:];&|$`<>"'"'"']+|"[^"$`\]*"|'"'"'[^'"'"']*'"'"')'
CE_ARG="(-f|-F|--field|--raw-field)[[:space:]]+[[:alnum:]_]+=${CE_VAL}|(--jq|-q|--template|-t)[[:space:]]+${CE_OUT_VAL}|--silent"
CE_CD="(cd[[:space:]]+${CE_OUT_VAL}[[:space:]]*&&[[:space:]]*)?"
COMMENT_EDIT_RE='^[[:space:]]*'"$CE_CD"'gh[[:space:]]+api[[:space:]]+(-X[[:space:]]*PATCH|--method[[:space:]=]PATCH)[[:space:]]+/?repos/[[:alnum:]_.{}-]+/[[:alnum:]_.{}-]+/issues/comments/[0-9]+([[:space:]]+('"$CE_ARG"'))*[[:space:]]*$'
if [[ "$JOINED" != *$'\n'* && "$JOINED" =~ $COMMENT_EDIT_RE ]]; then
  exit 0
fi

# Patterns are matched line by line, so one line's text cannot complete another's match.
while IFS= read -r line; do
  for p in "${PATTERNS[@]}"; do
    [[ "$line" =~ $p ]] && block "$p"
  done
done <<< "$JOINED"

# Per-command checks: split on ; & | and newlines.
SEGMENTS="${JOINED//[;&|]/$'\n'}"

# Field arguments make `gh api` send a POST unless the method is set to GET.
GH_API_RE="${S}gh[[:space:]]+api([[:space:]]|$)"
GH_FIELD_RE='[[:space:]](-[fF]|--field|--raw-field|--input)'
GH_GET_RE='[[:space:]](-X[[:space:]]*|--method[[:space:]=])GET([[:space:]]|$)'

# Recursive rm (-r, -R, --recursive, with or without -f). Each target, resolved against the
# directory the command is in, must lie below the session's cwd or be exactly one level
# under /tmp (/tmp/<name>). `cd` moves that directory; a `cd` the hook cannot follow
# (~, -, a variable) makes every later relative target unsafe. Paths are resolved by
# spelling only: a symlink inside cwd can still lead outside it.
RM_RE="${S}rm[[:space:]]+(.*)$"
RM_RECURSIVE_RE='^-[[:alpha:]]*[rR][[:alpha:]]*$|^--recursive$'
TMP_TARGET_RE='^/tmp/[^/*?[]+$'
CD_RE='^[[:space:](]*cd([[:space:]]+(.*))?$'
FIND_EXEC_RM_RE="${S}find[[:space:]]+(.*)-exec(dir)?[[:space:]]+rm[[:space:]]+([^[:space:]]+[[:space:]]+)*(-[[:alpha:]]*[rR][[:alpha:]]*|--recursive)([[:space:]]|$)"
GIT_PUSH_RE="${S}git(([[:space:]]+(-C|-c)[[:space:]]+${ARG})*)[[:space:]]+push([[:space:]]+(.*))?$"
GIT_C_RE="-C[[:space:]]+${ARG}"
LEASE_RE='^--force-with-lease=([^:]+):[0-9a-fA-F]{7,40}$'
LEASE_HINT="The recommended way is to use: git push --delete with a lease on each deleted branch's expected commit."
CUR="$CWD" # the directory the command is in; empty once it cannot be followed

strip_quotes() {
  local t="${1#[\"\']}"
  printf '%s' "${t%[\"\']}"
}

# Resolve . and .. by spelling: norm_path /a/b/../c -> /a/c
norm_path() {
  local part out=()
  IFS='/' read -ra parts <<< "$1"
  for part in "${parts[@]}"; do
    case "$part" in
      ''|'.') ;;
      '..') [ "${#out[@]}" -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$part") ;;
    esac
  done
  local IFS=/
  printf '/%s' "${out[*]}"
}

# Print the absolute path a word names from the current directory; print nothing when
# the hook cannot tell (variables, substitutions, ~, or a directory it lost track of).
resolve_word() {
  local t
  t=$(strip_quotes "$1")
  case "$t" in
    *'$'*|*'`'*|'~'*) return ;;
  esac
  if [[ "$t" == /* ]]; then norm_path "$t"
  elif [ -n "$CUR" ]; then norm_path "$CUR/$t"
  fi
}

# Exit 0 (unsafe) unless the target lies below cwd or is exactly /tmp/<name>.
rm_target_unsafe() {
  local t abs
  t=$(strip_quotes "$1")
  [ -z "$t" ] && return 1
  [ "$t" = '*' ] && return 0
  abs=$(resolve_word "$1")
  [ -z "$abs" ] && return 0
  [[ "$abs" == "$CWD"/?* ]] && return 1
  # /tmp/<name> only, and without a trailing slash, which would follow a symlink
  [[ "$abs" =~ $TMP_TARGET_RE && "$t" != */ ]] && return 1
  return 0
}

while IFS= read -r seg; do
  if [[ "$seg" =~ $GH_API_RE && "$seg" =~ $GH_FIELD_RE && ! "$seg" =~ $GH_GET_RE ]]; then
    block "gh api with field arguments and no -X GET (an implicit POST)"
  fi

  # cd: follow the directory by spelling, ignoring any redirection after it.
  if [[ "$seg" =~ $CD_RE ]]; then
    d="${BASH_REMATCH[2]}"
    full="$d"
    d="${d%%[<>]*}" # cut at a redirection
    # a separate fd number before the redirection (`cd dir 2>/dev/null`) goes too
    if [ "$d" != "$full" ] && [[ "$d" =~ ^(.*[^[:space:]])[[:space:]]+[0-9]+[[:space:]]*$ ]]; then
      d="${BASH_REMATCH[1]}"
    fi
    [[ "$d" =~ ^[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]] && d="${BASH_REMATCH[1]}"
    d=$(strip_quotes "$d")
    case "$d" in
      ''|'-'|'~'*|*'$'*|*'`'*) CUR="" ;;
      *) CUR=$(resolve_word "$d") ;;
    esac
    continue
  fi

  if [[ "$seg" =~ $GIT_PUSH_RE ]]; then
    globals="${BASH_REMATCH[2]}"
    read -ra pw <<< "${BASH_REMATCH[7]}"
    refs=() leases=() delete=0 skip=0
    for w in "${pw[@]}"; do
      [ "$skip" = 1 ] && { skip=0; continue; }
      w="${w//[\"\']/}"
      case "$w" in
        -o|--push-option|--repo) skip=1 ;;
        --delete|-d) delete=1 ;;
        --force-with-lease*) leases+=("$w") ;;
        -*) ;;
        *) refs+=("$w") ;;
      esac
    done

    # Remote branch deletes (--delete/-d, or a :<branch> refspec) remove whatever the
    # branch points at, so each needs a lease naming the commit it is expected to be at.
    # A lease on anything other than a delete would rewrite the branch.
    deleted=()
    if [ "$delete" = 1 ]; then
      deleted=("${refs[@]:1}")
    else
      for r in "${refs[@]:1}"; do [[ "$r" == :?* ]] && deleted+=("${r#:}"); done
    fi
    if [ "${#deleted[@]}" -gt 0 ]; then
      for r in "${deleted[@]}"; do
        leased=0
        for l in "${leases[@]}"; do
          [[ "$l" =~ $LEASE_RE && "${BASH_REMATCH[1]#refs/heads/}" == "${r#refs/heads/}" ]] && leased=1
        done
        [ "$leased" = 1 ] || block "git push --delete without a lease on $r" "$LEASE_HINT"
      done
    elif [ "${#leases[@]}" -gt 0 ]; then
      block "git push --force-with-lease outside a branch delete"
    fi

    # A plain `git push` (or `git push <remote> [HEAD]`) pushes the current branch.
    if [ "${#refs[@]}" -le 1 ] || [ "${refs[1]}" = HEAD ]; then
      repo="${CUR:-$CWD}"
      [[ "$globals" =~ $GIT_C_RE ]] && repo=$(resolve_word "${BASH_REMATCH[1]}")
      branch=$(git -C "${repo:-$CWD}" symbolic-ref --short -q HEAD 2>/dev/null)
      [[ "$branch" == main || "$branch" == master ]] && block "git push while on $branch"
    fi
  fi

  # find ... -exec rm -r: the folders find starts from are the real targets.
  if [[ "$seg" =~ $FIND_EXEC_RM_RE ]]; then
    read -ra fw <<< "${BASH_REMATCH[2]}"
    for w in "${fw[@]}"; do
      case "$w" in -*|'('|'!') break ;; esac
      [ "$(resolve_word "$w")" = "$CWD" ] && continue # find . from the session's cwd
      rm_target_unsafe "$w" && block "find -exec rm -r starting outside cwd or /tmp/<name>: $w"
    done
    continue
  fi

  # BASH_REMATCH[2] is everything after the first rm word in the segment.
  [[ "$seg" =~ $RM_RE ]] || continue
  read -ra words <<< "${BASH_REMATCH[2]}"
  recursive=0
  for w in "${words[@]}"; do
    [[ "$w" =~ $RM_RECURSIVE_RE ]] && recursive=1
  done
  [ "$recursive" -eq 0 ] && continue
  for w in "${words[@]}"; do
    case "$w" in -*) continue ;; esac               # flags
    [[ "$w" =~ ^[0-9]*[\<\>] ]] && continue         # redirections (2>/dev/null)
    if rm_target_unsafe "$w"; then
      block "recursive rm with a target outside cwd or /tmp/<name>: $w"
    fi
  done
done <<< "$SEGMENTS"

exit 0
