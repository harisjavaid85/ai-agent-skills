---
name: setup-repo-skills
description: Configure the current repo for the engineering skills with working directories, GitHub workflow conventions, per-language coding standards, and agent guidance. Use when the user wants to set up, wire, or reconfigure a repo for these skills.
---

# Setup Repo Skills

Wire a repo for the engineering skills. This skill owns the **structural** setup — mechanical scaffolding derivable from disk and convention. It never decides the repo's domain layout.

It sets up two things:

- **Harness-specific working state** — `.claude` for Claude Code, `.agents` for Codex and other agents, plus Claude settings when applicable (details in step 2).
- **`docs/agents/` config** — GitHub workflow conventions, skill vocabularies, and domain-doc rules, summarised in an `## Agent skills` block in `AGENTS.md` or `CLAUDE.md`.

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write.

## 1. Explore

Read the current repo to understand its starting state. Don't assume:

- Which harness is active? Use `.claude` for Claude Code and `.agents` for Codex or any other agent.
- When running in Claude Code, is `~/.claude/settings.json` present, and does it contain a `_setupClaudeCode` marker? (For the setup-claude-code nudge — detection only, never to change global settings.)
- `git remote -v` — is there a GitHub remote?
- `gh auth status` — is the GitHub CLI available and authenticated? (Detection only until label provisioning.)
- `AGENTS.md` and `CLAUDE.md` at the root — does either exist? Is there already an `## Agent skills` section, and does it already contain a `### Repo mode: <mode>` subsection?
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

Walk the user through the following sections **one at a time** — present each decision, get the answer where one is needed, then move on. Assume the user doesn't know these terms; each starts with a short explainer.

**Section A — Repo mode.**

> Tell the agent what this codebase _is_. Will it outlive the week? Will it ship to users? Or are you finding out if an idea works? The answer guides agents on tests, error handling, and refactoring.

Three modes:

- **`prototype`** — throwaway / exploratory. The agent gets permission to cut corners.
- **`standard`** _(default)_ — build it like you might keep it. Almost-production quality so promotion later isn't a rewrite.
- **`production`** — load-bearing. Strict defaults; the agent fights entropy.

If the user has no opinion, pick `standard`.

If step 1 found an existing `### Repo mode: <mode>` subsection in `AGENTS.md` or `CLAUDE.md`, show the user the current mode and ask **keep or change** (default keep). Mode is stickier than vocabulary — don't re-prompt blindly.

The rendered block per mode is defined in step 4.

A `prototype` repo still goes through Sections B–E. Mode doesn't skip them — a prototype can still live on GitHub and use the standard label/tag vocabulary.

**Section B — GitHub workflow.**

> GitHub Issues is the supported issue tracker for `to-prd`, `to-issues`, and `triage`. This setup writes the shared `gh` conventions those skills consume.

Do not ask the user to select an issue tracker. If step 1 found no GitHub remote, no `gh` command, or unauthenticated `gh`, warn that the GitHub lifecycle skills cannot run yet, but continue the local setup.

**Section C — Triage-role label vocabulary.**

> When `triage` processes an issue, it assigns one Issue category (`bug` or `enhancement`) and moves it through a state machine of triage roles. The five triage roles need labels that match strings you've actually configured. If your repo uses `bug:triage` instead of `needs-triage`, map that role so the skills apply the right label.

The five canonical triage roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Default each role's string to its own name; ask if the user wants to override any. The confirmed strings will be provisioned on GitHub during step 4 when GitHub is available.

**Section D — Commit tag vocabulary.**

> When `commit` writes a message, it prefixes the subject with a tag — e.g. `[Feature] Add parser`. If this repo uses different tag names, or a different subject format such as Conventional Commits (`feat: add parser`), map them here so the skill matches your house style.

The eight canonical tags: `Feature`, `Bugfix`, `Doc`, `Refactor`, `Test`, `Chore`, `Merge`, `Revert`. Default each tag's string to its own name and the subject template to `[<tag>] <summary>`; ask if the user wants to rename any tag or change the template (e.g. `<tag>: <summary>` with lowercased tags for Conventional Commits). The mood is always imperative — not configurable.

