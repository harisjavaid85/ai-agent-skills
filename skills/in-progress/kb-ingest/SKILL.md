---
name: kb-ingest
description: "Ingest sources into a named file-based knowledge base: normalize each to Markdown and register it under a stable key. Use when the user asks to add papers, PDFs, URLs, or notes to a specific KB, or to ingest sources into a KB for review before integrating them."
---

# KB Ingest

Take sources into a file-based knowledge base: normalize → register. Stops at `sources/index.md` and writes nothing to `knowledge/`, which is `kb-integrate`'s job.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](../kb-builder/reference/registry.md). Done when you have its absolute root path.

## 2. Normalize and register each argument

An argument is either a **source** (URL, path, pasted text) or an **already-registered key**, since a caller re-running over what it ingested earlier holds keys rather than URLs. Resolve each against `sources/index.md` first, by key or by `origin`. [ingestion.md](./reference/ingestion.md)'s *Idempotency* rule governs the three cases:

- **Unknown.** Convert and register it.
- **Known**, status `candidate` or `integrated`. Refresh its metadata only; nothing is re-converted.
- **Known, status `declined`.** A reopen, which re-converts. **Confirm with the user first**, per that rule.

Run the pipeline in [ingestion.md](./reference/ingestion.md) on each **new or reopened** source: convert, keep the originals, register the key. Done when every ingestible source has a normalized `.md` and an entry carrying every field the [citation contract](../kb-builder/reference/citation.md)'s registry schema lists, and every source left out is noted with its reason.

## 3. Report

List the ingested keys, each now a `candidate`; the known keys that were only refreshed; and the sources left out with their reasons, both those the fidelity guard skipped and any reopen that was not confirmed. Done when the user can see what entered `sources/`, what didn't, and that nothing has been integrated yet.
