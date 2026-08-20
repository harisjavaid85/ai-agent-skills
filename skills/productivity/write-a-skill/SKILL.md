---
name: write-a-skill
description: Convert settled requirements into a well-structured agent skill with clear steps and reference. Use when the user wants to create, update, refactor, or iterate on a skill after its scope is settled.
---

# Writing Skills

This skill does one thing: transform **settled requirements** into a clean, well-structured skill. It does not gather requirements itself, because a shallow self-grill produces low-quality drafts and rework is needed later.

The terms below (**steps**, **reference**, **progressive disclosure**, **completion criterion**, **leading word**) and the principles behind the rules are in [`../writing-for-agents/SKILL.md`](../writing-for-agents/SKILL.md); what changes because the document is a skill (frontmatter, the invocation choice, router skills) is in [`../writing-for-agents/SKILL-MECHANICS.md`](../writing-for-agents/SKILL-MECHANICS.md). Work the numbered steps below in order; templates to use are in `FORMAT.md`.

## Workflow

### 1. Branch: create vs update

First, check whether a `SKILL.md` already exists at the target path.

- **No existing file → Create branch.** Continue with "Create: confirm settled requirements" below, then steps 2–4.
- **Existing file → Update branch.** Jump to "Update: checkpoint" below, then step 4. Skip step 2 (duplication/collision was already settled when the skill was first written; only re-check if the conversation says scope is shifting). Step 3's drafting rules apply as constraints, verified by the step 4 checklist rather than re-walked.

#### Create: confirm settled requirements

Before writing, confirm requirements are settled. There are three cases:

1. **Grilled in this conversation**: a grilling session earlier in the current context already settled scope. Write from that.
2. **Handoff doc**: the user has (or points you to) a handoff document capturing the settled design. Read it, then write.
3. **Cold start**: neither of the above. Do **not** improvise a requirements interview. Recommend the user run `/grill-me` (general design) or `/grill-with-context` (when the skill introduces or depends on canonical domain terms), then re-run this skill.

If the user declines grilling and wants a draft anyway, collect only the **irreducible inputs**, the minimum needed to emit a valid skill:

- **name** (kebab-case)
- **trigger**: the "Use when…" for the description
- **one sentence** on what it does (core behaviour)

Draft a best-effort pass from those and label it as rough, since scope wasn't grilled. Never invent scope, edge cases, or alternatives to fill the gap.

#### Update: checkpoint

Read the existing skill files in full before editing. Then post a **checkpoint** and stop for confirmation. The checkpoint has two parts:

1. **Intended edits**: one bullet per change, in the form *decision from conversation → section of `SKILL.md` (or other file) it touches*.
2. **Conflicts**: any edit that would violate an existing rule in the skill, or override a structural decision (see preservation rule below). If none, write "none".

Only edit after the user confirms.

**Preservation rule.** Preserve the existing skill's structural decisions (file split, reference location, scope guards, section ordering) unless the checkpoint explicitly overrides them. Moving inline what was in a separate file (or vice versa) is an override, not a stylistic edit, and must appear in the conflicts list.

### 2. Check duplication & collision

Scan the existing skills first:

- **Overlap**: does a skill already cover this? ("`triage` already classifies issues, so is this new skill actually distinct?") If it overlaps, raise it before creating a redundant skill.
- **Vocabulary collision**: does the new skill reuse a term that the repo's `CONTEXT.md` already defines differently? Reconcile the term before writing.

### 3. Draft

#### Separate steps from reference

Keep the doing and the knowing apart: the **progressive disclosure** the skill should embody.

- **Steps** always live in `SKILL.md`: ordered actions, process, decision rules. Each step ends on a checkable **completion criterion**.
- **Reference**: definitions, templates, formats, and mappings go in a section of `SKILL.md` when small, or in a separate disclosed file (`REFERENCE.md`, `FORMAT.md`, or a focused file) when shared, independently reusable, or needed only on some **branches**. Never split based on line count alone. Keep references one level deep.

Never interleave "here's the format of X" with "here's when you do Y", because that smear makes drafts noisy to edit.

#### Cut non-features

The produced skill is for whoever runs it later, not a record of the grilling conversation.

- **Cut** all process archaeology: "we considered X but decided against it", "this skill does not build Y", rationale for rejected alternatives. None of it helps a future reader of the finished skill.
- **Keep only** a terse, present-tense **scope guard** when the agent would plausibly overstep without it ("Only triages; never edits code"). The test: does the line stop the agent from doing the wrong thing _right now_? If it just explains a past decision, cut it.
- Prune everything else per `writing-for-agents`: run the **no-op** test sentence by sentence, state the **positive** rather than steering by **negation**, and prefer a strong **leading word** over a restated triad.

Whether a cut decision deserves an ADR is the grilling skill's call at runtime; this skill doesn't record rejected decisions anywhere.

#### Add scripts when deterministic

Add utility scripts when the operation is deterministic (validation, formatting), the same code would be generated repeatedly, or errors need explicit handling. Scripts save tokens and improve reliability vs generated code.

#### Write a concise description

The description is **the only thing the agent sees** when deciding which skill to load, surfaced in the system prompt alongside all other installed skills. Follow the **Description format** in `FORMAT.md`, and the context-pointer rules in `writing-for-agents`: front-load the skill's **leading word**, one trigger per **branch**, cut identity already in the body.

### 4. Review checklist

After drafting, verify:

- [ ] **Create:** requirements were settled (grilled, handoff, or irreducible-inputs override). **Update:** checkpoint approved by user before editing.
- [ ] Description matches the Description format in `FORMAT.md`
- [ ] Steps and reference are separated (section or file)
- [ ] Each step ends on a checkable completion criterion
- [ ] No non-features documented (scope guards only if they change behaviour)
- [ ] Deterministic operations use scripts where appropriate
- [ ] No duplication/collision with existing skills
- [ ] No time-sensitive info
- [ ] Consistent terminology
- [ ] Concrete examples included
- [ ] References one level deep
