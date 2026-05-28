---
name: commit
description: Stage and commit working-tree changes — group them into a sensible commit plan, write concise [Tag]-prefixed messages (commit after approval or automatically). Use when the user wants to commit changes.
---

# Commit

Group working-tree changes into one or more commits, each with a `[Tag] summary` message, and commit them. Commit only — no pushing and branch ops.

## Tags & message format

Tags and message style are defined in the **Tags & message convention** section at the end of this file. If `setup-repo-skills` has been run, a per-repo override at `docs/agents/commit-tags.md` takes precedence over those defaults; use it when present.

## Modes

- **Review (default, plain `/commit`):** emit the plan and wait. Approving the plan _is_ the go-ahead to commit.
- **Auto (`/commit auto`):** emit the plan, then commit best-effort without blocking. Where review mode would stop to ask, auto takes the safe default (below) and keeps going.

## Workflow

1. **Survey** the whole working tree (staged + unstaged + untracked; `.gitignore` respected). If nothing to commit, report "nothing to commit" and stop.
2. **Group & tag.** Group by **logical change first**: all files that make up one coherent change belong in one commit, even when they span categories (e.g. doc edits plus the config file the same change renames). Only split into separate commits when the working tree holds genuinely _independent_ changes that happen to be staged together. Whole files only. Give each commit the **dominant tag** for its change. When a single logical change truly spans two categories and one tag alone would mislead, use `[Tag1][Tag2]` (dominant tag first, never three); otherwise one tag. The resulting grouping is shown in the plan in both modes.
3. **Build the plan:** for each commit, list its files and proposed message. Mark untracked files `NEW:`.
4. **Handle the two cases where the modes differ:**
   - **No fitting tag at all** — the change matches none of the canonical tags (distinct from spanning two; usually means it's doing two things). _Review:_ stop and ask. _Auto:_ commit under the best-fit dominant tag.
   - **Sensitive file** — `.env`, `*.key`/`*.pem`, credential-ish names, large binaries, files outside normal source dirs. _Review:_ ask before including. _Auto:_ exclude it and report it.

   Auto prints the full plan as a reviewable trail and never blocks.

5. **Commit:** stage each group's files explicitly by path (not `git add -A`) and commit it. In review mode commit on approval; in auto mode proceed.

## Pre-commit hook failure

Always fix the root cause → re-stage → create a **new** commit (never `--amend` a failed commit, never `--no-verify`).

- **Review:** after fixing, stop and report so the user decides whether to continue the sequence.
- **Auto:** after fixing, continue with the remaining commits. Bail and report only if the same hook fails again after the fix.

## Amend (opt-in)

Only when the user asks. **HEAD only**, and **only if unpushed** — verify the target isn't on the remote-tracking branch; refuse if already pushed. Default always creates new commits.

## Tags & message convention

The canonical vocabulary and message style.

### Canonical tags

| Tag        | Covers                                                        |
| ---------- | ------------------------------------------------------------- |
| `Feature`  | new functionality (`feat`)                                    |
| `Bugfix`   | fixes broken behavior (`fix`)                                 |
| `Doc`      | documentation (`docs`)                                        |
| `Refactor` | behavior-preserving restructure, including `perf` and `style` |
| `Test`     | tests                                                         |
| `Chore`    | non-code housekeeping: deps, build, ci, config, tooling       |
| `Merge`    | manual merge resolution                                       |
| `Revert`   | manually backing out a previous change                        |

### Message style

- **Subject:** `[Tag] imperative summary` — always imperative mood ("Add", "Fix", "Consolidate"), ≤ ~50 chars including the tag, no trailing period.
- **Body:** only when it adds _why_ the subject alone doesn't capture; 1–3 short lines on intent. Never enumerate file changes. Wrap ~72; blank line after subject.
- **Trailer:** append `Co-Authored-By: Claude <noreply@anthropic.com>`.
