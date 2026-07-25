Quickstart:

```bash
npx skills add harisjavaid85/ai-agent-skills --skill=open-pr
```

```bash
npx skills update open-pr
```

[Source](https://github.com/harisjavaid85/ai-agent-skills/tree/main/skills/engineering/open-pr)

## What it does

`open-pr` pushes the current branch and opens — or updates — its GitHub pull request in a standard format: a tagged title, a summary, and a curated change list. It is idempotent: re-running pushes new commits and refreshes the same PR rather than opening a duplicate.

The defining constraint is that it **only opens the PR** — it never commits and never merges. A dirty working tree stays dirty; what exists on the branch is what gets proposed.

## When to reach for it

Type `/open-pr`, or the agent reaches for it automatically when a task fits.

Reach for it when a branch is ready for review. Plain `/open-pr` composes title and body and waits for approval; `/open-pr auto` pushes and creates or updates without blocking — the path an agent driving the loop takes. Optional arguments cover drafts, base-branch overrides, and slug enrichment.

## Slug enrichment

Passed a `<slug>`, the skill enriches the PR from the matching spec-tracker issue on repos configured for the GitHub tracker — linking the PR back to the spec it implements so the issue lifecycle stays traceable from ticket to merge. Without a slug, the PR stands on its own: tagged title, summary, change list.

## Where it fits

The public face of the build chain: [to-tickets](https://aihero.dev/skills-to-tickets) shapes the work, [implement](https://aihero.dev/skills-implement) builds it, [commit](https://aihero.dev/skills-commit) writes the history, and `open-pr` proposes it for review. [ask-matt](https://aihero.dev/skills-ask-matt) routes the wider system.
