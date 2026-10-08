# The cross-check trusts the container, not Codex's sandbox, inside to-done

Since Codex 0.115, Codex's read-only sandbox needs a user namespace that a default Docker container denies, so to-done's review could never get a Codex cross-check. We keep Docker's default isolation, run Codex in the container without its own sandbox, and fail, and undo, any review that changes the repository. Inside that container Codex's sandbox was never a security boundary, since the Claude reviewer beside it already holds a writable worktree, the GitHub token, and the network; it only promised that Codex would not edit, which is cheaper to check than to buy by weakening the container.

## Considered Options

- **No reviewer sandbox and no check.** Simplest, but a Codex edit could be committed along with the reviewer's own fixes unnoticed.
- **Loosen the container's seccomp and AppArmor confinement for the review.** Weakens the real boundary, depends on a host-specific AppArmor profile (absent under Docker Desktop on WSL), needs a sandcastle change, and breaks again whenever Codex changes how it sandboxes.
- **Custom confinement profiles.** Tighter, but host-specific and maintained against Codex internals.
- **The distribution's bubblewrap.** Hits the same namespace restrictions.
- **An older Codex.** The ChatGPT backend rejects old clients.

## Consequences

- Codex does not fail when its sandbox cannot start: it reports the blocked commands and exits successfully, having read nothing. Wherever Codex's own sandbox is relied on, the cross-check must confirm it starts before reviewing.
- The choice is framed as what isolates the reviewer, not where it runs, so a future non-Codex reviewer can make the same choice with its own controls.
