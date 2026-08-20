---
name: bootstrap-context
description: Create or refresh a repository's domain-language glossary and context map in a single batched pass. Use when establishing the project's canonical terminology for the first time, or auditing it for drift, not for inline term-sharpening during design work.
disable-model-invocation: true
---

## Guiding principle

The audience is a human onboarding _and_ an agent loading context, and both should use the same domain language. Keep it a glossary, not a spec or operational handbook.

This is the **batched** mode of domain modeling: run once to establish `CONTEXT.md`, then occasionally to audit drift. The **inline** mode, challenging terms as they come up mid-session and updating the glossary the moment a term resolves, is the `/domain-modeling` skill, which other skills (`/grill-with-context`, `/triage`) use while they work. Formats are canonical there: [CONTEXT-FORMAT.md](../domain-modeling/CONTEXT-FORMAT.md) and [ADR-FORMAT.md](../domain-modeling/ADR-FORMAT.md).

## Terminology used in this skill

- **single-context** (one `CONTEXT.md` at root) / **multi-context** (`CONTEXT-MAP.md` at root + per-folder `CONTEXT.md`).
- **bootstrap mode** / **update mode**; branched on whether any context files already exist.

## Workflow

### 1. Survey

Read enough to know what already exists:

- Top-level tree (1–2 levels deep).
- Root `README*` and any subfolder `README*` files.
- Manifests: only to spot monorepo workspace boundaries.
- `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`.
- Any existing `CONTEXT.md` / `CONTEXT-MAP.md` / per-folder `CONTEXT.md`.

If no context files exist → **bootstrap mode**.
If any exist → **update mode**: diff against current repo state and list:

- **Missing**: modules with their own terminology but no per-folder `CONTEXT.md`; terms used in recent code/README files but absent from the glossary.
- **Stale**: terms whose referenced code is gone or renamed; cross-links that no longer resolve.
- **Drifted**: definitions that no longer match how the code uses the term.
- **Out of contract**: implementation details, operational rules, conventions, or gotchas that are not domain language.

Surface this list to the user before touching anything. Preserve out-of-contract content; classify each item per the taxonomy in [domain.md](../setup-repo-skills/domain.md) and always ask the user where each belongs, and never relocate or delete it automatically.

### 2. Choose layout

Ask the user: **single-context** or **multi-context**.

In update mode, default to the on-disk layout but offer to restructure it; if switched, migrate existing content.

### 3. Interview

Ask <5 questions covering what belongs in the glossary, prioritizing categories the Survey flagged as thin. In update mode, scope to those gaps. Prefer iterative follow-ups.

### 4. Write or update

Use [CONTEXT-FORMAT.md](../domain-modeling/CONTEXT-FORMAT.md). Omit empty sections.

**In update mode, edit in place**: only patch the missing / stale / drifted entries; leave the rest alone.

In **single-context**, write or patch `CONTEXT.md` at repo root.

In **multi-context**:

**Each term has exactly one home: the lowest common ancestor folder's `CONTEXT.md`.**

- Used in one folder → that folder's `CONTEXT.md`.
- Used in multiple folders → the nearest shared parent's `CONTEXT.md` (root if no closer ancestor).
