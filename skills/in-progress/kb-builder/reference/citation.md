# Citation contract

How a claim connects to its source, and what to do when it cannot. What a note may **say** is [distillation.md](./distillation.md)'s question. Grounding ties text to the sources it cites: no marker or verdict says whether a claim, or a source, is true.

## Golden rules

- **Never fabricate.** No invented facts, numbers, dates, quotes, or citations; never invent a citation to clear a marker.
- **When unsure, mark it.** A claim you cannot ground is left standing with its marker, per *Markers*; never smooth over a gap with a plausible guess, and never delete a claim to make a marker go away.
- **Markers and citations go into a note as plain text, never inside backticks**: the check skips inline code, so a wrapped marker or citation is invisible to it.

## Citations are receipts

- Form: `[key: locator]`. `[key]` resolves in the KB's `sources/index.md`.
- A **locator is required for any specific claim** (a number, result, quoted wording, figure); a bare `[key]` is allowed only for a source's central thesis.
- **Damaged content.** Content `citing`'s `damaged:` lists is not a place in the normalized `.md`: a claim cited to it there is unsupported, and is cited from the kept original instead (`p.`, `fig.`, `tbl.`, `eq.`).
- **One locator per bracket.** A key list (`[a, b]`, `[a; b]`) or several locators in one bracket (`[a: p.1; b: p.2]`, `[a: p.1; a: p.4]`) is malformed.

Locator grammar:

| Locator | Cites |
| --- | --- |
| `[key]` | whole source / thesis-level claim |
| `[key: p.7]`, `[key: pp.7-9]` | page(s) of the original |
| `[key: §"Heading text"]` | a section of the normalized `.md`: the named heading's body and its Markdown descendants, ending at the next heading of the same or higher level that is not a noise heading `citing`'s `quirks:` names. Numbering adds no nesting: `## 2` ends at the next `## 2.1`. The heading is outside fenced code, at any level, and reads as written, whitespace and decoration aside (a self-link, `**`, an HTML entity, a backslash escape, a closing `#` run after a space, a trailing `¶`), with no other such heading reading the same; the name holds no `"` or `]` |
| `[key: fig.3]`, `[key: tbl.2]`, `[key: eq.4]` | a figure, table, or equation. N is Arabic whatever numerals the caption uses, so a table captioned "Table IV" is `tbl.4` |
| `[key: "verbatim span"]` | a line of the normalized `.md`: a span copied verbatim (whitespace aside) from one line outside fenced code, found on no other such line, holding no `"`, `[`, `]`, or backtick |
| `[key: /json/pointer]` | a node of a structured source: a leaf, its line in the normalized `.md`; an element of an array leaf by index (`/architectures/0`); or a map, every line under its prefix (`/` for the whole file), for a claim about it as a whole, such as its keys, a count, or a comparison with another source's. A **structured source** is one whose kept original parses to a data tree of maps, arrays, and scalars; its `citing` declares `locators: pointer ✓`, it keeps that original in `files`, and its `.md` is one fenced block of pointer lines. It takes pointers only, and a pointer cites only a structured source; a claim citing a leaf states its value |

## Coverage

Which text each citation covers. Work it out as if every marker were absent: a marker never changes what a citation covers.

- **Units.** A citation covers the text before it, back to the previous citation or the start of its unit: a paragraph, a list item, or a table cell. It never covers text after it.
- **Adjacent citations**, with only whitespace between them, count together as one citation.
- **Lead-ins.** A paragraph or list item ending in `:` directly before a block (a list, table, fenced code, display math, or block quote) is the block's lead-in: its last citation also covers the whole block, nested items included. Citations inside the block add to it for the parts they cover. Content that cannot carry a citation, such as fenced code or display math, is covered only by a lead-in.
- **Tables.** Each cell is a unit. A cell holding only citations, such as a Source column, covers its whole row. Header cells, and a row's first cell naming the row, are labels and take no citation. A cell holding only `[UNVERIFIED]` records a value the KB lacks: no citation covers it.
- **Text after the last citation** of its unit, with no Source cell or lead-in covering it, is covered by nothing.
- **Headings** are navigation, not units: no citation covers one and none takes a marker, so a heading states nothing its section's cited text does not.
- **Edits move coverage.** Inserting or appending text or a citation changes what the citations around it cover. After any edit, every piece of factual text is covered by citations that hold it, or marked per *Markers*: where a new citation splits text off from the citation after it, repeat that citation right after the split-off text wherever it still holds part of it.

