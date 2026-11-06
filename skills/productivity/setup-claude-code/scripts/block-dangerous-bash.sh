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
# A denial stops one call, not the agent, so the message ends by telling it to stop, or,
# with a recommendation, to retry only that way.
block() {
  local tail="Do not retry with another spelling or tool. Report the blocked command to the user and stop."
  [ -n "$2" ] && tail="$2 Retry only in the recommended way; do not try any other spelling or tool."
  echo "BLOCKED: '$COMMAND' matches dangerous pattern '$1'. The user has prevented you from doing this. $tail" >&2
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
  # gh auth subcommands that change login state (`gh auth status` must stay usable: skills preflight with it)
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

# Network (curl, wget) and package-install rules. Each set runs only when the call names
# one of its tools, so other commands pay for neither.
FETCH_ON=0 INSTALL_ON=0
[[ "$JOINED" == *curl* || "$JOINED" == *wget* ]] && FETCH_ON=1
[[ "$JOINED" =~ pip|npm|pnpm|yarn|bun|cargo|go[[:space:]]+install ]] && INSTALL_ON=1
NL=$'\n'
# Like S, plus ( and a backtick, so a command inside $(...) or `...` counts.
NS='(^|[;&|"'"'"'[:space:](`])'
# An absolute directory before a command name: /usr/bin/curl.
ABS_DIR='/([^[:space:];&|"'"'"'(`]*/)?'
PATHP="(${ABS_DIR})?"
# A command name: bare after NS, or with a directory only at command position, so the
# last part of ~/src/curl or github.com/curl/curl is not a command.
CMD="(${NS}|(^|[;&|(\`\"'${NL}])[[:space:]]*${ABS_DIR})"
# The rest of one command: stops at an unquoted separator or newline.
CRUN="([^;&|${NL}\"']|\"[^\"]*\"|'[^']*')*"
INTERP='(sh|bash|zsh|dash|python|python3|node|perl)'
# Any words of one command, then the whitespace before the next.
WORDS='([[:space:]]+[^[:space:];&|]+)*[[:space:]]+'
# The interpreter reads its program from stdin: only flags follow, or a - / -s / -- argument.
STDIN_END="(([[:space:]]+-[[:alpha:]]*)*[[:space:]]*(\$|[;&|)\`${NL}])|[\"'\`]|([[:space:]]+-[[:alpha:]]*)*[[:space:]]+(-|-s|--)([[:space:]]|\$))"
Q="[\"']"
# Like ARG, but a plain word also stops at a separator or redirection.
NARG="(\"[^\"]*\"|'[^']*'|[^[:space:];&|<>]+)"
# The flags naming an output file: curl -o / --output, wget -O / --output-document.
CURL_O_FLAG='(-[[:alnum:]]*o([[:space:]]+|=)?|--output([[:space:]]+|=))'
WGET_O_FLAG='(-[[:alnum:]]*O([[:space:]]+|=)?|--output-document([[:space:]]+|=))'

# Set FLAG_VALUES to the value of every <flag> in the arguments <args>, in order: curl
# takes one -o per URL, so the last is not the only one.
flag_values() {
  local rest=" $1" re="[[:space:]]$2${NARG}"
  FLAG_VALUES=()
  while [[ "$rest" =~ $re ]]; do
    FLAG_VALUES+=("${BASH_REMATCH[${#BASH_REMATCH[@]}-1]}")
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
}

# Command position after an earlier command, and the end of a path word. A ( counts only
# when it opens a subshell or $(...), not a call like open("x").
XP="([;&|\`${NL}]|(^|[[:space:];&|\$])\()[[:space:]]*"
XE="${Q}?([[:space:];&|)\`]|\$)"
RUN_FILE="${XP}${INTERP}([[:space:]]+-[^[:space:]]*)*[[:space:]]+${Q}?(\./)?"
CHMOD_X="${NS}chmod([[:space:]]+-[^[:space:]]+)*[[:space:]]+[ugoa]*\+[rwxX]*x[rwxX]*[[:space:]]+${Q}?(\./)?"

# Line-local rules, as reason/pattern pairs.
FETCH_RULES=(
  "curl or wget output run by an interpreter"
  "${NS}${INTERP}([[:space:]]+-[^[:space:]]*)*[[:space:]]+<\([[:space:]]*${PATHP}(curl|wget)${E}"
  "curl or wget output sourced into the shell"
  "${NS}(source|\.)[[:space:]]+<\([[:space:]]*${PATHP}(curl|wget)${E}"
  "curl or wget output run by an interpreter"
  "${NS}${INTERP}([[:space:]]+-[^[:space:]]*)*[[:space:]]+-[[:alpha:]]*c[[:space:]]+[\"']?"'(\$\(|`)[[:space:]]*'"${PATHP}(curl|wget)${E}"
)
PKG_INSTALL='(install|i|add|ci|update|upgrade|up)'
PKG_SOURCE='(--index-url|--extra-index-url|--registry)'
# Options before a package manager's subcommand. Only the listed ones take the next word
# as a value, so in `npm --silent run update` the subcommand is run, not update.
PKG_VALUE_OPT='(-w|--workspace|--prefix|--filter|-C|--dir|--cwd|--loglevel|--index-url|--extra-index-url|--registry)'
PKG_OPTS="([[:space:]]+(${PKG_VALUE_OPT}[[:space:]]+[^[:space:];&|]+|-[^[:space:];&|]*))*"
INSTALL_RULES=(
  # pip covers python -m pip and uv pip too.
  "pip install from a URL or git"
  "${NS}pip3?[[:space:]]+install${WORDS}${Q}?(git\+|https?://)"
  "package install from a URL or git"
  "${NS}(npm|pnpm|yarn|bun)[[:space:]]+(install|i|add)${WORDS}${Q}?(github:|git\+|git://|https?://)"
  "global package install"
  "${NS}(npm|pnpm|bun)${WORDS}(install|i|add)${WORDS}(-g|--global)${E}"
  "global package install"
  "${NS}(npm|pnpm|bun)${WORDS}(-g|--global)${WORDS}(install|i|add)${E}"
  "global package install"
  "${NS}(yarn[[:space:]]+global[[:space:]]+add|cargo[[:space:]]+install|pipx[[:space:]]+install)${E}"
  "global package install"
  "${NS}go[[:space:]]+install${WORDS}[^-[:space:];&|][^[:space:];&|]*@"
  # Only an install subcommand takes a custom source: `npm run install -- --registry URL`
  # passes it to a script.
  "custom package source"
  "${NS}(pip3?|npm|pnpm|yarn|bun)${PKG_OPTS}[[:space:]]+${PKG_INSTALL}${WORDS}${PKG_SOURCE}${E}"
  "custom package source"
  "${NS}(pip3?|npm|pnpm|yarn|bun)${PKG_OPTS}[[:space:]]+${PKG_SOURCE}([[:space:]]+|=)[^[:space:];&|]+${PKG_OPTS}[[:space:]]+${PKG_INSTALL}${E}"
  "custom package source"
  "${NS}pip3?[[:space:]]+install${WORDS}-i${E}"
)

# Line-local rules for sending a file's contents, waived when every URL is loopback.
UPLOAD_RULES=(
  "curl request body read from a file"
  "${CMD}curl${CRUN}[[:space:]](-d|--data|--data-binary|--data-ascii|--json)([[:space:]]+|=)?${Q}?@"
  "curl --data-urlencode read from a file"
  "${CMD}curl${CRUN}[[:space:]]--data-urlencode([[:space:]]+|=)${Q}?[^[:space:]=\"'@]*@"
  "curl form field read from a file"
  "${CMD}curl${CRUN}[[:space:]](-F|--form)([[:space:]]+|=)?${Q}?[^[:space:]=\"']*=[@<]"
  "curl file upload"
  "${CMD}curl${CRUN}[[:space:]](-T|--upload-file)"
  "wget request body read from a file"
  "${CMD}wget${CRUN}[[:space:]]--(post|body)-file${E}"
)
URL_RE='[[:alpha:]][[:alnum:]+.-]*://([^/[:space:]"'"'"'?#]*)'
LOOPBACK_RE='^(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?$'

# Exit 0 when the call names at least one URL and every URL's host is loopback.
only_loopback_urls() {
  local rest="$JOINED" host seen=0
  while [[ "$rest" =~ $URL_RE ]]; do
    host="${BASH_REMATCH[1]##*@}"
    rest="${rest#*"${BASH_REMATCH[0]}"}"
    [[ "$host" =~ $LOOPBACK_RE ]] || return 1
    seen=1
  done
  [ "$seen" = 1 ]
}

# A command that prints a credential, at command position (also inside $(...) or `...`).
TOKEN_CMD_RE="(^|[;&|(\`${NL}])[[:space:]]*(gh[[:space:]]+auth[[:space:]]+token|gcloud[[:space:]]+auth[[:space:]]+print-(access|identity)-token|az[[:space:]]+account[[:space:]]+get-access-token|aws[[:space:]]+configure[[:space:]]+(get|export-credentials)|aws[[:space:]]+sts[[:space:]]+get-session-token|op[[:space:]]+(read|item[[:space:]]+get)|pass[[:space:]]+show|vault[[:space:]]+(read|kv[[:space:]]+get)|kubectl[[:space:]]+get[[:space:]]+secrets?|git[[:space:]]+credential[[:space:]]+fill|security[[:space:]]+find-generic-password)${E}"
VAR_RE='\$\{?([[:alpha:]_][[:alnum:]_]*)'
SECRET_PART_RE='^(TOKENS?|SECRETS?|PASSWORD|PASSWD|PASS|KEYS?|APIKEY|AUTH|AUTHORIZATION|CREDENTIALS?)$'
PUBLIC_PART_RE='^(PUBLIC|PUBLISHABLE)$'

# Exit 0 when a _-separated part of the name, in any case, is a secret word and no part
# is PUBLIC or PUBLISHABLE. Whole parts only: NEXTAUTH_URL and BYPASS_CACHE do not match.
secret_looking() {
  local part secret=1
  IFS=_ read -ra parts <<< "$1"
  shopt -s nocasematch
  for part in "${parts[@]}"; do
    [[ "$part" =~ $PUBLIC_PART_RE ]] && { secret=1; break; }
    [[ "$part" =~ $SECRET_PART_RE ]] && secret=0
  done
  shopt -u nocasematch
  return "$secret"
}

# A bare GitHub owner/repo argument (not @scope/pkg, ./, ../, or /). Values of the flags
# that take one (--workspace packages/api) are not install arguments.
JS_INSTALL_RE="${NS}(npm|pnpm|yarn|bun)[[:space:]]+(install|i|add)(([[:space:]]+[^[:space:];&|]+)*)"
OWNER_REPO_RE="^[[:alnum:]_][[:alnum:]_.-]*/[[:alnum:]_.-]+([#@].*)?$"

if [ "$INSTALL_ON" = 1 ]; then
  while IFS= read -r line; do
    for ((i = 0; i < ${#INSTALL_RULES[@]}; i += 2)); do
      [[ "$line" =~ ${INSTALL_RULES[i+1]} ]] && block "${INSTALL_RULES[i]}"
    done
    [[ "$line" =~ $JS_INSTALL_RE ]] || continue
    read -ra words <<< "${BASH_REMATCH[4]}"
    skip=0
    for w in "${words[@]}"; do
      [ "$skip" = 1 ] && { skip=0; continue; }
      case "$w" in
        -w|--workspace|--prefix|--filter|-C|--dir|--cwd|--tag|--registry) skip=1 ;;
        -*) ;;
        *) [[ "${w//[\"\']/}" =~ $OWNER_REPO_RE ]] && block "package install from a GitHub owner/repo" ;;
      esac
    done
  done <<< "$JOINED"
fi

if [ "$FETCH_ON" = 1 ]; then
  while IFS= read -r line; do
    for ((i = 0; i < ${#FETCH_RULES[@]}; i += 2)); do
      [[ "$line" =~ ${FETCH_RULES[i+1]} ]] && block "${FETCH_RULES[i]}"
    done
    for ((i = 0; i < ${#UPLOAD_RULES[@]}; i += 2)); do
      [[ "$line" =~ ${UPLOAD_RULES[i+1]} ]] && ! only_loopback_urls && block "${UPLOAD_RULES[i]}"
    done
  done <<< "$JOINED"

  # Whole-call rules, which can span lines.
  [[ "$JOINED" =~ ${CMD}(curl|wget)${CRUN}\|[[:space:]]*(sudo([[:space:]]+-[^[:space:]]+)*[[:space:]]+)?${PATHP}${INTERP}${STDIN_END} ]] \
    && block "curl or wget output piped into an interpreter"

  # Download then execute: a later command in the call runs a file that curl -o or
  # wget -O wrote, by the same spelling.
  for tool in curl wget; do
    if [ "$tool" = curl ]; then oflag="$CURL_O_FLAG"; else oflag="$WGET_O_FLAG"; fi
    rest="$JOINED"
    while [[ "$rest" =~ ${CMD}${tool}([[:space:]]${CRUN})? ]]; do
      rest="${rest#*"${BASH_REMATCH[0]}"}"
      flag_values "${BASH_REMATCH[0]#*"$tool"}" "$oflag"
      for f in "${FLAG_VALUES[@]}"; do
        f="${f#[\"\']}" f="${f%[\"\']}"
        [[ -z "$f" || "$f" == - ]] && continue
        base="${f#./}"
        if [[ "$rest" =~ $RUN_FILE"$base"$XE ]] \
          || [[ "$f" != /* && "$rest" =~ $XP$Q?\./"$base"$XE ]] \
          || [[ "$f" == /* && "$rest" =~ $XP$Q?"$f"$XE ]] \
          || [[ "$rest" =~ $CHMOD_X"$base"$XE ]]; then
          block "download then execute: $f"
        fi
      done
    done
  done

  # Secrets on the wire: anywhere in a call that runs curl or wget, a variable with a
  # secret-looking name or a command that prints a token. No host is exempt.
  if [[ "$JOINED" =~ ${CMD}(curl|wget)${E} ]]; then
    [[ "$JOINED" =~ $TOKEN_CMD_RE ]] && block "token-printing command in a call that runs curl or wget"
    rest="$JOINED"
    while [[ "$rest" =~ $VAR_RE ]]; do
      name="${BASH_REMATCH[1]}"
      rest="${rest#*"${BASH_REMATCH[0]}"}"
      secret_looking "$name" && block "secret-looking variable \$$name in a call that runs curl or wget"
    done
  fi
fi

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

# Resolve . and .. by spelling into NORMED: /a/b/../c -> /a/c. Setting a variable
# instead of printing spares callers a subshell.
norm_path_into() {
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
  NORMED="/${out[*]}"
}

norm_path() {
  norm_path_into "$1"
  printf '%s' "$NORMED"
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

# Downloads must not land in these. SENS_CUR is the directory for this check alone: unlike
# CUR it follows ~ and $HOME, and it is empty (not sensitive) once it cannot be followed.
SENS_DIRS=("$HOME/.ssh" "$HOME/.aws" "$HOME/.gnupg" "$HOME/.claude" "$HOME/.config" "$HOME/.local/bin" /etc /usr/local/bin)
SENS_FILES=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc" "$HOME/.zprofile")
SENS_CUR="$CWD"
CURL_DIR_RE="curl${CRUN}[[:space:]]--output-dir([[:space:]]+|=)${NARG}"
CURL_REMOTE_RE="curl${CRUN}[[:space:]](-[[:alnum:]]*O[[:alnum:]]*|--remote-name(-all)?)${E}"
WGET_OUT_RE="wget${CRUN}[[:space:]]${WGET_O_FLAG}${NARG}"
WGET_DIR_RE="wget${CRUN}[[:space:]](-[[:alnum:]]*P([[:space:]]+|=)?|--directory-prefix([[:space:]]+|=))${NARG}"

# Like resolve_word against SENS_CUR, but expanding ~, $HOME, and ${HOME}. Sets SENS_PATH,
# empty when the hook cannot tell.
sens_resolve() {
  local t="${1#[\"\']}"
  t="${t%[\"\']}"
  SENS_PATH=""
  case "$t" in
    '~'|'$HOME'|'${HOME}') t="$HOME" ;;
    '~/'*|'$HOME/'*|'${HOME}/'*) t="$HOME/${t#*/}" ;;
  esac
  case "$t" in
    *'$'*|*'`'*|'~'*) return ;;
  esac
  if [[ "$t" == /* ]]; then norm_path_into "$t"
  elif [ -n "$SENS_CUR" ]; then norm_path_into "$SENS_CUR/$t"
  else return
  fi
  SENS_PATH="$NORMED"
}

sensitive_path() {
  local p
  [ -z "$1" ] && return 1
  for p in "${SENS_DIRS[@]}"; do [[ "$1" == "$p" || "$1" == "$p"/* ]] && return 0; done
  for p in "${SENS_FILES[@]}"; do [ "$1" = "$p" ] && return 0; done
  return 1
}

# Exit 0 when the path word <w> resolves to a sensitive path.
word_sensitive() {
  [ "$1" = - ] && return 1 # wget -O - writes to stdout
  sens_resolve "$1"
  sensitive_path "$SENS_PATH"
}

# The same for the last group of the latest match: the path word of the *_OUT_RE /
# *_DIR_RE patterns.
matched_path_sensitive() {
  word_sensitive "${BASH_REMATCH[${#BASH_REMATCH[@]}-1]}"
}

# curl or wget writing into a sensitive path: named outright, through an output
# directory, or by the remote name into a sensitive current directory.
check_download_target() {
  local seg="$1"
  if [[ "$seg" =~ ${CMD}curl${E} ]]; then
    flag_values "${seg#*curl}" "$CURL_O_FLAG"
    for w in "${FLAG_VALUES[@]}"; do
      word_sensitive "$w" && block "curl download into a sensitive path"
    done
    if [[ "$seg" =~ $CURL_DIR_RE ]]; then
      matched_path_sensitive && block "curl download into a sensitive directory"
    elif [[ "$seg" =~ $CURL_REMOTE_RE ]]; then
      sensitive_path "$SENS_CUR" && block "curl download into a sensitive directory"
    fi
  fi
  if [[ "$seg" =~ ${CMD}wget${E} ]]; then
    if [[ "$seg" =~ $WGET_OUT_RE ]]; then
      matched_path_sensitive && block "wget download into a sensitive path"
    elif [[ "$seg" =~ $WGET_DIR_RE ]]; then
      matched_path_sensitive && block "wget download into a sensitive directory"
    else
      sensitive_path "$SENS_CUR" && block "wget download into a sensitive directory"
    fi
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

# Set CD_DIR to the directory a `cd` command names, unquoted and without any redirection
# after it. Exit 1 when the command is not a cd.
cd_dir() {
  [[ "$1" =~ $CD_RE ]] || return 1
  local d="${BASH_REMATCH[2]}" full
  full="$d"
  d="${d%%[<>]*}" # cut at a redirection
  # a separate fd number before the redirection (`cd dir 2>/dev/null`) goes too
  if [ "$d" != "$full" ] && [[ "$d" =~ ^(.*[^[:space:]])[[:space:]]+[0-9]+[[:space:]]*$ ]]; then
    d="${BASH_REMATCH[1]}"
  fi
  [[ "$d" =~ ^[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]] && d="${BASH_REMATCH[1]}"
  d="${d#[\"\']}"
  CD_DIR="${d%[\"\']}"
}

# Downloads into sensitive paths, command by command. Unlike SEGMENTS, a separator inside
# quotes (the & of a query string) does not end a command; an unclosed quote makes the
# rest of the call one command.
if [ "$FETCH_ON" = 1 ]; then
  QSEG_RE="^(${CRUN})[;&|${NL}]*"
  rest="$JOINED"
  while [ -n "$rest" ]; do
    [[ "$rest" =~ $QSEG_RE ]]
    if [ -z "${BASH_REMATCH[0]}" ]; then seg="$rest" rest=""
    else seg="${BASH_REMATCH[1]}" rest="${rest:${#BASH_REMATCH[0]}}"
    fi
    if cd_dir "$seg"; then
      case "$CD_DIR" in
        '') SENS_CUR="$HOME" ;;
        '-') SENS_CUR="" ;;
        *) sens_resolve "$CD_DIR"; SENS_CUR="$SENS_PATH" ;;
      esac
    elif [[ "$seg" == *curl* || "$seg" == *wget* ]]; then
      check_download_target "$seg"
    fi
  done
fi

while IFS= read -r seg; do
  if [[ "$seg" =~ $GH_API_RE && "$seg" =~ $GH_FIELD_RE && ! "$seg" =~ $GH_GET_RE ]]; then
    block "gh api with field arguments and no -X GET (an implicit POST)"
  fi

  # cd: follow the directory by spelling, ignoring any redirection after it.
  if cd_dir "$seg"; then
    case "$CD_DIR" in
      ''|'-'|'~'*|*'$'*|*'`'*) CUR="" ;;
      *) CUR=$(resolve_word "$CD_DIR") ;;
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
