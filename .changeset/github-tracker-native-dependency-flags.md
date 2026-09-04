---
"ai-agent-skills": patch
---

Stop the GitHub tracker profile prescribing `gh api --method POST` for sub-issues and blocking edges.

`/setup-repo-skills` wrote a profile telling agents to wire dependency and sub-issue links through `gh api --method POST`, which `/setup-claude-code`'s own guardrail hook denies. Two skills in this repo therefore contradicted each other, and any agent following the profile on a machine set up here stalled at the blocking step, every time. `gh issue create --parent`/`--blocked-by` and `gh issue edit --parent`/`--add-blocked-by` do the same work, take the `#number` or the issue URL rather than the internal database id, and clear the hook. Repos whose `docs/agents/issue-tracker.md` was written from the old profile need `/setup-repo-skills` re-run to pick this up.
