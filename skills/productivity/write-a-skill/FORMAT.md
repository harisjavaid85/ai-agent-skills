# Reference formats

The formats a skill draft reproduces.

## Skill structure

```
skill-name/
├── SKILL.md           # Behaviour: instructions, process, decision rules (required)
├── VOCABULARY.md      # Vocabulary: templates/formats/specs (only if needed)
└── scripts/           # Utility scripts (only if needed)
    └── helper.js
```

## SKILL.md template

```md
---
name: skill-name
description: Brief description of capability. Use when [specific triggers].
---

# Skill Name

## Vocabulary

[Only if a few terms/mappings; otherwise link to VOCABULARY.md]

## Quick start

[Minimal working example]

## Workflows

[Step-by-step processes with checklists for complex tasks]
```

## Description format

- ≤ 512 chars
- Third person
- Exactly two sentences. The first names **what** the skill does or produces, in terms a user would recognize. Not a recipe — no enumerated steps, command literals (`pnpm install`), no file-level counts ("three prompt.md edits"). The second is `Use when [specific triggers]`. If you need a third sentence, you're overspecifying.
- **No navigational paths or filenames** — i.e. where things live in this repo (`docs/agents/`, `settings.local.json`, `CLAUDE.md/AGENTS.md`). Those belong in the body.
- **Trigger markers are fine** — file extensions or filename patterns that are how the agent *recognises* the situation (`.env`, `*.pem`, `package.json`) belong in the trigger sentence when they're load-bearing for matching.

**Good**:

```
Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when user mentions PDFs, forms, or document extraction.
```

**Bad** — too vague: `Helps with documents.` — gives the agent no way to distinguish this from other document skills.

**Bad** — navigational paths in description:

```
Set up the repo's docs/agents/ folder with issue-tracker.md, triage-labels.md, commit-tags.md, and domain.md, plus the .claude/ working directories (.claude/plans/, .claude/handoffs/, .claude/overviews/) and the ## Agent skills block in CLAUDE.md/AGENTS.md. Use when configuring a repo for the engineering skills.
```

**Rewritten clean** — capability without the file tour:

```
Configure the current repo so the engineering skills work in it — scaffolds working directories, repo settings, and the per-skill config files the other skills consume. Use when the user wants to set up, wire, or configure a repo for the engineering skills.
```

**Bad** — enumerated steps in description:

```
Scaffold a new experiment in this rehearsal harness — copy a base template, `pnpm install`, run `sandcastle init` and apply surgical patches (one main.ts replacement + three prompt.md edits), seed a runnable PRD, seed AGENTS/findings stubs, create the `exp/<name>` GitHub label, and seed one GitHub Issue per acceptance criterion labeled `exp/<name>` + `needs-triage`, all committed on `main`. Use when the user wants to start a new experiment, scaffold an experiment dir, or says "create experiment" / "new experiment from <template>".
```

**Rewritten clean** — names what's produced, not the recipe:

```
Scaffold a new experiment from a template in the rehearsal harness — produces a runnable PRD and one GitHub issue per acceptance criterion. Use when the user wants to start a new experiment, or says "create experiment" or "new experiment from <template>".
```
