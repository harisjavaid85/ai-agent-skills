#!/usr/bin/env python3
"""Check that every reference in a KB's notes resolves.

Resolves `[key]` and each entry's required fields against sources/index.md,
each entry's `files` against sources/<key>/ on disk, each source body's image
links against sources/<key>/, and `[[note]]` links and index listing against
knowledge/. Also reports an entry or a note name declared twice. A KB with no
knowledge/ yet is a KB holding only candidates: the note-side checks are
skipped, the registry ones still run.

Two findings it can spot but not settle go to FOR JUDGMENT: a bare `[key]`,
legal on a thesis-level claim and a defect on anything more specific, and an
image link resolving to nothing with no such file stored, legitimate only where
`citing` records the figures were never fetched, which this never reads. Where
the file *is* stored under another path the link is repointable, so that half
is a DEFECT.

Whether a locator still *supports* its claim, whether a sentence records what a
source omits, and how any of this is classed, all stay with kb-verify: they are
judgments, and a checker that guesses at them is worse than one that does not
try.

Prints whichever of DEFECTS, FOR JUDGMENT, and HYGIENE is non-empty, then always
an OPEN MARKERS tally and the site of every marker counted, and finally `all
references resolve` when none of the three held an entry. Only a DEFECTS entry
exits non-zero.

Usage: check_kb_references.py <kb-root>
"""

import os
import re
import sys
import urllib.parse
from collections import defaultdict

INLINE = re.compile(r"`[^`]*`")
WIKI = re.compile(r"\[\[([^\]]+)\]\]")
MARKER = re.compile(r"\[(UNVERIFIED|DRIFTED)\]")
MDLINK = re.compile(r"\[[^\]]*\]\([^)]*\)")
CITE = re.compile(r"\[([A-Za-z0-9][A-Za-z0-9._-]*)(:\s*[^\]]*)?\]")
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
DROPPED_PASSES = 4


def scan(path):
    """Return a list of (lineno, kind, value), one per finding in a note.

    Three kinds are references, resolved against a target: wiki, cite (has a
    locator), and bare (key alone). The fourth, marker, is not resolved against
    anything: it is counted and located, and kb-verify judges each site.

    Fenced and inline code are skipped, so a note quoting the distillation
    contract's worked pair, or showing a citation as an example, never reads as
    a live reference.
    """
    found, fenced = [], False
    with open(path, encoding="utf-8") as fh:
        for n, raw in enumerate(fh, 1):
            if raw.lstrip().startswith("```"):
                fenced = not fenced
                continue
            if fenced:
                continue
            line = INLINE.sub(" ", raw)
            # Wikilinks first: [[x]] would otherwise read as the citation [x].
            for m in WIKI.finditer(line):
                found.append((n, "wiki", m.group(1).strip()))
            line = WIKI.sub(" ", line)
            for m in MARKER.finditer(line):
                found.append((n, "marker", m.group(1)))
            line = MDLINK.sub(" ", MARKER.sub(" ", line))
            for m in CITE.finditer(line):
                # A key is at least two characters and carries a letter, so a
                # task-list checkbox and a pasted footnote marker ([x], [1])
                # read as the structural markdown they are, not as citations.
                if len(m.group(1)) < 2 or not LETTER.search(m.group(1)):
                    continue
                found.append((n, "cite" if m.group(2) else "bare", m.group(1)))
    return found


def plural(n, word):
    return f"{n} {word}" if n == 1 else f"{n} {word}s"


