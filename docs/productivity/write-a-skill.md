## What it does

`write-a-skill` converts settled requirements into a well-structured skill: clean steps, separated reference material, a description that triggers reliably, and a review checklist before it ships. It handles both creating a new skill and updating an existing one.

The defining constraint is right in the name of its gate: requirements must be **settled** first. The skill refuses to gather scope itself, because a shallow self-interview produces low-quality drafts, and sends you to a grilling session when the design is still fuzzy.

## When to reach for it

Type `/write-a-skill`, or the agent reaches for it automatically when a task fits.

Reach for it after a design conversation has converged and you want the result captured as a reusable skill, or when an existing skill needs revising. For updates it posts a checkpoint of intended edits and conflicts, and touches nothing until you approve. If scope isn't settled, run [grilling](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/productivity/grilling.md) first, then come back.

## The reference behind it

The skill is the *procedure*; the principles it enforces live in [writing-great-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/productivity/writing-great-skills.md): steps vs reference, progressive disclosure, completion criteria, leading words. `write-a-skill` applies that vocabulary as a workflow: branch create-vs-update, check duplication against existing skills, draft, verify against the checklist.

## It's working if

- Requirements came from a grilling session or handoff, not improvised on the spot
- The new skill's steps end on checkable completion criteria, with reference material disclosed behind links
- The description leads with the skill's leading word and lists one trigger per branch

## Where it fits

A **reach-for-it-anytime standalone**: the meta-skill that grows the system. It pairs with [writing-great-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/productivity/writing-great-skills.md), which holds the principles this one applies. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
