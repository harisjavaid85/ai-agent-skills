---
name: kb-builder
description: "Build or update a file-based knowledge base from named sources in one pass, producing cited topic notes, a grounding audit, and a repair of open markers."
disable-model-invocation: true
---

# KB Builder

Orchestrate a KB update end to end: ingest, integrate, verify, repair.

Takes sources (URL, path, pasted text), already-registered keys, or a mix, optionally with a must-take, per `kb-integrate`'s step 2. Naming an already-registered key runs the rest of the pipeline over it. Given nothing, it skips steps 2 and 3: it audits the whole KB, repairs the sections that audit marked, and verifies the repair.

[reference/](./reference/) holds this family's shared contracts: [registry.md](./reference/registry.md) (which KB to operate on), [distillation.md](./reference/distillation.md) (what a note may say), [citation.md](./reference/citation.md) (how a claim cites its source).

**Steps 2 to 5 run in subagents**, dispatched with the Agent tool: each returns its report to this orchestrator instead of ending the run. Pass each dispatch the KB root, the sources or keys, the scope its step names, and a link to the contracts, and **nothing else**, except a reopen the user confirmed in step 2, and the user's must-take, verbatim, to step 3 only.

**Snapshots.** This orchestrator takes each snapshot its steps name, with [kb_changes.py](../kb-verify/scripts/kb_changes.py): `python3 <kb-verify>/scripts/kb_changes.py snapshot "<kb-root>"` prints the ID of a snapshot of the KB's `knowledge/` as on disk, uncommitted changes included.

## 1. Resolve the KB

Resolve which KB to operate on per [registry.md](./reference/registry.md). Done when you have its absolute root path.

## 2. Ingest

Dispatch a subagent that calls the Skill tool with "kb-ingest", passing the KB root and the named sources and keys.

Return contract: the keys ingested, the keys only refreshed, and the sources left out with their reasons, each reopen awaiting confirmation among them.

**Proceed to step 3 without pausing** on a `candidate`.

**One genuine stop:** a reopen awaiting confirmation. Put each to the user with its prior decline and reason, and wait; never answer it for them to keep the run moving. Dispatch a second ingest for the reopens they confirm, passing each key as confirmed by the user. Report each they refuse as skipped and carry on with the rest. Done when every named source has a key or, where skipped, a reason.

## 3. Integrate

Take `S1`. Dispatch a subagent that calls the Skill tool with "kb-integrate", passing the KB root, the keys step 2 ingested or refreshed, and any must-take items. Where the user named sources or keys and step 2 left none, skip to step 6 and report any must-take as not attempted.

Return contract: its step 8 report. Done when that report is in hand.

## 4. Verify

Take `S2`. Dispatch a subagent that calls the Skill tool with "kb-verify", passing `since S1`. Where the user named nothing, pass no scope, so `kb-verify` audits the whole KB.

Return contract: its step 5 report. Done when that report is in hand.

## 5. Repair

**Run this step when the scope it passes below holds an open marker, or one step 4 classed as not belonging.** Otherwise skip it and say so.

Take `S3`. Dispatch one subagent that calls the Skill tool twice, in order: first with "kb-integrate", passing `repair since S1`, or `repair since S2` where step 4 audited the whole KB; then, where the repair changed anything, with "kb-verify", passing `since S3`. Where it changed nothing, skip the verify half and say so.

**This step does not loop.** Its verify half reports; it never triggers a second repair.

Return contract: the integrate half's step 8 report and the verify half's step 5 report. Done when that report is in hand, or the step was skipped and the reason recorded.

## 6. Report

Give one combined summary of the ingest, integrate, verify, and repair results, led up front by the defects and open markers still outstanding, and whether the KB is current and clean. Distinguish the sources **converted now** from those **already registered and integrated now**. Name each key step 3 could not integrate, with its reason. Name any earlier drop steps 3 and 5 took, and any must-take item step 3 did not find or did not attempt. Name the scope each `kb-verify` run used: step 4's, and step 5's where its verify half ran.

**Report markers in five parts**: those step 4 wrote, those step 5's repair cleared or removed as not belonging, those step 5's repair left open, those its verify half wrote, and the check's KB-wide open-marker count.

Where step 3 skipped to this step, say that no audit ran, and give no verdict or marker counts.

Close on what is left: everything still standing is the user's, each open marker, defect, and hygiene item with the fix `kb-verify` prescribed, and each contradiction it listed for the reader.

This step writes nothing to `verification-log.md`; `kb-verify` owns it. Done when the user has that summary.
