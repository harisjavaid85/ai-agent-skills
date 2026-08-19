---
"ai-agent-skills": minor
---

Enrich `/open-pr <slug>` from a local ticket queue, not just GitHub.

Slug enrichment now probes the **slug** rather than the repo's tracker configuration: a `kind:spec` issue carrying `spec:<slug>`, or a `.scratch/<slug>/spec.md` committed on the branch, with GitHub winning when both answer. The tracker is a property of the spec, so a repo wired to GitHub can still carry a local queue for one feature. Local specs and tickets are linked by commit permalink, since those files exist only on the branch until the PR merges.

The body's Format rule now keys on whether a reader can resolve a reference rather than on where the artifact lives. The PR body is also written to the OS temp directory instead of an unlocated "scratchpad file", which had been landing inside the repo and leaving the working tree dirty.
