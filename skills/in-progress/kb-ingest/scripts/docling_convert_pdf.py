#!/usr/bin/env python3
"""Convert a PDF (or office/image file) to markdown at a fixed, known layout.

Run bare, docling decides the layout and the caller inherits two problems. It
names the `.md` after the input, so every caller hardcodes an assumption about a
name it does not control. And it nests the figure directory one level deep,
under a directory named after the *output* directory, so `--output k/` yields
`k/k/probe_artifacts/` and there is no honest way to write that into an entry's
`files`, which lists top-level names only.

So the conversion happens in a temp directory and the outputs are *placed*:
`<dir>/<key>.md` and `<dir>/artifacts/`, with every image link rewritten to
match. Nothing in the result derives from docling's naming, which is what makes
both problems collapse into this one file.

Links are rewritten by resolving each one against the file that was actually
moved, never by substituting a known prefix, so the next layout change docling
makes is absorbed here instead of silently producing dead links.

Requires `docling` on PATH. Extra arguments are passed through to it, e.g.
`--device cuda`.

Usage: docling_convert_pdf.py <source> <dir> <key> [docling-args...]
"""

import glob
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.parse

from conversion_utils import IMAGE, REMOTE, refuse_if_empty, report


def _convert(source, tmp, extra):
    """Run docling into `tmp`; return the path of the `.md` it produced."""
    r = subprocess.run(
        ["docling", "convert", source, "--to", "md", "--output", tmp,
         "--image-export-mode", "referenced", "--abort-on-error", *extra],
        env={**os.environ, "TMPDIR": tmp},
    )
    # Located by glob, not by computing a name from the input stem. That stem
    # rule is docling's, undocumented, and has already changed once.
    produced = sorted(glob.glob(os.path.join(tmp, "*.md")))
    if r.returncode != 0 or not produced:
        sys.exit(f"docling failed (exit {r.returncode}): source not ingestible")
    if len(produced) > 1:
        sys.exit(f"docling produced {len(produced)} .md files, expected 1: "
                 + ", ".join(os.path.basename(p) for p in produced))
    return produced[0]


def _place_artifacts(tmp, outdir):
    """Move every artifacts directory under `tmp` into `<outdir>/artifacts/`.

    Returns {absolute path before the move: path relative to outdir}, which is
    what lets the links be rewritten by resolution rather than by prefix.
    """
    dest = os.path.join(outdir, "artifacts")
    moves = {}
    for adir in sorted(d for d, _, _ in os.walk(tmp) if d.endswith("_artifacts")):
        for root, _, names in os.walk(adir):
            for name in sorted(names):
                src = os.path.join(root, name)
                rel = os.path.relpath(src, adir)
                target = os.path.join(dest, rel)
                # Two artifacts directories can hold the same relative name.
                # Overwriting one with the other would leave a link pointing at
                # the wrong figure, which reads as a correct conversion.
                stem, ext = os.path.splitext(target)
                n = 1
                while os.path.exists(target):
                    target = f"{stem}_{n}{ext}"
                    n += 1
                os.makedirs(os.path.dirname(target), exist_ok=True)
                key = os.path.realpath(src)
                shutil.move(src, target)
                moves[key] = os.path.relpath(target, outdir)
    return moves


def _rewrite_links(md, md_dir, outdir, moves):
    """Repoint each image link at where its file was actually moved to."""
    def sub(m):
        alt, target = m.group(1), m.group(2).strip()
        if not target or target.startswith(REMOTE):
            return m.group(0)
        was = os.path.realpath(os.path.join(md_dir, urllib.parse.unquote(target)))
        moved = moves.get(was)
        return f"![{alt}]({moved})" if moved else m.group(0)

    return IMAGE.sub(sub, md)


def run(source, outdir, key, extra=()):
    # docling's temp files must land on local disk: on NFS it raises OSError 39
    # during cleanup and exits 1 *after* writing a good .md.
    tmp = tempfile.mkdtemp(prefix="docling-", dir=os.environ.get("TMPDIR", "/tmp"))
    try:
        produced = _convert(source, tmp, extra)
        md = open(produced, encoding="utf-8").read()
        refuse_if_empty(md)

        os.makedirs(outdir, exist_ok=True)
        moves = _place_artifacts(tmp, outdir)
        md = _rewrite_links(md, os.path.dirname(produced), outdir, moves)
        open(os.path.join(outdir, f"{key}.md"), "w", encoding="utf-8").write(md)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    report(md, outdir, key)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    run(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:])
