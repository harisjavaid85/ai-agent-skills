#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO/skills/productivity/setup-claude-code/scripts/block-dangerous-bash.sh"

pass_count=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  pass_count=$((pass_count + 1))
  echo "ok $pass_count - $1"
}

run_hook() {
  jq -n --arg c "$1" '{tool_input: {command: $c}}' | bash "$HOOK" >/dev/null 2>&1
}

assert_allowed() {
  run_hook "$1" || fail "expected allowed: $1"
  pass "allows: $1"
}

assert_blocked() {
  local status=0
  run_hook "$1" || status=$?
  [ "$status" -eq 2 ] || fail "expected blocked (exit 2), got $status: $1"
  pass "blocks: $1"
}

# Editing one issue comment in place is the only gh REST write the hook lets through.
assert_allowed 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@/tmp/report.md'
assert_allowed 'gh api -XPATCH repos/acme/widgets/issues/comments/123 -F body=@report.md'
assert_allowed 'gh api --method PATCH repos/acme/widgets/issues/comments/123 -F body=@report.md'
assert_allowed 'gh api --method=PATCH /repos/acme/widgets/issues/comments/123 -f body=done'
assert_allowed 'gh api -X PATCH repos/{owner}/{repo}/issues/comments/123 --field body=@report.md'

# Every other write stays blocked.
assert_blocked 'gh api -X PATCH repos/acme/widgets/pulls/1 -f state=closed'
assert_blocked 'gh api -X PATCH repos/acme/widgets/git/refs/heads/main -F sha=abc -F force=true'
assert_blocked 'gh api -X PATCH repos/acme/widgets -f private=false'
assert_blocked 'gh api -X PATCH repos/acme/widgets/issues/comments/123/reactions -f content=heart'
assert_blocked 'gh api -X DELETE repos/acme/widgets/issues/comments/123'
assert_blocked 'gh api -X POST repos/acme/widgets/issues/1/comments -f body=hi'
assert_blocked 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md -X DELETE'

# The comment edit cannot carry a second command.
assert_blocked 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md && gh api -X DELETE repos/acme/widgets/issues/comments/9'
assert_blocked 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md; gh api -X DELETE repos/acme/widgets/issues/comments/9'
assert_blocked "gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md
gh api -X DELETE repos/acme/widgets/issues/comments/9"
assert_blocked 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=$(gh api -X DELETE repos/acme/widgets/issues/comments/9)'
assert_blocked 'bash -c "gh api -X PATCH repos/acme/widgets/pulls/1 -f state=closed"'


# Field arguments make gh send a POST unless the method is GET.
assert_blocked 'gh api repos/acme/widgets/issues/1/comments -f body=hi'
assert_blocked 'gh api repos/acme/widgets/issues/1/comments -fbody=hi'
assert_blocked 'gh api repos/acme/widgets/issues/1/comments --raw-field body=hi'
assert_blocked 'gh api repos/acme/widgets/issues/1/comments --input body.json'
assert_blocked 'gh api -X "DELETE" repos/acme/widgets/issues/comments/123'
assert_allowed 'gh api -X GET search/issues -f q=repo:acme/widgets'
assert_allowed 'gh api --method GET search/issues -f q=repo:acme/widgets'
assert_allowed 'cd repo && gh api -X GET search/issues -f q=x'
assert_allowed 'gh api repos/acme/widgets/issues/1/comments --paginate'
assert_allowed 'gh api repos/acme/widgets/commits/abc/pulls --jq ".[].number"'

