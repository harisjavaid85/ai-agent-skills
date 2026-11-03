#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
NORMALIZER="$REPO/skills/in-progress/kb-ingest/scripts/normalize_structured.py"
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

# Normalizes stdin, saved as the original <file> (default config.json), as key `src`,
# leaving the .md at $TMP_ROOT/<name>/out/src.md and the printed counts at $TMP_ROOT/<name>/output.
normalize() {
  local name="$1" file="${2:-config.json}"
  mkdir -p "$TMP_ROOT/$name"
  cat >"$TMP_ROOT/$name/$file"
  python3 "$NORMALIZER" "$TMP_ROOT/$name/$file" "$TMP_ROOT/$name/out" src \
    >"$TMP_ROOT/$name/output" 2>&1
}

assert_md() {
  local name="$1" expected="$2"
  [ "$(cat "$TMP_ROOT/$name/out/src.md")" = "$expected" ] ||
    fail "$name: unexpected .md:"$'\n'"$(cat "$TMP_ROOT/$name/out/src.md")"
}

test_nesting() {
  normalize nesting <<'EOF'
{"num_key_value_heads": 128, "quantization_config": {"fmt": "e4m3", "inner": {"bits": 8}}}
EOF
  assert_md nesting '```
/num_key_value_heads: 128
/quantization_config/fmt: "e4m3"
/quantization_config/inner/bits: 8
```'
  grep -qx 'src.md written' "$TMP_ROOT/nesting/output" || fail "written line missing"
  grep -qx '  3 leaves' "$TMP_ROOT/nesting/output" || fail "leaf count missing"
  pass "writes one pointer line per nested leaf, in document order, and counts them"
}

test_inline_array() {
  normalize array <<'EOF'
{"weight_block_size": [128, 128], "modules": ["a", {"b": 1}]}
EOF
  assert_md array '```
/weight_block_size: [128, 128]
/modules: ["a", {"b": 1}]
```'
  grep -qx '  2 leaves' "$TMP_ROOT/array/output" || fail "an array counted as more than one leaf"
  pass "keeps an array as one inline leaf, never split per element"
}

test_empty_object() {
  normalize empty <<'EOF'
{"rope_scaling": {}, "next": 1}
EOF
  assert_md empty '```
/rope_scaling: {}
/next: 1
```'
  pass "writes an empty object as a leaf"
}

test_scalars() {
  normalize scalars <<'EOF'
{"s": "bfloat16", "q": "say \"hi\"", "i": 7168, "f": 1e-06, "t": true, "n": null}
EOF
  assert_md scalars '```
/s: "bfloat16"
/q: "say \"hi\""
/i: 7168
/f: 1e-06
/t: true
/n: null
```'
  pass "JSON-encodes string, number, boolean, and null values"
}

test_escapes() {
  normalize escapes <<'EOF'
{"a/b": 1, "m~n": 2, "~/": 3}
EOF
  assert_md escapes '```
/a~1b: 1
/m~0n: 2
/~0~1: 3
```'
  pass "escapes / as ~1 and ~ as ~0"
}

test_refusals() {
  if printf '{"a": ' | normalize invalid; then fail "accepted invalid JSON"; fi
  [ ! -e "$TMP_ROOT/invalid/out" ] || fail "invalid JSON left output behind"
  if printf '{}' | normalize noleaves; then fail "accepted zero leaves"; fi
  [ ! -e "$TMP_ROOT/noleaves/out" ] || fail "zero leaves left output behind"
  pass "refuses invalid JSON and zero leaves, writing nothing"
}

test_unsupported_format() {
  if printf 'a: 1\n' | normalize yaml config.yaml; then fail "accepted a .yaml original"; fi
  [ ! -e "$TMP_ROOT/yaml/out" ] || fail "unsupported format left output behind"
  grep -q 'supported: .json' "$TMP_ROOT/yaml/output" || fail "refusal did not name the supported formats"
  pass "refuses an original whose extension names no supported format, writing nothing"
}

test_nesting
test_inline_array
test_empty_object
test_scalars
test_escapes
test_refusals
test_unsupported_format

echo "1..$pass_count"
