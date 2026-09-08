---
name: kb-integrate
description: "Fold a registered source's insights into a named file-based knowledge base as cited claims in its topic notes, and re-ground its open markers. Use when the user asks to integrate or fold a reviewed source into a specific KB, decline a candidate they have rejected, or re-ground that KB's open markers."
---

# KB Integrate

Make a registered source's insights part of the knowledge: fold into `knowledge/`, re-ground, index. Writes to the KB; never invents. Operates on keys `kb-ingest` has already registered.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](../kb-builder/reference/registry.md). Done when you have its absolute root path.

## 2. Route by verdict

An invocation takes one of three shapes:

- **`<key>`**, optionally scoped to part of the source. Accept. → §3.
- **`decline <key>: <reason>`.** Reject. → §6.
- **No key.** A re-ground sweep. It integrates no `candidate`: integrating one always requires naming it, so a later broad command cannot push a source still under review into `knowledge/`. → §4.

Resolve each named key in `sources/index.md` first. A key that is not registered, or whose files are missing, stops the run: say so rather than integrating from nothing. Done when every named key resolves and the path is chosen.

## 3. Integrate insights

Read each key's `citing` before writing from it: it records how the source was converted, and its `damaged:` field drives the pass below. Never write to `citing`: `kb-ingest` owns it.

**Follow every `damaged:` pointer.** It names the defect and where to find it. Each pointer ends one of three ways, and passing over one silently is not among them: nothing mechanical catches that, and the content the pointer stood in for is simply lost.

- **The kept original settles the claim.** Write it from there, cited to the original.
- **It does not, or the entry kept none.** Write the claim and mark it `[UNVERIFIED]`, which §4 re-attempts in this same run.
- **The content does not earn a claim** under distillation rule 1. Record it in `dropped` with its reason, so the skip is on the record rather than silent.

Fold each named source's insights into the topic notes under `knowledge/` per the [distillation contract](../kb-builder/reference/distillation.md) (note shape, its rules, scoping a claim) and [citation contract](../kb-builder/reference/citation.md) (citations, markers, registry schema). Where the invocation named only part of a source, take only those parts.

Then, on each key integrated:

- Set `status: integrated`.
- **Append** one dated entry to `dropped`, in the citation contract's shape: what this pass deliberately left behind and why, or `nothing`.

Done when the touched notes carry their new citations, every `damaged:` pointer ended in a citation, a marker, or a `dropped` line, and each key's `status` and `dropped` record what this pass took.

## 4. Re-ground open markers

Run the re-ground sweep from the [distillation contract](../kb-builder/reference/distillation.md). It is KB-wide, and it includes the markers §3 just wrote, in this same invocation.

This is also where a false marker gets rewritten, which `kb-verify` can mark as a defect but never fix. Done when every open marker has been judged and, where it belongs, re-attempted.

## 5. Update the index

Update `knowledge/index.md` per the [distillation contract](../kb-builder/reference/distillation.md): every note under `knowledge/` is listed in it, including any this pass created. Done when the topic map lists them all.

## 6. Decline a source

**Refuse to decline a key that any note cites**, which would strand a citation on a source whose files are gone. Report the notes that cite it and stop.

Otherwise confirm before deleting: report the key, the files under `sources/<key>/` that will go, and the result of that cites-nowhere check, then ask. No diff restores converted output and kept originals.

On confirmation, two writes happen, and both must happen or neither:

1. Delete `sources/<key>/`: the normalized `.md`, the kept originals, and the figures.
2. Rewrite the registry entry to `declined`, in the shape the [citation contract](../kb-builder/reference/citation.md) gives that status, using the reason the user gave rather than your own judgment of the source, and **remove its `files` field**: a declined entry carries none, and the check flags one that does.

`knowledge/` is untouched either way: the refusal above has already established that nothing in it cites the key.

Done when the entry records the rejection and no file of that source remains, or the refusal is reported.

## 7. Report

List the notes touched, the keys integrated and what each `dropped`, the keys declined with their reasons, the markers cleared this run, the false ones rewritten, and those still open. Say plainly that these writes are unaudited, and that verifying them is `kb-verify`'s job.

Done when the user can see what entered the knowledge, what was rejected, and what is still ungrounded.
