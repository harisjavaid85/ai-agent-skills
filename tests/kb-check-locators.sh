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
# which keeps `cfg.json` and declares `pointer ✓`, with the note body read from stdin.
new_kb() {
  local kb="$TMP_ROOT/$1"
  mkdir -p "$kb/knowledge" "$kb/sources/paper" "$kb/sources/cfg"
  cat >"$kb/knowledge/note.md"
  printf -- '- [[note]]: the fixture note\n' >"$kb/knowledge/index.md"
  printf '# Paper\n' >"$kb/sources/paper/paper.md"
  printf '{}\n' >"$kb/sources/cfg/cfg.json"
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

- **files:** `cfg.md`, `cfg.json`
- **status:** integrated
- **citing:** Fixture.
  - locators: pointer ✓
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

# Fails if the output holds a line matching $2.
assert_absent() {
  if grep -q "$2" "$TMP_ROOT/output"; then
    fail "$1: unexpected '$2':"$'\n'"$(cat "$TMP_ROOT/output")"
  fi
}

# Asserts the region (DEFECTS, FOR JUDGMENT, or HYGIENE) the line matching $3 is printed under.
assert_region() {
  local region
  region="$(awk -v pat="$3" '/^[A-Z][A-Z ]+ \([0-9]+\)$/ { r = $0; sub(/ \(.*/, "", r) } $0 ~ pat { print r; exit }' "$TMP_ROOT/output")"
  [ "$region" = "$2" ] || fail "$1: expected under $2, found under '${region:-nothing}':"$'\n'"$(cat "$TMP_ROOT/output")"
}

# Asserts the summary line counts $2 keys cited.
assert_counted() {
  grep -q ", $2 keys\? cited$" "$TMP_ROOT/output" ||
    fail "$1: expected $2 keys cited:"$'\n'"$(cat "$TMP_ROOT/output")"
}

# Builds a KB whose note is $2, runs the source writer $4 on it if given,
# checks it, and asserts a DEFECT matching $3.
defect_case() {
  local kb
  case_n=$((case_n + 1))
  kb="$(new_kb "case-$case_n" <<<"$2")"
  [ -z "${4:-}" ] || "$4" "$kb"
  check "$kb"
  assert_defect "$1" "$3"
}

# As defect_case, asserting no DEFECT instead, with the source writer as $3.
clean_case() {
  local kb
  case_n=$((case_n + 1))
  kb="$(new_kb "case-$case_n" <<<"$2")"
  [ -z "${3:-}" ] || "$3" "$kb"
  check "$kb"
  assert_no_defects "$1"
}

# Declines `paper` in the registry, dropping its files field.
decline_paper() {
  python3 - "$1/sources/index.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("- **files:** `paper.md`\n- **status:** integrated",
                           "- **status:** declined (out of scope, 2026-10-28)", 1)
open(p, "w").write(s)
PY
}

forms_source() {
  printf 'front matter line\n# Paper\n## Heading text\n' >"$1/sources/paper/paper.md"
}

test_grammar_forms_pass() {
  clean_case "grammar forms" 'Page [paper: p.7], pages [paper: pp.7-9], section [paper: §"Heading text"].
Figure [paper: fig.3], table [paper: tbl.2], equation [paper: eq.4].
Quote [paper: "front matter line"].
Pointer [cfg: /num_key_value_heads], thesis [paper].' forms_source
  pass "accepts every locator form in the grammar"
}

