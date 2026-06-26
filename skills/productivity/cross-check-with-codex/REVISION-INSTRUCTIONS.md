# Codex Revision Review Instructions

Verify the revision against the original request, settled constraints, and complete review instructions already present in this resumed thread.

- Reassess unresolved findings using their existing IDs.
- Verify accepted fixes and Claude's rejection rationale.
- Identify regressions introduced by the revision.
- Mark corrected findings `RESOLVED`.
- Mark findings `WITHDRAWN` when Claude's rejection rationale is accepted.
- Keep `NEEDS_REVISION` when a finding remains valid.
- Use `NEEDS_USER_DECISION` when resolution requires the user.
- Do not reopen `WITHDRAWN` findings without new concrete evidence.
- Continue to remain read-only and independently inspect repository evidence when needed.

Return the canonical review format established in the initial instructions. Begin with exactly:

```text
NEEDS_REVISION: <count>
NEEDS_USER_DECISION: <count>
```

The counters must equal the active `NEEDS_REVISION` and `NEEDS_USER_DECISION` findings.
