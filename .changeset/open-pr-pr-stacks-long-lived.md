---
"ai-agent-skills": minor
---

Teach `/open-pr` about PR stacks and long-lived branches.

A branch whose first-parent history is only merged PRs is a **PR stack**: its body lists one line per PR instead of its commits, and its title is the `Merge` tag with `Merge <head> branch into <base>`. The `Merge` tag now covers any branch merged into another, in the `/commit` table and the `commit-tags.md` seed.

`/open-pr` no longer pushes new commits onto a **long-lived branch** (the default branch, one the repo's agent instructions name, a protected one, or one other PRs have merged into), and skips the push when the branch already matches its remote. The base now resolves from `base=`, then the branch's open PR, then the default branch, so a re-run never opens a duplicate PR against a different base, and a refusal now means HEAD is the resolved base rather than the default branch. The docs page gains **Common questions** and **It's working if**.