test_malformed_locators() {
  local citation
  for citation in '[cfg: "num_key_value_heads": 128]' '[paper: tbl.IV]' '[paper:p.7]' '[paper: @12:30]'; do
    defect_case "$citation" "A claim $citation." "knowledge/note.md:1  malformed locator"
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
  local unresolved="knowledge/note.md:1  unresolved quote" malformed="knowledge/note.md:1  malformed locator"
  clean_case "quotes that resolve to one line" \
    'Front [paper: "license: apache-2.0"], section [paper: "AITER is  Disabled for these runs"].' quote_source
  defect_case "unfound quote" 'Kernel [paper: "never written"].' "$unresolved" quote_source
  defect_case "unfound quote on a [DRIFTED] claim" 'Kernel [paper: "never written"] [DRIFTED].' "$unresolved" quote_source
  defect_case "quote inside fenced code" 'Code [paper: "line in a fence"].' "$unresolved" quote_source
  defect_case "quote on two lines" 'Twice [paper: "the same phrase"].' \
    "knowledge/note.md:1  ambiguous quote: 2 lines" quote_source
  defect_case "quote span holding a backtick" 'Kernel [paper: "and `x = 1` is set"].' "$malformed" quote_source
  defect_case "quote span holding [" 'Interval [paper: "the interval [a, b) is half-open"].' "$malformed" quote_source
  defect_case "whitespace-only quote" 'Blank [paper: " "].' "malformed locator: an empty quote span" quote_source
  # The citation must still be read after the link: its unresolved quote proves it.
  defect_case "citation after a stray [ and a link" \
    'Half-open [a, b) intervals and the [docs](https://x.org) agree [paper: "never written"].' "$unresolved" quote_source
  assert_absent "link text after a stray [ read as a key" 'unresolved key'
  local link
  for link in '§"[Setup](#setup)"' '"see [docs](https://x.org)"'; do
    defect_case "locator holding a link: $link" "Setup [paper: $link]." "$malformed" quote_source
    assert_absent "locator holding a link: $link" 'orphan key .paper.'
  done
  defect_case "citation after a stray [, its quote holding a link" \
    'Half-open [a, b) and [paper: "see [docs](https://x.org)"].' "$malformed" quote_source
  clean_case "link text shaped like a citation" 'See [Note: "quoted" text](https://x.org), thesis [paper].' quote_source
  pass "resolves quotes to one line; reports unresolved, fenced, ambiguous, and malformed ones, a link in a locator included"
}

# Writes the paper source used by the section tests: a plain heading, a
# decorated one, one holding an entity, two holding backslash escapes, one
# ending in `C#`, one repeated, and one inside a fence.
section_source() {
  cat >"$1/sources/paper/paper.md" <<'EOF'
# Paper

## Setup

### [**3.2 Results #**](#results) ¶

## Reason &amp; Answer

## The max\_tokens API

## Benchmarks \- English

## Using C#

## Notes

## Notes

```
## Fenced
```
EOF
}

remove_body() {
  rm "$1/sources/paper/paper.md"
}

test_sections() {
  local unresolved="knowledge/note.md:1  unresolved section"
  clean_case "sections that resolve to one heading" 'Plain [paper: §"Setup"], decorated [paper: §"3.2 Results"], entity [paper: §"Reason & Answer"].
Hash kept [paper: §"Using C#"], spaced [paper: §"Reason  &  Answer"].
Unescaped [paper: §"The max_tokens API"], copied raw [paper: §"The max\_tokens API"], [paper: §"Benchmarks - English"].' section_source
  defect_case "unfound heading" 'Kernel [paper: §"Method"].' "$unresolved" section_source
  defect_case "heading inside fenced code" 'Code [paper: §"Fenced"].' "$unresolved" section_source
  defect_case "heading differing in case" 'Case [paper: §"setup"].' "$unresolved" section_source
  defect_case "heading on two lines" 'Twice [paper: §"Notes"].' \
    "knowledge/note.md:1  ambiguous section: 2 headings" section_source
  assert_region "heading on two lines" DEFECTS "ambiguous section"
  defect_case "whitespace-only section" 'Blank [paper: §" "].' "malformed locator: an empty section name" section_source
  defect_case "section into an absent <key>.md" 'Kernel [paper: §"Setup"].' "$unresolved" remove_body
  defect_case "section citing a declined key" 'Kernel [paper: §"Method"].' "cites declined key \[paper\]" decline_paper
  assert_absent "section citing a declined key" 'unresolved section'
  defect_case "unfound heading on a [DRIFTED] claim" 'Kernel [paper: §"Method"] [DRIFTED].' "$unresolved" section_source
  pass "resolves sections to one heading, decoration and escapes aside; reports unresolved, fenced, ambiguous, and empty ones"
}

