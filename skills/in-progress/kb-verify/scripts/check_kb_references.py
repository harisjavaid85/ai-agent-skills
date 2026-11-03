#!/usr/bin/env python3
"""Check that every reference in a KB's notes resolves.

Resolves `[key]` and each entry's required fields against sources/index.md,
each entry's `files` against sources/<key>/ on disk, each source body's image
links against sources/<key>/, and `[[note]]` links and index listing against
knowledge/. Checks each locator's form against the citation contract's grammar
(`malformed locator`), a pointer locator against its line in
sources/<key>/<key>.md (`unresolved pointer`), a `§` locator against the
headings of that `.md` (`unresolved section`, `ambiguous section`), and a quote
against its lines (`unresolved quote`, `ambiguous quote`), and reports any other
form citing a structured source (`non-pointer locator`). Also reports an
entry or a note name declared twice, and checks the index's shape per the
distillation contract: one `- [[note]]: <scope>` entry per note, its scope
within the word cap, and each cross-cutting line spanning three notes with
every aspect naming one. A KB with no knowledge/ yet is a KB holding only
candidates: the note-side checks are skipped, the registry ones still run.

FOR JUDGMENT holds what it spots but cannot settle, a bare `[key]` and an image
link to no stored file; kb-verify's step 4 table says how each is judged. A
settled finding is a DEFECT or HYGIENE by kb-verify's step 4 rule, *Defect or
hygiene*; a new message lands by it too.

Prints whichever of DEFECTS, FOR JUDGMENT, and HYGIENE is non-empty, then always
an OPEN MARKERS tally and the site of every marker counted, and finally `all
references resolve` when none of the three held an entry. Only a DEFECTS entry
exits non-zero.

Usage: check_kb_references.py <kb-root>
"""

import html
import json
import os
import re
import sys
import urllib.parse
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Optional

INLINE = re.compile(r"`[^`]*`")
WIKI = re.compile(r"\[\[([^\]]+)\]\]")
MARKER = re.compile(r"\[(UNVERIFIED|DRIFTED)\]")
# Link text holds no `[`, so a link never opens at a stray `[` or a citation's
# own and swallows the citation: one holding a link reaches the grammar check.
MDLINK = re.compile(r"\[[^\[\]]*\]\([^)]*\)")
CITE = re.compile(r"\[([A-Za-z0-9][A-Za-z0-9._-]*)(:\s*[^\]]*)?\]")
# The locator grammar in kb-builder's reference/citation.md. All but the last
# form, the pointer, copy _LOCATOR in kb-web's backend/kb_web/citations.py, with
# two differences until kb-web catches up: kb-web still accepts the dropped
# `@mm:ss` timestamp, and here the quote also excludes `[`, `]`, and a backtick,
# and the section name `]`, which kb-web cannot parse inside a citation.
LOCATOR = re.compile(r': (?:p\.\d+|pp\.\d+-\d+|(?:fig|tbl|eq)\.\d+|§"[^"\]\n]+"'
                     r'|"[^"\[\]`\n]+"|/[^\]\n]+)')
