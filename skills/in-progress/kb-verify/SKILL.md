---
name: kb-verify
description: "Audit a named file-based knowledge base for grounding and reference integrity, marking gaps inline and recording the pass. Use when the user asks to verify or fact-check a specific KB, or after integrating new sources into one."
---

# KB Verify

Audit a KB's grounding: text against the citations covering it, citations against the places they name, `[[note]]` links against notes. Marks grounding gaps inline and otherwise only reports; never alters or deletes a claim.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](../kb-builder/reference/registry.md). Done when you have its absolute root path.

## 2. Resolve every reference

Run [check_kb_references.py](./scripts/check_kb_references.py) against the KB root, KB-wide whatever step 3's scope:

```bash
python3 <kb-verify>/scripts/check_kb_references.py "<kb-root>"
```

It resolves what is mechanical: citations and the registry against `sources/` per the [citation contract](../kb-builder/reference/citation.md), and `[[note]]` links and the index against `knowledge/` per the [distillation contract](../kb-builder/reference/distillation.md). A bare `[key]`, and an image link resolving to nothing with no such file stored under the key, go to `FOR JUDGMENT` for step 4.

It prints a summary line, then whichever of `DEFECTS`, `FOR JUDGMENT`, and `HYGIENE` is non-empty, then an `OPEN MARKERS` tally with the site of every marker. It exits non-zero on a `DEFECTS` entry alone. Done when its output is in hand.

## 3. Audit the text, mark grounding gaps

**Scope.** Given nothing, read every note. Given `uncommitted`, or `since <snapshot>` (passed only by `kb-builder`), list the changed sections with [kb_changes.py](./scripts/kb_changes.py):

```bash
python3 <kb-verify>/scripts/kb_changes.py sections "<kb-root>" <snapshot | uncommitted>
```

Read each `section` and `new-note` it lists, and, for each `citation-removed` or `citation-moved` line, the text that citation covered. Report each `deleted` note. Keep the scope for step 5.

Read each cited key's `citing` first: `locators:` records which locator forms that conversion reaches, and `damaged:` and `quirks:` how to read its `.md`. Skip text whose covering citations name a key step 2 reported as `declined` or as an `unresolved key`.

In scope, work out what each citation covers, per the [citation contract](../kb-builder/reference/citation.md)'s *Coverage*. Check each piece of factual text against all the citations reaching it, per *What a citation must hold*, and each citation for relevance, per *Markers*. Read each place a citation names, whatever step 2 said of its form: `§"…"`, `"quote"`, and a pointer in `sources/<key>/<key>.md`, `p.` in the kept original, and `fig.`/`tbl.`/`eq.` in whichever holds it, following the `.md`'s image link for a figure. Never search the sources for a receipt for uncovered text.

**Mark `[UNVERIFIED]` and `[DRIFTED]` in place** where that contract's *Markers* puts them, never beside a marker already in the sentence, item, or cell: where that marker's kind is wrong, set it per *Markers*. Note everything else the read finds for step 4.

Done when all factual text in scope is confirmed, marked, noted for step 4, or skipped.

## 4. Judge what the read and the check surfaced

Class every line step 2 printed, and every finding step 3 noted:

| What the check prints | You judge | Class |
| --- | --- | --- |
| `DEFECTS` | nothing, the check settled it | defect. For a dangling link, the fix is to repoint it or create the note; for a duplicate note name, to rename one |
| `FOR JUDGMENT`, bare `[key]` | is the text it covers, per the [citation contract](../kb-builder/reference/citation.md)'s *Coverage*, thesis-level? | thesis-level: fine. A specific claim, per that contract's *Citations are receipts*: **defect**, and the fix is a locator |
| `FOR JUDGMENT`, unstored image link | does the entry's `citing` record that these figures were never fetched? | recorded: fine. Unrecorded: **defect**, and the fix is to fetch the figures with `curl` or record the omission |
| `OPEN MARKERS`, each site in step 3's scope | does it belong, per the [citation contract](../kb-builder/reference/citation.md)'s *Markers*? | belongs: **open marker**; otherwise **hygiene**, and the fix removes it |
| `HYGIENE` | nothing, report it as it stands | hygiene. For an oversized note, per the distillation contract's *The index*, the user trims its entry or runs `kb-integrate split <note>` |

**The open-marker count** you report is the check's tally minus the markers this pass found do not belong.

**Defect or hygiene.** A defect is anything a reader following a note's claims, citations, or links hits as wrong or broken; hygiene is everything else (form, bookkeeping, caps). Hygiene never takes an inline mark.

**Defects only step 3's read finds:**

- **A sentence recording what a source omits**, judged against the [distillation contract](../kb-builder/reference/distillation.md)'s rule 5 and its two carve-outs.
- **A fact given its full account in two notes**, judged against that contract's rule 4.
- **A restatement out of step with its owner.** Where text in scope restates a claim another note owns, or draws a conclusion from one, open that note and compare; a bare `[[link]]` is no reason to. Settle a disagreement against the sources, never against the owner's word.
- **A coverage defect**, per the citation contract's *What a citation must hold*.
- **A heading stating more than its section's cited text**, per that contract's *Coverage*.
- **A synthesis hiding a contradiction**, per distillation rule 5. The fix restores both claims, each scoped.

**Disagreeing claims.** Where accurately cited claims disagree, judge them against distillation rule 5: a settling scope a claim does not state, or a superseded claim left standing, is a defect, fixed per rules 5 and 4; a **contradiction** is neither defect nor marker: list it for the reader.

**Prescribe every fix; apply none.** Step 3's marks are this skill's only writes to a note. `kb-integrate repair` repairs markers and removes the ones that do not belong; every other fix waits for an edit the user directs.

Done when every line the check printed, every marker site in scope, and every finding step 3 noted is classed as defect, open marker, hygiene, or contradiction.

## 5. Re-check, log, and report

**Re-run the step 2 check where step 3 marked anything**, and class each new finding per step 4: it belongs to this pass. Where step 3 marked nothing, skip the re-run and say so.

Then record the pass in `verification-log.md`, creating the file if absent. It holds exactly two lines, rewritten in place rather than appended to:

```
last-verified: <YYYY-MM-DD> (<scope>) at <commit>
last-full-sweep: <YYYY-MM-DD> at <commit>
```

`<scope>` is `whole KB`, `uncommitted`, or `since <snapshot>` with the snapshot ID shortened to 7 characters. `<commit>` is the short `HEAD` the pass started from: the pass read that commit plus any uncommitted changes then on disk. Every pass rewrites the first line. **Only a whole-KB pass rewrites the second**; any other pass leaves it exactly as it found it, writing `last-full-sweep: never` when it is the pass creating the file.

Finally, report the findings led by the open-marker count, and for a pass that read only changed sections, how many open markers sit in them: each defect and open marker with its fix, each place step 3 marked, each hygiene item with the repair it needs, such as the index entry to add, each contradiction, and each deleted note.

Close with two independent verdicts: **current** (no open markers KB-wide) and **clean** (no defects and no hygiene, whether found by step 2's KB-wide check or in what step 3 read); name whichever is missing and why. Name step 3's scope alongside them: a whole-KB pass read every note; any other pass read only its changed sections. Done when the re-check's findings are classed, the pass is recorded, and the report is given.
