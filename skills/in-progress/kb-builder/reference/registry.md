# KB resolution (registry)

Every `kb-*` skill resolves which knowledge base to operate on the same way, from a registry, never by guessing from the working directory.

- **Registry file:** `~/.claude/kb/registry.json`
- **Schema:**
  ```json
  { "default": "<name>", "kbs": { "<name>": "<absolute-path-to-KB-repo-root>" } }
  ```
- **A KB path** points at a KB repo root holding `sources/`, `knowledge/`, and `verification-log.md`. Each is created on first use by the skill that owns it: `kb-ingest` writes `sources/`, `kb-integrate` writes `knowledge/`, `kb-verify` writes the log.
- **A KB is a repo**, and its diff is the only review any of these writes gets, since a pass may supersede an existing claim in place rather than only adding. Tell the user to commit after a pass that wrote: an uncommitted KB cannot show what changed or take it back.
- **The audience knob** says who the KB is written for. `kb-integrate` and `kb-expert` read it from the KB's `AGENTS.md` to calibrate depth. **Known gap:** nothing in this family creates or validates it, and its format is undefined. Where `AGENTS.md` is missing or declares no audience, say so and write for a competent generalist rather than guessing.

## Resolve

1. If the invocation names a KB, use `kbs["<name>"]`.
2. Otherwise use `kbs[default]`.
3. If the registry is missing, or the named KB is absent, stop and report; do not fall back to the working directory.

By convention an invocation names the KB with a leading `<name>:`, e.g. `/kb-ingest ai: source A, source B`. This is the recommended form, not a strict grammar; any unambiguous reference to a registered KB resolves the same way.

## Add a KB

Append `"<name>": "<abs path>"` to `kbs`; set `default` to it if it should be the default.
