---
name: setup-claude-code
description: Bootstrap global Claude Code setup at ~/.claude/ — permissions baseline, dangerous-command hook, optional statusline/model. Use when user wants to set up Claude Code on a new machine (host, sandbox, etc.).
argument-hint: host | sandbox | guardrails
---

# setup-claude-code

Installs a global Claude Code configuration under `~/.claude/`:

- Merges a permissions baseline into `~/.claude/settings.json` (deny/ask lists, `additionalDirectories`, etc.).
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
| `guardrails` | Hook only — no permissions or other settings changes                             |

Non-interactive bootstrap example (Dockerfile): `RUN claude -p "/setup-claude-code sandbox"`.

## Workflow

### 1. Resolve mode

If the user passed `host`, `sandbox`, or `guardrails` as the argument, use it directly. Otherwise ask which mode.

### 2. Read existing state

- `~/.claude/settings.json` (may not exist)
- `~/.claude/hooks/block-dangerous-bash.sh` (may not exist)
- `~/.claude/settings.json` → `_setupClaudeCode` (tells you what previous runs managed)

### 3. Compute the target settings

Start from existing `settings.json`. Apply changes per mode:

**All modes (including `guardrails`):**

- Ensure `hooks.PreToolUse` contains an entry with `matcher: "Bash"` and `command: "~/.claude/hooks/block-dangerous-bash.sh"`. Match by `command` string; don't duplicate.

**`host` and `sandbox` modes:**

- set `permissions.additionalDirectories` and the profile's deny/ask lists. Profile lists and all merge rules are in [REFERENCE.md](REFERENCE.md).

### 4. Ask about opt-ins (host/sandbox only, interactive only)

- **Default mode**: `plan` (requires approval before acting — safest) / `auto` (acts without approval) / `bypassPermissions` (skips all permission checks) / `skip` (don't set it)?
- **Model**: `opus` / `sonnet` / `haiku` / `skip` (don't set it)?
- **Statusline**: install `scripts/statusline.sh` → `~/.claude/statusline.sh` and set `statusLine.type = "command"`, `statusLine.command = "~/.claude/statusline.sh"`? (`yes` / `skip`)

If the user chooses `skip` for any opt-in, do not write that key to `settings.json` at all.

Skip all opt-ins in non-interactive (scripted) invocations — e.g. `RUN claude -p "/setup-claude-code sandbox"` in a Dockerfile.

### 5. Diff and confirm

Show the user the diff between current and proposed `~/.claude/settings.json` and ask for confirmation before writing. Skip only when running non-interactively (no TTY / scripted context).

### 6. Write

In order:

1. `cp ~/.claude/settings.json ~/.claude/settings.json.bak-$(date +%s)` (if it exists).
2. `mkdir -p ~/.claude/hooks`.
3. Copy `scripts/block-dangerous-bash.sh` → `~/.claude/hooks/block-dangerous-bash.sh`; `chmod +x`.
4. If statusline opt-in accepted: copy `scripts/statusline.sh` → `~/.claude/statusline.sh`; `chmod +x`.
5. Write merged `~/.claude/settings.json`. Include the `_setupClaudeCode` sentinel (shape in [REFERENCE.md](REFERENCE.md#sentinel-shape)).

6. Regenerate `~/.claude/GUARDRAILS.md` summarising both static permissions and hook patterns. Template in [REFERENCE.md](REFERENCE.md).

### 7. Verify

Test the hook is wired correctly:

```bash
echo '{"tool_input":{"command":"rm -rf /"}}' | ~/.claude/hooks/block-dangerous-bash.sh
```

Should exit 2 and print a BLOCKED message.

Print a one-line summary: profile, hook path, settings backup path.

## Design notes

See [`docs/adr/0002-setup-claude-code-guardrails-design.md`](../../../docs/adr/0002-setup-claude-code-guardrails-design.md) for the hook-vs-static boundary and host-vs-sandbox profile rationale.
