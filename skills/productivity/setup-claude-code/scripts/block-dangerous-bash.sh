#!/bin/bash
# Installed by setup-claude-code. Overwritten on each skill re-run; edit the source in
# the skill's scripts/ folder, not the installed copy at ~/.claude/hooks/.
# Blocks dangerous Bash commands at PreToolUse time. Exits 2 to deny.
#
# A speed bump for the harmful shapes agents commonly write, not a defence against
# deliberate evasion; the auto mode classifier judges everything it lets through.
# Every rule follows six principles:
#   1. One rule per harm, matching the shapes agents commonly write for it.
#   2. One quote-aware tokenizer splits the call into commands; every rule matches on a
#      command's name, options and operands, never across commands or inside data.
#   3. Deletes fail closed on a target the hook cannot resolve.
#   4. One safe place for deletes: strictly inside the working directory, or in or under
#      a /tmp/<name> directory, with symlinks checked on disk.
#   5. A message states what was blocked. A hint is added only where a safe route to the
#      same goal exists, and it names that route or the goal not to reach by other means.
#   6. Fast: bash built-ins and jq, plus one git call for a plain `git push`.

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

# Bytes, not characters, and no pathname expansion anywhere in the hook.
LC_ALL=C
set -f
unset CDPATH
HOOK_PWD=$PWD

# Join backslash-newline continuations so a command split over lines is checked whole.
# The tokenizer's marker bytes are dropped from the input so no text can forge one.
JOINED="${COMMAND//$'\\\n'/ }"
JOINED="${JOINED//[$'\x02\x03\x04\x05\x06\x07\x1f']/}"

# Every rule needs one of these names, so a call without any of them is let through
# before tokenizing. A name inside a `bash -c` script still appears in the text.
PREFILTER_RE='(^|[^[:alnum:]_])(rm|find|git|gh|curl|wget|pip|pip3|npm|pnpm|yarn|bun|cargo|pipx|go|uv)([^[:alnum:]_]|$)'
[[ "$JOINED" =~ $PREFILTER_RE ]] || exit 0

H_DLRUN="Save the download to a new directory under /tmp (or the working directory if it must stay with the project), read it, and run it in a separate call only if it is what the task needs."
H_DLDIR="Download into a new directory under /tmp, or the working directory if the file belongs to the project."
H_SECRET="Do not send this credential over the network by any other means. For the GitHub API, use gh api, which authenticates itself."
H_UPLOAD="Do not send this file's contents to a remote host by any other means."
H_SRC_CLONE="Do not install from this source by any other means, such as cloning it first."
H_SRC="Do not install from this source by any other means."
H_NPX="Run it with npx, or add it to the project as a dependency."
H_HOOKS="Run it with git hooks enabled; if a git hook fails, fix the problem it reports. Do not skip or disable git hooks by any other means."
H_GHGET="If this is a read, add -X GET."
H_LITERAL="The hook cannot resolve shell variables other than \$HOME, command substitutions, or this cd; name the target as a literal path under the working directory or under /tmp/<name>."
H_XARGS="The hook cannot see targets that xargs reads from its input; name each target as a literal path under the working directory or under /tmp/<name>."
H_FINDOP="Pass {} on its own as the rm operand, or name the target as a literal path under the working directory or under /tmp/<name>."
H_LEASE="The recommended way is to use: git push --delete with a lease on each deleted branch's expected commit."

# block <reason> [hint]
block() {
  local msg="BLOCKED: '$COMMAND' matches dangerous pattern '$1'. The user has prevented you from doing this."
  [ -n "$2" ] && msg="$msg $2"
  echo "$msg" >&2
  exit 2
}

# ---------------------------------------------------------------------------------------
# Tokenizer. The call becomes a flat list of commands. Each word is kept in three forms:
#   WT: its text as bash passes it, quotes and escapes removed;
#   WS: its source spelling, for messages and the comment-edit exception;
#   WE: its encoding, which keeps the provenance the text loses. Plain (unquoted) text is
#       written as is, so a leading ~ or a glob character in it means what bash makes of
#       it; quoted or escaped text sits between \x02 and \x03; $NAME is \x04NAME\x05
#       (\x04?\x05 for one the hook never resolves); a substitution is \x06<list>\x07.
# Per command: C_LIST (the list it belongs to), C_OP (the operator after it), C_SUB (1
# for a ( ... ) subshell), C_REDIR, C_W0/C_WN (its words), C_NAMEW (its command word,
# after assignments, keywords and wrappers), C_SKIP (words before it), C_NAME (the
# command word's basename), C_A0 (first argument), C_XARGS, and for interpreters C_STDIN
# (reads its program from stdin), C_SCRIPTW and C_CODEW (script operand, -c code word).
# A list is the body of the call, a substitution, a subshell, a `sh -c` script or a
# heredoc an interpreter runs; LIST_PARENT is the command it runs inside.
# ---------------------------------------------------------------------------------------
NCMD=0 NLIST=0 NWORD=0
VARS=() # every variable name bash expands in the call
INTERP_RE='^(sh|bash|zsh|dash|python|python3|node|perl)$'
SHELL_RE='^(sh|bash|zsh|dash)$'

PLAIN_RE='^[^[:space:]'"'"'"\\$`;&|<>()]+'
DQ_RUN_RE='^[^"\\$`]+'
BT_RE='^`(([^`\\]|\\.)*)`'
SQ_RE="^'([^']*)'"
ANSI_RE="^\\\$'(([^'\\\\]|\\\\.)*)'"
ARITH_RE='^\$\(\(([^()]|\([^()]*\))*\)\)'
VAR_BRACE_RE='^\$\{([[:alpha:]_][[:alnum:]_]*)\}'
VAR_BRACE_OP_RE='^\$\{([[:alpha:]_][[:alnum:]_]*)[^}]*\}'
VAR_BRACE_ANY_RE='^\$\{[^}]*\}'
VAR_RE='^\$([[:alpha:]_][[:alnum:]_]*)'
VAR_SPECIAL_RE='^\$[0-9@*#?$!-]'
REDIR_RE='^(<<<|<<-|<<|<>|<&|>&|>>|>\||&>>|&>|<|>)'
OP_RE='^(;;&|;;|;&|&&|\|\||\|&|;|&|\|)'
LINE_RE=$'^([^\n]*)\n'
KEYWORD_RE='^(if|then|elif|else|fi|do|done|while|until|for|case|esac|function|select|!|\{|\})$'
ASSIGN_RE='^[[:alpha:]_][[:alnum:]_]*(\[[^]]*\])?\+?='
LIT_RE=$'^([^\x02]*)\x02([^\x03]*)\x03'
SUBST_RE=$'\x06([0-9]+)\x07'
GLOB_DIR_RE='[*?[].*/'
BRACE_RE='\{([^{}]*)\}'

lit() { we+=$'\x02'"$1"$'\x03'; wt+="$1"; }

start_cmd() {
  cur=$NCMD
  NCMD=$((NCMD + 1))
  C_LIST[cur]=$lid C_OP[cur]="" C_SUB[cur]=0 C_REDIR[cur]=0 C_W0[cur]=0 C_WN[cur]=0
  C_NAMEW[cur]=-1 C_SKIP[cur]=0 C_NAME[cur]="" C_A0[cur]=0 C_XARGS[cur]=0
  C_STDIN[cur]=0 C_SCRIPTW[cur]=-1 C_CODEW[cur]=-1
}

