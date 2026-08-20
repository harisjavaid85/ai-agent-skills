# Semantic vs structural authority split between `bootstrap-context` and `setup-repo-skills`

Two skills configure a repo for the engineering toolchain, and their responsibilities kept overlapping (both decided whether a repo was single- or multi-context). We drew a single governing boundary: **`bootstrap-context` is the semantic authority; `setup-repo-skills` is the structural authority.**

The deciding test for which skill owns a piece of work: *does it require a judgment about the domain's meaning?* If yes, it belongs to `bootstrap-context` (the domain model: `CONTEXT.md`, `CONTEXT-MAP.md`, per-folder contexts, and the single/multi-context **decision**). If it's mechanical scaffolding derivable from disk or convention, it belongs to `setup-repo-skills` (`.claude/` directories, `.gitignore`, `settings.json`, the agent-guidance sections in `AGENTS.md`/`CLAUDE.md`, issue-tracker and triage-label config).

The consequence that will surprise a future reader: **`setup-repo-skills` never decides whether a repo is single- or multi-context, and the `docs/agents/domain.md` it writes contains no such decision.** It only reads the layout from disk (presence of `CONTEXT-MAP.md`) and emits a static *agent contract*: how agents read this repo's domain docs, and how they add to its knowledge base. The decision lives in `bootstrap-context` alone.

The contract covers capture as well as reading because `KNOWLEDGE.md` has no producer skill. A glossary term is resolved deliberately, so `bootstrap-context` authors it; a durable behavioral fact is learned mid-work by whichever skill happens to be running (`diagnose`, `tdd`, `review`), so its capture rules must live where every skill already reads. This does not move semantic authority: what `setup-repo-skills` emits is static text, and judging which facts are worth keeping stays with the skill that learned them.

## Consequences

- **One home per facet of the single/multi-context concept.** The *decision* lives in `bootstrap-context`; the *format + diagram* lives in `bootstrap-context/CONTEXT-FORMAT.md` (same-repo skill docs link to it rather than re-pasting); the *agent contract* lives in `docs/agents/domain.md`.
- **`KNOWLEDGE.md` rules sit in the contract, not the map.** A repo's `CONTEXT-MAP.md` is a per-repo vocabulary index; it carries no standing rule about knowledge files. Stating the rule in `domain.md` instead keeps it single-sourced and reaches single-context repos, which have no map at all.
- **Dedup respects the maintenance boundary.** `domain.md` is emitted into a foreign repo that cannot link back into the plugin bundle, so it inlines a compact diagram. That is deliberate self-containment, not the same-repo copy-paste smell that actually rots.
- **The skills scale cleanly.** New domain richness accretes onto `bootstrap-context`; new toolchain plumbing accretes onto `setup-repo-skills`. The boundary holds because it is drawn on "semantic vs structural," not on "which files happen to live under `docs/`."

## Rejected alternative

Dropping `domain.md` entirely and baking its rules into each consuming skill. Rejected because they are a genuine per-repo contract worth installing in one discoverable place, and because a repo's `docs/agents/` is the right audit surface for "how agents read and extend this repo's domain docs."
