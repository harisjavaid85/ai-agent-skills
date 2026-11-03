#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CHANGES="$REPO/skills/in-progress/kb-verify/scripts/kb_changes.py"
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

# Builds a committed KB repo holding knowledge/a.md and knowledge/b.md, and prints its root.
new_kb() {
  local kb="$TMP_ROOT/$1"
  mkdir -p "$kb/knowledge" "$kb/sources"
  cat >"$kb/knowledge/a.md" <<'EOF'
# A

Opening sentence [pa: p.1].

## Routing

Each token picks 8 experts [pa: p.2].
One expert is shared [pa: p.3].

## Results

Accuracy rises [qb: tbl.1].

```
## not a heading
```
EOF
  cat >"$kb/knowledge/b.md" <<'EOF'
# B

B opens here.

## Costs

Cost falls [qb: p.5].
EOF
  printf -- '- [[a]]: routing, results\n- [[b]]: costs\n' >"$kb/knowledge/index.md"
  git -C "$kb" init -q
  git -C "$kb" add -A
  git -C "$kb" -c user.name=t -c user.email=t@t commit -qm base
  printf '%s\n' "$kb"
}

# Runs `sections` on a KB against $2, leaving its output at $TMP_ROOT/output.
sections() {
  python3 "$CHANGES" sections "$1" "$2" >"$TMP_ROOT/output" 2>&1 ||
    fail "sections exited non-zero:"$'\n'"$(cat "$TMP_ROOT/output")"
}

# Fails unless the output equals stdin exactly.
assert_output() {
  local expected
  expected="$(cat)"
  [ "$(cat "$TMP_ROOT/output")" = "$expected" ] ||
    fail "$1:"$'\n'"expected:"$'\n'"$expected"$'\n'"got:"$'\n'"$(cat "$TMP_ROOT/output")"
}

test_nothing_changed() {
  local kb
  kb="$(new_kb unchanged)"
  sections "$kb" uncommitted
  assert_output "no change lists nothing" </dev/null
  pass "lists nothing when nothing changed"
}

test_modified_section_and_opening() {
  local kb
  kb="$(new_kb modified)"
  sed -i 's/Accuracy rises/Accuracy rises sharply/' "$kb/knowledge/a.md"
  sed -i 's/B opens here./B opens here, briefly./' "$kb/knowledge/b.md"
  sections "$kb" uncommitted
  assert_output "modified section and opening" <<'EOF'
section  knowledge/a.md › ## Results
section  knowledge/b.md › (opening)
EOF
  pass "maps a changed line to its ## section, or to the opening above the first ##"
}

test_deletion_only_hunks() {
  local kb
  kb="$(new_kb deletions)"
  sed -i '/^One expert is shared/d' "$kb/knowledge/a.md"
  sed -i '/^B opens here.$/d' "$kb/knowledge/b.md"
  sections "$kb" uncommitted
  assert_output "deletion-only hunks" <<'EOF'
section  knowledge/a.md › ## Routing
section  knowledge/b.md › (opening)
citation-removed  knowledge/a.md › ## Routing  [pa: p.3]
EOF
  pass "maps a deletion-only hunk to the section or opening now holding its position"
}

test_new_deleted_untracked() {
  local kb
  kb="$(new_kb notes)"
  git -C "$kb" rm -q knowledge/b.md
  printf '# C\n\nC holds [qb: p.9].\n' >"$kb/knowledge/c.md"
  sections "$kb" uncommitted
  assert_output "new, untracked, deleted" <<'EOF'
new-note knowledge/c.md
deleted  knowledge/b.md
EOF
  pass "lists an untracked new note and a deleted note, and no citation of either"
}

test_renamed_heading() {
  local kb
  kb="$(new_kb renamed)"
  sed -i 's/^## Routing$/## Expert routing/' "$kb/knowledge/a.md"
  sections "$kb" uncommitted
  assert_output "renamed heading" <<'EOF'
section  knowledge/a.md › ## Expert routing
EOF
  pass "lists a renamed heading under its new name"
}