```
V3's routing works as follows [v3: §"2.1 Routing"]:
- each token picks 8 of 256 routed experts
- one shared expert sees every token
```

Both items are covered by `[v3: §"2.1 Routing"]`.

```
Configs for the two models [v3: tbl.1] [moe: tbl.2]:

| Model | Experts      | Context       | Params |
| ----- | ------------ | ------------- | ------ |
| V3    | 256 [a: p.4] | 128K [b: p.2] | 671B   |
| MoE   | 64           | 4K            | 145B   |
```

`256` is checked against the lead-in's citations plus `[a: p.4]`, `128K` against the lead-in's plus `[b: p.2]`, and `671B` and the MoE row against the lead-in's alone. Without the lead-in, `671B` and the whole MoE row are covered by nothing. `[v3: tbl.1]` says nothing about MoE and `[moe: tbl.2]` nothing about V3, but each supports part of the block, so neither is irrelevant.

```
| Model      | Layers       | Attn heads  | Source      |
| ---------- | ------------ | ----------- | ----------- |
| Llama 3 8B | [UNVERIFIED] | 32 [x: p.3] |             |
| V3         | 61           | 128         | [v3: tbl.1] |
```

In the first row, `[x: p.3]` covers only `32`, and the layer count is a value the KB lacks. In the second, the Source cell covers `61` and `128`.

## What a citation must hold

- Everything a citation covers must be **stated by its sources, or follow directly from them**: a reader can check it against the cited places with simple reasoning. Text reached by several citations (its own, its row's Source cell, its block's lead-in) is checked against all of them together.
- **Keep the source's strength.** Never drop a hedge or condition, or widen a population, setup, time, comparison basis, or certainty: "can be missed" does not hold "goes missing". Words that make text exclusive, comparative, or causal (for example, "only", "the", "more than", "is what") are parts the sources must hold too, and so is a bold lead's conclusion.
- A claim about what a source says ("X reports Y") is grounded by citing that source, like any other factual claim.
- A citation holds what any place it names holds: an ambiguous locator names each place it matches, and an unresolved one names none.
- **Cite at the part.** Where parts of a sentence rest on different places, put each citation where its part ends: `about 250 words/min [a: p.3] or about 6 tokens/s [b: p.6]`. In a block, cite the cell or item.
- **Coverage defects**, which `kb-verify` reports without a marker: a citation covering no text; content that cannot carry a citation, with no lead-in. The fix moves the citation or gives the content a lead-in.

## Markers

Two inline markers flag text whose tie to its sources is missing or broken.

- **`[UNVERIFIED]`**: no citation covers this factual text. Likely fix: a repair citing a place in an `integrated` source that holds it; failing that, a new source, integrating a `candidate` that holds it, or a cleaner conversion.
- **`[DRIFTED]`**: a citation covering this text is wrong: the citations reaching it together do not state it and it does not follow from them, one of them contradicts it, or one of them is irrelevant. *Damaged content* says which content is not a place in the `.md`. Likely fix: a repair, per [distillation.md](./distillation.md)'s *Repair*, or a correction the user directs.
- **Relevance.** Each citation must speak to some part of the text it covers, agreeing or not: for a lead-in, its block; for a Source cell, its row. One whose place says nothing about any of it is **irrelevant**. A citation that speaks to another row of its block is not irrelevant to this one.
- **Placement.** A marker sits at the end of the sentence, list item, or table cell holding the failing claim, or of the lead-in covering content that cannot carry one, before any citation there. One marker per sentence, `[DRIFTED]` where both would apply. For an irrelevant citation, `[DRIFTED]` sits right before that citation.
- **Kind follows coverage.** Whoever changes what a citation covers, or finds a marker of the wrong kind, sets the kind the text's coverage now gives.
- **What takes a marker.** Factual text, claims about what a source says included, and a table cell recording a missing value. Navigation and statements about the KB itself ("see [[x]]", "this note covers") take none: a marker there is wrong and is removed. A sentence recording what a source omits is a [distillation.md](./distillation.md) rule 5 defect, fixed by rewriting it as a scoped positive claim. Its marker stays until that rewrite.
- **Who writes and clears.** `kb-verify` writes a marker where its audit finds a gap. `kb-integrate` writes one on a claim it writes but cannot ground, and wherever *Edits move coverage* calls for one. A marker is cleared only by grounding its text, in `kb-integrate`, or by a human.
- **Open markers.** A KB with open markers is not current; an open marker is a work item, not a defect.

