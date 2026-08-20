# FORK.md: Intentional Divergences from Upstream

## Premises

The goal is to stay mergeable. Upstream moves fast, and this fork exists to follow it while keeping
the handful of things that do our work better. Every divergence is a standing cost: it conflicts on
every future sync, forever. So a divergence has to earn it.

Three things earn it:

1. **Correctness here.** A name, path, or link that would otherwise point at upstream's world instead
   of ours. A docs page linking `aihero.dev/skills-ask-matt` is wrong in a fork that ships
   `ask-author`. Fix these. Never let a link fail, and never let one fall back to upstream's page for
   a skill we have changed.
2. **Function we use.** A skill, or a behaviour inside one, that measurably improves our work.
   `commit`, `open-pr`, and the spec lifecycle are here on that basis.
3. **Identity.** Package name, repo URLs, plugin manifests.

Everything else follows upstream, including things we merely prefer. Prose, punctuation, structure,
section order, and file layout are upstream's call: taking their version costs nothing, and taking
ours costs a conflict on every future edit to that line. When upstream deletes something, the default
is to follow.

Every divergence below survives one of the three tests. When one looks like it has stopped earning
its cost, raise it rather than acting on it. Deleting a divergence, or letting upstream overwrite
fork work, is the user's call and never the agent's: propose it, get confirmation, then act.

Each entry is tagged with the test that justifies it: *(correctness)*, *(function)*, *(identity)*.

## Merging with upstream

This fork (`harisjavaid85/ai-agent-skills`) tracks `mattpocock/skills` as the `upstream` remote.

1. `git fetch upstream`, then merge `upstream/main` on a throwaway branch first. The conflict list is
   the survey; read it before resolving anything.
2. Resolve by the table below. Where it says take theirs, take the **whole file**, then re-apply the
   fork's names and links; `git checkout --theirs` discards fork edits living outside the conflict
   hunks, which is right for prose and wrong for a file we actively maintain.
3. Watch the clean merges, not just the conflicts. Upstream deleting a file we depend on produces no
   conflict marker at all.
4. Run the checks: `claude plugin validate . --strict`, `npm run check-plugin-version`,
   `npx changeset status`, `bash tests/link-skills.sh`.
5. Update this file in the same pass. A divergence that is not written down here is one the next sync
   resolves back toward upstream by accident.

Two house rules that are upstream's and ours: no em-dashes anywhere in prose, and skill descriptions
in `SKILL.md` frontmatter are quoted YAML scalars when they contain a colon.

| Path | At a conflict | See |
| --- | --- | --- |
| `docs/**` | take theirs, then repoint sibling and router links | Repo furniture |
| `skills/engineering/{implement,code-review,tdd}/SKILL.md` | hand-merge, keep the fork's behaviour | Behaviour changed on upstream skills |
| `skills/engineering/{to-spec,to-tickets}/SKILL.md` | hand-merge, keep the lifecycle arguments | Spec lifecycle |
| `skills/engineering/ask-author/**` | hand-merge, the router must list fork skills | Renamed skills |
| `skills/**/SKILL.md` (all others) | take theirs, re-apply fork names | Renamed skills |
| `skills/engineering/domain-modeling/**`, `setup-repo-skills/domain.md` | hand-merge, preserve the `KNOWLEDGE.md` block | KNOWLEDGE.md |
| `.changeset/*.md` | take theirs, rename the package key | Repo furniture |
| `scripts/link-skills.sh` | take ours | Repo furniture |
| `README.md`, `CLAUDE.md`, `CONTEXT.md` | hand-merge | Repo furniture |
| `.claude-plugin/*.json`, `package.json` | hand-merge, fork identity wins | Repo furniture |
| `.agents/install-block.md` | take theirs | Misc |

## Divergences

### Renamed skills

Renames are the most expensive class here: they conflict on every upstream edit to the renamed file
and on every cross-reference to it. Both below predate these premises.

- **`ask-author`** (upstream: `ask-matt`) *(identity)*. Author-neutral name for the router over this
  skill set. The skill directory, metadata, docs page, plugin manifest, READMEs, and active
  cross-references use the fork name; imported `CHANGELOG.md` and `.changeset/` entries retain the
  historical name.
