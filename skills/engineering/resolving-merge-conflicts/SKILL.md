---
name: resolving-merge-conflicts
description: "Finish an in-progress git merge or rebase by resolving each conflict on the intent behind each side, checking the result, and reporting how and why each conflict was resolved. Use when a merge or rebase has stopped on conflicts."
---

# Resolving merge conflicts

Carry an in-progress merge or rebase to a finished, checked result, resolving every conflict by the **intent** behind each side rather than by its text, and report each non-trivial resolution in one line the user can check and override. Read GitHub freely; write only to the local repository.

## Arguments

All optional, and usually passed by the caller:

- **Base** and **head**: the two sides, named per **Base and head**.
- **PR**: the pull request landing the head, a known starting point for the head's sources.
- **Decisions**: decisions the user already made on these conflicts, each naming the point, the side kept, and its timestamp.

## Reference

### Base and head

**Base** is the side the work lands on; **head** is the work landing on it. Git's `ours` and `theirs` swap between operations, so name the sides this way, first match wins:

| Situation | Base | Head |
| --- | --- | --- |
| The caller names the sides | as named | as named |
| Rebase | the branch being rebased onto | the commits being replayed |
| A PR joins the two branches | the PR's base | the PR's head |
| Any other merge | the checked-out branch | the branch being merged in |

### Intent

What one side meant its change to do. Read it from that side's **sources**, for each conflicted hunk:

1. The commits on that side that touched the hunk: `git log --format='%H %s' <merge-base>..<side> -- <path>`, then `git show <sha>` for the ones whose diff reaches the hunk's lines. In a rebase, the replayed commit (`REBASE_HEAD`) is the head side.
2. The PR each commit belongs to: the PR that merged it (`gh api repos/{owner}/{repo}/commits/<sha>/pulls --jq '.[] | select(.merged_at) | .number'`), else, on the head side, the PR landing the head. Other PRs that list the commit only contain it; a commit with no PR of its own rests on its message.
3. Each PR read in full: `gh pr view <n> --json title,body,author,createdAt,comments,reviews,closingIssuesReferences`, plus its review comments: `gh api repos/{owner}/{repo}/pulls/<n>/comments --paginate`.
4. The issues each PR closes or names as implemented, then their parent spec, through the repository's documented issue-tracker workflow.

Without a GitHub remote or an authenticated `gh`, skip the GitHub reads (2 and 3), still read what the documented tracker holds, and say so in the report.

An issue or spec is its body plus its comments, read in order:

- A human comment amends the body. Where a later human comment conflicts with the body or an earlier comment, the later one wins.
- An **agent report**, text an agent posted to report on the work, is context, not a requirement. Use it to learn what was tried, ruled out, or already landed, so dead ends are not repeated; it never adds to or changes what to build.
- An **agent brief**, text written as the specification for an agent to work from, is the specification itself: the body and earlier discussion are context to it, and a later human comment still amends it.

An AI disclaimer, in any wording, marks text an agent wrote; whether that text is a report or a brief is its role: an account of work done, or a specification to work from. Where text carries no disclaimer, tell its author by its content.

A PR body and commit messages are the change's account of itself, whoever wrote them: context, like an agent report. A PR's human comments and reviews amend the issue it closes, as later comments on it.

### Governing statement

Where the two intents disagree on a point, the decision belongs to the **governing statement**: the most recent **deciding statement** on either side, once each spec statement that a deciding statement in its own child issue answers is set aside. A deciding statement is specification text (an issue or spec body, an agent brief, a human comment or review) or a user decision that picks one side's behaviour for the disputed point itself. A user decision is one wherever it is recorded: the **Decisions** argument, the conversation, or a report or record line it decided.

- Date a statement from when its deciding text was written, to the second with its timezone: its creation, or the edit that introduced that text where the edit history shows it. Statements that cannot be ordered decide nothing between them.
- A statement that only touches the same area informs the intent and decides nothing.
- A statement that asks for behaviour neither side has decides nothing; quote it in the conflict's report line.

### Resolution tiers

A **conflict** is one point the two sides disagree on, however many hunks and files carry it. Every conflict resolves into exactly one tier:

- **Trivial**: the result is the union of both sides with no line of either altered (independent additions to imports, lists, changelog entries), or a generated file regenerated with the project's own tool (a lockfile from its manifest).
- **Combined**: both intents survive, with lines of one or both sides adapted to fit (head's new parameter carried onto base's renamed function).
- **Chosen**: the intents are incompatible and one is dropped, in whole or part. The governing statement picks the survivor. With no governing statement, keep the base side and mark the conflict **Needs your decision**.

A change only one side made is not a conflict, even inside a conflicted hunk: it is kept and not counted. A resolution carries only behaviour one of the two intents asks for.

### Changes outside the operation

Changes outside the operation never mix with it. A tracked change, staged or not, on a path the operation does not touch is set aside in step 1 and restored in step 5:

- **Set aside**: save both layers as patches outside the repository, staged (`git diff --binary --cached -- <paths> > <staged>`) and unstaged (`git diff --binary -- <paths> > <unstaged>`), then clear the paths to HEAD with `git restore --source=HEAD --staged --worktree -- <paths>`, which also removes files HEAD does not have. A path holding both such a change and part of the operation stops the run `BLOCKED` before anything is set aside.
- **Restore**: `git apply --index <staged>`, then `git apply <unstaged>`, leaving both layers as they were. When either does not apply cleanly, keep both patches and name them under Warnings.

