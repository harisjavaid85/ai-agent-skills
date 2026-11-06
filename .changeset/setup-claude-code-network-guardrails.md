---
"ai-agent-skills": patch
---

Stop `/setup-claude-code` from prompting on every curl, wget, and WebFetch call, and block their risky shapes in the hook instead.

`Bash(curl:*)`, `Bash(wget:*)` and `WebFetch` leave the `ask` list. An `ask` rule forces a prompt even in auto mode, so long research runs prompted constantly, and no repo setting could relax it. WebFetch is now left to auto mode. The Bash hook now blocks curl or wget output run by an interpreter (piped, through `<(...)` or `-c "$(...)"`, or downloaded and then run in the same call), file-body uploads to anything but localhost, downloads into credential, config, and shell-startup paths, and any call that runs curl or wget alongside a secret-looking variable or a token-printing command such as `gh auth token`. It also blocks package installs from a URL or git repo, global installs, and custom package registries; ordinary dependency installs and `npx` are left to auto mode.

Every block message now tells the agent not to retry another way, and to report the blocked command and stop. A block that recommends a safe form, such as a remote branch delete with a lease, allows a retry in that form only. `REFERENCE.md` no longer claims curl and wget can be re-allowed per repo: a global `ask` or `deny` beats any repo-level `allow`. The final verify step no longer has the agent run the hook's block check through Bash, where the newly installed hook blocked the check itself: the agent compares the installed hook with the skill's copy, and the user runs the block check.

Re-run `/setup-claude-code host` to drop the old `ask` entries and install the updated hook.