- **`grill-with-context`** (upstream: `grill-with-docs`) *(identity)*. Same thin composition ("run a
  `/grilling` session, using the `/domain-modeling` skill"), fork name kept. Cross-references in
  `ask-author`, `write-a-skill`, `setup-repo-skills/domain.md`, docs pages, and `engineering/README.md`
  point to the fork name. Unlike `ask-author` this is a naming preference rather than a necessity, so
  it is the weaker of the two under the premises above.

### Behaviour changed on upstream skills

Upstream still ships all four. Only the behaviour differs, so these are the hand-merges.

- **`implement`** *(function)*. Owns exactly one explicit issue, path, or settled conversation.
  Executes autonomously through `tdd`, runs and remediates one `code-review`, then leaves the working
  tree uncommitted for the separate `commit` skill. It does not resolve lifecycle slugs or mutate
  issue or PR state. It is **model-invoked** where upstream sets `disable-model-invocation: true`: a
  user-invoked skill can never reach another, so a closed `implement` is unreachable from any
  orchestrating skill.
- **`code-review`** *(function)*. Reviews the complete included working tree since a fixed point:
  committed, staged, unstaged, and untracked work, with optional exclusion pathspecs. Upstream
  reviews the diff alone. The caller owns remediation.
- **`tdd`** *(function)*. Treats a seam named by the work source or supplied by its caller as agreed;
  otherwise proposes the narrowest existing public seam and confirms it with the user. Upstream
  requires every seam be confirmed up front. `implement` supplies missing seams before invoking
  `tdd`, which is what preserves autonomous execution.
- **`to-tickets`** *(correctness)*. Writes the issue body's **Blocked by** section only when the
  tracker has no native blocking relationship; upstream writes it unconditionally. Where native links
  exist they are the sole record: a body copy beside them is somewhere for the two to disagree, and a
  reader trusts whichever they see first.

### Fork-only skills

`commit`, `open-pr`, `cross-check-with-codex`, `setup-claude-code`, `write-a-skill`,
`bootstrap-context`, `setup-repo-skills`. Each carries `agents/openai.yaml` metadata.
`setup-repo-skills`, `setup-claude-code`, and `bootstrap-context` are **user-invoked**
(`disable-model-invocation: true` plus `allow_implicit_invocation: false`); the rest are
model-invoked. Three need more than a name:

- **`setup-repo-skills`** *(function)* supersedes upstream's `setup-matt-pocock-skills`. Ported from
  upstream: PRs-as-triage-surface and wayfinding operations in `issue-tracker-*.md`, the
  tracker-choice section (GitHub, GitLab, local, other), the interactive "one section, one answer"
  flow, triage-installed gating of the triage-labels section, tracker-neutral `triage-labels.md`.
  **Not** ported: upstream's section that *decides* single- versus multi-context layout, per ADR-0004,
  because `bootstrap-context` is the semantic authority for that decision.
- **`write-a-skill`** *(function)* is the workflow counterpart to upstream's `writing-great-skills`
  reference. It uses upstream's terms (**steps** and **reference**, not Behaviour and Vocabulary) and
  defers principles to `writing-great-skills/GLOSSARY.md`.
- **`bootstrap-context`** *(function)* is the **batched** domain-modeling mode (survey, then bootstrap
  or update, then drift audit); upstream's `domain-modeling` is the **inline** mode. Formats live
  canonically in `domain-modeling/`, and `bootstrap-context` links to them.

### Spec lifecycle

Fork-only, and cross-cutting: it touches `to-spec`, `to-tickets`, `open-pr`, and `setup-repo-skills`
at once. All *(function)*.

- A GitHub parent spec carries `kind:spec` and no triage-state label. An optional kebab-case slug adds
  the repository-wide lifecycle label `spec:<slug>`; one slug identifies one parent across open and
  closed states.
- `to-tickets` resolves or inherits the lifecycle slug and applies `spec:<slug>` plus
  `ready-for-agent` to every implementation ticket. Numbered source stories are mapped across the
  tickets and checked for complete coverage before publication. Acceptance criteria use imperative
  voice and independently verifiable success conditions.
- `open-pr <slug>` resolves the spec by two slug-scoped probes, a `kind:spec` plus `spec:<slug>` issue
  or else a `.scratch/<slug>/spec.md` committed on the branch, and links the parent and completed
  tickets from whichever answers, GitHub winning when both do.
- `setup-repo-skills` provisions the fixed `kind:spec` marker. `to-spec` creates each dynamic
  `spec:<slug>` label.
- The tracker-specific `gh` commands live in the **Spec lifecycle operations** section of
  `setup-repo-skills/issue-tracker-github.md` (emitted into consumer repos as
  `docs/agents/issue-tracker.md`). `to-spec` and `to-tickets` stay tracker-agnostic and follow that
  section when the tracker config defines it, mirroring how `wayfinder` consumes "Wayfinding
  operations".

### KNOWLEDGE.md

Upstream has no knowledge-base file. This fork's `KNOWLEDGE.md` holds durable learned facts, distinct
from glossary, ADRs, and policy. All *(function)*. It appears in:

- `domain-modeling/SKILL.md`, in the tree diagrams. The two `KNOWLEDGE.md` lines are the fork block;
  upstream's file has none.
- `domain-modeling/CONTEXT-FORMAT.md`, as the "Domain language only" carve-out rule (the first rule),
  plus the "root `CONTEXT.md` may sit alongside the map for repo-wide carrier vocabulary" line in the
  multi-context section.
- `setup-repo-skills/domain.md`, as the full routing taxonomy. Fork-authored; upstream's `domain.md`
  is a subset.
- `bootstrap-context/SKILL.md`, where the out-of-contract audit classifies per `domain.md`.

### Repo furniture

- **`scripts/link-skills.sh`** *(function)*. Upstream's dual-destination base (`~/.claude/skills` plus
  `~/.agents/skills`) with fork enhancements: interactive collision prompts that never silently
  `rm -rf`, non-interactive abort, stale-link pruning including deprecated skills, argument
  strictness. Tests in `tests/link-skills.sh`. Take ours at a conflict: the enhancements sit outside
  the conflicting hunks, so taking theirs discards them silently.
