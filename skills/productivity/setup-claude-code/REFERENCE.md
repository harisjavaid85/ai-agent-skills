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

`Bash(gh api graphql:*)` blocks all `gh api graphql` calls, because GraphQL reads and writes share the same HTTP verb and the read/write distinction lives in the query body, which the hook can't inspect. REST `gh api <path>` reads are allowed; the hook blocks REST writes, except editing a single issue or PR comment in place.

`gh auth` is not denied: the hook blocks only the subcommands that change login state (`login`/`logout`/`refresh`/`switch`/`setup-git`), because `open-pr`, `merge` and `setup-repo-skills` run `gh auth status` as a preflight.

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

An `ask` rule forces a prompt even in auto mode, so it never reaches the classifier. Anything in the global `ask` (or `deny`) list cannot be re-allowed by a repo's settings either, because rules evaluate deny, then ask, then allow across all scopes: a repo-level `allow` never beats a global `ask`.

`curl`, `wget`, and `WebFetch` are not in either list. `WebFetch` is GET only and its output is summarised by a model, so auto mode judges it. `curl` and `wget` go to auto mode too, after the hook has blocked their risky shapes (see [Hook patterns](#hook-patterns-all-modes)).

### `permissions.allow`

```
Bash(gh pr create:*)
Bash(gh pr comment:*)
Bash(gh pr review:*)
Bash(gh pr edit:*)
Bash(gh issue create:*)
Bash(gh issue comment:*)
Bash(gh label:*)
```

`gh pr review:*` is allowed at the harness layer for ergonomics; the hook still blocks `--approve`/`-a` in any flag position.

## Profile: `guardrails`

Adds the PreToolUse hook entry to `settings.json` only. No deny/ask or other entries written.

## Tool surface (`host`)

Three levels. `standard` is the default and writes nothing.

`lean` denies these tools, tracked as `managedToolSurfaceDeny`, kept out of the safety deny list above so `GUARDRAILS.md` stays a safety surface:

```
DesignSync
NotebookEdit
RemoteTrigger
ReportFindings
ScheduleWakeup
CronCreate
CronDelete
CronList
```

and writes:

```json
{
  "disableBundledSkills": true,
  "disableWorkflows": true,
  "disableRemoteControl": true,
  "disableClaudeAiConnectors": true
}
```

`leanest` is `lean` plus `"disableArtifact": true`.

What each level costs the operator:

- `lean`: `/loop` and `/schedule` stop working (consistent with the cron denies), Jupyter notebook editing goes, the bundled `/security-review`, `/review`, `/run`, `/simplify` and `/init` disappear, and code-review findings render as prose instead of the findings UI.
- `leanest`: also gives up publishing Artifacts.

Keep enabled at every level: `EnterPlanMode` / `ExitPlanMode`, `AskUserQuestion`, `PushNotification`, `SendMessage`, `EnterWorktree` / `ExitWorktree`.

Never deny `EnterPlanMode` / `ExitPlanMode`. Their schemas ship whether or not they are denied, so denying them saves nothing and removes the enforced read-only guardrail that plan mode provides when `defaultMode` is `auto`.

## Hook patterns (all modes)

[`scripts/block-dangerous-bash.sh`](scripts/block-dangerous-bash.sh) blocks the shapes agents commonly write that should not run; the script is the source of truth for the exact shapes. It is a speed bump, not a defence against deliberate evasion (aliases, `eval`, encoding, or a download and its execution split across separate calls); the auto-mode classifier judges everything it lets through. The principles every rule follows head the script. A block message says what was blocked and that the user prevented it, and gives no instruction about what to do next. A hint is added only where a safe route to the same goal exists: it names that route (for example, download into a new directory under /tmp instead of a credential directory), or the goal not to reach by other means (sending a credential, uploading a file, installing from an unvetted source).

- **Files**: recursive `rm` and `find` deletes (`-delete`, `-exec rm`) that fall in any of these cases:
  - outside the working directory and `/tmp/<name>` directories
  - through a symlink that leads outside them
  - of the whole working directory
  - in a `/tmp` directory that is a symlink or not yours
  - with a target the hook cannot resolve (a variable other than `$HOME`, a command substitution, input from `xargs`)
- **git**:
  - pushes to `main` or `master` (other branches allowed)
  - `--force` and `-f` pushes, a `+<branch>` refspec (a force push), and `--force-with-lease` outside a branch delete
  - a remote branch delete without a lease on each branch's expected commit
  - `reset --hard`, `clean -f`, `branch -D`, `checkout .` and `restore .`
  - `--no-verify` on any git command, `git commit -n` and `git am -n`, and `git -c core.hooksPath=...`
- **gh**:
  - `gh auth` subcommands that change login state
  - `gh pr review --approve` and `gh pr merge --admin`
  - `gh api` REST writes, except editing one issue or PR comment in place
- **Running downloaded code** (curl or wget):
  - output piped into, or fed to, an interpreter that runs it
  - output saved and then run in the same call
- **Uploading a file's contents** (curl or wget):
  - `-d @file`, `-F f=@file`, `-T`, `--post-file` and similar
  - not blocked when every destination URL in that curl or wget command is localhost and nothing reroutes it (a proxy, `--resolve`, `--connect-to`)
- **Downloads into sensitive paths** (curl or wget):
  - credential, config, and shell-startup files under `~`
  - `/etc` and `/usr/local/bin`
- **Secrets in a network call** (curl or wget in the same call as):
  - a secret-looking variable (`$API_TOKEN`, `$DB_PASS`); the match is on names, not values, so `$AUTH_URL` is blocked too
  - a token-printing command (`gh auth token`)
  - instead: authenticated GitHub calls go through `gh api`; other authenticated calls are the user's to run
- **Risky package installs**:
  - from a URL, git, or a GitHub `owner/repo`
  - global installs
  - custom package sources (`--index-url`, `--registry`)
  - not blocked: ordinary dependency installs and `npx`, left to auto mode

## `~/.claude/GUARDRAILS.md` template

Regenerate on every skill run. Replace `{{profile}}` and the static lists with the actual installed values, and `{{hookPatterns}}` with the bullets under [Hook patterns](#hook-patterns-all-modes), copied as written.

```md
# Claude Code guardrails

Installed by `/setup-claude-code {{profile}}`, last run {{timestamp}}. To regenerate, re-run the command.

## Static (settings.json)

### Deny

- Read(./.env), Read(~/.ssh/\*_), Bash(sudo:_), Bash(gh api graphql:\*) …

### Ask before running

- Bash(npm publish:_), Bash(docker push:_), Bash(kubectl delete:\*) …

### Tool surface

- Level {{toolSurface}}, denied tools: {{toolSurfaceDenies}}

## Hook-enforced (~/.claude/hooks/block-dangerous-bash.sh)

{{hookPatterns}}
```

## Merge rules

| Field                                                        | Strategy                                                                                                                                |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| `permissions.defaultMode`                                    | Write only if user chose a value (opt-in); skip if user chose `skip`                                                                    |
| `permissions.additionalDirectories`                          | Union by value.                                                                                                                         |
| `permissions.deny` / `permissions.ask` / `permissions.allow` | Replace previously-managed entries (tracked in `_setupClaudeCode.managedDeny`/`managedAsk`/`managedAllow`); preserve user-added entries |
| `hooks.PreToolUse[]`                                         | Append if no entry matches the command string                                                                                           |
| Tool-surface entries in `permissions.deny`                   | Replace previously-managed entries (tracked in `_setupClaudeCode.managedToolSurfaceDeny`); drop them all at `standard`                   |
| The `disable*` keys in [Tool surface](#tool-surface-host)   | Write only at the level that includes the key; remove keys a previous run wrote when the level drops                                     |
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
    "toolSurface": "standard",
    "managedToolSurfaceDeny": [],
    "hookInstalled": true,
    "statuslineInstalled": false,
    "modelSet": false,
    "lastRun": "2026-05-28T12:00:00Z"
  }
}
```
