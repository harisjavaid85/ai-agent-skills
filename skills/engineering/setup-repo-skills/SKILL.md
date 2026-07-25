---
name: setup-repo-skills
description: Configure the current repo for the engineering skills with working directories, issue-tracker conventions, per-language coding standards, and agent guidance. Use when the user wants to set up, wire, or reconfigure a repo for these skills.
disable-model-invocation: true
---

# Setup Repo Skills

Wire a repo for the engineering skills. This skill owns the **structural** setup — mechanical scaffolding derivable from disk and convention. It never decides the repo's domain layout.

It sets up three things:

- **Harness-specific working state** — `.claude` for Claude Code, `.agents` for Codex and other agents, plus Claude settings when applicable (details in step 2).
- **The agent guide** — the repo's `AGENTS.md` or `CLAUDE.md`: repo mode, output discipline, and pointers to everything below.
- **`docs/agents/` config** — issue-tracker conventions, skill vocabularies, and domain-doc rules the agent guide points to.

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write.

## 1. Explore

Read the current repo to understand its starting state. Don't assume:

- Which harness is active? Use `.claude` for Claude Code and `.agents` for Codex or any other agent.
- When running in Claude Code, is `~/.claude/settings.json` present, and does it contain a `_setupClaudeCode` marker? (For the setup-claude-code nudge — detection only, never to change global settings.)
- `git remote -v` — which host, if any (GitHub, GitLab, other)?
- `gh auth status` — is the GitHub CLI available and authenticated? (Detection only until label provisioning.)
- Is the `triage` skill installed? (Gates Section C — an uninstalled skill needs no labels.)
- `.scratch/` — is a local-markdown issue-tracker convention already in use?
- Monorepo signals — a `pnpm-workspace.yaml`, a `workspaces` field in `package.json`, or a populated `packages/*` with its own `src/` (feeds the bootstrap-context nudge only — never a layout decision here).
- `AGENTS.md` and `CLAUDE.md` at the root — does either exist? Do the agent-guide sections already exist — e.g. a `### Repo mode: <mode>` subsection under `## Operating mode`?
- The active harness directory — which of `plans/`, `handoffs/`, and `overviews/` already exist? For Claude Code, also check `.claude/settings.json`.
- `.gitignore` — does it already ignore the active harness's working dirs?
- `CONTEXT.md` / `CONTEXT-MAP.md` at the root — present or absent? (For the bootstrap-context nudge, never to decide domain layout.)
- `docs/agents/` — does this skill's prior output already exist?
- `package.json` — is this a JS/TS repo? (For the pre-commit nudge.)

Summarise what's present and what's missing before changing anything.

## 2. Structural scaffolding

Set `agent-dir` to `.claude` for Claude Code or `.agents` for Codex and other agents. Create these working directories if absent:

- `<agent-dir>/plans/`
- `<agent-dir>/handoffs/`
- `<agent-dir>/overviews/`

### `.gitignore`

Update `.gitignore` for the selected harness. If `.gitignore` is absent, create it. If it already exists, merge the relevant entries into the existing file: preserve unrelated entries, do not clobber comments or project-specific rules, and dedupe entries that are already present.

For Claude Code, ignore `.claude/*` by default, then explicitly allow the checked-in Claude config and repo-local skills:

```
.claude/*
!.claude/settings.json
!.claude/skills/
!.claude/skills/**
```

This allowlist keeps `.claude/settings.json` and `.claude/skills/**` trackable while ignoring ephemeral Claude working state such as `.claude/plans/`, `.claude/handoffs/`, and `.claude/overviews/`.

If the repo already has older narrow Claude entries such as `.claude/plans/`, `.claude/handoffs/`, and `.claude/overviews/`, replace those entries with the allowlist block above when practical. If replacing them would risk disturbing nearby hand-written rules, leave the old entries and add the allowlist block; correctness matters more than perfect tidiness.

For Codex and other agents, ignore only the ephemeral working-memory directories:

```
.agents/plans/
.agents/handoffs/
.agents/overviews/
```

### Claude Code settings

For Claude Code only, `.claude/settings.json` is checked in. Write it if it does not exist. If it already exists, merge the following settings into it: preserve unrelated keys, preserve user-added permission entries, and dedupe `permissions.allow` values.

