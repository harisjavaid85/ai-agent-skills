#!/usr/bin/env bash

set -euo pipefail

readonly MAX_REVIEWS=5
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly REVIEW_INSTRUCTIONS="$SCRIPT_DIR/../REVIEW-INSTRUCTIONS.md"
readonly REVISION_INSTRUCTIONS="$SCRIPT_DIR/../REVISION-INSTRUCTIONS.md"

# The Reviewer's model and effort when start is given none, per harness.
readonly CODEX_DEFAULT_MODEL=gpt-6-astra
readonly CODEX_DEFAULT_EFFORT=high
readonly CLAUDE_DEFAULT_MODEL=claude-opus-5-5
readonly CLAUDE_DEFAULT_EFFORT=high

usage() {
  cat <<'EOF'
Usage:
  review.sh start  --packet PATH --output PATH
                   --author requester|user|external
                   --requester-harness codex|claude|unknown
                   --requester-model MODEL|unknown --requester-effort LEVEL|unknown
                   [--harness codex|claude] [--model MODEL] [--effort LEVEL]
  review.sh resume --session-id ID --packet PATH --output PATH

Runs one read-only review round by the Reviewer, captures its final response,
and prints:
  SESSION_ID=<id>
  NEEDS_REVISION=<count>
  NEEDS_USER_DECISION=<count>
  REVIEW_FILE=<path>

Reviewer defaults when start omits them: harness codex; model gpt-6-astra for
codex and claude-opus-5-5 for claude; effort high. The model and effort are
passed to the harness unchanged.

The review state (.review-state beside the review file) records the session,
the review count, the Author, the Requester's harness, model, and effort as
stated, the Reviewer's harness, model, and effort as used, and
REVIEWER_MODEL_RESOLVED, the model the harness reported running (empty when it
reported none). Everything but the count is set on start; resume reads it from
the state, so a review session keeps the same Reviewer for every round.

CROSS_CHECK_REVIEWER_SANDBOX says what isolates a Codex Reviewer:
  native    (default) Codex's own read-only sandbox, which must start
  external  the caller already isolates this process, so Codex runs without one
A Claude Reviewer is held read-only by its permissions either way. In every case,
a round that changes the working tree, index, branch, or HEAD fails and is undone.
EOF
}

fail() {
  printf 'review: %s\n' "$*" >&2
  exit 1
}

require_value() {
  local option=$1
  local value=${2:-}
  [[ -n "$value" ]] || fail "$option requires a value"
}

absolute_path() {
  local path=$1
  local directory
  directory=$(cd "$(dirname "$path")" && pwd)
  printf '%s/%s\n' "$directory" "$(basename "$path")"
}

extract_counter() {
  local name=$1
  local review_file=$2
  local matches

  matches=$(grep -Ec "^${name}: [0-9]+$" "$review_file" || true)
  [[ "$matches" -eq 1 ]] || return 1
  grep -E "^${name}: [0-9]+$" "$review_file" | awk '{print $2}'
}

# Every key is written even when empty, so a resume can tell an unresolved model
# from a corrupt state file.
write_state() {
  local review_count=$1

  {
    printf 'SESSION_ID=%s\n' "$session_id"
    printf 'REVIEW_COUNT=%s\n' "$review_count"
    printf 'AUTHOR=%s\n' "$author"
    printf 'REQUESTER_HARNESS=%s\n' "$requester_harness"
    printf 'REQUESTER_MODEL=%s\n' "$requester_model"
    printf 'REQUESTER_EFFORT=%s\n' "$requester_effort"
    printf 'REVIEWER_HARNESS=%s\n' "$harness"
    printf 'REVIEWER_MODEL=%s\n' "$model"
    printf 'REVIEWER_EFFORT=%s\n' "$effort"
    printf 'REVIEWER_MODEL_RESOLVED=%s\n' "$resolved_model"
  } >"$state_file"
}

read_state_value() {
  local state_file=$1
  local name=$2
  local value

  value=$(grep -E "^${name}=" "$state_file" | head -n 1 | cut -d= -f2-)
  [[ -n "$value" ]] || fail "$state_file does not contain $name"
  printf '%s\n' "$value"
}

