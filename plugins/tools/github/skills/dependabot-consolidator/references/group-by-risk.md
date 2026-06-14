# Group by Risk

Ecosystem × risk taxonomy for deciding how to consolidate Dependabot PRs.

## Risk classification

### Config-only Actions bumps (low risk)

Characteristics:
- Changed files are all under `.github/workflows/`
- No source code, no lockfiles, no package manifests changed
- Version bump is within the same major version (e.g., `@v4.1.0` → `@v4.2.2`)

Validation path: real GitHub CI running on the pushed branch is the authoritative gate. These bumps run in the CI environment and are validated by the actual workflows that use them.

Decision: **consolidate freely** into the main branch.

### Minor/patch package bumps (medium risk)

Characteristics:
- Semver minor or patch change (e.g., `1.8.0` → `1.10.0`, `2.3.1` → `2.3.4`)
- Language/package manifest changed (`Cargo.toml`, `package.json`, `go.mod`, `requirements.txt`, etc.)
- No public API removal expected per semver convention

Validation path: local compile + unit tests under baseline-diff discipline.

Decision: **consolidate** unless baseline-diff shows a new test failure.

### Major package bumps (high risk)

Characteristics:
- Semver major change (e.g., `1.x` → `2.0`, `3.x` → `4.0`)
- May remove or rename public APIs
- May require code changes in the consuming repo

Validation path: local compile + unit tests + any integration tests. May require manual code changes before cherry-pick can complete.

Decision: **evaluate individually**. Consider splitting from other bumps if code changes are needed. If MAJOR bumps are few and straightforward (no API removals in the changelog), they can be included; if they require code edits, create a separate PR for each MAJOR bump.

## Consolidate-all vs split-actions-from-code

| Scenario | Recommendation |
|----------|----------------|
| All PRs are config-only Actions bumps | Consolidate all into one PR |
| Mix of Actions bumps + minor/patch packages | Consolidate all; baseline-diff validates |
| Any MAJOR package bump with API removals | Split: Actions+minor/patch in one PR, each MAJOR in its own PR |
| Large volume (>15 PRs) | Consider two PRs: Actions and code, to keep review scope manageable |

## Identifying ecosystem from PR file list

```bash
gh pr view <n> --json files --jq '.files[].path'
```

- All paths match `.github/workflows/*.yml` → config-only Actions
- Paths include `Cargo.toml` or `Cargo.lock` → Rust package
- Paths include `package.json` or `package-lock.json` → npm
- Paths include `go.mod` or `go.sum` → Go module
- Paths include `requirements.txt` or `pyproject.toml` → Python package

## Version-change detection

To identify MAJOR version bumps without reading each PR body:

```bash
gh pr view <n> --json title
```

Dependabot PR titles follow the pattern `Bump <dep> from <old> to <new>`. Parse the versions:

```bash
gh pr list --author "app/dependabot" --state open --json number,title \
  | from json \
  | where title =~ "from \\d+\\." \
  | select number title
```

Extract old and new major versions from the title. If `new_major > old_major`, classify as MAJOR bump.