# Adds an array leaf holding a U+2028 line separator inside cfg's fence.
separator_source() {
  sed -i "\$i /tags: [\"a$(printf '\342\200\250')b\", \"c\"]" "$1/sources/cfg/cfg.md"
}

test_pointers() {
  local unresolved="knowledge/note.md:1  unresolved pointer: no line of sources/cfg/cfg.md opens with it"
  clean_case "resolving pointers" \
    'Heads [cfg: /num_key_value_heads], nested [cfg: /text_config/dtype], class [cfg: /architectures/0].'
  assert_absent "resolving pointers" "is not one fenced block of pointer lines"
  defect_case "unresolved pointer" 'Heads [cfg: /num_heads].' "$unresolved \[cfg: /num_heads\]"
  defect_case "prefix pointer" 'Heads [cfg: /num_key_value].' "$unresolved \[cfg: /num_key_value\]"
  defect_case "out-of-range index" 'Class [cfg: /architectures/1].' "$unresolved \[cfg: /architectures/1\]"
  clean_case "element of an array holding a line separator" 'Tag [cfg: /tags/1].' separator_source
  defect_case "index into a scalar" 'Heads [cfg: /num_key_value_heads/0].' \
    "$unresolved \[cfg: /num_key_value_heads/0\]"
  defect_case "unresolved pointer on a [DRIFTED] claim" 'Heads [cfg: /num_heads] [DRIFTED].' \
    "$unresolved \[cfg: /num_heads\]"
  clean_case "whole-file and map pointers" 'Keys [cfg: /], block [cfg: /text_config].'
  defect_case "trailing slash on a map" 'Block [cfg: /text_config/].' "$unresolved \[cfg: /text_config/\]"
  defect_case "part of a key name as a map" 'Block [cfg: /text].' "$unresolved \[cfg: /text\]"
  clean_case "empty-key child" 'Empty [cfg: /text_config/].' empty_key_source
  pass "resolves leaf, element, map, and whole-file pointers; reports unresolved and out-of-range ones"
}

# Gives `cfg` a child of /text_config under the empty key.
empty_key_source() {
  sed -i 's#^/text_config/dtype: "bfloat16"$#&\n/text_config/: 1#' "$1/sources/cfg/cfg.md"
}

# A paper whose body is one fenced block of paths, then prose.
fenced_paper() {
  printf '```\n/usr/lib/a.so\n```\n\nProse.\n' >"$1/sources/paper/paper.md"
}

# A paper whose body is one fenced block of paths alone.
paths_paper() {
  printf '```\n/usr/lib/a.so\n```\n' >"$1/sources/paper/paper.md"
}

# A paper that also keeps a `.json`, declaring no pointer mark.
paper_with_json() {
  printf '{}\n' >"$1/sources/paper/paper.json"
  sed -i 's/^- \*\*files:\*\* `paper.md`$/- **files:** `paper.md`, `paper.json`/' "$1/sources/index.md"
  printf '/a: 1\n' >"$1/sources/paper/paper.md"
}

# cfg declaring pointer ✓ while keeping no data original.
cfg_without_original() {
  rm "$1/sources/cfg/cfg.json"
  sed -i 's/^- \*\*files:\*\* `cfg.md`, `cfg.json`$/- **files:** `cfg.md`/' "$1/sources/index.md"
}

# cfg declaring pointer ✓ over a prose `.md`.
cfg_prose_body() {
  printf '# Config\n\nProse.\n' >"$1/sources/cfg/cfg.md"
}