read_optional_state_value() {
  local state_file=$1
  local name=$2

  grep -qE "^${name}=" "$state_file" || fail "$state_file does not contain $name"
  grep -E "^${name}=" "$state_file" | head -n 1 | cut -d= -f2-
}

validate_harness() {
  case "$1" in
    codex | claude) ;;
    *) fail "$2 must be 'codex' or 'claude', not '$1'" ;;
  esac
}

validate_author() {
  case "$1" in
    requester | user | external) ;;
    *) fail "$2 must be 'requester', 'user', or 'external', not '$1'" ;;
  esac
}

validate_requester_harness() {
  case "$1" in
    codex | claude | unknown) ;;
    *) fail "$2 must be 'codex', 'claude', or 'unknown', not '$1'" ;;
  esac
}

# A tree of the whole working tree, untracked files included, built in a scratch
# index so the real one is untouched. The review directory is left out: this
# script and the Reviewer write the round's own records there.
worktree_tree() {
  local index tree
  index=$(mktemp)
  cp "$(git rev-parse --git-path index)" "$index" 2>/dev/null || rm -f "$index"
  if ! tree=$(
    GIT_INDEX_FILE=$index git add -A 2>/dev/null &&
      GIT_INDEX_FILE=$index git rm -r -q --cached --ignore-unmatch -- "$review_dir" &&
      GIT_INDEX_FILE=$index git write-tree
  ); then
    rm -f "$index"
    return 1
  fi
  rm -f "$index"
  printf '%s\n' "$tree"
}

# Each entry's mode, object, stage, and path, read without writing the index.
# Raw bytes would not do: a read-only `git status` rewrites the stat cache.
index_fingerprint() {
  git ls-files --stage -z | sha256sum
}

# The round's starting point: branch, HEAD, working tree, and index, so a review
# that changes any of them can be detected and put back.
snapshot_repo() {
  before_ref=$(git symbolic-ref -q HEAD || printf detached)
  before_head=$(git rev-parse -q --verify HEAD || printf none)
  index_saved=0
  cp "$(git rev-parse --git-path index)" "$index_backup" 2>/dev/null && index_saved=1
  before_index=$(index_fingerprint)
  before_tree=$(worktree_tree) || fail "cannot snapshot the working tree before the review"
}

# Puts the repository back to the snapshot. It assumes nothing but the Reviewer
# touched the repository during the round, which holds while the caller waits on it.
restore_repo() {
  local after_tree=$1 top
  top=$(git rev-parse --show-toplevel) || return 1
  if [[ "$before_ref" == detached ]]; then
    [[ "$before_head" == none ]] || git update-ref --no-deref HEAD "$before_head" || return 1
  else
    git symbolic-ref HEAD "$before_ref" || return 1
    [[ "$before_head" == none ]] || git update-ref "$before_ref" "$before_head" || return 1
  fi
  if [[ "$index_saved" == 1 ]]; then
    cp "$index_backup" "$(git rev-parse --git-path index)" || return 1
  else
    rm -f -- "$(git rev-parse --git-path index)" || return 1
  fi
  (
    cd "$top" &&
      git diff -z --name-only --no-renames --diff-filter=A "$before_tree" "$after_tree" | xargs -0 -r rm -f -- &&
      git diff -z --name-only --no-renames --diff-filter=MDT "$before_tree" "$after_tree" |
      xargs -0 -r git restore --source="$before_tree" --worktree --
  )
}

# The read-only promise is checked here rather than trusted, because no harness
# setting enforces it everywhere. A broken promise is undone, then fails the
# round. $1 is the Reviewer's exit status: a Reviewer that changed the
# repository and then failed is reported as both, the change first.
require_unchanged() {
  local status=${1:-0} after_ref after_head after_tree changes= what
  after_ref=$(git symbolic-ref -q HEAD || printf detached)
  after_head=$(git rev-parse -q --verify HEAD || printf none)
  after_tree=$(worktree_tree) || fail "cannot snapshot the working tree after the review"
  if [[ "$after_ref" != "$before_ref" || "$after_head" != "$before_head" ]]; then
    changes+="  HEAD: $before_ref at $before_head became $after_ref at $after_head"$'\n'
  fi
  if [[ "$after_tree" != "$before_tree" ]]; then
    changes+=$(git diff --name-status --no-renames "$before_tree" "$after_tree" | head -n 20 | sed 's/^/  /')$'\n'
  fi
  if [[ "$(index_fingerprint)" != "$before_index" ]]; then
    changes+="  index: staged changes differ from before the review"$'\n'
  fi
  [[ -n "$changes" ]] || return 0
  changes=${changes%$'\n'}
  what="the reviewer changed the repository during the review"
  [[ "$status" == 0 ]] || what="the reviewer exited with status $status and changed the repository during the review"
  restore_repo "$after_tree" ||
    fail "$what, and restoring it failed; check git status:"$'\n'"$changes"
  [[ "$status" == 0 ]] ||
    fail "$what; restored to the state before the round:"$'\n'"$changes"$'\n'"failure output was preserved in $review_dir"
  fail "$what, so it was not read-only. Restored to the state before the round:"$'\n'"$changes"
}

