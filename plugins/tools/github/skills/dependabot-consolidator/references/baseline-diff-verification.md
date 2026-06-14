# Baseline-Diff Verification

The discipline for classifying CI failures as regressions vs pre-existing issues.

## The core principle

A gate failure on the consolidated branch is only a blocking regression if that gate was PASSING on `main` before the bump. Running gates on `main` first is not optional — it is the only way to avoid false blame.

## Gate enumeration

Before running anything, list all gates that will be verified:

1. Compile / build: `cargo build`, `npm run build`, `go build ./...`
2. Unit tests: `cargo test`, `npm test`, `go test ./...`
3. Lint / format: `cargo clippy`, `npm run lint`, `go vet ./...`
4. Type-check: `tsc --noEmit` (if applicable)
5. Integration tests: any script in `scripts/` or `Makefile` that runs broader tests
6. Local integration gates (see `local-integration-gates.md`): Apple Container cluster spawn, hardware-dependent steps

## Procedure

### Step 1: record merge-base state

```bash
git checkout main
git pull origin main
```

Run each gate. Capture verbatim output for each:

```bash
cargo test 2>&1 | tee /tmp/gate-main-cargo-test.txt
```

Mark each gate: `PASS` or `FAIL`.

### Step 2: run gates on consolidated branch

```bash
git checkout chore/consolidate-dependabot
```

Run the same gates in the same order. Capture verbatim output:

```bash
cargo test 2>&1 | tee /tmp/gate-branch-cargo-test.txt
```

### Step 3: diff and classify

For each gate, compare main vs branch:

| Gate | main | branch | Classification |
|------|------|--------|----------------|
| cargo test | PASS | PASS | not a regression |
| cargo test | PASS | FAIL | **BLOCKING regression** |
| cargo test | FAIL | FAIL | pre-existing failure (not caused by bump) |
| cargo test | FAIL | PASS | improvement (not blocking) |

Only `PASS → FAIL` transitions are blocking. Stop the consolidation and report the gate name and the diff between the two output files.

## Worked kina examples (kina PR #36)

**Example 1 — Apple Container XPC gate**

`cargo test` included a test that spawns an Apple Container cluster. On `main`, this test failed because Apple Container XPC was not running in the CI environment. On the consolidated branch, it failed identically. Classification: pre-existing infrastructure gap, not a regression. The bump was not the cause.

**Example 2 — integration validate script**

`scripts/test-cluster.nu` line 68 raised an error on both `main` and the branch due to a harness bug (missing env var). Classification: pre-existing harness bug, not a regression. The consolidated PR correctly excluded this failure from the blocking list.

## Reporting a blocking regression

When a `PASS → FAIL` transition is found:

1. Name the gate exactly: `cargo test --test integration_tests`
2. Show the diff of outputs (main vs branch)
3. Identify which cherry-picked commit introduced the failure (`git bisect` if needed)
4. Stop. Report to operator. Do not attempt to fix the dependency bump unilaterally.

## Anti-fabrication rule

Never report "gates pass" without showing captured command output. Paste `/tmp/gate-branch-*.txt` contents or equivalent verbatim in the report.
