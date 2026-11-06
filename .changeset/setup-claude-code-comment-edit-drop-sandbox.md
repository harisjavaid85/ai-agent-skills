---
"ai-agent-skills": patch
---

Tighten `/setup-claude-code`'s Bash hook and drop the `sandbox` mode.

The hook now catches more of the everyday ways agents write destructive commands, lets an agent edit a single issue or PR comment in place, only lets a remote branch be deleted with a lease on the commit it is expected to be at, and runs about four times faster. See `REFERENCE.md` and the hook script for the exact rules.

The `sandbox` mode is gone; `host` and `guardrails` remain. Re-run `/setup-claude-code` to install the updated hook.