begin_word() {
  [ "$inword" = 1 ] && return
  inword=1 wt="" we="" wpos=$((${#input} - ${#REST}))
  [ "$cur" = -1 ] && start_cmd
}

end_word() {
  [ "$inword" = 1 ] || return
  inword=0
  if [ "$redir" = 1 ]; then
    redir=0
    if [ "$hdmode" != 0 ]; then
      local q=1
      [ "$we" = "$wt" ] && q=0
      hd_delim+=("$wt") hd_quoted+=("$q") hd_strip+=("$hdmode") hd_cmd+=("$cur")
      hdmode=0
    fi
    return
  fi
  lw_t+=("$wt") lw_e+=("$we") lw_s+=("${input:wpos:$((${#input} - ${#REST} - wpos))}")
}

end_cmd() {
  [ "$cur" = -1 ] && return
  local i=$cur k n=${#lw_t[@]}
  C_OP[i]=$1 C_W0[i]=$NWORD C_WN[i]=$n
  for ((k = 0; k < n; k++)); do
    WT[NWORD]=${lw_t[k]} WE[NWORD]=${lw_e[k]} WS[NWORD]=${lw_s[k]}
    NWORD=$((NWORD + 1))
  done
  lw_t=() lw_e=() lw_s=()
  cur=-1
  name_cmd "$i"
}

# opt_walk <from> <end> <short value letters> <long value options> [stop]: parse the
# options in WT[from..end). OW_NAME and OW_VAL hold each long or value-taking option and
# its value: the next word's index, "<index>:<text>" for a value attached to the option's
# own word, or -1. OW_FLAGS collects the short letters that take no value, and OW_OPS the
# operand indices. Options may follow operands, as most tools allow; with <stop> the walk
# ends at the first operand, and OW_NEXT is where it ended.
opt_walk() {
  local k=$1 end=$2 vs=$3 vl=" $4 " t dd=0
  OW_NAME=() OW_VAL=() OW_FLAGS="" OW_OPS=()
  for ((; k < end; k++)); do
    t=${WT[k]}
    if [ "$dd" = 1 ] || [[ "$t" != -?* ]]; then
      OW_OPS+=("$k")
      [ -n "$5" ] && break
      continue
    fi
    case "$t" in
      --) dd=1 ;;
      --*=*) OW_NAME+=("${t%%=*}") OW_VAL+=("$k:${t#*=}") ;;
      --*)
        OW_NAME+=("$t")
        if [[ "$vl" == *" $t "* ]] && [ $((k + 1)) -lt "$end" ]; then k=$((k + 1)) OW_VAL+=("$k"); else OW_VAL+=(-1); fi
        ;;
      *)
        if [ -n "$vs" ] && [[ "$t" =~ ^-([^$vs]*)([$vs])(.*)$ ]]; then
          OW_FLAGS+=${BASH_REMATCH[1]} OW_NAME+=("-${BASH_REMATCH[2]}")
          if [ -n "${BASH_REMATCH[3]}" ]; then OW_VAL+=("$k:${BASH_REMATCH[3]}")
          elif [ $((k + 1)) -lt "$end" ]; then k=$((k + 1)) OW_VAL+=("$k")
          else OW_VAL+=(-1); fi
        else
          OW_FLAGS+=${t:1}
        fi
        ;;
    esac
  done
  OW_NEXT=$k
}

# ow_value <n>: OWV, OWE and OWS are option n's value as text, encoding and source. An
# attached value (-o<f>, --output=<f>) keeps its encoding when the option before it is
# plain text, and is unresolvable otherwise. Exits 1 when the option has no value.
ow_value() {
  local x=${OW_VAL[$1]} k n
  OWV="" OWE="" OWS=""
  case "$x" in
    -1) return 1 ;;
    *:*)
      k=${x%%:*} OWV=${x#*:}
      n=$((${#WT[k]} - ${#OWV}))
      OWS=${WS[k]}
      if [ "${WE[k]:0:n}" = "${WT[k]:0:n}" ]; then OWE=${WE[k]:n}; else OWE=$'\x04?\x05'; fi
      ;;
    *) OWV=${WT[x]} OWE=${WE[x]} OWS=${WS[x]} ;;
  esac
}

ow_has() { # <option name>
  local o
  for o in "${OW_NAME[@]}"; do [ "$o" = "$1" ] && return 0; done
  return 1
}

ow_flag() { # <short letter> <long option>
  [[ "$OW_FLAGS" == *"$1"* ]] || ow_has "$2"
}

# skip_opts <short value letters> <long value options>: step w past a wrapper's options.
skip_opts() {
  opt_walk "$w" "$end" "$1" "$2" stop
  w=$OW_NEXT
}

# Find the command word behind assignments, keywords and wrappers, and lex a shell's
# -c script as a nested list.
name_cmd() {
  local i=$1 w=${C_W0[$1]} end=$((C_W0[$1] + C_WN[$1])) t
  if [ "${C_SUB[i]}" = 1 ]; then C_NAME[i]='('; return; fi
  while [ "$w" -lt "$end" ]; do
    t=${WT[w]}
    if [[ "$t" =~ $KEYWORD_RE || "$t" =~ $ASSIGN_RE ]]; then w=$((w + 1)); continue; fi
    case "$t" in
      command|builtin|nohup|time) w=$((w + 1)); skip_opts "" "" ;;
      exec) w=$((w + 1)); skip_opts "a" "" ;;
      env) w=$((w + 1)); skip_opts "uCS" "--unset --chdir --split-string" ;;
      nice) w=$((w + 1)); skip_opts "n" "--adjustment" ;;
      sudo) w=$((w + 1)); skip_opts "ughpCDrtUT" "--user --group --host --prompt --chdir --role --type --other-user --close-from" ;;
      timeout) w=$((w + 1)); skip_opts "sk" "--signal --kill-after"; w=$((w + 1)) ;;
      xargs) C_XARGS[i]=1; w=$((w + 1)); skip_opts "ILnPsdEa" "--arg-file --delimiter --eof --max-lines --max-args --max-procs --max-chars --process-slot-var" ;;
      *) break ;;
    esac
  done
  [ "$w" -lt "$end" ] || return
  C_SKIP[i]=$((w - C_W0[i]))
  t=${WT[w]##*/}
  if [[ "$t" =~ ^python[0-9.]*$ && "${WT[w+1]}" == -m && "${WT[w+2]}" =~ ^pip3?$ && $((w + 2)) -lt "$end" ]]; then
    w=$((w + 2)) t=pip
  elif [[ "$t" == uv && "${WT[w+1]}" == pip && $((w + 1)) -lt "$end" ]]; then
    w=$((w + 1)) t=pip
  fi
  C_NAMEW[i]=$w C_NAME[i]=$t C_A0[i]=$((w + 1))
  [[ "$t" =~ $INTERP_RE ]] && interp_parse "$i" "$end"
}

