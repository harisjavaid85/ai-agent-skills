---
"ai-agent-skills": minor
---

Port upstream's improvements into the five skills held at the fork side during the sync.

The merge kept `tdd`, `code-review`, `to-spec`, `to-tickets` and `ask-author` on the fork's behaviour, which also froze out everything upstream had improved around it. Each now carries both.

- `ask-author` gains upstream's **Phase boundaries** section, replacing the two-bullet `Crossing sessions`. It carries all five options in order (continue, `/clear`, `/handoff`, subagent, `/compact`) and discloses the reasoning to `PHASE-BOUNDARIES.md`, a file the sync brought in that nothing linked to. The router also picks up `/grilling`, `/resolving-merge-conflicts`, `/to-questionnaire`, `/wizard`, `/wait-what` and `/writing-for-agents`, and keeps the fork-only entries alongside them.
- `tdd` gains the pointer to `codebase-design` for when the shape of the interface, not the test, is the open question.
- `code-review` and `to-spec` quote their `description` front matter. An unquoted colon-space makes the block invalid YAML, and `skills.sh` skips such a skill during discovery rather than reporting it.
- Prose across all five moves to the repo's no-em-dash rule.

`setup-repo-skills` was missing from the top-level `README.md` skill list, and is now listed.
