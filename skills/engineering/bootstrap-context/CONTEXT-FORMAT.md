# File structure

Most repos have a single context — one `CONTEXT.md` at the root:

```
/
├── CONTEXT.md
├── KNOWLEDGE.md                      ← learned facts
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── <code>/                           ← wherever this repo keeps its code
```

Multi-context repos add a `CONTEXT-MAP.md` at the root; each context owns its `CONTEXT.md` and optionally its own `docs/adr/`. A root `CONTEXT.md` may sit alongside the map for repo-wide carrier vocabulary:

```
/
├── CONTEXT-MAP.md
├── CONTEXT.md                        ← repo-wide carrier vocabulary
├── KNOWLEDGE.md                      ← system-wide learned facts
├── docs/
│   └── adr/                          ← system-wide decisions
└── <context dir>/                    ← wherever each context's code lives
    ├── CONTEXT.md
    ├── KNOWLEDGE.md                  ← context-specific facts
    └── docs/adr/                     ← context-scoped decisions
```

# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Domain language only.** Operational invariants, coding conventions, implementation details, and agreements belong in other documentation; recurring gotchas and learned behavioral facts belong in `KNOWLEDGE.md`.
- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others as aliases to avoid.
- **Flag conflicts explicitly.** If a term is used ambiguously, call it out in "Flagged ambiguities" with a clear resolution.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Show relationships.** Use bold term names and express cardinality where obvious.
- **Only include terms specific to this project's context.** General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them extensively. Before adding a term, ask: is this a concept unique to this context, or a general programming concept? Only the former belongs.
- **Group terms under subheadings** when natural clusters emerge. If all terms belong to a single cohesive area, a flat list is fine.
- **Write an example dialogue.** A conversation between a dev and a domain expert that demonstrates how the terms interact naturally and clarifies boundaries between related concepts.

# CONTEXT-MAP.md Format (multi-context repos)

```md
# Context Map

## Contexts

- [Ordering](./ordering/CONTEXT.md) – receives and tracks customer orders
- [Billing](./billing/CONTEXT.md) – generates invoices and processes payments
- [Fulfillment](./fulfillment/CONTEXT.md) – manages warehouse picking and shipping

## Relationships

- **Ordering -> Fulfillment**: Ordering emits `OrderPlaced` events; Fulfillment consumes them to start picking
- **Fulfillment -> Billing**: Fulfillment emits `ShipmentDispatched` events; Billing consumes them to generate invoices
- **Ordering <-> Billing**: Shared types for `CustomerId` and `Money`
```
