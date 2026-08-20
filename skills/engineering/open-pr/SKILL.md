---
name: open-pr
description: Open or update a GitHub pull request from the current branch in a standard format, with optional spec-slug enrichment (proposes for approval by default, or opens automatically in auto mode). Use when the user wants to open, create, update, or refresh a PR, or when an agent needs to compose a PR in a standard format.
---

# Open PR

Push the current branch and open (or update) its GitHub pull request with a standard title and body. Idempotent: re-running pushes new commits and refreshes the PR. It opens a PR only, and never commits or merges.

## Modes

- **Review (default, plain `/open-pr`):** compose the title and body, emit the plan, and wait for approval. User approving the plan _is_ the go-ahead to push and create/update.
- **Auto (`/open-pr auto`):** emit the plan, then push and create/update best-effort without blocking. Where review mode would stop to ask, auto takes the safe default and keeps going. This is the path an agent invokes.

## Arguments

All optional, parsed loosely from the invocation:

- `auto`: Auto mode.
- `<slug>`: turn on lifecycle enrichment for a `spec:<slug>` parent (see **Slug enrichment**).
- `draft`: open PR as a draft instead of ready-for-review.
- `base=<branch>`: override the base branch.

Callers may also supply an **extra markdown block** (see **Caller extra block**).

## Workflow

1. **Preflight.** Confirm a GitHub remote exists and `gh` is authenticated (`git remote -v`, `gh auth status`). If either fails, report the blocker and stop, because a PR is impossible. Both modes.
2. **Check the branch.** Resolve the base (see **Base**). Then:
   - HEAD **is** the base/default branch → refuse; a branch can't PR itself. Tell the user to branch first.
   - No commits ahead of base (`git log <base>..HEAD` empty) → report "nothing to PR" and stop.
   - Working tree **dirty** → _Review:_ stop, "uncommitted changes; run `/commit` first" (approval is not a license to commit them). _Auto:_ push only committed work and report what was left uncommitted.
3. **Detect an existing PR:** `gh pr list --head <branch> --json number,url --limit 1`. Capture the number if one exists: this is the update path.
4. **Compose** the title and body per **Format**.
5. **Build the plan:** title, base, draft/ready, body preview, and any warnings (dirty tree, ambiguous tag, suspected non-default base). In Review, wait for approval; in Auto, print it as a trail and proceed.
6. **Push:** `git push -u origin <branch>` (idempotent; sets upstream if unset). Pushing new commits refreshes the PR's diff on its own.
7. **Create or update:**
   - **No PR exists:** `gh pr create --base <base> --head <branch> --title "<title>" --body-file <body>` (add `--draft` when `draft` is set). Write the body with the `Write` tool to `<tmpdir>/pr-body-<branch-slug>.md`, resolving `<tmpdir>` from `$TMPDIR` and falling back to `/tmp`, then pass it via `--body-file`. It lives outside the repo, so the working tree stays clean.
   - **PR exists:** `gh pr edit <number> --body-file <body>` (and `--title` if it changed). See **Re-run** for body handling. **Never** change the existing PR's draft/ready state.

## Re-run (existing PR)

Always push. Then refresh the body:

- **Review:** compose the fresh body and compare it to the live PR body. If they diverge, show the diff and ask: keep / replace / merge. The diff surfaces any hand-edit before it's overwritten; there is no pre-set default.
- **Auto:** regenerate and overwrite unconditionally.

Draft/ready is set only at create time. A re-run never toggles it.

## Base

Default to GitHub's default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`. `base=<branch>` overrides. In Review, if the branch's tracking info or merge-base points at a non-default base, surface it and ask; in Auto, use the default silently. The change list derives from `git log <base>..HEAD`, so the body stays consistent with the chosen base.

## Slug enrichment

With a `<slug>`, add the **Spec** and **Tickets completed** sections (see **Format**). The spec lives either on the issue tracker or as files in the branch. Resolve which with two slug-scoped probes, first answer wins:

1. **GitHub**: `gh issue list --label "spec:<slug>" --label "kind:spec" --state open --json number --limit 1`
2. **Local**: `git cat-file -e HEAD:.scratch/<slug>/spec.md`

Probe the branch, not the repo's tracker configuration: the tracker is a property of the spec, so a repo configured for GitHub can still carry a local queue for one feature. When both answer, GitHub wins: `Implements #n` and `Closes #n` carry linking and auto-close semantics that files cannot.

