---
name: implement
description: "Implement one concrete work item autonomously, test-first, and leave the reviewed changes uncommitted. Use when the user wants a named issue, ticket, plan, or settled conversation built end to end, mentions implementing or building a specific work item."
---

# Implement

Implement exactly one work item from an explicit source. An issue, path, or settled conversation is a work item; a lifecycle slug or collection of tickets is not.

## 1. Resolve the source

Use the source named by the invocation:

- An issue URL or number means that exact issue. Fetch it through the repository's documented issue-tracker workflow.
- A path means that exact local plan, spec, or ticket.
- No argument means the settled current conversation.
- Use more than one source only when the user explicitly asks to combine them. In that case, later explicit user instructions override conflicts; incidental conversation does not expand scope.

Do not search for or guess a work item. If the source is a lifecycle slug, an unresolved collection, or absent from both the invocation and conversation, emit the final `BLOCKED` report and stop.

**Complete when:** one authoritative work item and any explicit overrides are identified.

## 2. Establish the baseline

**Repository guidance is binding.** Read the repository's agent instructions and every authoritative convention, standard, and guideline they point to for issue access, implementation, review, and verification. Apply that guidance throughout the run. Record `git rev-parse HEAD` as the review fixed point and inspect `git status --short`.

When the working tree is dirty, ask the user to classify the existing changes:

- **Fold in**: include them in this work item and its review.
- **Ignore**: preserve those paths and exclude them from implementation and review.

If implementation later needs an ignored path, ask whether to fold it in before editing it.

**Complete when:** the binding repository guidance, fixed point, and included and excluded paths are identified.

## 3. Build in red-green slices

Proceed without a plan-approval pause. For behavioural implementation, collect the public seams named by the source; where a behaviour has none, choose and record the narrowest existing public seam. Invoke `/tdd` once for the work item with those seams. Implement changes without meaningful observable behaviour directly.

Resolve ordinary ambiguity with the smallest conservative interpretation permitted by the binding repository guidance identified in step 2 and relevant existing patterns: preserve compatibility and avoid speculative behaviour. Continue until every source requirement is implemented. For a hard obstacle such as unavailable required infrastructure, irreconcilable requirements, or an operation with no safe default, emit the final `BLOCKED` report with the partial state and stop.

Apply the verification instructions identified in step 2. When none exist, use applicable existing project scripts; do not install or configure verification tooling solely to create a check.

**Complete when:** every source requirement is implemented through the applicable red-green slices, or a concrete hard blocker is identified.

## 4. Review and remediate once

Run the `/code-review` skill exactly once. Pass it:

- The fixed point from step 2.
- The exact work source and explicit overrides from step 1.
- Any paths excluded in step 2.

Judge every finding. A finding that demonstrates a breach of the work source or binding repository guidance is valid and must be fixed. Fix other findings that are valid for the work item and record a concise rationale for each declined finding. Do not rerun `/code-review`. After remediation, run the verification required by the repository's instructions, or the existing project scripts selected in step 3.

**Complete when:** every review finding has a disposition and post-remediation verification has completed or produced a concrete blocker.

## 5. Report the handoff

Print the final report in the terminal. Leave the working tree uncommitted and leave issue and PR state unchanged. Use `COMPLETE` only when the source is implemented, accepted review findings are fixed, and required verification passes; otherwise use `BLOCKED`.

**Complete when:** the report below is emitted, with `/commit` named as the next step only for `COMPLETE`.

## Final report

```markdown
## Implementation

Status: COMPLETE | BLOCKED
Source: <issue, path, or current conversation>
Fixed point: <starting SHA>

### Changes

- <behavioural outcome>

### TDD

- Seams: <public interfaces>
- Red-green slices: <brief summary>
- Exceptions: <non-behavioural changes and why no test applied, if any>

### Code review

- Status: completed once | not run: <blocker>
- Findings accepted and fixed: <count; omit when not run>
- Findings declined: <count and concise rationale; omit when not run>

### Verification

- `<command>`: <outcome>

### Assumptions or blockers

- <material assumptions, warnings, or blockers; omit when empty>

Working tree intentionally left uncommitted.
Next step: `/commit` | <resolve blocker>
```