### Report

```markdown
## Conflict resolution

Status: RESOLVED | BLOCKED: <reason>
Commits: merge `<sha>` | rebased onto `<base>`, now `<sha>`; fix `<sha>`
Checks: passed | <check> fails

Conflicts resolved:
`<base>` merged into `<head>` | `<head>` rebased onto `<base>` | Fixes after either: <n> conflicts.

Needs your decision:
- `<file>:<line>`[, `<file>:<line>` ...] <point>: kept base's <X> over head's <Y>. Why: no statement decides it; <each side's intent and its source>. Override: <the change that restores head's side>.

Chosen by a governing statement:
- `<file>:<line>` <point>: kept <X> over <Y>. Why: <statement, author, date, link>: "<quote>".

Combined:
- `<file>:<line>` <point>: <how both intents were kept>, per <each side's source>.

Trivial: <count> (<short list of what they were>)

Warnings:
- <limits on the read, such as GitHub unavailable, or a set-aside patch that did not re-apply>
```

Each group is a label, not a heading. Omit any group with nothing in it. Each non-trivial conflict is one line naming every place it touched, and counts are of conflicts (`1 conflict`, `2 conflicts`). A line's **point** names what the two sides disagree on in a few words; with the kept side it is the line's identity, so a conflict that matches a known decision reuses that decision's point verbatim. A user's approval of a **Needs your decision** line is appended to it with the ISO 8601 time the user gave it, `Decided <timestamp>: approved.`, and moves the line to **Chosen by a governing statement**; an override is a new resolution with its own line. Example:

```markdown
Needs your decision:
- `src/retry.ts:88` retry log level: kept base's `debug` over head's `warn`. Why: no statement decides it; #61 lowered network logging "to cut noise", head's #42 sets no level. Override: log at `warn` in `logRetry`.

Chosen by a governing statement:
- `src/config/defaults.ts:12` default timeout: kept `30s` over head's `60s`. Why: human comment on #42 (2026-10-30, <link>): "60 is too long, users see a hang; use 30 and retry instead".
```

### Record

A resolution's **record** is part of the commit it records. It is the marker line `<!-- conflict-record -->` followed by the report from `Conflicts resolved:` to its end, covering only what that commit did, written into the commit's message body after a blank line below the subject. A commit this skill makes carries one whenever it resolved a conflict or holds a fix: the merge commit, each replayed commit that stopped in a rebase, and the fix commit. A commit carries at most one record, describing it as it now stands: writing a record replaces any record its message already holds. The printed report joins the run's records under one `Conflicts resolved:` label, each record's first line on its own line; `Status`, `Commits`, and `Checks` are for the caller to act on.

## Workflow

### 1. See the state

Identify the operation in progress (`git status`; a merge has `MERGE_HEAD`, a rebase has a `rebase-merge` or `rebase-apply` directory), name base and head per **Base and head**, and list the conflicted paths: `git diff --name-only --diff-filter=U`. A merge with no conflicted paths, left uncommitted by `--no-commit`, has nothing for steps 2 and 3. Set aside every change outside the operation per **Changes outside the operation**.

**Complete when:** the operation, base, head, and every conflicted path are named, and every change outside the operation is set aside: its patches are saved and `git status --porcelain -- <paths>` is empty.

### 2. Read both intents

For every conflicted hunk, read each side's sources per **Intent** and state each side's intent in a sentence, with the sources it rests on. Where the two intents disagree on a point, find its governing statement, or establish that none exists.

**Complete when:** every hunk has both intents stated with their sources, and every disagreement has its governing statement or a recorded absence of one.

### 3. Resolve every hunk

Edit each hunk to its resolution, stage its path, and assign each conflict its tier per **Resolution tiers**. Carry the operation through: abort is never a resolution.

**Complete when:** no conflict markers remain (`git grep -nE '^(<{7}|={7}|>{7})( |$)' -- <paths>` finds none), every conflicted path is staged, and every conflict has a tier and, unless Trivial, its report line.

### 4. Finish the operation

Commit the merge with its **Record**: `git commit --allow-empty -F <message>`, where the message is a subject in the repo's commit convention (without one, the first line of git's prepared merge message, `git rev-parse --git-path MERGE_MSG`), a blank line, and the record; `--allow-empty` keeps the record of a resolution that leaves nothing to commit. In a rebase, commit each stop the same way, its original message (`git log -1 --format=%B REBASE_HEAD`) followed by the record, then `git rebase --continue`, and work steps 1 to 3 again at each later stop.

**Complete when:** no merge or rebase is in progress, and every commit made carries its record.

### 5. Run the checks

Find the project's automated checks from its agent instructions, then its scripts, and run them. Fix what fails in one commit on top, in the repo's commit convention with its **Record**, staging only the paths the fix touched. A fix is a conflict like any other: it carries only behaviour one of the two intents asks for, and is tiered and reported the same way. When a check still fails, leave the result committed locally and report `BLOCKED: <check> fails`, with the failing output, and say whether the merge base fails it too.

Then restore what step 1 set aside per **Changes outside the operation**.

**Complete when:** every check passes, or the status is `BLOCKED` with the failing check and its output; every change this skill made is committed; and every set-aside change is restored or its patches named.

### 6. Report

Print the **Report**.

**Complete when:** the report is printed with every non-trivial conflict, fixes included, on its own line.
