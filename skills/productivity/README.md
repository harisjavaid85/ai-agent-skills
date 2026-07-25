# Productivity

General workflow tools, not code-specific.

## User-invoked

Reachable only when you type them (Claude Code: `disable-model-invocation: true`; Codex: `policy.allow_implicit_invocation: false` in `agents/openai.yaml`).

- **[grill-me](./grill-me/SKILL.md)** — Get relentlessly interviewed about a plan or design until every branch of the decision tree is resolved.
- **[handoff](./handoff/SKILL.md)** — Compact the current conversation into a handoff document so another agent can continue the work.
- **[setup-claude-code](./setup-claude-code/SKILL.md)** — Bootstrap a machine's global Claude Code setup at `~/.claude/`: permissions baseline, dangerous-command hook, optional statusline. Supports `host` / `sandbox` / `guardrails` modes.
- **[teach](./teach/SKILL.md)** — Teach the user a new skill or concept over multiple sessions, using the current directory as a stateful teaching workspace.
- **[writing-great-skills](./writing-great-skills/SKILL.md)** — Reference for writing and editing skills well: the vocabulary and principles that make a skill predictable.

## Model-invoked

Model- or user-reachable (rich trigger phrasing so the model can reach for them).

- **[cross-check-with-codex](./cross-check-with-codex/SKILL.md)** — Cross-check an artifact with Codex through an independent review loop and local audit record.
- **[grilling](./grilling/SKILL.md)** — Interview the user relentlessly about a plan, decision, or idea until every branch of the decision tree is resolved. The reusable loop behind `grill-me` and `grill-with-context`.
- **[write-a-skill](./write-a-skill/SKILL.md)** — Convert settled requirements into a well-structured skill (steps, reference, progressive disclosure). Grill first if scope is fuzzy.
