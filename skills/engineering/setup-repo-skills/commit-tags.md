# Commit Tags

The `commit` skill prefixes each commit subject with a tag. This file maps the eight canonical tags to the strings this repo actually uses, and sets the subject format. When the skill builds a commit message, it uses the right-hand column and the template below.

| Canonical tag | Tag in this repo | Covers                                                        |
| ------------- | ---------------- | ------------------------------------------------------------- |
| `Feature`     | `Feature`        | new functionality (`feat`)                                    |
| `Fix`         | `Fix`            | fixes broken behavior (`fix`)                                 |
| `Doc`         | `Doc`            | documentation (`docs`)                                        |
| `Refactor`    | `Refactor`       | behavior-preserving restructure, including `perf` and `style` |
| `Test`        | `Test`           | tests                                                         |
| `Chore`       | `Chore`          | non-code housekeeping: deps, build, ci, config, tooling       |
| `Merge`       | `Merge`          | manual merge resolution                                       |
| `Revert`      | `Revert`         | manually backing out a previous change                        |

**Subject template:** `[<tag>] <summary>`

`<tag>` is the right-column string; `<summary>` is an imperative summary (≤ ~50 chars including the tag, no trailing period). The mood is always imperative.

Edit the right-hand column and the subject template if the house style changes.
