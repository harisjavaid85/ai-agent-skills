## What it does

`cross-check` gets an independent second opinion on an artifact (a plan, diagnosis, design, or implementation). The agent you are working with is the **Requester**: it hands the artifact to a **Reviewer**, another agent run through its own [harness](https://www.aihero.dev/ai-coding-dictionary/harness) (Codex or Claude Code) at the model and effort you choose, then reconciles what comes back. Every round is preserved as a local audit record that names both sides, so the review history survives the session.

The Reviewer stays independent: it gets the artifact and the request, never the Requester's reasoning or suspicions, and it gathers its own evidence from the repository. The Requester judges each finding rather than obeying it, and never merges the two voices into one.

## When to reach for it

Type `/cross-check`, or the agent reaches for it automatically when a task fits ("get a second opinion from Codex", "have Claude review this").

Reach for it when an artifact matters enough that self-review isn't enough: before committing to an implementation plan, after a tricky diagnosis, or when you want blind spots surfaced. You can scope it ("focus on operational risks"), cap the rounds ("up to two reviews"), or take a single pass with no revisions. For a review of a branch's code against the repo's standards and its spec, use [code-review](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/code-review.md) instead.

## Prerequisites

The Reviewer's CLI (`codex` or `claude`) installed and logged in on the machine, plus `jq`. The skill writes its records into `.cross-checks/<review-slug>/` at the repository root and keeps that directory out of Git through `.git/info/exclude`.

## Requester and Reviewer

The **Requester** is whichever agent you are talking to; the **Reviewer** is the one you pick for this review, by harness, model, and effort, in plain words:

| You say | Reviewer |
|---|---|
| nothing about the Reviewer | the other harness from the one you are in, at the [script's default model](https://github.com/harisjavaid85/ai-agent-skills/blob/main/skills/productivity/cross-check/scripts/review.sh) for that harness and `high` effort |
| "with Codex" / "with Claude" | that harness, even when it is the one you are in |
| "with Claude Opus at high effort" | that harness, model, and effort, passed through as given |

The Requester keeps the judgement: it classifies each finding as accepted, rejected with rationale, or needing your decision, and the Reviewer then rechecks that reasoning in the next round.

## Common questions

**Where did the Codex-only cross-check go?**
It is this skill, renamed. It used to hard-wire Claude as the Requester and Codex as the Reviewer; now either agent can play either role. Invoke `/cross-check` instead, and look for new records under `.cross-checks/`; records from before the rename stay where they were.

**Why does a Codex review fail inside a Docker container?**
Codex's reviewer [sandbox](https://www.aihero.dev/ai-coding-dictionary/sandbox) needs a user namespace, and Docker's default security profile denies one, so the script refuses rather than run a review that reads nothing. Set `CROSS_CHECK_REVIEWER_SANDBOX=external` when the container is what isolates the review, and Codex runs without its own sandbox while the script still fails, and undoes, any round that changes your files; the [to-done](https://github.com/harisjavaid85/ai-agent-skills/tree/main/skills/in-progress/to-done) loop does this for its containers. Loosening Docker's profile instead is the trade the repo rejected in [ADR-0006](https://github.com/harisjavaid85/ai-agent-skills/blob/main/.agents/adr/0006-cross-check-trusts-the-container-not-codex-sandbox.md). The setting only concerns Codex; a Claude Reviewer behaves the same either way.

**Why didn't the Claude reviewer run my tests?**
A Claude Reviewer is held to read-only commands by permissions the harness enforces: anything that writes, even to `/tmp`, is denied, and most test runners, builds, and caching linters write. It reviews by reading. Pick Codex when running verification matters: under `CROSS_CHECK_REVIEWER_SANDBOX=external` it can write outside the repository, though under the default `native` its own sandbox also forbids writes.

**Can Claude review Claude's work?**
Yes, when you ask for it, and the record logs both sides. A same-family review is a weaker second opinion, though, so pick a different model or the other harness when independence matters.

**Which effort values work?**
Whatever the Reviewer's harness accepts, passed through unchanged: Codex takes `minimal`, `low`, `medium`, `high`, `xhigh`; Claude Code takes `low`, `medium`, `high`, `xhigh`, `max`. The harness rejects anything else.

**Why does the Requester line say `unknown`?**
The Requester reports on itself, and an agent often cannot see its own settings: effort is usually hidden, and under Codex the model is too. It writes `unknown` rather than guess. The Reviewer line never needs it, because the script always passes the Reviewer an explicit model and effort, and records them.

## It's working if

- Each round leaves a review file under `.cross-checks/<review-slug>/`, and your working tree and staging area are exactly as they were before the round.
- That directory's `.review-state` names the Requester and the Reviewer, each with harness, model, and effort, and who wrote the artifact.
- A Reviewer that edits a file, stages one, or commits fails the round with the change already undone, and a Codex whose sandbox cannot start stops with a message instead of a review that quietly read nothing.
- The final report carries `Requester:` and `Reviewer:` lines, a review count, and an accepted, withdrawn, and unresolved tally, and never claims approval for findings left open.

## Where it fits

A **reach-for-it-anytime standalone** that slots in after anything produces an artifact worth verifying, commonly after [grill-with-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/grill-with-context.md) settles a design, or after [implement](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/implement.md) leaves a change worth a second look. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
