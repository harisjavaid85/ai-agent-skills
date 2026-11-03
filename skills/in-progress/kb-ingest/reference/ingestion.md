# Ingestion pipeline (source → `.md`)

How a source becomes a registered `.md`.

Each source owns a directory `sources/<key>/` holding its normalized `.md`, its kept originals, and the figures the conversion produced.

## Convert

`docling` is the only document converter (converters for other types are below), invoked via shell; it must be on `PATH`. It handles PDF, office, HTML, images, and audio.

**Convert the form the document was authored in**, when it is published more than one way and the user has not named one. Papers, preprints, and reports: the PDF. Web-native articles (blog posts, distill-style pages, hosted demos): the HTML.

**Fetch with `curl`, never WebFetch.** Only the HTML converter takes a URL directly. Fetch every other source given by URL with `curl -fsSL -o <file> "<url>"` into a `mktemp -d` directory and convert it from there. Once its conversion is kept, move the fetched file into `sources/<key>/` per *Keep originals*. Otherwise delete it. WebFetch returns a summary, not the source. A source `curl` cannot fetch in full is un-fetchable under the fidelity guard.

One script per converted route, same argument order, same output layout: `<key>.md` directly under `sources/<key>/`, with `artifacts/` beside it when the conversion produced figures.

**PDF, office, images.** `<source>` is a local path:

```bash
python3 <kb-ingest>/scripts/docling_convert_pdf.py \
  "<source>" "sources/<key>/" "<key>"
```

**HTML.**

```bash
python3 <kb-ingest>/scripts/docling_convert_html_with_figures.py \
  "<url>" "sources/<key>/" "<key>"
```

**Structured sources**: an original that parses to a data tree, per the [citation contract](../../kb-builder/reference/citation.md)'s pointer row, registered with `locators: pointer ✓`. Only JSON is supported so far. `<original>` is the fetched or given file under its published name, whose extension picks the parser, and keeps that name in `sources/<key>/`. It writes one `<JSON Pointer>: <value>` line per leaf:

```bash
python3 <kb-ingest>/scripts/normalize_structured.py \
  "<original>" "sources/<key>/" "<key>"
```

**Pasted text, plain notes.** No conversion: save the text as `sources/<key>/<key>.md` and register it. No converter, no `artifacts/`.

Trailing arguments to either docling converter pass through to docling.

- Add `--device cuda` and `--num-threads <n>` when GPUs are present. Never let it block a conversion.
- Leave OCR at its default, which already runs on the pages that need it. `--force-ocr` discards a born-digital PDF's text layer and re-recognizes from pixels, corrupting prose.

## Keep originals

- Keep the original file(s) in `sources/<key>/` for **PDFs, images, office/binary**, and **structured** formats.
- Keep the figures the conversion produced beside the `.md`, in `artifacts/`. **Every stored image must be reachable from the body that references it.** Where a source ships its own figure directory under another name, rename it to `artifacts/` **and repoint the body's references to match**. Note the repointing in `citing`'s lead line, and no more.
- **Record where each file came from** in the entry's `files` list, in the shape the [citation contract](../../kb-builder/reference/citation.md) defines, leaving `origin` as the source's citable identity. When the kept original is not the file that was converted (a paper's PDF alongside a converted web build), fetch that original as well and move it in with the converted source.
- **Exclude raw HTML.** A fetched page is normalized to `.md`; the page itself is not kept.

## Register

Add the source's key to `sources/index.md` (creating it if absent) per the schema in [citation.md](../../kb-builder/reference/citation.md), with **`status: candidate`**.

On a **first** ingest or a reopen, the two paths that convert, fill the entry's `citing` from this conversion and the sanity check below, per the [citation contract](../../kb-builder/reference/citation.md)'s *What `citing` carries*: every line states something learned by comparing the `.md` to the source it came from.

## Fidelity guard: the failure path

If the converter cannot produce a clean `.md` (unsupported format, scan without OCR, un-fetchable / paywalled / JS-only page, corrupt file, a structured original that does not parse or holds no leaves, or a giant-page PDF: a web export that is one enormous unrasterizable page), **skip the source and report** "cannot be ingested" with the reason, and delete any `sources/<key>/` the attempt wrote. Name the reason precisely enough to act on ("the PDF is a single 102,000-pt page"); never go hunting for a substitute source yourself. No fallback converter, no degraded conversion. A missing docling is a setup error, not a reason to degrade.

One exception is worth a second attempt before reporting the skip: where the source itself publishes a Markdown sibling (the same URL with a `.md` extension, or a documented `llms.txt`-style endpoint), fetch that, save it as `sources/<key>/<key>.md`, and register it as the conversion. That is the same document in the form the publisher chose to serve, not a substitute source.

**Do not try to recover a giant-page PDF**: no slicing by MediaBox or CropBox, no form-XObject rebuild, no GPU. Diagnose its geometry with pikepdf, which reports the oversized MediaBox; `pypdfium2.get_size()` reports only the CropBox.

## Sanity-check the conversion

After every conversion, check the produced `.md` against the source and record what you find in the entry's `citing`, per the [citation contract](../../kb-builder/reference/citation.md), which governs which field each finding belongs in. This check corrects nothing in the `.md`. The converter's counts seed that entry: investigate every mismatch they show, **and every line printed beneath them**.

Where to look in a docling conversion, and what each place catches:

- **Every table, and the 40 lines after it.** A table spanning a page break arrives shredded: row labels become headings, cell values a flat list, the last column loose paragraphs, so the remnant is no longer a table at all. A row-label column also collapses on its own, values staying in row order against merged or empty labels.
- **Every figure, its caption, and the sentences either side.** Captions detach from their figure or splice mid-sentence; figure content that exists only inside the image reaches the `.md` as nothing at all.
- **Every `<!-- formula-not-decoded -->`.** One lost display equation, or several. Inline math flattens as well, subscripts running together.
- **Every heading.** Noise headings arrive promoted to `##`: name them in `quirks:`, per the citation contract.
- **Every image link.** Some resolve to nothing on disk.
- **The first and last 100 lines.**

## Idempotency

Ingest is idempotent: a known source (matched by key or origin) is not re-converted, only its metadata refreshed. `retrieved` changes only when the source is re-fetched.

A re-ingest of an already-`integrated` key refreshes metadata and leaves `status`, `dropped`, and `citing` alone; it never demotes a source back to `candidate`.

A `declined` key is the exception: re-ingesting it, a **reopen**, re-converts the source and returns it to `candidate`. Report the prior decline and its reason, and confirm, before re-converting. The reopen overwrites both, and a match by `origin` reaches this path too.