# Runs one round through the harness adapter. A failed round's output is kept
# before the repository check, so a Reviewer that edits and then crashes is
# still undone and still leaves its evidence.
run_round() {
  local status=0
  snapshot_repo
  "${harness}_run_$mode" <"$prompt_file" || status=$?
  if [[ "$status" != 0 ]]; then
    cp "$events_file" "$review_dir/review-${review_count}.failure.events.jsonl"
    cp "$stderr_file" "$review_dir/review-${review_count}.failure.stderr.log"
  fi
  require_unchanged "$status"
  [[ "$status" == 0 ]] || fail "$harness $mode failed; failure output was preserved in $review_dir"
}

# Harness adapters. Each harness supplies <harness>_preflight, _run_start,
# _run_resume, and _resolve_model. A run_* reads the prompt on stdin, writes the
# Reviewer's final message to $output, leaves the session ID in $session_id, and
# returns non-zero when the CLI failed.

codex_preflight() {
  case "$sandbox" in
    native)
      codex_start_sandbox=(--sandbox read-only)
      # `exec resume` has no --sandbox flag, so the policy is pinned by config.
      codex_resume_sandbox=(--config 'sandbox_mode="read-only"')
      # A sandbox that cannot start does not fail `codex exec`: Codex reports the
      # blocked commands and still exits 0, having read nothing.
      codex sandbox -- true >/dev/null 2>"$stderr_file" ||
        fail "Codex's reviewer sandbox cannot start here: $(head -n 1 "$stderr_file")"$'\n'"This is the caller's configuration to fix: CROSS_CHECK_REVIEWER_SANDBOX=external is only for a caller that already isolates the review, such as a container."
      ;;
    external)
      codex_start_sandbox=(--dangerously-bypass-approvals-and-sandbox)
      codex_resume_sandbox=("${codex_start_sandbox[@]}")
      ;;
  esac
  codex_options=(--json --output-last-message "$output" --model "$model"
    --config "model_reasoning_effort=\"$effort\"")
}

codex_run_start() {
  codex exec "${codex_start_sandbox[@]}" "${codex_options[@]}" - >"$events_file" 2>"$stderr_file" || return
  session_id=$(jq -r 'select(.type == "thread.started") | .thread_id // empty' "$events_file" | head -n 1)
}

codex_run_resume() {
  codex exec resume "${codex_resume_sandbox[@]}" "${codex_options[@]}" "$session_id" - >"$events_file" 2>"$stderr_file"
}

# `--json` output omits the model; the session rollout records it. The rollout
# format is internal and undocumented, so any failure here is silent.
codex_resolve_model() {
  local rollout
  rollout=$(find "${CODEX_HOME:-$HOME/.codex}/sessions" -name "*-${session_id}.jsonl" -print -quit 2>/dev/null) || return 0
  [[ -n "$rollout" ]] || return 0
  jq -r 'select(.type == "turn_context") | .payload.model // empty' "$rollout" 2>/dev/null | tail -n 1 || true
}

# --permission-mode dontAsk: the harness denies, without prompting, every tool
#   call that is neither read-only nor pre-approved by an allow rule. (`plan` mode
#   only asks the model to refrain.)
# --setting-sources "": no settings file loads, so no allow rule can pre-approve
#   a write or an outward action such as posting to GitHub, which the repository
#   check could neither see nor undo.
# --disallowedTools: the file-writing tools are not offered at all.
# A denied tool call does not fail `claude -p`; the review goes on, and the
# repository check stays the arbiter.
claude_preflight() {
  claude_options=(-p --setting-sources "" --output-format stream-json --verbose
    --permission-mode dontAsk --disallowedTools Edit Write NotebookEdit
    --model "$model" --effort "$effort")
}

