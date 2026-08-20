---
"ai-agent-skills": patch
---

Remove em-dashes from fork-authored prose, adopting the rule the upstream sync brought in.

`CLAUDE.md` has carried "no em-dashes anywhere in this repo's prose" since the sync, while 567 of them remained across 49 files. Each was rewritten to the punctuation the sentence wanted (a colon, comma, semicolon, parentheses, or a conjunction) rather than swapped for a single replacement character. `CHANGELOG.md` is left alone as a historical record of released versions.

Also fixes a regression from the same sync: `to-tickets` now heads a local ticket file `# <NN>: <Title>` where it used to separate the number and title with a dash, and `to-done`'s loop stripped only the dash form, so every ticket title parsed out of a new queue kept its number. The loop now accepts both, since queues written under the old convention are still on disk.