# Recursive rm: a target must be a plain relative path under cwd, or one level under /tmp.
assert_allowed 'rm -rf build'
assert_allowed 'rm -rf build dist 2>/dev/null'
assert_allowed 'rm -rf "build dir"'
assert_allowed 'rm -rf src/generated'
assert_allowed 'rm -rf /tmp/claude-setup-123'
assert_allowed 'rm -rf "/tmp/claude-setup-123"'
assert_allowed 'rm notes.txt'
assert_allowed 'rm -f /tmp/x.log'
assert_allowed 'git rm -r --cached build'
assert_allowed 'rm -rf build && git commit -m "a; b"'
assert_blocked 'rm -rf /'
assert_blocked 'rm -rf "/home/haris"'
assert_blocked "rm -rf '/etc'"
assert_blocked 'rm -rf "$HOME"'
assert_blocked 'rm -rf $HOME/work'
assert_blocked 'rm -rf "$TMP_ROOT"'
assert_blocked 'rm -rf `pwd`'
assert_blocked 'rm -rf ~'
assert_blocked 'rm -rf ~/work'
assert_blocked 'rm -Rf /etc'
assert_blocked 'rm -fR /etc'
assert_blocked 'rm -r -f /etc'
assert_blocked 'rm --recursive --force /etc'
assert_blocked 'rm -r /etc'
assert_blocked 'rm -rf .'
assert_blocked 'rm -rf ./'
assert_blocked 'rm -rf ..'
assert_blocked 'rm -rf src/../..'
assert_blocked 'rm -rf *'
assert_blocked 'rm -rf build && rm -rf /etc'
assert_blocked 'cd /tmp; rm -rf build /etc'
assert_blocked 'rm -rf /tmp'
assert_blocked 'rm -rf /tmp/'
assert_blocked 'rm -rf /tmp/*'
assert_blocked 'rm -rf /tmp/abc/'
assert_blocked 'rm -rf /tmp/abc/sub'
assert_blocked 'rm -rf /tmp/../home/haris'
assert_blocked 'bash -c "rm -rf /etc"'

# Line continuations join into one command.
assert_blocked 'gh api \
  -X DELETE repos/acme/widgets/issues/comments/123'
assert_blocked 'rm -rf \
  /etc'
assert_allowed 'rm -rf build \
  dist'

# git, find, and gh rules carried over from the previous hook.
assert_blocked 'git reset --hard HEAD~1'
assert_blocked 'git clean -fd'
assert_blocked 'git branch -D feature'
assert_blocked 'git checkout .'
assert_blocked 'git push --force origin feature'
assert_blocked 'git push --force-with-lease origin feature'
assert_blocked 'git push -f origin feature'
assert_blocked 'git push origin main'
assert_blocked 'git push origin HEAD:master'
assert_blocked 'git commit --no-verify -m wip'
assert_blocked 'git commit -n -m wip'
assert_blocked 'find . -name "*.tmp" -delete'
assert_blocked 'gh auth logout'
assert_blocked 'gh pr review 1 --approve'
assert_allowed 'git push origin feature'
assert_allowed 'git push -u origin feature'
assert_allowed 'git commit -m "fix the thing"'
assert_allowed 'git status --short'
assert_allowed 'gh auth status'

# Remote branch deletes need a lease on each deleted branch's expected commit.
SHA=0123456789abcdef0123456789abcdef01234567
assert_allowed "git push --force-with-lease=feature/login:$SHA origin --delete feature/login"
assert_allowed "git push origin -d feature --force-with-lease=feature:abc1234"
assert_allowed "git push --force-with-lease=\"feature:$SHA\" origin --delete feature"
assert_allowed "git push --force-with-lease=refs/heads/feature:$SHA origin --delete feature"
assert_allowed "git push --force-with-lease=a:$SHA --force-with-lease=b:$SHA origin --delete a b"
assert_allowed "git push --force-with-lease=feature:$SHA origin :feature"
assert_allowed "git push -o ci.skip --force-with-lease=feature:$SHA origin --delete feature"
assert_blocked 'git push origin --delete feature'
assert_blocked 'git push origin -d feature'
assert_blocked 'git push --delete origin feature'
assert_blocked 'git push origin :feature'
assert_blocked 'git push --force-with-lease origin --delete feature'
assert_blocked 'git push --force-with-lease=feature origin --delete feature'
assert_blocked 'git push --force-with-lease=feature:origin/feature origin --delete feature'
assert_blocked "git push --force-with-lease=other:$SHA origin --delete feature"
assert_blocked "git push --force-with-lease=a:$SHA origin --delete a b"
assert_blocked "git push --force --force-with-lease=feature:$SHA origin --delete feature"
assert_blocked "git push --force-with-lease=main:$SHA origin --delete main"
assert_blocked "git push --force-with-lease=feature:$SHA origin feature"
assert_blocked "git push --force-with-lease=feature:$SHA origin --delete feature && git push --force-with-lease origin x"
assert_allowed 'gh pr review 1 --comment -b ok'
assert_blocked 'gh pr merge 12 --admin'
assert_blocked 'gh pr merge 12 --merge --admin --delete-branch'
assert_allowed 'gh pr merge 12 --merge'
assert_allowed 'gh pr merge 12 --merge --auto'

