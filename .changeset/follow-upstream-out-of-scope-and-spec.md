---
"ai-agent-skills": patch
---

Drop two fork divergences upstream had already settled: the out-of-scope path and the word PRD.

`triage` emits its rejected-request knowledge base at `.out-of-scope/` again, upstream's location, across `SKILL.md`, `OUT-OF-SCOPE.md`, `AGENT-BRIEF.md`, `setup-repo-skills/domain.md` and the `triage` docs page. This repo's own records already lived there, so nothing on disk moves; only the path the skill writes into a consumer repo changes.

`to-spec` no longer glosses a spec as "you may know this document as a PRD", matching upstream. `CONTEXT.md` has told this repo to avoid the term since the spec lifecycle landed, so the remaining fork-authored uses follow: `cross-check-with-codex`'s review instructions, two example descriptions in `write-a-skill`'s `FORMAT.md`, and `to-done`'s full reviewer reference, which also picks up the `SPEC_LABEL` and `kind:spec` names the loop actually passes.
