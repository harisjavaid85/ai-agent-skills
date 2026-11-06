---
name: merge
description: Land a branch on a named base through its GitHub pull request, from finding or opening the PR to a merge commit, the runs it triggers, and a cleaned-up head. Use when the user asks to merge a branch or PR into a named base, or to promote one long-lived branch into another.
---

# Merge

Take one branch onto one base through its pull request: find or open the PR, keep its head level with the base, resolving conflicts by intent, wait for its CI, merge it with a merge commit, follow the runs the merge triggers, and delete the head when it is short-lived. The merge is the deliverable; workflow reruns stay with the user.

## Authorisation

Proceed only when the user has asked for this merge in their own words, naming the base: directly ("merge this branch into main", "merge release main"), or as an explicit instruction to the agent running you ("implement X, then merge it into main"). An agent's or skill's own judgement that work is ready is never authorisation. Without that request, or without a named base, stop and ask.

The request also authorises what landing a short-lived head needs: the writes in **Writes to the head**, and the conflict report on its PR.

## Arguments

Parsed loosely from the request:

- **Base** (required): the branch to merge into.
- **Head** (optional): the branch to merge. Defaults to the current branch.

`merge release main` reads as head `release`, base `main`; `merge this into main` reads as head `<current branch>`, base `main`.

## Long-lived branch

A branch other branches merge into by PR. Treat a branch as long-lived when any of these holds:

1. It is the repo's default branch (`gh repo view --json defaultBranchRef`).
2. The target repo's agent instructions name it as long-lived.
3. GitHub protects it: `gh api repos/{owner}/{repo}/branches/<b> --jq .protected`, or `gh api repos/{owner}/{repo}/rules/branches/<b>` returns any rule. A lookup that errors (plans without rulesets answer 403 or 404) gives no signal either way.
4. It has been the base of a merged PR: `gh pr list --base <b> --state merged --limit 1` is non-empty.

Every other branch is short-lived. A long-lived branch never takes new commits by a direct push (they need their own branch and PR) and is never deleted.

## Tracked head

The run tracks one head SHA. It records it once the PR is open in step 2, from `git ls-remote origin refs/heads/<head>`; re-records it after each push the run makes (`git rev-parse HEAD`); and re-reads it with `git ls-remote` when the user says in the conversation that they pushed. Every write to the remote head lands only while it still equals the tracked SHA: a push only after `git ls-remote` shows it there, and as a fast-forward of it; the merge matched to it (`--match-head-commit`); and the deletion leased on it (`--force-with-lease=<head>:<tracked SHA>`). A refused write or any other difference means the head moved: stop and report the SHAs.

## Check out

Every branch switch the run makes needs a clean working tree (no tracked change, no merge or rebase in progress) and a branch no other worktree has checked out. A switch that cannot meet both stops the run before the PR merges, asking the user to clear the way; after it merges, the run stays where it is and says why. To check out the head: `git fetch origin`, then switch to it, created from `origin/<head>` when there is no local branch.

## Writes to the head

The run writes only to a short-lived head. Every write starts from a **Check out** of the head and ends in its **Push**:

- **Commit**: the local head must equal the tracked SHA; `git merge --ff-only <tracked SHA>` brings a behind head level, and a head that is ahead or cannot fast-forward means the head moved. Then write the commit, in the repo's commit convention.
- **Push**: run the project's automated checks on the checked-out head, found from its agent instructions, then its scripts; a `RESOLVED` report from `resolving-merge-conflicts` is that run for the commits it made. A failing check, or a `BLOCKED` report, stops the run unpushed: `STOPPED at <step>: <check> fails` or the resolver's `BLOCKED` reason, with the output. Then `git push origin <head>` and re-record the tracked SHA.

## Mergeability

Read with `gh pr view <n> --json mergeable,mergeStateStatus`. A state stops the run only when nothing the run is about to do can clear it:

