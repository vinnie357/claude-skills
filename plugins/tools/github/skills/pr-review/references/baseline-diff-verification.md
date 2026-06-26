# Baseline-Diff Verification

The discipline that prevents blaming a PR for a failure it did not introduce: run every gate
on `main` FIRST, then on the PR branch, and block only on a NEW failure.

## Why

A repo's `main` often carries pre-existing gate failures — a flaky integration test, a
hardware-dependent gate that fails off-CI, a lint that was never green. If you run a gate only
on the PR branch and see red, you cannot tell whether the PR caused it. Running the same gate
on `main` first gives you the baseline to diff against.

## Procedure

1. **Enumerate gates** with `mise tasks`.
2. **Run on main**, capturing verbatim output:
   ```bash
   git checkout main && git pull origin main
   mise run ci 2>&1 | tee /tmp/gate-main-ci.txt
   ```
   Repeat for each gate the PR needs (`pre-commit`, `test`, integration tasks). Record
   PASS/FAIL per gate.
3. **Run on the branch**, same gates:
   ```bash
   git fetch origin && git checkout <headRefName>
   mise run ci 2>&1 | tee /tmp/gate-branch-ci.txt
   ```
4. **Diff and classify**:
   ```bash
   diff /tmp/gate-main-ci.txt /tmp/gate-branch-ci.txt
   ```

| main | branch | verdict |
|------|--------|---------|
| PASS | FAIL | **regression** — block, report gate name + diff |
| FAIL | FAIL | pre-existing — not a blocker; show on both sides |
| PASS | PASS | clean |
| FAIL | PASS | the PR fixed a pre-existing failure — note it |

5. **Return to main** (`git checkout main`) before the next PR.

## Local-only integration gates

Some gates run only on the operator machine: Apple Container cluster spawns, hardware tests,
anything hosted CI skips. Run these locally under the same main-then-branch discipline. They
need exclusive hardware, so review PRs that exercise them **sequentially** — never spawn two
cluster gates in one working tree at once. See `/core:container`.

## Worked example — kina

kina's hosted CI runs only `cargo fmt --check` + `cargo clippy` (tests need macOS + Apple
Container and are disabled in the workflow). So the real gate is local:

- `mise run ci` → fmt check → clippy → test
- `mise run pre-commit` → the above + `cargo audit` + gitleaks
- `mise run test:cluster` → spawns a real Apple Container cluster (exclusive hardware)

A Rust PR there runs `mise run ci` on `main`, then on the branch, and diffs. If `test:cluster`
fails identically on both sides it is pre-existing (a known harness issue), not a regression —
exactly the call made on kina PR #36.

## Anti-fabrication

Never report a gate result without the verbatim command output. When a failure is
pre-existing, show it failing on BOTH `main` and the branch — a paraphrase is not evidence.
