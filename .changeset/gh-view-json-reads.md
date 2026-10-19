---
"ai-agent-skills": patch
---

Read issues and PRs with `--json` in `/setup-repo-skills`'s GitHub issue-tracker seed.

`gh issue view --comments` prints only the comments when no terminal is attached, so an agent fetching a ticket got no title or body, and `gh pr view` fails outright with a fine-grained token that cannot read check status. Re-run `/setup-repo-skills` to refresh a repo's `docs/agents/issue-tracker.md`.
