# Domain Docs

How the engineering skills consume this repo's domain documentation when exploring the codebase and how to add to the knowledge base.

## Before exploring, read these

- **`CONTEXT-MAP.md`** at the repo root, if it exists — the entry point for a multi-context repo. It indexes one `CONTEXT.md` per context; from it, read the root `CONTEXT.md` (repo-wide carrier terms) and each per-context `CONTEXT.md` relevant to your topic.
- **`CONTEXT.md`** at the repo root, when there is no `CONTEXT-MAP.md` — the single-context glossary.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. In multi-context repos, also check each context's own `docs/adr/` (beside its `CONTEXT.md`) for context-scoped decisions.
- **`docs/out-of-scope/`** — records of rejected feature requests. Check before proposing work that may have been declined before.
- **`KNOWLEDGE.md`** — durable, learned facts (gotchas, non-obvious invariants) about how the system behaves, neither vocabulary nor decisions. Read a context's `KNOWLEDGE.md` beside its `CONTEXT.md`, and the root `KNOWLEDGE.md` for system-wide facts.

If any of these don't exist, **proceed silently**. Don't flag their absence or suggest creating them upfront. They are created lazily — the glossary and ADRs by the producer skills (`/bootstrap-context`, `/grill-with-context`, etc.) as terms and decisions get resolved, and `KNOWLEDGE.md` as facts are learned.

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

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the glossary (the relevant context's `CONTEXT.md`). Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/grill-with-context`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_

## Knowledge base

A `KNOWLEDGE.md` holds durable, learned facts about how the system behaves — the gotchas and non-obvious invariants a future agent would otherwise waste time rediscovering. Each file is the behavioral companion to a `CONTEXT.md`, created lazily: the first fact makes the file.

**Where it goes — by scope.** Place a fact where its grouping makes sense:

- system-wide → the root `KNOWLEDGE.md`, beside the root `CONTEXT.md`;
- specific to one context → that context's `KNOWLEDGE.md`, beside its `CONTEXT.md`.

If a fact spans contexts, file it under the one where you hit the symptom and cross-link the other. `CONTEXT-MAP.md` already routes to every context, so no separate index is needed.

**When to add one.** You learned something durable while working, and it is:

- not a term → that's the glossary (`CONTEXT.md`);
- not a decision → that's an ADR (`docs/adr/`);
- not a purely local invariant → that's a comment at the code.

If it's a behavioral fact worth finding _before_ opening the file it concerns, it belongs here. The bar is high — this is not a log of what you did. Every entry states what **is currently true**, and is pruned when it stops being true. Note any entry you add in your summary so a human can review it.

**Routing, by example.** Each pair sits on one topic; only the second half is a knowledge fact.

- _Term vs fact._ "An **Invoice** is a request for payment sent to a customer after delivery" defines vocabulary → glossary. "An invoice renders its VAT line only if the customer's country is set before the PDF job runs; set it after and the total is silently wrong" → knowledge.
- _Decision vs fact._ "Postgres backs the write model" records a choice and its tradeoffs → ADR. "The unique index on `(customer_id, idempotency_key)` is what stops a retried checkout double-charging; dropping it looks safe and isn't" → knowledge.
- _Local invariant vs fact._ "This loop assumes a non-empty batch" concerns one function → a comment at the code. "Fulfillment retries webhooks for 24h with backoff, so a handler that isn't idempotent double-ships" → knowledge.

**Format.** Mirror `CONTEXT.md`: a headed file whose entries are the facts. No frontmatter.

```markdown
# <Area> Knowledge

Durable facts about how <area> behaves. Vocabulary is in [`CONTEXT.md`](CONTEXT.md).

**<Short fact title>**:
<The fact, stated as what is true. Link the code, ADR, or glossary term it concerns.>
```