HEADING = re.compile(r"^#{1,6}(?:\s+(.*))?$")
SELF_LINK = re.compile(r"\[([^\]]*)\]\(#[^)]*\)")
BOLD = re.compile(r"\*\*(.+?)\*\*")
# A closing `#` run only after whitespace, so `## Using C#` keeps its `#`.
HEADING_TAIL = re.compile(r"(?:\s+#+|\s*¶)+\s*$")
# A markdown backslash escape, which docling writes before `_`, `-`, and more.
ESCAPE = re.compile(r"\\([!-/:-@\[-`{-~])")
ARRAY_INDEX = re.compile(r"0|[1-9]\d*")
LETTER = re.compile(r"[A-Za-z]")
KEY_HEADING = re.compile(r"^##\s+(\S+)")
FIELD_BULLET = re.compile(r"^-\s+\*\*([A-Za-z][A-Za-z ()]*):\*\*\s*(.*)$")
BACKTICKED = re.compile(r"`([^`]+)`")
DIR_COUNT = re.compile(r"`([^`]+/)`\s*\((\d+)\s+files?\)")
MD_IMAGE = re.compile(r"!\[[^\]]*\]\(([^)]*)\)")
HTML_IMAGE = re.compile(r"<img[^>]+src=[\"']([^\"']+)[\"']", re.I)
DATE_STAMP = re.compile(r"\d{4}-\d{2}-\d{2}:")
STATUSES = ("candidate", "integrated", "declined")
REMOTE = ("http://", "https://", "//", "data:", "mailto:")
DROPPED_WORDS = 100
BULLET = re.compile(r"^[-*]\s+")
ENTRY = re.compile(r"^\[\[([^\]]+)\]\]\s*(.*)$")
CROSS_HEADING = "cross-cutting concepts"
CROSS_MIN = 3
ENTRY_WORDS = 40
# Any separator, so an entry written in another form is still held to the cap.
SEPARATOR = re.compile(r"^\W+")


def unfenced(lines):
    """Yield (lineno, line) for each line outside fenced code, numbered from 1."""
    fenced = False
    for n, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            fenced = not fenced
        elif not fenced:
            yield n, line


def scan(path):
    """Return a list of (lineno, kind, value, locator), one per finding in a note.

    Three kinds are references, resolved against a target: wiki, cite (has a
    locator), and bare (key alone). The fourth, marker, is not resolved against
    anything: it is counted and located, and kb-verify judges each site. Only a
    cite carries a locator, from its colon on; every other kind carries None.

    Fenced and inline code are skipped, so a note quoting the distillation
    contract's worked pair, or showing a citation as an example, never reads as
    a live reference. Skipped runs are blanked to the same length, so a
    locator is read from the raw line and keeps any inline code it quotes.
    """
    found = []
    with open(path, encoding="utf-8") as fh:
        for n, raw in unfenced(fh):
            line = INLINE.sub(blank, raw)
            # Wikilinks first: [[x]] would otherwise read as the citation [x].
            for m in WIKI.finditer(line):
                found.append((n, "wiki", m.group(1).strip(), None))
            line = WIKI.sub(blank, line)
            for m in MARKER.finditer(line):
                found.append((n, "marker", m.group(1), None))
            line = MDLINK.sub(blank, MARKER.sub(blank, line))
            for m in CITE.finditer(line):
                # A key is at least two characters and carries a letter, so a
                # task-list checkbox and a pasted footnote marker ([x], [1])
                # read as the structural markdown they are, not as citations.
                if len(m.group(1)) < 2 or not LETTER.search(m.group(1)):
                    continue
                locator = raw[m.start(2):m.end(2)] if m.group(2) else None
                found.append((n, "cite" if locator else "bare", m.group(1), locator))
    return found


def blank(m):
    """A match replaced by spaces of its own length, keeping later offsets aligned."""
    return " " * len(m.group(0))


def resolves(lines, pointer):
    """Whether a pointer locator resolves against a structured source's lines.

    It resolves when a line opens with it. One segment below an array leaf, it
    resolves when the parent's line holds an array and the last segment is an
    index into it.
    """
    if any(line.startswith(f"{pointer}: ") for line in lines):
        return True
    parent, _, index = pointer.rpartition("/")
    if not parent or not ARRAY_INDEX.fullmatch(index):
        return False
    for line in lines:
        if line.startswith(f"{parent}: "):
            try:
                value = json.loads(line[len(parent) + 2:])
            except ValueError:
                return False
            return isinstance(value, list) and int(index) < len(value)
    return False


def pointer_problem(lines, pointer, md):
    """Why a pointer locator fails, or None when it resolves."""
    if resolves(lines, pointer):
        return None
    return f"unresolved pointer: no line of {md} opens with it"