# The last result event carries the final message; is_error or no result at all
# is a failed CLI run.
claude_take_result() {
  local result
  result=$(jq -Rc 'fromjson? | select(.type == "result")' "$events_file" | tail -n 1)
  [[ -n "$result" ]] || return 1
  [[ "$(jq -r '.is_error' <<<"$result")" != true ]] || return 1
  jq -r '.result // empty' <<<"$result" >"$output"
}

claude_run_start() {
  session_id=$({ cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null; } | tr '[:upper:]' '[:lower:]') || true
  [[ -n "$session_id" ]] || fail "cannot generate a session ID: neither /proc/sys/kernel/random/uuid nor uuidgen is available"
  claude "${claude_options[@]}" --session-id "$session_id" >"$events_file" 2>"$stderr_file" || return
  claude_take_result
}

claude_run_resume() {
  claude "${claude_options[@]}" --resume "$session_id" >"$events_file" 2>"$stderr_file" || return
  claude_take_result
}

claude_resolve_model() {
  jq -Rr 'fromjson? | select(.type == "system" and .subtype == "init") | .model // empty' "$events_file" 2>/dev/null |
    head -n 1 || true
}

[[ $# -gt 0 ]] || {
  usage
  exit 2
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

mode=$1
shift

packet=
output=
session_id=
harness=
model=
effort=
author=
requester_harness=
requester_model=
requester_effort=
resolved_model=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packet)
      require_value "$1" "${2:-}"
      packet=$2
      shift 2
      ;;
    --output)
      require_value "$1" "${2:-}"
      output=$2
      shift 2
      ;;
    --session-id)
      require_value "$1" "${2:-}"
      session_id=$2
      shift 2
      ;;
    --harness)
      require_value "$1" "${2:-}"
      harness=$2
      shift 2
      ;;
    --model)
      require_value "$1" "${2:-}"
      model=$2
      shift 2
      ;;
    --effort)
      require_value "$1" "${2:-}"
      effort=$2
      shift 2
      ;;
    --author)
      require_value "$1" "${2:-}"
      author=$2
      shift 2
      ;;
    --requester-harness)
      require_value "$1" "${2:-}"
      requester_harness=$2
      shift 2
      ;;
    --requester-model)
      require_value "$1" "${2:-}"
      requester_model=$2
      shift 2
      ;;
    --requester-effort)
      require_value "$1" "${2:-}"
      requester_effort=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ "$mode" == "start" || "$mode" == "resume" ]] || fail "mode must be 'start' or 'resume'"
[[ -n "$packet" ]] || fail "--packet is required"
[[ -n "$output" ]] || fail "--output is required"
[[ -f "$packet" ]] || fail "packet does not exist: $packet"
[[ ! -e "$output" ]] || fail "refusing to overwrite review file: $output"
[[ -d "$(dirname "$output")" ]] || fail "output directory does not exist: $(dirname "$output")"

packet=$(absolute_path "$packet")
output=$(absolute_path "$output")
review_dir=$(dirname "$output")
state_file="$review_dir/.review-state"

if [[ "$mode" == "start" ]]; then
  [[ -f "$REVIEW_INSTRUCTIONS" ]] || fail "review instructions do not exist: $REVIEW_INSTRUCTIONS"
  [[ -z "$session_id" ]] || fail "--session-id is only valid with resume"
  [[ ! -e "$state_file" ]] || fail "review state already exists: $state_file"
  [[ -n "$author" ]] || fail "--author is required with start"
  [[ -n "$requester_harness" ]] || fail "--requester-harness is required with start"
  [[ -n "$requester_model" ]] || fail "--requester-model is required with start"
  [[ -n "$requester_effort" ]] || fail "--requester-effort is required with start"
  validate_author "$author" --author
  validate_requester_harness "$requester_harness" --requester-harness
  harness=${harness:-codex}
  validate_harness "$harness" --harness
  case "$harness" in
    codex)
      model=${model:-$CODEX_DEFAULT_MODEL}
      effort=${effort:-$CODEX_DEFAULT_EFFORT}
      ;;
    claude)
      model=${model:-$CLAUDE_DEFAULT_MODEL}
      effort=${effort:-$CLAUDE_DEFAULT_EFFORT}
      ;;
  esac
  review_count=1
  prior_review_count=0
