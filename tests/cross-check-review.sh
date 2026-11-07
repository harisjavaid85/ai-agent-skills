#!/usr/bin/env bash
set -uo pipefail

# Drives the real review.sh against stub `codex` and `claude` CLIs on PATH and
# asserts each harness's flags, how CROSS_CHECK_REVIEWER_SANDBOX picks Codex's
# sandbox, what the review state and output record, and that a review which
# changes the repository fails whichever harness ran it, and is put back. No real
# CLI, no network.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/skills/productivity/cross-check/scripts/review.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass_count=0

fail() {
  echo "FAIL: $*" >&2
  [ -f "$TMP_ROOT/output" ] && sed 's/^/  | /' "$TMP_ROOT/output" >&2
  exit 1
}

pass() {
  pass_count=$((pass_count + 1))
  echo "ok $pass_count - $1"
}

# The stub records its argv and fails `codex sandbox` when STUB_SANDBOX=broken.
# Standing in for a review that edits: STUB_EDIT appends to a path, STUB_DELETE
# removes one, STUB_COMMIT commits everything, and STUB_RUN runs a command.
mkdir -p "$TMP_ROOT/bin"
cat >"$TMP_ROOT/bin/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG"
if [[ "$1" == "sandbox" ]]; then
  [[ "${STUB_SANDBOX:-}" == "broken" ]] && { echo "bwrap: No permissions to create a new namespace" >&2; exit 1; }
  exit 0