# cfg declaring pointer ✓ with no files field at all.
cfg_without_files() {
  sed -i '/^- \*\*files:\*\* `cfg.md`, `cfg.json`$/d' "$1/sources/index.md"
}

# cfg naming `config.json` only inside a URL, keeping no data original.
cfg_original_only_in_url() {
  cfg_without_original "$1"
  sed -i 's|^- \*\*files:\*\* `cfg.md`$|- **files:** `cfg.md` (`https://hf.co/x/config.json`)|' "$1/sources/index.md"
}

# cfg keeping a `.yaml` original instead of a `.json`.
cfg_yaml_original() {
  mv "$1/sources/cfg/cfg.json" "$1/sources/cfg/cfg.yaml"
  sed -i 's/`cfg.json`/`cfg.yaml`/' "$1/sources/index.md"
}

# cfg's locators line wrapped, `pointer ✓` on its continuation line.
cfg_wrapped_locators() {
  sed -i 's/^  - locators: pointer ✓$/  - locators:\n    pointer ✓\n  - checked: 3 leaves/' "$1/sources/index.md"
}

# cfg's locators sub-bullet written `Locators:`.
cfg_capitalized_locators() {
  sed -i 's/^  - locators: pointer ✓$/  - Locators: pointer ✓/' "$1/sources/index.md"
}

# Declines `cfg`, dropping its files field and leaving its folder.
decline_cfg() {
  sed -i 's/^- \*\*files:\*\* `cfg.md`, `cfg.json`$//; /^## cfg$/,$ s/^- \*\*status:\*\* integrated$/- **status:** declined (out of scope, 2026-10-28)/' "$1/sources/index.md"
}

# cfg marking pointer ✗: not declared structured.
cfg_pointer_unchecked() {
  sed -i 's/^  - locators: pointer ✓$/  - locators: pointer ✗/' "$1/sources/index.md"
}

# cfg whose `pointer ✓` sits in damaged:, not locators:.
cfg_pointer_in_damaged() {
  sed -i 's/^  - locators: pointer ✓$/  - locators: p ✓\n  - damaged (1): throughout: pointer ✓ lines garbled/' "$1/sources/index.md"
}

test_locator_form_follows_the_registry() {
  local citation
  for citation in '[cfg: p.3]' '[cfg: tbl.2]' '[cfg: §"dtype"]' '[cfg: "bfloat16"]'; do
    defect_case "$citation" "A claim $citation." \
      "knowledge/note.md:1  wrong-form locator: \[cfg\] is a structured source"
  done
  defect_case "pointer into a paper" 'Value [paper: /a].' \
    "knowledge/note.md:1  wrong-form locator: \[paper\] is not a structured source" paper_with_json
  clean_case "page into a paper keeping a .json" 'Page [paper: p.3].' paper_with_json
  clean_case "page into a paper" 'Page [paper: p.3].'
  clean_case "page into a paper opening with a fence of paths" 'Page [paper: p.3].' fenced_paper
  clean_case "page into a paper that is a fence of paths" 'Page [paper: p.3].' paths_paper
  defect_case "declared structured source with no data original" 'Heads [cfg: /num_key_value_heads].' "cfg. declares pointer ✓ but files lists no data original" cfg_without_original
  assert_region "declared structured source with no data original" DEFECTS "cfg. declares pointer ✓ but files lists no data original"
  defect_case "declared structured source with no files field" 'Heads [cfg: /num_key_value_heads].' "cfg. declares pointer ✓ but files lists no data original" cfg_without_files
  assert_region "declared structured source with no files field" DEFECTS "cfg. declares pointer ✓ but files lists no data original"
  defect_case "data original named only in a URL" 'Heads [cfg: /num_key_value_heads].' "cfg. declares pointer ✓ but files lists no data original" cfg_original_only_in_url
  assert_region "data original named only in a URL" DEFECTS "cfg. declares pointer ✓ but files lists no data original"
  clean_case "YAML data original" 'Heads [cfg: /num_key_value_heads].' cfg_yaml_original
  assert_absent "YAML data original" "no data original"
  defect_case "declared structured source with a prose .md" 'Thesis [paper].' "cfg. declares pointer ✓ but its .md is not one fenced block of pointer lines" cfg_prose_body
  assert_region "declared structured source with a prose .md" DEFECTS "cfg. declares pointer ✓ but its .md is not one fenced block of pointer lines"
  defect_case "locators wrapped onto a second line" 'Page [cfg: p.3].' \
    "wrong-form locator: \[cfg\] is a structured source" cfg_wrapped_locators
  defect_case "locators field capitalized" 'Page [cfg: p.3].' \
    "wrong-form locator: \\[cfg\\] is a structured source" cfg_capitalized_locators
  defect_case "pointer into a pointer-shaped source not declared structured" 'Heads [cfg: /num_key_value_heads].' \
    "wrong-form locator: \\[cfg\\] is not a structured source" cfg_pointer_unchecked
  defect_case "declined structured source" 'Heads [cfg: /num_key_value_heads].' "cites declined key \\[cfg\\]" decline_cfg
  assert_absent "declined structured source" "wrong-form locator"
  assert_absent "declined structured source" "declares pointer ✓"
  for writer in cfg_pointer_unchecked cfg_pointer_in_damaged; do
    clean_case "no pointer ✓ in locators: $writer" 'Page [cfg: p.3].' "$writer"
  done
  pass "takes the form a source's registry entry declares: pointers into a structured source, and into no other"
}

