---
"ai-agent-skills": patch
---

Move the `kb-*` skills' registry to `~/.config/kb-skills/registry.json`.

The registry now lives under `$XDG_CONFIG_HOME` (default `~/.config`) instead of `~/.claude/kb/`, so Claude Code, Codex and other harnesses all resolve the same knowledge bases. Move an existing `~/.claude/kb/registry.json` there by hand.
