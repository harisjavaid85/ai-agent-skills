---
"ai-agent-skills": patch
---

Let `/resolving-merge-conflicts` resolve by intent read from PR and issue comments, and report every resolution.

Each side's intent now comes from the commits that touched the hunk, their PRs, the issues those PRs close, and the parent spec, each read as its body plus its comments, so a design change posted in a comment after testing steers the resolution. Incompatible intents go to the more recent statement that decides the point (an issue or spec body, an agent brief, a human comment or review, or a decision you already made); PR descriptions and commit messages inform the intent but never decide it. With none, the base side stays and the conflict is marked for your decision. The checks now run once on the finished result, with any fix in its own commit on top. Each commit that carries a resolution records it in its own message. The skill ends on a report with one line per non-trivial conflict, grouped into those that need your decision, those a statement decided, and those that kept both sides, with trivial ones only counted.

The in-progress merge skill now lands conflicting or out-of-date PRs itself: it brings the base into a short-lived head, resolves conflicts with `/resolving-merge-conflicts`, keeps one conflict report on the PR gathered from the resolutions recorded in the PR's commits, whoever made them, and asks before merging while any of them still needs your decision.

`/implement` tells an agent report from an agent brief by its role rather than by its AI disclaimer, since briefs carry disclaimers too.