def quote_problem(lines, span, md):
    """Why a quote locator fails, or None when it resolves.

    The span sits within exactly one line outside fenced code, matched with
    whitespace collapsed.
    """
    want = " ".join(span.split())
    if not want:
        return "malformed locator: an empty quote span"
    hits = sum(want in " ".join(line.split()) for _, line in unfenced(lines))
    if not hits:
        return f"unresolved quote: no line of {md} outside fenced code holds it"
    if hits > 1:
        return (f"ambiguous quote: {hits} lines of {md} hold it; lengthen the span "
                "within its line, or cite another form the source has")
    return None


def heading_text(raw):
    """A heading's text as a `§` locator names it: self-link and each `**…**`
    pair unwrapped, then a trailing `¶` or whitespace-led `#` run stripped, in
    that order, then entities decoded, backslash escapes dropped, and
    whitespace collapsed."""
    text = BOLD.sub(r"\1", SELF_LINK.sub(r"\1", raw or ""))
    text = ESCAPE.sub(r"\1", html.unescape(HEADING_TAIL.sub("", text)))
    return " ".join(text.split())


def section_problem(lines, name, md):
    """Why a `§` locator fails, or None when it resolves.

    Exactly one heading outside fenced code, at any level, reads as the name
    once both pass through heading_text.
    """
    want = heading_text(name)
    if not want:
        return "malformed locator: an empty section name"
    hits = 0
    for _, line in unfenced(lines):
        m = HEADING.match(line)
        if m and heading_text(m.group(1)) == want:
            hits += 1
    if not hits:
        return f"unresolved section: no heading of {md} outside fenced code reads so"
    if hits > 1:
        return (f"ambiguous section: {hits} headings of {md} read so; cite a quote "
                "from the source line that supports the claim, or another form the "
                "source has")
    return None


def structured(lines):
    """Whether a source's lines are a structured source's normalized `.md`: one
    fenced block holding only `<pointer>: <value>` lines, and nothing outside it."""
    body = (line for line in lines if line.strip())
    if not next(body, "").startswith("```"):
        return False
    rest = list(body)
    return (len(rest) > 1 and rest[-1].startswith("```")
            and all(line.startswith("/") and ": " in line for line in rest[:-1]))


def locator_problem(root, key, locator, cache):
    """Why a well-formed locator fails against sources/<key>/<key>.md, or None.

    A pointer, quote, or `§` resolves in that `.md`. `p.`, `fig.`, `tbl.`, and
    `eq.` name the original and pass, unless the `.md` is a structured source's.
    """
    md, lines = f"sources/{key}/{key}.md", source_lines(root, key, cache)
    if locator.startswith(": /"):
        return pointer_problem(lines, locator[2:], md)
    if structured(lines):
        return f"non-pointer locator: {md} is a structured source, which takes pointers only"
    if locator.startswith(': "'):
        return quote_problem(lines, locator[3:-1], md)
    if locator.startswith(': §"'):
        return section_problem(lines, locator[4:-1], md)
    return None


def source_lines(root, key, cache):
    """The lines of sources/<key>/<key>.md, read once per key; none if it is absent."""
    if key not in cache:
        path = os.path.join(root, "sources", key, f"{key}.md")
        cache[key] = []
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as fh:
                # Not splitlines(): it also breaks at U+2028 inside a JSON value.
                cache[key] = fh.read().split("\n")
    return cache[key]


def index_items(path):
    """Return (lineno, text, cross) for each top-level bullet of the index.

    An indented line continues the bullet above it, so a wrapped entry is read
    whole. `cross` is true under `## Cross-cutting concepts`. Fenced and inline
    code are skipped, as in scan.
    """
    items, cross, current, last = [], False, None, 0
    with open(path, encoding="utf-8") as fh:
        for n, raw in unfenced(fh):
            # A gap in the numbering is a fence, which ends the bullet above it.
            if n != last + 1:
                current = None
            last = n
            line = INLINE.sub(" ", raw.rstrip("\n"))
            heading = HEADING.match(line)
            if heading:
                cross = (heading.group(1) or "").strip().lower() == CROSS_HEADING
                current = None
            elif BULLET.match(line):
                current = [n, BULLET.sub("", line, count=1), cross]
                items.append(current)
            elif line.strip() and line[0].isspace() and current:
                current[1] += " " + line.strip()
            else:
                current = None
    return [tuple(i) for i in items]


