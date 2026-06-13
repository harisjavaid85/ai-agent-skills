#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$REPO/scripts/link-skills.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass_count=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  pass_count=$((pass_count + 1))
  echo "ok $pass_count - $1"
}

assert_fails() {
  if "$@" >"$TMP_ROOT/output" 2>&1; then
    fail "expected command to fail: $*"
  fi
}

assert_link_to() {
  local link="$1"
  local expected="$2"
  [ -L "$link" ] || fail "expected symlink: $link"
  [ "$(readlink -f -- "$link")" = "$expected" ] ||
    fail "expected $link to resolve to $expected"
}

new_home() {
  local name="$1"
  mkdir -p "$TMP_ROOT/$name"
  printf '%s\n' "$TMP_ROOT/$name"
}

test_argument_validation() {
  local home
  home="$(new_home validation)"

  assert_fails env HOME="$home" "$INSTALLER"
  assert_fails env HOME="$home" "$INSTALLER" --claude --codex
  assert_fails env HOME="$home" "$INSTALLER" --other
  grep -q 'Usage:' "$TMP_ROOT/output" || fail "usage was not printed"
  pass "requires exactly one known target"
}

test_target_isolation_and_exclusions() {
  local home
  home="$(new_home isolation)"

  HOME="$home" "$INSTALLER" --claude >"$TMP_ROOT/output"
  assert_link_to "$home/.claude/skills/commit" "$REPO/skills/engineering/commit"
  [ ! -e "$home/.agents/skills/commit" ] || fail "codex target changed during claude install"
  [ ! -e "$home/.claude/skills/qa" ] || fail "deprecated skill was installed"

  HOME="$home" "$INSTALLER" --codex >"$TMP_ROOT/output"
  assert_link_to "$home/.agents/skills/commit" "$REPO/skills/engineering/commit"
  assert_link_to "$home/.agents/skills/setup-claude-code" "$REPO/skills/productivity/setup-claude-code"
  assert_link_to "$home/.claude/skills/commit" "$REPO/skills/engineering/commit"
  grep -q '^\[codex\] linked:' "$TMP_ROOT/output" || fail "codex output was not labelled"
  pass "isolates targets and excludes deprecated skills"
}

test_idempotency() {
  local home before after
  home="$(new_home idempotency)"

  HOME="$home" "$INSTALLER" --codex >/dev/null
  before="$(readlink "$home/.agents/skills/commit")"
  HOME="$home" "$INSTALLER" --codex >/dev/null
  after="$(readlink "$home/.agents/skills/commit")"
  [ "$before" = "$after" ] || fail "link target changed on second install"
  pass "is idempotent"
}

test_noninteractive_collision() {
  local home collision
  home="$(new_home collision)"
  collision="$home/.agents/skills/commit"
  mkdir -p "$collision"
  printf 'keep\n' >"$collision/marker"

  assert_fails env HOME="$home" "$INSTALLER" --codex
  [ "$(cat "$collision/marker")" = "keep" ] || fail "collision was modified"
  [ ! -e "$home/.agents/skills/tdd" ] || fail "installer linked before collision abort"
  grep -q '^\[codex\] collision: leaving' "$TMP_ROOT/output" ||
    fail "collision was not reported"
  pass "preserves non-interactive collisions and aborts before linking"
}

test_interactive_collisions() {
  local leave_home replace_home
  leave_home="$(new_home interactive-leave)"
  replace_home="$(new_home interactive-replace)"
  mkdir -p "$leave_home/.agents/skills/commit" "$replace_home/.agents/skills/commit"
  printf 'keep\n' >"$leave_home/.agents/skills/commit/marker"

  printf '\n' |
    script -qec "HOME='$leave_home' '$INSTALLER' --codex" /dev/null >"$TMP_ROOT/output"
  [ -f "$leave_home/.agents/skills/commit/marker" ] ||
    fail "interactive default did not leave collision"
  assert_link_to "$leave_home/.agents/skills/tdd" "$REPO/skills/engineering/tdd"

  printf 'y\n' |
    script -qec "HOME='$replace_home' '$INSTALLER' --codex" /dev/null >"$TMP_ROOT/output"
  assert_link_to "$replace_home/.agents/skills/commit" "$REPO/skills/engineering/commit"
  grep -q '\[codex\] replaced collision:' "$TMP_ROOT/output" ||
    fail "interactive replacement was not reported"
  pass "leaves or replaces interactive collisions as selected"
}

test_stale_link_pruning() {
  local home dest external
  home="$(new_home stale)"
  dest="$home/.claude/skills"
  external="$home/external-skill"
  mkdir -p "$dest" "$external"
  ln -s "$REPO/skills/deprecated/qa" "$dest/old-qa"
  ln -s "$REPO/skills/deprecated/removed-skill" "$dest/removed-skill"
  ln -s "$external" "$dest/external"

  HOME="$home" "$INSTALLER" --claude >"$TMP_ROOT/output"
  [ ! -L "$dest/old-qa" ] || fail "stale repository link was not pruned"
  [ ! -L "$dest/removed-skill" ] || fail "dangling repository link was not pruned"
  assert_link_to "$dest/external" "$external"
  grep -q '^\[claude\] pruned stale link:' "$TMP_ROOT/output" ||
    fail "prune action was not labelled"
  pass "prunes only stale links into this repository"
}

test_destination_symlink_protection() {
  local home
  home="$(new_home destination-link)"
  mkdir -p "$home/.claude"
  ln -s "$REPO/skills" "$home/.claude/skills"

  assert_fails env HOME="$home" "$INSTALLER" --claude
  grep -q 'symlink into this repo' "$TMP_ROOT/output" ||
    fail "destination symlink error was not reported"
  pass "rejects a destination symlink into this repository"
}

test_argument_validation
test_target_isolation_and_exclusions
test_idempotency
test_noninteractive_collision
test_interactive_collisions
test_stale_link_pruning
test_destination_symlink_protection

echo "1..$pass_count"