## Keys and their status

An **orphan key** (an `integrated` entry cited nowhere) is registry hygiene, not a claim defect: `kb-verify` reports it but leaves no inline mark. Likely fix: cite it or prune it. A `candidate` cited nowhere is expected.

A `declined` entry must be cited nowhere at all: its files are deleted, so a surviving citation is a claim defect. Likely fix: re-ingest the source if the decline was wrong, otherwise repoint the claim.

## Stable keys

- One bib-style key per source (e.g. `[doe2024-sparsity]`), assigned at ingest.
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
| status | **required.** `candidate` (registered, not yet folded in), `integrated` (folded into `knowledge/`), or `declined` (reviewed and rejected). A decline carries the user's reason and the date in parentheses: `declined (superseded by roe2025-scaling, 2026-08-13)` |
| citing | **required.** Written by `kb-ingest`, once per conversion, and holding conversion fidelity only. Answers one question: *"what do I need to know before writing from this source?"* A lead line naming what was converted, then `locators:`, `checked:`, `damaged:`, and `quirks:` as indented sub-bullets. Shape and rules below |
| dropped | **required** on an `integrated` entry. **One dated value, source-wide**, recording what integration has not taken from this source: `<YYYY-MM-DD>: <item>; <why>. <item>; <why>.`, one sentence per item, dated by the last pass that rewrote it. `<YYYY-MM-DD>: nothing` once every part is taken. Only `kb-integrate` writes it: every pass that names the key rewrites it in place, and so does a repair that cites a part it lists, removing what the pass took and adding what it decided to leave. A part a later pass supersedes still counts as taken. A part is taken when a claim states it, not when a citation's span reaches it: a claim about a whole section, map, or file (`/`) takes what it states, such as the key set, not every part under it. A `candidate` or `declined` entry carries none. **Aim under 100 words**, each reason a short phrase: over that, coarsen the list to the enclosing section or group (`Appendices B-D`, `the remaining API metadata fields`), grouping only parts none of which was taken. **Never omit an item**: every part not taken is listed, individually or within a group. Wrapping it, never break a line just before a date |

An **earlier drop** is an item the previous value of `dropped` listed that a pass has now taken, and so removed. A pass reports each by key and item. Taking part of a grouped item splits the group, and the part taken is the earlier drop.

### What `citing` carries

**The schema is a lead line, then `locators:`, `checked:`, `damaged:`, and `quirks:`, in that order. Follow it strictly: nothing added, nothing dropped.** Each makes a different **kind** of statement. Write all of them **terse**: `locators:` and `checked:` are phrases, `damaged:` and `quirks:` the shortest sentences that carry a finding.

**The lead line** names what was converted: the form, its extent, and anything separating this conversion from what `origin` already names, such as an unpinned URL with the commit it was fetched at (Fetched from unpinned `main` at commit `<sha>`), or a `.md` assembled from several pages. A pinned version lives in `origin`, and what a locator reaches lives in `locators:`. **Capped at 25 words.**

