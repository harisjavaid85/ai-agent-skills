---
name: kb-expert
description: "Answer a question from a file-based knowledge base with cited claims, or summarize one of its registered sources. Use when the user asks what a KB says about a topic, or asks to summarize a source already registered in one."
---

# KB Expert

The read side of a KB: answer a question, or summarize one of its sources. Depth follows the request, terse and cross-topic for a question, whole-source for a summary, and both are pitched at the KB's audience knob (its `AGENTS.md`, per [registry.md](../kb-builder/reference/registry.md)). Reads `knowledge/` and `sources/`; **writes nothing**.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](../kb-builder/reference/registry.md). Done when you have its absolute root path.

## 2. Route by request shape

Two request shapes enter the KB by different doors:

- A **question** ("how does X work", "why does Y"). Enter via `knowledge/index.md`, the topic map. → §3.
- A **source-scoped summary** ("summarize the QSparse paper", "what does source X say"). Enter via `sources/index.md` to resolve the source to its key. → §4.

A request for *what the KB took from* a source ("what did we take from X") is a question scoped to that `[key]`: answer it via §3 from the notes that cite the key, which are the record of what was taken. The entry's `dropped` names what a pass **deliberately** left behind and cannot show what a pass simply missed, so give it as that record and never as a full account of what the source held. Done when you have chosen the door.

## 3. Answer a question

- Read `knowledge/index.md`, then open only the notes relevant to the question. If it is absent or empty, tell the user the KB has no knowledge yet.
- Give the takeaway first, concrete and quantitative, each claim carrying its citation.
- Where a relevant claim is marked `[UNVERIFIED]` or `[DRIFTED]`, say so rather than presenting it as established.
- Where the KB does not support an answer, say so: admit uncertainty rather than invent, per the [citation contract](../kb-builder/reference/citation.md).
- **"Do any of the sources address Y?" is not answerable from the KB.** It records what its sources say, not what they leave out, and it tracks no coverage. Answer from what the notes do contain, and say plainly that a topic missing from the notes is no evidence the sources miss it too.
- When the user asks for details or how a claim was derived, read that key's `citing` first, then drill into `sources/<key>/<key>.md`, and into the kept original or the figure file the `.md` links to for figures and tables. `citing` names what arrived mangled, so damaged content is read from the original rather than quoted from the `.md`.
- Where a cited key's entry reads `declined`, the citation is a defect and the source's files are gone: say so rather than reconstructing it from the notes.

Done when every claim in the answer carries its citation, every marked claim was flagged as marked, and any part of the question the notes do not reach was named as unanswered.

## 4. Summarize a source

- Resolve the named source to its key via `sources/index.md`. If the source is not registered at all, say so.
- Read the entry's `citing`, then its normalized text at `sources/<key>/<key>.md`. `citing` records what the conversion mangled, so nothing is claimed from a shredded table or a lost figure.
- Summarize faithfully: lead with the contribution, then method, results, and limitations as the source supports them.
- Cite into that one source (`[key: p.7]`, `[key: §"Results"]`) per the [citation contract](../kb-builder/reference/citation.md); never fabricate, and never import claims from other sources. Use the kept original, or the figure files the `.md` links to, for figures and tables.
- A `candidate` is a legitimate target, not an error. A `declined` entry is not: a decline deletes its files, so report the decline and the reason its entry carries rather than reconstructing the source from notes.

Done when every claim in the summary comes from that one source and cites it, with a locator on every specific claim, or the key's absence or decline is reported instead.
