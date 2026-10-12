---
name: kb-integrate
description: "Fold a registered source's insights into a named file-based knowledge base as cited claims in its topic notes, and re-ground its open markers. Use when the user asks to integrate or fold a reviewed source into a specific KB, decline a candidate they have rejected, re-ground that KB's open markers, or split a note that has outgrown its index entry."
---

# KB Integrate

Make a registered source's insights part of the knowledge: fold into `knowledge/`, re-ground, index. Writes to the KB; never invents. Operates on keys `kb-ingest` has already registered, and on notes for a split.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](../kb-builder/reference/registry.md). Done when you have its absolute root path.

## 2. Route by invocation

An invocation takes one of four shapes:

- **`<key>`**, optionally with a **must-take**: insights the user names as ones that must land, as one free-text list for the whole invocation. The rest is judged per distillation rule 1 as usual. Accept. → §3.
- **`decline <key>: <reason>`.** Reject. → §6.
- **`split <note>`.** Split an oversized note. → §7.
- **No key.** A re-ground sweep. It integrates no `candidate`: integrating one always requires naming it, so a later broad command cannot push a source still under review into `knowledge/`. → §4.

Resolve each named key in `sources/index.md`, or the named note under `knowledge/`, first. A key that is not registered or whose files are missing, or a note that does not exist, stops the run: say so rather than working from nothing. Done when every named key or note resolves and the path is chosen.

## 3. Integrate insights

Read each key's `citing` before writing from it: it records how the source was converted, and its `damaged:` field drives the pass below. Never write to `citing`: `kb-ingest` owns it.

**Follow every `damaged:` pointer.** It names the defect and where to find it. Each pointer ends one of three ways, and passing over one silently is not among them: nothing mechanical catches that, and the content the pointer stood in for is simply lost.

- **The kept original settles the claim.** Write it from there, cited to the original.
- **It does not, or the entry kept none.** Write the claim and mark it `[UNVERIFIED]`, which §4 re-attempts in this same run.
- **The content does not earn a claim** under distillation rule 1. Record it in `dropped` with its reason, so the skip is on the record rather than silent.

Fold each named source's insights into the topic notes under `knowledge/` per the [distillation contract](../kb-builder/reference/distillation.md) (note shape, its rules, scoping a claim) and [citation contract](../kb-builder/reference/citation.md) (citations, markers, registry schema).

Land each must-take item even where distillation rule 1 would leave it out; every other rule still applies. Where the named sources do not say it, write nothing and report it as not found, with the reason. Where a note already holds it from another source, add this source's citation to that claim.

Then, on each key integrated:

- Set `status: integrated`.
- **Rewrite** `dropped` in place, per the [citation contract](../kb-builder/reference/citation.md)'s registry schema.

Done when the touched notes carry their new citations, every `damaged:` pointer ended in a citation, a marker, or a `dropped` item, and each key reads `status: integrated` with a `dropped` that states what integration has not taken from the source.

## 4. Re-ground open markers

Run the re-ground sweep from the [distillation contract](../kb-builder/reference/distillation.md). It is KB-wide, and it includes the markers §3 just wrote, in this same invocation.

This is also where a false marker gets rewritten, which `kb-verify` can mark as a defect but never fix.

Where re-grounding a marker cites a part of a source whose `dropped` lists it, rewrite that key's `dropped` without it. Done when every open marker has been judged and, where it belongs, re-attempted, and every `dropped` listing a part it cited has been rewritten.

## 5. Update the index

Update `knowledge/index.md` per the [distillation contract](../kb-builder/reference/distillation.md)'s *The index*: an index entry for each note this pass created, and each index entry and cross-cutting line whose note this pass changed in scope. Record each note whose index entry runs over the cap as an oversized note for §8.

Done when every note under `knowledge/` has exactly one index entry, each touched note's index entry names all of its content sections, and every cross-cutting line follows the contract.

## 6. Decline a source

**Refuse to decline a key that any note cites**, which would strand a citation on a source whose files are gone. Report the notes that cite it and stop.

Otherwise confirm before deleting: report the key, the files under `sources/<key>/` that will go, and the result of that cites-nowhere check, then ask. No diff restores converted output and kept originals.

On confirmation, two writes happen, and both must happen or neither:

1. Delete `sources/<key>/`: the normalized `.md`, the kept originals, and the figures.
2. Rewrite the registry entry to `declined`, in the shape the [citation contract](../kb-builder/reference/citation.md) gives that status, using the reason the user gave rather than your own judgment of the source, and **remove its `files` and `dropped` fields**: a declined entry carries neither, and the check flags a `files` it still holds.

`knowledge/` is untouched either way: the refusal above has already established that nothing in it cites the key.

Done when the entry records the rejection and no file of that source remains, or the refusal is reported.

## 7. Split a note

Read the note and its index entry. Propose the split and ask:

- the new notes, and which `##` sections go to each,
- each new note's index entry and group,
- the cross-cutting lines that change,
- the notes whose `[[note]]` links will be repointed.

On confirmation:

1. Write the new notes, moving each section whole. Citations move with their claims unchanged.
2. Repoint every `[[old-note]]` link whose concept moved, and remove the old note unless the split keeps its name.
3. Update the index per §5: the new notes' index entries replace the old one.

Done when every moved section lives in exactly one new note, no `[[link]]` points at a concept that moved away, and the index lists the new notes.

## 8. Report

List the notes touched, the keys integrated and what each `dropped`, each must-take item with the note it landed in or why it was not found, any earlier drop this run took, the keys declined with their reasons, the markers cleared this run, the false ones rewritten, and those still open. List each oversized note, to trim or split with `kb-integrate split <note>`, and for a split, the notes created and the links repointed. Say plainly that these writes are unaudited, and that verifying them is `kb-verify`'s job.

Done when the user can see what entered the knowledge, what was rejected, what was restructured, and what is still ungrounded.
