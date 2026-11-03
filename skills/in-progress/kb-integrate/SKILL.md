---
name: kb-integrate
description: "Fold a registered source's insights into a named file-based knowledge base as cited claims in its topic notes, and repair its open markers. Use when the user asks to integrate or fold a reviewed source into a specific KB, decline a candidate they have rejected, repair that KB's open markers, or split a note that has outgrown its index entry."
---

# KB Integrate

Make a registered source's insights part of the knowledge: fold into `knowledge/`, index, and repair open markers. Writes to the KB; never invents. Operates on keys `kb-ingest` has already registered, on notes for a split, and on open markers for a repair.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](../kb-builder/reference/registry.md). Done when you have its absolute root path.

## 2. Route by invocation

An invocation takes one of four shapes:

- **`<key>`**, optionally with a **must-take**: insights the user names as ones that must land, as one free-text list for the whole invocation. The rest is judged per distillation rule 1 as usual. Accept. → steps 3, 5, then 8.
- **`decline <key>: <reason>`.** Reject. → step 6, then 8.
- **`split <note>`.** Split an oversized note. → step 7, then 8.
- **`repair`**, optionally with a scope: none for every open marker in the KB, `uncommitted`, or `since <snapshot>`. → step 4, then 8.

With none of these, do nothing and list the four shapes.

Resolve each named key in `sources/index.md`, or the named note under `knowledge/`, first. Skip a named key that is not registered or whose files are missing, and report it with the reason; stop the run where keys were named and none resolves, or the named note does not exist, rather than working from nothing, and report per step 8. Done when every named key either resolves or is set aside for the report, and the path is chosen.

## 3. Integrate insights

Read each key's `citing` before writing from it. Never write to it: `kb-ingest` owns it.

**Write every claim drawing on damaged content from the kept original**, per the [citation contract](../kb-builder/reference/citation.md)'s *Damaged content* rule. **Also follow every located `damaged:` entry to its location**, whether or not a claim is written from it, and end each one of three ways:

- **The kept original settles the claim.** Write it from there, cited to the original.
- **It does not, or no original was kept.** Write the claim and mark it per the [citation contract](../kb-builder/reference/citation.md)'s *Markers*.
- **The content does not earn a claim** under distillation rule 1. Record it in `dropped` with its reason.

Fold each named source's insights into the topic notes under `knowledge/` per the [distillation contract](../kb-builder/reference/distillation.md) and the [citation contract](../kb-builder/reference/citation.md), grounding every claim you write per the latter's *Coverage*, *What a citation must hold*, and *Markers*: a claim you cannot ground takes its marker, and every edit keeps coverage per *Edits move coverage*.

Per distillation rule 4, a claim you correct or supersede is corrected in every note that restates or relies on it, in any form it takes. Start from the notes linking `[[<owner>]]` and the owner's cross-cutting lines in `knowledge/index.md`; at minimum, read every note naming the claim's subject or its value.

Land each must-take item even where distillation rule 1 would leave it out; every other rule still applies. Where the named sources cannot ground it, write nothing and report it as not found, with the reason, naming any key step 2 skipped as unread. Where a note already holds it from another source, cite this source at that claim, per the [citation contract](../kb-builder/reference/citation.md)'s *Coverage*.

Then, on each key integrated:

- Set `status: integrated`.
- **Rewrite** `dropped` in place, per the `dropped` row of the [citation contract](../kb-builder/reference/citation.md)'s registry schema.

Done when every claim this pass wrote is grounded or marked; every located `damaged:` entry ended in a citation, a marker, or a `dropped` item; each key reads `status: integrated` with a rewritten `dropped`; and every claim this pass corrected or superseded is corrected wherever it is restated or relied on, every note naming its subject or value read.

## 4. Repair open markers

**Scope.** Given none, every open marker in the KB: run [check_kb_references.py](../kb-verify/scripts/check_kb_references.py) for its `OPEN MARKERS` sites. Given `uncommitted`, or `since <snapshot>` (passed only by `kb-builder`), the open markers in the sections and new notes [kb_changes.py](../kb-verify/scripts/kb_changes.py) lists:

```bash
python3 <kb-verify>/scripts/kb_changes.py sections "<kb-root>" <snapshot | uncommitted>
```

Repair each per the [distillation contract](../kb-builder/reference/distillation.md)'s *Repair*. Done when every marker in scope is cleared, removed as not belonging, or left open with the reason, and every `dropped` listing a part a repair cited has been rewritten.

## 5. Update the index

Update `knowledge/index.md` per the [distillation contract](../kb-builder/reference/distillation.md)'s *The index*: an index entry for each note this pass created, and each index entry and cross-cutting line whose note this pass changed in scope. Record each note whose index entry runs over the cap as an oversized note for step 8.

Done when every note this pass created or changed in scope has exactly one index entry naming all of its content sections, and every cross-cutting line naming such a note follows the contract.

## 6. Decline a source

**Refuse to decline a key that any note cites.** Report the notes that cite it and stop.

Otherwise confirm before deleting: report the key, the files under `sources/<key>/` that will go, and the result of that cites-nowhere check, then ask.

On confirmation, two writes happen, and both must happen or neither:

1. Delete `sources/<key>/`: the normalized `.md`, the kept originals, and the figures.
2. Rewrite the registry entry to `declined`, in the shape the [citation contract](../kb-builder/reference/citation.md) gives that status, using the reason the user gave rather than your own judgment of the source, and **remove its `files` and `dropped` fields**.

`knowledge/` is untouched either way.

Done when the entry records the rejection and no file of that source remains, or the refusal is reported.

## 7. Split a note

Read the note and its index entry. Propose the split and ask:

- the new notes, and which `##` sections go to each,
- each new note's index entry and group,
- the cross-cutting lines that change,
- the notes whose `[[note]]` links will be repointed.

On confirmation:

1. Write the new notes, moving each section whole. Citations move with their claims unchanged. Rewrite each note's opening for that note, citing it like any paragraph per the [citation contract](../kb-builder/reference/citation.md)'s *Coverage*.
2. Repoint every `[[old-note]]` link whose concept moved, and remove the old note unless the split keeps its name.
3. Update the index per step 5: the new notes' index entries replace the old one.

Done when every moved section lives in exactly one new note, every rewritten opening is grounded or marked, no `[[link]]` points at a concept that moved away, and the index lists the new notes.

## 8. Report

List the notes changed, the keys integrated and what each `dropped`, each key step 2 skipped with its reason, each must-take item with the note it landed in or why it was not found, any earlier drop this run took, the keys declined with their reasons, and the markers written. For a repair, list the markers cleared, those removed as not belonging, those still open with the reason, and each citation deleted or moved with its source's reason. List each oversized note, to trim or split with `kb-integrate split <note>`, and for a split, the notes created and the links repointed. Say plainly that these writes are unaudited, and that verifying them is `kb-verify`'s job.

Done when the user can see what entered the knowledge, what was rejected, what was restructured, and what is still ungrounded.
