---
name: kb-verify
description: "Audit a named file-based knowledge base for reference integrity, marking drifted claims inline and recording the pass. Use when the user asks to verify or fact-check a specific KB, or after integrating new sources into one."
---

# KB Verify

Audit a KB's references: citations against its sources, `[[note]]` links against its own notes. Marks drift inline and otherwise only reports; never alters or deletes a claim. Fixing is `kb-integrate`'s job and the human's.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](../kb-builder/reference/registry.md). Done when you have its absolute root path.

## 2. Resolve every reference

Run [check_kb_references.py](./scripts/check_kb_references.py) against the KB root:

```bash
python3 <kb-verify>/scripts/check_kb_references.py "<kb-root>"
```

It resolves what is mechanical: `[key]` and each entry's required fields against `sources/index.md` per the [citation contract](../kb-builder/reference/citation.md), each entry's `files` against `sources/<key>/` on disk, each source body's image links against that same directory, `[[note]]` links and index listing against `knowledge/` per the [distillation contract](../kb-builder/reference/distillation.md). It also reports an entry declared twice, where the later one silently wins, and a note name declared twice, where a `[[link]]` to it resolves to neither file in particular.

Two things it can spot but not settle go to `FOR JUDGMENT`: a bare `[key]`, and an image link resolving to nothing with no such file stored anywhere under the key. Step 4 resolves both.

It prints a summary line, then whichever of `DEFECTS`, `FOR JUDGMENT`, and `HYGIENE` is non-empty, then always an `OPEN MARKERS` tally and the site of every marker it counted, then `all references resolve` when the three regions were empty. It exits non-zero on a `DEFECTS` entry alone.

This runs KB-wide whatever step 3's scope, being cheap. It finds; you judge in step 4. Done when the check has run and its output is in hand.

## 3. Check locators, mark drift

**Scope.** Given keys, check only the claims citing those keys. Given none, check the whole KB. Keep which, for step 5.

Read each key's `citing` first: `locators:` records which locator forms that conversion supports, `damaged:` what arrived mangled. Where a locator fails on something `citing` already flagged, the citation never held rather than drifted: leave it unmarked and carry it to §4.

For each cited claim in scope, confirm the locator still supports the claim, reading the artifact its form names: `§"…"` and `"quote"` resolve in `sources/<key>/<key>.md`, `p.` in the kept original, and `fig.`/`tbl.`/`eq.` in whichever holds it, following the `.md`'s image link for a figure. Where the locator no longer supports the claim, mark it `[DRIFTED]` in place, per the [citation contract](../kb-builder/reference/citation.md).

Done when every cited claim in scope is confirmed, marked `[DRIFTED]`, or carried to §4 as one `citing` shows never held.

## 4. Judge what the check surfaced

Step 2's output becomes findings only once classed, and the class decides which of §5's two verdicts a finding bears on. Every line it printed routes as follows:

| What the check prints | You judge | Class |
| --- | --- | --- |
| `DEFECTS` | nothing, the check settled it | defect |
| `FOR JUDGMENT`, bare `[key]` | is the claim thesis-level? | thesis-level: fine. Anything specific (number, result, quote, figure): **defect**, and the fix is a locator |
| `FOR JUDGMENT`, unstored image link | does the entry's `citing` record that these figures were never fetched? | recorded: fine. Unrecorded: **defect**, and the fix is to fetch the figures or record the omission |
| `OPEN MARKERS`, each site | subject claim or source claim, per the [citation contract](../kb-builder/reference/citation.md)'s marker invariant | subject: **open marker**; source: a false marker, which is a **defect** |
| `HYGIENE` | nothing, report it as it stands | hygiene |

**Open markers are not defects.** They are what makes a KB **not current**, which is the golden rule working. But **the count you report is the check's tally minus the false markers**, which are defects instead. The check counts and locates markers without judging them, so its tally is a raw count and never the verdict.

**Hygiene** covers the registry's own consistency and the notes' navigation. It never takes an inline mark: grounding markers apply to claims, and neither a registry gap nor a broken link is an ungrounded claim.

**Three defects the check cannot see at all.** All turn up in step 3's read rather than in the check's output:

- **A claim miscited from a damaged conversion.** Where `citing`'s `locators:` marks that form `✗`, or its `damaged:` names the content the locator points into, the citation never held, so `[DRIFTED]` is the wrong mark and relocating within the `.md` is the wrong fix. The kept original is.
- **A sentence recording what a source omits.** Judge it against the [distillation contract](../kb-builder/reference/distillation.md)'s rule 5, which carves out the two cases that only look like one.
- **The same fact stated in two notes.** The check reports a note *name* declared twice, never a fact written twice. Judge it against that contract's rule 4.

**Prescribe every fix; apply none.** Rewriting a claim, rescoping one, and re-grounding a marker are all fixes, and step 3's `[DRIFTED]` mark is the only write this skill makes to a note. The prescriptions are for the user: a later `kb-integrate` finds work by reading the notes' markers, never by reading this report.

Done when every line the check printed, every marker site, and anything step 3's read turned up is classed as defect, open marker, or hygiene.

## 5. Re-check, log, and report

**Re-run the step 2 check where step 3 marked anything.** Its marks landed in the notes, so the re-run both tallies them and catches what they broke: a marker in the wrong place, or prose that now parses as a citation. Class any new finding per step 4; it belongs to this pass. Where step 3 marked nothing, the re-run can only reprint step 2: skip it, and say so in the report.

Then record the pass in `verification-log.md`, creating the file if absent. It holds exactly two lines, rewritten in place rather than appended to:

```
last-verified: <YYYY-MM-DD> (<scope>)
last-full-sweep: <YYYY-MM-DD>
```

`<scope>` names what step 3 checked: `whole KB`, or the keys. Every pass rewrites the first line. **Only an unscoped pass rewrites the second**, and a scoped pass leaves it exactly as it found it, writing `last-full-sweep: never` when it is the pass creating the file. Otherwise a file called `last-verified` answers with a fresh date earned by one key, and nothing records when the KB was last swept whole.

Finally, report the findings led by the open-marker count: each defect and open marker with its fix, each claim step 3 marked `[DRIFTED]`, and each hygiene item with the repair it needs, the note to repoint or the index entry to add.

Close with two independent verdicts: **current** (no open markers, so nothing in the KB is ungrounded) and **clean** (no defects and no hygiene). A KB is often one without the other; name whichever is missing and why. Name step 3's scope alongside them: a scoped pass checked locators, and could meet the three defects the check cannot see, in those keys' claims alone. Done when the re-check's findings are classed, the pass is recorded, and the report is given.