def check_index(path, hygiene):
    """Check knowledge/index.md's shape; return the notes its index entries list.

    Only an index entry lists a note: a mention in a cross-cutting line does not.
    """
    listed = {}
    for n, text, cross in index_items(path):
        where = f"knowledge/index.md:{n}"
        if cross:
            concept, sep, rest = text.partition(":")
            if not sep:
                hygiene.append(f"{where}  cross-cutting line lacks the `: ` after its "
                               "concept: write `- <Concept>: <aspect> → [[note]]; …`")
                continue
            where, names = f"{where}  {concept.strip()}:", []
            for aspect in rest.split(";"):
                targets = [m.group(1).strip() for m in WIKI.finditer(aspect)]
                if not targets and aspect.strip():
                    hygiene.append(f"{where} aspect '{aspect.strip()}' names no [[note]]")
                names += targets
            for name in sorted({x for x in names if names.count(x) > 1}):
                hygiene.append(f"{where} [[{name}]] appears more than once")
            if len(set(names)) < CROSS_MIN:
                hygiene.append(f"{where} spans {plural(len(set(names)), 'note')}, under "
                               f"{CROSS_MIN}: drop the line")
            continue
        m = ENTRY.match(text)
        if not m:
            continue
        name, rest = m.group(1).strip(), m.group(2)
        if name in listed:
            hygiene.append(f"{where}  duplicate index entry for [[{name}]], first at "
                           f"knowledge/index.md:{listed[name]}: every note has one")
            continue
        listed[name] = n
        if not rest.startswith(":"):
            hygiene.append(f"{where}  [[{name}]]'s entry lacks the `: ` separator: "
                           f"write `- [[{name}]]: <scope>`")
        words = len(SEPARATOR.sub("", rest).split())
        if words > ENTRY_WORDS:
            hygiene.append(f"{where}  [[{name}]]'s entry runs {words} words, over the "
                           f"{ENTRY_WORDS}-word cap: trim the entry, or run "
                           f"kb-integrate split {name}")
    return set(listed)


def plural(n, word):
    return f"{n} {word}" if n == 1 else f"{n} {word}s"


def check_files(root, key, spec):
    """Compare one entry's `files` against sources/<key>/ on disk.

    Returns (defects, hygiene). An absent sources/<key>/ is the caller's to
    report, so nothing is compared.

    Elements are backticked and name top-level entries of that directory, so a
    token carrying an inner slash (a URL, or a path reaching into the figure
    directory) is not one and is ignored. A trailing slash marks a directory,
    which may declare a "(N files)" count of what it holds: the figure
    directory is one element, not one element per figure.
    """
    sdir = os.path.join(root, "sources", key)
    listed = {t.rstrip("/") for t in BACKTICKED.findall(spec) if "/" not in t.rstrip("/")}
    if not listed:
        # A files value nothing can be read out of is worse than an absent one,
        # since it satisfies the required-field check and then skips both
        # directions of the comparison silently. Two shapes reach here: a value
        # with no backticks at all, and one listing only nested paths.
        return [], [f"sources/index.md  [{key}] has a files value naming no top-level path: "
                    f"list each top-level name under sources/{key}/, in backticks"]
    if not os.path.isdir(sdir):
        return [], []
    on_disk = {n for n in os.listdir(sdir) if not n.startswith(".")}
    defects = [f"sources/index.md  [{key}] lists `{n}`, absent from sources/{key}/"
               for n in sorted(listed - on_disk)]
    out = [f"sources/{key}/{n}  on disk, unlisted in [{key}]'s files"
           for n in sorted(on_disk - listed)]
    for name, want in DIR_COUNT.findall(spec):
        d = os.path.join(sdir, name.rstrip("/"))
        if os.path.isdir(d):
            have = sum(len(f) for _, _, f in os.walk(d))
            if have != int(want):
                out.append(f"sources/index.md  [{key}] says `{name}` holds "
                           f"{plural(int(want), 'file')}, found {have}")
    return defects, out


