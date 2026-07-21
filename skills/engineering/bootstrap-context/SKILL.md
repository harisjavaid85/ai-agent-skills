---
name: bootstrap-context
description: Create or update a repository's domain-language glossary and context map for humans and agents. Use when the user wants to establish, reconcile, or refresh the project's canonical terminology.
---

## Guiding principle

The audience is a human onboarding _and_ an agent loading context - both should use the same domain language. Keep it a glossary, not a spec or operational handbook.

### What to capture

- **Shared terminology** - domain terms this repo gives a specific meaning that differs from common usage, plus aliases to avoid. E.g. "Order" means a placed customer order, not a sort order.
- **Relationships** - how domain concepts and contexts relate, especially distinctions that prevent ambiguous language.
- **Flagged ambiguities** - overloaded or conflicting terms with an explicit canonical resolution.

Do not capture implementation details, operational invariants, coding conventions, agreements, or recurring gotchas in `CONTEXT.md`. Conventions and agreements belong in `AGENTS.md`, `CLAUDE.md`, or `README.md`; decisions in ADRs; gotchas and learned behavioral facts in a `KNOWLEDGE.md` beside the relevant `CONTEXT.md`.

## Terminology used in this skill

- **single-context** (one `CONTEXT.md` at root) / **multi-context** (`CONTEXT-MAP.md` at root + per-folder `CONTEXT.md`).
- **bootstrap mode** / **update mode**; branched on whether any context files already exist.

## Workflow

### 1. Survey

Read enough to know what already exists:

- Top-level tree (1-2 levels deep).
- Root `README*` and any subfolder `README*` files.
- Manifests - only to spot monorepo workspace boundaries.
- `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`.
- Any existing `CONTEXT.md` / `CONTEXT-MAP.md` / per-folder `CONTEXT.md`.

If no context files exist -> **bootstrap mode**.
If any exist -> **update mode**: diff against current repo state and list:

- **Missing**: modules with their own terminology but no per-folder `CONTEXT.md`; terms used in recent code/README files but absent from the glossary.
- **Stale**: terms whose referenced code is gone or renamed; cross-links that no longer resolve.
- **Drifted**: definitions that no longer match how the code uses the term.
- **Out of contract**: implementation details, operational rules, conventions, or gotchas that are not domain language.

Surface this list to the user before touching anything. Preserve out-of-contract content until the user chooses where it should move; never relocate or delete it automatically.

### 2. Choose layout

Ask the user: **single-context** or **multi-context**.

In update mode, default to the on-disk layout but offer to restructure it; if switched, migrate existing content.

### 3. Interview

Ask <5 questions covering [What to capture](#what-to-capture), prioritizing categories the Survey flagged as thin. In update mode, scope to those gaps. Prefer iterative follow-ups.

### 4. Write or update

Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md). Omit empty sections.

**In update mode, edit in place**: only patch the missing / stale / drifted entries; leave the rest alone.

In **single-context**, write or patch `CONTEXT.md` at repo root.

In **multi-context**:

**Each term has exactly one home: the lowest common ancestor folder's `CONTEXT.md`.**

- Used in one folder -> that folder's `CONTEXT.md`.
- Used in multiple folders -> the nearest shared parent's `CONTEXT.md` (root if no closer ancestor).
- If a per-folder file needs a term defined elsewhere, link to it (e.g. `see [Order](../CONTEXT.md#order)`) rather than redefining.

1. **Propose per-folder candidates.** A folder qualifies if it owns its own terminology - typically a distinct module (own manifest/README) with non-trivial activity. In update mode, only propose folders not already covered.
2. **Confirm the candidate list with the user.**
3. **Write or patch the files**:
   - `CONTEXT-MAP.md` at root - index + relationships only, no definitions.
   - root `CONTEXT.md` - repo-wide terminology.
   - per-folder `CONTEXT.md` - terminology used only in that folder.
4. **Deduplicate.** Scan all `CONTEXT.md` files for any term defined in two places. For each duplicate, promote to the lowest common ancestor `CONTEXT.md` and link from the others. If the ancestor file doesn't exist, ask the user: create one, or promote to root instead.
5. **Cross-link**: every per-folder `CONTEXT.md` links up to `CONTEXT-MAP.md`; `CONTEXT-MAP.md` links down to every per-folder `CONTEXT.md`.
