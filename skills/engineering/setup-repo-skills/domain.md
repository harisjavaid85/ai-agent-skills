# Domain docs & knowledge

How the engineering skills read, and add to, this repo's domain documentation and knowledge base.

## What goes where

When you learn or decide something durable, route it rather than leaving it in a session summary, agent memory, or the nearest open file.

### 1. What kind of thing is it?

- a **term**, a word for a domain concept → the glossary (`CONTEXT.md`); you write it, in the format the `/domain-modeling` skill carries in its `CONTEXT-FORMAT.md`.
- a **decision** taken among real alternatives, and its tradeoffs → an ADR (`docs/adr/`); you write it, in the format the `/domain-modeling` skill carries in its `ADR-FORMAT.md`.
- a **rule** for how the agent should work → operational policy (`AGENTS.md` / `CLAUDE.md`); you write it, sparingly, because it loads every session.
- a **fact** about how the system behaves → step 2; you write it.

**The boundaries are where classification goes wrong.** Each pair sits on one topic:

- _Term vs fact._ "An **Invoice** is a request for payment sent to a customer after delivery" defines vocabulary → glossary. "An invoice renders its VAT line only if the customer's country is set before the PDF job runs; set it after and the total is silently wrong" → fact.
- _Decision vs fact._ "Postgres backs the write model" records a choice and its tradeoffs → ADR. "The unique index on `(customer_id, idempotency_key)` is what stops a retried checkout double-charging; dropping it looks safe and isn't" → fact.
- _Rule vs fact._ "Deploy only from a green `main`" prescribes how to work → operational policy. "The deploy loads secrets at boot, so a rotated secret needs a pod restart, and updating the secret store alone does nothing" → fact.

The cut most easily missed is fact vs rule, and it is **register**: a fact _describes_ how the system behaves; rule _prescribes_ how the agent acts. One reality can throw off both, since "webhooks retry for 24h with backoff" is a fact while "make handlers idempotent" is a rule, but they are not duplicates, and a fact that also warrants a rule lives once as a fact, and is referenced instead of being copied.

### 2. Where does a fact go, and does it earn its place?

**The code is the source of truth.** A written fact is a **cache** of it: a copy worth keeping only when the lookup it saves is expensive. Both answers follow from one question.

Find the fact's **arrival site**: the single declaration that every reader who needs this fact passes through, meaning the exported function, type, endpoint, or config key they land on.

- **It has one** → comment it there, on that declaration rather than on the line where you discovered it. A fact commented deep in an implementation file is accurate and unread, because the reader never opens that file. The lookup you save is reading the code in front of you, so the bar is whatever that code cannot say for itself; `docs/agents/coding-standards.md` holds the bar and the length budget. _"Construct this client before the event loop starts; a late bind attaches the socket to the wrong worker"_ goes on the client's constructor.
- **It has none**, because the readers who need it share no declaration → `KNOWLEDGE.md` (below). The lookup you save is discovery, so the bar is higher: keep the fact only if you learned it by running the system, or by following a behaviour through code that never states it. If reading the code would have shown it, the code already says it and the copy only waits to go stale. _"The deploy loads secrets at boot, so a rotated secret needs a pod restart"_ has no declaration to sit on.

Two readings of the same fact can differ, and the code decides which is right: where a facade gates every path to a behaviour, that facade is the arrival site, however many parts the behaviour spans; where the readers are handlers registered by convention with no shared declaration, there is nowhere to put it but `KNOWLEDGE.md`.

When a written fact and the code disagree, the code is what is true, and the change that invalidated the fact updates it in the same pass, because nothing else revisits them.

`CLAUDE.md` loads into every session, so keep it small: stable, global policy only. `CONTEXT.md`, `KNOWLEDGE.md`, and ADRs are distributed beside the code they describe and read only when that area is touched, so prefer them by default; even a prescriptive rule that bites in just one area belongs in that area's docs, not the always-loaded file.

Whatever you add, state it as what **is currently true**, and note the addition in your summary so a human can review it.

## Before exploring, read these

- **`CONTEXT-MAP.md`** at the repo root, if it exists: the entry point for a multi-context repo. It indexes one `CONTEXT.md` per context; from it, read the root `CONTEXT.md` (repo-wide carrier terms) and each per-context `CONTEXT.md` relevant to your topic.
- **`CONTEXT.md`** at the repo root, when there is no `CONTEXT-MAP.md`: the single-context glossary.
- **`KNOWLEDGE.md`**: durable, learned facts about how the system behaves. Read a context's `KNOWLEDGE.md` beside its `CONTEXT.md`, and the root `KNOWLEDGE.md` for system-wide facts.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in (in multi-context repos, also each context's own `docs/adr/` beside its `CONTEXT.md`). If your output contradicts one, surface it rather than silently overriding, e.g. _"Contradicts ADR-0007 (event-sourced orders), but worth reopening because…"_.
- **`.out-of-scope/`**: records of rejected feature requests. Check before proposing work that may have been declined before.

If any of these don't exist, **proceed silently**. Don't flag their absence or suggest creating them upfront. They are created lazily: the glossary and ADRs by the producer skills (`/domain-modeling`, `/bootstrap-context`, `/grill-with-context`) as terms and decisions get resolved, and `KNOWLEDGE.md` as facts are learned.

Layout is self-describing on disk: a root `CONTEXT-MAP.md` means multi-context (a root `CONTEXT.md` may still exist alongside it for repo-wide carrier terms); a root `CONTEXT.md` with no map means single-context. (Canonical layout also in the `/domain-modeling` skill's `CONTEXT-FORMAT.md`.)

```
single-context:
/
├── CONTEXT.md
├── KNOWLEDGE.md              ← learned facts
├── docs/adr/
└── <code>/                   ← wherever this repo keeps its code

multi-context:
/
├── CONTEXT-MAP.md
├── CONTEXT.md                ← repo-wide carrier vocabulary
├── KNOWLEDGE.md              ← system-wide learned facts
├── docs/adr/                 ← system-wide decisions
└── <context dir>/            ← wherever each context's code lives
    ├── CONTEXT.md
    ├── KNOWLEDGE.md          ← context-specific facts
    └── docs/adr/             ← context-scoped decisions
```

## Glossary

When your output names a domain concept (an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the glossary (the relevant context's `CONTEXT.md`). Don't drift to synonyms the glossary explicitly avoids. If the concept you need isn't there yet, that's a signal: either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/grill-with-context`).

## Knowledge base

A `KNOWLEDGE.md` holds durable, learned facts about how the system behaves: the gotchas and non-obvious invariants that have no arrival site to sit on. Each file is the behavioral companion to a `CONTEXT.md`, created lazily: the first fact makes the file.

**Where it goes: the nearest common home.**

A fact goes in the `KNOWLEDGE.md` beside the nearest ancestor `CONTEXT.md` that covers everything the fact touches: that context's own when it stays inside one context, the root's when it spans several.

`CONTEXT-MAP.md` already routes to every context, so no separate index is needed. A context whose facts all have arrival sites in code never grows a `KNOWLEDGE.md`, which is the file working as intended.

**Format.** Mirror `CONTEXT.md`: a headed file whose entries are the facts. No frontmatter.

```markdown
# <Area> Knowledge

Durable facts about how <area> behaves. Vocabulary is in [`CONTEXT.md`](CONTEXT.md).

**<Short fact title>**:
<The fact, stated as what is true. Link the code, ADR, or glossary term it concerns.>
```