def image_targets(line):
    """Every image target on one line, markdown and HTML.

    HTML is not optional: model cards carry `<img src=...>` tags no markdown
    pattern sees. A quoted `src` is taken whole, the attribute having delimited
    it already; a markdown target sheds its angle brackets and title.
    """
    out = [t for t in HTML_IMAGE.findall(line) if t.strip()]
    for target in MD_IMAGE.findall(line):
        t = target.strip()
        if t.startswith("<") and ">" in t:
            t = t[1:t.index(">")]
        else:
            parts = t.split()
            t = parts[0] if parts else ""
        if t:
            out.append(t)
    return out


def stored_basenames(sdir):
    """Every file under sources/<key>/, by basename, relative to that directory."""
    out = {}
    for dirpath, _, names in os.walk(sdir):
        for name in names:
            out.setdefault(name, os.path.relpath(os.path.join(dirpath, name), sdir))
    return out


def check_source_images(root, key):
    """Resolve a source body's image links against its own directory.

    Returns (defects, judgment). A link whose file is stored under another path
    is a defect, repointable; one whose file is stored nowhere is for judgment,
    per kb-verify's step 4 table, since this never reads `citing`.
    """
    sdir = os.path.join(root, "sources", key)
    path = os.path.join(sdir, f"{key}.md")
    if not os.path.isfile(path):
        return [], []
    defects, judgment, stored = [], [], None
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            for target in image_targets(line):
                if target.startswith(REMOTE):
                    continue
                rel = urllib.parse.unquote(target)
                if os.path.exists(os.path.join(sdir, rel)):
                    continue
                if stored is None:
                    stored = stored_basenames(sdir)
                at = stored.get(os.path.basename(rel))
                if at:
                    defects.append(
                        f"sources/{key}/{key}.md:{n}  image link '{target}' does not "
                        f"resolve; the file is at '{at}'. Repoint the reference")
                else:
                    judgment.append(
                        f"sources/{key}/{key}.md:{n}  image link '{target}' resolves to "
                        "nothing and no such file is stored: legitimate only where citing "
                        "records the figures were never fetched")
    return defects, judgment


@dataclass
class SourceEntry:
    """One key's entry in sources/index.md.

    A status of None means the entry declares none: status is required, and a
    missing one is a hand-edit gone wrong rather than a case to default. detail
    holds whatever follows the status word, a decline's reason and date. stamps
    counts the lines of dropped that open with a date, read before joining: the
    contract keeps a date off the start of a wrapped line, so each one opens a
    value, and a date quoted mid-reason opens none.
    """
    status: Optional[str] = None
    detail: str = ""
    fields: dict = field(default_factory=dict)
    stamps: int = 0


