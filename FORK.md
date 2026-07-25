# FORK.md — intentional divergences from upstream

This fork (`harisjavaid85/ai-agent-skills`) tracks `mattpocock/skills` as `upstream`. This file is the merge playbook: every intentional divergence from upstream, with rationale. When syncing (`git fetch upstream && git merge upstream/main`), resolve conflicts so these divergences are preserved — and update this file when a divergence is added or dropped.

## Renames kept from this fork

- **`ask-author`** (upstream: `ask-matt`) — author-neutral name for the router over this skill set. The skill directory, metadata, docs page, plugin manifest, READMEs, and active cross-references use the fork name; imported upstream `CHANGELOG.md` and `.changeset/` entries retain the historical name.
- **`grill-with-context`** (upstream: `grill-with-docs`) — same thin composition ("run a `/grilling` session, using the `/domain-modeling` skill"), fork name kept. Cross-references in `ask-author`, `write-a-skill`, `setup-repo-skills/domain.md`, docs pages, and `engineering/README.md` point to the fork name.

## Skills that replace upstream skills

- **`setup-repo-skills`** supersedes upstream's `setup-matt-pocock-skills` (deleted from this fork). Ported from upstream: PRs-as-triage-surface + wayfinding operations in `issue-tracker-*.md`, the tracker-choice section (GitHub/GitLab/local/other), the interactive "one section, one answer" flow, triage-installed gating of the triage-labels section, tracker-neutral `triage-labels.md`. **Not** ported: upstream's section that *decides* single- vs multi-context layout — ADR-0004 (`bootstrap-context` is the semantic authority for that decision).
- **`write-a-skill`** (fork-only workflow skill) complements upstream's `writing-great-skills` (reference). Fork version uses upstream's terms (**steps**/**reference**, not Behaviour/Vocabulary) and defers principles to `writing-great-skills/GLOSSARY.md`.
- **`bootstrap-context`** (fork-only) is the **batched** domain-modeling mode (survey → bootstrap/update → drift audit); upstream's `domain-modeling` is the **inline** mode. Formats live canonically in `domain-modeling/`; `bootstrap-context` links to them.

## Fork-only skills (additive, no upstream counterpart)

`commit`, `open-pr`, `cross-check-with-codex`, `setup-claude-code` — plus `write-a-skill`, `bootstrap-context`, `setup-repo-skills` above. Each carries `agents/openai.yaml` metadata. Invocation choices: `setup-repo-skills`, `setup-claude-code`, and `bootstrap-context` are **user-invoked** (`disable-model-invocation: true` + `allow_implicit_invocation: false`); the rest are model-invoked.

## KNOWLEDGE.md concept (fork-only)

Upstream has no knowledge-base file. This fork's `KNOWLEDGE.md` (durable learned facts, distinct from glossary/ADRs/policy) appears in:

- `domain-modeling/SKILL.md` — tree diagrams (the two `KNOWLEDGE.md` lines are the fork block; upstream's file has none)
- `domain-modeling/CONTEXT-FORMAT.md` — the "Domain language only" carve-out rule (first rule), plus the "root `CONTEXT.md` may sit alongside the map for repo-wide carrier vocabulary" line in the multi-context section
- `setup-repo-skills/domain.md` — the full routing taxonomy (fork-authored; upstream's `domain.md` is a subset)
- `bootstrap-context/SKILL.md` — out-of-contract audit classifies per `domain.md`

## Deletions following upstream

`caveman`, `zoom-out` (upstream removed both), `in-progress/review` (upstream renamed to `engineering/code-review` and promoted it). Deprecated `setup-matt-pocock-skills` kept as historical record in `deprecated/`.

## Tooling and docs

- **`scripts/link-skills.sh`** — upstream's dual-destination base (`~/.claude/skills` + `~/.agents/skills`) plus fork enhancements: interactive collision prompts (never silently `rm -rf`), non-interactive abort, stale-link pruning including deprecated skills, argument strictness. Tests in `tests/link-skills.sh`.
- **`misc/` bucket is not shipped** (upstream policy): its skills appear only in `skills/misc/README.md`, never in the top-level `README.md` or `.claude-plugin/plugin.json`.
- Fork metadata lives in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `package.json` (name `ai-agent-skills`, this repo's URL).
- Every promoted skill has a page under `docs/`. Quickstart, source, sibling, and router links use absolute `github.com/harisjavaid85/ai-agent-skills` URLs; this fork does not use upstream's `aihero.dev` publishing convention. The canonical rules and template live in `.agents/writing-docs.md`.

## Pending (Plan 2, not yet applied)

The slug groups one spec and its implementation tickets so a future agent loop can select `ready-for-agent` + `spec:<slug>` while native tracker dependencies expose the unblocked frontier.

- **`to-spec`:** accept an optional `[slug]`. For a GitHub tracker, idempotently create and apply `spec:<slug>` (`gh label create --force`). Decide whether the old `agent/<slug>` companion branch returns as an optional GitHub-only step or moves to `implement`.
- **`to-tickets`:** accept the optional `[slug]` and apply `spec:<slug>` to every ticket. Restore the `Covers user stories` field and confirmation-time coverage check when the source spec has numbered stories. Restore acceptance-criteria rules: imperative voice, an explicit success condition, and references to symbols/interfaces rather than file paths.
- **`triage`:** spec-derived tickets default to `enhancement`; use `bug` only when reproduction surfaces a defect. Optionally scope discovery by slug.
- **Rename the old PRD label convention:** replace `prd:<slug>` / `kind:prd` and "PRD-slug" wording with `spec:<slug>` across `setup-repo-skills/triage-labels.md`, label provisioning in `setup-repo-skills/SKILL.md`, and `open-pr/SKILL.md`.
