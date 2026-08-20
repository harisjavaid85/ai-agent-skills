## What it does

`setup-repo-skills` wires a repo for the engineering skills: `.gitignore` and Claude Code settings, the `AGENTS.md`/`CLAUDE.md` agent guide, and the `docs/agents/` config that the other skills read — issue-tracker conventions, triage-label and commit-tag vocabularies, coding standards, and domain-doc rules.

The defining constraint is the authority split: this skill owns only **structural** setup — what's derivable from disk and convention. It never decides the repo's domain layout (single- vs multi-context); that judgment belongs to [bootstrap-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/bootstrap-context.md).

## When to reach for it

You invoke this by typing `/setup-repo-skills` — the agent won't reach for it on its own.

Reach for it once per repo, before the issue-lifecycle skills — [to-spec](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-spec.md), [to-tickets](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-tickets.md), and [triage](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/triage.md) stop and ask for it when their config is missing. It walks you through one section at a time, leading with the recommended answer: repo mode, issue tracker (GitHub, GitLab, or local markdown), label vocabularies, verify tiers, coding standards.

## What it writes

Everything lands in reviewable files, not hidden state: the agent guide gains operating-mode and verify sections, and `docs/agents/` gains the config the skills consume at runtime. All of it is yours to edit afterwards — re-running the skill updates in place rather than clobbering.

## It's working if

- `docs/agents/` exists with issue-tracker, triage-label, commit-tag, and domain-doc config
- The repo's `AGENTS.md` or `CLAUDE.md` names its repo mode and verify commands
- Lifecycle skills stop asking you where issues live

## Where it fits

The **run-once keystone** of the whole system — every other engineering skill assumes its output. Follow it with [bootstrap-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/bootstrap-context.md) to establish the domain glossary. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
