# Citation contract

How a claim connects to its source, and what to do when it cannot. Shared by `kb-ingest` (registering), `kb-integrate` (writing claims), `kb-verify` (auditing), and `kb-expert` (answering).

What a note may **say** is a separate question, governed by [distillation.md](./distillation.md). This file governs the connection only: its notation, its targets, and what to do when there is none.

## Golden rules

- **Never fabricate.** No invented facts, numbers, dates, or quotes, and never invent a citation to clear a marker.
- **When unsure, mark it.** A claim you cannot ground gets a marker (below) and is left standing; never smooth over a gap with a plausible guess, and never silently delete a claim to make one go away.
- **Markers and citations go into a note as plain text, never inside backticks.** The check skips inline code, so that a snippet like `x[i]` does not read as a citation to key `i`. A marker or citation wrapped the same way is invisible to it, and an open marker then reads as a clean run.

## Grounding markers

Inline markers on a claim, cleared only by grounding (a re-ground pass or a new source) or by a human.

- **`[UNVERIFIED]` (never grounded).** Sits on a subject claim the current sources cannot ground: none of them says it, or the one that does arrived too mangled to cite from. `kb-integrate` writes it. Likely fix: a new source, or a cleaner conversion.
- **`[DRIFTED]` (citation broke).** Sits on a subject claim whose cited locator no longer supports it. `kb-verify` writes it. Likely fix: relocate within the same source.

A KB with open markers that **belong** is not current. That is the golden rule working, not a defect.

### The marker invariant

**A grounding marker applies to a claim about the subject. A claim about a source is never marked: it is grounded by citing that source.**

**The claim need not be a whole sentence.** Where a note's structure already supplies the subject and the predicate, a marker standing where the value would go is a marker on a subject claim. A table cell is the common case: its row names the subject, its column the property, and the cell is the ungrounded value.

A marker that does not belong is a defect. A **false marker** sits on a claim about a source rather than about the subject, so it makes the KB report itself not-current when nothing is actually ungrounded. Its fix belongs to [distillation.md](./distillation.md) rule 5, since it rewrites what a note says. Where that fix deletes the sentence, it is not the deletion the golden rules forbid: a sentence that was never a subject claim takes nothing grounded with it.

## Keys and their status

An **orphan key** (an `integrated` entry cited nowhere) is registry hygiene, not a claim defect: `kb-verify` reports it but leaves no inline mark. Likely fix: cite it or prune it. A `candidate` cited nowhere is expected, since it is registered and not yet folded in.

A `declined` entry must be cited nowhere at all: `kb-integrate` deletes its files, so a surviving citation is a claim defect. Likely fix: re-ingest the source if the decline was wrong, otherwise repoint the claim. The check confirms both halves of that, the entry recording its reason and its files being in fact gone, since an undeleted decline leaves the citation rule resting on a false premise.

## Citations are receipts

A citation lets a reader verify or drill down; it is not needed to understand the claim.

- Form: `[key: locator]`. `[key]` resolves in the KB's `sources/index.md`.
- A **locator is required for any specific claim** (a number, result, quote, figure); a bare `[key]` is allowed only for a source's central thesis.

Locator grammar:

| Locator | Cites |
| --- | --- |
| `[key]` | whole source / thesis-level claim |
| `[key: p.7]`, `[key: pp.7-9]` | page(s) of the original |
| `[key: §"Heading text"]` | a section of the normalized `.md` (level-agnostic; matches heading text) |
| `[key: fig.3]`, `[key: tbl.2]`, `[key: eq.4]` | a figure, table, or equation |
| `[key: @12:30]` | a timestamp (audio/video source) |
| `[key: "short exact quote"]` | an exact quote, the most robust locator |

## Stable keys

- One bib-style key per source (e.g. `[wang2024-qsparse]`), assigned at ingest.
- Reused across every note. Append new keys; **never renumber**.

## `sources/index.md`, the KB-wide citation registry

One entry per key:

| Field | Content |
| --- | --- |
| key | stable bib-style key |
| files | **required** unless `declined`, whose files are deleted. `<key>.md`, any figure directory, and any kept originals: the **top-level** names under the entry's own `sources/<key>/` and nothing nested inside them, **each in backticks**, each fetched file noting the URL it came from, and a figure directory its file count rather than its contents. Paths, counts, and URLs only; the judgment goes in `citing` |
| origin | URL / arXiv / DOI + version |
| title | source title |
| authors | source authors |
| retrieved | date the source was fetched |
| type | paper, post, note, ... |
| status | **required.** `candidate` (registered, not yet folded in), `integrated` (folded into `knowledge/`), or `declined` (reviewed and rejected). A decline carries the user's reason and the date in parentheses: `declined (superseded by austin2025-scaling, 2026-08-13)` |
| citing | **required.** Written by `kb-ingest`, once per conversion, and holding conversion fidelity only. Answers one question: *"what do I need to know before writing from this source?"* A lead line naming what was converted, then `locators:`, `checked:`, `damaged:`, and `quirks:` as indented sub-bullets. Shape and rules below |
| dropped | **required** on an `integrated` entry. Append-only: one line per integrate pass, oldest first. Never edit or remove an existing entry. Each entry is `<YYYY-MM-DD>: <what this pass left behind>; <why>`. When a pass took everything remaining, the entry is `<YYYY-MM-DD>: nothing`. A `candidate` carries none, having left nothing behind yet. **Capped at 80 words per line, with no cap on the field as a whole**: when a line runs over, cut its reasons rather than its list, since the list is what a later pass needs |

`dropped` buys one thing: a deliberate decision, with its reason, on the record for a later pass or a human to review and disagree with. It cannot tell a deliberate skip from a forgotten one, since an agent that missed a section writes `nothing`. Requiring it is what makes `nothing` readable: optional, a blank is ambiguous; required, it is a gap `kb-verify` reports.

### What `citing` carries

**The schema is a lead line, then `locators:`, `checked:`, `damaged:`, and `quirks:`, in that order. Follow it strictly: nothing added, nothing dropped.** Each makes a different **kind** of statement, which is what keeps them from overlapping. Write all of them **terse**: `locators:` and `checked:` are phrases, `damaged:` and `quirks:` the shortest sentences that carry a finding. Every entry is read in full before anything is written from its source, so length here is a tax on every later pass.

**The lead line** names what was converted: the form, its extent, and anything separating this conversion from what `origin` already names, an unpinned URL or a `.md` assembled from several pages. The version itself lives in `origin`, and what a locator reaches lives in `locators:`. **Capped at 25 words.**

- **`locators:`** capability. One mark per locator form in the grammar above, in that order, `n/a` where the source's type has no such form. The bare `[key]` row takes none, being the absence of a locator. Judged from the source's form and a spot check, not from counts. Qualify a mark that holds only within a bound: `§"…" ✓ (all headings at ##)`.
- **`checked:`** inspection scope, machine-derived: the counts line `kb-ingest`'s conversion wrapper printed and any `N HTML tables` term beneath it, pasted verbatim, then investigated. Each caption count carries a total and a **distinct** count; the distinct one is what pairs against the objects, and a total far above it means duplicates or line-initial cross-references. A mismatch names where to look, so 13 tables against 9 distinct `Table N` captions is four extra blocks, one table shredded into pieces, and 16 distinct `Figure N` captions against 13 images is three figures whose images never arrived. Headings and HTML tables pair with nothing: headings read across documents, so 76 where comparable papers carry 30 is heading noise. **Agreement is necessary, not sufficient:** a `.md` that lost Tables 7 and 8 still reports 8 tables against 8 captions. The wrapper's `caption gap:` line catches that and seeds `damaged:`, not this field. It is itself a floor: **a printed gap is real; an empty line is unproven.**
- **`damaged:`** every finding that has a location, written `damaged (N):` with **N the count of distinct findings**. The wrapper's lost-equation count and its `caption gap:` line both seed this field, not `checked:`. **Capped at 30 words per finding**, so its length tracks the damage rather than the source's size. Never drop or merge findings to meet the rate; over it, the entry is over-explaining. `damaged: none` when the check found nothing, with no count.
- **`quirks:`** every finding that has **no** location, because it runs through the whole document. That is why it cannot name a page, and why it is capped at **50 words** flat rather than by rate: a document-wide finding has a bounded number of things to say, so it needs no count. `quirks: none` when there are none.

