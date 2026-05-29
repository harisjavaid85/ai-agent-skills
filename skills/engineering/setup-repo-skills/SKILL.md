---
name: setup-repo-skills
description: Configure the current repo so the engineering skills work in it — scaffolds working directories, repo settings, the `## Agent skills` block in CLAUDE.md/AGENTS.md, and `docs/agents/` (issue tracker, skill vocabularies, and domain-doc rules). Run once when setting up a repo for these skills, or to reconfigure any of them.
disable-model-invocation: true
---

# Setup Repo Skills

Wire a repo for the engineering skills. This skill owns the **structural** setup — mechanical scaffolding derivable from disk and convention. It never decides the repo's domain layout.

It sets up two things:

- **The repo's local `.claude` config** — working directories and settings (details in step 2).
- **`docs/agents/` config** — issue tracker, skill vocabularies, and domain-doc rules, summarised in an `## Agent skills` block in `CLAUDE.md`/`AGENTS.md`.

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write.

## 1. Explore

Read the current repo to understand its starting state. Don't assume:

- `~/.claude/settings.json` — is it present, and does it contain a `_setupClaudeCode` marker? (For the setup-claude-code nudge — detection only, never to change global settings.)
- `git remote -v` — is this GitHub, GitLab, or neither?
- `CLAUDE.md` and `AGENTS.md` at the root — does either exist? Is there already an `## Agent skills` section?
- `.claude/` — which of `settings.json`, `plans/`, `handoffs/`, `overviews/` already exist?
- `.gitignore` — does it already ignore the `.claude/` working dirs?
- `CONTEXT.md` / `CONTEXT-MAP.md` at the root — present or absent? (For the bootstrap-context nudge, never to decide domain layout.)
- `docs/agents/` — does this skill's prior output already exist?
- `package.json` — is this a JS/TS repo? (For the pre-commit nudge.)
- `.scratch/` — sign that a local-markdown issue-tracker convention is already in use.

Summarise what's present and what's missing before changing anything.

## 2. Structural scaffolding

Create the `.claude/` working directories if absent:

- `.claude/plans/`
- `.claude/handoffs/`
- `.claude/overviews/`

Add these to `.gitignore` (append if the file exists, create it if not; don't duplicate entries that are already present):

```
.claude/plans/
.claude/handoffs/
.claude/overviews/
```

These three are ephemeral agent working memory. `.claude/settings.json` is **not** ignored — it's checked in.

Write `.claude/settings.json` if it doesn't exist (don't clobber an existing one — merge the keys in instead and dedupe):

```json
{
  "permissions": {
    "allow": [
      "Write(./.claude/plans/**)",
      "Edit(./.claude/plans/**)",
      "Write(./.claude/handoffs/**)",
      "Edit(./.claude/handoffs/**)",
      "Write(./.claude/overviews/**)",
      "Edit(./.claude/overviews/**)"
    ]
  },
  "plansDirectory": ".claude/plans"
}
```

Scope the rules to the three specific dirs — a blanket `Write(./.claude/**)` would also let the agent change its own `settings.json`, which should never be done (settings must stay reviewable).

## 3. Agent-skills wiring

Walk the user through the following decisions **one at a time** — present, get the answer, then move on. Assume the user doesn't know these terms; each starts with a short explainer.

**Section A — Issue tracker.**

> The "issue tracker" is where issues live for this repo. Skills like `to-issues`, `triage`, and `to-prd` read from and write to it — they need to know whether to call `gh issue create`, `glab issue create`, write a markdown file under `.scratch/`, or follow some other workflow.

Propose based on `git remote`: GitHub remote → GitHub; GitLab remote → GitLab; otherwise offer the full list:

- **GitHub** — GitHub Issues via the `gh` CLI
- **GitLab** — GitLab Issues via the [`glab`](https://gitlab.com/gitlab-org/cli) CLI
- **Local markdown** — files under `.scratch/<feature>/` (good for solo projects or repos with no remote)
- **Other** (Jira, Linear, etc.) — ask the user to describe the workflow in one paragraph; record it as freeform prose

**Section B — Triage label vocabulary.**

> When `triage` processes an issue, it moves it through a state machine and applies labels. It needs labels that match strings you've actually configured. If your repo already uses different names (e.g. `bug:triage` instead of `needs-triage`), map them here so the skill applies the right ones.

The five canonical roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Default each role's string to its own name; ask if the user wants to override any.

**Section C — Commit tag vocabulary.**

> When `commit` writes a message, it prefixes the subject with a tag — e.g. `[Feature] Add parser`. If this repo uses different tag names, or a different subject format such as Conventional Commits (`feat: add parser`), map them here so the skill matches your house style.

The eight canonical tags: `Feature`, `Bugfix`, `Doc`, `Refactor`, `Test`, `Chore`, `Merge`, `Revert`. Default each tag's string to its own name and the subject template to `[<tag>] <summary>`; ask if the user wants to rename any tag or change the template (e.g. `<tag>: <summary>` with lowercased tags for Conventional Commits). The mood is always imperative — not configurable.

There is **no** domain-layout question. The domain-doc rules are static and written as-is (see step 4).

## 4. Confirm and write

Show the user a draft of everything before writing; let them edit.

**Pick the file to edit:**

- If `CLAUDE.md` exists, edit it.
- Else if `AGENTS.md` exists, edit it.
- If neither exists, ask which to create — don't pick for them. Never create one when the other already exists.

If an `## Agent skills` block already exists, update it in place rather than appending a duplicate. Don't overwrite surrounding sections.

The block:

```markdown
## Agent skills

### Issue tracker

[one-line summary of where issues are tracked]. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the label vocabulary]. See `docs/agents/triage-labels.md`.

### Commit tags

[one-line summary of the tag vocabulary and subject format]. See `docs/agents/commit-tags.md`.

### Domain docs

How to read this repo's glossary and ADRs. See `docs/agents/domain.md`.
```

Then write the `docs/agents/` files from the seed templates in this skill folder:

- [issue-tracker-github.md](./issue-tracker-github.md) / [issue-tracker-gitlab.md](./issue-tracker-gitlab.md) / [issue-tracker-local.md](./issue-tracker-local.md) — pick the chosen one
- [triage-labels.md](./triage-labels.md) — fill in the user's label strings
- [commit-tags.md](./commit-tags.md) — fill in the user's tag strings and subject template
- [domain.md](./domain.md) — the consumer contract, written as-is (no per-repo decision)

For an "other" issue tracker, write `docs/agents/issue-tracker.md` from scratch using the user's description.

## 5. Punch list

Finish with recommended next steps, based on what step 1 found. Offer, don't run:

- **No global setup detected** (file absent or no `_setupClaudeCode` marker) → "Run `/setup-claude-code` to install security guardrails — it's the global counterpart to this repo setup."
- **No `CONTEXT.md` and no `CONTEXT-MAP.md`** → "Run `/bootstrap-context` to capture this repo's domain language. It surveys the tree and decides single- vs multi-context with evidence — better than guessing." (If the user runs it later and the layout changes, re-running this skill is safe and idempotent.)
- **`package.json` present** → "Run `/setup-pre-commit` to add Husky/lint-staged pre-commit hooks."

Tell the user setup is complete and that they can edit `docs/agents/*.md` directly later — re-running is only needed to switch issue trackers or start fresh.

---

_Background: the structural-vs-semantic split between this skill and `bootstrap-context` is recorded in [ADR-0003](../../../docs/adr/0003-semantic-vs-structural-authority-split.md)._
