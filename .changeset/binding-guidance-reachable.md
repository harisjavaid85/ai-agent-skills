---
"ai-agent-skills": patch
---

Close two gaps where binding guidance existed but the agent never reached it.

`domain.md` routed the glossary and ADR formats through `/grill-with-context`, which is user-invoked (`disable-model-invocation: true`, `allow_implicit_invocation: false`). An agent writing an ADR mid-implementation cannot invoke it, so the format was unreachable and the model's own heavy Status/Context/Decision/Consequences prior filled the gap. Both bullets now name the `/domain-modeling` skill, which is model-invoked and hands over `CONTEXT-FORMAT.md` and `ADR-FORMAT.md` on relative links that resolve wherever the skill is installed.

The agent guide's routing table said only `an ADR: docs/adr/`, which reads as complete and stops the agent going further. It now reads `an ADR in docs/adr/, format per docs/agents/domain.md`.

`implement` step 2 listed the guidance to read as issue access, implementation, review, and verification, leaving out the comment discipline that `coding-standards.md` carries, and its completion criterion asked only that the guidance be *identified*, which a glance at a filename satisfies. It now names code comments explicitly and requires that the guidance be read.
