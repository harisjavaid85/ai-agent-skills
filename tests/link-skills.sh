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

  assert_fails env HOME="$home" "$INSTALLER" --claude
  grep -q 'Usage:' "$TMP_ROOT/output" || fail "usage was not printed"
  pass "rejects arguments (dual-destination, no flags)"
}

test_links_both_destinations_and_exclusions() {
  local home
  home="$(new_home both)"

  HOME="$home" "$INSTALLER" >"$TMP_ROOT/output"
  assert_link_to "$home/.claude/skills/commit" "$REPO/skills/engineering/commit"
  assert_link_to "$home/.agents/skills/commit" "$REPO/skills/engineering/commit"
  assert_link_to "$home/.agents/skills/setup-claude-code" "$REPO/skills/productivity/setup-claude-code"
  [ ! -e "$home/.claude/skills/qa" ] || fail "deprecated skill was installed"
  [ ! -e "$home/.agents/skills/qa" ] || fail "deprecated skill was installed"
  grep -q "^\[$home/.claude/skills\] linked:" "$TMP_ROOT/output" ||
    fail "claude destination output was not labelled"
  grep -q "^\[$home/.agents/skills\] linked:" "$TMP_ROOT/output" ||
    fail "agents destination output was not labelled"
  pass "links both destinations and excludes deprecated skills"
}

test_idempotency() {
  local home before after
  home="$(new_home idempotency)"

  HOME="$home" "$INSTALLER" >/dev/null
  before="$(readlink "$home/.agents/skills/commit")"
  HOME="$home" "$INSTALLER" >/dev/null
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

  assert_fails env HOME="$home" "$INSTALLER"
  [ "$(cat "$collision/marker")" = "keep" ] || fail "collision was modified"
  [ ! -e "$home/.agents/skills/tdd" ] || fail "installer linked into colliding destination before abort"
  grep -q "^\[$home/.agents/skills\] collision: leaving" "$TMP_ROOT/output" ||
    fail "collision was not reported"
  pass "preserves non-interactive collisions and aborts that destination before linking"
}

test_interactive_collisions() {
  local leave_home replace_home
  leave_home="$(new_home interactive-leave)"
  replace_home="$(new_home interactive-replace)"
  mkdir -p "$leave_home/.agents/skills/commit" "$replace_home/.agents/skills/commit"
  printf 'keep\n' >"$leave_home/.agents/skills/commit/marker"

  printf '\n' |
    script -qec "HOME='$leave_home' '$INSTALLER'" /dev/null >"$TMP_ROOT/output"
  [ -f "$leave_home/.agents/skills/commit/marker" ] ||
    fail "interactive default did not leave collision"
  assert_link_to "$leave_home/.agents/skills/tdd" "$REPO/skills/engineering/tdd"

  printf 'y\n' |
    script -qec "HOME='$replace_home' '$INSTALLER'" /dev/null >"$TMP_ROOT/output"
  assert_link_to "$replace_home/.agents/skills/commit" "$REPO/skills/engineering/commit"
  grep -q "\[$replace_home/.agents/skills\] replaced collision:" "$TMP_ROOT/output" ||
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

  HOME="$home" "$INSTALLER" >"$TMP_ROOT/output"
  [ ! -L "$dest/old-qa" ] || fail "deprecated repository link was not pruned"
  [ ! -L "$dest/removed-skill" ] || fail "dangling repository link was not pruned"
  assert_link_to "$dest/external" "$external"
  grep -q "^\[$dest\] pruned stale link:" "$TMP_ROOT/output" ||
    fail "prune action was not labelled"
  pass "prunes only stale links into this repository"
}

test_destination_symlink_protection() {
  local home
  home="$(new_home destination-link)"
  mkdir -p "$home/.claude"
  ln -s "$REPO/skills" "$home/.claude/skills"

  assert_fails env HOME="$home" "$INSTALLER"
  grep -q 'symlink into this repo' "$TMP_ROOT/output" ||
    fail "destination symlink error was not reported"
  pass "rejects a destination symlink into this repository"
}

test_argument_validation
test_links_both_destinations_and_exclusions
test_idempotency
test_noninteractive_collision
test_interactive_collisions
test_stale_link_pruning
test_destination_symlink_protection

echo "1..$pass_count"
