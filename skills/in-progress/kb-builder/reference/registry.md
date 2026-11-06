# KB resolution (registry)

Every `kb-*` skill resolves which knowledge base to operate on the same way, from a registry.

- **Registry file:** `$XDG_CONFIG_HOME/kb-skills/registry.json`, or `~/.config/kb-skills/registry.json` when `XDG_CONFIG_HOME` is unset. The path is outside any harness directory, so every harness resolves the same KBs.
- **Schema:**
  ```json
  { "default": "<name>", "kbs": { "<name>": "<absolute-path-to-KB-repo-root>" } }
  ```
- **A KB path** points at the root of a KB's git repo, holding `sources/`, `knowledge/`, and `verification-log.md`. Each is created on first use by the skill that owns it: `kb-ingest` writes `sources/`, `kb-integrate` writes `knowledge/`, `kb-verify` writes the log.
- **The audience knob** says who the KB is written for. `kb-integrate` and `kb-expert` read it from the KB's `AGENTS.md`. Where `AGENTS.md` is missing or declares no audience, say so and write for a competent generalist rather than guessing.

## Resolve

1. If the invocation names a KB, by its name or its registered root path, use that entry.
2. Otherwise use `kbs[default]`.
3. If the registry is missing, or the named KB or path is absent from it, stop and report; do not fall back to the working directory.

By convention an invocation names the KB with a leading `<name>:`, e.g. `/kb-ingest ai: source A, source B`.

## Add a KB

Append `"<name>": "<abs path>"` to `kbs`; set `default` to it if it should be the default.
