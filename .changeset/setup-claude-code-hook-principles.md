---
"ai-agent-skills": patch
---

Rebuild the `/setup-claude-code` Bash hook on six stated principles: one rule per harm, one quote-aware tokenizer every rule matches on, deletes that fail closed on targets the hook cannot resolve, one safe place for deletes, messages that state the fact, and speed.

A block message now states what was blocked and that the user prevented it, and gives no instruction about what to do next, so one block no longer ends the agent's whole task. Where a safe route to the same goal exists, the message names it: save a download under `/tmp` and read it before running it, download into `/tmp` instead of a credential directory, fix what a failing git hook reports, add `-X GET` to a `gh api` read, name a delete target as a literal path. Where the goal itself is off limits (sending a credential, uploading a file, installing from an unvetted source), it names that goal as one not to reach by other means. Reasons are readable rule names instead of raw regexes.

Behaviour changes:

- Matches never cross commands or enter data. A `git commit` followed by `grep -rn` or `head -n`, `git push origin feat && echo main`, a commit message that mentions `--no-verify`, and an `rm -rf` inside a quoted search pattern or a quoted heredoc are all allowed.
- Recursive `rm` may delete anywhere in or under a `/tmp/<name>` directory, with a trailing slash too, as long as that directory is a real directory you own.
- `find` deletes follow the same workspace rule as `rm`. `find . -name "*.tmp" -delete` is allowed; `find . -delete` is still blocked. `find -exec rm` and `-execdir rm` operands are checked as targets too, whether or not the rm is recursive, and an operand built from `{}` (such as `{}.bak`) is blocked. With `find -H`, a start path that is a symlink is checked where it leads.
- A symlink that leads outside the working directory or `/tmp/<name>` blocks a delete through it, such as a package linked in with `npm link`. Symlinks that stay inside, like pnpm's, are allowed.
- `~` and `$HOME` are resolved in delete targets; a quoted or escaped `~` or `$HOME` is an ordinary path.
- `xargs` feeding a recursive `rm` is blocked, and so is a brace expansion in a delete target that could reach another directory (`{a,../b}`, `{x,y}/sub`); `{build,dist}` stays allowed.
- Commands inside `case` branches and function bodies are checked like any other.
- A numeric `chmod` mode that adds execute (`chmod 755`) counts for download then execute.
- `git push` with a `+<ref>` refspec is blocked as a force push, `git -c core.hooksPath=...` and `git am -n` are blocked as skipping git hooks.
- The localhost exemption for uploads is judged per curl or wget command, not per call, and only on its destination URLs: a localhost header or user agent no longer earns it, and a proxy, `--resolve` or `--connect-to` rules it out.
- A curl `-o` path is resolved inside `--output-dir`, so `--output-dir ~ -o .bashrc` counts as a download into a sensitive path and a download there followed by running it is caught.
- A secret-looking variable counts only where bash expands it, so single-quoted, escaped, or quoted-heredoc `$NAME` text no longer blocks a curl call. An unquoted heredoc body still counts.

Re-run `/setup-claude-code host` to install the updated hook.