# Typical agent spellings. The hook input carries the session's cwd.
assert_allowed_in() {
  jq -n --arg c "$2" --arg d "$1" '{cwd: $d, tool_input: {command: $c}}' | bash "$HOOK" >/dev/null 2>&1 \
    || fail "expected allowed in $1: $2"
  pass "allows in $1: $2"
}
assert_blocked_in() {
  local status=0
  jq -n --arg c "$2" --arg d "$1" '{cwd: $d, tool_input: {command: $c}}' | bash "$HOOK" >/dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "expected blocked in $1, got $status: $2"
  pass "blocks in $1: $2"
}
REPO_DIR=/home/dev/project
assert_allowed_in "$REPO_DIR" 'rm -rf /home/dev/project/build'
assert_allowed_in "$REPO_DIR" 'rm -rf /home/dev/project/src/generated'
assert_blocked_in "$REPO_DIR" 'rm -rf /home/dev/project'
assert_blocked_in "$REPO_DIR" 'rm -rf /home/dev/project/'
assert_blocked_in "$REPO_DIR" 'rm -rf /home/dev/project/../other'
assert_blocked_in "$REPO_DIR" 'rm -rf /home/dev/project-old'
assert_blocked_in "$REPO_DIR" 'cd ~ && rm -rf work'
assert_blocked_in "$REPO_DIR" 'cd /home/dev && rm -rf project'
assert_blocked_in "$REPO_DIR" 'cd .. && rm -rf project'
assert_blocked_in "$REPO_DIR" 'cd && rm -rf work'
assert_allowed_in "$REPO_DIR" 'cd src && rm -rf generated'
assert_allowed_in "$REPO_DIR" 'cd /home/dev/project/web && rm -rf dist'
assert_allowed_in "$REPO_DIR" 'cd /tmp && rm -rf claude-setup-123'
assert_allowed_in "$REPO_DIR" 'find . -name "__pycache__" -type d -exec rm -rf {} +'
assert_blocked_in "$REPO_DIR" 'find /home/dev -name build -exec rm -rf {} +'
assert_blocked_in "$REPO_DIR" 'find ~ -name build -exec rm -rf {} \;'

# Discarding all changes, in the spellings agents use.
assert_blocked 'git checkout -- .'
assert_blocked 'git restore -- .'
assert_blocked 'git checkout HEAD -- .'
assert_allowed 'git restore --staged .'
assert_allowed 'git checkout -- src/file.ts'

# Pushes that land on main or master.
assert_blocked 'git push origin feature:main'
assert_blocked 'git push origin +main'
assert_allowed 'git push origin feature:feature'
assert_allowed 'git push origin main-docs'

