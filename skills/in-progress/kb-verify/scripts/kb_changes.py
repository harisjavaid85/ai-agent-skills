#!/usr/bin/env python3
"""Snapshot a KB's knowledge/ and list the sections changed since a snapshot.

`snapshot <kb-root>` prints the git tree ID of knowledge/ exactly as on disk,
uncommitted and untracked notes included, written through a temporary index so
the user's own index and HEAD are never touched.

`sections <kb-root> <snapshot | uncommitted>` diffs that snapshot, or HEAD for
`uncommitted`, against a fresh snapshot and prints one line per change:

    section           <note> › <## heading>      a changed section
    section           <note> › (opening)         a changed opening (before the first ##)
    new-note          <note>                     a note added, to read whole
    deleted           <note>                     a note removed, to report
    citation-removed  <note> › <where>  [cite]   a citation gone from the diff
    citation-moved    <note> › <where> -> <note> › <where>  [cite]

A changed line maps to the nearest `##` heading above it in the new file, or to
the note's opening when there is none; a hunk that only deletes lines maps to
the section now holding its position. A heading that repeats in a note takes
its ordinal, `## Results (2)`. A citation removed in one place and added in
another is moved; one removed and added back in the same section is not listed:
that section is, and reading it whole finds any text the move left uncovered. Citations in a deleted note are not listed. Fenced code is
skipped, as the reference check skips it, and citations are read with that
check's own patterns.

Usage: kb_changes.py snapshot <kb-root>
       kb_changes.py sections <kb-root> <snapshot | uncommitted>
"""

import os
import re
import subprocess
import sys
import tempfile
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_kb_references import CITE, INLINE, LETTER, MARKER, MDLINK, WIKI, blank  # noqa: E402

EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
SECTION_HEADING = re.compile(r"^##(?!#)\s")


