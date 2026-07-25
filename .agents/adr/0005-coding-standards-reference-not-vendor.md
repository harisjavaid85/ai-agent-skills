# Coding standards reference a named guide, never vendor its rules

`setup-repo-skills` wires each repo with per-language coding standards so agents write high-quality code by default. A standard could either transcribe a style guide's rules into the repo or bind the agent to the guide by name and let the guide stay the source of truth. We bind by name: each language section names a style guide, records its authoritative URL for the agent to fetch when a rule is unclear, and lists only the repo's deviations and emphases. The rules themselves are never copied in.

The primary consumer is the **producing agent**, which reads the standard before writing code in that language; `review`'s Standards axis is a backstop, not the point. Coverage of the full guide — both the mechanical rules a formatter enforces and the judgment calls it cannot — rests on the named guide, applied wholesale by the agent and fetchable on demand. The linter is the mechanical safety net, not the definition of the standard; `setup-repo-skills` references it but never installs it.

The defaults catalog — which guide leads for each language — is vendored into the emitted `docs/agents/coding-standards.md` as a lookup table, not merely referenced from the skill. A repo cannot reach back into the plugin bundle, so an agent introducing a new language needs the default available locally — the same self-containment reason [ADR-0003](./0003-semantic-vs-structural-authority-split.md) gives for inlining `domain.md`'s diagram. Consistency depends on it: one vendored table makes every agent pick the same guide for a language, where per-agent recall would drift.

## Consequences

- **No transcribed rules to rot.** The repo carries the delta — guide name, URL, deviations, emphases; the guide carries the rules. Nothing local goes stale when the guide changes.
- **Standards hold at write time, not just review time.** The binding is agent-facing guidance loaded before code is written, orthogonal to Repo mode's rigor posture.
- **Self-heal is local.** The vendored defaults table lets a producing agent add a section for a new language without the skill present, deterministically.
- **The catalog's contents live in the skill, not here.** Which guide leads for which language is tunable reference data in `setup-repo-skills`; naming specific guides in this ADR would date it.

## Rejected alternative

Vendoring the guides' judgment-layer rules into each repo so coverage is fully local. Rejected because it duplicates a large external document that drifts, and violates single-source-of-truth for no gain the named guide plus a fetchable URL doesn't already provide.
