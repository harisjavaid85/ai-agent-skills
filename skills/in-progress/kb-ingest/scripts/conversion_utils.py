"""The emptiness guard and the counts, shared by both conversion wrappers so an
entry's `checked:` line reads the same whichever route produced the `.md`.

The counts are paired on purpose, and the mismatch is the signal: more captions
than objects means something was lost, more objects than captions means
something was shredded into extra blocks or a caption detached. Objects pair
against **distinct** caption numbers; the total prints beside them, so a difference
between the two means a number captioned twice or a line-initial cross-reference.

Agreement is necessary, not sufficient: it counts how many captions exist and
never which numbers they carry, so a document that lost Tables 7 and 8 still
reports 8 tables against 8 captions. The `caption gap:` line carries the rest,
as leads for `damaged:`: a prose reference to another work's table prints a gap
that is no loss, and a cross-reference opening a line reads as a caption, so the
`caption gap:` line can print a false gap or hide a real one. Confirm each against
the source; an absent line is unproven. A Roman table number prints as its Arabic
value, so a gap's `Table 4` may read `TABLE IV` in the source.

HTML tables are counted as a separate unpaired term, supporting no `tbl.N`
locator to fold into the markdown table count.

Lost equations are counted but paired with nothing. The `.md` cannot say how
many the source held, so the number is a floor and belongs in `damaged:` as a
finding rather than in `checked:` as an inspection scope.

An unresolved image link is a warning, never a failure. A source whose figures
live somewhere the conversion could not fetch is still a correct ingest; the
caveat belongs in `citing`, and a guard that exited non-zero would reject it.
"""

import os
import re
import sys
import urllib.parse

IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)]*)\)")
HEADING = re.compile(r"^#{1,6} ", re.M)
# The leading class strips markdown decoration, both bullet characters included,
# since docling emits captions as list items. A table number is Arabic in any case,
# or Roman (IEEE's `TABLE IV`) after a capitalized `Table` or `TABLE`, so prose such
# as "the table I built" is no reference.
TABLE_NUMBER = r"(?:(?i:table)\s+(\d+)|(?:Table|TABLE)\s+([IVX]+)\b)"
TABLE_CAPTION = re.compile(r"^[-#*>\s]*" + TABLE_NUMBER, re.M)
FIGURE_CAPTION = re.compile(r"^[-#*>\s]*(?:Figure|Fig\.)\s*(\d+)", re.M | re.I)
TABLE_REF = re.compile(r"\b" + TABLE_NUMBER)
FIGURE_REF = re.compile(r"\b(?:Figure|Fig\.)\s*(\d+)", re.I)
HTML_TABLE = re.compile(r"<table", re.I)
LOST_EQUATION = re.compile(r"formula-not-decoded")
REMOTE = ("http://", "https://", "//", "data:", "mailto:")

MIN_CHARS = 200


def refuse_if_empty(md):
    """Stop on a conversion that produced almost no text.

    On a source with no extractable text docling exits 0 having written an empty
    file, which `--abort-on-error` does not cover, so a scanned or JS-rendered
    page would otherwise register as a successful ingest. Call before creating
    the destination directory, so a source that cannot be ingested leaves
    nothing behind.
    """
    text = md.strip()
    if len(text) < MIN_CHARS:
        sys.exit(f"docling produced {len(text)} chars: source not ingestible "
                 f"(likely a scanned or JS-rendered source with no extractable text)")


def table_blocks(lines):
    """Group runs of consecutive `|`-led lines into table blocks.

    A block is one markdown table. A table shredded across a page break leaves
    more blocks than the source has tables, which is why this count is read
    against the `Table N` caption count rather than on its own.
    """
    rows = [i for i, l in enumerate(lines) if l.startswith("|")]
    blocks, cur = [], []
    for i in rows:
        if cur and i == cur[-1] + 1:
            cur.append(i)
        else:
            if cur:
                blocks.append(cur)
            cur = [i]
    if cur:
        blocks.append(cur)
    return blocks