- **Out-of-scope KB path is `docs/out-of-scope/`** (upstream: `.out-of-scope/`) *(function)* in
  consumer repos: `triage/SKILL.md`, `triage/OUT-OF-SCOPE.md`, `triage/AGENT-BRIEF.md`,
  `setup-repo-skills/domain.md`, and `docs/engineering/triage.md` all use the fork path. This repo's
  **own** rejected-request records live at `.out-of-scope/`, upstream's location, so upstream edits to
  those merge cleanly.
- **Docs pages** *(correctness)*. Every promoted skill has a page under `docs/`. Sibling and router
  links use absolute `github.com/harisjavaid85/ai-agent-skills` URLs instead of upstream's
  `aihero.dev/skills-<name>`, because those pages document skills this fork ships under other names.
  Everything else about a page is upstream's, including the absence of an install block: upstream
  dropped Quickstart and Source links from every page and this fork followed. Install wording lives
  once in the top-level `README.md`. Rules and template in `.agents/writing-docs.md`. Links to the
  AI Coding Dictionary are upstream's convention and are kept.
- **`.changeset/*.md`** *(identity)*. Every changeset keys on `ai-agent-skills`. Upstream's arrive
  naming `mattpocock-skills`, which makes `changeset status` exit 1 with "not in the workspace";
  rename the key on every incoming changeset.
- **Fork metadata** *(identity)* lives in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
  and `package.json`: name `ai-agent-skills`, this repo's URL. The release version tracks upstream's
  numbering so the two stay comparable.
- **`misc/` bucket is not shipped** (upstream policy): its skills appear only in
  `skills/misc/README.md`, never in the top-level `README.md` or `.claude-plugin/plugin.json`.

### Misc

Upstream files whose state we deliberately do not mirror.

- **`.agents/install-block.md`** is imported verbatim and is **not** authoritative here. It names
  `mattpocock-skills` in Claude Code's official marketplace and `skills.sh/mattpocock/skills`; this
  fork is in neither. Its rule that a docs page carries no install commands is one we follow, but for
  a different reason: not because a site renders a widget, but because the wording belongs in
  `README.md`. Where it says to select `setup-matt-pocock-skills` on install, here it is
  `setup-repo-skills`. Rewrite or delete it before citing it.
- **`CHANGELOG.md`** retains upstream's package name and `github.com/mattpocock/skills` PR links
  throughout. It is a historical record of released versions, most of them upstream's.
- **`skills/productivity/writing-great-skills/`** is kept although upstream deleted it in favour of
  `writing-for-agents`. `write-a-skill` links its `SKILL.md` and `GLOSSARY.md` directly, and
  `writing-for-agents` ships no `GLOSSARY.md`, so the deletion cannot be adopted before
  `write-a-skill` is ported off it. Both skills currently ship.
- **`skills/personal/`** (`edit-article`, `obsidian-vault`) is kept although upstream deleted the
  whole bucket. Not promoted, so it appears in no manifest.
- **`skills/deprecated/setup-matt-pocock-skills/`** is kept as the historical record of the skill
  `setup-repo-skills` replaced.