```json
{
  "permissions": {
    "allow": [
      "Read(./.claude/skills/**)",
      "Edit(./.claude/plans/**)",
      "Edit(./.claude/handoffs/**)",
      "Edit(./.claude/overviews/**)"
    ]
  },
  "plansDirectory": ".claude/plans"
}
```

Do not use a blanket `Edit(./.claude/**)` rule. That would let the agent change `.claude/settings.json`, which must stay reviewable. Repo-local Claude skills are read-only by default: agents can load `.claude/skills/**` without a prompt, but changing those skills still requires review.

For Codex and other agents, do not create a harness settings file.

## 3. Agent-skills wiring

Walk the user through the following sections **one at a time** — one section, one answer, then the next. Lead each section with the recommended answer so the user can accept it in a word. Assume the user doesn't know these terms; give a one-line explainer only when the choice genuinely branches, and skip a section entirely when exploration already settled it (Section C when `triage` isn't installed).

**Section A — Repo mode.**

> Tell the agent what this codebase _is_. Will it outlive the week? Will it ship to users? Or are you finding out if an idea works? The answer guides agents on tests, error handling, and refactoring.

Three modes:

- **`prototype`** — throwaway / exploratory. The agent gets permission to cut corners.
- **`standard`** _(default)_ — build it like you might keep it. Almost-production quality so promotion later isn't a rewrite.
- **`production`** — load-bearing. Strict defaults; the agent fights entropy.

If the user has no opinion, pick `standard`.

If step 1 found an existing `### Repo mode: <mode>` subsection in `AGENTS.md` or `CLAUDE.md`, show the user the current mode and ask **keep or change** (default keep). Mode is stickier than vocabulary — don't re-prompt blindly.

The rendered block per mode is defined in step 4.

A `prototype` repo still goes through Sections B–F. Mode doesn't skip them — a prototype can still live on GitHub and use the standard label/tag vocabulary.

**Section B — Issue tracker.**

> The "issue tracker" is where issues live for this repo. Skills like `to-spec`, `to-tickets`, and `triage` read from and write to it — they need to know whether to call `gh issue create`, write a markdown file under `.scratch/`, or follow some other workflow you describe. Pick the place you actually track work for this repo.

Default posture: these skills were designed for GitHub. If a `git remote` points at GitHub, propose that. If a `git remote` points at GitLab (`gitlab.com` or a self-hosted host), propose GitLab. Otherwise (or if the user prefers), offer:

- **GitHub** — issues live in the repo's GitHub Issues (uses the `gh` CLI)
- **GitLab** — issues live in the repo's GitLab Issues (uses the `glab` CLI)
- **Local markdown** — issues live as files under `.scratch/<feature>/` in this repo (good for solo projects or repos without a remote)
- **Other** (Jira, Linear, etc.) — ask the user to describe the workflow in one paragraph; record it as freeform prose

Record the choice in `docs/agents/issue-tracker.md` from the matching seed template in step 4. The GitHub and GitLab templates carry a "PRs as a request surface" flag, defaulted **off** — leave it off and don't raise it; a user who wants external PRs in the triage queue can flip the flag in the file later.

If the user picks GitHub but step 1 found no GitHub remote, no `gh` command, or unauthenticated `gh`, warn that the GitHub lifecycle skills cannot run yet, but continue the local setup.

**Section C — Triage-role label vocabulary.** Skip this section entirely if the `triage` skill isn't installed (exploration told you).

> When `triage` processes an issue, it assigns one Issue category (`bug` or `enhancement`) and moves it through a state machine of triage roles. The five triage roles need labels that match strings you've actually configured. If your repo uses `bug:triage` instead of `needs-triage`, map that role so the skills apply the right label.

The five canonical triage roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Default each role's string to its own name; ask if the user wants to override any. The confirmed strings will be provisioned on GitHub during step 5 when the GitHub tracker was chosen and GitHub is available.

**Section D — Commit tag vocabulary.**

> When `commit` writes a message, it prefixes the subject with a tag — e.g. `[Feature] Add parser`. If this repo uses different tag names, or a different subject format such as Conventional Commits (`feat: add parser`), map them here so the skill matches your house style.

