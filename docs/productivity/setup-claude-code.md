Quickstart:

```bash
npx skills add harisjavaid85/ai-agent-skills --skill=setup-claude-code
```

```bash
npx skills update setup-claude-code
```

[Source](https://github.com/harisjavaid85/ai-agent-skills/tree/main/skills/productivity/setup-claude-code)

## What it does

`setup-claude-code` bootstraps a machine's global Claude Code configuration under `~/.claude/`: a permissions baseline, a dangerous-command hook, and optional interface settings. It works in three modes — `host`, `sandbox`, and `guardrails` — for a personal machine, an ephemeral environment, or just the safety layer.

The defining constraint is **safe re-runs**: everything the skill manages is tracked under a sentinel in your settings, so running it again updates its own entries while preserving every key you added by hand.

## When to reach for it

You invoke this by typing `/setup-claude-code` — the agent won't reach for it on its own.

Reach for it on a new machine, a fresh sandbox, or any host where Claude Code has no guardrails yet. Run it once per machine — its repo-level counterpart [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md) runs once per repo, and will nudge you toward this one when the global setup is missing.

## The two guardrail layers

The skill installs belt and braces: a **permissions baseline** in `~/.claude/settings.json` (deny and ask lists for dangerous operations) and a **PreToolUse hook** that blocks destructive shell commands outright. Both layers report to one audit surface, `~/.claude/GUARDRAILS.md`, so you can see exactly what protection is in place.

## Choosing a tool surface

On `host` and `sandbox` the skill also asks how much of Claude Code's tool surface you want loaded: `standard` keeps everything and is the default, `lean` strips the tools and bundled features most setups never call, and `leanest` goes one step further. It tells you exactly what each level costs before writing anything — pick a lean level only once you've checked that none of your own skills call a tool it denies.

## Where it fits

**Run-once setup**, machine-level: this first, then [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md) per repo. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
