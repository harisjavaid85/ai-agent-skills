# Domain docs & knowledge

How the engineering skills read, and add to, this repo's domain documentation and knowledge base.

## What goes where

When you learn or decide something durable, route it — don't leave it in a session summary, agent memory, or the nearest open file. Match it to one home:

- a **term** or domain concept → the glossary (`CONTEXT.md`). Write it directly or via `/grill-with-context`, in that skill's format.
- a **decision and its tradeoffs** → an ADR (`docs/adr/`). Write it directly or via `/grill-with-context`, in that skill's format.
- **how the system behaves** — a gotcha or non-obvious invariant → the knowledge base (`KNOWLEDGE.md`); you write it (detailed below).
- a **rule for how the agent should work** → operational policy (`AGENTS.md` / `CLAUDE.md`); you write it, sparingly — it loads every session.
- a **purely local invariant** → a comment at the code.

**The boundaries are where classification goes wrong.** Each pair sits on one topic:

- _Term vs fact._ "An **Invoice** is a request for payment sent to a customer after delivery" defines vocabulary → glossary. "An invoice renders its VAT line only if the customer's country is set before the PDF job runs; set it after and the total is silently wrong" → knowledge.
- _Decision vs fact._ "Postgres backs the write model" records a choice and its tradeoffs → ADR. "The unique index on `(customer_id, idempotency_key)` is what stops a retried checkout double-charging; dropping it looks safe and isn't" → knowledge.
- _Rule vs fact._ "Deploy only from a green `main`" prescribes how to work → operational policy. "The deploy loads secrets at boot, so a rotated secret needs a pod restart — updating the secret store alone does nothing" → knowledge.
- _Local invariant vs fact._ "This loop assumes a non-empty batch" concerns one function → a comment at the code. "Fulfillment retries webhooks for 24h with backoff, so a handler that isn't idempotent double-ships" → knowledge.

The cut most easily missed is knowledge vs operational policy, and it is **register**: `KNOWLEDGE.md` _describes_ how the system behaves; operational policy _prescribes_ how the agent acts. One reality can throw off both — "webhooks retry for 24h with backoff" is a fact (knowledge); "make handlers idempotent" is a rule (policy) — but they are not duplicates, and a fact that also warrants a rule lives once in knowledge, and is referenced instead of being copied.

`CLAUDE.md` loads into every session, so keep it small — stable, global policy only. `CONTEXT.md`, `KNOWLEDGE.md`, and ADRs are distributed beside the code they describe and read only when that area is touched, so prefer them by default; even a prescriptive rule that bites in just one area belongs in that area's docs, not the always-loaded file.

Whatever you add, state it as what **is currently true**, keep the bar high (this is not a log of what you did), and note the addition in your summary so a human can review it.

## Before exploring, read these

- **`CONTEXT-MAP.md`** at the repo root, if it exists — the entry point for a multi-context repo. It indexes one `CONTEXT.md` per context; from it, read the root `CONTEXT.md` (repo-wide carrier terms) and each per-context `CONTEXT.md` relevant to your topic.
- **`CONTEXT.md`** at the repo root, when there is no `CONTEXT-MAP.md` — the single-context glossary.
- **`KNOWLEDGE.md`** — durable, learned facts about how the system behaves. Read a context's `KNOWLEDGE.md` beside its `CONTEXT.md`, and the root `KNOWLEDGE.md` for system-wide facts.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in (in multi-context repos, also each context's own `docs/adr/` beside its `CONTEXT.md`). If your output contradicts one, surface it rather than silently overriding — e.g. _"Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…"_.
- **`docs/out-of-scope/`** — records of rejected feature requests. Check before proposing work that may have been declined before.

If any of these don't exist, **proceed silently**. Don't flag their absence or suggest creating them upfront. They are created lazily — the glossary and ADRs by the producer skills (`/bootstrap-context`, `/grill-with-context`) as terms and decisions get resolved, and `KNOWLEDGE.md` as facts are learned.

Layout is self-describing on disk: a root `CONTEXT-MAP.md` means multi-context (a root `CONTEXT.md` may still exist alongside it for repo-wide carrier terms); a root `CONTEXT.md` with no map means single-context. (Canonical layout also in the `bootstrap-context` skill's `CONTEXT-FORMAT.md`.)

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

When your output names a domain concept (an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the glossary (the relevant context's `CONTEXT.md`). Don't drift to synonyms the glossary explicitly avoids. If the concept you need isn't there yet, that's a signal — either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/grill-with-context`).

## Knowledge base

A `KNOWLEDGE.md` holds durable, learned facts about how the system behaves — the gotchas and non-obvious invariants a future agent would otherwise waste time rediscovering. Each file is the behavioral companion to a `CONTEXT.md`, created lazily: the first fact makes the file. Facts are pruned when they stop being true.

**Where it goes — by scope.**

- system-wide → the root `KNOWLEDGE.md`, beside the root `CONTEXT.md`;
- specific to one context → that context's `KNOWLEDGE.md`, beside its `CONTEXT.md`.

If a fact spans contexts, file it under the one where you hit the symptom and cross-link the other. `CONTEXT-MAP.md` already routes to every context, so no separate index is needed.

**Format.** Mirror `CONTEXT.md`: a headed file whose entries are the facts. No frontmatter.

```markdown
# <Area> Knowledge

Durable facts about how <area> behaves. Vocabulary is in [`CONTEXT.md`](CONTEXT.md).

**<Short fact title>**:
<The fact, stated as what is true. Link the code, ADR, or glossary term it concerns.>
```
