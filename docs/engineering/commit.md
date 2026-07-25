Quickstart:

```bash
npx skills add harisjavaid85/ai-agent-skills --skill=commit
```

```bash
npx skills update commit
```

[Source](https://github.com/harisjavaid85/ai-agent-skills/tree/main/skills/engineering/commit)

## What it does

`commit` stages and commits your working-tree changes: it groups them into a sensible commit plan and writes a concise, tagged message for each, following the repo's convention. It only commits — no pushing, no branch operations.

The defining constraint is **grouping by logical change, not by file category**: everything that makes up one coherent change lands in one commit even when it spans docs, code, and config — and genuinely independent changes always split, even when staged together.

## When to reach for it

Type `/commit`, or the agent reaches for it automatically when a task fits.

Reach for it whenever the working tree should become commits. Plain `/commit` proposes the plan and waits — your approval is the go-ahead. `/commit auto` commits best-effort without blocking: it takes the safe default wherever review mode would ask (excluding sensitive files, best-fit tag) and prints the full plan as a reviewable trail.

## Tags

Each commit gets a **commit tag** — `Feature`, `Fix`, `Doc`, `Refactor`, and friends — prefixed to an imperative subject, e.g. `[Feature] Add parser`. The vocabulary is configurable per repo by [setup-repo-skills](https://aihero.dev/skills-setup-repo-skills), so the skill matches your house style (including Conventional Commits) instead of imposing one.

## It's working if

- You see a plan — commit groups with files and messages — before anything is committed (review mode)
- Each commit is one logical change; mixed trees come out as several focused commits, not one lump
- Subjects read `[Tag] Imperative summary` in the repo's own tag vocabulary

## Where it fits

The tail of the build chain: after [implement](https://aihero.dev/skills-implement) or any manual change, `commit` turns the diff into history, and [open-pr](https://aihero.dev/skills-open-pr) takes it from there. [ask-matt](https://aihero.dev/skills-ask-matt) routes the wider system.
