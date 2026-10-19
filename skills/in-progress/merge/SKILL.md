---
name: merge
description: Land a branch on a named base through its GitHub pull request, from finding or opening the PR to a merge commit, the runs it triggers, and a cleaned-up head. Use when the user asks to merge a branch or PR into a named base, or to promote one long-lived branch into another.
---

# Merge

Take one branch onto one base through its pull request: find or open the PR, wait for its CI, merge it with a merge commit, follow the runs the merge triggers, and delete the head when it is short-lived. The merge is the deliverable; commits, conflict resolution, and workflow reruns stay with the user.

## Authorisation

Proceed only when the user has asked for this merge in their own words, naming the base: directly ("merge this branch into main", "merge release main"), or as an explicit instruction to the agent running you ("implement X, then merge it into main"). An agent's or skill's own judgement that work is ready is never authorisation. Without that request, or without a named base, stop and ask.

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

## Workflow

### 1. Resolve the request

Confirm the authorisation above. Confirm a GitHub remote and an authenticated `gh` (`git remote -v`, `gh auth status`); either failing is a hard stop. Refuse when head and base are the same branch.

**Repository guidance is binding.** Read the target repo's agent instructions (`AGENTS.md`, `CLAUDE.md`, or the repo's equivalent) and every convention, guide, and runbook they point to. Note anything that names long-lived branches, and any merge or promotion procedure that applies to this base: pre-merge gates, post-merge checks, manual checks.

Run `git fetch origin`, record the starting branch, and classify head and base with **Long-lived branch**.

**Complete when:** the merge is authorised, head and base are resolved and classified, and the procedure for this base (or its absence) is noted.

### 2. Find or open the PR

Look for an open PR: `gh pr list --head <head> --base <base> --state open --json number,isDraft,headRefOid`.

**No PR.** Switch to the head, which needs a clean working tree; otherwise stop and ask the user to commit or stash. For a long-lived head, bring it level with `git pull --ff-only`, and stop if that fails. Then call the Skill tool with "open-pr", passing `auto base=<base>`. When it opens no PR (nothing ahead of the base, a long-lived head with new commits, or a failed push), stop and pass on its reason.

**PR exists.** Leave its title and body alone. Compare the local head (when one exists) with `origin/<head>`:

| Local vs remote | Action |
| --- | --- |
| level, behind, or no local branch | use the remote head |
| ahead, short-lived head | `git push origin <head>` |
| ahead, long-lived head | stop (see **Long-lived branch**) |
| diverged | stop and report both SHAs |

Then check the PR:

- **Draft**: stop. Tell the user to run `gh pr ready <n>` once it is reviewed, then ask again.
- **Mergeability** (`gh pr view <n> --json mergeable,mergeStateStatus`): `CONFLICTING` or `DIRTY` stops the run; point the user to the `resolving-merge-conflicts` skill. `UNKNOWN` means GitHub is still computing; re-read it.

**Complete when:** an open, ready, mergeable PR exists and its remote head SHA is recorded.

### 3. Check the pre-merge gates

Check every pre-merge gate the procedure from step 1 sets for this base, using read-only lookups. A failed gate stops the run with the gate and the evidence.

**Complete when:** every documented gate passed, or the procedure sets none.

### 4. Wait for CI

Follow CI by workflow run, matched on the head SHA whatever event started them: `gh run list --commit <sha> --json databaseId,name,event,status,conclusion`, then `gh run view <id> --json status,conclusion,jobs` for each. Use runs rather than `gh pr checks`: a fine-grained token cannot read the PR's check rollup.

Wait in the background with a poll that exits once every run's `status` is `completed`, never a foreground `sleep`. There is no ceiling on a run in progress. A completed run passes when its conclusion is `success`, `skipped`, or `neutral`; any other conclusion (`failure`, `cancelled`, `timed_out`, `action_required`, `startup_failure`, ...) fails.

- **No run appears** within about two minutes of the head being pushed: proceed, and carry a warning into the report that the PR merged without CI.
- **A run fails**: stop. Report the failing job and an excerpt of `gh run view <id> --log-failed`, and hand the user `! gh run rerun <id> --failed`.

**Complete when:** every run on the head SHA completed and passed, or none appeared within the window.

### 5. Merge

`gh pr merge <n> --merge --match-head-commit <sha>`, always a merge commit, with no branch flags. `--match-head-commit` makes GitHub refuse if the head moved after CI passed; on that refusal, stop and report the new SHA. Record the merge commit: `gh pr view <n> --json mergeCommit --jq .mergeCommit.oid`.

**Complete when:** the PR is merged and the merge SHA is recorded.

### 6. Follow what the merge triggered

Follow the runs the push to the base started: `gh run list --branch <base> --event push --commit <merge-sha>`, with the same background poll, pass rule, and two-minute window as step 4. No run within the window means nothing was triggered. A failed run stays failed: report the job, a log excerpt, and the rerun command, and leave the merge in place.

Then work the post-merge part of the procedure from step 1: run each read-only check and record its result, list each manual check for the user, and hand any documented step that writes (a rerun, a config push, a deploy) to the user as a `!` command.

**Complete when:** every triggered run reached a terminal state and every documented post-merge check is run, listed, or handed over.

### 7. Clean up

Delete the head only when it is short-lived and no open PR uses it as a base (`gh pr list --base <head> --state open`):

1. **Local** first, while `origin/<head>` still exists for `git branch -d` to check against: when the head is checked out, switch to the base and `git pull --ff-only`. Then `git branch -d <head>`. When git refuses, or the branch is checked out in another worktree, keep it and say why.
2. **Remote**: `git push origin --delete <head>`, skipped when the branch is already gone. It stays restorable from the PR page.

Leave every other branch in place, local or remote, including a local copy this run created. Finish on the starting branch when it still exists, otherwise on the base.

**Complete when:** the head is deleted or kept with a stated reason, and the working copy is on the starting branch or the base.

### 8. Report

Print the report below. A run that stopped early reports the step it stopped at, the reason, and what the user does next.

## Report

```markdown
## Merge

Status: MERGED | STOPPED at <step>: <reason>
PR: #<n> <title> (<head> → <base>)
Merge commit: <sha>

### CI
- <workflow>: <conclusion> | none ran (warning: merged without CI)

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