else
  [[ -f "$REVISION_INSTRUCTIONS" ]] || fail "revision instructions do not exist: $REVISION_INSTRUCTIONS"
  [[ -z "$harness$model$effort$author$requester_harness$requester_model$requester_effort" ]] ||
    fail "--harness, --model, --effort, --author, and the --requester-* options are set on start; read from the review state"
  [[ -n "$session_id" ]] || fail "--session-id is required with resume"
  [[ -f "$state_file" ]] || fail "review state does not exist: $state_file"

  state_session_id=$(read_state_value "$state_file" SESSION_ID)
  [[ "$session_id" == "$state_session_id" ]] || fail "session ID does not match review state"
  author=$(read_state_value "$state_file" AUTHOR)
  requester_harness=$(read_state_value "$state_file" REQUESTER_HARNESS)
  requester_model=$(read_state_value "$state_file" REQUESTER_MODEL)
  requester_effort=$(read_state_value "$state_file" REQUESTER_EFFORT)
  harness=$(read_state_value "$state_file" REVIEWER_HARNESS)
  validate_harness "$harness" "REVIEWER_HARNESS in $state_file"
  model=$(read_state_value "$state_file" REVIEWER_MODEL)
  effort=$(read_state_value "$state_file" REVIEWER_EFFORT)
  resolved_model=$(read_optional_state_value "$state_file" REVIEWER_MODEL_RESOLVED)

  previous_count=$(read_state_value "$state_file" REVIEW_COUNT)
  [[ "$previous_count" =~ ^[0-9]+$ ]] || fail "invalid review count in $state_file"
  [[ "$previous_count" -lt "$MAX_REVIEWS" ]] || fail "review cap of $MAX_REVIEWS has been reached"
  review_count=$((previous_count + 1))
  prior_review_count=$previous_count
fi

command -v "$harness" >/dev/null 2>&1 || fail "$harness is not available; install it and log in"
command -v jq >/dev/null 2>&1 || fail "jq is required"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "must run inside a git working tree"

sandbox=${CROSS_CHECK_REVIEWER_SANDBOX:-native}
case "$sandbox" in
  native | external) ;;
  *) fail "CROSS_CHECK_REVIEWER_SANDBOX must be 'native' or 'external', not '$sandbox'" ;;
esac

events_file=$(mktemp)
stderr_file=$(mktemp)
index_backup=$(mktemp)
cleanup() {
  rm -f "$events_file" "$stderr_file" "$index_backup"
}
trap cleanup EXIT

"${harness}_preflight"

prompt_file="$review_dir/prompt-${review_count}.md"
if [[ "$mode" == "start" ]]; then
  {
    cat "$REVIEW_INSTRUCTIONS"
    printf '\n\n# Review Packet\n\n'
    cat "$packet"
  } >"$prompt_file"
else
  {
    cat "$REVISION_INSTRUCTIONS"
    printf '\n\n# Revision Packet\n\n'
    cat "$packet"
  } >"$prompt_file"
fi

run_round
[[ -n "$session_id" ]] || fail "$harness completed without reporting a session ID"

# A round that cannot read the model keeps the one an earlier round resolved.
round_model=$("${harness}_resolve_model")
resolved_model=${round_model:-$resolved_model}

if [[ ! -s "$output" ]] ||
  ! needs_revision=$(extract_counter NEEDS_REVISION "$output") ||
  ! needs_user_decision=$(extract_counter NEEDS_USER_DECISION "$output"); then
  write_state "$prior_review_count"
  printf 'SESSION_ID=%s\n' "$session_id" >&2
  fail "the reviewer returned a malformed final response; correct it by resuming this session without consuming a review round"
fi

write_state "$review_count"

printf 'SESSION_ID=%s\n' "$session_id"
printf 'NEEDS_REVISION=%s\n' "$needs_revision"
printf 'NEEDS_USER_DECISION=%s\n' "$needs_user_decision"
printf 'REVIEW_FILE=%s\n' "$output"
