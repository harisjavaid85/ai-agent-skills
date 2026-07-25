# AI Agent Skills

A collection of composable skills used by Claude Code, Codex, and other coding agents. Skills are organized into buckets and can consume per-repo configuration emitted by `/setup-repo-skills`.

## Language

**Issue tracker**:
The tool that hosts a repo's issues — GitHub Issues, Linear, a local `.scratch/` markdown convention, or similar. Skills like `to-tickets`, `to-spec`, and `triage` read from and write to it through the conventions in `docs/agents/issue-tracker.md`.
_Avoid_: backlog manager, backlog backend, issue host

**Ticket**:
A tracer-bullet implementation unit produced by `to-tickets`, published to the configured **Issue tracker**.

**Issue**:
A work item hosted by an **Issue tracker** — a bug, request, spec, task, or published ticket.

**Decision ticket**:
A `wayfinder` unit — a child **Issue** of a `wayfinder:map` holding a *question* whose resolution is a decision, not an implementation ticket. The **decision** qualifier is what keeps it distinct from an implementation ticket; `wayfinder` introduces the term, then uses "ticket".

**Lifecycle slug**:
A kebab-case identifier that groups one parent spec with its implementation tickets across their shared lifecycle.
_Avoid_: PRD slug

**Triage role**:
A canonical state-machine label applied to an **Issue** during triage (e.g. `needs-triage`, `ready-for-agent`). Each role maps to a real label string in the **Issue tracker** via `docs/agents/triage-labels.md`.

**Issue category**:
The tracker classification applied during triage: `bug` for broken behavior or `enhancement` for new functionality and improvements.

**Commit tag**:
A canonical category prefixing a commit subject, applied by `commit` (e.g. `Feature`, `Fix`). Each tag maps to the repo's actual tag string and subject format via `docs/agents/commit-tags.md`.

**Repo mode**:
The rigor posture `setup-repo-skills` assigns a repo — `prototype`, `standard`, or `production` — governing how much an agent tests, hardens error paths, and refactors.
_Avoid_: repo type, quality level

**Coding standard**:
A per-language binding to a named external style guide (e.g. Google Python Style Guide) plus this repo's deviations, that an agent follows when writing code. Emitted by `setup-repo-skills` and read by the producing agent; the guide, not the binding, holds the rules.
_Avoid_: style guide (the external source, not this repo's binding to it), linting rules

Skill-authoring terms (**steps**, **reference**, **progressive disclosure**, **leading word**, **completion criterion**) are defined in [`skills/productivity/writing-great-skills/GLOSSARY.md`](./skills/productivity/writing-great-skills/GLOSSARY.md), not here.

## Relationships

- An **Issue tracker** holds many **Issues**
- A **Ticket** is an **Issue** produced by `to-tickets`
- A triaged **Issue** carries one **Issue category** and one **Triage role** at a time
- A **Decision ticket** is an **Issue** (a child of a `wayfinder:map`)
- A **Lifecycle slug** groups one parent spec and its implementation **Tickets**
- A **Repo mode** and a **Coding standard** are orthogonal axes: mode sets rigor, standard sets convention

## Flagged ambiguities

- "backlog" was previously used to mean both the *tool* hosting issues and the *body of work* inside it — resolved: the tool is the **Issue tracker**; "backlog" is no longer used as a domain term.
- "backlog backend" / "backlog manager" — resolved: collapsed into **Issue tracker**.
