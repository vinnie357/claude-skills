# Scanning for TODO/FIXME/XXX/HACK markers

Code review rejects new `TODO`, `FIXME`, `XXX`, `HACK`, `KLUDGE`, and `DEFERRED` comments in shipped code. The presence of any of these markers in the diff is a BLOCKER, not a nit.

## Why

TODO-style markers are issue tracking pretending to be code:
- They rot — the context that motivated them is forgotten by the next reader.
- They do not surface in any tracker query (`bees ready`, sprint dashboards, etc.).
- They invite the same author to defer their own contract instead of escalating properly.
- They describe what the code IS NOT or SHOULD BECOME, instead of what it IS.

## The scan

In any code review of a PR diff:

```bash
git diff <base>...HEAD | grep -nE '\b(TODO|FIXME|XXX|HACK|KLUDGE|DEFERRED)\b'
```

If the scan returns non-empty lines added by THIS diff (`+` lines, not `-` lines), reject the PR with a structured finding citing each match's file:line and the marker word.

## What to do instead

The author has two acceptable responses to "I want to TODO this":

1. **Implement it now.** If the change fits in the current PR, do it.
2. **File a follow-up issue.** The deferred work becomes a tracked issue (bees, Linear, or equivalent); the comment-source becomes the issue body, not a code comment. The PR description links the issue.

## What IS allowed

- Comments explaining WHY non-obvious code does what it does (hidden constraints, subtle invariants, workarounds for specific bugs the comment NAMES).
- Module and function documentation describing purpose and contract.
- ADRs and design docs in the project's architecture directory — that is their job.
