---
name: kb-expert
description: "Answer a question from a file-based knowledge base with cited claims, or summarize one of its registered sources. Use when the user asks what a KB says about a topic, or asks to summarize a source already registered in one."
---

# KB Expert

The read side of a KB: answer a question, or summarize one of its sources. Depth follows the request, terse and cross-topic for a question, whole-source for a summary, and both are pitched at the KB's audience knob (its `AGENTS.md`, per [registry.md](../kb-builder/reference/registry.md)). Reads `knowledge/` and `sources/`; **writes nothing**.

**Reading a source.** Read its entry's `citing` first, then `sources/<key>/<key>.md`, drilling into the kept original or the figure file the `.md` links to for figures and tables. Read damaged content per the [citation contract](../kb-builder/reference/citation.md)'s *Damaged content* rule. A `declined` entry's files are gone: report the decline and its reason rather than reconstructing the source from the notes, and treat a citation to it as a defect.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](../kb-builder/reference/registry.md). Done when you have its absolute root path.

## 2. Route by request shape

Two request shapes enter the KB by different doors:

- A **question** ("how does X work", "why does Y"). Enter via `knowledge/index.md`, the topic map. → step 3.
- A **source-scoped summary** ("summarize the sparsity paper", "what does source X say"). Enter via `sources/index.md` to resolve the source to its key. → step 4.

A request for *what the KB took from* a source ("what did we take from X") is a question scoped to that `[key]`: answer it via step 3 from the notes that cite the key. The entry's `dropped` names what integration **deliberately** did not take from the source. It cannot show what a pass simply missed, nor what a later pass superseded, so give it as that record and never as a full account of what the source held. Done when you have chosen the door.

## 3. Answer a question

- Read `knowledge/index.md` (shape per the [distillation contract](../kb-builder/reference/distillation.md)'s *The index*). If it is absent or empty, tell the user the KB has no knowledge yet.
- Pick the notes whose index entries' scopes match the question. For a question spanning several notes, find its cross-cutting concept and open each note named for the aspects asked about. Open those notes, and answer from them: the index holds scopes, never facts.
- Give the takeaway first, concrete and quantitative, each claim grounded per the [citation contract](../kb-builder/reference/citation.md)'s *What a citation must hold*: a fact with its citation, a locator wherever it is specific, and a conclusion with the citations it rests on.
- **Cite what you checked.** A claim a note states carries the citations the note gives it. A claim no note states as written, your own synthesis, comparison, or negative, is checked against each place you cite for it, read as above.
- Where a relevant claim is marked `[UNVERIFIED]` or `[DRIFTED]`, or rests on a marked claim, say so rather than presenting it as established.
- Where the KB does not establish an answer, say so rather than presenting a conclusion as established.
- Where the notes hold a contradiction, per the [distillation contract](../kb-builder/reference/distillation.md)'s rule 5, give both claims, each scoped, and leave the judgment to the user.
- **Scope a negative to what you read.** "The notes on X give no Y" can be checked; "no source compares X and Y" cannot, unless a place you read says so. So "Do any of the sources address Y?" is answered from what the notes contain, saying plainly that a topic missing from the notes is no evidence the sources miss it too.
- When the user asks for details or how a claim was derived, read each source its citation names, as above.

Done when every claim in the answer is grounded as above or flagged as marked, and any part of the question the notes do not reach was named as unanswered.

## 4. Summarize a source

- Resolve the named source to its key via `sources/index.md`. If the source is not registered at all, say so.
- Read the source as above.
- Summarize faithfully: lead with the source's main point, then cover its substance as the source itself organizes it.
- Cite into that one source (`[key: p.7]`, `[key: §"Results"]`, a pointer for a structured source) per the [citation contract](../kb-builder/reference/citation.md), never importing claims from other sources.
- A `candidate` is a legitimate target; a `declined` one is reported, as above.

Done when every claim in the summary comes from that one source and cites it, with a locator on every specific claim, or the key's absence or decline is reported instead.
