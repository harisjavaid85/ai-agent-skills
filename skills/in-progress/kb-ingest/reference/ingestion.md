# Ingestion pipeline (source → `.md`)

How a source becomes a registered `.md`. The only judgment in this pipeline is whether a conversion is usable.

Each source owns a directory `sources/<key>/` holding its normalized `.md`, its kept originals, and the figures the conversion produced.

## Convert

`docling` is the only converter, invoked via shell (so it works under any harness). It must be on `PATH` which is a one-time setup. It handles PDF, office, HTML, images, and audio with layout, tables, equations, reading order, and OCR.

**Convert the form the document was authored in**, when it is published more than one way and the user has not named one. Papers, preprints, and reports: the PDF, which carries the authoritative tables and figures and is the only form giving page numbers for a citation to point at. Web-native articles (blog posts, distill-style pages, hosted demos): the HTML, whose PDF is an export of it.

One wrapper per converted route, same argument order, same output layout: `<key>.md` directly under `sources/<key>/`, with `artifacts/` beside it when the conversion produced figures. Both place docling's output themselves, so what lands on disk is decided by the wrapper and not by docling. Both run docling under a local-disk `TMPDIR`, because on NFS it exits 1 *after* writing a correct `.md`. Both refuse a conversion that produced almost no text, which docling itself misses.

**PDF, office, images.** `<source>` is a local path or a URL:

```bash
python3 <kb-ingest>/scripts/docling_convert_pdf.py \
  "<source>" "sources/<key>/" "<key>"
```

**HTML.**

```bash
python3 <kb-ingest>/scripts/docling_convert_html_with_figures.py \
  "<url>" "sources/<key>/" "<key>"
```

**Pasted text, plain notes.** No conversion: save the text as `sources/<key>/<key>.md` and register it. No wrapper, no `artifacts/`.

Trailing arguments to either wrapper pass through to docling.

- Add `--device cuda` and `--num-threads <n>` when GPUs are present. The gain is modest, so never let it block a conversion.
- Leave OCR at its default, which already runs on the pages that need it. `--force-ocr` discards a born-digital PDF's text layer and re-recognizes from pixels, corrupting prose.

## Keep originals

- Keep the original file(s) in `sources/<key>/` for **PDFs, images, and office/binary** formats: a faithful artifact for reading figures and tables and for verification.
- Keep the figures the conversion produced beside the `.md`, in `artifacts/`. **Every stored image must be reachable from the body that references it.** Where a source ships its own figure directory under another name, rename it to `artifacts/` **and repoint the body's references to match**: storing the images locally already changed the paths, so keeping the old strings is a broken render, not fidelity. Note the repointing in `citing`'s lead line, and no more.
- **Record where each file came from** in the entry's `files` list, in the shape the [citation contract](../../kb-builder/reference/citation.md) defines, leaving `origin` as the source's citable identity. When the kept original is not the file that was converted (a paper's PDF alongside a converted web build), fetch that original into `sources/<key>/` as well, so a rebuild restores it.
- **Exclude raw HTML.** A fetched page is normalized to `.md`; the page itself is not kept.

## Register

Add the source's key to `sources/index.md` (creating it if absent) per the schema in [citation.md](../../kb-builder/reference/citation.md), with **`status: candidate`**. `kb-integrate` moves it on from there.

On a **first** ingest, fill the entry's `citing` from this conversion and the sanity check below. It is the only channel by which a conversion caveat reaches a later pass. A reopen re-converts, so it rewrites `citing`; any other re-ingest leaves it alone.

**Write `citing` from the conversion alone:** every line states something learned by comparing the `.md` to the source it came from. A fact that would still be true had the conversion been perfect is subject matter, and belongs in the note that owns it.

## Fidelity guard: the failure path

If docling cannot produce a clean `.md` (unsupported format, scan without OCR, un-fetchable / paywalled / JS-only page, corrupt file, or a giant-page PDF: a web export that is one enormous unrasterizable page), **skip the source and report** "cannot be ingested" with the reason. Name the reason precisely enough to act on. A skip that says "the PDF is a single 102,000-pt page" tells the user to offer the HTML build instead; never go hunting for a substitute source yourself. No secondary converter, no degraded conversion. A missing docling is a setup error, not a reason to degrade.

One exception is worth a second attempt before reporting the skip: where the source itself publishes a Markdown sibling (the same URL with a `.md` extension, or a documented `llms.txt`-style endpoint), fetch that and register it as the conversion. That is the same document in the form the publisher chose to serve, not a substitute source.

**Do not try to recover a giant-page PDF.** Slicing by MediaBox/CropBox, rebuilding the pages as form-XObject slices, and throwing a GPU at it all fail the same way: every page still carries the whole document's content stream, so docling re-parses the entire document once per page and a conversion turns into hours. Diagnose the geometry with pikepdf, because `pypdfium2.get_size()` reports the CropBox and hides the oversized MediaBox that is the real problem.

## Sanity-check the conversion

Some defects survive conversion instead of failing it, so a clean exit is not a clean `.md`. After every conversion, check the produced `.md` against the source and record what you find in the entry's `citing`, per the [citation contract](../../kb-builder/reference/citation.md), which governs which field each finding belongs in. Detection only: never edit the `.md`. The wrapper's counts seed that entry. Investigate every mismatch they show, **and every line printed beneath them**: agreement across the counts is not a clean reading on its own, and a `caption gap:` line names a loss they agree straight through.

Where to look, and what each place catches, all of it observed in this KB's corpus:

- **Every table, and the 40 lines after it.** A table spanning a page break arrives shredded: row labels become headings, cell values a flat list, the last column loose paragraphs, so the remnant is no longer a table at all. A row-label column also collapses on its own, values staying in row order against merged or empty labels.
- **Every figure, its caption, and the sentences either side.** Captions detach from their figure or splice mid-sentence; figure content that exists only inside the image reaches the `.md` as nothing at all.
- **Every `<!-- formula-not-decoded -->`.** One lost display equation, or several. Inline math flattens as well, subscripts running together.
- **Every heading.** Page headers, run-in bold leads, and figure panel labels all arrive promoted to `##`.
- **Every image link.** Some resolve to nothing on disk.
- **The first and last 100 lines.**

## Idempotency

Ingest is idempotent: a known source (matched by key or origin) is not re-converted, only its metadata refreshed. `retrieved` is exempt, since it records when the source was **fetched**: a refresh that does not re-fetch leaves it as it found it, or the field names a fetch that never happened.

A re-ingest of an already-`integrated` key refreshes metadata and leaves `status`, `dropped`, and `citing` alone; it never demotes a source back to `candidate`. `citing` is protected because a refresh that does not re-convert has no new conversion caveat to report, so overwriting it could only lose the caveats the first conversion found.

A `declined` key is the exception: its files were deleted, so re-ingesting re-converts the source and returns it to `candidate`. That is how a rejected source is reopened.

Reopening is deliberate. Report the prior decline and its reason, and confirm, before re-converting. The reopen overwrites both, and a match by `origin` reaches this path without the key ever being typed.