test_removed_and_moved_citations() {
  local kb
  kb="$(new_kb citations)"
  sed -i 's/Accuracy rises \[qb: tbl.1\]./Accuracy rises./' "$kb/knowledge/a.md"
  sed -i 's/Cost falls \[qb: p.5\]./Cost falls./' "$kb/knowledge/b.md"
  sed -i 's/Opening sentence \[pa: p.1\]./Opening sentence [qb: p.5]./' "$kb/knowledge/a.md"
  sections "$kb" uncommitted
  assert_output "removed and moved citations" <<'EOF'
section  knowledge/a.md › (opening)
section  knowledge/a.md › ## Results
section  knowledge/b.md › ## Costs
citation-removed  knowledge/a.md › (opening)  [pa: p.1]
citation-removed  knowledge/a.md › ## Results  [qb: tbl.1]
citation-moved  knowledge/b.md › ## Costs -> knowledge/a.md › (opening)  [qb: p.5]
EOF
  pass "lists a removed citation, and one removed here and added there as moved"
}

test_citation_moved_within_section() {
  local kb
  kb="$(new_kb within)"
  sed -i 's/Each token picks 8 experts \[pa: p.2\]./Each token picks 8 experts./' "$kb/knowledge/a.md"
  sed -i 's/One expert is shared \[pa: p.3\]./One expert is shared [pa: p.3] [pa: p.2]./' "$kb/knowledge/a.md"
  sections "$kb" uncommitted
  assert_output "citation moved within a section" <<'EOF'
section  knowledge/a.md › ## Routing
EOF
  pass "lists the section a citation moved within, and no citation line"
}

test_unchanged_citation_on_edited_line() {
  local kb
  kb="$(new_kb kept)"
  sed -i 's/Each token picks 8 experts/Each token picks eight experts/' "$kb/knowledge/a.md"
  printf '\n## Results\n\nA second results section [rc: p.1].\n' >>"$kb/knowledge/b.md"
  printf '\n## Results\n\nAgain [rc: p.2].\n' >>"$kb/knowledge/b.md"
  sections "$kb" uncommitted
  assert_output "kept citation, repeated heading" <<'EOF'
section  knowledge/a.md › ## Routing
section  knowledge/b.md › ## Costs
section  knowledge/b.md › ## Results (1)
section  knowledge/b.md › ## Results (2)
EOF
  pass "keeps a citation an edited line still carries out of the list, and numbers a repeated heading"
}

test_fenced_code() {
  local kb
  kb="$(new_kb fenced)"
  sed -i 's/^## not a heading$/## not a heading [xd: p.1]/' "$kb/knowledge/a.md"
  sections "$kb" uncommitted
  assert_output "fenced code" <<'EOF'
section  knowledge/a.md › ## Results
EOF
  pass "reads a ## line in fenced code as content, and no citation there"
}

test_snapshot() {
  local kb snap index_before
  kb="$(new_kb snapshot)"
  sed -i 's/Cost falls/Cost falls fast/' "$kb/knowledge/b.md"
  git -C "$kb" add knowledge/b.md
  index_before="$(git -C "$kb" ls-files -s | sha1sum)"
  snap="$(python3 "$CHANGES" snapshot "$kb")"
  [ "$(git -C "$kb" cat-file -t "$snap")" = tree ] || fail "snapshot: $snap is not a tree"
  printf 'New text [pa: p.4].\n' >>"$kb/knowledge/a.md"
  printf '# D\n' >"$kb/knowledge/d.md"
  [ "$(git -C "$kb" ls-files -s | sha1sum)" = "$index_before" ] || fail "snapshot: the user's index changed"
  [ -z "$(git -C "$kb" ls-files knowledge/d.md)" ] || fail "snapshot: staged a file"
  sections "$kb" "$snap"
  assert_output "since a snapshot" <<'EOF'
section  knowledge/a.md › ## Results
new-note knowledge/d.md
EOF
  [ "$(git -C "$kb" ls-files -s | sha1sum)" = "$index_before" ] || fail "sections: the user's index changed"
  pass "lists only what changed since a snapshot, leaving the user's index untouched"
}

test_bad_snapshot() {
  local kb
  kb="$(new_kb bad)"
  if python3 "$CHANGES" sections "$kb" HEAD >"$TMP_ROOT/output" 2>&1; then
    fail "a commit was accepted as a snapshot"
  fi
  grep -q "not a snapshot" "$TMP_ROOT/output" || fail "bad snapshot: $(cat "$TMP_ROOT/output")"
  pass "refuses anything but a snapshot or uncommitted"
}

test_nothing_changed
test_modified_section_and_opening
test_deletion_only_hunks
test_new_deleted_untracked
test_renamed_heading
test_removed_and_moved_citations
test_citation_moved_within_section
test_unchanged_citation_on_edited_line
test_fenced_code
test_snapshot
test_bad_snapshot

echo "1..$pass_count"
