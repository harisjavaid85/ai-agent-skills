---
created: 2026-05-29
generated-by: zoom-out skill
---

# Repo Overview

## What it is

This is **a library of agent skills** — not an application. It's a fork of Matt Pocock's "Skills For Real Engineers." Each skill is a folder containing a `SKILL.md` (a slash command + behavior instructions) that Claude Code loads. There's no runtime code to speak of; the "product" is the prompts/workflows themselves, distributed via the `skills.sh` installer and a Claude Code plugin manifest (`.claude-plugin/plugin.json`).

The whole thing exists to fix four recurring agent failure modes (from the README's thesis):

1. **Agent didn't do what I want** → grilling skills force alignment up front
2. **Agent too verbose** → a shared domain language (`CONTEXT.md`) cuts jargon
3. **Code doesn't work** → feedback-loop skills (TDD, diagnosis)
4. **Built a ball of mud** → design-aware skills (architecture, PRD, zoom-out)

## How it's organized

Skills live under `skills/` in **buckets** that signal maturity/promotion status (the repo's core organizing concept, enforced by `CLAUDE.md`):

| Bucket          | Meaning                        | In README + plugin.json? |
| --------------- | ------------------------------ | ------------------------ |
| `engineering/`  | daily code work                | yes (required)           |
| `productivity/` | daily non-code workflow        | yes (required)           |
| `misc/`         | kept but rarely used           | yes (required)           |
| `personal/`     | tied to the author's own setup | no                       |
| `in-progress/`  | drafts not ready to ship       | no                       |
| `deprecated/`   | retired                        | no                       |

The promotion rule is the invariant the repo cares most about: a skill in the first three buckets **must** be referenced in the top-level `README.md` and `.claude-plugin/plugin.json`; a skill in the last three **must not** appear in either. `scripts/list-skills.sh` and `link-skills.sh` support managing this.

## The domain vocabulary (from `CONTEXT.md`)

The skills coordinate around two groups of terms.

**Coordination terms** (how skills hand work to each other):

- **Issue tracker** — GitHub Issues, where this workflow stores PRDs and implementation issues
- **Issue** — one tracked unit of work
- **Issue category** — the GitHub `bug` or `enhancement` classification applied during triage
- **Triage role** — a state-machine label on an Issue (e.g. `needs-triage`, `ready-for-agent`), mapped to real labels via `docs/agents/triage-labels.md`
- **Commit tag** — a canonical category prefixing a commit subject, applied by `commit`

**Skill-authoring terms** (how a skill is structured):

- **Vocabulary** — the _nouns_ a skill operates on: term definitions, templates, mappings, format specs
- **Behaviour** — the _verbs_ a skill performs: its process, decision rules, and steps

## How the engineering skills fit together (a workflow)

The engineering bucket is roughly a development lifecycle:

```
setup-repo-skills   → run ONCE per repo; writes docs/agents/ config the others read
        │
bootstrap-context   → run ONCE per repo; build CONTEXT.md (shared language) + ADRs
        │
grill-with-context  → align on a change, sharpening terms against CONTEXT.md
        │
prototype           → (if needed) flesh out a design with a throwaway build before committing
        │
to-prd → to-issues  → turn the discussion into a PRD, then sliced GitHub issues
        │
triage              → move issues through triage roles
        │
tdd / diagnose      → implement & debug with tight feedback loops
        │
commit              → group changes into a sensible commit plan, [Tag]-prefixed messages
        │
zoom-out / improve-codebase-architecture  → keep the design clean over time
```

`setup-repo-skills` is the keystone: it emits the per-repo `docs/agents/` config (GitHub workflow, triage-role labels, commit tags, and domain-doc rules) that the other skills consume, and provisions missing required GitHub labels. It is required for the GitHub lifecycle skills and strongly recommended for other engineering workflows.

## Where the meta-work happens

This repo is also self-documenting about its _own_ design decisions:

- `docs/adr/` — Architecture Decision Records (e.g. ADR-0003 "semantic vs structural authority split")
- `docs/out-of-scope/` — things deliberately excluded
- `.claude/` — local working dirs (`overviews/`, `handoffs/`, `plans/`) produced by the skills themselves when you run them here

## Where it's useful

- **As a user**: install via `npx skills@latest add harisjavaid85/ai-agent-skills`, run `/setup-repo-skills` in any project, then invoke skills like `/grill-with-context`, `/tdd`, `/diagnose` as slash commands. They're model-agnostic and meant to be hacked on.
- **As a maintainer**: editing the skills themselves. The main things to respect are the bucket promotion rules in `CLAUDE.md` and the domain vocabulary in `CONTEXT.md`. Install using `link-skills.sh --claude` or `link-skills.sh --codex`.
