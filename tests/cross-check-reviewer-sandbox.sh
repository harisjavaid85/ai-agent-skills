#!/usr/bin/env bash
set -uo pipefail

# Drives the real codex-review.sh against a stub `codex` on PATH and asserts how
# CROSS_CHECK_REVIEWER_SANDBOX picks the sandbox, and that a review which changes
# the repository fails whichever sandbox ran it, and is put back. No real Codex,
# no network.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/skills/productivity/cross-check-with-codex/scripts/codex-review.sh"
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
# removes one, and STUB_COMMIT commits everything.
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
if [[ -n "${STUB_COMMIT:-}" ]]; then
  git add -A
  git -c user.email=t@example.com -c user.name=Tester commit -q --allow-empty -m sneaky
fi
printf 'NEEDS_REVISION: 0\nNEEDS_USER_DECISION: 0\n' >"$output"
echo '{"type":"thread.started","thread_id":"thread-1"}'
EOF
chmod +x "$TMP_ROOT/bin/codex"
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
  echo ".claude/codex-reviews/" >>"$repo/.git/info/exclude"
  mkdir -p "$repo/.claude/codex-reviews/r"
  echo "Review the plan." >"$repo/.claude/codex-reviews/r/request.md"
  : >"$STUB_LOG"
}

# $1 = mode (start|resume), remaining = extra args. Exit status is the script's.
review() {
  local mode=$1 n
  shift
  n=$([[ "$mode" == "start" ]] && echo 1 || echo 2)
  (cd "$repo" && "$SCRIPT" "$mode" "$@" \
    --packet .claude/codex-reviews/r/request.md \
    --output ".claude/codex-reviews/r/review-$n.md") >"$TMP_ROOT/output" 2>&1
}

new_repo
review start || fail "native start should succeed when the sandbox works"
grep -q '^sandbox -- true$' "$STUB_LOG" || fail "native should probe the sandbox first"
grep -q '^exec --sandbox read-only ' "$STUB_LOG" || fail "native start should pass --sandbox read-only"
review resume --thread-id thread-1 || fail "native resume should succeed"
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
CROSS_CHECK_REVIEWER_SANDBOX=external review resume --thread-id thread-1 || fail "external resume should succeed"
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
[ -e "$repo/.claude/codex-reviews/r/.codex-review-state" ] && fail "a failed round should not be recorded"
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
CROSS_CHECK_REVIEWER_SANDBOX=external STUB_EDIT="$repo/file.txt" review resume --thread-id thread-1 &&
  fail "a resumed review that edits a file should fail"
grep -qF "file.txt" "$TMP_ROOT/output" || fail "the resume failure should name the changed file"
[ "$(cat "$repo/file.txt")" = tracked ] || fail "the resume edit should be restored"
grep -q '^REVIEW_COUNT=1$' "$repo/.claude/codex-reviews/r/.codex-review-state" ||
  fail "a failed resume should not consume a round"
pass "a resumed review that edits a file fails and restores it"

new_repo
sed -i '/codex-reviews/d' "$repo/.git/info/exclude"
review start || fail "the round's own records should not trip the check when not git-excluded"
pass "the review directory's own records are outside the check"

new_repo
echo "work in progress" >>"$repo/file.txt"
CROSS_CHECK_REVIEWER_SANDBOX=external review start || fail "uncommitted work under review should not trip the check"
pass "uncommitted work present before the review is not a change"

echo "1..$pass_count"
