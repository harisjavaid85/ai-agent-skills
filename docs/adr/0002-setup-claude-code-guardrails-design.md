# Layered guardrails design for `setup-claude-code`

The `setup-claude-code` skill installs Claude Code guardrails (`~/.claude/settings.json` permissions + a `~/.claude/hooks/block-dangerous-bash.sh` PreToolUse hook). Two cross-cutting design decisions shape what gets installed and how it's enforced. They're orthogonal but reinforce each other, so they live in one ADR.

Both are constrained by one Claude Code semantic: **`deny` always beats `allow` across every layer of the settings cascade** (enterprise → CLI → `.claude/settings.local.json` → `.claude/settings.json` → `~/.claude/settings.json`). Anything that should be per-repo-overridable must stay out of global `deny` — once globally denied, no lower-precedence `allow` (or hook) can re-enable it.

## Sub-decision 1: Enforcement axis — hook vs static permissions

**Decision:** A guardrail goes into the **hook** when it needs syntactic-variant matching (e.g. `rm -rf` vs `rm -fr` vs `rm --recursive --force` vs `bash -c "rm -rf …"`) or conditional logic (e.g. `git push` to feature branches OK, push to `main`/`master` blocked). Everything else goes into the **static** `permissions.deny` / `permissions.ask` lists.

**Trade-off:** Hooks catch more (syntactic variants, conditional rules) but are opaque bash — Claude can't see them at plan time. Static permissions are introspectable (Claude reads them and avoids forbidden actions before attempting) and benefit from schema validation, but can only express flat glob/string matches.

**Rejected alternative:** Putting overlapping rules in both layers (defense-in-depth). Rejected because keeping two layers in sync creates drift risk, and the `ask` semantic conflicts with hook-based silent allows (worst-of-both UX).

**Discoverability:** Because guardrails span two files, the skill regenerates `~/.claude/GUARDRAILS.md` on every run as the single human-readable audit surface.

## Sub-decision 2: Deployment profile — host vs sandbox

**Decision:** The skill ships two named profiles selected by argument (`/setup-claude-code host` or `/setup-claude-code sandbox`, plus a `guardrails`-only mode). The `sandbox` profile is for running Claude Code inside an automated Docker sandbox; the `host` profile is for a developer machine. When no argument is given, Claude asks the user interactively.

**Trade-off:** Sandbox calibrates for autonomy — drops the `.env*` / app-config reads that would block legitimate test setup inside a disposable container. Host calibrates for safety on a long-lived machine where the file system is the safety boundary, not the container.

**Invariant preserved across both profiles:** denies for SSH/AWS/GPG keys and shell-history files, and `ask` for public-state-mutating commands (`npm publish`, `docker push`, `kubectl delete`). The sandbox boundary doesn't protect against these — published packages and registry pushes cross it.

**Rejected alternative:** Auto-detecting `/.dockerenv` and switching profiles silently. Rejected because explicit profile selection is auditable and works reliably in non-interactive Dockerfile bootstrap (`RUN claude -p "/setup-claude-code sandbox"`).
