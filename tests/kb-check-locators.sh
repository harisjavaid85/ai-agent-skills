#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$REPO/skills/in-progress/kb-verify/scripts/check_kb_references.py"
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

# Builds a KB holding a paper source `paper` and a structured source `cfg`,
# with the note body read from stdin.
new_kb() {
  local kb="$TMP_ROOT/$1"
  mkdir -p "$kb/knowledge" "$kb/sources/paper" "$kb/sources/cfg"
  cat >"$kb/knowledge/note.md"
  printf -- '- [[note]]: the fixture note\n' >"$kb/knowledge/index.md"
  printf '# Paper\n' >"$kb/sources/paper/paper.md"
  cat >"$kb/sources/cfg/cfg.md" <<'EOF'
```
/num_key_value_heads: 128
/architectures: ["DeepseekV3ForCausalLM"]
/text_config/dtype: "bfloat16"
```
EOF
  cat >"$kb/sources/index.md" <<'EOF'
## paper

- **files:** `paper.md`
- **status:** integrated
- **citing:** Fixture.
- **dropped:** 2026-10-23: nothing

## cfg

- **files:** `cfg.md`
- **status:** integrated
- **citing:** Fixture.
- **dropped:** 2026-10-23: nothing
EOF
  printf '%s\n' "$kb"
}

# Runs the checker on a KB, leaving its output at $TMP_ROOT/output and its exit code in $status.
check() {
  status=0
  python3 "$CHECKER" "$1" >"$TMP_ROOT/output" 2>&1 || status=$?
}

assert_no_defects() {
  [ "$status" -eq 0 ] || fail "$1: exit $status:"$'\n'"$(cat "$TMP_ROOT/output")"
  if grep -q '^DEFECTS' "$TMP_ROOT/output"; then
    fail "$1: DEFECTS printed:"$'\n'"$(cat "$TMP_ROOT/output")"
  fi
}

assert_defect() {
  [ "$status" -ne 0 ] || fail "$1: exit 0 with a DEFECT expected"
  grep -q "$2" "$TMP_ROOT/output" ||
    fail "$1: expected '$2':"$'\n'"$(cat "$TMP_ROOT/output")"
}

test_grammar_forms_pass() {
  local kb
  kb="$(new_kb forms <<'EOF'
Page [paper: p.7], pages [paper: pp.7-9], section [paper: §"Heading text"].
Figure [paper: fig.3], table [paper: tbl.2], equation [paper: eq.4].
Quote [paper: "front matter line"].
Pointer [cfg: /num_key_value_heads], thesis [paper].
EOF
)"
  printf 'front matter line\n# Paper\n' >"$kb/sources/paper/paper.md"
  check "$kb"
  assert_no_defects "grammar forms"
  pass "accepts every locator form in the grammar"
}

test_malformed_locators() {
  local kb citation n=0
  for citation in '[cfg: "num_key_value_heads": 128]' '[paper: tbl.IV]' '[paper:p.7]' '[paper: @12:30]'; do
    n=$((n + 1))
    kb="$(new_kb "malformed-$n" <<<"A claim $citation.")"
    check "$kb"
    assert_defect "$citation" "knowledge/note.md:1  malformed locator"
  done
  pass "reports \"name\": value, tbl.IV, a missing space after :, and a timestamp as malformed locators"
}

# Writes the paper source used by the quote tests: front matter, a heading, a
# line holding inline code and one holding `[`, a fenced block, and a line
# repeated.
quote_source() {
  cat >"$1/sources/paper/paper.md" <<'EOF'
license: apache-2.0

# Paper

## Setup

AITER is Disabled for these runs, and `x = 1` is set.

the interval [a, b) is half-open

```
line in a fence
```

the same phrase
the same phrase
EOF
}

