# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT-MAP.md`** at the repo root, if it exists — the entry point for a multi-context repo. It indexes one `CONTEXT.md` per context; from it, read the root `CONTEXT.md` (repo-wide carrier terms) and each per-context `CONTEXT.md` relevant to your topic.
- **`CONTEXT.md`** at the repo root, when there is no `CONTEXT-MAP.md` — the single-context glossary.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. In multi-context repos, also check `src/<context>/docs/adr/` for context-scoped decisions.
- **`docs/out-of-scope/`** — records of rejected feature requests. Check before proposing work that may have been declined before.

If any of these don't exist, **proceed silently**. Don't flag their absence or suggest creating them upfront. The producer skills (`/bootstrap-context`, `/grill-with-context`, etc.) create them lazily as terms and decisions get resolved.

Layout is self-describing on disk: a root `CONTEXT-MAP.md` means multi-context (a root `CONTEXT.md` may still exist alongside it for repo-wide carrier terms); a root `CONTEXT.md` with no map means single-context. (Canonical layout also in the `bootstrap-context` skill's `CONTEXT-FORMAT.md`.)

```
single-context:
/
├── CONTEXT.md
├── docs/adr/
└── src/

multi-context:
/
├── CONTEXT-MAP.md
├── docs/adr/              ← system-wide decisions
└── src/
    └── <context>/
        ├── CONTEXT.md
        └── docs/adr/      ← context-scoped decisions
```

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the glossary (the relevant context's `CONTEXT.md`). Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/grill-with-context`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_