The eight canonical tags: `Feature`, `Fix`, `Doc`, `Refactor`, `Test`, `Chore`, `Merge`, `Revert`. Default each tag's string to its own name and the subject template to `[<tag>] <summary>`; ask if the user wants to rename any tag or change the template (e.g. `<tag>: <summary>` with lowercased tags for Conventional Commits). The mood is always imperative — not configurable.

**Section E — Verify tiers.**

> The `## Verify` block in `AGENTS.md` or `CLAUDE.md` tells agents how to confirm their work. Agents run the **Fast** tier after each coherent implementation step and after fixing a failure. They run the **Full** tier before declaring substantial work complete, handing it off, or requesting human review. If a command cannot run, they report the blocker and what remains unverified.

Verify setups vary too much to guess well, so don't auto-classify or web-search for commands. Note the build manifests at the repo root (`package.json`, `pyproject.toml`, `Makefile`, …) and ask the user for their **Fast** and **Full** commands:

- **Fast** — checks that scale with code, don't bundle or package, and don't touch external services: lint, typecheck, unit tests.
- **Full** — everything heavier: production build, integration, e2e.

If the user hasn't settled these yet, write the block with the cadence prose and empty tiers for them to fill. If a `## Verify` block already exists, show its contents and ask: keep / edit / regenerate.

**Section F — Coding standards.**

> Coding standards bind agents to a per-language style guide so they write idiomatic, high-quality code by default. This is orthogonal to Repo mode: mode sets _rigor_ (how much you test and harden), standards set _convention_ (how the code reads). A `prototype` still writes guide-conformant code.

Detect languages from root manifests, plus the dominant source-file extension for a language with no manifest. For each detected language, read the matching row in [coding-standards.md](./coding-standards.md)'s _Catalog defaults_ table and propose that guide as the default. Ask the user to confirm or override, and to add any house deviations (default none). A detected language with no catalog row gets an open prompt for its guide.

Standards are **referenced, never installed**. If a language's canonical linter is not configured in the repo, still record it under "Enforced by" and add the finish-summary nudge from step 6 — never run or install it.

## 4. Confirm and write

Show the user a draft of everything before writing; let them edit.

**Pick the file to edit:**

- If `AGENTS.md` exists, edit it.
- Else if `CLAUDE.md` exists, edit it.
- If neither exists, create `AGENTS.md`.

If the file already exists and carries its own section structure, **do not restructure it silently.** Show the user how its sections map onto the shape below and ask whether to keep their structure (adding only missing pieces), adopt this shape, or merge. Default to keeping their structure. The shape below is for a fresh file.

Write the file as these top-level sections, in order. Replace `<agent-dir>` with the selected harness directory. Include the `## Operating mode` _Memory_ paragraph and the _Plan mode artifacts_ item **only for Claude Code** — they have no meaning for Codex or other agents. If a section already exists, update it in place rather than appending a duplicate.

