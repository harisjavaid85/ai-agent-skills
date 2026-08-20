---
name: setup-claude-code
description: Bootstrap a global Claude Code configuration with permissions, command guardrails, and optional interface settings. Use when the user wants to configure Claude Code on a host, sandbox, or new machine.
argument-hint: host | sandbox | guardrails
disable-model-invocation: true
---

# setup-claude-code

Installs a global Claude Code configuration under `~/.claude/`:

- Merges a permissions baseline into `~/.claude/settings.json` (deny/ask lists, etc.).
- Installs `~/.claude/hooks/block-dangerous-bash.sh` and wires it into PreToolUse.
- Regenerates `~/.claude/GUARDRAILS.md` (single audit surface for both layers).
- Optionally sets some settings and installs bundled scripts.

Safe to re-run. Managed entries are tracked under a top-level `_setupClaudeCode` sentinel; non-managed keys you've added by hand are preserved.

## Modes

The skill takes one argument (`host` | `sandbox` | `guardrails`). If no argument is given, ask the user.

| Mode         | What it installs                                                                 |
| ------------ | -------------------------------------------------------------------------------- |
| `host`       | Hook + strict permissions for a long-lived dev machine                           |
| `sandbox`    | Hook + relaxed permissions for a disposable Docker container running Claude Code |
| `guardrails` | Hook only, no permissions or other settings changes                             |

Non-interactive bootstrap example (Dockerfile): `RUN claude -p "/setup-claude-code sandbox"`.

## Workflow

### 1. Resolve mode

If the user passed `host`, `sandbox`, or `guardrails` as the argument, use it directly. Otherwise ask which mode.

### 2. Read existing state

- `~/.claude/settings.json` (may not exist)
- `~/.claude/settings.json` → `_setupClaudeCode` (tells you what previous runs managed)

### 3. Compute the target settings

Start from existing `settings.json`. Apply changes per mode:

**All modes (including `guardrails`):**

- Ensure `hooks.PreToolUse` contains an entry with `matcher: "Bash"` and `command: "~/.claude/hooks/block-dangerous-bash.sh"`. Match by `command` string; don't duplicate.

**`host` and `sandbox` modes only:**

- Set `additionalDirectories`, deny/ask/allow lists, and other permissions per [REFERENCE.md](REFERENCE.md).

### 4. Ask about opt-ins (host/sandbox only, interactive only)

- **Default mode**: `plan` (requires approval before acting, safest) / `auto` (handles permissions automatically, middle ground) / `bypassPermissions` (skips all permission checks) / `skip` (don't set it)?
- **Model**: `opus` / `sonnet` / `haiku` / `skip` (don't set it)?
- **Statusline**: install `scripts/statusline.sh` → `~/.claude/statusline.sh` and set `statusLine.type = "command"`, `statusLine.command = "~/.claude/statusline.sh"`? (`yes` / `skip`)
- **Tool surface**: `standard` (default) / `lean` / `leanest`? Read the levels out of [REFERENCE.md](REFERENCE.md#tool-surface-hostsandbox) and present what each one costs. Before recommending a lean level, grep the user's installed skills for the tools it denies, because a skill that calls a denied tool fails at the point of use.

If the user chooses `skip` for any opt-in, do not write that key to `settings.json` at all. `standard` is the same: write no tool-surface keys.

Skip all opt-ins in non-interactive (scripted) invocations, e.g. `RUN claude -p "/setup-claude-code sandbox"` in a Dockerfile.

### 5. Show diff and confirm

If the `settings.json` diff is non-empty (and running interactively), show it and ask for confirmation before proceeding. Abort if the user declines.

Skip in non-interactive invocations.

### 6. Stage and apply

Write all generated files to a temp staging directory `/tmp/claude-setup-<timestamp>/` with all placeholders resolved to actual paths:

- `settings.json`: merged config with `_setupClaudeCode` sentinel (shape in [REFERENCE.md](REFERENCE.md#sentinel-shape))
- `GUARDRAILS.md`: summarising both static permissions and hook patterns (template in [REFERENCE.md](REFERENCE.md))
- `apply.sh`: script that performs all writes:
  1. `cp ~/.claude/settings.json ~/.claude/settings.json.bak-$(date +%s)` (if it exists)
  2. `mkdir -p ~/.claude/hooks`
  3. `cp <staging>/settings.json ~/.claude/settings.json`
  4. `cp <skill-base-dir>/scripts/block-dangerous-bash.sh ~/.claude/hooks/block-dangerous-bash.sh && chmod +x ~/.claude/hooks/block-dangerous-bash.sh`
  5. If statusline opt-in accepted: `cp <skill-base-dir>/scripts/statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh`
  6. `cp <staging>/GUARDRAILS.md ~/.claude/GUARDRAILS.md`

Then run `apply.sh` via Bash tool. If blocked, ask the user to run it manually:

```bash
! bash /tmp/claude-setup-<timestamp>/apply.sh
```

### 7. Verify

Once the user confirms apply.sh ran, test the hook:

```bash
! echo '{"tool_input":{"command":"rm -rf /"}}' | ~/.claude/hooks/block-dangerous-bash.sh
```

Should exit 2 and print a BLOCKED message.

Print a one-line summary: profile, hook path, settings backup path.

## Design notes

See [ADR-0003](../../../.agents/adr/0003-setup-claude-code-guardrails-design.md) for the hook-vs-static boundary and host-vs-sandbox profile rationale.