Then list the completed tickets for whichever answered:

- **GitHub**: `gh issue list --state closed --label "spec:<slug>" --json number,title,labels --jq '[.[] | select([.labels[].name] | index("kind:spec") | not)]'`.
- **Local**: `git ls-tree --name-only HEAD .scratch/<slug>/issues/`, then `git show HEAD:<path>` for each. A ticket counts as completed when its `Status:` line reads `closed`, bolding optional (`**Status:** closed`); its title is the file's first heading.

If neither probe answers, do **not** fail. Warn, skip enrichment, and open the standalone PR. Review notes it in the plan; Auto proceeds and reports.

## Caller extra block

A caller may provide an extra markdown block: its own sections such as remaining issues, stuck branches, or a status note. Append it verbatim after the last standard section. `open-pr` stays ignorant of the caller's semantics.

## Failure handling

- **No remote / `gh` unauthenticated:** hard stop, both modes; report the blocker, do nothing partial.
- **Push succeeds but PR creation fails:** partial remote state: the branch is up, no PR. Report it and say _re-run to retry_; the re-run finds no PR and creates it, and the bare pushed branch needs no unwinding.

## Format

The body is read by people who have only the repository and this PR: the branch diff, the commit history, and any linked GitHub issues. Every term and reference must resolve from those. Name only what such a reader can open: a file committed on the branch, a GitHub issue, a checked-in doc. Uncommitted and gitignored files, internal work-block or task slugs, conversation-only codenames, and any "the plan"/"the doc" resolve for nobody else. When one is load-bearing, restate its substance in plain terms or link something public instead.

### Title

`[Tag] imperative summary`, in imperative mood with no trailing period. Pick the **dominant** tag across the branch's commits. Tag source, in order:

1. If `docs/agents/commit-tags.md` is present → use its vocabulary and subject template.
2. Otherwise:
   - Infer from the branch's own commit subjects (`git log <base>..HEAD`); mirror their style (bracketed `[Feature]`, Conventional `feat:`, etc.).
   - If commits carry no recognizable tags → no bracket; the title is the plain imperative summary. Never fabricate a tag.

Review asks when the commits' tags are genuinely mixed or ambiguous; Auto picks the dominant silently.

### Body

Compose the sections in the following order, with these conditions:

- **AI disclosure**: Auto mode prepends `Generated by an AI agent.`; Review mode omits it. Do **not** append any tool-generated or default trailer or a `Co-Authored-By:` line.
- **Spec** and **Tickets completed** sections appear only when a `<slug>` is provided.
- **Changes** appears when the branch has more than one logical change; omit it when a single clean commit makes the Summary sufficient.
- **Testing** appears only when real verification was performed: state what was run, never an aspirational plan; omit otherwise.
- **Notes** appears only when there's a genuine callout: out-of-scope / follow-ups, a known limitation or risk, a deliberate deviation from a reader-visible plan/spec (describe the deviation itself; never name a local plan file), a migration/deploy caveat, a pointer to where a reviewer should start or the riskiest part to scrutinize, or, for UI changes, a reminder to attach before/after screenshots. Terse bullets; omit the section otherwise.

Those two sections reference their tickets in the form the answering probe resolves:

| Probe | `<spec ref>` | `<ticket ref>` |
| --- | --- | --- |
| **GitHub** | `Implements #<parent>.` | `Closes #<n>` |
| **Local** | `[Spec: <slug>](<permalink>)` | `[<NN>](<permalink>)` |

A local permalink pins the commit (`<repo-url>/blob/<sha>/<path>` for the file the probe found, from `gh repo view --json url -q .url` and `git rev-parse HEAD`) so it resolves during review, while those files exist only on the branch, and stays good after the branch is deleted. A bare `#<NN>` there would auto-link to whichever issue holds that number.

```markdown
<AI disclosure>

## Summary

<2-3 sentences: what changed and why, drawn from the diff and commits, not from local planning context>

## Spec

<spec ref>

## Changes

<3-6 thematic bullets grouped by logical change, not one per commit. Derive from `git log <base>..HEAD` and the diff, but curate: merge WIP/fixup commits into the change they serve.>

- <change>
- ...

## Testing

<what was actually run to verify: commands, suites, or manual steps a reviewer can reproduce.>

- <what was run → result>
- ...

## Tickets completed (<N>)

- <ticket ref>: <title>
- ...

## Notes

- <note>
- ...

<caller extra block, if any>
```
