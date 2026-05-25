# Forbid TODO markers in implementer worker prompts

When a Tier 3 implementer (or any stage that writes shipped code) is dispatched, the prompt MUST forbid the worker from leaving `TODO` / `FIXME` / `XXX` / `HACK` / `KLUDGE` / `DEFERRED` markers in committed code.

## The directive (copy into worker prompts)

```text
## TODO discipline

Do not commit any `TODO`, `FIXME`, `XXX`, `HACK`, `KLUDGE`, or `DEFERRED` comments. Two acceptable responses when tempted:

1. Implement the deferred work in this PR.
2. STOP and escalate to the lead for a follow-up issue. The lead files a tracker entry; the worker resumes with the original scope intact.

Do not punt scope via a comment. Comments describe what the code IS, not what it SHOULD BECOME.

Before each commit, run:

    git diff --cached | grep -nE '\b(TODO|FIXME|XXX|HACK|KLUDGE|DEFERRED)\b'

If any line begins with `+` (an addition), remove the marker or escalate.
```

## Why this lives in the agent-loop skill

Tier 5 reviewers catch TODO additions via the code-review scan. By the time Tier 5 sees them, the worker has already committed and dispatched the review tier — the fix loop is the cost. Forbidding at the implementer level avoids that round trip.