fi
output=
while [[ $# -gt 0 ]]; do
  [[ "$1" == "--output-last-message" ]] && output=$2
  shift
done
cat >/dev/null
[[ -z "${STUB_EDIT:-}" ]] || echo edited >>"$STUB_EDIT"
[[ -z "${STUB_DELETE:-}" ]] || rm -f "$STUB_DELETE"
[[ -z "${STUB_RUN:-}" ]] || eval "$STUB_RUN"
if [[ -n "${STUB_COMMIT:-}" ]]; then
  git add -A
  git -c user.email=t@example.com -c user.name=Tester commit -q --allow-empty -m sneaky
fi
printf 'NEEDS_REVISION: 0\nNEEDS_USER_DECISION: 0\n' >"$output"
echo '{"type":"thread.started","thread_id":"thread-1"}'
if [[ -n "${STUB_ROLLOUT:-}" ]]; then
  mkdir -p "$CODEX_HOME/sessions/2026/11/07"
  echo '{"type":"turn_context","payload":{"model":"stub-codex"}}' \
    >"$CODEX_HOME/sessions/2026/11/07/rollout-2026-11-07T00-00-00-thread-1.jsonl"
fi
exit "${STUB_EXIT:-0}"
EOF
chmod +x "$TMP_ROOT/bin/codex"

# The claude stub logs its argv shell-quoted, so an empty argument shows as ''.
# It prints an init event (STUB_NO_MODEL drops its model) and a result event
# carrying the counters; STUB_IS_ERROR, STUB_NO_RESULT, and STUB_DENIALS shape
# the result.
cat >"$TMP_ROOT/bin/claude" <<'EOF'
#!/usr/bin/env bash
{ printf 'claude'; printf ' %q' "$@"; echo; } >>"$STUB_LOG"
cat >/dev/null
[[ -z "${STUB_EDIT:-}" ]] || echo edited >>"$STUB_EDIT"
[[ -z "${STUB_DELETE:-}" ]] || rm -f "$STUB_DELETE"
[[ -z "${STUB_RUN:-}" ]] || eval "$STUB_RUN"
if [[ -n "${STUB_COMMIT:-}" ]]; then
  git add -A
  git -c user.email=t@example.com -c user.name=Tester commit -q --allow-empty -m sneaky
fi
if [[ -n "${STUB_NO_MODEL:-}" ]]; then
  echo '{"type":"system","subtype":"init","session_id":"x"}'
else
  echo '{"type":"system","subtype":"init","session_id":"x","model":"stub-claude"}'
fi
denials='[]'
[[ -z "${STUB_DENIALS:-}" ]] || denials='[{"tool_name":"Bash"}]'
[[ -n "${STUB_NO_RESULT:-}" ]] ||
  jq -cn --arg r $'NEEDS_REVISION: 0\nNEEDS_USER_DECISION: 0\n' --argjson e "${STUB_IS_ERROR:-false}" \
    --argjson d "$denials" '{type:"result",is_error:$e,result:$r,permission_denials:$d}'
exit "${STUB_EXIT:-0}"
EOF
chmod +x "$TMP_ROOT/bin/claude"
export PATH="$TMP_ROOT/bin:$PATH"
export STUB_LOG="$TMP_ROOT/codex.log"

# A fresh repo per case with one committed file, and the audit directory
# git-excluded as SKILL.md asks.
new_repo() {
  repo="$TMP_ROOT/repo-$pass_count-$RANDOM"
  git init -q "$repo"
  echo tracked >"$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" -c user.email=t@example.com -c user.name=Tester commit -q -m init
  echo ".cross-checks/" >>"$repo/.git/info/exclude"
  mkdir -p "$repo/.cross-checks/r"
  echo "Review the plan." >"$repo/.cross-checks/r/request.md"
  : >"$STUB_LOG"
  export CODEX_HOME="$repo.codex-home"
}

state() { cat "$repo/.cross-checks/r/.review-state"; }
out_value() { grep -E "^$1=" "$TMP_ROOT/output" | cut -d= -f2-; }

# The Requester's own facts, which every start must state.
REQUESTER=(--author requester --requester-harness claude --requester-model req-model --requester-effort unknown)

# $1 = mode (start|resume), remaining = extra args. A start also passes
# REQUESTER unless NO_REQUESTER is set. Exit status is the script's.
review() {
  local mode=$1 n requester=()
  shift
  n=$([[ "$mode" == "start" ]] && echo 1 || echo 2)
  [[ "$mode" != "start" || -n "${NO_REQUESTER:-}" ]] || requester=("${REQUESTER[@]}")
  (cd "$repo" && "$SCRIPT" "$mode" "${requester[@]}" "$@" \
    --packet .cross-checks/r/request.md \
    --output ".cross-checks/r/review-$n.md") >"$TMP_ROOT/output" 2>&1
}

new_repo
review start || fail "native start should succeed when the sandbox works"
grep -q '^sandbox -- true$' "$STUB_LOG" || fail "native should probe the sandbox first"
grep -q '^exec --sandbox read-only ' "$STUB_LOG" || fail "native start should pass --sandbox read-only"
review resume --session-id thread-1 || fail "native resume should succeed"
grep -q '^exec resume --config sandbox_mode="read-only" ' "$STUB_LOG" ||
  fail "native resume should pin the read-only sandbox"
pass "native (the default) uses Codex's read-only sandbox on start and resume"

new_repo
STUB_SANDBOX=broken review start && fail "native start should fail when the sandbox cannot start"
grep -qF "CROSS_CHECK_REVIEWER_SANDBOX=external" "$TMP_ROOT/output" || fail "the failure should name the way out"
grep -q '^exec' "$STUB_LOG" && fail "no review should run when the sandbox cannot start"
pass "native refuses before reviewing when Codex's sandbox cannot start"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_SANDBOX=broken review start ||
  fail "external start should not depend on Codex's sandbox"
grep -q '^sandbox' "$STUB_LOG" && fail "external should not probe Codex's sandbox"
grep -q '^exec --dangerously-bypass-approvals-and-sandbox ' "$STUB_LOG" ||
  fail "external start should bypass Codex's sandbox"
CROSS_CHECK_REVIEWER_SANDBOX=external review resume --session-id thread-1 || fail "external resume should succeed"
grep -q '^exec resume --dangerously-bypass-approvals-and-sandbox ' "$STUB_LOG" ||
  fail "external resume should bypass Codex's sandbox too"
pass "external bypasses Codex's sandbox on start and resume"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=container review start && fail "an unknown value should be refused"
grep -q '^exec' "$STUB_LOG" && fail "no review should run on an unknown value"
pass "an unknown CROSS_CHECK_REVIEWER_SANDBOX value is refused"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EDIT="$repo/file.txt" review start &&
  fail "a review that edits a file should fail"
grep -qF "file.txt" "$TMP_ROOT/output" || fail "the failure should name the changed file"
[ "$(cat "$repo/file.txt")" = tracked ] || fail "the edited file should be restored"
[ -e "$repo/.cross-checks/r/.review-state" ] && fail "a failed round should not be recorded"
pass "a review that edits a file fails, names it, and restores it"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EDIT="$repo/new.txt" review start &&
  fail "a review that creates a file should fail"
grep -qF "new.txt" "$TMP_ROOT/output" || fail "the failure should name the new file"
[ -e "$repo/new.txt" ] && fail "the created file should be removed"
pass "a review that creates a file fails and removes it"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_DELETE="$repo/file.txt" review start &&
  fail "a review that deletes a file should fail"
[ "$(cat "$repo/file.txt" 2>/dev/null)" = tracked ] || fail "the deleted file should be restored"
pass "a review that deletes a file fails and restores it"

new_repo
init_head=$(git -C "$repo" rev-parse HEAD)
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EDIT="$repo/file.txt" STUB_COMMIT=1 review start &&
  fail "a review that commits should fail"
grep -qF "HEAD" "$TMP_ROOT/output" || fail "the failure should say HEAD moved"
[ "$(git -C "$repo" rev-parse HEAD)" = "$init_head" ] || fail "the branch should be moved back"
[ "$(cat "$repo/file.txt")" = tracked ] || fail "the committed edit should be undone in the working tree"
[ -z "$(git -C "$repo" status --porcelain)" ] || fail "the index should be back as it was"
pass "a review that commits fails and moves the branch back"

new_repo
echo "work in progress" >>"$repo/file.txt"
git -C "$repo" add file.txt
echo "more, unstaged" >>"$repo/file.txt"
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EDIT="$repo/file.txt" review start &&
  fail "a review that edits dirty work should fail"
[ "$(cat "$repo/file.txt")" = "$(printf 'tracked\nwork in progress\nmore, unstaged')" ] ||
  fail "dirty work should be restored to its pre-review content, not to HEAD"
[ "$(git -C "$repo" diff --cached --name-only)" = file.txt ] || fail "staged work should stay staged"
pass "restoring keeps the work that was there before the review"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external review start || fail "external start should succeed"
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EDIT="$repo/file.txt" review resume --session-id thread-1 &&
  fail "a resumed review that edits a file should fail"
grep -qF "file.txt" "$TMP_ROOT/output" || fail "the resume failure should name the changed file"
[ "$(cat "$repo/file.txt")" = tracked ] || fail "the resume edit should be restored"
grep -q '^REVIEW_COUNT=1$' "$repo/.cross-checks/r/.review-state" ||
  fail "a failed resume should not consume a round"
pass "a resumed review that edits a file fails and restores it"

new_repo
sed -i '/cross-checks/d' "$repo/.git/info/exclude"
review start || fail "the round's own records should not trip the check when not git-excluded"
pass "the review directory's own records are outside the check"

new_repo
echo "work in progress" >>"$repo/file.txt"
CROSS_CHECK_REVIEWER_SANDBOX=external review start || fail "uncommitted work under review should not trip the check"
pass "uncommitted work present before the review is not a change"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EDIT="$repo/file.txt" STUB_EXIT=1 review start &&
  fail "a review that edits and then exits non-zero should fail"
grep -qF "status 1" "$TMP_ROOT/output" || fail "the failure should give the exit status"
grep -qF "file.txt" "$TMP_ROOT/output" || fail "the failure should name the changed file"
[ "$(cat "$repo/file.txt")" = tracked ] || fail "the edit should be undone even though the reviewer failed"
[ -e "$repo/.cross-checks/r/review-1.failure.events.jsonl" ] || fail "the failure events should be preserved"
[ -e "$repo/.cross-checks/r/review-1.failure.stderr.log" ] || fail "the failure stderr should be preserved"
[ -e "$repo/.cross-checks/r/.review-state" ] && fail "a failed round should not be recorded"
pass "a start that edits and then fails is undone and keeps its failure output"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external review start || fail "external start should succeed"
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EDIT="$repo/file.txt" STUB_EXIT=1 review resume --session-id thread-1 &&
  fail "a resume that edits and then exits non-zero should fail"
grep -qF "status 1" "$TMP_ROOT/output" || fail "the resume failure should give the exit status"
[ "$(cat "$repo/file.txt")" = tracked ] || fail "the resume edit should be undone"
[ -e "$repo/.cross-checks/r/review-2.failure.stderr.log" ] || fail "the resume failure output should be preserved"
grep -q '^REVIEW_COUNT=1$' "$repo/.cross-checks/r/.review-state" || fail "a failed resume should not consume a round"
pass "a resume that edits and then fails is undone and keeps its failure output"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EXIT=1 review start && fail "a reviewer that exits non-zero should fail"
grep -qF "start failed; failure output was preserved" "$TMP_ROOT/output" || fail "a plain failure keeps its message"
[ -e "$repo/.cross-checks/r/review-1.failure.events.jsonl" ] || fail "the failure events should be preserved"
pass "a reviewer that fails without editing reports the failure"

new_repo
echo "unstaged edit" >>"$repo/file.txt"
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_RUN="git add file.txt" review start &&
  fail "a review that stages a change should fail"
grep -qF "index" "$TMP_ROOT/output" || fail "the failure should say the index changed"
[ -z "$(git -C "$repo" diff --cached --name-only)" ] || fail "the staged change should be unstaged again"
[ "$(git -C "$repo" diff --name-only)" = file.txt ] || fail "the edit should still be an unstaged change"
pass "a review that stages a change fails and unstages it"

new_repo
echo "staged edit" >>"$repo/file.txt"
git -C "$repo" add file.txt
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_RUN="git reset -q file.txt" review start &&
  fail "a review that unstages a change should fail"
[ "$(git -C "$repo" diff --cached --name-only)" = file.txt ] || fail "the edit should be staged again"
pass "a review that unstages a change fails and stages it again"

new_repo
echo new >"$repo/untracked.txt"
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_RUN="git add -N untracked.txt" review start &&
  fail "a review that marks a file intent-to-add should fail"
[ "$(git -C "$repo" status --porcelain -- untracked.txt)" = "?? untracked.txt" ] || fail "the file should be untracked again"
pass "a review that adds an intent-to-add entry fails and removes it"

new_repo
touch "$repo/file.txt"
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_RUN="git status >/dev/null" review start ||
  fail "a review that only runs git status should pass"
pass "git status refreshing the index stat cache is not a change"

UUID='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
CLAUDE_FLAGS="-p --setting-sources '' --output-format stream-json --verbose --permission-mode dontAsk --disallowedTools Edit Write NotebookEdit"

new_repo
review start --harness claude || fail "claude start should succeed"
grep -qE "^claude $CLAUDE_FLAGS --model claude-opus-5-5 --effort high --session-id $UUID\$" "$STUB_LOG" ||
  fail "claude start should run locked down with a fresh session ID"
sid=$(out_value SESSION_ID)
[[ "$sid" =~ ^$UUID$ ]] || fail "the session ID should be the generated UUID, got '$sid'"
[ "$(cat "$repo/.cross-checks/r/review-1.md")" = "$(printf 'NEEDS_REVISION: 0\nNEEDS_USER_DECISION: 0')" ] ||
  fail "the review file should hold the result event's text"
: >"$STUB_LOG"
review resume --session-id "$sid" || fail "claude resume should succeed"
grep -qxF "claude $CLAUDE_FLAGS --model claude-opus-5-5 --effort high --resume $sid" "$STUB_LOG" || fail "claude resume should resume the same session"
grep -q -- '--fork-session' "$STUB_LOG" && fail "claude resume should never fork"
grep -q '^exec\|^sandbox' "$STUB_LOG" && fail "a claude review should not touch codex"
pass "a claude reviewer runs locked down and resumes its own session"

new_repo
review start --harness claude --model opus-x --effort high || fail "claude start with model and effort should succeed"
grep -q -- "--model opus-x --effort high --session-id" "$STUB_LOG" || fail "claude start should pass --model and --effort"
grep -qx 'REVIEWER_HARNESS=claude' <(state) || fail "state should record the harness"
grep -qx 'REVIEWER_MODEL=opus-x' <(state) || fail "state should record the model"
grep -qx 'REVIEWER_EFFORT=high' <(state) || fail "state should record the effort"
sid=$(out_value SESSION_ID)
: >"$STUB_LOG"
review resume --session-id "$sid" || fail "claude resume should succeed"
grep -q -- "--model opus-x --effort high --resume $sid" "$STUB_LOG" || fail "claude resume should re-pass model and effort from state"
pass "claude model and effort reach the CLI on start and, from state, on resume"

new_repo
review start --harness codex --model gpt-x --effort high || fail "codex start with model and effort should succeed"
grep -q -- '--model gpt-x --config model_reasoning_effort="high"' "$STUB_LOG" || fail "codex start should pass model and effort"
: >"$STUB_LOG"
review resume --session-id thread-1 || fail "codex resume should succeed"
grep -q -- '^exec resume .*--model gpt-x --config model_reasoning_effort="high" thread-1 -$' "$STUB_LOG" ||
  fail "codex resume should re-pass model and effort from state"
pass "codex model and effort reach the CLI on start and, from state, on resume"

for option in "--harness claude" "--model m" "--effort high"; do
  new_repo
  review start || fail "start should succeed"
  # shellcheck disable=SC2086
  review resume --session-id thread-1 $option && fail "resume should refuse $option"
  grep -qF "set on start; read from the review state" "$TMP_ROOT/output" || fail "the refusal should say why"
done
for option in "--author user" "--requester-harness codex" "--requester-model m" "--requester-effort high"; do
  new_repo
  review start || fail "start should succeed"
  # shellcheck disable=SC2086
  review resume --session-id thread-1 $option && fail "resume should refuse $option"
  grep -qF "set on start; read from the review state" "$TMP_ROOT/output" || fail "the refusal should say why"
done
pass "resume refuses the Reviewer and Requester settings, which are set on start"

new_repo
review start || fail "start with no harness should succeed"
grep -qx 'REVIEWER_HARNESS=codex' <(state) || fail "the script-level default harness is codex"
grep -q -- '--model gpt-6-astra --config model_reasoning_effort="high"' "$STUB_LOG" ||
  fail "codex start should default to gpt-6-astra at high effort"
grep -qx 'REVIEWER_MODEL=gpt-6-astra' <(state) && grep -qx 'REVIEWER_EFFORT=high' <(state) ||
  fail "the codex defaults should be recorded as the values used"
grep -qx 'REVIEWER_MODEL_RESOLVED=' <(state) || fail "an unresolved model is recorded empty"
: >"$STUB_LOG"
review resume --session-id thread-1 || fail "resume should succeed"
grep -q -- '--model gpt-6-astra --config model_reasoning_effort="high" thread-1 -$' "$STUB_LOG" ||
  fail "codex resume should re-pass the defaults from state"
new_repo
review start --harness claude || fail "claude start should succeed"
grep -qx 'REVIEWER_MODEL=claude-opus-5-5' <(state) && grep -qx 'REVIEWER_EFFORT=high' <(state) ||
  fail "the claude defaults should be recorded as the values used"
new_repo
review start --effort low || fail "start should succeed"
grep -qx 'REVIEWER_MODEL=gpt-6-astra' <(state) && grep -qx 'REVIEWER_EFFORT=low' <(state) ||
  fail "an explicit effort should override only the effort default"
pass "an omitted model or effort takes the Reviewer harness's default: gpt-6-astra or claude-opus-5-5, at high"

new_repo
review start || fail "start should succeed"
[ "$(state)" = "$(printf '%s\n' SESSION_ID=thread-1 REVIEW_COUNT=1 AUTHOR=requester REQUESTER_HARNESS=claude \
  REQUESTER_MODEL=req-model REQUESTER_EFFORT=unknown REVIEWER_HARNESS=codex REVIEWER_MODEL=gpt-6-astra REVIEWER_EFFORT=high \
  REVIEWER_MODEL_RESOLVED=)" ] || fail "the state should hold exactly the session, both participants, and the Author"
review resume --session-id thread-1 || fail "resume should succeed"
grep -qx 'AUTHOR=requester' <(state) && grep -qx 'REQUESTER_MODEL=req-model' <(state) &&
  grep -qx 'REQUESTER_EFFORT=unknown' <(state) || fail "resume should carry the Requester and Author forward"
pass "the review state records the session, the Requester, the Reviewer, and the Author"

for missing in --author --requester-harness --requester-model --requester-effort; do
  new_repo
  args=()
  for ((i = 0; i < ${#REQUESTER[@]}; i += 2)); do
    [[ "${REQUESTER[i]}" == "$missing" ]] || args+=("${REQUESTER[i]}" "${REQUESTER[i + 1]}")
  done
  NO_REQUESTER=1 review start "${args[@]}" && fail "start should require $missing"
  grep -qF -- "$missing is required with start" "$TMP_ROOT/output" || fail "the refusal should name $missing"
done
new_repo
NO_REQUESTER=1 review start --author boss --requester-harness claude --requester-model m --requester-effort e &&
  fail "an unknown Author should be refused"
grep -qF -- "--author must be 'requester', 'user', or 'external'" "$TMP_ROOT/output" || fail "the refusal should list the Authors"
new_repo
NO_REQUESTER=1 review start --author user --requester-harness gemini --requester-model m --requester-effort e &&
  fail "an unknown Requester harness should be refused"
new_repo
NO_REQUESTER=1 review start --author external --requester-harness unknown --requester-model unknown \
  --requester-effort unknown || fail "unknown is allowed for every Requester value"
pass "start requires the Author and the Requester's harness, model, and effort"

new_repo
STUB_ROLLOUT=1 review start --effort low || fail "start should succeed"
grep -qx 'REVIEWER_MODEL_RESOLVED=stub-codex' <(state) || fail "the codex model should be resolved from its rollout"
new_repo
review start --model gpt-x || fail "start should succeed"
grep -qx 'REVIEWER_MODEL=gpt-x' <(state) && grep -qx 'REVIEWER_MODEL_RESOLVED=' <(state) ||
  fail "with no rollout, only the passed model is recorded"
pass "the codex model is resolved from its rollout"

new_repo
review start --harness claude || fail "start should succeed"
grep -qx 'REVIEWER_MODEL_RESOLVED=stub-claude' <(state) || fail "the claude model should be resolved from its init event"
STUB_NO_MODEL=1 review resume --session-id "$(out_value SESSION_ID)" || fail "resume should succeed"
grep -qx 'REVIEWER_MODEL_RESOLVED=stub-claude' <(state) ||
  fail "a round that cannot resolve the model should keep the one already resolved"
new_repo
STUB_NO_MODEL=1 review start --harness claude || fail "start should succeed"
grep -qx 'REVIEWER_MODEL_RESOLVED=' <(state) || fail "with no init model, nothing is resolved"
pass "the claude model is resolved from its init event, and a resolved model is kept"

new_repo
STUB_IS_ERROR=true review start --harness claude && fail "an is_error result should fail the round"
grep -qF "start failed; failure output was preserved" "$TMP_ROOT/output" || fail "the failure should be reported"
[ -e "$repo/.cross-checks/r/review-1.failure.events.jsonl" ] || fail "the failure events should be preserved"
[ -e "$repo/.cross-checks/r/.review-state" ] && fail "a failed round should not be recorded"
new_repo
STUB_NO_RESULT=1 review start --harness claude && fail "a missing result event should fail the round"
[ -e "$repo/.cross-checks/r/review-1.failure.stderr.log" ] || fail "the failure output should be preserved"
pass "a claude error or missing result fails the round and keeps its output"

new_repo
STUB_DENIALS=1 review start --harness claude || fail "permission denials alone are a normal round"
pass "claude permission denials do not fail the round"

new_repo
CROSS_CHECK_REVIEWER_SANDBOX=external review start --harness claude || fail "external should work with claude"
ext_log=$(cat "$STUB_LOG")
new_repo
review start --harness claude || fail "native should work with claude"
[ "$(sed -E "s/$UUID/U/" <<<"$ext_log")" = "$(sed -E "s/$UUID/U/" "$STUB_LOG")" ] ||
  fail "the sandbox setting should not change claude's flags"
new_repo
CROSS_CHECK_REVIEWER_SANDBOX=container review start --harness claude && fail "an unknown sandbox value should be refused for claude"
pass "CROSS_CHECK_REVIEWER_SANDBOX is validated but changes nothing for claude"

new_repo
review start --harness gemini && fail "an unknown harness should be refused"
grep -qF -- "--harness must be 'codex' or 'claude'" "$TMP_ROOT/output" || fail "the refusal should name the harnesses"
new_repo
# Only the tools the script needs before its CLI check, so no real claude can
# be found wherever one is installed.
mkdir -p "$TMP_ROOT/no-cli-bin"
for tool in env bash dirname basename cat grep cut head mktemp git jq; do
  ln -sf "$(command -v "$tool")" "$TMP_ROOT/no-cli-bin/$tool"
done
(PATH="$TMP_ROOT/no-cli-bin" && export PATH && review start --harness claude) &&
  fail "a missing claude CLI should fail"
grep -qF "claude is not available; install it and log in" "$TMP_ROOT/output" || fail "the failure should say how to fix it"
pass "an unknown harness or a missing CLI is refused"

new_repo
review start --harness claude || fail "start should succeed"
sid=$(out_value SESSION_ID)
sed -i '/^REVIEWER_HARNESS=/s/claude/gemini/' "$repo/.cross-checks/r/.review-state"
review resume --session-id "$sid" && fail "an unknown recorded harness should be refused"
pass "resume validates the recorded harness"

new_repo
review start || fail "start should succeed"
review resume --session-id thread-1 || fail "resume should accept an empty REVIEWER_MODEL_RESOLVED"
new_repo
review start || fail "start should succeed"
sed -i "/^REVIEWER_MODEL_RESOLVED=/d" "$repo/.cross-checks/r/.review-state"
review resume --session-id thread-1 && fail "resume should refuse a state file without a REVIEWER_MODEL_RESOLVED line"
grep -qF "does not contain REVIEWER_MODEL_RESOLVED" "$TMP_ROOT/output" || fail "the refusal should name the key"
for key in AUTHOR REQUESTER_HARNESS REQUESTER_MODEL REQUESTER_EFFORT REVIEWER_MODEL REVIEWER_EFFORT; do
  new_repo
  review start || fail "start should succeed"
  sed -i "s/^$key=.*/$key=/" "$repo/.cross-checks/r/.review-state"
  review resume --session-id thread-1 && fail "resume should refuse an empty $key"
  grep -qF "does not contain $key" "$TMP_ROOT/output" || fail "the refusal should name $key"
done
pass "resume reads an empty resolved model, but refuses a missing line or any other empty value"

# The repository checks, under a claude reviewer.
new_repo
STUB_EDIT="$repo/file.txt" review start --harness claude && fail "a claude review that edits should fail"
[ "$(cat "$repo/file.txt")" = tracked ] || fail "the claude edit should be restored"
new_repo
STUB_EDIT="$repo/new.txt" review start --harness claude && fail "a claude review that creates a file should fail"
[ -e "$repo/new.txt" ] && fail "the created file should be removed"
new_repo
STUB_DELETE="$repo/file.txt" review start --harness claude && fail "a claude review that deletes should fail"
[ "$(cat "$repo/file.txt" 2>/dev/null)" = tracked ] || fail "the deleted file should be restored"
new_repo
init_head=$(git -C "$repo" rev-parse HEAD)
STUB_EDIT="$repo/file.txt" STUB_COMMIT=1 review start --harness claude && fail "a claude review that commits should fail"
[ "$(git -C "$repo" rev-parse HEAD)" = "$init_head" ] || fail "the branch should be moved back"
pass "a claude review that edits, creates, deletes, or commits fails and is restored"

for shape in STUB_EXIT=1 STUB_IS_ERROR=true STUB_NO_RESULT=1; do
  new_repo
  (export "$shape" STUB_EDIT="$repo/file.txt" && review start --harness claude) &&
    fail "a claude review that edits and fails ($shape) should fail"
  [ "$(cat "$repo/file.txt")" = tracked ] || fail "the edit should be undone ($shape)"
  grep -qF "file.txt" "$TMP_ROOT/output" || fail "the failure should name the changed file ($shape)"
  [ -e "$repo/.cross-checks/r/review-1.failure.events.jsonl" ] || fail "the failure output should be preserved ($shape)"
done
pass "a claude review that edits and then fails is undone and keeps its failure output"

new_repo
echo "unstaged edit" >>"$repo/file.txt"
STUB_RUN="git add file.txt" review start --harness claude && fail "a claude review that stages should fail"
[ -z "$(git -C "$repo" diff --cached --name-only)" ] || fail "the staged change should be unstaged again"
new_repo
echo "staged edit" >>"$repo/file.txt"
git -C "$repo" add file.txt
STUB_RUN="git reset -q file.txt" review start --harness claude && fail "a claude review that unstages should fail"
[ "$(git -C "$repo" diff --cached --name-only)" = file.txt ] || fail "the edit should be staged again"
pass "a claude review that changes only the index fails and restores it"

echo "1..$pass_count"
