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
├── response-2.md
└── .review-state
```

Use monotonically numbered rounds. The bundled script creates `prompt-N.md`, containing the exact instructions and packet sent to the Reviewer, and `.review-state`, described below.

For a canonical file artifact, record its path and revision identifier in the request or response rather than copying its contents. For a chat artifact, preserve its exact text.

## Review State

The script writes `.review-state` from the values passed on `start` and updates it after every round. It is the record of who took part, and the source of the final report's `Requester:` and `Reviewer:` lines. Never edit it by hand.

```text
SESSION_ID=a8f1b309-4590-4c89-94a3-6892b5667e86
REVIEW_COUNT=2
AUTHOR=requester
REQUESTER_HARNESS=claude
REQUESTER_MODEL=claude-opus-5-5
REQUESTER_EFFORT=unknown
REVIEWER_HARNESS=codex
REVIEWER_MODEL=gpt-6-astra
REVIEWER_EFFORT=high
REVIEWER_MODEL_RESOLVED=gpt-6-astra
```

- `AUTHOR` and the `REQUESTER_*` values are what the Requester stated on `start`. `unknown` means the Requester could not determine its own value.
- `REVIEWER_MODEL` and `REVIEWER_EFFORT` are what was passed to the Reviewer harness: the values the user named, else the script's defaults for that harness.
- `REVIEWER_MODEL_RESOLVED` is the model the Reviewer harness reported running. Empty means it reported none. Effort is never reported.

In the report, give each participant as `<harness> / <model> / effort <effort>`:

- Requester: the `REQUESTER_*` values as recorded.
- Reviewer model: `REVIEWER_MODEL_RESOLVED`, else `REVIEWER_MODEL`.
- Reviewer effort: `REVIEWER_EFFORT`.

## Initial Request

Create `request.md`:

```markdown
# Cross-check Request

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

Do not include a diff, selected evidence, the Requester's reasoning, suspected weaknesses, or the Requester's interpretation of the repository.

## Revision Response

After each review, create `response-N.md`:

```markdown
# Response To Review <N>

## Review Round

Revision review

## Revised Artifact

<exact revised artifact or canonical path and revision identifier>

## Finding Responses

### F1: <original title>
- Requester classification: accepted | rejected with rationale | needs user decision
- Action or rationale: <what changed or why the finding is rejected>

## Verification

<commands and outcomes, or why verification was not applicable>

## Newly Settled User Decisions

<decisions made since the prior review, if any>
```