def read_registry(sindex, hygiene):
    """Parse sources/index.md into {key: SourceEntry}.

    A field's value continues onto an indented line and ends at the first blank
    one, so loose prose never glues onto the last field.
    """
    entries, seen_at, entry, name = {}, {}, None, None
    if not os.path.exists(sindex):
        return entries
    with open(sindex, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if m := KEY_HEADING.match(line):
                key, name = m.group(1), None
                # The reset below lets a second entry win silently, and a
                # re-ingest that appends instead of updating produces exactly
                # that: a report describing a registry the file does not hold.
                if key in seen_at:
                    hygiene.append(f"sources/index.md:{n}  duplicate registry entry [{key}], "
                                   f"first at line {seen_at[key]}: the later one wins")
                seen_at[key] = n
                entry = entries[key] = SourceEntry()
                continue
            if entry is None:
                continue
            if m := FIELD_BULLET.match(line):
                name, text = m.group(1).strip().lower(), m.group(2).strip()
                entry.fields[name] = text
                if name == "status":
                    word = text.split(None, 1)
                    entry.status = word[0].lower() if word else None
                    entry.detail = word[1].strip() if len(word) > 1 else ""
            elif not line.strip():
                name = None
                continue
            elif name and line[:1].isspace():
                text = line.strip()
                entry.fields[name] += " " + text
            else:
                continue
            if name == "dropped" and DATE_STAMP.match(text):
                entry.stamps += 1
    return entries


def check_entry(root, key, entry, cite_count):
    """Check one registry entry against its fields and sources/<key>/.

    Returns (defects, judgment, hygiene); cite_count is how often the notes cite
    the key.
    """
    defects, judgment, hygiene = [], [], []
    status, fields = entry.status, entry.fields
    # A candidate cited nowhere is registered but not yet folded in, and a
    # declined entry is expected to be uncited: neither earns a line.
    if status is None:
        hygiene.append(f"sources/index.md  [{key}] has no status: every entry needs one")
    elif status not in STATUSES:
        hygiene.append(f"sources/index.md  [{key}] has unknown status '{status}'")
    elif status == "integrated" and not cite_count:
        hygiene.append(f"sources/index.md  orphan key [{key}]: cited nowhere")
    elif status == "declined" and not entry.detail:
        hygiene.append(f"sources/index.md  declined [{key}] records no reason")
    elif status == "candidate" and cite_count:
        hygiene.append(f"sources/index.md  candidate [{key}] is cited "
                       f"{cite_count}×: status is stale")

    # Fields, independent of the status chain above. Each is required, so
    # that "nothing" is a statement and an absence is a gap worth reporting.
    if not fields.get("citing"):
        hygiene.append(f"sources/index.md  [{key}] has no citing: every entry needs one")
    if status == "integrated" and not fields.get("dropped"):
        hygiene.append(f"sources/index.md  integrated [{key}] has no dropped: say what "
                       "integration has not taken from this source, or that it took it all")
    # dropped is one dated value, the latest set, rewritten by every pass.
    if entry.stamps > 1:
        hygiene.append(f"sources/index.md  [{key}]'s dropped carries {entry.stamps} dated "
                       "values: it holds one, the latest set")
    # The word count is a target, not a cap: listed so the long ones get a
    # periodic cleanup, never a reason to omit an item.
    words = len((fields.get("dropped") or "").split())
    if words > DROPPED_WORDS:
        hygiene.append(f"sources/index.md  [{key}]'s dropped runs {words} words, over "
                       f"the {DROPPED_WORDS}-word target: coarsen the list, omitting "
                       "no item")
    sdir = os.path.join(root, "sources", key)
    if status == "declined":
        # A decline deletes the source's files; leftovers are bookkeeping,
        # since a citation of a declined key is reported as a defect anyway.
        if fields.get("files"):
            hygiene.append(f"sources/index.md  declined [{key}] still lists files: "
                           "a decline drops the field along with the files")
        if os.path.isdir(sdir):
            n = sum(len(f) for _, _, f in os.walk(sdir))
            held = f" holding {plural(n, 'file')}" if n else " (empty)"
            hygiene.append(f"sources/index.md  declined [{key}]: sources/{key}/ still "
                           f"exists{held}, which a decline deletes")
    elif status in ("candidate", "integrated") and not os.path.isdir(sdir):
        defects.append(f"sources/index.md  [{key}]: sources/{key}/ does not exist")
    elif not fields.get("files"):
        # files is the one field a checker can confirm in both directions
        # against disk, so leaving it optional silently skips both.
        hygiene.append(f"sources/index.md  [{key}] has no files: list what "
                       f"sources/{key}/ holds")
    else:
        found, untidy = check_files(root, key, fields["files"])
        defects.extend(found)
        hygiene.extend(untidy)

    # A decline deleted the source's files, so there is no body to open.
    if status != "declined":
        found, unstored = check_source_images(root, key)
        defects.extend(found)
        judgment.extend(unstored)
    return defects, judgment, hygiene


def main(root):
    kdir = os.path.join(root, "knowledge")
    sindex = os.path.join(root, "sources", "index.md")
    defects, judgment, hygiene = [], [], []

    # os.walk yields nothing for a missing directory, so a KB holding only
    # ingested candidates simply has no notes. That is a stage, not an error.
    notes = defaultdict(list)
    for dirpath, _, names in os.walk(kdir):
        for name in names:
            if name.endswith(".md"):
                notes[name[:-3]].append(os.path.join(dirpath, name))

    entries = read_registry(sindex, hygiene)

    cited, counts, cite_count, marker_sites = set(), defaultdict(int), defaultdict(int), []
    bodies = {}
    for name in sorted(notes):
        for path in notes[name]:
            rel = os.path.relpath(path, root)
            for line, kind, value, locator in scan(path):
                where = f"{rel}:{line}"
                if kind == "wiki":
                    if value not in notes:
                        defects.append(f"{where}  dangling link [[{value}]]")
                elif kind == "marker":
                    counts[value] += 1
                    marker_sites.append(f"{where}  [{value}]")
                else:
                    cited.add(value)
                    cite_count[value] += 1
                    if value not in entries:
                        defects.append(f"{where}  unresolved key [{value}]")
                        continue
                    declined = entries[value].status == "declined"
                    if declined:
                        defects.append(
                            f"{where}  cites declined key [{value}]: a decline deletes the "
                            "source, so the locator cannot be verified")
                    if kind == "bare":
                        judgment.append(f"{where}  bare [{value}]: thesis-level only")
                    elif not LOCATOR.fullmatch(locator):
                        defects.append(f"{where}  malformed locator [{value}{locator}]: "
                                       "write one of the citation contract's forms")
                    elif not declined:
                        problem = locator_problem(root, value, locator, bodies)
                        if problem:
                            defects.append(f"{where}  {problem} [{value}{locator}]")

    if notes:
        for name in sorted(notes):
            if len(notes[name]) > 1:
                defects.append(f"duplicate note name '{name}': " + ", ".join(
                    os.path.relpath(p, root) for p in notes[name]))

        index = os.path.join(kdir, "index.md")
        if not os.path.exists(index):
            hygiene.append("knowledge/index.md is missing: no note is listed")
        else:
            listed = check_index(index, hygiene)
            for name in sorted(notes):
                if name != "index" and name not in listed:
                    hygiene.append(f"{os.path.relpath(notes[name][0], root)}  not listed in "
                                   "knowledge/index.md")

    if not os.path.exists(sindex):
        defects.append("sources/index.md is missing: no key can resolve")
    for key, entry in sorted(entries.items()):
        found, unsettled, untidy = check_entry(root, key, entry, cite_count[key])
        defects.extend(found)
        judgment.extend(unsettled)
        hygiene.extend(untidy)

    tally = defaultdict(int)
    for entry in entries.values():
        tally[entry.status or "no status"] += 1
    breakdown = ", ".join(f"{n} {s}" for s, n in sorted(tally.items()))
    print(f"{plural(len(notes), 'note') if notes else 'no notes yet'}, "
          f"{plural(len(entries), 'registered key')}"
          f"{f' ({breakdown})' if entries else ''}, {plural(len(cited), 'key')} cited")
    for label, items in (("DEFECTS", defects), ("FOR JUDGMENT", judgment), ("HYGIENE", hygiene)):
        if items:
            print(f"\n{label} ({len(items)})")
            print("\n".join("  " + i for i in items))
    # Always printed. This is a raw count of markers present, not a verdict:
    # kb-verify judges each site and drops the false ones before deciding
    # whether the KB is current, which is why the sites are listed too.
    print(f"\nOPEN MARKERS  [UNVERIFIED] {counts['UNVERIFIED']}  [DRIFTED] {counts['DRIFTED']}")
    if marker_sites:
        print("\n".join("  " + s for s in marker_sites))
    if not (defects or judgment or hygiene):
        print("all references resolve")
    return 1 if defects else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
