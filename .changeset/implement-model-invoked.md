---
"ai-agent-skills": minor
---

Let the model invoke `/implement`.

It was reachable only by a human, which left it unreachable from any orchestrating skill: a user-invoked skill can never reach another user-invoked one, so a loop dispatching `/implement` per ticket had no way to call its one implementing step. Opening it unblocks that dispatch. The cost, taken knowingly: any model session may now reach for it on its own once a work item is settled and named.
