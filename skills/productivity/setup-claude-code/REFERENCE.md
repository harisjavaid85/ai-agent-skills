# setup-claude-code reference

## Profile: `host`

### `permissions.additionalDirectories`

```
~/.claude/skills
```

Allows Claude to read skill companion files (REFERENCE.md, ADR-FORMAT.md, etc.) without permission prompts. `~/.claude` root is intentionally excluded to keep `settings.json` and hooks tamper-proof.

### `permissions.deny`

```
Read(./.env)
Read(./.env.*)
Read(./secrets/**)
Read(./.aws/**)
Read(./config/credentials.json)
Read(./appsettings.*.json)
Read(~/.ssh/**)
Read(~/.aws/**)
Read(~/.aws/credentials)
Read(~/.gnupg/**)
Read(**/id_rsa)
Read(**/id_ed25519)
Read(**/.netrc)
Read(~/.bash_history)
Read(~/.zsh_history)
Read(~/.psql_history)
Bash(sudo:*)
Bash(gh repo delete:*)
Bash(gh release delete:*)
Bash(gh issue delete:*)
Bash(gh pr close:*)
Bash(gh api graphql:*)
```

`Bash(gh api graphql:*)` blocks all `gh api graphql` calls — GraphQL reads and writes share the same HTTP verb and the read/write distinction lives in the query body, which the hook can't inspect. REST `gh api <path>` is allowed; the hook blocks `gh api -X POST/PUT/PATCH/DELETE` and `-XPOST` / `--method=POST` forms.

`gh auth` is not denied — the hook blocks the mutating subcommands (`login`/`logout`/`refresh`/`switch`/`setup-git`) so `gh auth status` and `gh auth token` work without prompts.

`Bash(curl:*)`, `Bash(wget:*)`, and `WebFetch` default to "ask" — opt in per-repo if needed.

### `permissions.ask`

```
Bash(npm publish:*)
Bash(docker push:*)
Bash(docker rm:*)
Bash(docker rmi:*)
Bash(docker volume rm:*)
Bash(docker system prune:*)
Bash(kubectl delete:*)
Bash(curl:*)
Bash(wget:*)
WebFetch
```

### `permissions.allow`

```
Bash(gh pr create:*)
Bash(gh pr comment:*)
Bash(gh pr review:*)
Bash(gh issue create:*)
Bash(gh issue comment:*)
Bash(gh label:*)
```

`gh pr review:*` is allowed at the harness layer for ergonomics; the hook still blocks `--approve`/`-a` in any flag position.

## Profile: `sandbox`

### `permissions.additionalDirectories`

```
~/.claude/skills
```

Same rationale as `host`.

### `permissions.deny`

```
Read(~/.ssh/**)
Read(~/.aws/**)
Read(~/.aws/credentials)
Read(~/.gnupg/**)
Read(**/id_rsa)
Read(**/id_ed25519)
Read(**/.netrc)
Read(~/.bash_history)
Read(~/.zsh_history)
Read(~/.psql_history)
Bash(gh repo delete:*)
Bash(gh release delete:*)
Bash(gh issue delete:*)
Bash(gh pr close:*)
Bash(gh api:*)
```

### `permissions.ask`

```
Bash(npm publish:*)
Bash(docker push:*)
Bash(kubectl delete:*)
```

### `permissions.allow`

```
Bash(gh pr create:*)
Bash(gh pr comment:*)
Bash(gh pr review:*)
Bash(gh issue create:*)
Bash(gh issue comment:*)
Bash(gh label:*)
```

## Profile: `guardrails`

Adds the PreToolUse hook entry to `settings.json` only. No deny/ask or other entries written.

## Hook patterns (all modes)

See [`scripts/block-dangerous-bash.sh`](scripts/block-dangerous-bash.sh) — covers `rm -rf` variants, `find . -delete`, dangerous git operations, and destructive/identity-mutating `gh` operations.

## `~/.claude/GUARDRAILS.md` template

Regenerate on every skill run. Replace `{{profile}}` and the static lists with the actual installed values.

```md
# Claude Code guardrails

Installed by `/setup-claude-code {{profile}}`, last run {{timestamp}}. To regenerate, re-run the command.

## Static (settings.json)

### Deny

- Read(./.env), Read(~/.ssh/\*_), Bash(sudo:_), Bash(gh api graphql:\*) …

### Ask before running

- Bash(npm publish:_), Bash(docker push:_), Bash(kubectl delete:\*) …

## Hook-enforced (~/.claude/hooks/block-dangerous-bash.sh)

- rm -rf: targets must stay inside cwd (allowed relative paths only; blocked /…, ~…, .., ., \*)
- find . -delete
- git push to main/master (other branches allowed)
- git push --force / -f (any branch)
- git reset --hard, git clean -f, git branch -D, git checkout .
- ...
```

## Merge rules

| Field                                                        | Strategy                                                                                                                                |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| `permissions.defaultMode`                                    | Write only if user chose a value (opt-in); skip if user chose `skip`                                                                    |
| `permissions.additionalDirectories`                          | Union by value.                                                                                                                         |
| `permissions.deny` / `permissions.ask` / `permissions.allow` | Replace previously-managed entries (tracked in `_setupClaudeCode.managedDeny`/`managedAsk`/`managedAllow`); preserve user-added entries |
| `hooks.PreToolUse[]`                                         | Append if no entry matches the command string                                                                                           |
| `statusLine`                                                 | Write only if user chose `yes` (opt-in); skip if user chose `skip`                                                                      |
| `model`                                                      | Write only if user chose a value (opt-in); skip if user chose `skip`                                                                    |
| `_setupClaudeCode`                                           | Overwrite with current run's state                                                                                                      |

## Sentinel shape

```json
{
  "_setupClaudeCode": {
    "version": 1,
    "profile": "host",
    "managedDeny": ["Read(./.env)", "..."],
    "managedAsk": ["Bash(npm publish:*)", "..."],
    "managedAllow": ["Bash(gh pr create:*)", "..."],
    "hookInstalled": true,
    "statuslineInstalled": false,
    "modelSet": false,
    "lastRun": "2026-05-28T12:00:00Z"
  }
}
```
