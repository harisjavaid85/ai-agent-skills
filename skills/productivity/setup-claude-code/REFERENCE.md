# setup-claude-code reference

## Profile: `host`

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
Bash(curl:*)
Bash(wget:*)
Bash(sudo:*)
WebFetch
```

### `permissions.ask`

```
Bash(npm publish:*)
Bash(docker push:*)
Bash(docker rm:*)
Bash(docker rmi:*)
Bash(docker volume rm:*)
Bash(docker system prune:*)
Bash(kubectl delete:*)
```

## Profile: `sandbox`

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
```

### `permissions.ask`

```
Bash(npm publish:*)
Bash(docker push:*)
Bash(kubectl delete:*)
```

## Profile: `guardrails`

Hook only. No deny/ask entries written, no settings changed.

## Hook patterns (all modes)

See [`scripts/block-dangerous-bash.sh`](scripts/block-dangerous-bash.sh) — covers `rm -rf` variants, `find . -delete`, and dangerous git operations.

## `~/.claude/GUARDRAILS.md` template

Regenerate on every skill run. Replace `{{profile}}` and the static lists with the actual installed values.

```md
# Claude Code guardrails

Installed by `setup-claude-code` — profile **{{profile}}**, last run {{timestamp}}.

## Static (settings.json)

### Deny

- Read(./.env), Read(~/.ssh/\*_), Bash(curl:_) …

### Ask before running

- Bash(npm publish:_), Bash(docker push:_), Bash(kubectl delete:\*) …

## Hook-enforced (~/.claude/hooks/block-dangerous-bash.sh)

- rm -rf and all syntactic variants
- find . -delete
- git push to main/master (other branches allowed)
- git push --force / -f (any branch)
- git reset --hard, git clean -f, git branch -D, git checkout .

To regenerate: re-run `/setup-claude-code {{profile}}`.
```

## Merge rules

| Field                                  | Strategy                                                                                                                 |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `permissions.defaultMode`              | Write only if user chose a value (opt-in); skip if user chose `skip`                                                     |
| `permissions.additionalDirectories`    | Union by value                                                                                                           |
| `permissions.deny` / `permissions.ask` | Replace previously-managed entries (tracked in `_setupClaudeCode.managedDeny`/`managedAsk`); preserve user-added entries |
| `hooks.PreToolUse[]`                   | Append if no entry matches the command string                                                                            |
| `statusLine`                           | Write only if user chose `yes` (opt-in); skip if user chose `skip`                                                       |
| `model`                                | Write only if user chose a value (opt-in); skip if user chose `skip`                                                     |
| `_setupClaudeCode`                     | Overwrite with current run's state                                                                                       |

## Sentinel shape

```json
{
  "_setupClaudeCode": {
    "version": 1,
    "profile": "host",
    "managedDeny": ["Read(./.env)", "..."],
    "managedAsk": ["Bash(npm publish:*)", "..."],
    "hookInstalled": true,
    "statuslineInstalled": false,
    "modelSet": false,
    "lastRun": "2026-05-28T12:00:00Z"
  }
}
```