```markdown
# <AGENTS.md or CLAUDE.md>

## Operating mode

_(Claude Code only)_ **Memory** — the harness surfaces this project's memory index by default, but not the global one. At session start, also read the global memory if it exists and load the entries that carry cross-project working discipline; they apply here as much as project memory does.

### Repo mode: <mode>

<mode-specific prose — from the table below>

- **Tests:** …
- **Errors:** …
- **Refactoring:** …

## Producing code & docs

**Settled state — code comments as much as docs.** These rules govern everything you produce that carries comments or prose — inline code comments, docs, commit messages, PR text, plan files. If it needs a comment or a sentence, it needs this discipline.

- Write what IS true, not how you got there. A reader who wasn't in the session shouldn't be able to tell a debate happened. No "we considered", "originally", "previously", "changed from", "after discussion".
- Keep rationale only when it constrains a future choice — a tradeoff, a "don't do X, it breaks Y". Historical "why we picked this" is noise.
- Single source of truth — define once at the declaration; elsewhere name it, don't re-describe it. _What_ a thing is belongs to the type, field, function, or glossary entry that declares it; every use site leans on that name and adds, if needed, only what's true there and nowhere else (why it's used here, an ordering or coupling the name can't carry).
  - _Portability test:_ a comment that would read as equally true at another use site is a misplaced definition — move it to the declaration and delete the copies. Classic trap: re-explaining a param or field at each site that touches it when its type name already says what it is.
- Match the surrounding density. Don't add comments, summaries, or prose the existing code or docs wouldn't already carry.

**Coding standards** — per-language style-guide bindings agents follow when writing code, orthogonal to Repo mode. See `docs/agents/coding-standards.md`.

_(Claude Code only)_ **Plan mode artifacts** — plan and design docs produced in plan mode go in `<agent-dir>/plans/<slug>.md` (kebab-case, topical, no date in the slug). Don't invent other locations (`docs/design/`, etc.).

## Issues, triage & commits

- **Issue tracker** — [one-line summary of where issues are tracked]. See `docs/agents/issue-tracker.md`.
- **Triage labels** — [one-line summary of the triage-role label vocabulary]. See `docs/agents/triage-labels.md`.
- **Commit tags** — [one-line summary of the tag vocabulary and subject format]. See `docs/agents/commit-tags.md`.

## Navigating & extending the repo

**Where things go.** When you learn or decide something durable, route it — don't dump it in memory or the nearest open file:

| What you have | Goes to |
| --- | --- |
| a term / domain concept | glossary — `CONTEXT.md` |
| a decision + its tradeoffs | an ADR — `docs/adr/` |
| how the system behaves (gotcha, non-obvious invariant) | knowledge — `KNOWLEDGE.md` |
| a rule for how the agent should work | operational policy — this file |
| a purely local invariant | a comment at the code |

Agent memory is **not** on this list — it holds cross-project working style, not facts about this repo. Full routing rules (register, scope, the high bar): `docs/agents/domain.md`. Note anything you add in your summary.

- **Domain docs** — read before exploring: `docs/agents/domain.md`.

## Repo conventions

_Repo-specific — record durable local rules agents must follow (secrets handling, migration policy, branching & PR flow, debug-flag naming…). Leave empty if none yet._

## Verify

Run Fast checks after each coherent implementation step and after fixing a failure. Run Full checks before declaring substantial work complete, handing off, or requesting human review. If a command cannot run, report the blocker and what remains unverified.

### Fast

- <Fast commands from Section E, or leave empty for the user to fill>

### Full

- <Full commands from Section E, or leave empty for the user to fill>
```

The `### Repo mode` prose and bullets come from the mode table below. Everything not marked for substitution — settled-state, the Navigating routing, Repo conventions — is written verbatim.

**Mode content** — substitute the prose and bullets for the chosen mode verbatim.

`prototype`:

> This code is exploratory. Optimize for learning speed and feedback. The goal is to find out if the idea works, not to ship it.
>
> Prefer the shortest path to a clear answer. Make shortcuts visible, keep experiments easy to change or delete, and avoid building production infrastructure before the shape of the problem is known.

- **Tests:** skip unless they clarify behavior, protect tricky logic, or speed up iteration
- **Errors:** handle only the failures needed to keep the experiment understandable; call out known gaps
- **Refactoring:** keep changes local; hardcode values when it speeds learning, but don't bury assumptions

`standard`:

> This code is real. It might not be load-bearing yet, but it could be. Build it so promotion to production is an upgrade path, not a rewrite.
>
> Prefer straightforward, maintainable solutions. Make tradeoffs explicit when they affect future work, but don't over-engineer for scale, compliance, or operational needs the repo does not have yet.

- **Tests:** test new logic and changed behavior; add regression tests for bugs; don't backfill broadly
- **Errors:** handle errors at user input, persistence, network, and other external boundaries; keep internal assumptions clear
- **Refactoring:** fix smells you actively touch when it clarifies the change; don't go hunting

`production`:

> This codebase is meant for production deployment. Treat it as load-bearing software: correctness, maintainability, security, observability, and operability matter.
>
> Act with the judgment of an experienced principal engineer. When planning, designing, or implementing, choose proven best practices and make tradeoffs explicit. Prefer simple, durable designs over clever shortcuts.
>
> Fight entropy. If a requested approach would create avoidable risk, technical debt, brittle behavior, or operational burden, say so and propose a better path. Leave the codebase easier to understand, verify, operate, and evolve.

