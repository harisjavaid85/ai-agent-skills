---
name: bootstrap-context
description: Bootstrap context for a repo focusing on terminology, invariants, and non-obvious agreements, resulting in a mental model which is meant to be read by both humans and AI agents. Use when the user asks to create an initial or update an existing context for a repo.
---

## Guiding principle

The audience is a human onboarding _and_ an agent loading context - both should walk away with the same mental model. Keep it a glossary, not a spec. If a single tool call or glance at the tree would reveal it, it doesn't belong.

### What to capture

- **Shared terminology** - terms this repo gives a specific meaning that differs from common usage, plus the aliases to avoid. E.g. "Order" means a placed customer order, not a sort order.
- **Cross-cutting invariants** - rules that hold everywhere, which other code is allowed to rely on without checking. E.g. "all timestamps are UTC".
- **Non-obvious agreements** - conventions not enforced by compiler/linter/CI but the team (humans and agents) follows. E.g. "never edit `vendor/`", "migration files are append-only once merged".
- **Recurring gotchas** - sharp edges people keep cutting themselves on. E.g. "the test DB resets between files but not between tests in the same file".

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

Surface this list to the user before touching anything.

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