| State | Action |
| --- | --- |
| `UNKNOWN` (either field) | GitHub is still computing; re-read |
| `CONFLICTING`, `DIRTY`, or `BEHIND` | step 3 |
| `BLOCKED`, before CI has passed | continue: pending required checks block too |
| `BLOCKED`, after CI has passed | stop, naming the unmet rule where `gh` exposes it (`gh pr view <n> --json reviewDecision`, the base's protection or rules) |
| anything else | continue |

## Conflict report

The ledger of the resolutions this PR lands, and of the user's decisions on them. The resolutions themselves are records in commit messages, written by `resolving-merge-conflicts` whoever ran it. A record belongs to the PR that first lands its commit: a record whose commit a merged PR already landed (`gh api repos/{owner}/{repo}/commits/<sha>/pulls` lists one with `merged_at` set) was settled there. A PR carries at most one conflict report, a comment whose body starts with the marker line `<!-- merge:conflict-report -->`, then `Generated by an AI agent.`, then the records under one `Conflicts resolved:` label, in `resolving-merge-conflicts`' report format. A PR with no such comment has an empty report.

- **Find**: `gh api repos/{owner}/{repo}/issues/<n>/comments --paginate --jq '.[] | select(.body | startswith("<!-- merge:conflict-report -->")) | .id'`.
- **Write**: when **Find** returns none, create it with `gh pr comment <n> --body-file <file>`; otherwise edit it in place with `gh api -X PATCH repos/{owner}/{repo}/issues/comments/<id> -F body=@<file>`.
- **Sync**: rebuild the report from the records this PR lands, found by their marker line in `git log --reverse --format='%H%n%B' origin/<base>..<tracked SHA>`, oldest first: each record's first line with `(in <short sha>)`, its Trivial count added to the total, and one line per point, from the latest record holding it, with `(in <short sha>)` at its end. A line keeps the decision of the existing report's line for its point when both keep the same side; points no record holds any more drop out.
- **Decisions**: a **Needs your decision** line is **open** until the user decides it: an approval appends its `Decided` suffix and moves it to **Chosen by a governing statement**, in `resolving-merge-conflicts`' report format; an override's record replaces it. Lines the user decided, approved or chosen by their decision, are passed as decisions to every later resolution on this PR. A decision's timestamp is GitHub's time when the user gave it, so every statement is ordered on one clock: the `Date` header of `gh api -i rate_limit`, in ISO 8601 (`date -u -Iseconds -d '<Date>'`).

## Workflow

### 1. Resolve the request

Confirm the authorisation above. Confirm a GitHub remote and an authenticated `gh` (`git remote -v`, `gh auth status`); either failing is a hard stop. Refuse when head and base are the same branch.

**Repository guidance is binding.** Read the target repo's agent instructions (`AGENTS.md`, `CLAUDE.md`, or the repo's equivalent) and every convention, guide, and runbook they point to. Note anything that names long-lived branches, and any merge or promotion procedure that applies to this base: pre-merge gates, post-merge checks, manual checks.

Run `git fetch origin`, record where the run starts (its branch, or the commit of a detached HEAD), and classify head and base with **Long-lived branch**.

**Complete when:** the merge is authorised, head and base are resolved and classified, and the procedure for this base (or its absence) is noted.

### 2. Find or open the PR

Look for an open PR: `gh pr list --head <head> --base <base> --state open --json number,isDraft`.

**No PR.** **Check out** the head. For a long-lived head, bring it level with `git pull --ff-only`, and stop if that fails; for a short-lived head, run the checks as for a push. Then call the Skill tool with "open-pr", passing `auto base=<base>`. When it opens no PR (nothing ahead of the base, a long-lived head with new commits, or a failed push), stop and pass on its reason; when it opens one, record the tracked head.

**PR exists.** Leave its title and body alone, and record the tracked head. Compare the local head (when one exists) with `origin/<head>`:

| Local vs remote | Action |
| --- | --- |
| level, behind, or no local branch | use the remote head |
| ahead, short-lived head | push per **Writes to the head** |
| ahead, long-lived head | stop (see **Long-lived branch**) |
| diverged | stop and report both SHAs |

With the PR open, check it:

- **Draft**: stop. Tell the user to run `gh pr ready <n>` once it is reviewed, then ask again.
- **Mergeability**: act on it per **Mergeability**.

**Complete when:** an open, ready PR exists, its head SHA is tracked, and its mergeability has been acted on.

### 3. Update the head

Entered from **Mergeability** when the head is conflicting with or behind the base. Each entry is one round; a fourth round in one run stops with `base kept moving after 3 head updates`.

**Long-lived head**: stop. Hand the user these commands, then ask them to merge `merge/<base>-into-<head>` into `<head>` and re-run this merge:

```bash
git switch -c merge/<base>-into-<head> origin/<head>
git merge origin/<base>   # resolve with /resolving-merge-conflicts, base <base>, head <head>; then push the branch
```

**Short-lived head**: bring the base in per **Writes to the head**, with `git merge --no-commit --no-ff origin/<base>` as the write. Then call the Skill tool with "resolving-merge-conflicts", passing base `<base>`, head `<head>`, PR `#<n>`, and the conflict report's lines the user decided as decisions.

The run always continues from step 3 at step 4.

**Complete when:** the head contains the base, and is pushed and tracked.

### 4. Settle open decisions

Sync the **Conflict report**, writing it when the sync changed it. When it holds an open decision, print its open **Needs your decision** lines, then ask, while CI runs on GitHub:

> Some conflict resolutions need your decision, see "Needs your decision" section above. Should I go ahead, or you would like me to override any resolutions.

The answer settles every line open when it was given, and is recorded in the conflict report:

- **Go ahead**: every open line is approved.
- **Override**: the lines named are overridden and the rest approved. An override is a resolution: its commit carries a **record** in `resolving-merge-conflicts`' format, each overridden point under **Chosen by a governing statement** with the user's decision as its Why. Write the change and its record in one commit per **Writes to the head**; when the user says they pushed the change instead, re-record the tracked head and write the record in an empty commit on top (`git commit --allow-empty`).
- **A question**: answer it, then ask again.
- **Hold**: stop and report the open decisions.

**Complete when:** the conflict report holds no open decision.

### 5. Check the pre-merge gates

Check every pre-merge gate the procedure from step 1 sets for this base, using read-only lookups. A failed gate stops the run with the gate and the evidence.

**Complete when:** every documented gate passed, or the procedure sets none.

### 6. Wait for CI

Follow CI by workflow run, matched on the tracked head SHA whatever event started them: `gh run list --commit <sha> --json databaseId,name,event,status,conclusion`, then `gh run view <id> --json status,conclusion,jobs` for each. Use runs rather than `gh pr checks`: a fine-grained token cannot read the PR's check rollup.

Wait in the background with a poll that exits once every run's `status` is `completed`, never a foreground `sleep`. There is no ceiling on a run in progress. A completed run passes when its conclusion is `success`, `skipped`, or `neutral`; any other conclusion (`failure`, `cancelled`, `timed_out`, `action_required`, `startup_failure`, ...) fails.

- **No run appears** within about two minutes of starting to follow: proceed, and carry a warning into the report that the PR merged without CI.
- **Runs unreadable** (`gh run list` refused, such as HTTP 403): proceed, and carry a warning that CI is unknown.
- **A run fails**: stop. Report the failing job and an excerpt of `gh run view <id> --log-failed`, and hand the user `! gh run rerun <id> --failed`.

**Complete when:** every run on the tracked head SHA completed and passed, or none appeared within the window, or runs were unreadable.

### 7. Merge

Confirm the **Tracked head** and re-read **Mergeability**, acting on both.

Then `gh pr merge <n> --merge --match-head-commit <sha>` with the tracked SHA, always a merge commit, with no branch flags. On a refusal, re-read the PR and act on it per **Tracked head** and **Mergeability**; a refusal neither explains stops the run with GitHub's message. Record the merge commit: `gh pr view <n> --json mergeCommit --jq .mergeCommit.oid`.

**Complete when:** the PR is merged and the merge SHA is recorded.

### 8. Follow what the merge triggered

Follow the runs the push to the base started: `gh run list --branch <base> --event push --commit <merge-sha>`, with the same background poll, pass rule, and two-minute window as step 6. No run within the window means nothing was triggered; unreadable runs are unknown, and said so. A failed run stays failed: report the job, a log excerpt, and the rerun command, and leave the merge in place.

Then work the post-merge part of the procedure from step 1: run each read-only check and record its result, list each manual check for the user, and hand any documented step that writes (a rerun, a config push, a deploy) to the user as a `!` command.

**Complete when:** every triggered run reached a terminal state and every documented post-merge check is run, listed, or handed over.

### 9. Clean up

First return, per **Check out**, to where the run started: its branch or detached commit, or the base when the run started on the head or its branch is gone, then `git pull --ff-only` when that is the base.

Then delete the head only when it is short-lived and no open PR uses it as a base (`gh pr list --base <head> --state open`):

1. **Local** first, while `origin/<head>` still exists for `git branch -d` to check against: `git branch -d <head>`. When git refuses, keep it and say why.
2. **Remote**: `git push --force-with-lease=<head>:<tracked SHA> origin --delete <head>`, skipped when the branch is already gone. It stays restorable from the PR page. When the lease refuses, the head moved after the merge: keep it and say why.

Leave every other branch in place, local or remote, including a local copy this run created.

**Complete when:** the head is deleted or kept with a stated reason, and the working copy is where the run started, on the base, or kept where it is with a stated reason.

### 10. Report

Print the report below.

## Report

```markdown
## Merge

Status: MERGED | STOPPED at <step>: <reason>
Next: <what the user does next, when the run stopped>
PR: #<n> <title> (<head> → <base>)
Merge commit: <sha>

<the conflict report as step 4 last synced it; when the run stopped before pushing, synced per **Sync** with the checked-out head in place of the tracked SHA>

### CI
- <workflow>: <conclusion> | none ran (warning: merged without CI) | unreadable (warning: CI unknown)

### Triggered by the merge
- <workflow> <run id>: <conclusion, failing job and rerun command when failed>

### Post-merge checks
- <check>: <result>

### Manual checks for you
- <check>

### Branches
- <head>: deleted (local, remote) | kept: <reason>

### Warnings
- <warning>
```

Omit any section with nothing in it.
