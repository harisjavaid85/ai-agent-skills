# AI Agent Skills

A collection of composable skills used by Claude Code, Codex, and other coding agents. Skills are organized into buckets and can consume per-repo configuration emitted by `/setup-repo-skills`.

## Language

**Issue tracker**:
GitHub Issues, the supported place where this workflow stores PRDs and implementation issues. Skills like `to-issues`, `to-prd`, and `triage` read from and write to it through the `gh` conventions in `docs/agents/issue-tracker.md`.
_Avoid_: backlog manager, backlog backend, issue host

**Issue**:
A single tracked unit of work inside an **Issue tracker** — a bug, task, PRD, or slice produced by `to-issues`.
_Avoid_: ticket (use only when quoting external systems that call them tickets)

**Triage role**:
A canonical state-machine label applied to an **Issue** during triage (e.g. `needs-triage`, `ready-for-agent`). Each role maps to a real label string in the **Issue tracker** via `docs/agents/triage-labels.md`.

**Issue category**:
The GitHub classification applied during triage: `bug` for broken behavior or `enhancement` for new functionality and improvements.

**Commit tag**:
A canonical category prefixing a commit subject, applied by `commit` (e.g. `Feature`, `Fix`). Each tag maps to the repo's actual tag string and subject format via `docs/agents/commit-tags.md`.

**Repo mode**:
The rigor posture `setup-repo-skills` assigns a repo — `prototype`, `standard`, or `production` — governing how much an agent tests, hardens error paths, and refactors.
_Avoid_: repo type, quality level

**Coding standard**:
A per-language binding to a named external style guide (e.g. Google Python Style Guide) plus this repo's deviations, that an agent follows when writing code. Emitted by `setup-repo-skills` and read by the producing agent; the guide, not the binding, holds the rules.
_Avoid_: style guide (the external source, not this repo's binding to it), linting rules

**Vocabulary** (of a skill):
The *nouns* a skill operates on — canonical term definitions, the fixed templates/formats it emits, label/tag mappings, file-format specs. Stable reference data (e.g. `commit-tags.md`, `CONTEXT-FORMAT.md`, a `SKILL.md` frontmatter template).
_Avoid_: glossary (too narrow — vocabulary includes templates and mappings, not just term definitions)

**Behaviour** (of a skill):
The *verbs* a skill performs — its process, decision rules, when-to-do-what, and the steps the agent executes (e.g. "gather requirements → draft → review", "offer ADRs only when all three are true").

**Progressive disclosure** (of a skill):
The structuring principle that `SKILL.md` is the always-loaded entry point holding **Behaviour**, while shared, independently reusable, or branch-specific reference material lives in linked files loaded on demand. Split by usage, never by line count alone; references stay one level deep.
_Avoid_: lazy loading, file splitting

## Relationships

- An **Issue tracker** holds many **Issues**
- A triaged **Issue** carries one **Issue category** and one **Triage role**
- A **Repo mode** and a **Coding standard** are orthogonal axes: mode sets rigor, standard sets convention

## Flagged ambiguities

- "backlog" was previously used to mean both the *tool* hosting issues and the *body of work* inside it — resolved: the tool is the **Issue tracker**; "backlog" is no longer used as a domain term.
- "backlog backend" / "backlog manager" — resolved: collapsed into **Issue tracker**.