# A paper line holding `, cfg:` inside quotable text.
comma_line_paper() {
  printf '# Paper\nalpha, cfg: beta\n' >"$1/sources/paper/paper.md"
}

# A cfg leaf whose name holds `, paper`.
comma_leaf_cfg() {
  sed -i '$i /a, paper: 1' "$1/sources/cfg/cfg.md"
}

test_one_locator_per_bracket() {
  local own="give each locator its own brackets"
  defect_case "key list" 'A claim [cfg, paper].' "knowledge/note.md:1  malformed locator \[cfg, paper\]: $own"
  assert_counted "key list" 2
  defect_case "key list with ;" 'A claim [paper; cfg].' "knowledge/note.md:1  malformed locator \[paper; cfg\]: $own"
  defect_case "key list ending in a locator" 'A claim [paper, cfg: /num_key_value_heads].' \
    "knowledge/note.md:1  malformed locator \[paper, cfg: /num_key_value_heads\]: $own"
  assert_counted "key list ending in a locator" 2
  local prose
  for prose in '[128, 128]' '[TODO, notes]' '[cfg, TODO]'; do
    clean_case "bracketed prose $prose" "Shape $prose here [paper]."
  done
  defect_case "two sources in one locator" 'A claim [paper: p.1; cfg: /a].' \
    "knowledge/note.md:1  malformed locator \[paper: p.1; cfg: /a\]: $own"
  assert_counted "two sources in one locator" 2
  defect_case "pointer first, then ;" 'A claim [cfg: /num_key_value_heads; paper: p.1].' \
    "unresolved pointer: .* \[cfg: /num_key_value_heads; paper: p.1\]: $own"
  defect_case "pointer first, then ," 'A claim [cfg: /num_key_value_heads, paper].' \
    "unresolved pointer: .* \[cfg: /num_key_value_heads, paper\]: $own"
  defect_case "; before a word that is no key" 'A claim [paper: p.1; see below].' \
    "malformed locator \[paper: p.1; see below\]: write one of"
  assert_absent "; before a word that is no key" "$own"
  defect_case "a key after a comma inside a quote" 'A claim [paper: "nothing, cfg: here"].' \
    "unresolved quote"
  assert_absent "a key after a comma inside a quote" "$own"
  defect_case "a key after a comma inside a section name" 'A claim [paper: §"Setup, cfg: notes"].' \
    "unresolved section"
  assert_absent "a key after a comma inside a section name" "$own"
  clean_case "a key list as link text" 'See [paper, cfg](https://example.org) [paper].'
  defect_case "a declined key named second" 'A claim [paper: p.1; cfg: p.2].' \
    "malformed locator \[paper: p.1; cfg: p.2\]: $own" decline_cfg
  assert_absent "a declined key named second" "cites declined key"
  defect_case "one source, a second locator form" 'A claim [paper: p.1; p.4].' \
    "malformed locator \[paper: p.1; p.4\]: $own"
  defect_case "a second locator on the wrong-form path" 'A claim [paper: /a; cfg: /b].' \
    "wrong-form locator: .* \[paper: /a; cfg: /b\]: $own"
  defect_case "a key after a closed quote" 'A claim [paper: "x", cfg].' \
    "malformed locator \[paper: \"x\", cfg\]: $own"
  clean_case "a resolving quote holding , cfg:" 'A claim [paper: "alpha, cfg: beta"].' comma_line_paper
  assert_absent "a resolving quote holding , cfg:" "$own"
  assert_region "a resolving quote holding , cfg:" HYGIENE "orphan key .cfg."
  clean_case "a resolving pointer holding , paper" 'A claim [cfg: /a, paper].' comma_leaf_cfg
  assert_region "a resolving pointer holding , paper" HYGIENE "orphan key .paper."
  defect_case "a key list whose locator names another key" 'A claim [cfg, cfg: /a; paper: p.2].' \
    "malformed locator \[cfg, cfg: /a; paper: p.2\]: $own"
  assert_absent "a key list whose locator names another key" "orphan key .paper."
  defect_case "a declined key, then a second locator" 'A claim [cfg: /a, paper].' \
    "cites declined key .cfg.: .*: $own" decline_cfg
  assert_absent "a declined key, then a second locator" "orphan key .paper."
  defect_case "a malformed first locator, then a second" 'A claim [paper: Table 2, "alpha"].' \
    "malformed locator .*: write one of the citation contract's forms; $own"
  defect_case "a key inside a quote after the first locator" 'A claim [paper: p.1; "alpha, cfg: beta"].' \
    "malformed locator .*: $own"
  assert_region "a key inside a quote after the first locator" HYGIENE "orphan key .cfg."
  defect_case "a quote left open" 'A claim [paper: "hello, cfg: world].' "malformed locator .*: write one of"
  assert_absent "a quote left open" "$own"
  defect_case "a trailing key after a page" 'A claim [paper: p.1, cfg].' \
    "malformed locator \[paper: p.1, cfg\]: $own"
  defect_case "one source, two locators" 'A claim [paper: p.1; paper: p.4].' \
    "malformed locator \[paper: p.1; paper: p.4\]: $own"
  defect_case "an unregistered key, then a source" 'A claim [typo: p.1; paper: p.2].' \
    "unresolved key \[typo\]: $own"
  assert_absent "an unregistered key, then a source" "orphan key \[paper\]"
  clean_case "a citation group" 'Both state it [paper: p.1] [cfg: /num_key_value_heads].'
  assert_counted "a citation group" 2
  pass "reports a bracket holding several locators, and leaves bracketed prose and a citation group alone"
}

