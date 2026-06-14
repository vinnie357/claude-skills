# Consolidation Algorithm

Full cherry-pick mechanics for merging Dependabot PRs into a single branch.

## Branch setup

```bash
git fetch origin
git checkout -b chore/consolidate-dependabot origin/main
```

Always branch from `origin/main`, not from a local `main` that may be stale.

## Ordering cherry-picks

Order matters when multiple PRs touch the same file. Use this order:

1. Actions bumps (`.github/workflows/` only) — lowest conflict risk
2. Minor/patch package bumps — no API changes expected
3. Major package bumps — highest conflict risk, resolve last

Collect PR head SHAs with:

```bash
gh pr list --author "app/dependabot" --state open \
  --json number,headRefName,headRefOid \
  | from json
```

## Cherry-pick each PR

```bash
git cherry-pick <sha>
```

If `git cherry-pick` exits non-zero, inspect `git status` to classify the conflict.

## Conflict resolution: keep every bump

Dependabot PRs each target a distinct action or package. In a well-maintained lockstep repo, conflicts are rare. When they occur:

- **Same file, different line** (e.g., two actions bumped in the same workflow): accept both sides. Use `git checkout --ours <file>` then manually re-apply the other side, or edit the file to include both bumps.
- **Same file, same line** (two PRs bump the same dependency to different versions): escalate to operator. Do not choose a version unilaterally. Report: which two PRs conflict, the file, the line, and both target versions.

After resolving:

```bash
git add <file>
git cherry-pick --continue
```

## Pin-style preservation

Dependabot maintains two pin styles. Read the file before cherry-picking to identify the style in use:

**Major tag style**:
```yaml
uses: actions/checkout@v4
```

**Full SHA + comment style**:
```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```

After cherry-picking, verify the style was preserved with `git diff HEAD~1 <file>`. If the style changed (e.g., SHA replaced with tag), revert to the original style before committing.

## Lockfile handling

1. Check if the lockfile is tracked: `git check-ignore -v <lockfile>`
   - If ignored: do not commit it.
   - If tracked: update it and commit it with the bump.

2. For Cargo lockfiles (`Cargo.lock`): update only the bumped crate.
   ```bash
   cargo update -p <crate-name>
   ```
   Do not run `cargo update` (global) — it may update unrelated crates.

3. For npm (`package-lock.json`): `npm install` after applying the `package.json` bump.

4. For Go (`go.sum`): `go mod tidy` after applying the `go.mod` bump.

## Push and open PR

```bash
git push -u origin chore/consolidate-dependabot
```

Draft the PR body with a "Supersedes" section listing each Dependabot PR number and title:

```
## Supersedes

- #101 Bump actions/checkout from 4.1.0 to 4.2.2
- #102 Bump actions/setup-rust-toolchain from 1.8.0 to 1.10.0
```

This gives reviewers a clear audit trail.
