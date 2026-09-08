#!/usr/bin/env python3
"""Convert an HTML page to markdown with its figures intact.

docling's HTML backend mishandles figures three ways: it drops SVGs outright,
flattens GIFs, and discards <figure>/<picture> wrappers whole, taking the
<img> and the <figcaption> with them. Its native image fetch also aborts on
some pages while still exiting 0. This wraps the conversion instead: the
wrappers are flattened to <div>/<p> so captions survive as prose, and each
<img> is replaced with a numbered text sentinel before docling sees the page,
becoming a markdown image link afterward with the asset fetched alongside.
No <img> reaches docling, so its image handling is bypassed.

The sentinels are numbered because docling silently drops non-content images
(nav icons, hidden elements); matching by position would misalign the rest.

Writes <dir>/<key>.md and <dir>/artifacts/. Assets
that 404 become an HTML comment naming the alt text, so a dropped figure is
visible rather than silent.

Requires `docling` on PATH. Extra arguments are passed through to it, e.g.
`--device cuda`.

Usage: docling_convert_html_with_figures.py <url> <dir> <key> [docling-args...]
"""

import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse

from conversion_utils import refuse_if_empty, report

SENTINEL = re.compile(r"@@IMG(\d+)@@")


def _clean_alt(raw):
    """Alt text must survive as a single-line markdown label."""
    return re.sub(r"\s+", " ", html.unescape(raw)).replace("[", "(").replace("]", ")").strip()


def _fetch(url, dest=None):
    cmd = ["curl", "-sfL", "--max-time", "60"]
    if dest:
        return subprocess.run(cmd + ["-o", dest, url]).returncode == 0
    return subprocess.run(cmd + [url], capture_output=True, text=True,
                          errors="replace").stdout


def _unwrap(src):
    """Flatten <figure>/<picture> so docling keeps what they contain.

    docling discards these wrappers whole: the <img> sentinel inside one goes
    with it, and so does the <figcaption>, which often carries the figure's
    real explanation. Rewritten to <div>/<p> they read as ordinary content.
    <source> is dropped rather than rewritten: it is a void element whose
    srcset alternatives are never fetched.
    """
    src = re.sub(r"<source\b[^>]*>", "", src, flags=re.I)
    src = re.sub(r"<(?:figure|picture)\b[^>]*>", "<div>", src, flags=re.I)
    src = re.sub(r"</(?:figure|picture)>", "</div>", src, flags=re.I)
    src = re.sub(r"<figcaption\b[^>]*>", "<p>", src, flags=re.I)
    return re.sub(r"</figcaption>", "</p>", src, flags=re.I)


def _patch(url):
    """Swap every <img> for a sentinel; return (patched html, image list)."""
    src = _fetch(url)
    if not src:
        sys.exit(f"failed to fetch {url}")

    src = _unwrap(src)

    # Relative hrefs would survive conversion as local paths that resolve to
    # nothing inside sources/<key>/. Point them back at the origin.
    def abs_href(m):
        h = m.group(1)
        if h.startswith(("#", "mailto:", "data:")):
            return m.group(0)
        return f'href="{urllib.parse.urljoin(url, h)}"'

    src = re.sub(r'href="([^"]+)"', abs_href, src)

    imgs = []

    def repl(m):
        tag = m.group(0)
        s = re.search(r'\bsrc="([^"]+)"', tag)
        if not s or s.group(1).startswith("data:"):
            return tag
        a = re.search(r'\balt="([^"]*)"', tag, flags=re.S)
        imgs.append((s.group(1), _clean_alt(a.group(1)) if a else ""))
        return f"<p>@@IMG{len(imgs) - 1}@@</p>"

    return re.sub(r"<img\b[^>]*>", repl, src, flags=re.I), imgs


def _asset_name(i, src):
    """Name the file the numbered sentinel <i> resolves to.

    Decode before taking the basename: an image CDN embeds the origin URL,
    percent-encoded, inside its own path, so the raw basename is that whole
    escaped URL. A name left holding percent-escapes is unusable: every
    markdown renderer decodes a link target before resolving it, so the link
    would point at a path that does not exist.
    """
    path = urllib.parse.unquote(urllib.parse.urlparse(src).path)
    name = os.path.basename(path.rstrip("/")) or "asset"
    return f"img{i:03d}_" + re.sub(r"[^A-Za-z0-9._-]", "_", name)


def _restore(md, imgs, url, outdir):
    """Fetch the assets docling kept and turn sentinels into image links."""
    kept = sorted({int(x) for x in SENTINEL.findall(md)})
    # Created only when there is something to put in it.
    if kept:
        os.makedirs(os.path.join(outdir, "artifacts"), exist_ok=True)
    mapping, ok = {}, 0
    for i in kept:
        u, alt = imgs[i]
        src = urllib.parse.urljoin(url, u)
        name = _asset_name(i, src)
        dest = os.path.join(outdir, "artifacts", name)
        good = _fetch(src, dest) and os.path.exists(dest) and os.path.getsize(dest) > 0
        mapping[i] = (f"artifacts/{name}" if good else None, alt)
        ok += good

    def sub(m):
        p, alt = mapping.get(int(m.group(1)), (None, ""))
        return f"![{alt}]({p})" if p else f"<!-- image (unavailable): {alt} -->"

    return SENTINEL.sub(sub, md), ok, len(mapping)


def run(url, outdir, key, extra=()):
    patched, imgs = _patch(url)
    print(f"sentinels inserted: {len(imgs)}")

    # docling's temp files must land on local disk: on NFS it raises
    # OSError 39 during cleanup and exits 1 *after* writing a good .md.
    tmp = tempfile.mkdtemp(prefix="docling-", dir=os.environ.get("TMPDIR", "/tmp"))
    try:
        stage = os.path.join(tmp, "index.patched.html")
        open(stage, "w", encoding="utf-8").write(patched)
        r = subprocess.run(
            ["docling", "convert", stage, "--to", "md",
             "--output", tmp, "--abort-on-error", *extra],
            env={**os.environ, "TMPDIR": tmp},
        )
        out = os.path.join(tmp, "index.patched.md")
        if r.returncode != 0 or not os.path.exists(out):
            sys.exit(f"docling failed (exit {r.returncode}): source not ingestible")
        md = open(out, encoding="utf-8").read()
        refuse_if_empty(md)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    os.makedirs(outdir, exist_ok=True)
    md, ok, total = _restore(md, imgs, url, outdir)
    open(os.path.join(outdir, f"{key}.md"), "w", encoding="utf-8").write(md)

    print(f"assets fetched {ok}/{total}")
    if ok < total:
        print(f"WARNING: {total - ok} asset(s) unavailable, marked in the .md")
    # Resolves every link in the placed .md, including the ones the sentinel
    # mechanism never created: a page carrying its own relative image paths
    # passes through untouched and would otherwise be reported as clean.
    report(md, outdir, key)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    run(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:])