- **Tests:** TDD by default for new behavior; cover edge cases, regressions, and failure paths
- **Errors:** handle errors at boundaries; assert invariants; avoid silent failure
- **Refactoring:** improve code you touch when it reduces risk or clarifies behavior; avoid unrelated churn

Then write the `docs/agents/` files from the seed templates in this skill folder:

- [issue-tracker-github.md](./issue-tracker-github.md) / [issue-tracker-gitlab.md](./issue-tracker-gitlab.md) / [issue-tracker-local.md](./issue-tracker-local.md) — write the one matching Section B's choice as `docs/agents/issue-tracker.md`; for "other" trackers, write it from scratch using the user's description
- [triage-labels.md](./triage-labels.md) — fill in the user's label strings (only when `triage` is installed and Section C ran)
- [commit-tags.md](./commit-tags.md) — fill in the user's tag strings and subject template from Section D's answer (e.g. `[<tag>] <summary>` for bracketed, `<tag>: <summary>` for Conventional Commits); the resulting file should describe only the chosen format
- [domain.md](./domain.md) — the agent contract for reading and extending the domain docs and knowledge base, written as-is (no per-repo decision)
- [coding-standards.md](./coding-standards.md) — write as `docs/agents/coding-standards.md`; emit one binding block per detected language (guide, authoritative URL, enforcing linter, deviations, emphases) from Section F, and keep the complete _Catalog defaults_ table so a producing agent can add a language later

## 5. Provision GitHub labels

Only when Section B chose the GitHub tracker: if a GitHub remote exists and `gh auth status` succeeds, provision the five configured triage-role labels, the fixed issue category labels, and the fixed `kind:spec` marker. Use the confirmed mapped string as each triage label's name.

Create only labels that are missing. Match names exactly; do not use a fuzzy search. Preserve every existing label's color and description rather than updating it with `--force`.

| Label or canonical role | Description                              | Default color |
| ----------------------- | ---------------------------------------- | ------------- |
| `needs-triage`          | Maintainer needs to evaluate this issue  | `BFD4F2`      |
| `needs-info`            | Waiting on reporter for more information | `FBCA04`      |
| `ready-for-agent`       | Fully specified, ready for an AFK agent  | `0E8A16`      |
| `ready-for-human`       | Requires human implementation            | `C5DEF5`      |
| `wontfix`               | This will not be worked on               | `FFFFFF`      |
| fixed `bug`             | Something isn't working                  | `D73A4A`      |
| fixed `enhancement`     | New feature or request                   | `A2EEEF`      |
| fixed `kind:spec`       | Identifies parent spec issues             | `EDEDED`      |

For each missing label, run:

```bash
gh label create "<confirmed-label-name>" --description "<description>" --color "<color>"
```

If any label cannot be listed or created, continue writing the local setup, then report the failed label provisioning and error in the finish summary. Otherwise report that all required GitHub labels exist. If the GitHub tracker wasn't chosen, skip provisioning. If it was chosen but GitHub is unavailable, skip provisioning and include the GitHub prerequisite warning in the finish summary.

## 6. Finish

Tell the user setup is done and that `docs/agents/*.md` are theirs to edit. Then suggest the applicable next steps from the rubric below in your own prose.

### Rubric (internal)

Suggest only the rows whose condition is met. Never run these yourself.

| Condition from step 1                                                                                | Suggest                                                                               |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Running in Claude Code and `~/.claude/settings.json` is missing or lacks a `_setupClaudeCode` marker | `/setup-claude-code` — global security guardrails, counterpart to this repo setup     |
| Neither `CONTEXT.md` nor `CONTEXT-MAP.md` at the repo root                                           | `/bootstrap-context` — captures domain language; safe to re-run this skill afterwards |
| `package.json` present                                                                               | `/setup-pre-commit` — Husky + lint-staged pre-commit hooks                            |
| A detected language's canonical linter (from its coding standard) is not configured in the repo      | Wiring that linter/formatter so the coding standard is machine-enforced               |

Do not quote the conditions, marker names, or arrow syntax in your message — those are internal.

---

_Background: the structural-vs-semantic split between this skill and `bootstrap-context` is recorded in [ADR-0004](../../../.agents/adr/0004-semantic-vs-structural-authority-split.md)._
