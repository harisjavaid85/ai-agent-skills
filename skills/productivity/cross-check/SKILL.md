---
name: cross-check
description: Cross-checks an identified artifact with an independent reviewer agent (Codex or Claude, at a chosen model and effort) through a review loop, reconciles material findings, and preserves a local audit record. Use when the user asks to check, cross-check, review, or get a second opinion from Codex, Claude, or another model on a plan, diagnosis, design, implementation, or other artifact.
---

# Cross-check

The Requester authors or identifies the artifact, an independent Reviewer reviews it, and the Requester reconciles the findings. Either Claude Code or Codex can be the Requester, and either can be the Reviewer.

Read [REVIEW-FORMAT.md](REVIEW-FORMAT.md) before starting. The script automatically gives the Reviewer the complete [REVIEW-INSTRUCTIONS.md](REVIEW-INSTRUCTIONS.md) on the initial review and compact [REVISION-INSTRUCTIONS.md](REVISION-INSTRUCTIONS.md) on resumed reviews; the Requester must not copy or alter those instructions in review packets.

## Terms

- **Requester**: you, the agent running this skill. You resolve the review, author or identify the artifact, write the packets, classify and reconcile findings, revise when permitted, and report.
- **Reviewer**: the agent that independently reviews the artifact through the bundled script, identified by harness, model, and effort.
- **Harness**: the agent CLI that runs an agent: `codex` or `claude`.
- **Model**: the model the harness runs, passed through unchanged. When omitted, the script's default for that harness applies.
- **Effort**: the reasoning-effort level, passed through unchanged and never mapped between harnesses. Codex accepts `minimal`, `low`, `medium`, `high`, `xhigh`; Claude Code accepts `low`, `medium`, `high`, `xhigh`, `max`. The harness rejects an invalid value.
- **Author**: who wrote the artifact under review: `requester`, `user`, or `external`. It governs revision permission. You cross-checking your own plan is `requester`; the user's `docs/design.md` is `user`; another agent's implementation you were asked to review is `external`.
- **Review session**: the Reviewer's resumable conversation (a Codex thread or a Claude session), named by the script's `SESSION_ID`.
- **Audit record**: the local directory `.cross-checks/<review-slug>/` holding every round's packet, prompt, review, and response, and the review state recording who took part.
- **Round**: one Reviewer pass (`start` or `resume`) producing `review-N.md`.

## Quick Start

Examples:

- "Check your implementation plan with Codex."
- "Cross-check `docs/design.md` with Codex, focusing on operational risks."
- "Cross-check this plan with Claude Opus at high effort."
- "Have Codex review it with gpt-6.1-sol."
- "Have Codex review this once, but do not revise it."
- "Check the implementation with Codex, up to two reviews."

Defaults:

- The Reviewer's harness is the other harness from yours: a Claude Code Requester gets `codex`, a Codex Requester gets `claude`. Use the same harness only when the user asks for it.
- The Reviewer's model and effort are the script's defaults for that harness, which `<skill-dir>/scripts/review.sh --help` lists.
- Revisions are allowed for artifacts whose Author is `requester`.
- The review budget is 5 rounds.
- Stop early when both blocking issue counters are zero.
- "Review only" means no revisions and a budget of one round.
- An explicit review budget may be 1 through 5; never exceed 5.

Revision permission and review budget are independent. With a one-round budget, you may revise accepted findings when permitted, but must report the result as revised and not re-reviewed.

## Workflow

### 1. Resolve The Review

Identify:

- The original user request, preferably verbatim.
- The artifact to review: the latest substantive artifact matching the user's instruction, or the path the user named.
- The Author: `requester`, `user`, or `external`.
- The Reviewer's harness, model, and effort, from the invocation ("with claude opus at high effort"), else the defaults above.
- Your own harness, model, and effort as the Requester, from what you know about yourself or what the user stated. Record any value you cannot determine as `unknown`; never guess it.
- The review objective derived from the invocation. Use a comprehensive review by default.
- Settled constraints and explicit exclusions.
- Revision permission and review budget.

Ask for clarification only when multiple plausible artifacts exist, the requested focus conflicts with the artifact type, or the requested Reviewer harness is ambiguous.

You may revise an artifact whose Author is `requester`, and a tracked document explicitly placed under review. Revise a `user` or `external` artifact only when the user explicitly permits it. Never revise the original request or settled constraints without the user.

**Complete when:** the artifact, Author, Reviewer, Requester, objective, constraints, revision permission, and budget are each identified.

### 2. Create The Local Audit Record

Use:

```text
.cross-checks/<review-slug>/
```

at the repository root. Build `<review-slug>` from a short kebab-case task or artifact description plus a timestamp:

```text
p2a-implementation-plan-20260616-143022
```

Keep review records local. Ensure `.cross-checks/` is ignored through `.git/info/exclude`; leave the tracked `.gitignore` untouched.

Create `request.md` as defined in the review format. Record the starting commit SHA and `git status --short`, but do not include a diff or selected evidence in the initial review packet.

The initial packet must not include your reasoning, suspected weaknesses, selected evidence, or interpretation of the repository. The Reviewer must independently inspect the repository and establish its own evidence.