# Set C_STDIN, C_SCRIPTW and C_CODEW for an interpreter.
interp_parse() {
  local i=$1 k n code="" vals="" stdin=""
  case "${C_NAME[i]}" in
    sh|bash|zsh|dash) code=c vals=oO stdin=s ;;
    python|python3) code=cm vals=WX ;;
    node) code=ep vals=r ;;
    perl) code=eE ;;
  esac
  opt_walk "${C_A0[i]}" "$2" "$code$vals" "--eval --print" stop
  for ((k = 0; k < ${#OW_NAME[@]}; k++)); do
    n=${OW_NAME[k]}
    [[ "$n" == --eval || "$n" == --print || ( ${#n} = 2 && "$code" == *"${n:1}"* ) ]] || continue
    ow_value "$k" || return
    C_CODEW[i]=${OW_VAL[k]%%:*}
    [[ "${C_NAME[i]}" =~ $SHELL_RE ]] && lex_string "$OWV" "$i" script
    return
  done
  [ -n "$stdin" ] && [[ "$OW_FLAGS" == *[$stdin]* ]] && { C_STDIN[i]=1; return; }
  if [ ${#OW_OPS[@]} -gt 0 ] && [ "${WT[OW_OPS[0]]}" != - ]; then C_SCRIPTW[i]=${OW_OPS[0]}; else C_STDIN[i]=1; fi
}

# Lex a string as a nested list run by command <parent>.
lex_string() {
  local saved=$REST
  REST=$1
  lex_list "$2" "$3" ""
  REST=$saved
}

# $NAME, ${NAME}, $(...), $((...)), and in unquoted text $'...' and $"...".
lex_dollar() {
  local dq=$1 n
  if [[ "$REST" =~ $ARITH_RE ]]; then
    REST=${REST:${#BASH_REMATCH[0]}} we+=$'\x06-1\x07' wt+='$(:)'
  elif [[ "$REST" == '$('* ]]; then
    REST=${REST:2} we+=$'\x06'"$NLIST"$'\x07' wt+='$(:)'
    lex_list "$cur" subst ")"
  elif [[ "$REST" =~ $VAR_BRACE_RE || "$REST" =~ $VAR_RE ]]; then
    n=${BASH_REMATCH[1]} REST=${REST:${#BASH_REMATCH[0]}}
    VARS+=("$n") we+=$'\x04'"$n"$'\x05' wt+="\$$n"
  elif [[ "$REST" =~ $VAR_BRACE_OP_RE ]]; then
    n=${BASH_REMATCH[1]} REST=${REST:${#BASH_REMATCH[0]}}
    VARS+=("$n") we+=$'\x04?\x05' wt+="\$$n"
  elif [[ "$REST" =~ $VAR_BRACE_ANY_RE || "$REST" =~ $VAR_SPECIAL_RE ]]; then
    REST=${REST:${#BASH_REMATCH[0]}} we+=$'\x04?\x05' wt+="${BASH_REMATCH[0]}"
  elif [ "$dq" = 0 ] && [[ "$REST" =~ $ANSI_RE ]]; then
    REST=${REST:${#BASH_REMATCH[0]}}
    lit "${BASH_REMATCH[1]}"
  elif [ "$dq" = 0 ] && [[ "$REST" == '$"'* ]]; then
    REST=${REST:1}
    lex_dq 0
  else
    REST=${REST:1}
    if [ "$dq" = 1 ]; then lit '$'; else we+='$' wt+='$'; fi
  fi
}

lex_backtick() {
  if [[ "$REST" =~ $BT_RE ]]; then
    local body=${BASH_REMATCH[1]}
    REST=${REST:${#BASH_REMATCH[0]}}
    body=${body//\\\`/\`} body=${body//\\\$/\$} body=${body//\\\\/\\}
    we+=$'\x06'"$NLIST"$'\x07' wt+='$(:)'
    lex_string "$body" "$cur" subst
  else
    lit "$REST"
    REST=""
  fi
}

# Double-quoted text, or with <heredoc>=1 an unquoted heredoc body, which bash expands
# the same way but which has no closing quote.
lex_dq() {
  local heredoc=$1 c
  [ "$heredoc" = 1 ] || REST=${REST:1}
  while :; do
    case "${REST:0:1}" in
      '') return ;;
      '"')
        REST=${REST:1}
        [ "$heredoc" = 1 ] || return
        lit '"'
        ;;
      '\')
        c=${REST:1:1}
        case "$c" in
          '$'|'`'|'"'|'\') lit "$c"; REST=${REST:2} ;;
          *) lit '\'; REST=${REST:1} ;;
        esac
        ;;
      '$') lex_dollar 1 ;;
      '`') lex_backtick ;;
      *)
        [[ "$REST" =~ $DQ_RUN_RE ]]
        lit "${BASH_REMATCH[0]}"
        REST=${REST:${#BASH_REMATCH[0]}}
        ;;
    esac
  done
}

# Read the heredoc bodies queued on the line just ended. A quoted delimiter makes the
# body data; an unquoted one expands it like double-quoted text. An interpreter reading
# its program from stdin also runs the body as a script.
read_heredocs() {
  local k delim body line cmp nl ci
  for ((k = 0; k < ${#hd_delim[@]}; k++)); do
    delim=${hd_delim[k]} body=""
    while :; do
      if [[ "$REST" =~ $LINE_RE ]]; then
        line=${BASH_REMATCH[1]} REST=${REST:${#BASH_REMATCH[0]}} nl=1
      else
        line=$REST REST="" nl=0
      fi
      cmp=$line
      if [ "${hd_strip[k]}" = 2 ]; then
        while [[ "$cmp" == $'\t'* ]]; do cmp=${cmp:1}; done
      fi
      [ "$cmp" = "$delim" ] && break
      # Inside $(...), bash also ends the body at a line `<delimiter>)`.
      if [ "$term" = ")" ] && [[ "$cmp" == "$delim)"* ]]; then
        if [ "$nl" = 1 ]; then REST=${cmp:${#delim}}$'\n'$REST; else REST=${cmp:${#delim}}; fi
        break
      fi
      body+="$line"$'\n'
      [ "$nl" = 0 ] && break
    done
    ci=${hd_cmd[k]}
    if [ "${hd_quoted[k]}" = 0 ]; then
      local saved=$REST wt="" we=""
      cur=$ci REST=$body
      lex_dq 1
      cur=-1 REST=$saved
    fi
    [[ "${C_NAME[ci]}" =~ $INTERP_RE && "${C_STDIN[ci]}" = 1 ]] && lex_string "$body" "$ci" heredoc
  done
  hd_delim=() hd_quoted=() hd_strip=() hd_cmd=()
}

# lex_list <parent> <context> <terminator>: lex commands from REST into a new list, up
# to the terminator (")") or the end. Returns 1 when the terminator never came.
lex_list() {
  local parent=$1 ctx=$2 term=$3 lid=$NLIST
  NLIST=$((NLIST + 1))
  LIST_PARENT[lid]=$parent LIST_CTX[lid]=$ctx
  local input=$REST cur=-1 inword=0 wt="" we="" wpos=0 redir=0 hdmode=0 c
  local lw_t=() lw_e=() lw_s=() hd_delim=() hd_quoted=() hd_strip=() hd_cmd=()
  while :; do
    c=${REST:0:1}
    case "$c" in
      '')
        end_word
        end_cmd ""
        [ -z "$term" ]
        return
        ;;
      ' '|$'\t')
        end_word
        REST=${REST#"${REST%%[! $'\t']*}"}
        ;;
      $'\n')
        end_word
        end_cmd $'\n'
        REST=${REST:1}
        [ ${#hd_delim[@]} -gt 0 ] && read_heredocs
        ;;
      ';'|'&'|'|')
        if [[ "$REST" == '&>'* ]]; then
          end_word
          [[ "$REST" =~ $REDIR_RE ]]
          REST=${REST:${#BASH_REMATCH[0]}}
          [ "$cur" = -1 ] && start_cmd
          C_REDIR[cur]=1 redir=1
        else
          end_word
          [[ "$REST" =~ $OP_RE ]]
          REST=${REST:${#BASH_REMATCH[0]}}
          end_cmd "${BASH_REMATCH[0]}"
        fi
        ;;
      '<'|'>')
        if [[ "$REST" == [\<\>]'('* ]]; then
          begin_word
          REST=${REST:2} we+=$'\x06'"$NLIST"$'\x07' wt+='$(:)'
          lex_list "$cur" procsubst ")"
        else
          # Digits right before a redirection name a file descriptor, not a word.
          if [ "$inword" = 1 ] && [ "$we" = "$wt" ] && [[ "$wt" =~ ^[0-9]+$ ]]; then inword=0; fi
          end_word
          [[ "$REST" =~ $REDIR_RE ]]
          REST=${REST:${#BASH_REMATCH[0]}}
          case "${BASH_REMATCH[0]}" in
            '<<-') hdmode=2 ;;
            '<<') hdmode=1 ;;
          esac
          [ "$cur" = -1 ] && start_cmd
          C_REDIR[cur]=1 redir=1
        fi
        ;;
      '(')
        if [ "$inword" = 0 ] && { [ ${#lw_t[@]} = 0 ] || [[ "${lw_t[${#lw_t[@]}-1]}" =~ $KEYWORD_RE ]]; }; then
          [ "$cur" = -1 ] && start_cmd
          C_SUB[cur]=1
          REST=${REST:1}
          lex_list "$cur" subshell ")"
        else
          begin_word
          REST=${REST:1} we+='(' wt+='('
        fi
        ;;
      ')')
        # Closes this list, or ends a case pattern or a `name()` function header, after
        # which a command starts.
        end_word
        end_cmd ""
        REST=${REST:1}
        [ "$term" = ")" ] && return 0
        ;;
      "'")
        begin_word
        if [[ "$REST" =~ $SQ_RE ]]; then
          REST=${REST:${#BASH_REMATCH[0]}}
          lit "${BASH_REMATCH[1]}"
        else
          lit "${REST:1}"
          REST=""
        fi
        ;;
      '"') begin_word; lex_dq 0 ;;
      '\')
        begin_word
        if [ -n "${REST:1:1}" ]; then lit "${REST:1:1}"; REST=${REST:2}; else lit '\'; REST=""; fi
        ;;
      '$') begin_word; lex_dollar 0 ;;
      '`') begin_word; lex_backtick ;;
      '#')
        if [ "$inword" = 0 ]; then
          REST=${REST#"${REST%%$'\n'*}"}
        else
          REST=${REST:1} we+='#' wt+='#'
        fi
        ;;
      *)
        begin_word
        [[ "$REST" =~ $PLAIN_RE ]]
        we+=${BASH_REMATCH[0]} wt+=${BASH_REMATCH[0]}
        REST=${REST:${#BASH_REMATCH[0]}}
        ;;
    esac
  done
}

REST=$JOINED
lex_list -1 top ""

# ---------------------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------------------

# Resolve . and .. by spelling into NORMED: /a/b/../c -> /a/c.
norm_path_into() {
  local IFS=/ part out=() parts
  parts=($1)
  for part in "${parts[@]}"; do
    case "$part" in
      ''|'.') ;;
      '..') [ "${#out[@]}" -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$part") ;;
    esac
  done
  NORMED="/${out[*]}"
}

CWD_N=""
norm_path_into "$CWD"
CWD_N=$NORMED
CWD_P=${CWD_N%/}

# resolve <enc> <text> <dir>: set RES_RAW (absolute, . dropped, .. kept: what the kernel
# walks) and RES_LOG (.. collapsed by spelling). A leading plain ~ or $HOME expands to the
# hook's $HOME. Returns 1 for a word the hook cannot resolve (any other expansion or a
# substitution), 2 for a relative word in a directory the hook lost track of.
resolve() {
  local e=$1 t=$2 p
  case "$e" in
    '~') p=$HOME e="" ;;
    '~/'*) p="$HOME/${t:2}" e=${e:2} ;;
    $'\x04HOME\x05'*) p="$HOME${t:5}" e=${e:6} ;;
    '~'*) return 1 ;;
    *) p=$t ;;
  esac
  case "$e" in *[$'\x04\x06']*) return 1 ;; esac
  if [[ "$p" != /* ]]; then
    [ -n "$3" ] || return 2
    p="$3/$p"
  fi
  local IFS=/ part raw=() parts
  parts=($p)
  for part in "${parts[@]}"; do
    case "$part" in ''|'.') ;; *) raw+=("$part") ;; esac
  done
  RES_RAW="/${raw[*]}"
  norm_path_into "$RES_RAW"
  RES_LOG=$NORMED
}

# A word's spelling with quoted glob and brace characters neutralised, so a *, ?, [, {, }
# or , left in MASK is one bash expands.
glob_mask() {
  local e=$1 out="" l
  while [[ "$e" =~ $LIT_RE ]]; do
    l=${BASH_REMATCH[2]}
    out+="${BASH_REMATCH[1]}${l//[*?[\{\},]/_}"
    e=${e:${#BASH_REMATCH[0]}}
  done
  MASK=$out$e
}

# phys_of <absolute path>: PHYS is where the path really is. The longest existing prefix
# is resolved by `cd -P`, which resolves each symlink before any later ..; the rest, which
# does not exist and so holds no symlink, is appended by spelling.
phys_of() {
  local IFS=/ parts pre="" k=0 rest=""
  parts=(${1#/})
  while [ "$k" -lt "${#parts[@]}" ] && [ -e "$pre/${parts[k]}" ]; do
    pre="$pre/${parts[k]}" k=$((k + 1))
  done
  cd -P -- "${pre:-/}" 2>/dev/null || return 1
  local base=$PWD
  cd -- "$HOOK_PWD" 2>/dev/null
  rest="${parts[*]:k}"
  norm_path_into "$base/$rest"
  PHYS=$NORMED
}

# The workspace rule: a delete target must lie strictly inside the working directory, or
# in or under a /tmp/<name> directory, and really stay there on disk.
# check_delete <enc> <text> <src> <dir> <kind> <trailing slash>
check_delete() {
  local e=$1 t=$2 s=$3 kind=$5 trail=$6 rc=0
  [[ "$t" == */ ]] && trail=1
  resolve "$e" "$t" "$4" || rc=$?
  [ "$rc" = 1 ] && block "$kind with a target the hook cannot resolve: $s" "$H_LITERAL"
  [ "$rc" = 2 ] && block "$kind after a cd the hook cannot follow: $s" "$H_LITERAL"
  glob_mask "$e"
  local m=$MASK L=$RES_LOG raw=$RES_RAW root area
  while [[ "$m" == ?*/ ]]; do m=${m%/}; done
  [[ "$m" =~ $GLOB_DIR_RE ]] && block "$kind with a wildcard before the last path part: $s"
  # Brace expansion is judged as written only when every alternative is a plain sibling
  # in the last path part; one that could reach another directory is unresolvable.
  local b=$m c alt alts
  while [[ "$b" =~ $BRACE_RE ]]; do
    c=${BASH_REMATCH[1]} b=${b#*"${BASH_REMATCH[0]}"}
    [[ "$c" == *,* || "$c" == *..* ]] || continue
    { [[ "$b" == */* ]] || [ "$trail" = 1 ] || [[ "$c" == ,* || "$c" == *, || "$c" == *,,* ]]; } \
      && block "$kind with a target the hook cannot resolve: $s" "$H_LITERAL"
    IFS=, read -ra alts <<< "$c"
    for alt in "${alts[@]}"; do
      case "$alt" in
        .|..|*/*|*[*?[]*) block "$kind with a target the hook cannot resolve: $s" "$H_LITERAL" ;;
      esac
    done
  done
  if [ "$L" = "$CWD_N" ]; then
    block "$kind of the whole working directory: $s"
  elif [[ "$L" == "$CWD_P"/* ]]; then
    if [ "${L%/*}" = "$CWD_N" ] && [[ "${m##*/}" == '*' || "${m##*/}" == '.*' ]]; then
      block "$kind of the whole working directory: $s"
    fi
    area="the working directory" root=$CWD_N
  elif [[ "$L" =~ ^/tmp/([^/]+)(/.*)?$ ]] && { [ -n "${BASH_REMATCH[2]}" ] || [[ "$m" != *[*?[]* ]]; }; then
    area="/tmp/<name>" root="/tmp/${BASH_REMATCH[1]}"
    # /tmp is world-writable, so a /tmp/<name> walked through must be the user's own
    # real directory. Deleting /tmp/<name> itself is safe: the sticky bit limits it to
    # the owner, and a symlink there is removed as a link.
    if [ -n "${BASH_REMATCH[2]}" ] || [ "$trail" = 1 ]; then
      if [ -e "$root" ] || [ -L "$root" ]; then
        [ -d "$root" ] && [ ! -L "$root" ] && [ -O "$root" ] \
          || block "$kind inside a /tmp directory that is a symlink or not yours: $s"
      fi
    fi
  else
    block "$kind outside the working directory and /tmp/<name>: $s"
  fi

  # Walk the raw path from the area root down to the target's parent (the target too
  # when a trailing slash follows it), stopping at the first part that does not exist.
  local IFS=/ parts pre k lim found=0
  if [[ "$raw" == "$root"/* ]]; then pre=$root parts=(${raw:${#root}+1}); else pre="" parts=(${raw#/}); fi
  lim=$((${#parts[@]} - 1))
  [ "$trail" = 1 ] && lim=${#parts[@]}
  for ((k = 0; k < lim; k++)); do
    pre="$pre/${parts[k]}"
    if [ -L "$pre" ]; then found=1; break; fi
    [ -e "$pre" ] || break
  done
  [ "$found" = 1 ] || return 0

  # A symlink on the way: the kernel resolves it before any later .., so judge the
  # target by where it really is.
  local last=${raw##*/} parent=${raw%/*} pt proot
  if [ "$trail" = 1 ] || [ "$last" = .. ]; then parent=$raw last=""; fi
  local why="$kind through a symlink that leads outside $area: $s"
  phys_of "${parent:-/}" || block "$why"
  pt=${PHYS%/}${last:+/$last}
  phys_of "$root" || block "$why"
  proot=$PHYS
  if [ "$area" = "/tmp/<name>" ]; then
    [ "$pt" = "$proot" ] || [[ "$pt" == "${proot%/}"/* ]] || block "$why"
  else
    [[ "$pt" == "${proot%/}"/?* ]] || block "$why"
  fi
}

# Downloads must not land in these.
SENS_DIRS=("$HOME/.ssh" "$HOME/.aws" "$HOME/.gnupg" "$HOME/.claude" "$HOME/.config" "$HOME/.local/bin" /etc /usr/local/bin)
SENS_FILES=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc" "$HOME/.zprofile")

sensitive_path() {
  local p
  [ -z "$1" ] && return 1
  for p in "${SENS_DIRS[@]}"; do [[ "$1" == "$p" || "$1" == "$p"/* ]] && return 0; done
  for p in "${SENS_FILES[@]}"; do [ "$1" = "$p" ] && return 0; done
  return 1
}

# word_sensitive <enc> <text> <dir>: the path names a sensitive path. An unresolvable
# path is not sensitive, and `-` is stdout.
word_sensitive() {
  [ "$2" = - ] && return 1
  resolve "$1" "$2" "$3" && sensitive_path "$RES_LOG"
}

# ---------------------------------------------------------------------------------------
# Directories and pipelines. Commands run in order; a cd or pushd moves the directory for
# later commands in the same list, and a nested list starts from its parent's directory.
# C_DIR is empty once the hook cannot follow a cd. `cd a || cd b` and backgrounded cds
# are treated as sequential.
# ---------------------------------------------------------------------------------------
NPIPE=0
for ((i = 0; i < NCMD; i++)); do
  l=${C_LIST[i]}
  if [ -z "${LIST_SEEN[l]}" ]; then
    LIST_SEEN[l]=1 LIST_LASTOP[l]=""
    p=${LIST_PARENT[l]}
    if [ "$p" = -1 ]; then LIST_DIR[l]=$CWD_N; else LIST_DIR[l]=${C_DIR[p]}; fi
  fi
  C_DIR[i]=${LIST_DIR[l]}
  case "${LIST_LASTOP[l]}" in
    '|'|'|&') C_PIPE[i]=${LIST_PIPE[l]} ;;
    *) C_PIPE[i]=$NPIPE LIST_PIPE[l]=$NPIPE NPIPE=$((NPIPE + 1)) ;;
  esac
  LIST_LASTOP[l]=${C_OP[i]}
  case "${C_NAME[i]}" in
    cd|pushd)
      w=${C_A0[i]} end=$((C_W0[i] + C_WN[i]))
      while [ "$w" -lt "$end" ] && [[ "${WT[w]}" == -[LPe@]* ]]; do w=$((w + 1)); done
      [ "$w" -lt "$end" ] && [ "${WT[w]}" = -- ] && w=$((w + 1))
      if [ "$w" -ge "$end" ]; then
        [ "${C_NAME[i]}" = cd ] && LIST_DIR[l]=$HOME || LIST_DIR[l]=""
      elif [ "${WT[w]}" = - ]; then
        LIST_DIR[l]=""
      elif resolve "${WE[w]}" "${WT[w]}" "${C_DIR[i]}"; then
        LIST_DIR[l]=$RES_LOG
      else
        LIST_DIR[l]=""
      fi
      ;;
    popd) LIST_DIR[l]="" ;;
  esac
done

# ---------------------------------------------------------------------------------------
# The exception: editing one issue or PR comment in place, the one gh REST write allowed.
# The call is that one command, optionally after one `cd <dir> &&` (gh picks its account
# from the repo it runs in), with only field arguments and the output-only options
# --jq/-q, --template/-t and --silent. A value may be plain, "double-quoted" (no $,
# backtick or backslash), or 'single-quoted', with an optional @.
# ---------------------------------------------------------------------------------------
CE_VAL='([[:alnum:]_.@/~:,+=-]+|@?"[^"$`\]*"|@?'"'"'[^'"'"']*'"'"')'
CE_OUT_VAL='([^[:space:];&|$`<>"'"'"']+|"[^"$`\]*"|'"'"'[^'"'"']*'"'"')'
CE_FIELD_RE="^[[:alnum:]_]+=${CE_VAL}\$"
CE_OUT_RE="^${CE_OUT_VAL}\$"
CE_ENDPOINT_RE='^/?repos/[[:alnum:]_.{}-]+/[[:alnum:]_.{}-]+/issues/comments/[0-9]+$'

plain_cmd() { # top level, no subshell, redirection or wrapper
  [ "${C_NAMEW[$1]}" != -1 ] && [ "${C_LIST[$1]}" = 0 ] && [ "${C_SUB[$1]}" = 0 ] && [ "${C_REDIR[$1]}" = 0 ] && [ "${C_SKIP[$1]}" = 0 ]
}

comment_edit() {
  [[ "$JOINED" == *$'\n'* ]] && return 1
  local g=0 w end
  if [ "$NCMD" = 2 ]; then
    plain_cmd 0 && [ "${WS[C_NAMEW[0]]}" = cd ] && [ "${C_WN[0]}" = 2 ] && [ "${C_OP[0]}" = "&&" ] \
      && [[ "${WS[C_A0[0]]}" =~ $CE_OUT_RE ]] || return 1
    g=1
  elif [ "$NCMD" != 1 ]; then
    return 1
  fi
  plain_cmd "$g" && [ "${C_OP[g]}" = "" ] && [ "${WS[C_NAMEW[g]]}" = gh ] || return 1
  w=${C_A0[g]} end=$((C_W0[g] + C_WN[g]))
  [ "${WS[w]}" = api ] || return 1
  case "${WS[w+1]}" in
    -XPATCH|--method=PATCH) w=$((w + 2)) ;;
    -X|--method) [ "${WS[w+2]}" = PATCH ] || return 1; w=$((w + 3)) ;;
    *) return 1 ;;
  esac
  [ "$w" -lt "$end" ] && [[ "${WS[w]}" =~ $CE_ENDPOINT_RE ]] || return 1
  w=$((w + 1))
  while [ "$w" -lt "$end" ]; do
    case "${WS[w]}" in
      -f|-F|--field|--raw-field) [ $((w + 1)) -lt "$end" ] && [[ "${WS[w+1]}" =~ $CE_FIELD_RE ]] || return 1; w=$((w + 2)) ;;
      --jq|-q|--template|-t) [ $((w + 1)) -lt "$end" ] && [[ "${WS[w+1]}" =~ $CE_OUT_RE ]] || return 1; w=$((w + 2)) ;;
      --silent) w=$((w + 1)) ;;
      *) return 1 ;;
    esac
  done
}
comment_edit && exit 0

# ---------------------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------------------

# Load command <i>'s arguments into AT (text), AE (encoding), AS (source), AN (count),
# and AW (the index of the first argument in WT/WE/WS).
load_args() {
  local w=${C_A0[$1]} end=$((C_W0[$1] + C_WN[$1])) k=0
  AT=() AE=() AS=()
  AW=$w
  while [ "$w" -lt "$end" ]; do
    AT[k]=${WT[w]} AE[k]=${WE[w]} AS[k]=${WS[w]}
    k=$((k + 1)) w=$((w + 1))
  done
  AN=$k
}

# Recursive rm: every operand through the workspace rule.
rule_rm() {
  local i=$1 k
  opt_walk "$AW" $((AW + AN)) "" ""
  [[ "$OW_FLAGS" == *[rR]* ]] || ow_has --recursive || return
  [ "${C_XARGS[i]}" = 1 ] && block "recursive rm with targets from xargs" "$H_XARGS"
  for k in "${OW_OPS[@]}"; do
    [ -z "${WT[k]}" ] && continue
    check_delete "${WE[k]}" "${WT[k]}" "${WS[k]}" "${C_DIR[i]}" "recursive rm" 0
  done
}

# find deletes: -delete, or -exec / -execdir rm. Start paths go through the workspace
# rule; the working directory itself is fine as a start path when a name or path test
# narrows the matches. Literal rm operands are deleted as written, so they go through the
# workspace rule too.
rule_find() {
  local i=$1 k=0 t follow=0 hflag=0 narrow=0 del=0 starts=() rmops=() rmmode=() mode j
  while [ "$k" -lt "$AN" ]; do
    case "${AT[k]}" in
      -H) hflag=1 ;;
      -L) follow=1 ;;
      -P|-O*) ;;
      -D) k=$((k + 1)) ;;
      *) break ;;
    esac
    k=$((k + 1))
  done
  while [ "$k" -lt "$AN" ]; do
    case "${AT[k]}" in -*|'('|'!'|')') break ;; esac
    starts+=("$k")
    k=$((k + 1))
  done
  while [ "$k" -lt "$AN" ]; do
    t=${AT[k]}
    case "$t" in
      -delete) del=1 ;;
      -follow) follow=1 ;;
      -name|-iname|-path|-ipath|-wholename|-iwholename|-regex|-iregex) narrow=1; k=$((k + 1)) ;;
      # Primaries whose value is data, from GNU find(1).
      -amin|-anewer|-atime|-cmin|-cnewer|-ctime|-context|-files0-from|-fls|-fprint|-fprint0|\
      -fstype|-gid|-group|-ilname|-inum|-links|-lname|-maxdepth|-mindepth|-mmin|-mtime|\
      -newer|-newer[aBcmt][aBcmt]|-perm|-printf|-regextype|-samefile|-size|-type|-uid|\
      -used|-user|-xtype) k=$((k + 1)) ;;
      -fprintf) k=$((k + 2)) ;;
      -exec|-execdir|-ok|-okdir)
        mode=$t k=$((k + 1))
        j=$k
        while [ "$k" -lt "$AN" ] && [ "${AT[k]}" != ';' ] && [ "${AT[k]}" != '+' ]; do k=$((k + 1)); done
        if [[ "$mode" == -exec* && "${AT[j]##*/}" == rm ]]; then
          del=1 j=$((j + 1))
          while [ "$j" -lt "$k" ] && [[ "${AT[j]}" == -?* ]]; do
            [ "${AT[j]}" = -- ] && { j=$((j + 1)); break; }
            j=$((j + 1))
          done
          for ((; j < k; j++)); do rmops+=("$j") rmmode+=("$mode"); done
        fi
        ;;
    esac
    k=$((k + 1))
  done
  [ "$del" = 1 ] || return
  [ "$follow" = 1 ] && block "find delete that follows symlinks"
  if [ ${#starts[@]} = 0 ]; then
    [ "$narrow" = 1 ] && [ "${C_DIR[i]}" = "$CWD_N" ] || check_delete . . . "${C_DIR[i]}" "find delete" "$hflag"
  fi
  for k in "${starts[@]}"; do
    if [ "$narrow" = 1 ] && resolve "${AE[k]}" "${AT[k]}" "${C_DIR[i]}" && [ "$RES_LOG" = "$CWD_N" ]; then
      continue
    fi
    check_delete "${AE[k]}" "${AT[k]}" "${AS[k]}" "${C_DIR[i]}" "find delete" "$hflag"
  done
  for ((j = 0; j < ${#rmops[@]}; j++)); do
    k=${rmops[j]} t=${AT[k]}
    [ "$t" = '{}' ] && continue
    [[ "$t" == *'{}'* ]] && block "find -exec rm operand built from {}: ${AS[k]}" "$H_FINDOP"
    # Under -execdir the operand is relative to each match's directory.
    if [ "${rmmode[j]}" = -execdir ]; then
      resolve "${AE[k]}" "$t" "" || block "find delete with a target the hook cannot resolve: ${AS[k]}" "$H_LITERAL"
      check_delete "${AE[k]}" "$t" "${AS[k]}" "" "find delete" 0
    else
      check_delete "${AE[k]}" "$t" "${AS[k]}" "${C_DIR[i]}" "find delete" 0
    fi
  done
}

rule_git() {
  local i=$1 end=$((AW + AN)) k sub="" vs="" vl="" repo=${C_DIR[$1]}
  opt_walk "$AW" "$end" Cc "--git-dir --work-tree --namespace" stop
  sub=${WT[OW_NEXT]}
  [ "$OW_NEXT" -lt "$end" ] || sub=""
  k=$OW_NEXT
  local j
  for ((j = 0; j < ${#OW_NAME[@]}; j++)); do
    ow_value "$j" || continue
    case "${OW_NAME[j]}" in
      -C) if resolve "$OWE" "$OWV" "$repo"; then repo=$RES_LOG; else repo=""; fi ;;
      -c)
        shopt -s nocasematch
        [[ "${OWV%%=*}" == core.hookspath ]] && { shopt -u nocasematch; block "git -c core.hooksPath (skips git hooks)" "$H_HOOKS"; }
        shopt -u nocasematch
        ;;
    esac
  done

  # Only words before -- that are not an option's value are options. The value-taking
  # options per subcommand come from `git <sub> -h`.
  case "$sub" in
    commit) vs=FmcCtU vl="--file --author --date --message --reedit-message --reuse-message --squash --fixup --trailer --template --cleanup --unified --inter-hunk-context --pathspec-from-file" ;;
    merge) vs=sXmF vl="--cleanup --strategy --strategy-option --message --file --into-name" ;;
    push) vs=o vl="--repo --receive-pack --exec --push-option" ;;
    rebase) vs=CxsX vl="--onto --whitespace --exec --strategy --strategy-option" ;;
    am) vs=Cp vl="--quoted-cr --whitespace --directory --exclude --include --patch-format --resolvemsg" ;;
    cherry-pick|revert) vs=mX vl="--cleanup --mainline --strategy --strategy-option" ;;
  esac
  opt_walk $((k + 1)) "$end" "$vs" "$vl"

  # Skipping git hooks. -n is --no-verify only in commit and am.
  ow_has --no-verify && block "git --no-verify (skips git hooks)" "$H_HOOKS"
  [[ "$sub" =~ ^(commit|am)$ && "$OW_FLAGS" == *n* ]] && block "git $sub -n (skips git hooks)" "$H_HOOKS"

  case "$sub" in
    reset) ow_has --hard && block "git reset --hard" ;;
    clean) ow_flag f --force && block "git clean -f" ;;
    branch)
      [[ "$OW_FLAGS" == *D* ]] && block "git branch -D"
      ow_flag d --delete && ow_flag f --force && block "git branch -D"
      ;;
    checkout|restore)
      [ "$sub" = restore ] && ow_flag S --staged && ! ow_flag W --worktree && return
      for k in "${OW_OPS[@]}"; do
        case "${WT[k]}" in .|./|:/) block "git checkout . or git restore . (discards all changes)" ;; esac
      done
      ;;
    push) rule_push "$repo" ;;
  esac
}

LEASE_RE='^([^:]+):[0-9a-fA-F]{7,40}$'

# Force pushes, pushes to main or master, and remote branch deletes without a lease.
rule_push() {
  local repo=$1 k r d refs=() leases=() deleted=() delete=0 leased l branch
  # refs[0] is the remote; with --repo every operand is a refspec.
  ow_has --repo && refs=("")
  for k in "${OW_OPS[@]}"; do refs+=("${WT[k]}"); done
  ow_flag f --force && block "git push --force"
  ow_flag d --delete && delete=1
  for ((k = 0; k < ${#OW_NAME[@]}; k++)); do
    [ "${OW_NAME[k]}" = --force-with-lease ] || continue
    ow_value "$k"
    leases+=("$OWV")
  done
  for r in "${refs[@]:1}"; do
    [[ "$r" == +* ]] && block "git push with a +refspec (force push)"
  done
  for r in "${refs[@]:1}"; do
    d=$r
    [[ "$d" == *:* ]] && d=${d##*:}
    d=${d#refs/heads/}
    [[ "$d" == main || "$d" == master ]] && block "git push to main or master"
  done

  # A remote branch delete removes whatever the branch points at, so each needs a lease
  # naming the commit it is expected to be at. A lease on anything else rewrites it.
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
      [ "$leased" = 1 ] || block "git push --delete without a lease on $r" "$H_LEASE"
    done
  elif [ "${#leases[@]}" -gt 0 ]; then
    block "git push --force-with-lease outside a branch delete"
  fi

  # A plain `git push` (or `git push <remote> HEAD`) pushes the current branch.
  if [ "${#refs[@]}" -le 1 ] || { [ "${#refs[@]}" = 2 ] && [ "${refs[1]}" = HEAD ]; }; then
    branch=$(git -C "${repo:-$CWD}" symbolic-ref --short -q HEAD 2>/dev/null)
    [[ "$branch" == main || "$branch" == master ]] && block "git push while on $branch"
  fi
}

rule_gh() {
  local k end=$((AW + AN)) method="" field=0
  case "${AT[0]} ${AT[1]}" in
    "auth login"|"auth logout"|"auth refresh"|"auth switch"|"auth setup-git")
      block "gh auth ${AT[1]} (changes login state)"
      ;;
    "pr review")
      opt_walk $((AW + 2)) "$end" bFR "--body --body-file --repo"
      ow_flag a --approve && block "gh pr review --approve"
      ;;
    "pr merge")
      opt_walk $((AW + 2)) "$end" bFtR "--body --body-file --subject --repo --match-head-commit --author-email"
      ow_has --admin && block "gh pr merge --admin"
      ;;
    "api "*)
      opt_walk $((AW + 1)) "$end" XfFHqtp "--method --field --raw-field --input --header --jq --template --preview --hostname --cache"
      for ((k = 0; k < ${#OW_NAME[@]}; k++)); do
        case "${OW_NAME[k]}" in
          -X|--method) ow_value "$k" && method=$OWV ;;
          -f|-F|--field|--raw-field|--input) field=1 ;;
        esac
      done
      shopt -s nocasematch
      case "$method" in
        post) method=POST ;;
        put) method=PUT ;;
        patch) method=PATCH ;;
        delete) method=DELETE ;;
        *) method=${method:+other} ;;
      esac
      shopt -u nocasematch
      [ "$method" = other ] || [ -z "$method" ] || block "gh api REST write ($method)"
      [ -z "$method" ] && [ "$field" = 1 ] \
        && block "gh api with field arguments and no -X GET (an implicit POST)" "$H_GHGET"
      ;;
  esac
}

URL_HOST_RE='^[[:alpha:]][[:alnum:]+.-]*://([^/[:space:]"'"'"'?#]*)'
LOOPBACK_RE='^(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?$'

loopback_url() { # <url>
  [[ "$1" =~ $URL_HOST_RE ]] && [[ "${BASH_REMATCH[1]##*@}" =~ $LOOPBACK_RE ]]
}

# Exit 0 when this curl or wget command, after opt_walk, names at least one destination
# (a URL operand or --url value) and every one is a loopback URL with a scheme. Options
# that send the request elsewhere (a proxy, a redirected address, a config file or wget
# -e) rule the exemption out. <options that reroute>
only_loopback_urls() {
  local k seen=0
  for k in "${OW_NAME[@]}"; do [[ "$1" == *" $k "* ]] && return 1; done
  for ((k = 0; k < ${#OW_NAME[@]}; k++)); do
    [ "${OW_NAME[k]}" = --url ] || continue
    ow_value "$k"
    loopback_url "$OWV" || return 1
    seen=1
  done
  for k in "${OW_OPS[@]}"; do loopback_url "${WT[k]}" || return 1; seen=1; done
  [ "$seen" = 1 ]
}
CURL_REROUTE=" -x --proxy --preproxy --socks4 --socks4a --socks5 --socks5-hostname --connect-to --resolve -K --config "
WGET_REROUTE=" -e --execute -i --input-file "

# A path a curl or wget command writes, for download then execute: DL_PATH (resolved),
# DL_CMD, DL_SRC.
DL_PATH=() DL_CMD=() DL_SRC=()
add_download() { # <cmd> <dir the path is relative to>, after ow_value
  [ "$OWV" = - ] && return
  resolve "$OWE" "$OWV" "$2" || return
  DL_PATH+=("$RES_LOG") DL_CMD+=("$1") DL_SRC+=("$OWS")
}
FORM_FILE_RE='^[^=]*=[@<]'
URLENCODE_FILE_RE='^[^=@]*@'

CURL_VALUE_SHORT=AbcCdDeEFHKmoPQrtTuUwxXyYz
CURL_VALUE_LONG="--output --output-dir --data --data-binary --data-ascii --data-raw --data-urlencode --json --form --form-string --upload-file --header --user --request --url --user-agent --referer --cookie --cookie-jar --config --max-time --connect-timeout --retry --proxy --preproxy --socks4 --socks4a --socks5 --socks5-hostname --connect-to --resolve --write-out --range --cacert --cert --key"
WGET_VALUE_SHORT=OoaPtTwQUeiBlARDIXn
WGET_VALUE_LONG="--output-document --directory-prefix --post-file --body-file --header --user --password --output-file --append-output --tries --timeout --user-agent --method --body-data --post-data --execute --input-file"

# Uploads, downloads into sensitive paths, and the outputs download then execute follows.
rule_curl() {
  local i=$1 k up="" outdir=0 od_e od_t remote=0 base=${C_DIR[$1]}
  opt_walk "$AW" $((AW + AN)) "$CURL_VALUE_SHORT" "$CURL_VALUE_LONG"
  # curl writes every -o path inside --output-dir, wherever the two appear.
  for ((k = 0; k < ${#OW_NAME[@]}; k++)); do
    [ "${OW_NAME[k]}" = --output-dir ] || continue
    ow_value "$k"
    outdir=1 od_e=$OWE od_t=$OWV base=""
    resolve "$OWE" "$OWV" "${C_DIR[i]}" && base=$RES_LOG
  done
  for ((k = 0; k < ${#OW_NAME[@]}; k++)); do
    ow_value "$k"
    case "${OW_NAME[k]}" in
      -d|--data|--data-binary|--data-ascii|--json) [[ "$OWV" == @* ]] && up="curl request body read from a file" ;;
      --data-urlencode) [[ "$OWV" =~ $URLENCODE_FILE_RE ]] && up="curl --data-urlencode read from a file" ;;
      -F|--form) [[ "$OWV" =~ $FORM_FILE_RE ]] && up="curl form field read from a file" ;;
      -T|--upload-file) up="curl file upload" ;;
      -o|--output)
        word_sensitive "$OWE" "$OWV" "$base" && block "curl download into a sensitive path" "$H_DLDIR"
        add_download "$i" "$base"
        ;;
      --remote-name|--remote-name-all) remote=1 ;;
    esac
  done
  [[ "$OW_FLAGS" == *O* ]] && remote=1
  [ -n "$up" ] && ! only_loopback_urls "$CURL_REROUTE" && block "$up" "$H_UPLOAD"
  if [ "$outdir" = 1 ]; then
    word_sensitive "$od_e" "$od_t" "${C_DIR[i]}" && block "curl download into a sensitive directory" "$H_DLDIR"
  elif [ "$remote" = 1 ]; then
    sensitive_path "${C_DIR[i]}" && block "curl download into a sensitive directory" "$H_DLDIR"
  fi
}

rule_wget() {
  local i=$1 k out=0 dir=0 d_e d_t
  opt_walk "$AW" $((AW + AN)) "$WGET_VALUE_SHORT" "$WGET_VALUE_LONG"
  for ((k = 0; k < ${#OW_NAME[@]}; k++)); do
    ow_value "$k"
    case "${OW_NAME[k]}" in
      --post-file|--body-file) only_loopback_urls "$WGET_REROUTE" || block "wget request body read from a file" "$H_UPLOAD" ;;
      -O|--output-document)
        out=1
        word_sensitive "$OWE" "$OWV" "${C_DIR[i]}" && block "wget download into a sensitive path" "$H_DLDIR"
        add_download "$i" "${C_DIR[i]}"
        ;;
      -P|--directory-prefix) dir=1 d_e=$OWE d_t=$OWV ;;
    esac
  done
  [ "$out" = 1 ] && return
  if [ "$dir" = 1 ]; then
    word_sensitive "$d_e" "$d_t" "${C_DIR[i]}" && block "wget download into a sensitive directory" "$H_DLDIR"
  else
    sensitive_path "${C_DIR[i]}" && block "wget download into a sensitive directory" "$H_DLDIR"
  fi
}

PKG_VALUE_LONG="--workspace --prefix --filter --dir --cwd --loglevel --index-url --extra-index-url --registry --tag"
PKG_INSTALL_RE='^(install|i|add|ci|update|upgrade|up)$'
OWNER_REPO_RE='^[[:alnum:]_][[:alnum:]_.-]*/[[:alnum:]_.-]+([#@].*)?$'

# pkg_parse <short value letters>: PSUB is the subcommand's word index (-1 for none), and
# POPS the operand indices after it.
pkg_parse() {
  opt_walk "$AW" $((AW + AN)) "$1" "$PKG_VALUE_LONG"
  PSUB=${OW_OPS[0]:--1} POPS=("${OW_OPS[@]:1}")
}

custom_source() {
  ow_has --index-url || ow_has --extra-index-url || ow_has --registry
}

# Risky package installs.
rule_pip() {
  local k sub
  pkg_parse wCi
  [ "$PSUB" = -1 ] && return
  sub=${WT[PSUB]}
  if [ "$sub" = install ]; then
    for k in "${POPS[@]}"; do
      [[ "${WT[k]}" == git+* || "${WT[k]}" == http://* || "${WT[k]}" == https://* ]] \
        && block "pip install from a URL or git" "$H_SRC_CLONE"
    done
  fi
  [[ "$sub" =~ $PKG_INSTALL_RE ]] && { custom_source || ow_has -i; } && block "custom package source" "$H_SRC"
}

rule_js() {
  local i=$1 k t sub
  pkg_parse wC
  [ "$PSUB" = -1 ] && return
  sub=${WT[PSUB]}
  if [[ "$sub" =~ ^(install|i|add)$ ]]; then
    for k in "${POPS[@]}"; do
      t=${WT[k]}
      case "$t" in
        github:*|git+*|git://*|http://*|https://*) block "package install from a URL or git" "$H_SRC_CLONE" ;;
      esac
      [[ "$t" =~ $OWNER_REPO_RE ]] && block "package install from a GitHub owner/repo" "$H_SRC_CLONE"
    done
    [ "${C_NAME[i]}" != yarn ] && ow_flag g --global \
      && block "global package install (npm, pnpm, bun or yarn)" "$H_NPX"
  fi
  [ "${C_NAME[i]}" = yarn ] && [ "$sub" = global ] && [ ${#POPS[@]} -gt 0 ] && [ "${WT[POPS[0]]}" = add ] \
    && block "global package install (npm, pnpm, bun or yarn)" "$H_NPX"
  [[ "$sub" =~ $PKG_INSTALL_RE ]] && custom_source && block "custom package source" "$H_SRC"
}

FETCH_CMDS=()
for ((i = 0; i < NCMD; i++)); do
  load_args "$i"
  case "${C_NAME[i]}" in
    rm) rule_rm "$i" ;;
    find) rule_find "$i" ;;
    git) rule_git "$i" ;;
    gh) rule_gh "$i" ;;
    curl) FETCH_CMDS+=("$i"); rule_curl "$i" ;;
    wget) FETCH_CMDS+=("$i"); rule_wget "$i" ;;
    pip|pip3) rule_pip "$i" ;;
    npm|pnpm|yarn|bun) rule_js "$i" ;;
    cargo|pipx) [ "${AT[0]}" = install ] && block "global package install (cargo, pipx or go)" ;;
    go)
      if [ "${AT[0]}" = install ]; then
        for ((k = 1; k < AN; k++)); do
          [[ "${AT[k]}" != -* && "${AT[k]}" == *@* ]] && block "global package install (cargo, pipx or go)"
        done
      fi
      ;;
  esac
done
[ ${#FETCH_CMDS[@]} = 0 ] && exit 0

# ---------------------------------------------------------------------------------------
# Rules on how commands relate, for calls that run curl or wget.
# ---------------------------------------------------------------------------------------

# Exit 0 when list <l>, or a list nested in it, runs curl or wget.
list_fetches() {
  local j l p
  for j in "${FETCH_CMDS[@]}"; do
    l=${C_LIST[j]}
    while :; do
      [ "$l" = "$1" ] && return 0
      p=${LIST_PARENT[l]}
      [ "$p" = -1 ] && break
      l=${C_LIST[p]}
    done
  done
  return 1
}

# Exit 0 when word <w> holds a substitution that runs curl or wget.
word_fetches() {
  local e=${WE[$1]}
  while [[ "$e" =~ $SUBST_RE ]]; do
    list_fetches "${BASH_REMATCH[1]}" && return 0
    e=${e#*"${BASH_REMATCH[0]}"}
  done
  return 1
}

# Running downloaded code: piped into an interpreter reading stdin, or given to one
# through <(...), source, or a -c script built by $(...).
for j in "${FETCH_CMDS[@]}"; do
  for ((i = j + 1; i < NCMD; i++)); do
    [ "${C_LIST[i]}" = "${C_LIST[j]}" ] && [ "${C_PIPE[i]}" = "${C_PIPE[j]}" ] || continue
    [[ "${C_NAME[i]}" =~ $INTERP_RE && "${C_STDIN[i]}" = 1 ]] \
      && block "curl or wget output run by an interpreter" "$H_DLRUN"
  done
done
for ((i = 0; i < NCMD; i++)); do
  if [[ "${C_NAME[i]}" =~ $INTERP_RE ]]; then
    { [ "${C_SCRIPTW[i]}" != -1 ] && word_fetches "${C_SCRIPTW[i]}"; } \
      || { [ "${C_CODEW[i]}" != -1 ] && word_fetches "${C_CODEW[i]}"; } \
      && block "curl or wget output run by an interpreter" "$H_DLRUN"
  elif [[ "${C_NAME[i]}" == source || "${C_NAME[i]}" == . ]] && [ "${C_WN[i]}" -gt $((C_SKIP[i] + 1)) ]; then
    word_fetches "${C_A0[i]}" && block "curl or wget output run by an interpreter" "$H_DLRUN"
  fi
done

# Download then execute: a later command runs a file curl or wget wrote, as an
# interpreter's script, as its command word, or by making it executable.
CHMOD_X_RE='(^|,)[ugoa]*\+[rwxXst]*x'
same_download() { # <word index> <cmd> <download>
  resolve "${WE[$1]}" "${WT[$1]}" "${C_DIR[$2]}" && [ "$RES_LOG" = "${DL_PATH[$3]}" ]
}
for ((d = 0; d < ${#DL_PATH[@]}; d++)); do
  for ((i = DL_CMD[d] + 1; i < NCMD; i++)); do
    why="download then execute: ${DL_SRC[d]}"
    [[ "${C_NAME[i]}" =~ $INTERP_RE && "${C_SCRIPTW[i]}" != -1 ]] && same_download "${C_SCRIPTW[i]}" "$i" "$d" \
      && block "$why" "$H_DLRUN"
    [ "${C_NAMEW[i]}" != -1 ] && [[ "${WT[C_NAMEW[i]]}" == */* ]] && same_download "${C_NAMEW[i]}" "$i" "$d" \
      && block "$why" "$H_DLRUN"
    if [ "${C_NAME[i]}" = chmod ]; then
      load_args "$i"
      mode=0
      for ((k = 0; k < AN; k++)); do
        if [ "$mode" = 0 ]; then
          t=${AT[k]}
          if [[ "$t" =~ $CHMOD_X_RE ]] || { [[ "$t" =~ ^[0-7]{3,4}$ ]] && [[ "${t:${#t}-3}" == *[1357]* ]]; }; then
            mode=1
          fi
          continue
        fi
        same_download $((AW + k)) "$i" "$d" && block "$why" "$H_DLRUN"
      done
    fi
  done
done

# Secrets in a call that makes a network request: a variable bash expands with a
# secret-looking name, or a command that prints a token. No host is exempt.
SECRET_PART_RE='^(TOKENS?|SECRETS?|PASSWORD|PASSWD|PASS|KEYS?|APIKEY|AUTH|AUTHORIZATION|CREDENTIALS?)$'
PUBLIC_PART_RE='^(PUBLIC|PUBLISHABLE)$'

# Exit 0 when a _-separated part of the name, in any case, is a secret word and no part
# is PUBLIC or PUBLISHABLE. Whole parts only: NEXTAUTH_URL and BYPASS_CACHE do not match.
secret_looking() {
  local IFS=_ part secret=1 parts
  parts=($1)
  shopt -s nocasematch
  for part in "${parts[@]}"; do
    [[ "$part" =~ $PUBLIC_PART_RE ]] && { secret=1; break; }
    [[ "$part" =~ $SECRET_PART_RE ]] && secret=0
  done
  shopt -u nocasematch
  return "$secret"
}

for ((i = 0; i < NCMD; i++)); do
  load_args "$i"
  case "${C_NAME[i]} ${AT[0]} ${AT[1]}" in
    "gh auth token"|"gcloud auth print-access-token"|"gcloud auth print-identity-token"| \
    "az account get-access-token"|"aws configure get"|"aws configure export-credentials"| \
    "aws sts get-session-token"|"op read "*|"op item get"|"pass show "*|"vault read "*| \
    "vault kv get"|"kubectl get secret"|"kubectl get secrets"|"git credential fill"| \
    "security find-generic-password "*)
      block "token-printing command in a call that runs curl or wget" "$H_SECRET" ;;
  esac
done
for v in "${VARS[@]}"; do
  secret_looking "$v" && block "secret-looking variable \$$v in a call that runs curl or wget" "$H_SECRET"
done

exit 0
