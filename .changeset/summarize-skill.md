---
"ai-agent-skills": minor
---

Add `/summarize`: one article, paper, or document in, a structured **overview** out.

The overview is six fixed sections, ending in jump-back references (headings, page numbers, figures, phrases) so any line can be traced to the passage that produced it. Caveats print even when a source hedges nothing, since that is itself information about the source, and anything from outside the source is quarantined under Additional Context. The source is read inline and stays in context, so follow-up questions are answered from it rather than from the summary.

Scope is already-authored prose (URL, PDF, local document, pasted text), one source per overview. Video, audio, and codebases are out, and synthesis across several sources stays with `/research`. Printed in the conversation by default; saved to `.overviews/<topic-slug>.md` on request, with `source`, `title`, `authors`, and `accessed` frontmatter.

`setup-repo-skills` now documents and gitignores `.overviews/` alongside `.plans/` and `.handoffs/`, and `CONTEXT.md` defines **Overview** as the artifact, resolving it against "summary" and `loop-me`'s **brief**.