def git(root, *args, env=None):
    result = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, env=env)
    if result.returncode != 0:
        sys.exit(f"git {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout


def snapshot(root):
    """The tree ID of knowledge/ as on disk, through a throwaway index."""
    fd, index = tempfile.mkstemp(prefix="kb-snapshot-index-")
    os.close(fd)
    os.unlink(index)
    env = dict(os.environ, GIT_INDEX_FILE=index)
    try:
        if os.path.isdir(os.path.join(root, "knowledge")):
            git(root, "add", "-A", "--", "knowledge", env=env)
        return git(root, "write-tree", env=env).strip()
    finally:
        if os.path.exists(index):
            os.unlink(index)


def resolve_base(root, base):
    if base == "uncommitted":
        head = subprocess.run(["git", "-C", root, "rev-parse", "--verify", "-q", "HEAD^{tree}"],
                              capture_output=True, text=True)
        return head.stdout.strip() if head.returncode == 0 else EMPTY_TREE
    kind = subprocess.run(["git", "-C", root, "cat-file", "-t", base], capture_output=True, text=True)
    if kind.returncode != 0 or kind.stdout.strip() != "tree":
        sys.exit(f"not a snapshot: {base}")
    return git(root, "rev-parse", base).strip()


def read_blob(root, tree, path):
    result = subprocess.run(["git", "-C", root, "show", f"{tree}:{path}"], capture_output=True, text=True)
    return result.stdout.splitlines() if result.returncode == 0 else []


def fenced_lines(lines):
    """Line numbers, from 1, inside fenced code (fence lines included)."""
    fenced, inside = set(), False
    for n, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            fenced.add(n)
            inside = not inside
        elif inside:
            fenced.add(n)
    return fenced


def section_names(lines):
    """For each line number from 1 (and 0), the name of the section holding it."""
    fenced = fenced_lines(lines)
    seen = Counter()
    names = {0: "(opening)"}
    current = "(opening)"
    for n, line in enumerate(lines, 1):
        if n not in fenced and SECTION_HEADING.match(line):
            heading = line.rstrip()
            seen[heading] += 1
            current = heading if seen[heading] == 1 else f"{heading} ({seen[heading]})"
        names[n] = current
    total = Counter(line.rstrip() for n, line in enumerate(lines, 1)
                    if n not in fenced and SECTION_HEADING.match(line))
    # A repeated heading's first occurrence takes its ordinal too.
    return {n: (f"{name} (1)" if total.get(name, 0) > 1 else name) for n, name in names.items()}


def citations(line):
    """The citations on one line, as written, read as the reference check reads them."""
    line = INLINE.sub(blank, line)
    line = WIKI.sub(blank, line)
    line = MDLINK.sub(blank, MARKER.sub(blank, line))
    found = []
    for m in CITE.finditer(line):
        if len(m.group(1)) < 2 or not LETTER.search(m.group(1)):
            continue
        found.append(m.group(0))
    return found


def changed_files(root, base, now):
    out = git(root, "diff", "--no-renames", "--name-status", base, now, "--", "knowledge/")
    for row in out.splitlines():
        status, path = row.split("\t", 1)
        if path.endswith(".md"):
            yield status[0], path


def hunks(root, base, now, path):
    """(old_start, old_lines, new_start, new_count) per hunk, with old and new line texts."""
    out = git(root, "diff", "-U0", "--no-renames", base, now, "--", path)
    current = None
    for line in out.splitlines():
        m = HUNK.match(line)
        if m:
            if current:
                yield current
            o, oc, n, nc = m.groups()
            current = [int(o), int(oc) if oc is not None else 1, int(n), int(nc) if nc is not None else 1, [], []]
        elif current and line.startswith("-"):
            current[4].append(line[1:])
        elif current and line.startswith("+"):
            current[5].append(line[1:])
    if current:
        yield current


def sections(root, base_arg):
    base = resolve_base(root, base_arg)
    now = snapshot(root)
    changed, new_notes, deleted = [], [], []
    removed, added = [], []  # (note, section, citation)
    for status, path in changed_files(root, base, now):
        new_lines = read_blob(root, now, path)
        if status == "D":
            deleted.append(path)
            continue
        names = section_names(new_lines)
        new_fenced = fenced_lines(new_lines)
        if status == "A":
            new_notes.append(path)
            for n, line in enumerate(new_lines, 1):
                if n not in new_fenced:
                    added += [(path, names[n], c) for c in citations(line)]
            continue
        old_fenced = fenced_lines(read_blob(root, base, path))
        for old_start, _, new_start, new_count, old_text, new_text in hunks(root, base, now, path):
            if new_count:
                for n in range(new_start, new_start + new_count):
                    if names[n] not in [s for p, s in changed if p == path]:
                        changed.append((path, names[n]))
                    if n not in new_fenced:
                        added += [(path, names[n], c) for c in citations(new_lines[n - 1])]
                where = names[new_start]
            else:
                where = names[new_start]
                if where not in [s for p, s in changed if p == path]:
                    changed.append((path, where))
            for i, line in enumerate(old_text):
                if old_start + i not in old_fenced:
                    removed += [(path, where, c) for c in citations(line)]

    # A citation removed and added back in the same section is unchanged.
    pool = Counter(added)
    leftover = []
    for item in removed:
        if pool[item]:
            pool[item] -= 1
        else:
            leftover.append(item)
    moves, gone = [], []
    for note, where, cite in leftover:
        target = next((k for k, v in pool.items() if v and k[2] == cite), None)
        if target:
            pool[target] -= 1
            moves.append((note, where, target[0], target[1], cite))
        else:
            gone.append((note, where, cite))

    for path, where in changed:
        print(f"section  {path} › {where}")
    for path in new_notes:
        print(f"new-note {path}")
    for path in deleted:
        print(f"deleted  {path}")
    for note, where, cite in gone:
        print(f"citation-removed  {note} › {where}  {cite}")
    for note, where, to_note, to_where, cite in moves:
        print(f"citation-moved  {note} › {where} -> {to_note} › {to_where}  {cite}")
    return 0


def main(argv):
    if len(argv) == 3 and argv[1] == "snapshot":
        print(snapshot(argv[2]))
        return 0
    if len(argv) == 4 and argv[1] == "sections":
        return sections(argv[2], argv[3])
    sys.exit(__doc__.split("Usage: ", 1)[1])


if __name__ == "__main__":
    sys.exit(main(sys.argv))
