---
"ai-agent-skills": minor
---

**Breaking:** rename **`cross-check-with-codex`** to **`cross-check`** and make it harness-neutral. Invoke it as `/cross-check`; the old name is gone (no alias), so re-run `scripts/link-skills.sh` or reinstall.

Whichever agent runs the skill, Claude Code or Codex, is the **Requester**: it identifies the artifact, writes the packets, reconciles the findings, and reports. The **Reviewer** is chosen per invocation, in plain language ("cross-check this plan with Claude Opus at high effort"), by harness, model, and effort. It defaults to the other harness from the Requester's, at `high` effort with a per-harness default model set in the script: `gpt-6-astra` for Codex, `claude-opus-5-5` for Claude. A same-harness review runs when asked for and is logged like any other.

The bundled script is now `scripts/review.sh`. `start` takes `--harness codex|claude`, `--model`, and `--effort` (replacing `--reasoning`), and requires `--author` and the Requester's own `--requester-harness`, `--requester-model`, and `--requester-effort` (`unknown` allowed). `resume` takes `--session-id` (replacing `--thread-id`) and reads everything else from the review state, so a review session cannot switch Reviewer mid-loop.

A Claude Reviewer stays read-only through harness-enforced permissions: `dontAsk` mode, no settings files loaded (so no allow rule can pre-approve a write or a post to GitHub), and the file-writing tools disallowed. It reviews by reading and cannot run verification that writes anything. The snapshot-and-restore check now covers every harness, also catches a reviewer that changes only the index (staging or unstaging), and undoes a reviewer's edits even when the reviewer then crashes or exits non-zero.

The audit record moves to `.cross-checks/<review-slug>/` (old `.claude/codex-reviews/` records are left in place). Its `.review-state` now records the Author, the Requester's harness, model, and effort, the Reviewer's as passed, and the Reviewer model the harness reported running. The final report carries a `Requester:` and a `Reviewer:` line built from it.

`to-done`'s PR reviewer now invokes `/cross-check` with a Codex Reviewer.
