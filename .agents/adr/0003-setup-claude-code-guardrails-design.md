# Layered guardrails design for `setup-claude-code`

The `setup-claude-code` skill installs Claude Code guardrails (`~/.claude/settings.json` permissions + a `~/.claude/hooks/block-dangerous-bash.sh` PreToolUse hook). Two cross-cutting design decisions shape what gets installed and how it's enforced, a third applies the first to network tools, and a fourth sets the principles every hook rule follows. They reinforce each other, so they live in one ADR.

The first three are constrained by one Claude Code semantic: **`deny` always beats `allow` across every layer of the settings cascade** (enterprise → CLI → `.claude/settings.local.json` → `.claude/settings.json` → `~/.claude/settings.json`). Anything that should be per-repo-overridable must stay out of global `deny`: once globally denied, no lower-precedence `allow` (or hook) can re-enable it. The same holds for global `ask`: rules evaluate deny, then ask, then allow across all scopes, so a repo-level `allow` never beats a global `ask` (see Sub-decision 3).

## Sub-decision 1: Enforcement axis: hook vs static permissions

**Decision:** A guardrail goes into the **hook** when it needs syntactic-variant matching (e.g. `rm -rf` vs `rm -fr` vs `rm --recursive --force` vs `bash -c "rm -rf …"`) or conditional logic (e.g. `git push` to feature branches OK, push to `main`/`master` blocked). Everything else goes into the **static** `permissions.deny` / `permissions.ask` lists.

**Trade-off:** Hooks catch more (syntactic variants, conditional rules) but are opaque bash: Claude can't see them at plan time. Static permissions are introspectable (Claude reads them and avoids forbidden actions before attempting) and benefit from schema validation, but can only express flat glob/string matches.

**Rejected alternative:** Putting overlapping rules in both layers (defense-in-depth). Rejected because keeping two layers in sync creates drift risk, and the `ask` semantic conflicts with hook-based silent allows (worst-of-both UX).

**Discoverability:** Because guardrails span two files, the skill regenerates `~/.claude/GUARDRAILS.md` on every run as the single human-readable audit surface.

## Sub-decision 2: Deployment profile: host vs sandbox

**Status:** Superseded in part (2026-11-05). The `sandbox` profile was removed because it was never used; `host` and `guardrails` remain. The record below is kept as written.

**Decision:** The skill ships two named profiles selected by argument (`/setup-claude-code host` or `/setup-claude-code sandbox`, plus a `guardrails`-only mode). The `sandbox` profile is for running Claude Code inside an automated Docker sandbox; the `host` profile is for a developer machine. When no argument is given, Claude asks the user interactively.

**Trade-off:** Sandbox calibrates for autonomy, dropping the `.env*` / app-config reads that would block legitimate test setup inside a disposable container. Host calibrates for safety on a long-lived machine where the file system is the safety boundary, not the container.

**Invariant preserved across both profiles:** denies for SSH/AWS/GPG keys and shell-history files, and `ask` for public-state-mutating commands (`npm publish`, `docker push`, `kubectl delete`). The sandbox boundary doesn't protect against these, because published packages and registry pushes cross it.

**Rejected alternative:** Auto-detecting `/.dockerenv` and switching profiles silently. Rejected because explicit profile selection is auditable and works reliably in non-interactive Dockerfile bootstrap (`RUN claude -p "/setup-claude-code sandbox"`).

## Sub-decision 3: Network tools go through the hook, not static `ask`

**Status:** Accepted (2026-11-06). Amends the static lists from Sub-decision 1.

**Decision:** `Bash(curl:*)`, `Bash(wget:*)` and `WebFetch` leave `permissions.ask`. The hook blocks the risky curl and wget shapes instead (running downloaded code, uploading a file's contents, downloading into credential or startup paths, secrets in the same call), and auto mode judges the rest. `WebFetch` is not gated at all.

**Why:** These rules need syntactic-variant and relationship matching (`curl | bash` against `bash <(curl ...)`; an output file that a later command runs; a token variable anywhere in a call that runs curl), which is Sub-decision 1's own criterion for the hook. A static `ask` also forces a prompt even in auto mode, so the classifier never judged these calls and long research runs prompted constantly, and it could not be relaxed per repo, because a global `ask` beats any repo-level `allow`. `WebFetch` is the low-risk path (GET only, output summarised by a model, no disk or execution); gating it like curl pushed agents back to curl and prompted twice.

**Rejected alternative:** Keeping the static `ask` as defense in depth. It did not stop what it was meant to: package installs (`npm install`, `pip install git+...`), `/usr/bin/curl`, and `sh -c 'curl ...'` were never gated by it, and `Read(...)` deny rules do not cover `curl -d @.env`. The hook now covers risky installs as well.

## Sub-decision 4: The hook follows stated principles

**Status:** Accepted (2026-11-07). Replaces the "report the blocked command and stop" ending that commit `ab21231` added to every block message alongside Sub-decision 3.

**Decision:** Every hook rule follows six principles: one rule per harm, in the shapes agents commonly write; one quote-aware tokenizer whose commands every rule matches on; deletes fail closed on targets the hook cannot resolve; one definition of a safe place for deletes (inside the working directory, or in or under a `/tmp/<name>` directory, with symlinks checked on disk); messages state the fact, with a hint only where a safe route to the same goal exists; and the hook stays fast. A block message no longer tells the agent what to do next.

**Why:** The rules had grown one incident at a time, each with its own idea of where a command ends, so matches ran across `&&` and into quoted text (a `git commit` was blocked for the `-rn` of a later `grep`), and the `/tmp` rule allowed deleting a scratch directory but not a folder inside it. A generic ending ("report the blocked command and stop") could not fit every setting: in 18 headless probe runs it stopped the whole task in 5 of 6 scenarios, while agents given only the plain denial finished their independent work, and none rerouted to the harm with or without hints. Hints that name a safe route let agents finish the blocked step safely in 4 of 6 scenarios.

**Rejected alternatives:** Patching each rule's regex, because each fix created the next inconsistency. Rewording the generic ending, because any fixed next step is wrong somewhere (subagents, headless runs, long tasks). Expanding shell variables to judge delete targets, because it needs assignment, quoting and substitution tracking, still cannot know `$(...)` values, and costs time on every call, while naming a literal path costs the agent one retry.
