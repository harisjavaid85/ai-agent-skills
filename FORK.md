# FORK.md — intentional divergences from upstream

This fork (`harisjavaid85/ai-agent-skills`) tracks `mattpocock/skills` as `upstream`. This file is the merge playbook: every intentional divergence from upstream, with rationale. When syncing (`git fetch upstream && git merge upstream/main`), resolve conflicts so these divergences are preserved — and update this file when a divergence is added or dropped.

## Renames kept from this fork

- **`ask-author`** (upstream: `ask-matt`) — author-neutral name for the router over this skill set. The skill directory, metadata, docs page, plugin manifest, READMEs, and active cross-references use the fork name; imported upstream `CHANGELOG.md` and `.changeset/` entries retain the historical name.
- **`grill-with-context`** (upstream: `grill-with-docs`) — same thin composition ("run a `/grilling` session, using the `/domain-modeling` skill"), fork name kept. Cross-references in `ask-author`, `write-a-skill`, `setup-repo-skills/domain.md`, docs pages, and `engineering/README.md` point to the fork name.

## Skills that replace upstream skills

- **`setup-repo-skills`** supersedes upstream's `setup-matt-pocock-skills` (deleted from this fork). Ported from upstream: PRs-as-triage-surface + wayfinding operations in `issue-tracker-*.md`, the tracker-choice section (GitHub/GitLab/local/other), the interactive "one section, one answer" flow, triage-installed gating of the triage-labels section, tracker-neutral `triage-labels.md`. **Not** ported: upstream's section that *decides* single- vs multi-context layout — ADR-0004 (`bootstrap-context` is the semantic authority for that decision).
- **`write-a-skill`** (fork-only workflow skill) complements upstream's `writing-great-skills` (reference). Fork version uses upstream's terms (**steps**/**reference**, not Behaviour/Vocabulary) and defers principles to `writing-great-skills/GLOSSARY.md`.
- **`bootstrap-context`** (fork-only) is the **batched** domain-modeling mode (survey → bootstrap/update → drift audit); upstream's `domain-modeling` is the **inline** mode. Formats live canonically in `domain-modeling/`; `bootstrap-context` links to them.
- **`implement`** owns exactly one explicit issue, path, or settled conversation. It executes autonomously through `tdd`, runs and remediates one `code-review`, then leaves the working tree uncommitted for the separate `commit` skill. It does not resolve lifecycle slugs or mutate issue/PR state. Diverging from upstream, it is **model-invoked** (upstream sets `disable-model-invocation: true`): a user-invoked skill can never reach another, so a closed `implement` is unreachable from any orchestrating skill.
- **`code-review`** reviews the complete included working tree since a fixed point: committed, staged, unstaged, and untracked work. The caller owns remediation.
- **`tdd`** treats a seam named by the work source or supplied by its caller as agreed; otherwise it proposes the narrowest existing public seam and confirms it with the user. `implement` selects and supplies missing seams before invoking `tdd`, preserving autonomous execution.

## Fork-only skills (additive, no upstream counterpart)

`commit`, `open-pr`, `cross-check-with-codex`, `setup-claude-code` — plus `write-a-skill`, `bootstrap-context`, `setup-repo-skills` above. Each carries `agents/openai.yaml` metadata. Invocation choices: `setup-repo-skills`, `setup-claude-code`, and `bootstrap-context` are **user-invoked** (`disable-model-invocation: true` + `allow_implicit_invocation: false`); the rest are model-invoked.

## Spec lifecycle (fork-only)

- A GitHub parent spec carries `kind:spec` and no triage-state label. An optional kebab-case slug adds the repository-wide lifecycle label `spec:<slug>`; one slug identifies one parent across open and closed states.
- `to-tickets` writes the issue body's **Blocked by** section only when the tracker has no native blocking relationship; upstream writes it unconditionally. Where native links exist they are the sole record — a body copy is somewhere for the two to disagree, and a reader trusts whichever they see first.
- `to-tickets` resolves or inherits the lifecycle slug and applies `spec:<slug>` plus `ready-for-agent` to every implementation ticket. Numbered source stories are mapped across the tickets and checked for complete coverage before publication. Acceptance criteria use imperative voice and independently verifiable success conditions.
- `open-pr <slug>` resolves the spec by two slug-scoped probes — a `kind:spec` + `spec:<slug>` issue, else a `.scratch/<slug>/spec.md` committed on the branch — and links the parent and completed tickets from whichever answers, GitHub winning when both do.
- `setup-repo-skills` provisions the fixed `kind:spec` marker. `to-spec` creates each dynamic `spec:<slug>` label.
- The tracker-specific `gh` commands live in the **Spec lifecycle operations** section of `setup-repo-skills/issue-tracker-github.md` (emitted into consumer repos as `docs/agents/issue-tracker.md`); `to-spec` and `to-tickets` stay tracker-agnostic and follow that section when the tracker config defines it — mirroring how `wayfinder` consumes "Wayfinding operations".

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
- **Out-of-scope KB path is `docs/out-of-scope/`** (upstream: `.out-of-scope/`) in consumer repos: `triage/SKILL.md`, `triage/OUT-OF-SCOPE.md`, `triage/AGENT-BRIEF.md`, `setup-repo-skills/domain.md`, and `docs/engineering/triage.md` all use the fork path. This repo's **own** rejected-request records live at `.out-of-scope/` in upstream's location, so upstream edits to those files merge cleanly.
- **`misc/` bucket is not shipped** (upstream policy): its skills appear only in `skills/misc/README.md`, never in the top-level `README.md` or `.claude-plugin/plugin.json`.
- Fork metadata lives in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `package.json` (name `ai-agent-skills`, this repo's URL).
- Every promoted skill has a page under `docs/`. Quickstart, source, sibling, and router links use absolute `github.com/harisjavaid85/ai-agent-skills` URLs; this fork does not use upstream's `aihero.dev` publishing convention. The canonical rules and template live in `.agents/writing-docs.md`.