def check_files(root, key, spec):
    """Compare one entry's `files` against sources/<key>/ on disk.

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
        return [f"sources/index.md  [{key}] has a files value naming no top-level path: "
                f"list each top-level name under sources/{key}/, in backticks"]
    if not os.path.isdir(sdir):
        return [f"sources/index.md  [{key}] lists {plural(len(listed), 'path')} but "
                f"sources/{key}/ does not exist"]
    on_disk = {n for n in os.listdir(sdir) if not n.startswith(".")}
    out = [f"sources/index.md  [{key}] lists `{n}`, absent from sources/{key}/"
           for n in sorted(listed - on_disk)]
    out += [f"sources/{key}/{n}  on disk, unlisted in [{key}]'s files"
            for n in sorted(on_disk - listed)]
    for name, want in DIR_COUNT.findall(spec):
        d = os.path.join(sdir, name.rstrip("/"))
        if os.path.isdir(d):
            have = sum(len(f) for _, _, f in os.walk(d))
            if have != int(want):
                out.append(f"sources/index.md  [{key}] says `{name}` holds "
                           f"{plural(int(want), 'file')}, found {have}")
    return out


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

    Returns (defects, judgment); the module docstring gives the split. Reads no
    `citing`, which the split does not need.
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


def read_registry(sindex, hygiene):
    """Parse sources/index.md into (statuses, status details, all fields).

    A field's value continues onto an indented line and ends at the first blank
    one, so loose prose never glues onto the last field. A status of None means
    the entry declares none: status is required, and a missing one is a
    hand-edit gone wrong rather than a case to default. detail holds whatever
    follows the status word, a decline's reason and date.
    """
    keys, detail, fields, seen_at, current, field = {}, {}, {}, {}, None, None
    if not os.path.exists(sindex):
        return keys, detail, fields
    with open(sindex, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if m := KEY_HEADING.match(line):
                current, field = m.group(1), None
                # The reset below lets a second entry win silently, and a
                # re-ingest that appends instead of updating produces exactly
                # that: a report describing a registry the file does not hold.
                if current in seen_at:
                    hygiene.append(f"sources/index.md:{n}  duplicate entry [{current}], "
                                   f"first at line {seen_at[current]}: the later one wins")
                seen_at[current] = n
                keys[current], fields[current] = None, {}
            elif current is None:
                continue
            elif m := FIELD_BULLET.match(line):
                field = m.group(1).strip().lower()
                fields[current][field] = m.group(2).strip()
                if field == "status":
                    word = m.group(2).split(None, 1)
                    keys[current] = word[0].lower() if word else None
                    detail[current] = word[1].strip() if len(word) > 1 else ""
            elif not line.strip():
                field = None
            elif field and line[:1].isspace():
                fields[current][field] += " " + line.strip()
    return keys, detail, fields


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

    keys, detail, fields = read_registry(sindex, hygiene)

    cited, counts, cite_count, marker_sites = set(), defaultdict(int), defaultdict(int), []
    for name in sorted(notes):
        for path in notes[name]:
            rel = os.path.relpath(path, root)
            for line, kind, value in scan(path):
                where = f"{rel}:{line}"
                if kind == "wiki":
                    if value not in notes:
                        hygiene.append(f"{where}  dangling link [[{value}]]")
                elif kind == "marker":
                    counts[value] += 1
                    marker_sites.append(f"{where}  [{value}]")
                else:
                    cited.add(value)
                    cite_count[value] += 1
                    if value not in keys:
                        defects.append(f"{where}  unresolved key [{value}]")
                    else:
                        if keys[value] == "declined":
                            defects.append(
                                f"{where}  cites declined key [{value}]: a decline deletes the "
                                "source, so the locator cannot be verified")
                        if kind == "bare":
                            judgment.append(f"{where}  bare [{value}]: thesis-level only")

    if notes:
        for name in sorted(notes):
            if len(notes[name]) > 1:
                hygiene.append(f"duplicate note name '{name}': " + ", ".join(
                    os.path.relpath(p, root) for p in notes[name]))

    index = os.path.join(kdir, "index.md")
    if not os.path.exists(index):
        hygiene.append("knowledge/index.md is missing: no note is listed")
    else:
        with open(index, encoding="utf-8") as fh:
            listed = {m.group(1).strip() for m in WIKI.finditer(fh.read())}
        for name in sorted(notes):
            if name != "index" and name not in listed:
                hygiene.append(f"knowledge/{name}.md  not listed in knowledge/index.md")

    if not os.path.exists(sindex):
        defects.append("sources/index.md is missing: no key can resolve")
    for key, status in sorted(keys.items()):
        # A candidate cited nowhere is registered but not yet folded in, and a
        # declined entry is expected to be uncited: neither earns a line.
        if status is None:
            hygiene.append(f"sources/index.md  [{key}] has no status: every entry needs one")
        elif status not in STATUSES:
            hygiene.append(f"sources/index.md  [{key}] has unknown status '{status}'")
        elif status == "integrated" and key not in cited:
            hygiene.append(f"sources/index.md  orphan key [{key}]: cited nowhere")
        elif status == "declined" and not detail.get(key):
            hygiene.append(f"sources/index.md  declined [{key}] records no reason")
        elif status == "candidate" and key in cited:
            hygiene.append(f"sources/index.md  candidate [{key}] is cited "
                           f"{cite_count[key]}×: status is stale")

        # Fields, independent of the status chain above. Each is required, so
        # that "nothing" is a statement and an absence is a gap worth reporting.
        entry = fields.get(key, {})
        if not entry.get("citing"):
            hygiene.append(f"sources/index.md  [{key}] has no citing: every entry needs one")
        if status == "integrated" and not entry.get("dropped"):
            hygiene.append(f"sources/index.md  integrated [{key}] has no dropped: say what "
                           "the integration left behind, or that it left nothing")
        # The 80-word cap governs a line, nothing governs the field. Count date
        # stamps, not lines: read_registry joined the value with spaces already.
        passes = len(DATE_STAMP.findall(entry.get("dropped") or ""))
        if passes >= DROPPED_PASSES:
            hygiene.append(f"sources/index.md  [{key}]'s dropped records {passes} integrate "
                           "passes: append-only and uncapped as a field, so it grows without "
                           "bound and is now long enough to read whole before writing")
        if status == "declined":
            # A decline deletes the source's files. Every citation defect
            # reported for a declined key rests on that, unchecked until now.
            # The field going stale is untidy; the files surviving is the defect.
            if entry.get("files"):
                hygiene.append(f"sources/index.md  declined [{key}] still lists files: "
                               "a decline drops the field along with the files")
            sdir = os.path.join(root, "sources", key)
            if os.path.isdir(sdir):
                n = sum(len(f) for _, _, f in os.walk(sdir))
                held = f" holding {plural(n, 'file')}" if n else " (empty)"
                defects.append(f"sources/index.md  declined [{key}]: sources/{key}/ still "
                               f"exists{held}, which a decline deletes")
        elif not entry.get("files"):
            # files is the one field a checker can confirm in both directions
            # against disk, so leaving it optional silently skips both.
            hygiene.append(f"sources/index.md  [{key}] has no files: list what "
                           f"sources/{key}/ holds")
        else:
            hygiene.extend(check_files(root, key, entry["files"]))

        # A decline deleted the source's files, so there is no body to open.
        if status != "declined":
            found, unstored = check_source_images(root, key)
            defects.extend(found)
            judgment.extend(unstored)

    tally = defaultdict(int)
    for status in keys.values():
        tally[status or "no status"] += 1
    breakdown = ", ".join(f"{n} {s}" for s, n in sorted(tally.items()))
    print(f"{plural(len(notes), 'note') if notes else 'no notes yet'}, "
          f"{plural(len(keys), 'registered key')}"
          f"{f' ({breakdown})' if keys else ''}, {plural(len(cited), 'key')} cited")
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
