# Distillation contract

What a note may **say**: folding a source's insights into `knowledge/`, repairing open markers, and the topic map's shape. How a claim connects to its source is [citation.md](./citation.md)'s question.

1. **Integrate, don't summarize.** Fold each source's durable, load-bearing insights into existing notes: add a `[key: locator]`, deepen an explanation, or reconcile/supersede a prior claim. Never write a per-paper summary.
2. **Terse but self-sufficient.** Each insight stands alone: a reader at the KB's audience level understands it without opening the citation. Terse: no filler, no re-teaching what the audience already knows, but not cryptic references.
3. **Insight-first & audience-calibrated.** Lead with the takeaway, covered by a citation whose sources state it or from which it directly follows, per [citation.md](./citation.md)'s *What a citation must hold*. Calibrate depth to the KB's audience/expertise knob (declared in the KB's `AGENTS.md`): cite-don't-reteach what the reader knows, explain fully what they're learning.
4. **Prune, don't append duplicates.** Correct or supersede stale claims in place, in every note that restates or relies on them, in any form: a value in other units, rounded, or folded into a derived figure; a mechanism or finding in other words; and any conclusion drawn from it. Across notes, the topic note that owns a subject gives its full account: the derivation, the complete detail, the evidence. Another note links it with `[[note]]` and keeps what its own sentences need to stand alone under rule 2: the numbers it uses, the mechanism in a clause, a defining quote, each with its source citation. The defect is a second full account, not a repeated number. Before cutting, read the sentence with the cut applied: if it no longer stands without opening the link, keep it.
5. **Scope every claim to what its source supports.** The KB records what its sources say, never what they omit: write the bound into the claim rather than the omission that implies it. Where accurately cited claims disagree, a scope (version, workload, setup, definition) that settles it is written into each claim, and a superseding source settles it under rule 4; where neither does, a **contradiction**, keep both, each scoped, for the reader to judge; never merge them into one claim that hides it. Worked through under *Scoping a claim* below.

## Scoping a claim

**Wrong.** Records what the source omits:

```
The values are reported to transfer across batch size, model width, depth, and
token count [acme2025-pretraining-blog: §"Pre-training"]. No mechanism is given [UNVERIFIED].
```

**Right.** Same information, as a scoped positive claim:

```
The values are reported to transfer across batch size, model width, depth, and
token count, for the configurations the blog names [acme2025-pretraining-blog: §"Pre-training"].
```

The first version's second sentence records an omission. The fix is neither a better marker nor a citation: it is one scoped claim, cited, with the bound written in.

**A bound on the subject is not an absence.** "The method does not address batch sizes above 4096" is a claim about the method, and takes a citation like any other. Rule 5 reaches only sentences about a **source**, so judge by what a sentence is about, never by its shape.

**A source's own limits are content.** The rule bans the KB inventing an absence, not a source stating one. Where a source **itself** says what it does not do ("we do not evaluate multilingual benchmarks", "the mechanism is left to future work"), that is something it says: take it as a scope qualifier with an ordinary citation when rule 1's durable-and-load-bearing test passes.

## Where knowledge lives

Start coarse; subdivide under pressure.

- **Default:** one file per topic, `knowledge/<topic>.md`, with concepts as `##` sections that accrete across sources.
- **Subdivide** to `knowledge/<topic>/<concept>.md` or sibling notes only when a topic file outgrows a single read or sprouts several heavy concepts, and only as a named `kb-integrate split <note>`.
- After writing, update `knowledge/index.md` (the topic map, navigation only), creating it if absent, per *The index* below.
- **Keep each note's filename unique** across `knowledge/`, folders included.
- **Cross-link** notes as `[[note-name]]`, the target's filename without `.md` or its folder, resolved inside `knowledge/`. `[[…]]` navigates within the KB; `[key: locator]` points out to a source.

## The index

`knowledge/index.md` holds scopes, never facts. Its vocabulary:

- A **group** is a `##` heading of the index that partitions the notes by area. Every note sits in exactly one group.
- An **index entry** is a note's line in the index, under the note's group, stating the note's scope.
- A **cross-cutting concept** is a line under `## Cross-cutting concepts` mapping each aspect of a concept to the notes that hold it.
- An **oversized note** is a note whose index entry runs over the cap. Trim the entry, or split the note per *Where knowledge lives*.

### Index entries

- Form: `- [[note]]: <scope>`. An entry may wrap; indented continuation lines belong to it.
- Every note is **listed** by exactly one index entry. A note reachable only through another note or a cross-cutting concept is unlisted, and `kb-verify` reports it.
- The scope names what the note covers: no measured values, named results, or comparative findings. Concept and release names stay (`6ND`, `FP8`, `GLM-5.3`).
- One phrase per content section (every `##` except `## See also`), naming the section's subject and nothing it found. Related sections may share a phrase (e.g. "prefill vs decode and append-prefill"). Every content section is named by some phrase.
- Cap: **40 words** of scope text, split on whitespace. Write the honest scope even when it runs over: the overrun marks an oversized note, which `kb-verify` reports.
- Edit an entry only when its note's scope changes: a section added, removed, or split. Claims added to an existing section leave the entry as it is.

A nine-section note, 29 words:

```
- [[llm-inference]]: prefill vs decode and serving metrics, append-prefill, why decode is
  bandwidth-bound, the serving formulas, the latency-throughput Pareto curve, the KV cache,
  sharding for inference, a worked serving example, node boundaries and topology.
```

### Cross-cutting concepts

- Form: `- <Concept>: <aspect> → [[note]]; <aspect> → [[note]], [[note]]`. Aspects are `;`-separated and hold no facts.
- A line exists only for a concept spanning three or more distinct notes.
- Every aspect names at least one `[[note]]`, and each note appears at most once per line.
- Update a line when a note gains or loses its concept; add one when a concept first reaches three notes.

## Note shape

Conclusion-first, minimal structure. A living note, not a filled-in form:

```
# <Topic>

<One to three sentences of orientation, pitched at the KB's audience, each factual one cited> [key: §"Intro"].

## <Concept>
<Takeaway first.> <Supporting fact> [key: p.7]. <Reconciliation with a prior claim> [other-key: §"Results"].
<Claim no citation covers> [UNVERIFIED].

## See also
- [[related-topic]]
```

## Repair

Run only by `kb-integrate repair`, on the open markers in its scope. It changes citations and markers, never claims.

1. **Read `citing` first.** For each key involved, read its `citing` entry before any place it cites, and cite damaged content from the kept original, per [citation.md](./citation.md)'s *Damaged content* rule.
2. **Wrong markers.** Remove a marker [citation.md](./citation.md)'s *Markers* does not put where it stands. A marker alone in a table cell records a missing value and stays.
3. **`[UNVERIFIED]`.** Cite a place in an `integrated` source, never a `candidate`, that states the text or from which it directly follows: repeat a nearby citation where it holds, or cite a new place. Clear the marker only when the text is held, per [citation.md](./citation.md)'s *What a citation must hold*.
4. **`[DRIFTED]`.** Cite a place in an `integrated` source that holds what the covering citations miss, beside them, or delete an irrelevant citation per step 6. Clear the marker only when the remaining citations together hold every part of the sentence and none of them is irrelevant.
5. **Never clear over contrary evidence.** Where any covering source contradicts the text, the marker stays, whatever agreeing citation is added beside it. Report the conflict for an edit the user directs.
6. **Delete or move a citation** while the text it covers stays only when it is irrelevant, per [citation.md](./citation.md)'s *Markers*. Changing a citation's locator, or moving it so earlier text loses its coverage, is a deletion. Removing or moving a claim with its citations is a correction the user directs, or a `split`.
7. **Keep coverage and marker kinds**, per [citation.md](./citation.md)'s *Edits move coverage* and *Kind follows coverage*.
8. **Never change a claim** to clear a marker. Rewording, rescoping, adding, and deleting claims, a missing fact or table value included, are edits the user directs.
9. **`dropped`.** Where a repair cites a part a key's `dropped` lists, rewrite that `dropped` per the `dropped` row of [citation.md](./citation.md)'s registry schema.
