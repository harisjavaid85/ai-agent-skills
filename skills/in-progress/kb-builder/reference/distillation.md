# Distillation contract

What a note may **say**: folding a source's insights into `knowledge/`, re-grounding open markers, and the topic map. Shared by `kb-integrate` (writing notes) and `kb-verify` (auditing them).

How a claim connects to its source, which covers citations, grounding markers, the registry schema, and the never-fabricate rule, is a separate question, governed by [citation.md](./citation.md).

1. **Integrate, don't summarize.** Fold each source's durable, load-bearing insights into existing notes: add a `[key: locator]`, deepen an explanation, or reconcile/supersede a prior claim. Never write a per-paper summary.
2. **Terse but self-sufficient.** Each insight stands alone: a reader at the KB's audience level understands it without opening the citation. Terse: no filler, no re-teaching what the audience already knows, but not cryptic pointers.
3. **Insight-first & audience-calibrated.** Lead with the takeaway. Calibrate depth to the KB's audience/expertise knob (declared in the KB's `AGENTS.md`): cite-don't-reteach what the reader knows, explain fully what they're learning.
4. **Prune, don't append duplicates.** Correct or supersede stale entries in place. Across notes, the topic note that owns the subject states the fact once; every other note names it with `[[note]]` and adds only what is true at that site. The same fact written in two notes is a defect, not redundancy, because the two copies drift.
5. **Scope every claim to what its source supports.** The KB records what its sources say, never what they omit: write the bound into the claim rather than the omission that implies it. Worked through under *Scoping a claim* below.

## Scoping a claim

**Wrong.** Records what the source omits:

```
The values are reported to transfer across batch size, model width, depth, and
token count [meta2025-llama4-blog: §"Pre-training"]. No mechanism is given [UNVERIFIED].
```

**Right.** Same information, as a scoped positive claim:

```
The values are reported to transfer across batch size, model width, depth, and
token count, for the configurations the blog names [meta2025-llama4-blog: §"Pre-training"].
```

Two things go wrong in the first version. The marker is false, because the claim about the blog is grounded and nothing there is unverified. And the sentence should not exist at all, because the KB records what sources say and not what they omit. The fix is neither a better marker nor a citation on the second sentence: it is one scoped claim, cited, with the bound written in.

**A bound on the subject is not an absence.** "The method does not address batch sizes above 4096" is a claim about the method, and takes a citation like any other. Rule 5 reaches only sentences about a **source**, so judge by what a sentence is about, never by its shape.

**A source's own limits are content.** The rule bans the KB inventing an absence, not a source stating one. Where a source **itself** says what it does not do ("we do not evaluate multilingual benchmarks", "the mechanism is left to future work"), that is something it says: take it as a scope qualifier with an ordinary citation when rule 1's durable-and-load-bearing test passes, and drop it like any other unused detail when that test fails.

## Where knowledge lives

Start coarse; subdivide under pressure.

- **Default:** one file per topic, `knowledge/<topic>.md`, with concepts as `##` sections that accrete across sources.
- **Subdivide** to `knowledge/<topic>/<concept>.md` only when a topic file outgrows a single read or sprouts several heavy concepts.
- After writing, update `knowledge/index.md` (the topic map, navigation only), creating it if absent, to list the topics, and the concepts once a topic is split. Every note is **listed** in it, flatly and directly; a note reachable only through another note is not listed and `kb-verify` reports it.
- **Cross-link** notes as `[[note-name]]`, the target's filename without `.md`, resolved inside `knowledge/`. `[[…]]` navigates within the KB; `[key: locator]` points out to a source.

## Note shape

Conclusion-first, minimal structure. A living note, not a filled-in form:

```
# <Topic>

<One to three sentences of orientation, pitched at the KB's audience.>

## <Concept>
<Conclusion first.> <Supporting detail> [key: p.7]. <Reconciliation with a prior claim> [other-key: §"Results"].
<Claim about the subject that no source grounds> [UNVERIFIED].

## See also
- [[related-topic]]
```

## Re-grounding

Integrating always ends in a re-ground: sweep the KB's open `[UNVERIFIED]` and `[DRIFTED]` markers, **including any this pass just wrote**, and re-attempt each.

First judge whether the marker belongs, against [citation.md](./citation.md)'s marker invariant. A false marker is not an open marker: rewrite that sentence per rule 5, or delete it, and never carry it forward.

Then re-attempt the ones that do belong:

- **`[UNVERIFIED]`.** Ground the claim against the sources now present. Clear the marker when a citation lands, leave it standing when none does.
- **`[DRIFTED]`.** The source did not change, the pointer did: relocate the locator **within the same source**, and clear the marker when it lands.
