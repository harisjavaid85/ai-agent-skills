---
"ai-agent-skills": patch
---

Let `/implement` and to-done act on ticket and PR comments.

`/implement` now reads an issue as its body plus its comments, with a later human comment winning over the body, and reads the parent spec as context the ticket overrides. Comments an agent posted are context only, so a bail-out's guessed fix never becomes a requirement. to-done's implementer leaves both reads to `/implement`, and its PR reviewer judges the PR's top-level human comments alongside the spec, naming each in the verdict, and now finds the spec on a local tracker too. Re-running the `review` phase first marks a handed-over PR stalled again, so a review that dies does not leave it claiming ready. The planner's `priority:p*` signal is gone: the loop never passed it labels, so it could not fire.