def image_targets(md):
    """Every image link target, title and angle brackets stripped."""
    out = []
    for _, target in IMAGE.findall(md):
        t = target.strip()
        if t.startswith("<") and ">" in t:
            t = t[1:t.index(">")]
        else:
            parts = t.split()
            t = parts[0] if parts else ""
        if t:
            out.append(t)
    return out


def link_state(target, base):
    """Classify one image link: None if it resolves, else why it does not."""
    if target.startswith(REMOTE):
        return "remote, not fetched"
    path = os.path.join(base, urllib.parse.unquote(target))
    return None if os.path.exists(path) else "missing on disk"


def roman(numeral):
    """An `I`/`V`/`X` numeral's value: a smaller numeral before a larger one subtracts."""
    values = [{"I": 1, "V": 5, "X": 10}[c] for c in numeral]
    return sum(-v if v < nxt else v for v, nxt in zip(values, values[1:] + [0]))


def numbers(pattern, md):
    """Every number `pattern` finds in `md`: an Arabic group, else a Roman one."""
    return [int(m.group(1)) if m.group(1) else roman(m.group(2))
            for m in pattern.finditer(md)]


def captions(found):
    """The caption term, `N captions (M distinct)`. M is what pairs."""
    return f"{len(found)} captions ({len(set(found))} distinct)"


def caption_gaps(md, caption_re, ref_re, label):
    """Numbers this `.md` should carry a caption for and does not.

    Two sets, unioned: one missing below the highest caption, skipped where
    nothing is captioned since there is then no highest, and one the prose
    references but nothing captions. The second half runs whatever the caption
    count, or a document that captions nothing and cites Figure 2 reads clean.
    """
    numbered = set(numbers(caption_re, md))
    gaps = set(numbers(ref_re, md)) - numbered
    if numbered:
        gaps |= set(range(1, max(numbered))) - numbered
    return [f"{label} {n}" for n in sorted(gaps)]


def report(md, outdir, key):
    """Print the `checked:` counts, then warn on every link that does not resolve."""
    lines = md.split("\n")
    targets = image_targets(md)
    bad = [(t, why) for t in targets if (why := link_state(t, outdir))]
    html_tables = len(HTML_TABLE.findall(md))
    gaps = (caption_gaps(md, TABLE_CAPTION, TABLE_REF, "Table")
            + caption_gaps(md, FIGURE_CAPTION, FIGURE_REF, "Figure"))

    print(f"{key}.md written")
    print(f"  {len(table_blocks(lines))} tables, "
          f"{captions(numbers(TABLE_CAPTION, md))} · "
          f"{len(targets)} images, {len(targets) - len(bad)} resolve, "
          f"{captions(numbers(FIGURE_CAPTION, md))} · "
          f"{len(HEADING.findall(md))} headings")
    # Only when non-zero: most sources have none, and a zero line says nothing.
    if html_tables:
        print(f"  {html_tables} HTML tables")
    print(f"  {len(LOST_EQUATION.findall(md))} lost equations")
    if gaps:
        print(f"  caption gap: {', '.join(gaps)} (no line-initial caption)")

    for target, why in bad:
        print(f"WARNING: image link does not resolve ({why}): {target}")
    if bad:
        print(f"WARNING: {len(bad)} of {len(targets)} image link(s) unresolved; "
              f"record it in [{key}]'s citing rather than treating it as a failure")


if __name__ == "__main__":
    # `checked:` records an inspection, not a conversion, so it regenerates from
    # the `.md` alone. Otherwise report() is reachable only mid-conversion.
    if len(sys.argv) != 3:
        sys.exit("Usage: conversion_utils.py <dir> <key>")
    _dir, _key = sys.argv[1], sys.argv[2]
    with open(os.path.join(_dir, f"{_key}.md"), encoding="utf-8") as fh:
        report(fh.read(), _dir, _key)
