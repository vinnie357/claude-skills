# Merge and Close-Out

The operator-approved merge sequence and PR cleanup procedure.

## Gate checklist before merging

All three conditions must be true before executing the merge:

1. **Local gates green (baseline-diff)**: every gate that was passing on `main` is still passing on the consolidated branch. Paste output as evidence.
2. **Remote CI green**: `gh pr checks <consolidated-pr-number>` shows all checks passing. If any check is pending, wait. If any check fails, return to baseline-diff verification.
3. **Operator go-ahead**: explicit approval from the operator. The skill and any agents do not merge unilaterally.

## Squash merge

```bash
gh pr merge <consolidated-pr-number> --squash
```

The squash commit message is auto-generated from the PR title. Do not add attribution (no `Co-Authored-By`).

## Comment each superseded Dependabot PR

For each Dependabot PR number `<n>` that was cherry-picked into the consolidated branch:

```bash
gh pr comment <n> -b "Addressed by #<consolidated> (consolidated dependency update)"
```

This gives GitHub's Dependabot a signal and leaves a clear audit trail for reviewers who see the closed PRs.

## Verify each PR is closed

Dependabot may auto-close superseded PRs after merge, but do not assume it has done so.

```bash
gh pr view <n> --json state --jq '.state'
```

Expected values: `MERGED` or `CLOSED`. If the PR is still `OPEN`, close it manually:

```bash
gh pr close <n> --comment "Superseded by #<consolidated> (consolidated dependency update)"
```

Repeat for every Dependabot PR in the batch. Confirm each one before reporting done.

## PR body template (Supersedes section)

Include in the consolidated PR body:

```markdown
## Supersedes

Consolidates the following Dependabot PRs:

- #<n1> Bump <dep-a> from <old> to <new>
- #<n2> Bump <dep-b> from <old> to <new>
- #<n3> Bump <actions/checkout> from 4.1.0 to 4.2.2

## Baseline-diff verification

Gates run on `main` and on this branch. Only new failures block.

| Gate           | main  | branch | Classification |
|----------------|-------|--------|----------------|
| cargo test     | PASS  | PASS   | not a regression |
| cargo clippy   | PASS  | PASS   | not a regression |
```

## Anti-fabrication requirement

- Do not report "all Dependabot PRs are closed" without running `gh pr view <n> --json state` for each one.
- Do not report "CI is green" without showing `gh pr checks` output.
- Paste the exact state value returned by the CLI, not an interpretation.