**Section E — Verify tiers.**

> The `## Verify` block in `AGENTS.md` or `CLAUDE.md` tells agents how to confirm their work. Agents run the **Fast** tier after each coherent implementation step and after fixing a failure. They run the **Full** tier before declaring substantial work complete, handing it off, or requesting human review. If a command cannot run, they report the blocker and what remains unverified.

Detect the ecosystem from files at the repo root:

- `package.json` — JS/TS. Hints: `typecheck`/`tsc`, `lint`, `test:unit`/`test` → Fast; `build`, `e2e`, `integration`, `cypress`, `playwright` → Full.
- `pyproject.toml` — Python. Hints: `mypy`/`pyright`, `ruff`, unit pytest → Fast; integration/e2e pytest, packaging → Full.
- `Makefile` / `Justfile` — read targets, classify recognizable ones, ask the user to assign ambiguous targets.
- Other ecosystem — use `WebSearch` to look up conventional Fast/Full verification commands for the detected tooling.

Classification rule: a command goes in **Fast** only if it (a) doesn't bundle or package artifacts, (b) doesn't touch external services, (c) scales with code not infrastructure. Everything else → **Full**.

Present the proposal with one-line rationale per command (e.g. "`pnpm build` → Full because Vite bundling adds no new error coverage beyond typecheck"). Let the user edit before write. Rationale stays in the proposal — don't write it to the file.

If a `## Verify` block already exists, show its contents and ask: keep / edit / regenerate.

When generating or regenerating it, use this shape with the confirmed commands:

```markdown
## Verify

Agents run Fast checks after each coherent implementation step and after fixing a failure. Agents run Full checks before declaring substantial work complete, handing it off, or requesting human review. If a command cannot run, report the blocker and what remains unverified.

### Fast

- `<command>`

### Full

- `<command>`
```

**Section F — Coding standards.**

> Coding standards bind agents to a per-language style guide so they write idiomatic, high-quality code by default. This is orthogonal to Repo mode: mode sets _rigor_ (how much you test and harden), standards set _convention_ (how the code reads). A `prototype` still writes guide-conformant code.

Reuse the language detection from Section E — root manifests, plus the dominant source-file extension for a language with no manifest. For each detected language, read the matching row in [coding-standards.md](./coding-standards.md)'s _Catalog defaults_ table and propose that guide as the default. Ask the user to confirm or override, and to add any house deviations (default none). A detected language with no catalog row gets an open prompt for its guide.

Standards are **referenced, never installed**. If a language's canonical linter is not configured in the repo, still record it under "Enforced by" and add the finish-summary nudge from step 5 — never run or install it.

There is **no** domain-layout question. The domain-doc rules are static and written as-is (see step 4). The settled-state output rules (step 4) are likewise static — no question, written verbatim.

## 4. Confirm and write

Show the user a draft of everything before writing; let them edit.

**Pick the file to edit:**

- If `AGENTS.md` exists, edit it.
- Else if `CLAUDE.md` exists, edit it.
- If neither exists, create `AGENTS.md`.

Write these static blocks as sibling top-level sections. Replace `<agent-dir>` with the selected harness directory before writing. If a block already exists, update it in place rather than appending a duplicate.

For Claude Code only, write the `## Memory` block — it describes how that harness loads memory, and has no meaning for Codex or other agents:

```markdown
## Memory

The harness surfaces this project's memory index by default, but not the global one. At session start, also read the global memory if it exists and load the entries that carry cross-project working discipline — they apply here as much as project memory does.
```

For every harness, write the rest:

```markdown
## Artifacts represent settled state — code comments as much as docs

These rules govern everything you produce that carries comments or prose — inline code comments, docs, commit messages, PR text, plan files, etc. If it needs a comment or a sentence, it needs this discipline.

- Write what IS true, not how you got there. A reader who wasn't in the session shouldn't be able to tell a debate happened. No "we considered", "originally", "previously", "changed from", "after discussion".
- Keep rationale only when it constrains a future choice — a tradeoff, a "don't do X, it breaks Y". Historical "why we picked this" is noise.
- Single source of truth — define once at the declaration; elsewhere name it, don't re-describe it. _What_ a thing is belongs to the type, field, function, or glossary entry that declares it; every use site leans on that name and adds, if needed, only what's true there and nowhere else (why it's used here, an ordering or coupling the name can't carry).
  - _Portability test:_ a comment that would read as equally true at another use site is a misplaced definition — move it to the declaration and delete the copies. Classic trap: re-explaining a param or field at each site that touches it when its type name already says what it is.
- Match the surrounding density. Don't add comments, summaries, or prose the existing code or docs wouldn't already carry.

## Plan mode artifacts

Plan/design docs and artifacts produced in plan mode go in `<agent-dir>/plans/<slug>.md`. Don't invent other locations (`docs/design/`, etc.). The slug should be kebab-case, topical, with no date in it.
```

If an `## Agent skills` block already exists, update it in place rather than appending a duplicate. Don't overwrite surrounding sections.

The block (substitute the prose and bullets for the chosen mode from the table below):

```markdown
## Agent skills

### Repo mode: <mode>

<mode-specific prose>

- **Tests:** …
- **Errors:** …
- **Refactoring:** …

### Coding standards

Per-language style-guide bindings agents follow when writing code — orthogonal to Repo mode. See `docs/agents/coding-standards.md`.

### Issue tracker

GitHub Issues via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the triage-role label vocabulary]. See `docs/agents/triage-labels.md`.

### Commit tags

[one-line summary of the tag vocabulary and subject format]. See `docs/agents/commit-tags.md`.

### Domain docs

How to find and consume them: `docs/agents/domain.md`.

- _Glossary_ — canonical vocabulary: the `CONTEXT.md` files, indexed by `CONTEXT-MAP.md` in a multi-context repo.
- _Knowledge base_ — durable, learned facts about how the system behaves (gotchas, non-obvious invariants): a root `KNOWLEDGE.md` for system-wide facts, or a `KNOWLEDGE.md` beside a context's `CONTEXT.md`.
- _Capture_ — when you learn a durable, non-obvious behavioral fact a future agent would waste time rediscovering, add it per `docs/agents/domain.md`, and note it in your summary to user.
```

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

Write the `## Verify` block from Section E as a sibling top-level section. If a `## Verify` block already exists, follow Section E's keep / edit / regenerate rule.

Then write the `docs/agents/` files from the seed templates in this skill folder:

- [issue-tracker-github.md](./issue-tracker-github.md) — always write this as `docs/agents/issue-tracker.md`
- [triage-labels.md](./triage-labels.md) — fill in the user's label strings
- [commit-tags.md](./commit-tags.md) — fill in the user's tag strings and subject template from Section D's answer (e.g. `[<tag>] <summary>` for bracketed, `<tag>: <summary>` for Conventional Commits); the resulting file should describe only the chosen format
- [domain.md](./domain.md) — the agent contract for reading and extending domain docs, written as-is (no per-repo decision)
- [coding-standards.md](./coding-standards.md) — write as `docs/agents/coding-standards.md`; emit one binding block per detected language (guide, authoritative URL, enforcing linter, deviations, emphases) from Section F, and keep the complete _Catalog defaults_ table so a producing agent can add a language later

If a GitHub remote exists and `gh auth status` succeeds, provision the five configured triage-role labels, the fixed issue category labels, and the fixed `kind:prd` marker. Use the confirmed mapped string as each triage label's name.

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
| fixed `kind:prd`        | Marker for PRD tracker issues            | `EDEDED`      |

For each missing label, run:

```bash
gh label create "<confirmed-label-name>" --description "<description>" --color "<color>"
```

If any label cannot be listed or created, continue writing the local setup, then report the failed label provisioning and error in the finish summary. Otherwise report that all required GitHub labels exist. If GitHub is unavailable, skip provisioning and include the GitHub prerequisite warning in the finish summary.

## 5. Finish

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

_Background: the structural-vs-semantic split between this skill and `bootstrap-context` is recorded in [ADR-0003](../../../docs/adr/0003-semantic-vs-structural-authority-split.md)._