replace_body_with_pdf() {
  remove_body "$1"
  : >"$1/sources/paper/other.pdf"
}

list_original() {
  sed -i 's/^- \*\*files:\*\* `paper.md`$/- **files:** `paper.md`, `paper.pdf`/' "$1/sources/index.md"
}

duplicate_note() {
  mkdir "$1/knowledge/sub"
  cp "$1/knowledge/note.md" "$1/knowledge/sub/note.md"
}

remove_dir() {
  rm -r "$1/sources/paper"
}

remove_dir_and_files() {
  remove_dir "$1"
  sed -i '/^- \*\*files:\*\* `paper.md`$/d' "$1/sources/index.md"
}

test_regions() {
  defect_case "dangling link" 'See [[nowhere]].' "knowledge/note.md:1  dangling link"
  assert_region "dangling link" DEFECTS "dangling link"
  defect_case "files listing an absent <key>.md" 'Thesis [paper].' 'lists `paper.md`, absent' replace_body_with_pdf
  assert_region "files listing an absent <key>.md" DEFECTS 'lists `paper.md`, absent'
  assert_region "unlisted file" HYGIENE "other.pdf  on disk, unlisted"
  defect_case "files listing an absent original" 'Page [paper: p.3].' 'lists `paper.pdf`, absent' list_original
  assert_region "files listing an absent original" DEFECTS 'lists `paper.pdf`, absent'
  defect_case "duplicate note name" 'See [[note]].' "duplicate note name 'note'" duplicate_note
  assert_region "duplicate note name" DEFECTS "duplicate note name 'note'"
  defect_case "files listing an absent directory" 'Thesis [paper].' "sources/paper/ does not exist" remove_dir
  assert_region "files listing an absent directory" DEFECTS "sources/paper/ does not exist"
  defect_case "absent directory, no files field" 'Thesis [paper].' "sources/paper/ does not exist" remove_dir_and_files
  assert_region "absent directory, no files field" DEFECTS "sources/paper/ does not exist"
  assert_absent "absent directory, no files field: asks to list an absent folder" '.paper. has no files'
  clean_case "declined key's folder still on disk" 'Heads [cfg: /num_key_value_heads].' decline_paper
  assert_region "declined key's folder still on disk" HYGIENE 'declined .paper.: sources/paper/ still exists'
  pass "reports a dangling link, a duplicate note name, and an absent listed path as defects, a declined key's leftover folder as hygiene"
}

