# Review Record Format

## Audit Structure

```text
<review-dir>/
├── request.md
├── prompt-1.md
├── review-1.md
├── response-1.md
├── prompt-2.md
├── review-2.md
└── response-2.md
```

Use monotonically numbered rounds. The bundled script creates `prompt-N.md`, containing the exact instructions and packet sent to Codex, and a hidden state file containing the thread ID and review count.

For a canonical file artifact, record its path and revision identifier in the request or response rather than copying its contents. For a chat artifact, preserve its exact text.

## Initial Request

Create `request.md`:

```markdown
# Codex Cross-check Request

## Review Round

Initial review

## Original User Request

<verbatim request>

## Review Objective

<derived focus or comprehensive default>

## Settled Constraints And Exclusions

<constraints and explicit exclusions>

## Artifact

<exact artifact or canonical path>

## Repository State

- Starting commit: <sha>
- Working tree: <git status --short output>
```

Do not include a diff, selected evidence, Claude's reasoning, suspected weaknesses, or Claude's interpretation of the repository.

## Revision Response

After each review, create `response-N.md`:

```markdown
# Response To Codex Review <N>

## Review Round

Revision review

## Revised Artifact

<exact revised artifact or canonical path and revision identifier>

## Finding Responses

### F1: <original title>
- Claude classification: accepted | rejected with rationale | needs user decision
- Action or rationale: <what changed or why the finding is rejected>

## Verification

<commands and outcomes, or why verification was not applicable>

## Newly Settled User Decisions

<decisions made since the prior review, if any>
```
