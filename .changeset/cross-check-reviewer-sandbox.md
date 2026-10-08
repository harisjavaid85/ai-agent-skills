---
"ai-agent-skills": patch
---

`cross-check-with-codex` gains `CROSS_CHECK_REVIEWER_SANDBOX`, which says what keeps Codex read-only: `native` (the default, Codex's own reviewer sandbox) or `external` (a container or VM already isolates the review, so Codex runs without one). Since Codex 0.115 its sandbox needs a user namespace that a default Docker container denies, so the to-done review could never get a cross-check; the loop now sets `external` in its containers instead of loosening Docker's security profile. See ADR-0006.

In either mode, a round that changes the repository (the working tree, `HEAD`, or the branch) now fails, and the script puts the repository back as it was before the round and lists what it undid. `native` refuses to start when Codex's sandbox cannot, since Codex otherwise exits 0 having read nothing. Codex's review instructions now say that verification which needs to write should write outside the repository, to `/tmp` or a `mktemp -d` directory.

to-done's reviewer now stops when the cross-check cannot complete a single round: it posts a `Cross-check: unavailable (<reason>)` verdict and does no review of its own, no fixes, no commit, and no relabelling, so the PR stays stalled until a human fixes the cause and re-runs the review. Previously it reviewed alone and handed the PR over unchecked. The loop's review postcondition also reads the newest verdict comment rather than the first, so an earlier run's `Cross-check: unavailable` no longer blocks a PR whose re-review succeeded.
