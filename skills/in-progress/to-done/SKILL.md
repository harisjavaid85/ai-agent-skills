---
name: to-done
description: Drain a spec's agent-ready tickets to a reviewed draft PR, running each ticket unattended in a sandboxed container.
disable-model-invocation: true
---

# To Done

Drain a ticket queue to a draft PR, unattended.

Every ticket gets a **fresh context** (a new container, a new agent, one ticket) so the last ticket is implemented as sharply as the first. Between tickets the loop re-plans against live tracker state, so a ticket that lands, stalls, or gets relabelled mid-run changes what comes next.

This skill runs a queue; it never fills one. Point it at a slug `/to-tickets` has already published.

## Arguments

`/to-done <slug> [phase]`

- `<slug>`: a `spec:<slug>` label on the issue tracker, or a `.scratch/<slug>/` directory. The loop detects which.
- `[phase]`: run a single phase and stop, for inspection. Omit to run the whole loop.

| Phase | Does |
| --- | --- |
| `auto` (default) | Plan → implement → commit → repeat until the queue drains, then open and review the PR |
| `plan` | Print the frontier and stop. Writes nothing |
| `implement <ticket>` | Take one ticket from open to closed |
| `pr` | Open or refresh the draft PR |
| `review` | Review the PR |

## Credentials

`.to-done/secrets` in the target repo, and nowhere else. The loop reads no credentials from the environment, because an agent launching this skill cannot see the human's exported variables. Set it up once:

```sh
mkdir -p .to-done
cp <skill-dir>/secrets.example .to-done/secrets
chmod 600 .to-done/secrets
```

Fill in one value per group; the file explains each. It must stay gitignored, and `.to-done/.gitignore` is where that rule belongs, so it travels with the directory. Nothing is written into the image. The loop startup reports what each provider resolved to.


## Optional settings

| Variable | Effect |
| --- | --- |
| `TO_DONE_IMAGE` | Sandbox image to run phases in. Defaults to `to-done:<repo>` |
| `TO_DONE_SETUP` | Shell command run once per container before the agent starts: the repo's dependency install, when a bare checkout is not enough to build and test from. The loop copies a host `node_modules` into each worktree when one exists, so a JavaScript repo usually needs none, until a native addon does not match the image's Node, below |
| `TO_DONE_MODEL` | Model for every phase |
| `TO_DONE_MODEL_PLANNER`<br>`TO_DONE_MODEL_IMPLEMENTER`<br>`TO_DONE_MODEL_PR_COMPOSER`<br>`TO_DONE_MODEL_PR_REVIEWER` | Model for one phase; beats `TO_DONE_MODEL` |

By default Opus implements and reviews, Sonnet plans and composes. The loop prints the resolved set on startup, and every log directory records which models produced that run.

Anything in this table can also live in the target repo's `.to-done/config`, as `KEY=value` lines; the host environment wins over the file. `config` is committed, so credentials never go there; they go in the gitignored `secrets` beside it.

## Per-project setup

The image is two layers: `to-done:base` (node, `gh`, `claude`, `codex`, skills) and `to-done:<repo>` on top of it.

A repo a bare checkout can already build needs nothing: `build-image.sh` tags the base as `to-done:<repo>`. A repo needing more adds `.to-done/Dockerfile` starting `FROM ${BASE_IMAGE}`; the build context is the repo root, so it can `COPY` lockfiles.

Every phase is a fresh container, so anything installed at container start is paid once per ticket. Warm the package store and interpreter cache in the image and let `TO_DONE_SETUP` link from them. Do not bake the installed `node_modules` or virtualenv, because those go *wrong* when a ticket edits a lockfile, where a stale cache only costs time.

Three things that bite:

- The host `node_modules` is copied into every worktree, so a native addon built against the host's Node ABI is loaded by the image's. Anything that is not N-API then fails to load, and it surfaces as the repo's own suite throwing from a package no ticket touched. The loop warns at startup when the two ABIs differ; the rebuild goes in `TO_DONE_SETUP`, e.g. `pnpm rebuild better-sqlite3`.
- If the repo's root `.dockerignore` was written for another image, add `.to-done/Dockerfile.dockerignore`. BuildKit prefers it when the Dockerfile is passed with `--file`, and without one the other image's exclusions apply and the whole repo uploads on every build.
- `.to-done/` also holds run logs and `secrets`, so give it a `.gitignore` containing `logs/` and `secrets`.