test_quotes() {
  local kb
  kb="$(new_kb quote-allowed <<'EOF'
Front [paper: "license: apache-2.0"], section [paper: "AITER is  Disabled for these runs"].
EOF
)"
  quote_source "$kb"
  check "$kb"
  assert_no_defects "quotes that resolve to one line"

  kb="$(new_kb quote-missing <<<'Kernel [paper: "never written"].')"
  quote_source "$kb"
  check "$kb"
  assert_defect "unfound quote" "knowledge/note.md:1  unresolved quote"

  kb="$(new_kb quote-drifted <<<'Kernel [paper: "never written"] [DRIFTED].')"
  quote_source "$kb"
  check "$kb"
  assert_defect "unfound quote on a [DRIFTED] claim" "knowledge/note.md:1  unresolved quote"

  kb="$(new_kb quote-fenced <<<'Code [paper: "line in a fence"].')"
  quote_source "$kb"
  check "$kb"
  assert_defect "quote inside fenced code" "knowledge/note.md:1  unresolved quote"

  kb="$(new_kb quote-ambiguous <<<'Twice [paper: "the same phrase"].')"
  quote_source "$kb"
  check "$kb"
  assert_defect "quote on two lines" "knowledge/note.md:1  ambiguous quote: 2 lines"

  kb="$(new_kb quote-backtick <<<'Kernel [paper: "and `x = 1` is set"].')"
  quote_source "$kb"
  check "$kb"
  assert_defect "quote span holding a backtick" "knowledge/note.md:1  malformed locator"

  kb="$(new_kb quote-bracket <<<'Interval [paper: "the interval [a, b) is half-open"].')"
  quote_source "$kb"
  check "$kb"
  assert_defect "quote span holding [" "knowledge/note.md:1  malformed locator"

  kb="$(new_kb quote-blank <<<'Blank [paper: " "].')"
  quote_source "$kb"
  check "$kb"
  assert_defect "whitespace-only quote" "malformed locator: an empty quote span"

  # The citation must still be read after the link: its unresolved quote proves it.
  kb="$(new_kb interval-link <<<'Half-open [a, b) intervals and the [docs](https://x.org) agree [paper: "never written"].')"
  quote_source "$kb"
  check "$kb"
  assert_defect "citation after a stray [ and a link" "knowledge/note.md:1  unresolved quote"
  if grep -q 'unresolved key' "$TMP_ROOT/output"; then
    fail "link text after a stray [ read as a key:"$'\n'"$(cat "$TMP_ROOT/output")"
  fi
  pass "resolves quotes to one line; reports unresolved, fenced, ambiguous, and malformed ones"
}

test_pointers() {
  local kb
  kb="$(new_kb resolving <<'EOF'
Heads [cfg: /num_key_value_heads], nested [cfg: /text_config/dtype], class [cfg: /architectures/0].
EOF
)"
  check "$kb"
  assert_no_defects "resolving pointers"

  kb="$(new_kb unresolved <<<'Heads [cfg: /num_heads].')"
  check "$kb"
  assert_defect "unresolved pointer" "knowledge/note.md:1  unresolved pointer \[cfg: /num_heads\]"

  kb="$(new_kb prefix <<<'Heads [cfg: /num_key_value].')"
  check "$kb"
  assert_defect "prefix pointer" "knowledge/note.md:1  unresolved pointer \[cfg: /num_key_value\]"

  kb="$(new_kb out-of-range <<<'Class [cfg: /architectures/1].')"
  check "$kb"
  assert_defect "out-of-range index" "knowledge/note.md:1  unresolved pointer \[cfg: /architectures/1\]"

  kb="$(new_kb separator <<<'Tag [cfg: /tags/1].')"
  printf '/tags: ["a\u2028b", "c"]\n' >>"$kb/sources/cfg/cfg.md"
  check "$kb"
  assert_no_defects "element of an array holding a line separator"

  kb="$(new_kb not-array <<<'Heads [cfg: /num_key_value_heads/0].')"
  check "$kb"
  assert_defect "index into a scalar" "knowledge/note.md:1  unresolved pointer \[cfg: /num_key_value_heads/0\]"

  kb="$(new_kb pointer-drifted <<<'Heads [cfg: /num_heads] [DRIFTED].')"
  check "$kb"
  assert_defect "unresolved pointer on a [DRIFTED] claim" "knowledge/note.md:1  unresolved pointer \[cfg: /num_heads\]"

  pass "resolves leaf and element pointers; reports unresolved and out-of-range ones"
}

test_grammar_forms_pass
test_malformed_locators
test_pointers
test_quotes

echo "1..$pass_count"
