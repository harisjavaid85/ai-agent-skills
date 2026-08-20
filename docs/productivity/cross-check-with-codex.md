## What it does

`cross-check-with-codex` gets an independent second opinion on an artifact — a plan, diagnosis, design, or implementation — by having Codex review it while Claude reconciles the findings. Every round is preserved as a local audit record, so the review history survives the session.

The defining constraint is the fixed division of labour: **Claude authors, Codex reviews, Claude reconciles** — never the reverse, and never a merge of the two voices into one. The reviewer stays independent so its findings aren't contaminated by the author's reasoning.

## When to reach for it

Type `/cross-check-with-codex`, or the agent reaches for it automatically when a task fits.

Reach for it when an artifact matters enough that self-review isn't enough — before committing to an implementation plan, after a tricky diagnosis, or when you want blind spots surfaced. You can scope it ("focus on operational risks"), cap the rounds ("up to two reviews"), or take a single pass with no revisions.

## Prerequisites

Requires the `codex` CLI installed and authenticated on the machine — this is a two-tool orchestration, and Codex is always the reviewer.

## Where it fits

A **reach-for-it-anytime standalone** that slots in after anything produces an artifact worth verifying — commonly after [grill-with-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/grill-with-context.md) settles a design, or before [implement](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/implement.md) starts building from it. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
