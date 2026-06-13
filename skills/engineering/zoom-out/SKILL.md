---
name: zoom-out
description: Tell the agent to zoom out and give broader context or a higher-level perspective. Use when you're unfamiliar with a section of code or need to understand how it fits into the bigger picture.
disable-model-invocation: true
---

I don't know this area of code well. Go up a layer of abstraction. Give me an overview — a map of all the relevant modules and callers, using the project's domain glossary vocabulary.

## Output

`zoom-out` is interactive: by default, give the overview in-conversation and save nothing. Two actions are available on explicit request only — never save or promote automatically.

- **Save** → write the overview to `.claude/overviews/` for Claude Code or `.agents/overviews/` for Codex and other agents (create the directory if it does not exist).
- **Promote** → write the overview to `docs/overviews/` (create the directory if it does not exist), when it is durable and worth keeping for humans.

For both, use a kebab-case topical filename with no date in it (e.g. `auth-module.md`) and begin the file with this YAML frontmatter:

```yaml
---
created: YYYY-MM-DD
---
```
