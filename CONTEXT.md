# AI Agent Skills

A collection of agent skills (slash commands and behaviors) loaded by Claude Code. Skills are organized into buckets and consumed by per-repo configuration emitted by `/setup-repo-skills`.

## Language

**Issue tracker**:
The tool that hosts a repo's issues — GitHub Issues, Linear, a local `.scratch/` markdown convention, or similar. Skills like `to-issues`, `to-prd`, `triage`, and `qa` read from and write to it.
_Avoid_: backlog manager, backlog backend, issue host

**Issue**:
A single tracked unit of work inside an **Issue tracker** — a bug, task, PRD, or slice produced by `to-issues`.
_Avoid_: ticket (use only when quoting external systems that call them tickets)

**Triage role**:
A canonical state-machine label applied to an **Issue** during triage (e.g. `needs-triage`, `ready-for-afk`). Each role maps to a real label string in the **Issue tracker** via `docs/agents/triage-labels.md`.

**Commit tag**:
A canonical category prefixing a commit subject, applied by `commit` (e.g. `Feature`, `Bugfix`). Each tag maps to the repo's actual tag string and subject format via `docs/agents/commit-tags.md`.

**Vocabulary** (of a skill):
The *nouns* a skill operates on — canonical term definitions, the fixed templates/formats it emits, label/tag mappings, file-format specs. Stable reference data (e.g. `commit-tags.md`, `CONTEXT-FORMAT.md`, a `SKILL.md` frontmatter template).
_Avoid_: glossary (too narrow — vocabulary includes templates and mappings, not just term definitions)

**Behaviour** (of a skill):
The *verbs* a skill performs — its process, decision rules, when-to-do-what, and the steps the agent executes (e.g. "gather requirements → draft → review", "offer ADRs only when all three are true").

**Progressive disclosure** (of a skill):
The structuring principle that `SKILL.md` is the always-loaded entry point holding **Behaviour**, while verbatim formats and long reference material (**Vocabulary**) live in linked files loaded on demand. References stay one level deep.
_Avoid_: lazy loading, file splitting

## Relationships

- An **Issue tracker** holds many **Issues**
- An **Issue** carries one **Triage role** at a time

## Flagged ambiguities

- "backlog" was previously used to mean both the *tool* hosting issues and the *body of work* inside it — resolved: the tool is the **Issue tracker**; "backlog" is no longer used as a domain term.
- "backlog backend" / "backlog manager" — resolved: collapsed into **Issue tracker**.
