# Coding Standards

How agents write code in this repo, per language. The **producing** agent reads the relevant section _before_ writing code in that language; `review`'s Standards axis reads it as a backstop.

A section binds the agent to a named external style guide. The guide is the source of truth for the whole convention set: both what tooling enforces and the judgment calls it cannot (naming, docstrings, module boundaries). The linter is the mechanical safety net; the guide covers the rest. When a rule is unclear, fetch the authoritative URL and follow it.

Across every language: reach for an existing helper before writing a near-duplicate; don't extract a shared abstraction until a second caller genuinely earns it.

**Writing a language with no section below?** Add one first, using the matching row from the _Catalog defaults_ table. If the language isn't in that table either, pick its best-adopted style guide, add the section, and add a table row.

## Comments

Binds every language; the sections below add the per-language docstring form.

- **Earn it.** Write a comment only when the code can't say it: a non-obvious invariant, a constraint on a future change, a reason the obvious alternative fails. When the name, type, or signature already says it, let them.
- **In a body, at a use site, beside a branch: one line by default, three the ceiling.** Consecutive comment lines on one subject count as one block.
- **A comment that outgrows the ceiling isn't local.** It's carrying a fact about more than the line it sits on, so route it per `docs/agents/domain.md`: onto the declaration its readers pass through, or into `KNOWLEDGE.md` when they share none. Leave behind only what is true at this line and nowhere else.
- **Cite an ADR, not the glossary or the knowledge base.** _"Postgres, not Kafka: see ADR-0007"_ points at rationale the code can't carry. A glossary term from `CONTEXT.md` is already carried by the identifier that names it, and a `KNOWLEDGE.md` entry exists only because no declaration owns its fact, so a pointer to either is a second copy that goes stale on its own.
- **At a declaration, length is set by the design, not the ceiling.** This is where an invariant or a constraint on a future change gets written down. Structured docstrings follow the bound style guide, which owns their form and length.
- **The same bar applies in every file**, whatever its neighbours already carry.

## Python

- **Follow:** Google Python Style Guide
- **Authoritative:** https://google.github.io/styleguide/pyguide.html (fetch when a rule is unclear)
- **Enforced by:** `ruff` + `black`, the same commands the `## Verify` Fast tier runs
- **Deviations:** _none_; list where this repo departs from the guide (e.g. line length 100)
- **Emphasise:** _optional_; judgment-layer rules to weight here (e.g. Google-style docstrings on the public API)

_(One block like the above per language present in the repo. The block is this repo's binding and may carry deviations; the table below is the deviation-free default.)_

## Catalog defaults

Lookup source when adding a section above. A detected language with no row here gets its guide chosen by hand.

| Language                | Style guide                    | Authoritative URL                                  | Enforced by                              |
| ----------------------- | ------------------------------ | -------------------------------------------------- | ---------------------------------------- |
| Python                  | Google Python Style Guide      | https://google.github.io/styleguide/pyguide.html   | `ruff` + `black`                         |
| C++                     | Google C++ Style Guide         | https://google.github.io/styleguide/cppguide.html  | `clang-format`                           |
| Java                    | Google Java Style Guide        | https://google.github.io/styleguide/javaguide.html | `google-java-format`                     |
| Go                      | Effective Go + `gofmt`         | https://go.dev/doc/effective_go                    | `gofmt` / `goimports` (+ `golangci-lint`) |
| TypeScript / JavaScript | Airbnb JavaScript Style Guide  | https://github.com/airbnb/javascript               | `eslint` (airbnb config) + `prettier`    |
| Rust                    | Rust API Guidelines + `rustfmt`| https://rust-lang.github.io/api-guidelines/        | `rustfmt` + `clippy`                     |
| Ruby                    | RuboCop Ruby Style Guide       | https://rubocop.org/                               | `rubocop`                                |
| Shell                   | Google Shell Style Guide       | https://google.github.io/styleguide/shellguide.html| `shellcheck` + `shfmt`                   |

Edit a row to change the default, or add a row for a language not listed. Re-run `/setup-repo-skills` after adding a language, or add the section by hand from this table.
