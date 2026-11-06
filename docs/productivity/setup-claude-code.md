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

The hook is a **speed bump**, not a wall. It blocks the shapes agents commonly write, and its message tells the agent to report the blocked command and stop instead of rewording it. Where the hook names a safe form instead (a branch delete that names the commit it expects), the agent may retry that way and no other. Deliberate evasion gets past it; in auto mode the classifier judges everything the hook lets through. Both layers report to one audit surface, `~/.claude/GUARDRAILS.md`, so you can see exactly what protection is in place.

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
- also mentions a secret-looking variable (`$API_TOKEN`, `$DB_PASS`) or runs a token-printing command (`gh auth token`).

The secret check reads names, not values, so `$AUTH_URL` next to curl is blocked too. Authenticated GitHub calls belong in `gh api`; other authenticated calls are yours to run. The same hook blocks package installs from a URL or git repo, global installs, and custom package registries.

**Why is the 5h segment missing from my statusline?**

Claude Code only sends rate limits to subscription plans, and only after the session's first response. On an API key the segment never appears, and on a fresh session it shows up after your first message.

**Can I re-allow something for one repo?**

Not if the global settings deny it or ask for it. Rules are checked deny first, then ask, then allow, across every settings file, so an `allow` in a repo's `.claude/settings.json` never beats a global `deny` or `ask`. Only what the global baseline leaves alone can be decided per repo.

## It's working if

- Fetching docs or API responses during a long session no longer stops for approval.
- When the agent hits a blocked command, it reports it and stops, instead of retrying the same thing through another tool, unless the block named a safe form and it uses exactly that.
- `~/.claude/GUARDRAILS.md` lists every rule you see enforced, in both layers.
- Re-running the skill after an update leaves your hand-added settings in place.
- The statusline shows the session's effort level next to the model, and the context turns yellow once a session passes 200k tokens.

## Where it fits

**Run-once setup**, machine-level: this first, then [setup-repo-skills](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/setup-repo-skills.md) per repo. [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) routes the wider system.
