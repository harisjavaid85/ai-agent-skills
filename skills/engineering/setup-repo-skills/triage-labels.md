# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual GitHub label strings used in this repo. Issue categories use GitHub's `bug` and `enhancement` labels directly.

| Canonical label   | Label in our tracker | Meaning                                  |
| ----------------- | -------------------- | ---------------------------------------- |
| `needs-triage`    | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`      | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent` | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human` | `ready-for-human`    | Requires human implementation            |
| `wontfix`         | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use. Re-run `/setup-repo-skills` after changing a mapped string so it can create the label if it is missing.

## Markers

In addition to triage-role labels, this repo uses fixed marker labels:

| Marker     | Purpose                                |
| ---------- | -------------------------------------- |
| `kind:prd` | Identifies the tracker issue for a PRD |
