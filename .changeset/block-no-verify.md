---
"ai-agent-skills": patch
---

Block `--no-verify` in `/setup-claude-code`'s Bash hook.

The hook now refuses `--no-verify` on any git command, and `git commit -n`, its short form for commits, so an agent cannot skip a repo's pre-commit or pre-push hooks. Re-run `/setup-claude-code` to install the updated hook.
