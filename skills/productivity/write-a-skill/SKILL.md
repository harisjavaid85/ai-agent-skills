---
name: write-a-skill
description: Turn settled requirements into a well-structured agent skill, separating vocabulary from behaviour. Use when the user wants to create, write, or build a new skill and scope is already decided. Requires settled requirements — if scope is fuzzy, grill first.
---

# Writing Skills

This skill does one thing: transform **settled requirements** into a clean, well-structured skill. It does not gather requirements itself — a shallow self-grill produces low-quality drafts and rework.

## Entry gate — require settled requirements

Before writing, confirm requirements are settled. There are three cases:

1. **Grilled in this conversation** — a grilling session earlier in the current context already settled scope. Write from that.
2. **Handoff doc** — the user has (or points you to) a handoff document capturing the settled design. Read it, then write. Don't hard-code where handoff docs live; use whatever path the user gives or that the handoff skill reports.
3. **Cold start** — neither of the above. Do **not** improvise a requirements interview. Recommend the user run `/grill-me` (general design) or `/grill-with-context` (when the skill introduces or depends on canonical domain terms), then re-run this skill.

If the user declines grilling and wants a draft anyway, collect only the **irreducible inputs** — the minimum needed to emit a valid skill:

- **name** (kebab-case)
- **trigger** — the "Use when…" for the description
- **one sentence** on what it does (core behaviour)

Draft a best-effort pass from those and label it as rough, since scope wasn't grilled. Never invent scope, edge cases, or alternatives to fill the gap.

## Before drafting — duplication & collision check

Scan the existing skills first:

- **Overlap** — does a skill already cover this? ("`triage` already classifies issues — is this new skill actually distinct?") If it overlaps, raise it before creating a redundant skill.
- **Vocabulary collision** — does the new skill reuse a term that `CONTEXT.md` already defines differently? Reconcile the term before writing.

## Separate vocabulary from behaviour

Keep the nouns and the verbs apart (see `CONTEXT.md` for the canonical definitions of **Vocabulary** and **Behaviour**).

- **Behaviour** always lives in `SKILL.md` — the process, decision rules, and steps.
- **Vocabulary**:
  - If it's a **template/format/spec the agent reproduces verbatim**, or it's long, put it in a single separate vocabulary file (e.g. `VOCABULARY.md` or `FORMAT.md`). One vocabulary file is enough — don't fragment it across many.
  - If it's just **a few term definitions or a small mapping**, put it in a `## Vocabulary` section near the top of `SKILL.md`.

Never interleave "here's the format of X" with "here's when you do Y" in the same prose — that's the smear that makes drafts noisy to edit.

## Do not document non-features

The produced skill is for whoever runs it later, not a record of the grilling conversation.

- **Cut** all process archaeology: "we considered X but decided against it", "this skill does not build Y", rationale for rejected alternatives. None of it helps a future reader of the finished skill.
- **Keep only** a terse, present-tense **scope guard** when the agent would plausibly overstep without it ("Only triages; never edits code"). The test: does the line stop the agent from doing the wrong thing *right now*? If it just explains a past decision, cut it.

Whether a cut decision deserves an ADR is the grilling skill's call at runtime — this skill doesn't record rejected decisions anywhere.

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

## Description requirements

The description is **the only thing the agent sees** when deciding which skill to load. It's surfaced in the system prompt alongside all other installed skills.

**Format**:

- Max 1024 chars
- Third person
- First sentence: what it does
- Second sentence: "Use when [specific triggers]"

**Good**:

```
Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when user mentions PDFs, forms, or document extraction.
```

**Bad**: `Helps with documents.` — gives the agent no way to distinguish this from other document skills.

## When to add scripts

Add utility scripts when the operation is deterministic (validation, formatting), the same code would be generated repeatedly, or errors need explicit handling. Scripts save tokens and improve reliability vs generated code.

## When to split into a separate file

Split vocabulary into its own file when it's a verbatim template/format/spec, or when `SKILL.md` would otherwise grow past roughly 100 lines. Keep references one level deep.

## Review checklist

After drafting, verify:

- [ ] Requirements were settled (grilled, handoff, or irreducible-inputs override)
- [ ] Description includes triggers ("Use when…")
- [ ] Vocabulary and behaviour are separated (section or file)
- [ ] No non-features documented (scope guards only if they change behaviour)
- [ ] No duplication/collision with existing skills
- [ ] No time-sensitive info
- [ ] Consistent terminology
- [ ] Concrete examples included
- [ ] References one level deep