# Review round: everyday spellings found by the cross-check.
assert_blocked_in "$REPO_DIR" 'git -C /home/dev/project reset --hard HEAD'
assert_blocked_in "$REPO_DIR" 'git -C /home/dev/project push --force origin feature'
assert_blocked_in "$REPO_DIR" 'git -c core.pager=cat -C web clean -fd'
assert_allowed_in "$REPO_DIR" 'git -C /home/dev/project status --short'
assert_blocked_in "$REPO_DIR" 'cd /home/dev > /dev/null && rm -rf project'
assert_blocked_in "$REPO_DIR" 'cd "/home/dev/other project" && rm -rf build'
assert_allowed_in "$REPO_DIR" 'cd "/home/dev/project/my app" && rm -rf build'
assert_blocked_in "$REPO_DIR" 'cd /home/dev/project2 && rm -rf build'
assert_blocked_in "$REPO_DIR" 'cd /home/dev/project2 2>/dev/null && rm -rf build'
assert_blocked_in "$REPO_DIR" 'cd /home/dev/project2 >/dev/null && rm -rf build'
assert_allowed_in "$REPO_DIR" 'cd /home/dev/project/v2 && rm -rf build'
assert_allowed_in "$REPO_DIR" 'cd /home/dev/project/v2 2>/dev/null && rm -rf build'
assert_blocked_in "$REPO_DIR" 'git -C "/home/dev/my project" reset --hard HEAD'
assert_blocked_in "$REPO_DIR" 'git -C "/home/dev/my project" push --force origin feature'
assert_blocked_in "$REPO_DIR" "git -C '/home/dev/my project' clean -fd"
assert_blocked_in "$REPO_DIR" 'cd /tmp && rm -rf cache/build'
assert_blocked_in "$REPO_DIR" 'cd /tmp/cache && rm -rf build'
assert_allowed_in "$REPO_DIR" 'cd src && rm -rf ../build'
assert_blocked_in "$REPO_DIR" 'cd src && rm -rf ../..'
assert_blocked 'git reset HEAD --hard'
assert_blocked 'git reset origin/main --hard'
assert_blocked_in "$REPO_DIR" 'find /home/dev -name build -exec rm --recursive --force {} +'
assert_blocked_in "$REPO_DIR" 'find /home/dev -name build -exec rm -f -r {} +'
assert_blocked 'git push origin HEAD:refs/heads/main'
assert_blocked 'git push origin refs/heads/master'
assert_allowed 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -f body="Updated after review"'
assert_allowed "gh api -X PATCH repos/acme/widgets/issues/comments/123 -f body='Updated; see notes'"
assert_allowed 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@"/tmp/report one.md"'
assert_blocked 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -f body="$(cat x)"'
# The comment edit with output-only options, optionally after one leading cd.
assert_allowed 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@/tmp/merge-do/report.md --jq .id'
assert_allowed "gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md -q '.html_url'"
assert_allowed 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md --silent'
assert_allowed 'cd ~/work/mock-webapp && gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@/tmp/merge-do/report.md --jq .id'
assert_allowed 'cd "/home/dev/my app" && gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md'
assert_blocked 'cd x && gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md && gh api -X DELETE repos/acme/widgets/issues/comments/9'
assert_blocked 'cd x; rm -rf /etc && gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md'
assert_blocked 'cd $(rm -rf /etc) && gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md'
assert_blocked 'cd a && cd b && gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md'
assert_blocked 'cd a || gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md'
assert_blocked 'gh api -X PATCH repos/acme/widgets/issues/comments/123 -F body=@r.md --jq .id; gh api -X DELETE repos/acme/widgets/issues/comments/9'

# A plain push sends the current branch, so it is blocked while on main or master.
PUSH_TMP="$(mktemp -d)"
trap 'rm -rf "$PUSH_TMP"' EXIT
git init -q -b main "$PUSH_TMP/on-main"
git init -q -b feature "$PUSH_TMP/on-feature"
assert_blocked_in "$PUSH_TMP/on-main" 'git push'
assert_blocked_in "$PUSH_TMP/on-main" 'git push -u origin HEAD'
assert_blocked_in "$PUSH_TMP/on-main" 'git push origin'
assert_allowed_in "$PUSH_TMP/on-main" 'git push origin feature'
assert_allowed_in "$PUSH_TMP/on-feature" 'git push'
assert_allowed_in "$PUSH_TMP/on-feature" 'git push -u origin HEAD'
assert_blocked_in "$PUSH_TMP/on-feature" "git -C \"$PUSH_TMP/on-main\" push"
assert_allowed_in "$PUSH_TMP/on-main" "git -C \"$PUSH_TMP/on-feature\" push"

echo "all $pass_count passed"
