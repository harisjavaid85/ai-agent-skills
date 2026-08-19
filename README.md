# AI Agent Skills

_Forked from [Matt Pocock's "Skills For Real Engineers"](https://github.com/mattpocock/skills)._

[![skills.sh](https://skills.sh/b/harisjavaid85/ai-agent-skills)](https://skills.sh/harisjavaid85/ai-agent-skills)

Developing real applications is hard. Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control and make bugs in the process hard to resolve.

These skills are designed to be small, easy to adapt, and composable. They work with any model. They're based on decades of engineering experience. Hack around with them. Make them your own. Enjoy.

## Quickstart (30-second setup)

1. Run the skills.sh installer:

```bash
npx skills@latest add harisjavaid85/ai-agent-skills
```

2. Pick the skills you want, and which coding agents you want to install them on. Select `/setup-repo-skills` when using the issue-lifecycle skills.

3. Run `/setup-repo-skills` in your agent. It will:
   - Wire up `.gitignore` for the agent working directories (`.plans/`, `.handoffs/`), plus Claude Code settings when that harness is active
   - Ask whether this repo is `prototype`, `standard`, or `production` (tunes how aggressively skills push for tests, error handling, and refactoring)
   - Propose a per-language coding standard (a style-guide binding, e.g. Google Python) so agents write high-quality code by default
   - Record your issue-tracker choice (GitHub, GitLab, or local markdown) — the workflow `/to-spec`, `/to-tickets`, and `/triage` read
   - Ask what labels represent your triage roles, then create any required tracker labels that are missing (GitHub only)
   - Write the `docs/agents/` config the other skills read

4. Bam - you're ready to go.

## Full setup (from a clone)

If you've cloned this repo and want the whole workflow, rather than installing a subset via skills.sh:

### Once per machine

1. Install every skill into the local harness skill directories (`~/.claude/skills` and `~/.agents/skills`):

```bash
./scripts/link-skills.sh
```

Each entry is a symlink into this repo, so a `git pull` keeps installed skills current; re-run the script after adding, removing, or renaming a skill.

2. When using Claude Code, `/setup-claude-code` bootstraps your global `~/.claude` config.

### Once per repo

3. `/setup-repo-skills` — required before `/to-spec`, `/to-tickets`, and `/triage`; strongly recommended for other engineering and agent-loop workflows.
4. `/bootstrap-context` — create the repo's `CONTEXT.md` glossary so skills speak your project's language.

## Install as a Claude Code plugin

Prefer a plug-and-play install you don't maintain by hand? These skills also ship as a native [Claude Code plugin](https://code.claude.com/docs/en/plugins). Instead of copying editable files into your repo, the plugin installs the whole skill set as a managed bundle that updates when a new version ships — you subscribe rather than fork.

Inside Claude Code:

```
/plugin marketplace add harisjavaid85/ai-agent-skills
/plugin install ai-agent-skills@harisjavaid85
```

Or from your shell:

```bash
claude plugin marketplace add harisjavaid85/ai-agent-skills
claude plugin install ai-agent-skills@harisjavaid85
```

Then run `/setup-repo-skills` once per repo, exactly as in the quickstart above.

Two ways to install, two philosophies:

- **[skills.sh](https://skills.sh/harisjavaid85/ai-agent-skills)** copies the skills into your project so you can hack on them and make them your own.
- **The plugin** keeps them as a read-only, always-current bundle you don't edit — best when you just want the set to work and follow along as it evolves.

## Why These Skills Exist

I built these skills as a way to fix common failure modes I see with Claude Code, Codex, and other coding agents.

### #1: The Agent Didn't Do What I Want

> "No-one knows exactly what they want"
>
> David Thomas & Andrew Hunt, [The Pragmatic Programmer](https://www.amazon.co.uk/Pragmatic-Programmer-Anniversary-Journey-Mastery/dp/B0833F1T3V)

**The Problem**. The most common failure mode in software development is misalignment. You think the dev knows what you want. Then you see what they've built - and you realize it didn't understand you at all.

This is just the same in the AI age. There is a communication gap between you and the agent. The fix for this is a **grilling session** - getting the agent to ask you detailed questions about what you're building.

**The Fix** is to use:

- [`/grill-me`](./skills/productivity/grill-me/SKILL.md) - for non-code uses
- [`/grill-with-context`](./skills/engineering/grill-with-context/SKILL.md) - same as [`/grill-me`](./skills/productivity/grill-me/SKILL.md), but adds more goodies (see below)

These are my most popular skills. They help you align with the agent before you get started, and think deeply about the change you're making. Use them _every_ time you want to make a change.

### #2: The Agent Is Way Too Verbose

> With a ubiquitous language, conversations among developers and expressions of the code are all derived from the same domain model.
>
> Eric Evans, [Domain-Driven-Design](https://www.amazon.co.uk/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215)

**The Problem**: At the start of a project, devs and the people they're building the software for (the domain experts) are usually speaking different languages.

I felt the same tension with my agents. Agents are usually dropped into a project and asked to figure out the jargon as they go. So they use 20 words where 1 will do.

**The Fix** for this is a shared language. It's a document that helps agents decode the jargon used in the project.

<details>
<summary>
Example
</summary>

Here's an example [`CONTEXT.md`](https://github.com/mattpocock/course-video-manager/blob/076a5a7a182db0fe1e62971dd7a68bcadf010f1c/CONTEXT.md), from my `course-video-manager` repo. Which one is easier to read?

- **BEFORE**: "There's a problem when a lesson inside a section of a course is made 'real' (i.e. given a spot in the file system)"
- **AFTER**: "There's a problem with the materialization cascade"

This concision pays off session after session.

</details>

This is built into [`/grill-with-context`](./skills/engineering/grill-with-context/SKILL.md). It's a grilling session, but that helps you build a shared language with the AI, and document hard-to-explain decisions in ADR's.

It's hard to explain how powerful this is. It might be the single coolest technique in this repo. Try it, and see.

> [!TIP]
> A shared language has many other benefits than reducing verbosity:
>
> - **Variables, functions and files are named consistently**, using the shared language
> - As a result, the **codebase is easier to navigate** for the agent
> - The agent also **spends fewer tokens on thinking**, because it has access to a more concise language

### #3: The Code Doesn't Work

> "Always take small, deliberate steps. The rate of feedback is your speed limit. Never take on a task that’s too big."
>
> David Thomas & Andrew Hunt, [The Pragmatic Programmer](https://www.amazon.co.uk/Pragmatic-Programmer-Anniversary-Journey-Mastery/dp/B0833F1T3V)

**The Problem**: Let's say that you and the agent are aligned on what to build. What happens when the agent _still_ produces crap?

It's time to look at your feedback loops. Without feedback on how the code it produces actually runs, the agent will be flying blind.

**The Fix**: You need the usual tranche of feedback loops: static types, browser access, and automated tests.

For automated tests, a red-green-refactor loop is critical. This is where the agent writes a failing test first, then fixes the test. This helps give the agent a consistent level of feedback that results in far better code.

I've built a **[`/tdd`](./skills/engineering/tdd/SKILL.md) skill** you can slot into any project. It encourages red-green-refactor and gives the agent plenty of guidance on what makes good and bad tests.

For debugging, I've also built a **[`/diagnosing-bugs`](./skills/engineering/diagnosing-bugs/SKILL.md)** skill that wraps best debugging practices into a simple loop.

### #4: We Built A Ball Of Mud

> "Invest in the design of the system _every day_."
>
> Kent Beck, [Extreme Programming Explained](https://www.amazon.co.uk/Extreme-Programming-Explained-Embrace-Change/dp/0321278658)

> "The best modules are deep. They allow a lot of functionality to be accessed through a simple interface."
>
> John Ousterhout, [A Philosophy Of Software Design](https://www.amazon.co.uk/Philosophy-Software-Design-2nd/dp/173210221X)

**The Problem**: Most apps built with agents are complex and hard to change. Because agents can radically speed up coding, they also accelerate software entropy. Codebases get more complex at an unprecedented rate.

**The Fix** for this is a radical new approach to AI-powered development: caring about the design of the code.

This is built in to every layer of these skills:

- [`/to-spec`](./skills/engineering/to-spec/SKILL.md) quizzes you about which modules you're touching before creating a spec

And crucially, [`/improve-codebase-architecture`](./skills/engineering/improve-codebase-architecture/SKILL.md) helps you rescue a codebase that has become a ball of mud. I recommend running it on your codebase once every few days.

### Summary

Software engineering fundamentals matter more than ever. These skills are my best effort at condensing these fundamentals into repeatable practices, to help you ship the best apps of your career. Enjoy.

## Reference

These split on one axis — who can invoke them. **User-invoked** skills are reachable only when you type them (e.g. `/grill-me`); their job is to orchestrate. **Model-invoked** skills can be invoked by you _or_ reached for automatically by the agent when the task fits; they hold the reusable discipline. A user-invoked skill may invoke model-invoked skills, but never another user-invoked one.

### Engineering

Skills I use daily for code work.

**User-invoked**

- **[ask-author](./skills/engineering/ask-author/SKILL.md)** — Ask which skill or flow fits your situation. A router over the user-invoked skills in this repo.
- **[bootstrap-context](./skills/engineering/bootstrap-context/SKILL.md)** — Create or refresh the repo's domain-language glossary and context map in a single batched pass; the audit counterpart to `/domain-modeling`'s inline mode.
- **[grill-with-context](./skills/engineering/grill-with-context/SKILL.md)** — Grilling session that also builds your project's domain model, sharpening terminology and updating `CONTEXT.md` and ADRs inline.
- **[improve-codebase-architecture](./skills/engineering/improve-codebase-architecture/SKILL.md)** — Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.
- **[to-spec](./skills/engineering/to-spec/SKILL.md)** — Turn the current conversation into a spec and publish it to the issue tracker. No interview — just synthesizes what you've already discussed.
- **[to-tickets](./skills/engineering/to-tickets/SKILL.md)** — Break any plan, spec, or conversation into a set of tracer-bullet tickets, each declaring its blocking edges — written as text in a local file, or as native blocking links on a real tracker.
- **[triage](./skills/engineering/triage/SKILL.md)** — Move issues and external PRs through a state machine of triage roles.
- **[wayfinder](./skills/engineering/wayfinder/SKILL.md)** — Plan a huge chunk of work, more than one agent session can hold, as a shared map of investigation tickets on the issue tracker — resolve them one at a time until the way to the destination is clear.

**Model-invoked**

- **[codebase-design](./skills/engineering/codebase-design/SKILL.md)** — Shared discipline and vocabulary for designing deep modules: a lot of behaviour behind a small interface, placed at a clean seam, testable through that interface.
- **[code-review](./skills/engineering/code-review/SKILL.md)** — Two-axis review of the complete working-tree change set since a fixed point: **Standards** (does it follow the repo's coding standards, plus a Fowler smell baseline?) and **Spec** (does it faithfully implement the originating issue/spec?), run as parallel sub-agents so neither pollutes the other.
- **[commit](./skills/engineering/commit/SKILL.md)** — Stage and commit working-tree changes: group them into a sensible commit plan, write concise tagged messages following the repo's convention, and commit only after approval.
- **[diagnosing-bugs](./skills/engineering/diagnosing-bugs/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: reproduce → minimise → hypothesise → instrument → fix → regression-test.
- **[domain-modeling](./skills/engineering/domain-modeling/SKILL.md)** — Actively build and sharpen a project's domain model — challenge terms against the glossary, stress-test with edge-case scenarios, and update `CONTEXT.md` and ADRs inline.
- **[implement](./skills/engineering/implement/SKILL.md)** — Build one explicit issue, plan, or settled conversation autonomously through `/tdd` and one remediated `/code-review`, leaving the result uncommitted.
- **[open-pr](./skills/engineering/open-pr/SKILL.md)** — Push the current branch and open or update its GitHub PR in a standard format: a tagged title, a summary, and a curated change list, with optional spec-slug enrichment.
- **[prototype](./skills/engineering/prototype/SKILL.md)** — Build a throwaway prototype to answer a design question — a runnable terminal app for state/logic questions, or several radically different UI variations toggleable from one route.
- **[research](./skills/engineering/research/SKILL.md)** — Investigate a question against high-trust primary sources and capture the findings as a cited Markdown file in the repo, run as a background agent.
- **[resolving-merge-conflicts](./skills/engineering/resolving-merge-conflicts/SKILL.md)** — Work through an in-progress git merge or rebase conflict hunk by hunk, resolving by intent traced to each side's primary source, then finish the operation — never `--abort`.
- **[tdd](./skills/engineering/tdd/SKILL.md)** — Test-driven development with a red-green-refactor loop. Builds features or fixes bugs one vertical slice at a time.


### Productivity

General workflow tools, not code-specific.

**User-invoked**

- **[grill-me](./skills/productivity/grill-me/SKILL.md)** — Get relentlessly interviewed about a plan or design until every branch of the decision tree is resolved.
- **[handoff](./skills/productivity/handoff/SKILL.md)** — Compact the current conversation into a handoff document so another agent can continue the work.
- **[setup-claude-code](./skills/productivity/setup-claude-code/SKILL.md)** — Bootstrap a machine's global Claude Code setup at `~/.claude/`: permissions baseline, dangerous-command hook, optional statusline. Supports `host` / `sandbox` / `guardrails` modes.
- **[teach](./skills/productivity/teach/SKILL.md)** — Teach the user a new skill or concept over multiple sessions, using the current directory as a stateful teaching workspace.
- **[writing-great-skills](./skills/productivity/writing-great-skills/SKILL.md)** — Reference for writing and editing skills well: the vocabulary and principles that make a skill predictable.

**Model-invoked**

- **[cross-check-with-codex](./skills/productivity/cross-check-with-codex/SKILL.md)** — Cross-check an artifact with Codex through an independent review loop and local audit record.
- **[grilling](./skills/productivity/grilling/SKILL.md)** — Interview the user relentlessly about a plan, decision, or idea until every branch of the decision tree is resolved. The reusable loop behind `grill-me` and `grill-with-context`.
- **[write-a-skill](./skills/productivity/write-a-skill/SKILL.md)** — Convert settled requirements into a well-structured skill (steps, reference, progressive disclosure). Grill first if scope is fuzzy.
