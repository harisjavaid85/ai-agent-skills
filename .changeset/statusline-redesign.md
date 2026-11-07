---
"ai-agent-skills": patch
---

Rewrite `/setup-claude-code`'s statusline to show effort, context size, and the 5h quota.

The line now reads `user@host | repo (branch) | model (effort) | 84k/200k (42%) | 77% ↻2h10m`. Context is coloured by absolute token count, the 5h quota segment shows the quota left and the time until it resets, and a narrow terminal or tmux pane wraps the line instead of cutting it. Segments, labels, and thresholds sit at the top of the script. Re-run `/setup-claude-code` to install the updated statusline.
