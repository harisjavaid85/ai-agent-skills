---
"ai-agent-skills": minor
---

Route learned facts by arrival site, with the code as the source of truth.

`domain.md`'s routing is now two steps. The first sorts by kind: a term to the glossary, a decision to an ADR, a rule to operational policy, and a fact about how the system behaves to the second step. The second finds the fact's **arrival site**, the single declaration every reader who needs it passes through, and settles placement and worth together. On that declaration the fact is a comment, held to the bar in `coding-standards.md`. With no such declaration it goes to `KNOWLEDGE.md`, held to a higher bar: only a fact learned by running the system, or by following a behaviour through code that never states it, is worth the copy.

This replaces the module-boundary test. "Module" is scale-agnostic in this repo's own vocabulary, covering a function, class, package, or tier-spanning slice, so the boundary it named moved with the reader, and `domain.md` ships into repos where nothing defines it at all. The arrival site is self-defining and names the failure it prevents: a fact commented where no reader passes is accurate and unread. It also fixes a case the old test got wrong, where a behaviour spanning several parts is gated by one facade and belongs on that facade rather than in a file.

A written fact is a **cache** of the code, so when the two disagree the code is what is true, and the change that invalidated the fact updates it in the same pass, because nothing else revisits them. This retires "Facts are pruned when they stop being true", an outcome with no actor or moment, along with the "keep the bar high" maxim and the ban on creating a `KNOWLEDGE.md` for a single-module context, which existed only to patch the old test.

`code-review` now identifies standards sources by following the agent guide's pointers rather than guessing at `CODING_STANDARDS.md`, so it reaches whatever file the repo documents standards in, including the comment budget in `docs/agents/coding-standards.md`.