- **`locators:`** capability. One mark per locator form the source's type has, in the grammar's order: `p`, `§"…"`, `fig`, `tbl`, `eq`, `quote`, `pointer`, each `✓` or `✗`. A structured source carries `pointer ✓` alone. A form the type lacks takes no mark, and nor does the bare `[key]` row. Judged from the source's form and a spot check, not from counts. Qualify a mark that holds only within a bound: `§"…" ✓ (all headings at ##)`.
- **`checked:`** inspection scope, machine-derived: the counts line `kb-ingest`'s converter printed and any `N HTML tables` term beneath it, pasted verbatim, then investigated. A structured source's is its leaf count, which pairs with nothing. Each caption count carries a total and a **distinct** count; the distinct one is what pairs against the objects, and a total far above it means duplicates or line-initial cross-references. A mismatch names where to look. Headings and HTML tables pair with nothing; a heading count far above comparable sources' points to noise headings. **Agreement is necessary, not sufficient:** a `.md` that lost Tables 7 and 8 still reports 8 tables against 8 captions.
- **`damaged:`** everything not to cite from the normalized `.md`, written `damaged (N):` with **N the count of distinct findings**. Each entry names the content and its location, or reads `throughout:` for content that runs through the whole document (`throughout: inline math flattens`). The converter's lost-equation count and its `caption gap:` line both seed this field, not `checked:`. **A printed gap is a lead and an absent line is unproven:** write a gap here only once the source shows that table or figure, or its caption, and the `.md` lacks it. **Capped at 30 words per finding**; never drop or merge findings to meet the cap. `damaged: none` when the check found nothing, with no count.
- **`quirks:`** how to read the normalized `.md`, never a reason not to cite. Name each kind of **noise heading**: a heading the conversion promoted that is not part of the source's own structure, such as page headers, run-in bold leads, and figure panel labels. **Capped at 50 words.** `quirks: none` when there are none.

Three cross-checks tie the four together:

- **Every `✗` in `locators:`, and every mark whose qualifier names something absent or unreachable, has a `damaged:` or `quirks:` entry saying why, per those fields.** A qualifier asserting that something does not resolve needs the same backing as an outright `✗`: `tbl ✓ (not 7, 8)` obliges a line saying where Tables 7 and 8 went. One describing what the form reaches, `§"…" ✓ (all headings at ##)`, needs none.
- **Locate every `damaged:` entry not written `throughout:` with a form that still works.** Object and location are different things: the lost equations sit behind `eq ✗`, so the entry locates them by section, `§"…" ✓`. Where no working form reaches the damage, say so.
- **What the `.md` cannot count stays out of `checked:`.** A lost equation leaves no trace of what it replaced, and pages leave no marker to count at all.

Two things stay out of all these fields:

- **No transcribed values.** A value recovered from a damaged table is a claim: it belongs in `knowledge/`.
- **No cross-source commentary.** That one source names another under a different title, or supersedes it, is knowledge about the subject and goes in the note that owns it.

### Entry shape

One `##` heading per key, the remaining fields as bullets in the table's order. The file carries no other headings:

```
## doe2024-sparsity

- **files:** `doe2024-sparsity.md`;
    `doe2024-sparsity.pdf` (https://arxiv.org/pdf/2404.00000v1);
    `artifacts/` (12 files)
- **origin:** https://arxiv.org/abs/2404.00000v1
- **title:** Activation Sparsity for Efficient Inference
- **authors:** …
- **retrieved:** 2026-08-07
- **type:** paper
- **status:** integrated
- **citing:** Born-digital 53-page PDF.
  - locators: p ✓ · §"…" ✓ (all headings at ##) · fig ✓ · tbl ✓ · eq ✗ ·
    quote ✓ (not across inline math)
  - checked: 8 tables, 8 captions (8 distinct) · 8 images, 8 resolve, 8 captions (8 distinct) ·
    30 headings
  - damaged (3): 9 display equations lost (§"2 Method", §"3.1 Scaling Laws"). Table 4 (p.15)
    row-labels collapsed, so rows 3 and 7 share a label; drops cols F and K. throughout:
    inline math flattens, so subscripts run together (`O L 2` for O(L²)).
  - quirks: Footnotes arrive inline, mid-paragraph, where the page broke.
- **dropped:** 2026-08-19: §6; related-work survey, no subject claims. Appendix C's ablation
    grid; superseded by the §4 table.
```

A structured source's `citing`, the same fields:

```
- **citing:** A 43-key Hugging Face `config.json`, normalized to one pointer line per leaf. Fetched from unpinned `main` at commit `e815299b0bcbac849fa540c768ef21845365c9eb`.
  - locators: pointer ✓
  - checked: 54 leaves
  - damaged: none
  - quirks: none
```

`kb-verify`'s check reads `## <key>` and the `- **<field>:** <value>` bullets under it, a value continuing onto an **indented** line as `files`, `citing`, and a long `dropped` do, with a blank line ending the value; so `citing`'s sub-bullets are indented. It parses `status`, `citing`, `dropped`, and `files`, resolving the last against `sources/<key>/` on disk. Written any other way, no key resolves and every citation in the KB reads as a defect.
