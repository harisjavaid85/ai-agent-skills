## What it does

`commit` stages and commits your working-tree changes: it groups them into a sensible commit plan and writes a concise, tagged message for each, following the repo's convention. It only commits: no pushing, no branch operations.

The defining constraint is **work-item atomicity**: everything required to deliver one logical work item lands in one commit, including its implementation, schema or migrations, tests, fixtures, generated outputs, and documentation. Tags and file categories never determine the split; genuinely independent work items still split even when staged together.

## When to reach for it

Type `/commit`, or the agent reaches for it automatically when a task fits.

Reach for it whenever the working tree should become commits. Plain `/commit` proposes the plan and waits; your approval is the go-ahead. `/commit auto` commits best-effort without blocking: it takes the safe default wherever review mode would ask (excluding sensitive files, best-fit tag) and prints the full plan as a reviewable trail.

## Tags

Each commit gets a **commit tag** (`Feature`, `Fix`, `Doc`, `Refactor`, and friends) prefixed to an imperative subject, e.g. `[Feature] Add parser`. The vocabulary is configurable per repo by [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md), so the skill matches your house style (including Conventional Commits) instead of imposing one.

## It's working if

- You see a plan, commit groups with files and messages, before anything is committed (review mode)
- Each commit is one logical work item; its supporting implementation, tests, migrations, and docs stay in the same group
- A multi-commit plan names the independent work item in each group instead of splitting by tag, directory, or artifact type
- Subjects read `[Tag] Imperative summary` in the repo's own tag vocabulary

## Where it fits

The tail of the build chain: after [implement](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/implement.md) or any manual change, `commit` turns the diff into history, and [open-pr](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/open-pr.md) takes it from there. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