## 1. Preflight the repo

The loop inherits whatever state it starts from, and it runs for hours without a human. Confirm, in the target repo:

- The base commit is the one intended, and the verify tier from the repo's agent guide passes on it. Every phase runs in a worktree of `agent/<slug>`, so uncommitted host work is never in the container; commit anything the tickets build on. A red baseline makes every ticket look broken.
- The host can push. The loop pushes the shared branch itself, using the `GH_TOKEN` from `secrets`.
- `docs/agents/triage-labels.md` exists and maps `ready-for-agent`, `ready-for-human`, and `wontfix`. The loop reads this repo's actual label strings from it and refuses to start without it, rather than guessing and finding an empty queue.
- `.sandcastle/` is gitignored (the loop writes worktrees there) and `.to-done/.gitignore` covers `logs/` and `secrets`.

Report any failure and stop. Do not repair the baseline as part of this skill.

**Complete when:** the baseline is intended and green, `gh` is authenticated, and the triage-label map is present.

### The shared branch

The loop creates `agent/<slug>` from `HEAD` if it does not exist. To run against a different base, create it first; the loop uses whatever it finds.

For a `.scratch/<slug>/` queue, nothing needs committing by hand. The loop copies the queue onto the branch itself, so the agents can read a ticket and record closing it. That seed is the handover: **before it, the working copy is the queue; after it, the branch is**, which is what the implementers write to, and the local analogue of the GitHub remote.

So a queue edited after the run starts is ignored, and the loop warns when it spots that. To change the queue mid-spec, commit to `agent/<slug>`; to start the spec over, delete the branch and relaunch. Do not check the branch out and leave it checked out. The loop moves the ref without touching a working tree, which would show as a phantom diff in yours.

## 2. Launch

Run from the target repo's root. Substitute this skill's base directory for `<skill-dir>`; Node 22.18 or newer runs the `.mts` file with no build step.

```sh
mkdir -p .to-done/logs
console=".to-done/logs/console-$(date -u +%Y%m%dT%H%M%SZ).log"
setsid sh -c 'echo $$ > .to-done/logs/run.pid; exec node <skill-dir>/scripts/loop.mts <slug>' \
  > "$console" 2>&1 < /dev/null &
echo "$console"
```

`setsid` is load-bearing. The run lasts hours, and a plain background job is killed with the shell that started it, so a run launched from an agent session dies mid-ticket the moment that session ends. A new session detaches it from that. Nothing is then watching stdout, hence the redirect: `$console` is the run's own narrative, and its first line names the directory the per-phase logs land in. Report both. `run.pid` is how the run is stopped.

The loop checks its own launch and **refuses to start** when a ticket could not be read, when nothing is workable, or when a `.scratch/<slug>/` directory shadows a live GitHub queue. These are the mistakes no runtime guard catches, because they are about whether the loop was aimed at the right thing at all.

If it refuses, report the reason and stop. Do not pass `--force` on the user's behalf: that flag is for a human who has read the warning and decided it is fine anyway.

It also refuses if the sandbox image is missing, naming `scripts/build-image.sh`. Run that from the target repo's root, let it finish, then retry. If it instead *warns* that the image bakes an older skills commit, report the warning: the run will proceed on skills as they were at that commit, which is a rebuild away from being fixed but silent if ignored.

To inspect without launching, `... <slug> plan` prints `workable`, `remaining`, `excluded`, and the same warnings, and writes nothing.

**Complete when:** the loop is running detached, and the user has the console log and the log directory.

## 3. Report the outcome

The loop exits `0` when the queue drained, `1` when it stopped early. Either way it opens or refreshes a draft PR and runs the review.

The PR's labels say which of the two it is, and the loop verifies both states rather than assuming them:

| Labels | Means |
| --- | --- |
| `spec:<slug>` + `needs-info` | The loop stopped early, or the review did not finish. Unstick it; do not review yet |
| `spec:<slug>` + `ready-for-human` | Drained and reviewed. Yours to look at |

It is assigned to the token owner either way. Repeat any "missing" line the loop prints, because a draft PR with no label looks exactly like one still being worked on.

Report the exit status, the PR, and, when it stopped early, the reason the loop recorded in the PR body. Leave the PR in draft; promoting it to ready is the user's call.

**Complete when:** the user has the PR link, the terminating reason, and confirmation the handoff landed.
