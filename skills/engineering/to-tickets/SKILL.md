---
name: to-tickets
description: Break a plan, spec, or the current conversation into a set of tracer-bullet tickets, each declaring its blocking edges, published to the configured tracker — edges as text in one file per ticket locally, or native blocking links on a real tracker. An optional lifecycle slug groups the tickets under their parent spec.
disable-model-invocation: true
---

# To Tickets

Break a plan, spec, or conversation into a set of **tickets** — tracer-bullet vertical slices, each declaring the tickets that **block** it.

The issue tracker and triage label vocabulary should have been provided to you — run `/setup-repo-skills` if not.

## Arguments

Invoke as `/to-tickets [source] [slug=<slug>]`.

- No arguments — use the current conversation.
- An issue number, URL, or path — use that artifact as the source.
- One bare kebab-case token — when the tracker config defines **Spec lifecycle operations**, treat it as a lifecycle slug and resolve its parent spec; otherwise treat it as a source path or reference.
- A source plus `slug=<slug>` — use the explicit source and group the published tickets under that lifecycle slug.

Lifecycle slugs are optional and affect only trackers whose config defines **Spec lifecycle operations**.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body and comments.

For a lifecycle slug, use the commands in the tracker config's **Spec lifecycle operations**:

1. A bare slug resolves the open parent spec carrying it. Continue only when exactly one parent matches. Report zero or multiple matches and stop rather than guessing.
2. When the source is a tracker issue, inspect its lifecycle labels. Inherit its slug when exactly one exists; continue without grouping when none exists; stop when several exist.
3. When both an inherited slug and `slug=<slug>` are present, they must match. A supplied slug without a labelled parent must match an existing lifecycle label exactly. `/to-spec` owns lifecycle-label creation.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests) — vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

</vertical-slice-rules>

Give each ticket its **blocking edges** — the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

When the source spec has numbered user stories, map every ticket to the story numbers it covers. A pure enabling or prefactoring ticket may map to `None`.

Draft acceptance criteria using the rules under **Acceptance criteria** below.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change — rename a column, retype a shared symbol — whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own ticket blocked by the expand, keeping CI green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a ticket blocked by every migrate batch. When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify ticket — green is promised only there.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work
- **Covers user stories**: source story numbers, only when the source has numbered stories

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct — does each ticket only depend on tickets that genuinely gate it?
- Should any tickets be merged or split further?

When numbered stories exist, calculate and report any uncovered story numbers. Publication remains blocked until every story is covered or the source spec is updated to remove it.

Iterate until the user approves the breakdown.

### 5. Publish the tickets to the configured tracker

Publish the approved tickets. **How** depends on the tracker `/setup-repo-skills` configured — the tickets are the same either way, only the shape of the blocking edges changes:

- **Local files** → write one file per ticket under `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first). Each file's "Blocked by" lists the numbers/titles it depends on. Use the per-ticket file template below — one ticket per file, never a single combined file.
- **A real issue tracker (GitHub, Linear, …)** → publish one issue per ticket in dependency order (blockers first) so each ticket's blocking edges can reference real identifiers. Use the platform's native blocking / sub-issue relationship where it has one, and omit the body's **Blocked by** section — the link is then the only record, and the tracker renders it. Where the platform has none, set each ticket's "Blocked by" to the blocking issues. Apply the `ready-for-agent` triage label unless instructed otherwise — the tickets are agent-grabbable by construction.
- **A tracker with Spec lifecycle operations, when a slug is in play** → also apply the lifecycle label to every published ticket.

Work the **frontier**: any ticket whose blockers are all done. For a purely linear chain that means top to bottom.

Do NOT close or modify any parent issue.

<local-ticket-template>

# <NN> — <Ticket title>

**What to build:** the end-to-end behaviour this ticket makes work, from the user's perspective — not a layer-by-layer implementation list.

**Blocked by:** the numbers/titles of the tickets that gate this one, or "None — can start immediately".

**Status:** ready-for-agent

## Covers user stories

<Source story numbers and a source reference when one exists. Omit this section when the source has no numbered stories. Use `None` for a pure enabling ticket.>

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

</local-ticket-template>

<issue-template>

## Parent

A reference to the parent issue on the tracker (if the source was an existing issue, otherwise omit this section).

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective — not layer-by-layer implementation.

## Covers user stories

<Source story numbers and a source reference when one exists. Omit this section when the source has no numbered stories. Use `None` for a pure enabling ticket.>

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by

<Only when the tracker has no native blocking relationship; where it has one, that link is the record and this section is a second place for the two to disagree. A reference to each blocking ticket, or "None — can start immediately".>

</issue-template>

### Acceptance criteria

Each criterion:

- Uses imperative voice.
- States an explicit, independently verifiable success condition.
- Names a stable symbol, command, endpoint, or interface when technical precision is useful.
- Describes the target without file paths or code snippets — they go stale fast.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.
