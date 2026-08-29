---
"ai-agent-skills": patch
---

Tighten comment discipline at both ends: what a comment may cite, and a pass that trims them.

The emitted `coding-standards.md` said where an over-long comment should go but never what a comment may point at, so the routing rules read one way only: `domain.md`'s `KNOWLEDGE.md` template links out to code, and nothing said whether code links back. Left open, the model's default is to sprinkle `see KNOWLEDGE.md` pointers. A new `## Comments` bullet closes it in the direction the existing rules already imply. A glossary term needs no pointer because the identifier that names it is the pointer. A `KNOWLEDGE.md` entry exists only because no declaration owns its fact, so a pointer to it has no honest home and is a second copy that goes stale on its own; where a specific site would go wrong, the neighbouring bullet already says to leave behind what is true at that line. An ADR is the carve-out, holding rationale among rejected alternatives that provably is not in the code, so citing it is correct where inlining the tradeoff would not be.

`implement` ran `/code-review`, remediated, and verified, and nothing in that sequence looked at the comments the implementation and the remediation had just written. By then the agent's picture of them is a summary rather than the text, so verbose comments survived to handoff. Step 4 now re-reads every comment in the touched files from the files, cuts what step 2's binding guidance would not have earned, then verifies. Its completion criterion names the sweep, so skipping it no longer counts as done.
