---
name: cross-check-with-codex
description: Cross-checks an identified artifact with Codex through an independent review loop, reconciles material findings, and preserves a local audit record. Use when the user asks Claude to check, cross-check, review, or get a second opinion from Codex on a plan, diagnosis, design, implementation, or other artifact.
---

# Cross-check With Codex

Claude authors or identifies the artifact, Codex independently reviews it, and Claude reconciles the findings. This is a Claude-only orchestration skill: Codex is always the reviewer.

Read [REVIEW-FORMAT.md](REVIEW-FORMAT.md) before starting. The script automatically gives Codex the complete [REVIEW-INSTRUCTIONS.md](REVIEW-INSTRUCTIONS.md) on the initial review and compact [REVISION-INSTRUCTIONS.md](REVISION-INSTRUCTIONS.md) on resumed reviews; Claude must not copy or alter those instructions in review packets.

## Quick Start

Examples:

- "Check your implementation plan with Codex."
- "Cross-check `docs/design.md` with Codex, focusing on operational risks."
- "Have Codex review this once, but do not revise it."
- "Check the implementation with Codex, up to two reviews."

Defaults:

- Revisions are allowed for Claude-authored artifacts.
- The review budget is 5 Codex reviews.
- Stop early when both blocking issue counters are zero.
- "Review only" means no revisions and a budget of one review.
- An explicit review budget may be 1 through 5; never exceed 5.

Revision permission and review budget are independent. With a one-review budget, Claude may revise accepted findings when permitted, but must report the result as revised and not re-reviewed.

## Workflow

### 1. Resolve The Review

Identify:

- The original user request, preferably verbatim.
- The artifact to review: the latest substantive artifact matching the user's instruction, or the path the user named.
- The artifact author: Claude, user, or external.
- The review objective derived from the invocation. Use a comprehensive review by default.
- Settled constraints and explicit exclusions.
- Revision permission and review budget.

Ask for clarification only when multiple plausible artifacts exist or the requested focus conflicts with the artifact type.

Claude may revise its own artifact and a tracked document explicitly placed under review. Do not revise user-authored or external artifacts unless the user explicitly permits it. Never revise the original request or settled constraints without the user.

### 2. Create The Local Audit Record

Use:

```text
.claude/codex-reviews/<review-slug>/
```

Build `<review-slug>` from a short kebab-case task or artifact description plus a timestamp:

```text
p2a-implementation-plan-20260616-143022
```

Keep review records local. Ensure `.claude/codex-reviews/` is ignored through `.git/info/exclude`; do not modify the tracked `.gitignore` solely for this workflow.

Create the files defined in the review format. Record the starting commit SHA and `git status --short`, but do not include a diff or selected evidence in the initial review packet.

The initial packet must not include Claude's reasoning, suspected weaknesses, selected evidence, or interpretation of the repository. Codex must independently inspect the repository and establish its own evidence.

### 3. Start The Independent Review

Run the bundled script from the repository root:

```bash
<skill-dir>/scripts/codex-review.sh start \
  --packet .claude/codex-reviews/<review-slug>/request.md \
  --output .claude/codex-reviews/<review-slug>/review-1.md
```

The script uses the configured Codex defaults unless the user explicitly requests `--model` or `--reasoning`. It combines the complete initial instructions or compact revision instructions with the round packet, preserves the exact result as `prompt-N.md`, runs Codex in a read-only sandbox, captures the resumable thread ID, validates mechanical output invariants, and prints a small summary.

### 4. Validate And Classify Findings

After the script's mechanical validation, Claude validates the review semantically:

- Counters match the active blocking findings.
- Every blocking finding has a stable ID, classification, impact, and recommendation.
- `NEEDS_REVISION` findings cite evidence or identify a concrete reasoning gap.
- Request or constraint risks are separate from artifact defects.
- There are no more than three non-blocking notes.

If the output is malformed, request a corrected response in the same Codex thread. This is an operational retry and does not consume a review round.

Classify each finding:

- `accepted`: the finding is valid and will be addressed.
- `rejected with rationale`: Claude disagrees and records why.
- `needs user decision`: resolution changes a settled constraint, expands scope, or requires a consequential trade-off.

Do not blindly follow Codex. Do not continue the loop for style preferences, optional improvements, or findings already rejected with rationale unless Codex presents new concrete evidence.

### 5. Pause For User Decisions

If Codex reports any `NEEDS_USER_DECISION`, stop immediately and present:

- The decision required.
- Codex's concern.
- Claude's recommendation.
- Available alternatives and consequences.

After the user decides, update the settled constraints, revise when necessary, and resume the same Codex thread. A user-decision pause does not consume a review round.

### 6. Revise And Resume

When revisions are permitted, address accepted findings and run relevant verification. Write the round response defined in the review format.

Resume the same Codex thread:

```bash
<skill-dir>/scripts/codex-review.sh resume \
  --thread-id <thread-id> \
  --packet .claude/codex-reviews/<review-slug>/response-1.md \
  --output .claude/codex-reviews/<review-slug>/review-2.md
```

In the revision response, provide:

- The revised artifact or canonical path.
- Finding-by-finding classifications and actions.
- Rejection rationale.
- Verification results.
- Newly settled user decisions.

### 7. Stop And Report

Stop when:

- Both blocking counters are zero.
- A user decision is required.
- The review budget is exhausted.
- Codex cannot complete a valid review after one operational retry.

When the budget is exhausted with unresolved findings, treat the disagreement as requiring a user decision. Present Codex's evidence, Claude's rationale, Claude's recommendation, and the consequences of accepting or rejecting the finding. Claude must not unilaterally declare approval.

If Codex fails twice because of authentication, command failure, timeout, or malformed output, preserve the failure record and report the blocker. Claude may still present the artifact, clearly marked as not cross-checked.

Use this concise final-report shape:

```text
Codex cross-check: approved after 2 reviews.

Accepted findings: 3
Withdrawn findings: 1
Unresolved findings: 0
Verification: pnpm verify:fast passed
Audit record: .claude/codex-reviews/<review-slug>/
```

When not approved, lead with unresolved findings and required user decisions. For pre-response reviews, disclose the review outcome and number of rounds in the final answer.
