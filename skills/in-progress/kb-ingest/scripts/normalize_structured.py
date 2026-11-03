#!/usr/bin/env python3
"""Normalize a structured source, per the citation contract, to pointer lines.

The original's extension picks its parser; only JSON is supported so far, and
any other extension is refused.

Writes `<outdir>/<key>.md` holding one unlabelled fenced block and nothing
else: one `<JSON Pointer>: <compact JSON value>` line per leaf, in document
order. A leaf is a scalar, an array, or an empty map; an array stays one inline
value.

Prints `<key>.md written` and the leaf count, the line `citing`'s `checked:`
holds. Exits non-zero, writing nothing, on an unsupported extension, an
unreadable file, an original that does not parse, or zero leaves.

Usage: normalize_structured.py <original> <outdir> <key>
"""

import json
import os
import sys

PARSERS = {".json": json.load}


def escape(segment):
    """One RFC 6901 reference token: `~` before `/`, or `~1` reads back as `/`."""
    return segment.replace("~", "~0").replace("/", "~1")


def leaves(value, pointer=""):
    """Yield (pointer, value) for every leaf under value, in document order."""
    if isinstance(value, dict) and value:
        for k, v in value.items():
            yield from leaves(v, f"{pointer}/{escape(k)}")
    elif pointer:
        yield pointer, value


def run(original, outdir, key):
    parse = PARSERS.get(os.path.splitext(original)[1].lower())
    if parse is None:
        sys.exit(f"{original}: unsupported format (supported: {', '.join(PARSERS)})")
    try:
        with open(original, encoding="utf-8") as fh:
            data = parse(fh)
    except OSError as e:
        sys.exit(f"{original}: cannot read ({e.strerror})")
    except ValueError as e:
        sys.exit(f"{original}: does not parse ({e})")
    lines = [f"{p}: {json.dumps(v, ensure_ascii=False)}" for p, v in leaves(data)]
    if not lines:
        sys.exit(f"{original}: no leaves: nothing to cite")
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, f"{key}.md"), "w", encoding="utf-8") as fh:
        fh.write("```\n" + "\n".join(lines) + "\n```\n")
    print(f"{key}.md written")
    print(f"  {len(lines)} leaves")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    run(sys.argv[1], sys.argv[2], sys.argv[3])
