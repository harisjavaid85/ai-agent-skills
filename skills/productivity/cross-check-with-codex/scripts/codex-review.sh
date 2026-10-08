#!/usr/bin/env bash

set -euo pipefail

readonly MAX_REVIEWS=5
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly REVIEW_INSTRUCTIONS="$SCRIPT_DIR/../REVIEW-INSTRUCTIONS.md"
readonly REVISION_INSTRUCTIONS="$SCRIPT_DIR/../REVISION-INSTRUCTIONS.md"

usage() {
  cat <<'EOF'
Usage:
  codex-review.sh start --packet PATH --output PATH [--model MODEL] [--reasoning LEVEL]
  codex-review.sh resume --thread-id ID --packet PATH --output PATH [--model MODEL] [--reasoning LEVEL]

Runs one read-only Codex review, captures its final response, and prints:
  THREAD_ID=<id>
  NEEDS_REVISION=<count>
  NEEDS_USER_DECISION=<count>
  REVIEW_FILE=<path>

CROSS_CHECK_REVIEWER_SANDBOX says what isolates Codex:
  native    (default) Codex's own read-only reviewer sandbox, which must start
  external  the caller already isolates this process, so Codex runs without one
Either way, a review that changes the working tree or HEAD fails, and the change
is undone.
EOF
}

fail() {
  printf 'codex-review: %s\n' "$*" >&2
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

write_state() {
  local state_file=$1
  local thread_id=$2
  local review_count=$3

  {
    printf 'THREAD_ID=%s\n' "$thread_id"
    printf 'REVIEW_COUNT=%s\n' "$review_count"
  } >"$state_file"
}

# A tree of the whole working tree, untracked files included, built in a scratch
# index so the real one is untouched. The review directory is left out: this
# script and Codex write the round's own records there.
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

# The round's starting point: branch, HEAD, working tree, and index, so a review
# that changes any of them can be detected and put back.
snapshot_repo() {
  before_ref=$(git symbolic-ref -q HEAD || printf detached)
  before_head=$(git rev-parse -q --verify HEAD || printf none)
  index_saved=0
  cp "$(git rev-parse --git-path index)" "$index_backup" 2>/dev/null && index_saved=1
  before_tree=$(worktree_tree) || fail "cannot snapshot the working tree before the review"
}

# Puts the repository back to the snapshot. It assumes nothing but Codex touched
# the repository during the round, which holds while the caller waits on it.
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
  fi
  (
    cd "$top" &&
      git diff -z --name-only --no-renames --diff-filter=A "$before_tree" "$after_tree" | xargs -0 -r rm -f -- &&
      git diff -z --name-only --no-renames --diff-filter=MDT "$before_tree" "$after_tree" |
      xargs -0 -r git restore --source="$before_tree" --worktree --
  )
}

# The read-only promise is checked here rather than trusted, because under
# `external` nothing else enforces it. A broken promise is undone, then fails
# the round.
require_unchanged() {
  local after_ref after_head after_tree changes=
  after_ref=$(git symbolic-ref -q HEAD || printf detached)
  after_head=$(git rev-parse -q --verify HEAD || printf none)
  after_tree=$(worktree_tree) || fail "cannot snapshot the working tree after the review"
  if [[ "$after_ref" != "$before_ref" || "$after_head" != "$before_head" ]]; then
    changes="  HEAD: $before_ref at $before_head became $after_ref at $after_head"$'\n'
  fi
  if [[ "$after_tree" != "$before_tree" ]]; then
    changes+=$(git diff --name-status --no-renames "$before_tree" "$after_tree" | head -n 20 | sed 's/^/  /')
  fi
  [[ -n "$changes" ]] || return 0
  restore_repo "$after_tree" ||
    fail "Codex changed the repository during the review, and restoring it failed; check git status:"$'\n'"$changes"
  fail "Codex changed the repository during the review, so it was not read-only. Restored to the state before the round:"$'\n'"$changes"
}

read_state_value() {
  local state_file=$1
  local name=$2
  local value

  value=$(grep -E "^${name}=" "$state_file" | head -n 1 | cut -d= -f2-)
  [[ -n "$value" ]] || fail "$state_file does not contain $name"
  printf '%s\n' "$value"
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
thread_id=
model=
reasoning=

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
    --thread-id)
      require_value "$1" "${2:-}"
      thread_id=$2
      shift 2
      ;;
    --model)
      require_value "$1" "${2:-}"
      model=$2
      shift 2
      ;;
    --reasoning)
      require_value "$1" "${2:-}"
      reasoning=$2
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
command -v codex >/dev/null 2>&1 || fail "codex is not available"
command -v jq >/dev/null 2>&1 || fail "jq is required"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "must run inside a git working tree"

sandbox=${CROSS_CHECK_REVIEWER_SANDBOX:-native}
case "$sandbox" in
  native)
    start_sandbox=(--sandbox read-only)
    # `exec resume` has no --sandbox flag, so the policy is pinned by config.
    resume_sandbox=(--config 'sandbox_mode="read-only"')
    ;;
  external)
    start_sandbox=(--dangerously-bypass-approvals-and-sandbox)
    resume_sandbox=("${start_sandbox[@]}")
    ;;
  *)
    fail "CROSS_CHECK_REVIEWER_SANDBOX must be 'native' or 'external', not '$sandbox'"
    ;;
