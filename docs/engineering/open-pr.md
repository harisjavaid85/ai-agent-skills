## What it does

`open-pr` pushes the current branch and opens (or updates) its GitHub pull request in a standard format: a tagged title, a summary, and a curated change list. It is idempotent: re-running pushes new commits and refreshes the same PR rather than opening a duplicate.

The defining constraint is that it **only opens the PR**: it never commits and never merges. A dirty working tree stays dirty; what exists on the branch is what gets proposed. Nor does it push new commits onto a branch other PRs merge into: those need their own branch and PR.

## When to reach for it

Type `/open-pr`, or the agent reaches for it automatically when a task fits.

Reach for it when a branch is ready for review. Plain `/open-pr` composes title and body and waits for approval; `/open-pr auto` pushes and creates or updates without blocking, the path an agent driving the loop takes. Optional arguments cover drafts, base-branch overrides, and slug enrichment.

## Slug enrichment

Passed a `<slug>`, the skill adds the parent spec and its completed tickets to the PR, keeping the lifecycle traceable from ticket to merge. It probes the slug rather than the repo's configuration: a `kind:spec` issue carrying `spec:<slug>` on GitHub, or a `.scratch/<slug>/spec.md` committed on the branch. The tracker is a property of the spec, so a repo wired to GitHub can still carry a local queue for one feature, and a local spec is linked by commit permalink, since those files exist only on the branch until the PR merges. Without a slug, the PR stands on its own: tagged title, summary, change list.

## PR stacks

A branch whose history is nothing but merged PRs, such as a release branch headed for `main`, is a **PR stack**. Its commits were already reviewed one PR at a time, so the body lists the PRs (`#12 Add the export button`) instead of a wall of commits, and the title says what the PR is: `[Merge] Merge release branch into main`, written in the repo's own tag style.

## Common questions

**Why did it overwrite the description I edited by hand?**
`/open-pr auto` regenerates the body on every re-run, because it is the path an agent takes and has no one to ask. Plain `/open-pr` compares the fresh body with the live one and asks whether to keep, replace, or merge them, so hand edits survive.

**Why did it stop instead of pushing my commits?**
The branch is long-lived: it is the default branch, the repo's agent instructions name it, GitHub protects it, or other PRs have merged into it. New commits there belong on their own branch with their own PR.

**Will it mark my draft PR ready?**
No. Draft or ready is chosen once, when the PR is created, and a re-run never changes it.

## It's working if

- Re-running on the same branch updates one PR; a second PR for the branch never appears.
- The title's tag matches what your commits already use, and the body names only things a reviewer can open.
- A PR that merges a branch of already-merged PRs lists them by number, not as a wall of commits.

## Where it fits

The public face of the build chain: [to-tickets](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-tickets.md) shapes the work, [implement](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/implement.md) builds it, [commit](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/commit.md) writes the history, and `open-pr` proposes it for review. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