Three cross-checks tie the four together:

- **Every `✗` in `locators:`, and every mark whose qualifier names something absent or unreachable, has an entry in `damaged:` or `quirks:` saying why.** A qualifier asserting that something does not resolve needs the same backing as an outright `✗`: `tbl ✓ (not 7, 8)` obliges a line saying where Tables 7 and 8 went. One describing what the form reaches, `§"…" ✓ (all headings at ##)`, needs none.
- **For every `damaged:` entry, point at damage with a form that still works.** Object and pointer are different things: the lost equations sit behind `eq ✗`, so the entry locates them by section, `§ ✓`. With no location at all, `kb-integrate` reads the whole document to find one table; where no working form reaches the damage, say so.
- **What the `.md` cannot count stays out of `checked:`.** A lost equation leaves no trace of what it replaced, and pages leave no marker to count at all.

Two things stay out of all these fields, both because they are content rather than fidelity:

- **No transcribed values.** A value recovered from a damaged table is a claim: it belongs in `knowledge/`, cited to the kept original, which is what `damaged:`'s pointer sends `kb-integrate` to open.
- **No cross-source commentary.** That one source names another under a different title, or supersedes it, is knowledge about the subject and goes in the note that owns it.

`kb-verify` can see a missing `dropped`, but not a missing `damaged:`, which sits inside `citing`, so this contract is the only thing requiring it. `checked:` is what keeps the **partial** case unambiguous, which is the common one: without it, `damaged: Table 4 collapsed` cannot be told apart from "found Table 4 and stopped looking".

### Entry shape

One `##` heading per key, the remaining fields as bullets in the table's order. These are the only headings the file carries, so `## <key>` identifies an entry unambiguously:

```
## wang2024-qsparse

- **files:** `wang2024-qsparse.md`;
    `wang2024-qsparse.pdf` (https://arxiv.org/pdf/2404.00000v1);
    `artifacts/` (12 files)
- **origin:** https://arxiv.org/abs/2404.00000v1
- **title:** Q-Sparse: All Large Language Models can be Fully Sparsely-Activated
- **authors:** …
- **retrieved:** 2026-08-07
- **type:** paper
- **status:** integrated
- **citing:** Born-digital 53-page PDF.
  - locators: p ✓ · §"…" ✓ (all headings at ##) · fig ✓ · tbl ✓ · eq ✗ · @ n/a ·
    quote ✓ (not across inline math)
  - checked: 8 tables, 8 captions (8 distinct) · 8 images, 8 resolve, 8 captions (8 distinct) ·
    30 headings
  - damaged (2): 9 display equations lost (§§2.1-3.1). Table 4 (p.15) row-labels collapsed,
    so rows 3 and 7 share a label; drops cols F and K, cite the PDF.
  - quirks: Inline math flattens, so subscripts run together (`O L 2` for O(L²)).
- **dropped:** 2026-08-07: Appendix C's ablation grid; superseded by the §4 table.
               2026-08-19: nothing
```

`kb-verify`'s check reads `## <key>` and the `- **<field>:** <value>` bullets under it, a value continuing onto an **indented** line as `files`, `citing`, and `dropped` all do, with a blank line ending the value. `citing`'s sub-bullets are indented for exactly that reason: unindented, each would read as a new field and the block would fall out of the entry. It parses `status`, `citing`, `dropped`, and `files`, resolving the last against `sources/<key>/` on disk. Written any other way, no key resolves and every citation in the KB reads as a defect.
