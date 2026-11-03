#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
UTILS="$REPO/skills/in-progress/kb-ingest/scripts/conversion_utils.py"
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

# Saves stdin as $TMP_ROOT/<name>/src.md and reports on it, leaving the printed counts at $TMP_ROOT/<name>/output.
counts() {
  local name="$1"
  mkdir -p "$TMP_ROOT/$name"
  cat >"$TMP_ROOT/$name/src.md"
  python3 "$UTILS" "$TMP_ROOT/$name" src >"$TMP_ROOT/$name/output" 2>&1 ||
    fail "$name: exited non-zero:"$'\n'"$(output "$name")"
}

output() {
  cat "$TMP_ROOT/$1/output"
}

test_arabic_gap() {
  counts arabic <<'EOF'
Table 1: Setup

TABLE 3: Results

As Table 4 shows, throughput doubles; see also table 5.
EOF
  grep -q '2 captions (2 distinct)' "$TMP_ROOT/arabic/output" || fail "arabic: caption count:"$'\n'"$(output arabic)"
  grep -qx '  caption gap: Table 2, Table 4, Table 5 (no line-initial caption)' "$TMP_ROOT/arabic/output" ||
    fail "arabic: gap line:"$'\n'"$(output arabic)"
  pass "prints a number missing below the highest caption and one referenced but uncaptioned"
}

test_roman_captions() {
  counts roman <<'EOF'
TABLE I: Hardware configuration

| GPU | count |
|---|---|
| A100 | 8 |

- TABLE IV: Throughput results

| model | tok/s |
|---|---|
| a | 1 |

Table 4: Throughput results, continued

As shown in Table 4 and Table II, throughput doubles. We revisit Table IV later, and see Table VI.
EOF
  grep -q '3 captions (2 distinct)' "$TMP_ROOT/roman/output" || fail "roman: caption count:"$'\n'"$(output roman)"
  grep -qx '  caption gap: Table 2, Table 3, Table 6 (no line-initial caption)' "$TMP_ROOT/roman/output" ||
    fail "roman: gap line:"$'\n'"$(output roman)"
  pass "reads a Roman table number as its Arabic value, in captions, references, and the distinct count"
}

test_roman_needs_capital() {
  counts lower <<'EOF'
In the table I built, every row is a run.
table I lists them all.
EOF
  grep -q '0 tables, 0 captions (0 distinct)' "$TMP_ROOT/lower/output" || fail "lower: read a lowercase caption:"$'\n'"$(output lower)"
  grep -qx 'src.md written' "$TMP_ROOT/lower/output" || fail "lower: no report:"$'\n'"$(output lower)"
  if grep -q 'caption gap' "$TMP_ROOT/lower/output"; then fail "lower: read prose as a reference:"$'\n'"$(output lower)"; fi
  pass "takes a Roman number only after a capitalized Table, so 'the table I built' is no reference"
}

test_roman_word_boundary() {
  counts boundary <<'EOF'
Table Is not a number, nor is Table XL, Table iv, or Table C.1.
EOF
  grep -qx 'src.md written' "$TMP_ROOT/boundary/output" || fail "boundary: no report:"$'\n'"$(output boundary)"
  if grep -q 'caption gap' "$TMP_ROOT/boundary/output"; then fail "boundary: read a non-numeral:"$'\n'"$(output boundary)"; fi
  pass "reads no Roman number from a longer word or a letter outside I, V, X"
}

test_figures_unchanged() {
  counts figures <<'EOF'
Figure 1: Overview

Fig. 3: Ablation

See Figure 2, then FIGURE IV.

Figure II: Extra
EOF
  grep -q '2 captions (2 distinct) · 0 headings' "$TMP_ROOT/figures/output" || fail "figures: caption count:"$'\n'"$(output figures)"
  grep -qx '  caption gap: Figure 2 (no line-initial caption)' "$TMP_ROOT/figures/output" ||
    fail "figures: gap line:"$'\n'"$(output figures)"
  pass "keeps figure captions Arabic and reports their gaps as before"
}

test_arabic_gap
test_roman_captions
test_roman_needs_capital
test_roman_word_boundary
test_figures_unchanged

echo "1..$pass_count"
