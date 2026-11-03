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

It resolves what is mechanical: citations (each key, each locator's form, a section's heading, a pointer's line, a quote's line, and that a structured source is cited by pointer only) and the registry against `sources/` per the [citation contract](../kb-builder/reference/citation.md), and `[[note]]` links and the index against `knowledge/` per the [distillation contract](../kb-builder/reference/distillation.md).

Two things it can spot but not settle go to `FOR JUDGMENT`: a bare `[key]`, and an image link resolving to nothing with no such file stored anywhere under the key. Step 4 resolves both.

It prints a summary line, then whichever of `DEFECTS`, `FOR JUDGMENT`, and `HYGIENE` is non-empty, then always an `OPEN MARKERS` tally and the site of every marker it counted, then `all references resolve` when the three regions were empty. It exits non-zero on a `DEFECTS` entry alone.

This runs KB-wide whatever step 3's scope, being cheap. It finds; you judge in step 4. Done when the check has run and its output is in hand.

## 3. Check locators, mark drift

**Scope.** Given keys, check only the claims citing those keys. Given none, check the whole KB. Keep which, for step 5.

Read each key's `citing` first: `locators:` records which locator forms that conversion reaches, and `damaged:` what arrived mangled. Skip a claim citing a `declined` or unregistered key: step 2 already reports it.

For each cited claim in scope, confirm the locator still supports the claim, reading the artifact its form names: `§"…"`, `"quote"`, and a pointer resolve in `sources/<key>/<key>.md`, `p.` in the kept original, and `fig.`/`tbl.`/`eq.` in whichever holds it (the kept original, for damaged content), following the `.md`'s image link for a figure. Where the locator does not support the claim, or breaks the [citation contract](../kb-builder/reference/citation.md)'s *Damaged content* rule, mark the claim `[DRIFTED]` in place if it is a subject claim, per the contract's marker invariant. A claim about a source takes no marker: it is a defect, per step 4.

An unresolved locator supports nothing. One step 2 rejects for its form alone (malformed, ambiguous, or the wrong form for its source) is still read like any other: where a place it names supports the claim, the claim stays unmarked and the defect stands.

Done when every cited claim in scope is confirmed, marked `[DRIFTED]`, reported as a defect, or skipped.

## 4. Judge what the check surfaced

Step 2's output becomes findings only once classed, and the class decides which of step 5's two verdicts a finding bears on. Every line it printed routes as follows:

| What the check prints | You judge | Class |
| --- | --- | --- |
| `DEFECTS` | nothing, the check settled it | defect. For a dangling link, the fix is to repoint it or create the note; for a duplicate note name, to rename one |
| `FOR JUDGMENT`, bare `[key]` | is the claim thesis-level? | thesis-level: fine. Anything specific (number, result, quoted wording, figure): **defect**, and the fix is a locator |
| `FOR JUDGMENT`, unstored image link | does the entry's `citing` record that these figures were never fetched? | recorded: fine. Unrecorded: **defect**, and the fix is to fetch the figures with `curl` or record the omission |
| `OPEN MARKERS`, each site | subject claim or source claim, per the [citation contract](../kb-builder/reference/citation.md)'s marker invariant | subject: **open marker**; source: a false marker, which is a **defect** |
| `HYGIENE` | nothing, report it as it stands | hygiene. An index entry over the word cap marks an oversized note: the user trims the entry or runs `kb-integrate split <note>` |

**A broken locator can be both.** A `DEFECTS` line about a citation stays a defect until the citation is fixed, even where step 3 marked its claim `[DRIFTED]` as an open marker.

**Open markers are not defects.** They are what makes a KB **not current**, which is the golden rule working. But **the count you report is the check's tally minus the false markers**, which are defects instead. The check counts and locates markers without judging them, so its tally is a raw count and never the verdict.

**Defect or hygiene.** The check sorts its settled lines by one rule: a defect is anything a reader following a note's claims, citations, or links hits as wrong or broken; hygiene is everything else (form, bookkeeping, caps), and can wait. Hygiene never takes an inline mark.

**Four defects only step 3's read finds.** The check's output never names them:

- **A sentence recording what a source omits.** Judge it against the [distillation contract](../kb-builder/reference/distillation.md)'s rule 5, which carves out the two cases that only look like one.
- **A fact given its full account in two notes.** The check reports a note *name* declared twice, never a fact written twice. Judge it against that contract's rule 4. The fix for a re-derivation cuts it back to what the non-owner's sentence needs, never to a bare link.
- **A claim about a source its citation does not support**, or that breaks the *Damaged content* rule. The check may report the locator, never that the claim is about a source, which takes no marker. The fix repoints the citation, or rewrites the claim to what the source says.
- **A restatement out of step with its owner.** Where a claim in scope restates a claim another note owns, or draws a conclusion from one, open that note and compare. A bare `[[link]]` is no reason to. A disagreement is a defect: settle it against the sources, never against the owner's word.

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

Finally, report the findings led by the open-marker count: each defect and open marker with its fix, each claim step 3 marked `[DRIFTED]`, and each hygiene item with the repair it needs, such as the index entry to add.

Close with two independent verdicts: **current** (no open markers, so nothing in the KB is ungrounded) and **clean** (no defects and no hygiene). A KB is often one without the other; name whichever is missing and why. Name step 3's scope alongside them: a scoped pass checked locators, and could meet the four defects only step 3's read finds, in those keys' claims alone. Done when the re-check's findings are classed, the pass is recorded, and the report is given.
