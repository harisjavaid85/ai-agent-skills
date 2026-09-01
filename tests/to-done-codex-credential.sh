#!/usr/bin/env bash
set -uo pipefail

# Drives the real loop.mts against fixture credentials and asserts what it says
# about codex before it builds anything. The launch stops at requireImage(), so
# no container is ever started; every line under test is printed before that,
# which is the point: an expired credential has to be caught while the run is
# still cheap to abandon.
#
# Only the codex path is covered. The rest of the loop needs docker, gh, and a
# live tracker. The fixture queue holds exactly one ticket on purpose: `plan`
# skips the planner below two, so this cannot start a container even on a host
# that does have the image.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LOOP="$REPO/skills/in-progress/to-done/scripts/loop.mts"
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

# An unsigned JWT carrying nothing but the expiry the preflight decodes.
jwt() {
  local header payload
  header=$(printf '{"alg":"none"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
  payload=$(printf '{"exp":%s}' "$1" | base64 -w0 | tr '+/' '-_' | tr -d '=')
  printf '%s.%s.unsigned\n' "$header" "$payload"
}

auth_file() {
  printf '{"tokens":{"access_token":"%s"}}\n' "$(jwt "$2")" >"$TMP_ROOT/$1.json"
  printf '%s\n' "$TMP_ROOT/$1.json"
}

# A repo the loop will accept far enough to report its credentials.
target="$TMP_ROOT/target"
mkdir -p "$target/docs/agents" "$target/.to-done" "$target/.scratch/demo/issues"
git init -q -b base "$target"
git -C "$target" commit -q --allow-empty -m init
ln -s "$REPO/node_modules" "$target/node_modules"
cat >"$target/docs/agents/triage-labels.md" <<'EOF'
| Role | Label |
| --- | --- |
| `ready-for-agent` | `ready-for-agent` |
| `ready-for-human` | `ready-for-human` |
| `needs-info` | `needs-info` |
| `wontfix` | `wontfix` |
EOF
printf -- '---\nstatus: open\nlabels: [ready-for-agent]\n---\n# A ticket\n' \
  >"$target/.scratch/demo/issues/1.md"

# $1 = extra secrets lines, then the assertions are grep -F patterns.
launch() {
  {
    printf 'GH_TOKEN=placeholder\n'
    printf 'CLAUDE_CODE_OAUTH_TOKEN=placeholder\n'
    printf '%s\n' "$1"
  } >"$target/.to-done/secrets"
  shift
  (cd "$target" && node "$LOOP" demo plan) >"$TMP_ROOT/output" 2>&1
  for expected in "$@"; do
    grep -qF -- "$expected" "$TMP_ROOT/output" || fail "expected output to contain: $expected"
  done
}

now=$(date +%s)

launch "CODEX_AUTH_FILE=$(auth_file expired $((now - 200000)))" \
  "Codex: none" \
  "expired 2d ago" \
  "The review phase will refuse to start."
pass "an expired credential is refused before anything is built"

launch "CODEX_AUTH_FILE=$(auth_file soon $((now + 7200)))" \
  "(2h left)" \
  "expires in 2h, inside this run's 6h window"
pass "a credential expiring inside the run window warns about rotation"

launch "CODEX_AUTH_FILE=$(auth_file fresh $((now + 900000)))" \
  "(10d left)"
grep -q "^Warning: the codex credential" "$TMP_ROOT/output" &&
  fail "a fresh credential should not warn"
pass "a fresh credential is reported and passes silently"

printf 'not json\n' >"$TMP_ROOT/malformed.json"
launch "CODEX_AUTH_FILE=$TMP_ROOT/malformed.json" \
  "Codex: none" \
  "is not readable JSON"
pass "a malformed credential is refused"

launch "CODEX_AUTH_FILE=$TMP_ROOT/absent.json" \
  "Codex: none" \
  "does not exist; run \`codex login\`"
pass "a missing credential is refused"

launch "OPENAI_API_KEY=placeholder" \
  "Codex: OPENAI_API_KEY (metered)"
pass "an API key wins, is marked metered, and skips the preflight"

launch "$(printf 'CODEX_AUTH_JSON={"pasted":"copy"}\nCODEX_AUTH_FILE=%s' \
  "$(auth_file fresh2 $((now + 900000)))")" \
  "sets CODEX_AUTH_JSON, which is now ignored" \
  "(10d left)"
pass "a leftover CODEX_AUTH_JSON warns and does not win"

echo "1..$pass_count"
