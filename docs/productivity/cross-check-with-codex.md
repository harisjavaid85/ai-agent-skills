## What it does

`cross-check-with-codex` gets an independent second opinion on an artifact (a plan, diagnosis, design, or implementation) by having Codex review it while Claude reconciles the findings. Every round is preserved as a local audit record, so the review history survives the session.

The defining constraint is the fixed division of labour: **Claude authors, Codex reviews, Claude reconciles**, never the reverse, and never a merge of the two voices into one. The reviewer stays independent so its findings aren't contaminated by the author's reasoning.

## When to reach for it

Type `/cross-check-with-codex`, or the agent reaches for it automatically when a task fits.

Reach for it when an artifact matters enough that self-review isn't enough: before committing to an implementation plan, after a tricky diagnosis, or when you want blind spots surfaced. You can scope it ("focus on operational risks"), cap the rounds ("up to two reviews"), or take a single pass with no revisions.

## Prerequisites

Requires the `codex` CLI installed and authenticated on the machine, because this is a two-tool orchestration, and Codex is always the reviewer.

## Common questions

**Why does it fail inside a Docker container?**
Codex's reviewer [sandbox](https://www.aihero.dev/ai-coding-dictionary/sandbox) needs a user namespace, and Docker's default security profile denies one, so the script refuses rather than run a review that reads nothing. Set `CROSS_CHECK_REVIEWER_SANDBOX=external` when the container is what isolates the review, and Codex runs without its own sandbox while the script still fails, and undoes, any round that changes your files; the [to-done](https://github.com/harisjavaid85/ai-agent-skills/tree/main/skills/in-progress/to-done) loop does this for its containers. Loosening Docker's profile instead is the trade the repo rejected in [ADR-0006](https://github.com/harisjavaid85/ai-agent-skills/blob/main/.agents/adr/0006-cross-check-trusts-the-container-not-codex-sandbox.md).

## It's working if

- Each round leaves a review file under `.claude/codex-reviews/<review-slug>/`, and your working tree is exactly as it was before the round.
- A Codex whose reviewer sandbox cannot start stops the round with a message instead of a review that quietly read nothing, and one that edits a file fails the round with the edit already undone.
- The final report gives a review count and an accepted, withdrawn, and unresolved tally, and never claims approval for findings left open.

## Where it fits

A **reach-for-it-anytime standalone** that slots in after anything produces an artifact worth verifying, commonly after [grill-with-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/grill-with-context.md) settles a design, or before [implement](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/implement.md) starts building from it. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
