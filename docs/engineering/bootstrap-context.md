Quickstart:

```bash
npx skills add harisjavaid85/ai-agent-skills --skill=bootstrap-context
```

```bash
npx skills update bootstrap-context
```

[Source](https://github.com/harisjavaid85/ai-agent-skills/tree/main/skills/engineering/bootstrap-context)

## What it does

`bootstrap-context` builds — or refreshes — a repo's domain-language glossary (`CONTEXT.md`, plus a `CONTEXT-MAP.md` in multi-context repos) in one dedicated, batched pass. It surveys the repo, interviews you briefly, and writes the glossary in the canonical format.

Its defining constraint is the mode: this is the **batched** counterpart to inline term-sharpening. It exists for the two moments a repo needs the whole glossary at once — first establishment, and a periodic drift audit — not for capturing terms one at a time as design work happens.

## When to reach for it

You invoke this by typing `/bootstrap-context` — the agent won't reach for it on its own.

Reach for it when a repo has no `CONTEXT.md` yet, or when an existing one has drifted — terms referencing dead code, modules with their own jargon and no glossary entry. For sharpening a single term mid-conversation, that's [domain-modeling](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/domain-modeling.md) — usually driven for you by [grill-with-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/grill-with-context.md).

## The audit

In **update mode** the skill diffs the glossary against the current repo and surfaces four lists before touching anything: **missing** terms, **stale** references, **drifted** definitions, and **out-of-contract** content (implementation details and gotchas that were never glossary material). Out-of-contract items are preserved and classified with you — a decision becomes an ADR, a learned gotcha goes to `KNOWLEDGE.md` — never silently relocated or deleted.

In multi-context repos it enforces one placement rule: **each term has exactly one home — the lowest common ancestor folder's `CONTEXT.md`.**

## Where it fits

A **run-once** (then occasional) setup step: run it after [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md) on a new repo, and revisit it when the codebase's language has visibly drifted. Its inline counterpart [domain-modeling](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/domain-modeling.md) keeps the glossary current between audits. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
