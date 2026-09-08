---
name: kb-builder
description: "Build or update a file-based knowledge base from named sources in one pass, producing cited topic notes, an audit of their references, and a repair of what the audit finds."
disable-model-invocation: true
---

# KB Builder

Orchestrate a KB update end to end: ingest, integrate, verify, repair.

Takes sources (URL, path, pasted text), already-registered keys, or a mix. Naming a key you ingested earlier runs the rest of the pipeline over it without re-converting it. Re-running the whole thing is safe: no source is converted twice and no claim is written twice.

[reference/](./reference/) holds this family's shared contracts: [registry.md](./reference/registry.md) (which KB to operate on), [distillation.md](./reference/distillation.md) (what a note may say), [citation.md](./reference/citation.md) (how a claim cites its source).

**Steps 3 to 5 run in subagents**, dispatched with the Agent tool for context isolation: this orchestrator holds the conversion transcript, and an agent inheriting it distills from memory rather than from disk. Pass each dispatch the KB root, the keys, and a pointer to the contracts, and **nothing else**. What an earlier step learned reaches a later one through the files: an entry's `citing`, and the markers a pass leaves standing in the notes.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](./reference/registry.md). Done when you have its absolute root path.

## 2. Ingest

Call the Skill tool with "kb-ingest", passing the named sources and keys. A key already registered is refreshed, not re-converted.

**Proceed to step 3 without pausing.** A `candidate` is a pipeline state here, not a review gate: a user who wants to review each source before it lands runs `kb-ingest` and `kb-integrate` separately instead of this skill.

**One genuine stop:** `kb-ingest` asks before reopening a `declined` key, since reopening re-converts a source the user rejected. Put that question to the user and wait; never answer it for them to keep the run moving. Where they decline the reopen, report that key as skipped and carry on with the rest. Done when every named source has a key, and every skipped source has a reason.

## 3. Integrate

Dispatch a subagent that calls the Skill tool with "kb-integrate", passing the KB root and step 2's keys.

Return contract: **the keys it integrated**, which scope step 4, and any key it could not integrate, with the reason. Its markers need no report: step 4 counts every marker in the KB. Done when that report is in hand.

## 4. Verify

Dispatch a subagent that calls the Skill tool with "kb-verify", **naming the keys step 3 integrated**, so its locator check covers what this run touched.

Where step 3 integrated nothing, name no keys: `kb-verify` sweeps the whole KB instead, a broader pass than the scoped one.

Return contract: the defects **with the fixes it prescribed**, the open-marker count **after** judgment, the hygiene items, the claims it marked `[DRIFTED]`, and the scope it ran with. Done when that report is in hand.

## 5. Repair

**Skip this step when step 4 reported no open marker and no false marker**, and say it was skipped, or step 6 cannot tell "repaired and re-verified" from "nothing to repair".

Otherwise dispatch one subagent that runs both halves in order: `kb-integrate` **with no key**, then `kb-verify` with **step 4's scope**. Where the integrate half reports it cleared nothing, skip the verify half and say so.

**Keyless is the repair.** With no key `kb-integrate` runs the re-ground sweep alone, which is the whole of what it repairs unprompted: every open marker re-judged, every false one rewritten. Naming keys instead re-folds sources step 3 just folded, and appends a second `dropped` line under the same date.

**This step does not loop.** Its verify half reports; it never triggers a second repair.

Return contract: from the integrate half, the markers cleared and the false markers rewritten; from the verify half, its findings and its two verdicts. Done when that report is in hand, or the step was skipped and the reason recorded.

## 6. Report

Give one combined summary of the ingest, integrate, verify, and repair results, led up front by the defects and open markers still outstanding, and whether the KB is current and clean. Distinguish the sources **converted now** from those **already registered and integrated now**, or a re-pass reads as if it did work it skipped. Name the scope `kb-verify` ran with, this run's keys or the whole KB.

**Report markers in three parts**: step 4's count after judgment, those step 5 cleared, and those still open. A single final count is attributable to none of them.

Close on what is left and whose move it is. Step 5 made the one repair `kb-integrate` makes unprompted, so everything still standing is the user's, given with the fix `kb-verify` prescribed: an open marker needing a new source or a cleaner conversion, and every finding that leaves no marker for a later pass to find, a mis-scoped claim, a fact written in two notes, a specific claim citing a bare `[key]`, and each hygiene item.

Then tell the user to commit, per [registry.md](./reference/registry.md): this run wrote, and the KB's diff is the only review those writes get.

This step writes nothing to `verification-log.md`; `kb-verify` owns it. Done when the user has that summary.
