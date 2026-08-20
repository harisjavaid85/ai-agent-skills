## What it does

`implement` turns one concrete work item into reviewed, verified code and leaves the result uncommitted for a separate commit step. Its source is the exact issue or path you name, or the settled current conversation when you supply no argument; it never selects work from a lifecycle or ticket collection.

It executes autonomously once invoked. Ordinary gaps receive the smallest conservative interpretation, while genuine hard blockers produce a structured `BLOCKED` result instead of an open-ended planning exchange.

## When to reach for it

Type `/implement` to invoke it directly. The agent may also reach for it on its own once a work item is settled and named, which is what lets an orchestrating skill dispatch it one ticket at a time.

Reach for it when one issue, local plan, or settled conversation is ready to become code. Name multiple sources only when you want them combined explicitly. For a multi-ticket spec, choose one ready ticket before invoking `implement`; [to-tickets](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-tickets.md) handles the decomposition and ordering.

## Prerequisites

A GitHub issue source requires the issue-tracker wiring created by [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md). Repository agent instructions remain authoritative for implementation and verification commands.

`implement` starts from a clean working tree when possible. If work is already present, it asks whether those changes belong to the work item or should remain outside the implementation and review.

## Autonomous red-green

The build advances through **red-green slices** at public **seams**. Seams named by the work source are already agreed; for any behaviour without one, the agent chooses the narrowest existing public interface and records the choice. Each behavioural slice starts red and becomes green before the next one begins. Changes without meaningful observable behaviour do not acquire artificial tests.

The source remains the authority throughout. Existing patterns and compatibility resolve ordinary ambiguity without reopening the plan, keeping the command suitable for unattended loops as well as interactive use.

## One review, clean handoff

After implementation, `implement` runs [code-review](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/code-review.md) once over the complete included working tree. It fixes findings it judges valid, records why it declines any others, and runs the repository's prescribed verification after remediation. The review is intentionally bounded to one pass.

The terminal report ends in `COMPLETE` or `BLOCKED` and leaves issue state, PR state, and Git history untouched. Use [commit](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/commit.md) when you are ready to turn the working tree into history; use [cross-check-with-codex](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/productivity/cross-check-with-codex.md) separately when the implementation warrants an independent second-model review.

## It's working if

- Exactly one explicit work item defines the scope.
- Behaviour is built in red-green slices through public seams.
- One Standards + Spec review is remediated before final verification.
- The terminal reports `COMPLETE` or a concrete `BLOCKED` reason.
- The completed working tree remains uncommitted.

## Where it fits

`implement` is the autonomous build-and-review step in the main chain:

```txt
grill-with-context → to-spec → to-tickets → implement → commit → open-pr
```

Its upstream neighbour is [to-tickets](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-tickets.md), which produces one tracer-bullet ticket per invocation; internally it drives [tdd](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/tdd.md) and [code-review](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/code-review.md). [Ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