fence_in_index() {
  cat >"$1/knowledge/index.md" <<'EOF'
- [[note]]: the fixture note
```
code
```
  one two three four five six seven eight nine ten eleven twelve thirteen fourteen
  fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three
  twenty-four twenty-five twenty-six twenty-seven twenty-eight twenty-nine thirty
  thirty-one thirty-two thirty-three thirty-four thirty-five thirty-six thirty-seven
  thirty-eight thirty-nine forty forty-one forty-two forty-three forty-four forty-five
EOF
}

two_dropped_values() {
  sed -i 's/^- \*\*dropped:\*\* 2026-10-23: nothing$/- **dropped:** 2026-10-23: nothing\n  2026-10-24: nothing again/' "$1/sources/index.md"
}

test_registry_and_index() {
  clean_case "indented line after a fence in the index" 'Thesis [paper].' fence_in_index
  assert_absent "indented line after a fence glued onto the entry above" 'entry runs'
  clean_case "dropped wrapped onto a second dated line" 'Thesis [paper].' two_dropped_values
  assert_region "dropped wrapped onto a second dated line" HYGIENE "dropped carries 2 dated values"
  pass "ends an index entry at a fence; counts each dated line of dropped"
}

test_anchors() {
  clean_case "in-page anchors resolve" "$(printf '%s\n' \
    '# Note' '## Disk: the `next` tier' 'Body [paper], see [below](#disk-the-next-tier).' \
    '## Repeat' '## Repeat' 'Second [one](#repeat-1).')"
  defect_case "anchor to a renamed heading" "$(printf '%s\n' \
    '# Note' '## New name' 'Body [paper], see [below](#old-name).')" 'dangling link (#old-name)'
  defect_case "anchor to a heading only inside fenced code" "$(printf '%s\n' \
    '# Note' '```' '## Fenced' '```' 'Body [paper], see [below](#fenced).')" 'dangling link (#fenced)'
  pass "resolves in-page anchors against the note's own headings"
}

case_n=0
test_grammar_forms_pass
test_malformed_locators
test_pointers
test_locator_form_follows_the_registry
test_one_locator_per_bracket
test_quotes
test_sections
test_regions
test_registry_and_index
test_anchors

echo "1..$pass_count"
