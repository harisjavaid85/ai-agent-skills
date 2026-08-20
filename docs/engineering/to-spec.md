## What it does

`to-spec` turns the current conversation and your codebase understanding into a spec (you may know this document as a PRD), then publishes it as the parent artifact in your issue tracker. An optional lifecycle slug groups that spec with its implementation tickets on GitHub.

It does **not** interview you again. By the time you reach for it, the alignment work is done, and `to-spec` synthesises what is already known rather than asking a fresh round of questions.

## When to reach for it

You invoke this by typing `/to-spec`, and the agent won't reach for it on its own.

Reach for it once a change has been talked through and the domain language is settled, and you want that shared understanding written down before any code is written. If you *haven't* aligned yet, grill first. For that, use [grill-with-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/grill-with-context.md). To split the finished spec into tickets, use [to-tickets](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-tickets.md).

## Prerequisites

`to-spec` publishes into your issue tracker, so [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md) must have configured the tracker and labels for this repo first. On GitHub the published parent carries the `kind:spec` marker and no triage-state label, because `ready-for-agent` belongs to implementation tickets.

## What the spec includes

- **Problem statement**: what is broken or missing, and why it's worth solving, in the project's own vocabulary.
- **Solution**: the shape of the fix at a high level, before any implementation detail.
- **User stories**: an extensive, numbered list of the concrete behaviours the change must support, each one independently checkable.
- **Implementation decisions**: the choices already settled during the conversation, so they aren't relitigated later.
- **Testing decisions**: the seams the feature will be tested at, and what "done" looks like.
- **Out-of-scope items**: what this change deliberately does *not* cover, to keep the ticket bounded.
- **Further notes**: anything else worth carrying forward that doesn't fit the sections above.

## Lifecycle slug

Invoke `/to-spec` without a slug for an ungrouped parent spec, or pass a kebab-case slug to establish a GitHub lifecycle such as `spec:payments-redesign`. A slug identifies one parent spec across its whole lifetime and is shared by every ticket produced from it.

## Deep modules

Before writing the spec, `to-spec` sketches the **seams** at which the feature will be tested and looks for **deep module** opportunities: a lot of functionality hidden behind a small, stable interface. It prefers existing seams to new ones and the highest seam possible, ideally just one across the whole change.

That matters for agentic development: a good interface gives tests something durable to target, so the code underneath can change without the tests moving.

## It's working if

- It starts writing the spec instead of asking you a fresh round of questions.
- It checks the seams with you before writing, and proposes as few as possible.
- The spec comes back in your project's domain vocabulary, not generic boilerplate.
- A slugged GitHub spec carries one unique lifecycle label.

## Where it fits

`to-spec` is a step in the main build chain:

```txt
grill-with-context → to-spec → to-tickets → implement → commit → open-pr
```

Reach for it after the plan and domain language are resolved, and before you break the work into implementation tickets. Its key neighbours are [grill-with-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/grill-with-context.md), which sharpens the context so the spec is precise, and [to-tickets](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-tickets.md), which turns the spec into a set of tickets for [implement](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/implement.md) to build. When you're unsure which skill or flow fits, [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes you.
