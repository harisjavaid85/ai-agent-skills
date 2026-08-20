---
"ai-agent-skills": minor
---

**Breaking:** remove `writing-great-skills`. Use `writing-for-agents` instead.

Upstream renamed and restructured the skill in v1.1, and this fork kept the old copy alive for one reason: `write-a-skill` linked `writing-great-skills/GLOSSARY.md` directly, and `writing-for-agents` ships no glossary. It does not need one. Every term `write-a-skill` borrows (**steps**, **reference**, **progressive disclosure**, **completion criterion**, **leading word**, the **no-op** test, **negation**) is defined inline in `writing-for-agents/SKILL.md`, so `write-a-skill` now points there, and at `SKILL-MECHANICS.md` for what changes because the document is a skill.

`CONTEXT.md`, `ask-author` and the `write-a-skill` docs page follow the pointer to its new home.
