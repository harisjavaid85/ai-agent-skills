# FORK.md — intentional divergences from upstream

This fork (`harisjavaid85/ai-agent-skills`) tracks `mattpocock/skills` as `upstream`. This file is the merge playbook: every intentional divergence from upstream, with rationale. When syncing (`git fetch upstream && git merge upstream/main`), resolve conflicts so these divergences are preserved — and update this file when a divergence is added or dropped.

## Renames kept from this fork

- **`grill-with-context`** (upstream: `grill-with-docs`) — same thin composition ("run a `/grilling` session, using the `/domain-modeling` skill"), fork name kept. Cross-references in `ask-matt`, `write-a-skill`, `setup-repo-skills/domain.md`, docs pages, and `engineering/README.md` point to the fork name.

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

## Tooling

- **`scripts/link-skills.sh`** — upstream's dual-destination base (`~/.claude/skills` + `~/.agents/skills`) plus fork enhancements: interactive collision prompts (never silently `rm -rf`), non-interactive abort, stale-link pruning including deprecated skills, argument strictness. Tests in `tests/link-skills.sh`.
- **`misc/` bucket is not shipped** (upstream policy): no `README.md`/`plugin.json` entries for `misc/` skills.
- Fork metadata in `plugin.json`, `marketplace.json`, `package.json` (name `ai-agent-skills`, this repo's URL). Docs pages under `docs/` link source to this fork.

## Pending (Plan 2, not yet applied)

- Optional `[slug]` argument in `to-spec`/`to-tickets`: when the repo's tracker config is GitHub, label issues `spec:<slug>` (renamed from the fork's old `prd:<slug>` / `kind:prd` convention — see `setup-repo-skills/triage-labels.md` Markers, still old wording).
- `triage`: fork's category-default rule (PRD-derived tickets default to `enhancement`; `bug` only when reproduction surfaces a defect).
- `to-tickets`: story-traceability field ("Covers user stories") + coverage check in the confirmation step (conditional on numbered stories), acceptance-criteria quality rules.
- `agent/<slug>` companion branch: dropped from `to-spec` for now; may return as an optional GitHub-only step or move to `implement`.
- Docs pages owed for fork skills (`bootstrap-context`, `commit`, `open-pr`, `setup-repo-skills`, `cross-check-with-codex`, `setup-claude-code`, `write-a-skill`) per the docs-page convention in `CLAUDE.md`.
