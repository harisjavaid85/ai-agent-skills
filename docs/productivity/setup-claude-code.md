## What it does

`setup-claude-code` bootstraps a machine's global Claude Code configuration under `~/.claude/`: a permissions baseline, a dangerous-command hook, and optional interface settings. It works in two modes: `host` for a personal machine, and `guardrails` for just the safety layer.

The defining constraint is **safe re-runs**: everything the skill manages is tracked under a sentinel in your settings, so running it again updates its own entries while preserving every key you added by hand.

## When to reach for it

You invoke this by typing `/setup-claude-code`, and the agent won't reach for it on its own.

Reach for it on a new machine, or any host where Claude Code has no guardrails yet. Run it once per machine, and again whenever the skill changes, to install the new rules. Its repo-level counterpart [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md) runs once per repo, and will nudge you toward this one when the global setup is missing.

## The two guardrail layers

The skill installs two layers, and each rule lives in exactly one of them:

| Layer | Holds | Example |
| --- | --- | --- |
| **Permissions baseline** in `~/.claude/settings.json` | Flat rules a glob can express: deny and ask lists | Reading `~/.ssh`, `npm publish` |
| **PreToolUse hook** | Rules that need to recognise many spellings of one command, or how two commands in one call relate | `rm -rf` outside the repo, `curl ... \| bash`, a token variable sent with curl |

The hook is a **speed bump**, not a wall. It blocks the shapes agents commonly write, reading each call the way the shell does, so a dangerous-looking string inside quotes or a commit message is never mistaken for a command. A block message states what was blocked and that you prevented it, and never tells the agent what to do next. Where a safe route to the same goal exists, it names that route (download into a new directory under `/tmp`, push a branch delete with a lease), or the goal not to reach by other means (sending a credential, installing from an unvetted source). The agent skips the blocked step and carries on with the rest of the task. Deliberate evasion gets past it; in auto mode the classifier judges everything the hook lets through. Both layers report to one audit surface, `~/.claude/GUARDRAILS.md`, so you can see exactly what protection is in place.

## Choosing a tool surface

In `host` mode the skill also asks how much of Claude Code's tool surface you want loaded: `standard` keeps everything and is the default, `lean` strips the tools and bundled features most setups never call, and `leanest` goes one step further. It tells you exactly what each level costs before writing anything; pick a lean level only once you've checked that none of your own skills call a tool it denies.

## The optional statusline

In `host` mode the skill offers a one-line statusline:

```
you@laptop | ~/../ai-agent-skills (main) | Opus 5.5 (medium) | 84k/200k (42%) | 2h50m/5h (23%)
```

- **Context** is coloured by absolute size, because a long [context window](https://www.aihero.dev/ai-coding-dictionary/context-window) degrades answers whatever its limit: green under 200k [tokens](https://www.aihero.dev/ai-coding-dictionary/token), yellow up to 500k, red above. It also turns red at 80% full, so a 200k window warns you before auto-compact.
- **The 5h segment** shows how far you are into your subscription's 5-hour window and how much of its quota you have used, so `2h50m/5h (23%)` means you are on pace. It is hidden on API-key plans.
- **A narrow terminal or tmux pane** wraps the line at a segment boundary rather than dropping segments.

To change the segments, labels, or thresholds, edit the settings at the top of the skill's [`scripts/statusline.sh`](https://github.com/harisjavaid85/ai-agent-skills/blob/main/skills/productivity/setup-claude-code/scripts/statusline.sh) and re-run the skill: a re-run overwrites `~/.claude/statusline.sh`.

## Common questions

**Why don't curl, wget and WebFetch prompt any more?**

They used to sit in the `ask` list, and an `ask` rule forces a prompt even in auto mode, so long research runs stopped on every fetch. Now WebFetch is judged by auto mode (it only reads, and a model summarises what comes back), and curl and wget are judged by auto mode once the hook has ruled out their risky shapes. Re-run `/setup-claude-code host` to drop the old `ask` entries from your settings.

**Why was my curl blocked?**

The hook blocks curl or wget when the call:

- runs what it downloads (`curl ... | bash`, or saves it and runs it later in the same call);
- uploads a file's contents (`-d @.env`, `-F f=@key`, `-T`) to anything but localhost;
- writes into a credential, config, or shell-startup path (`~/.ssh`, `~/.bashrc`);
- also expands a secret-looking variable (`$API_TOKEN`, `$DB_PASS`) or runs a token-printing command (`gh auth token`).

The secret check reads names, not values, so `$AUTH_URL` next to curl is blocked too. Authenticated GitHub calls belong in `gh api`; other authenticated calls are yours to run. The same hook blocks package installs from a URL or git repo, global installs, and custom package registries.

**What does the agent do after a block?**

It skips the blocked step and finishes the rest of the task, or takes the safe route the message names. Earlier versions ended every message with "report the blocked command and stop", and agents read that as "end the turn": one block, even a false positive, abandoned all the independent work left in the task. Hints that name a safe route let agents finish the blocked step safely instead, and in probe runs no agent rerouted to the harm.

**Why was my rm blocked?**

A recursive `rm`, and a `find` that deletes, must stay in the workspace: strictly inside the working directory, or in or under a `/tmp/<name>` directory. The hook blocks a delete when:

- its target is outside both, or is the whole working directory (`.`, `*`);
- the hook cannot tell what the target is: a variable other than `$HOME` (`rm -rf $DIR`), a command substitution, a `cd` it cannot follow, targets that `xargs` reads from its input, or a brace expansion that could reach another directory (`{a,../b}`);
- a symlink on the way leads outside the workspace, as with an `npm link`ed package (pnpm's links inside `node_modules` stay allowed);
- the `/tmp/<name>` directory it reaches into is a symlink or someone else's.

The fix is one retry with a literal path, such as `rm -rf /tmp/build-cache`.

**Why is the 5h segment missing from my statusline?**

Claude Code only sends rate limits to subscription plans, and only after the session's first response. On an API key the segment never appears, and on a fresh session it shows up after your first message.

**Can I re-allow something for one repo?**

Not if the global settings deny it or ask for it. Rules are checked deny first, then ask, then allow, across every settings file, so an `allow` in a repo's `.claude/settings.json` never beats a global `deny` or `ask`. Only what the global baseline leaves alone can be decided per repo.

## It's working if

- Fetching docs or API responses during a long session no longer stops for approval.
- When the agent hits a blocked command, it skips that step and finishes the rest of the task, or takes the safe route the message names.
- `~/.claude/GUARDRAILS.md` lists every rule you see enforced, in both layers.
- Re-running the skill after an update leaves your hand-added settings in place.
- The statusline shows the session's effort level next to the model, and the context turns yellow once a session passes 200k tokens.

## Where it fits

**Run-once setup**, machine-level: this first, then [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md) per repo. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
