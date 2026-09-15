# Baseline-Diff Verification

The discipline that prevents blaming a PR for a failure it did not introduce: run every gate
on `main` FIRST, then on the PR branch, and block only on a NEW failure.

## Why

A repo's `main` often carries pre-existing gate failures — a flaky integration test, a
hardware-dependent gate that fails off-CI, a lint that was never green. If you run a gate only
on the PR branch and see red, you cannot tell whether the PR caused it. Running the same gate
on `main` first gives you the baseline to diff against.

## Procedure

Gates run in a gate-runner's own scratchpad clones, never in the shared working tree — clone handling per `/core:agent-loop` `references/researcher.md` "Execution hands". One clone at main's oid supplies the baseline; one clone at the PR's `headRefOid` supplies the branch.

1. **Enumerate gates** with `mise tasks`.
2. **Clone the baseline and run on it**, capturing verbatim output:
   ```bash
   git clone <repo-url> "$SCRATCHPAD/repo-main"
   git -C "$SCRATCHPAD/repo-main" checkout <main-oid>
   git -C "$SCRATCHPAD/repo-main" remote remove origin
   (cd "$SCRATCHPAD/repo-main" && mise run ci > "$SCRATCHPAD/gate-main-ci.log" 2>&1); echo "EXIT=$?"
   ```
   Repeat for each gate the PR needs (`pre-commit`, `test`, integration tasks). Record
   PASS/FAIL per gate. EXIT comes from the command itself, never through a pipe.
3. **Clone the PR head and run on it**, same gates:
   ```bash
   git clone <repo-url> "$SCRATCHPAD/repo-pr"
   git -C "$SCRATCHPAD/repo-pr" fetch origin "pull/<pr-number>/head"
   git -C "$SCRATCHPAD/repo-pr" checkout <headRefOid>
   git -C "$SCRATCHPAD/repo-pr" remote remove origin
   (cd "$SCRATCHPAD/repo-pr" && mise run ci > "$SCRATCHPAD/gate-branch-ci.log" 2>&1); echo "EXIT=$?"
   ```
   The fetch makes a fork PR's head reachable; a PR from the same repo needs it too when the branch was deleted.
4. **Diff and classify**:
   ```bash
   diff "$SCRATCHPAD/gate-main-ci.log" "$SCRATCHPAD/gate-branch-ci.log"
   ```

| main | branch | verdict |
|------|--------|---------|
| PASS | FAIL | **regression** — block, report gate name + diff |
| FAIL | FAIL | pre-existing — not a blocker; show on both sides |
| PASS | PASS | clean |
| FAIL | PASS | the PR fixed a pre-existing failure — note it |

5. **Discard both clones** (or leave them for the next step's re-read) before the next PR — no
   state to return, since the shared working tree was never touched.

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
Record each gate run as an Execution evidence record per `/claude-code:claude-output-styles`
`assets/ci-evidence-format.md` "Execution evidence".