**Complete when:** the directory is git-excluded and holds `request.md`.

### 3. Start The Independent Review

Run the bundled script from the repository root:

```bash
<skill-dir>/scripts/review.sh start \
  --author <requester|user|external> \
  --requester-harness <codex|claude> --requester-model <model|unknown> --requester-effort <level|unknown> \
  --harness <codex|claude> [--model M] [--effort L] \
  --packet .cross-checks/<review-slug>/request.md \
  --output .cross-checks/<review-slug>/review-1.md
```

Pass the Author and your own harness, model, and effort from step 1, and always pass `--harness`. Pass `--model` and `--effort` only when the user named them. The script combines the instructions with the round packet, preserves the exact result as `prompt-N.md`, runs the Reviewer read-only, records both participants and the Author in `.review-state`, validates mechanical output invariants, and prints `SESSION_ID`, the two counters, and `REVIEW_FILE`. Resumed rounds keep everything set on start.

How the Reviewer stays read-only:

- A Codex Reviewer runs in Codex's own read-only sandbox (`CROSS_CHECK_REVIEWER_SANDBOX=native`, the default), or without one when the caller already isolates it, such as in a container (`external`).
- A Claude Reviewer runs with harness-enforced permissions: every tool call that writes is denied, no settings file can pre-approve one, and the file-writing tools are withheld. It can run read-only commands but no verification that writes anything, even to `/tmp`, so it reviews by reading.

`external` exists because Codex's sandbox needs an unprivileged user namespace that a default Docker container denies, and when the sandbox cannot start Codex still exits 0 having read nothing; under `native` the script therefore refuses to start when the sandbox cannot. For every harness and mode, the script snapshots the repository before the round and fails, and undoes, any round that changed the working tree, index, branch, or HEAD.

**Complete when:** the script printed `SESSION_ID` and both counters.

### 4. Validate And Classify Findings

After the script's mechanical validation, validate the review semantically:

- Counters match the active blocking findings.
- Every blocking finding has a stable ID, classification, impact, and recommendation.
- `NEEDS_REVISION` findings cite evidence or identify a concrete reasoning gap.
- Request or constraint risks are separate from artifact defects.
- There are no more than three non-blocking notes.

If the output is malformed, request a corrected response by resuming the same review session. This is an operational retry and does not consume a round.

Classify each finding:

- `accepted`: the finding is valid and will be addressed.
- `rejected with rationale`: you disagree and record why.
- `needs user decision`: resolution changes a settled constraint, expands scope, or requires a consequential trade-off.

Do not blindly follow the Reviewer. Do not continue the loop for style preferences, optional improvements, or findings already rejected with rationale unless the Reviewer presents new concrete evidence.

**Complete when:** every finding carries one of the three classifications.

### 5. Pause For User Decisions

If the Reviewer reports any `NEEDS_USER_DECISION`, stop immediately and present:

- The decision required.
- The Reviewer's concern.
- Your recommendation.
- Available alternatives and consequences.

After the user decides, update the settled constraints, revise when necessary, and resume the same review session. A user-decision pause does not consume a round.

**Complete when:** the user has decided every open decision, or no decision was needed.

### 6. Revise And Resume

When revisions are permitted, address accepted findings and run relevant verification. Write the round response defined in the review format.

Resume the same review session:

```bash
<skill-dir>/scripts/review.sh resume \
  --session-id <session-id> \
  --packet .cross-checks/<review-slug>/response-1.md \
  --output .cross-checks/<review-slug>/review-2.md
```

In the revision response, provide:

- The revised artifact or canonical path.
- Finding-by-finding classifications and actions.
- Rejection rationale.
- Verification results.
- Newly settled user decisions.

**Complete when:** the resumed round printed its counters, or a stop condition in step 7 applies.

### 7. Stop And Report

Stop when:

- Both blocking counters are zero.
- A user decision is required.
- The review budget is exhausted.
- The Reviewer cannot complete a valid review after one operational retry.

When the budget is exhausted with unresolved findings, treat the disagreement as requiring a user decision. Present the Reviewer's evidence, your rationale, your recommendation, and the consequences of accepting or rejecting the finding. Never declare approval unilaterally.

A reviewer sandbox that cannot start, or a review that changed the repository, is not an operational retry: report it as the blocker. The script has already undone any such change and lists it.

If the Reviewer fails twice because of authentication, command failure, timeout, or malformed output, preserve the failure record and report the blocker. You may still present the artifact, clearly marked as not cross-checked.

Use this concise final-report shape, giving each participant from `.review-state` as the review format describes:

```text
Cross-check: approved after 2 reviews.

Requester: claude / claude-opus-5-5 / effort unknown
Reviewer: codex / gpt-6-astra / effort high
Accepted findings: 3
Withdrawn findings: 1
Unresolved findings: 0
Verification: pnpm verify:fast passed
Audit record: .cross-checks/<review-slug>/
```

When not approved, lead with unresolved findings and required user decisions. For pre-response reviews, disclose the review outcome and number of rounds in the final answer.

**Complete when:** the report is delivered in this shape.
