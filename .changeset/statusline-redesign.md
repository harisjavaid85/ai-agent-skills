---
"ai-agent-skills": patch
---

Rewrite `/setup-claude-code`'s statusline to show effort, context size, and the 5-hour limit.

The line now reads `user@host | repo (branch) | model (effort) | 84k/200k (42%) | 2h50m/5h (23%)`. Context is coloured by absolute token count, the 5-hour segment shows time into the window and quota used, and a narrow terminal or tmux pane wraps the line instead of cutting it. Segments, labels, and thresholds sit at the top of the script. Re-run `/setup-claude-code` to install the updated statusline.