esac

packet=$(absolute_path "$packet")
output=$(absolute_path "$output")
review_dir=$(dirname "$output")
state_file="$review_dir/.codex-review-state"

codex_options=(--json --output-last-message "$output")
[[ -z "$model" ]] || codex_options+=(--model "$model")
[[ -z "$reasoning" ]] || codex_options+=(--config "model_reasoning_effort=\"$reasoning\"")

events_file=$(mktemp)
stderr_file=$(mktemp)
index_backup=$(mktemp)
cleanup() {
  rm -f "$events_file" "$stderr_file" "$index_backup"
}
trap cleanup EXIT

# A reviewer sandbox that cannot start does not fail `codex exec`: Codex reports the
# blocked commands and still exits 0, having read nothing.
if [[ "$sandbox" == "native" ]] && ! codex sandbox -- true >/dev/null 2>"$stderr_file"; then
  fail "Codex's reviewer sandbox cannot start here: $(head -n 1 "$stderr_file")"$'\n'"This is the caller's configuration to fix: CROSS_CHECK_REVIEWER_SANDBOX=external is only for a caller that already isolates the review, such as a container."
fi

if [[ "$mode" == "start" ]]; then
  [[ -f "$REVIEW_INSTRUCTIONS" ]] || fail "review instructions do not exist: $REVIEW_INSTRUCTIONS"
  [[ -z "$thread_id" ]] || fail "--thread-id is only valid with resume"
  [[ ! -e "$state_file" ]] || fail "review state already exists: $state_file"
  review_count=1
  prior_review_count=0
  prompt_file="$review_dir/prompt-${review_count}.md"
  {
    cat "$REVIEW_INSTRUCTIONS"
    printf '\n\n# Review Packet\n\n'
    cat "$packet"
  } >"$prompt_file"

  snapshot_repo
  if ! codex exec "${start_sandbox[@]}" "${codex_options[@]}" - <"$prompt_file" >"$events_file" 2>"$stderr_file"; then
    cp "$events_file" "$review_dir/review-1.failure.events.jsonl"
    cp "$stderr_file" "$review_dir/review-1.failure.stderr.log"
    fail "Codex start failed; failure output was preserved in $review_dir"
  fi
  require_unchanged

  thread_id=$(jq -r 'select(.type == "thread.started") | .thread_id // empty' "$events_file" | head -n 1)
  [[ -n "$thread_id" ]] || fail "Codex completed without emitting a thread ID"
else
  [[ -f "$REVISION_INSTRUCTIONS" ]] || fail "revision instructions do not exist: $REVISION_INSTRUCTIONS"
  [[ -n "$thread_id" ]] || fail "--thread-id is required with resume"
  [[ -f "$state_file" ]] || fail "review state does not exist: $state_file"

  state_thread_id=$(read_state_value "$state_file" THREAD_ID)
  [[ "$thread_id" == "$state_thread_id" ]] || fail "thread ID does not match review state"

  previous_count=$(read_state_value "$state_file" REVIEW_COUNT)
  [[ "$previous_count" =~ ^[0-9]+$ ]] || fail "invalid review count in $state_file"
  [[ "$previous_count" -lt "$MAX_REVIEWS" ]] || fail "review cap of $MAX_REVIEWS has been reached"
  review_count=$((previous_count + 1))
  prior_review_count=$previous_count
  prompt_file="$review_dir/prompt-${review_count}.md"
  {
    cat "$REVISION_INSTRUCTIONS"
    printf '\n\n# Revision Packet\n\n'
    cat "$packet"
  } >"$prompt_file"

  snapshot_repo
  if ! codex exec resume "${resume_sandbox[@]}" "${codex_options[@]}" "$thread_id" - <"$prompt_file" >"$events_file" 2>"$stderr_file"; then
    cp "$events_file" "$review_dir/review-${review_count}.failure.events.jsonl"
    cp "$stderr_file" "$review_dir/review-${review_count}.failure.stderr.log"
    fail "Codex resume failed; failure output was preserved in $review_dir"
  fi
  require_unchanged
fi

if [[ ! -s "$output" ]] ||
  ! needs_revision=$(extract_counter NEEDS_REVISION "$output") ||
  ! needs_user_decision=$(extract_counter NEEDS_USER_DECISION "$output"); then
  write_state "$state_file" "$thread_id" "$prior_review_count"
  printf 'THREAD_ID=%s\n' "$thread_id" >&2
  fail "Codex returned a malformed final response; correct it by resuming this thread without consuming a review round"
fi

write_state "$state_file" "$thread_id" "$review_count"

printf 'THREAD_ID=%s\n' "$thread_id"
printf 'NEEDS_REVISION=%s\n' "$needs_revision"
printf 'NEEDS_USER_DECISION=%s\n' "$needs_user_decision"
printf 'REVIEW_FILE=%s\n' "$output"
