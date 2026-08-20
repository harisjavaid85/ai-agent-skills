## What it does

`code-review` reviews the complete working-tree change set since a fixed point you supply (a commit, branch, tag, or merge-base) along two separate axes: **Standards** (does the code follow this repo's documented conventions?) and **Spec** (does it implement what the originating issue or spec asked for?). The change set includes committed, staged, unstaged, and untracked work. It runs each axis as its own parallel sub-agent and reports them side by side. It never merges or re-ranks the two sets of findings, because keeping them separate is the whole point, because a change can pass one axis and fail the other, and a single blended verdict lets one mask the other.

## When to reach for it

Type `/code-review`, or the agent reaches for it automatically when you ask to review a branch, a PR, work-in-progress changes, or anything "since X".

Reach for this when there is a change set to judge against a known-good point and you want the two questions, *is it built right?* and *is it the right thing?*, answered independently. It works before or after commit. For actually writing the code test-first, use [tdd](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/tdd.md), and for building a whole work item use [implement](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/implement.md), which runs and remediates one `/code-review` pass internally.

## Prerequisites

The **Spec** axis needs somewhere to find the originating spec: a source the caller supplies, an issue reference in the commit messages, or a spec under `docs/`/`specs/`. That issue-tracker wiring comes from [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md); without a spec the Spec axis simply skips and says so. The **Standards** axis needs nothing set up: it always carries a built-in Fowler smell baseline even in a repo that documents no conventions.

## Two axes, never merged

The defining idea is the **two axes**. **Standards** asks whether the change set conforms to how this repo writes code: its `CODING_STANDARDS.md` or `CONTRIBUTING.md`, plus a fixed baseline of ~12 Fowler code smells (Mysterious Name, Duplicated Code, Feature Envy, Data Clumps, …). Two rules keep the baseline safe: a documented repo standard always overrides it, and every smell is a judgement call, never a hard violation. **Spec** asks the orthogonal question: does the code do what the issue or spec actually asked, without missing requirements or smuggling in scope creep?

They run as parallel sub-agents so neither pollutes the other's context, and the final report presents them under separate `## Standards` and `## Spec` headings with a per-axis summary. There is deliberately no single winner across axes. The skill reports findings; its caller owns remediation.

## It's working if

- It pins and confirms the fixed point first (`git rev-parse`), failing fast on a bad ref or empty included change set rather than inside the sub-agents.
- It covers committed, staged, unstaged, and untracked work while honoring caller-supplied exclusions.
- Standards and Spec findings arrive in two distinct blocks, each citing its source: a repo standard or baseline smell for one, a quoted spec line for the other.
- When no spec can be found, the Spec axis reports "no spec available" instead of inventing requirements.

## Where it fits

`code-review` is the review engine inside `implement` in the main build chain:

```txt
grill-with-context → to-spec → to-tickets → implement → commit → open-pr
```

Its closest neighbour is [implement](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/implement.md), which drives the build, runs this review once, fixes valid findings, and leaves the working tree for a separate commit. Reach for `code-review` directly to review a branch, PR, or uncommitted work against a fixed point; upstream, the spec it checks against is produced by [to-spec](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-spec.md) and [to-tickets](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/to-tickets.md). When you're unsure which skill or flow fits, [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes you.
