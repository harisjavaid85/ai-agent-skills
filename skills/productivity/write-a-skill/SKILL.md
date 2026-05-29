---
name: write-a-skill
description: Convert settled requirements into a well-structured agent skill (vocabulary, behaviour, progressive disclosure). Use when the user wants to create, write, or build a new skill and scope is already decided. Grill first if scope is fuzzy.
---

# Writing Skills

This skill does one thing: transform **settled requirements** into a clean, well-structured skill. It does not gather requirements itself — a shallow self-grill produces low-quality drafts and rework is needed later.

See `CONTEXT.md` for the canonical definitions of **Vocabulary**, **Behaviour**, and **Progressive disclosure**. Work the numbered steps below in order; templates to use are in `FORMAT.md`.

## Workflow

### 1. Confirm settled requirements

Before writing, confirm requirements are settled. There are three cases:

1. **Grilled in this conversation** — a grilling session earlier in the current context already settled scope. Write from that.
2. **Handoff doc** — the user has (or points you to) a handoff document capturing the settled design. Read it, then write.
3. **Cold start** — neither of the above. Do **not** improvise a requirements interview. Recommend the user run `/grill-me` (general design) or `/grill-with-context` (when the skill introduces or depends on canonical domain terms), then re-run this skill.

If the user declines grilling and wants a draft anyway, collect only the **irreducible inputs** — the minimum needed to emit a valid skill:

- **name** (kebab-case)
- **trigger** — the "Use when…" for the description
- **one sentence** on what it does (core behaviour)

Draft a best-effort pass from those and label it as rough, since scope wasn't grilled. Never invent scope, edge cases, or alternatives to fill the gap.

### 2. Check duplication & collision

Scan the existing skills first:

- **Overlap** — does a skill already cover this? ("`triage` already classifies issues — is this new skill actually distinct?") If it overlaps, raise it before creating a redundant skill.
- **Vocabulary collision** — does the new skill reuse a term that `CONTEXT.md` already defines differently? Reconcile the term before writing.

### 3. Draft

#### Separate vocabulary from behaviour

Keep the nouns and the verbs apart — the **progressive disclosure** the skill should embody.

- **Behaviour** always lives in `SKILL.md` — process, decision rules, steps.
- **Vocabulary** — a few terms or a small mapping go in a `## Vocabulary` section near the top of `SKILL.md`; a verbatim template/format/spec, anything long, or anything that would push `SKILL.md` past ~100 lines goes in one separate file (`VOCABULARY.md` or `FORMAT.md`). Keep references one level deep.

Never interleave "here's the format of X" with "here's when you do Y" — that smear makes drafts noisy to edit.

#### Cut non-features

The produced skill is for whoever runs it later, not a record of the grilling conversation.

- **Cut** all process archaeology: "we considered X but decided against it", "this skill does not build Y", rationale for rejected alternatives. None of it helps a future reader of the finished skill.
- **Keep only** a terse, present-tense **scope guard** when the agent would plausibly overstep without it ("Only triages; never edits code"). The test: does the line stop the agent from doing the wrong thing _right now_? If it just explains a past decision, cut it.

Whether a cut decision deserves an ADR is the grilling skill's call at runtime — this skill doesn't record rejected decisions anywhere.

#### Add scripts when deterministic

Add utility scripts when the operation is deterministic (validation, formatting), the same code would be generated repeatedly, or errors need explicit handling. Scripts save tokens and improve reliability vs generated code.

#### Write a concise description

The description is **the only thing the agent sees** when deciding which skill to load, surfaced in the system prompt alongside all other installed skills. Keep it tight and concrete, following the **Description format** in `FORMAT.md`.

### 4. Review checklist

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
