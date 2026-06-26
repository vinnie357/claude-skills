# Merge and Close Out

The operator-owned merge gate and the close-out steps. Agents never merge — this step runs in
the supervised loop after a reviewer returns `approve` and the operator gives the go-ahead.

## Pre-merge gate

All three must hold before merging a PR:

1. **Local gates green** — baseline-diff verified (gates run on `main` first), no regression.
2. **Remote CI green** — `gh pr checks <n>` shows all checks passing.
3. **Operator go-ahead** — explicit, per PR. Approval of one PR is not approval of the next.

## Merge

```bash
gh pr merge <n> --squash
```

Squash merge only. No attribution and no `Co-Authored-By` in the squash commit message.

## Confirm closure

Do not assume the merge succeeded — a merge step can report failure after GitHub already
merged, and vice versa. Confirm:

```bash
gh pr view <n> --json state,mergedAt
```

Verify `state` is `MERGED`. If a merge command errored but `state` is `MERGED`, the merge
happened — proceed. If `state` is still `OPEN`, the merge did not happen — investigate.

## request-changes path

A PR the reviewer flagged `request-changes` is not merged. Post a review comment summarizing
the blocking findings and leave the PR open for the author. Keep the comment terse and
specific — list the `file:line` blockers and the gate evidence, no filler. The author pushes
fixes; re-review from the baseline-diff step.

## Out of scope

Bot dependency PRs (`app/dependabot`) are not merged by this skill. Route them to
`/github:dependabot-consolidator`.
