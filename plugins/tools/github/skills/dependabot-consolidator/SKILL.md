---
name: dependabot-consolidator
description: Consolidate a repository's open Dependabot PRs into one tested branch and PR, grouping by ecosystem and risk, verifying with baseline-diff gates, and closing out on operator approval. Use when a repo has multiple open Dependabot PRs to batch, when consolidating dependency bumps into a single reviewable PR, or when verifying dependency updates without mistaking pre-existing failures for regressions.
license: MIT
---

# Dependabot Consolidator

Codifies the recipe proven on kina PR #36: collect open Dependabot PRs, consolidate into one tested branch and PR, verify with baseline-diff gates, and close out on operator approval. Single-repo, operator-supervised scope.

## When to Use This Skill

- A repo accumulates multiple open Dependabot PRs and you want to batch them
- You want a single reviewable dependency-update PR instead of N separate reviews
- You need to verify dependency bumps without confusing pre-existing CI failures with regressions
- You are preparing a consolidated PR for operator review and approval before merging

## Scope: Dependabot only

List open Dependabot PRs with:

```bash
gh pr list --author "app/dependabot" --state open \
  --json number,title,headRefName,files
```

**Warning**: never touch human-authored PRs in the same pass. The `--author app/dependabot` filter is the guard; verify it returns only bot-authored entries before proceeding.

## Decide grouping: ecosystem and risk

Classify each PR as config-only Actions or code/package bump before creating the branch. Decision: consolidate-all vs split-actions-from-code.

- **Config-only Actions bumps** (`.github/workflows/*.yml` only): validated authoritatively by real GitHub CI running on the pushed branch. Low risk; consolidate freely.
- **Language/package bumps** (Cargo.toml, package.json, go.mod, etc.): breaking MAJORs may need local compile, test, and code changes. Higher risk; consider splitting from Actions bumps if any contain MAJOR version changes.

See `group-by-risk.md` for the full ecosystem × risk taxonomy.

## Consolidation procedure

Create branch and cherry-pick each Dependabot PR head in order:

```bash
git fetch origin
git checkout -b chore/consolidate-dependabot origin/main
```

For each PR (ordered low-risk first, MAJOR bumps last):

```bash
git cherry-pick <pr-head-sha>
```

**Conflict rule — keep every bump**: Dependabot PRs each target a distinct dependency. When cherry-pick conflicts arise, keep both sides (each bump targets a different line/package). Do not drop either side.

**Pin-style preservation**: Dependabot updates pins in two styles — `@v4` major tag and full commit SHA with a `# vX.Y.Z` trailing comment. Read the file before cherry-picking to know which style applies; preserve that style after merge.

**Lockfile handling**: Before assuming a lockfile needs a manual update, run `git check-ignore <lockfile>`. If the lockfile is tracked, commit the updated version. For Cargo: `cargo update -p <dep>` for the specific crate only — do not run a global `cargo update`.

See `consolidation-algorithm.md` for full cherry-pick mechanics and edge cases.

## Verify with baseline-diff gates

**THE key insight**: run each gate on the merge-base (main) FIRST, then on the branch. Only a NEW failure — one that does not appear on main — is a regression worth blocking on.

Gate discipline:

1. Identify the gates: `cargo test`, `npm test`, lint, type-check, build, integration scripts.
2. Run each gate on `main` / merge-base. Capture output. Record pass/fail per gate.
3. Checkout the consolidated branch. Run the same gates. Capture output.
4. Diff: classify only gates that were PASSING on main and are now FAILING on branch as blocking.
5. Gates that fail identically on both sides are pre-existing failures — not regressions.

**Local integration gates**: some gates cannot run in GitHub CI (Apple Container cluster spawn, hardware-dependent tests). Run these on the operator machine under the same baseline-diff discipline. See `local-integration-gates.md` and `/core:container` for container-spawn patterns.

See `baseline-diff-verification.md` for worked kina examples and the full gate enumeration workflow.

Use `/github:act` to replay GitHub CI gates locally before pushing. See `/github:workflows` for workflow file interpretation.

## Merge and close out

Gate before merging:

1. Green on local gates (baseline-diff verified)
2. Green on remote CI (`gh pr checks` — all checks passing)
3. Explicit operator go-ahead

After operator approval:

```bash
gh pr merge <consolidated-pr-number> --squash
```

No attribution in the squash commit message.

For each superseded Dependabot PR, comment then verify closure:

```bash
gh pr comment <n> -b "Addressed by #<consolidated> (consolidated dependency update)"
gh pr view <n> --json state
```

Verify the `state` field is `MERGED` or `CLOSED`. Do not assume Dependabot auto-closes — confirm with `gh pr view` for each one.

See `merge-and-closeout.md` for the full close-out checklist.

## Delegation

Hand mechanical cherry-picking to `dependabot-consolidator-worker.md`. Read-only PR collection goes to `dependabot-collector.md`.

**Stop-and-report gates** (worker must halt, not thrash):

- Conflict that cannot be resolved with keep-both (same line, competing values) → STOP, report the conflicting PRs and the specific file/line
- Non-trivial dependency API break requiring code changes → STOP, report the bump and the compilation error
- A baseline-diff gate that was green on main but fails on branch → STOP, report the gate name and diff of outputs

**Hard constraint**: agents never merge unilaterally. Merge is operator-approved and executed by the skill's close-out step.

## Registration

See `registration.md` for the build checklist covering marketplace.json, plugin.json, and sources.md edits, plus the two validators to run before committing.

## Related skills

- `/core:anti-fabrication` — never claim a gate passed without showing command output
- `/core:container` — local integration gates using Apple Container
- `/github:act` — replay CI gates locally before push
- `/github:workflows` — read and interpret workflow files
- `/github:actions` — understand action versions and pin styles

## Anti-Fabrication

- Never claim a gate passed without showing the command and its output verbatim.
- Always run the baseline gate on `main` before blaming a bump for a failure.
- Confirm PR closure with `gh pr view <n> --json state` — do not assert "Dependabot closed it."
- Verify pin style by reading the file with the Read tool before asserting `@v4` vs full-SHA style.
- When reporting cherry-pick conflicts, show the exact `git status` output, not a paraphrase.

See `/core:anti-fabrication` for the full discipline.
