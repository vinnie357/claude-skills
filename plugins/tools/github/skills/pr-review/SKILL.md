---
name: pr-review
description: Review a repository's open human-authored pull requests one at a time with a stack-aware agent per PR, build and test each branch locally under baseline-diff gates, and squash-merge on operator approval. Use when a repo has open contributor or collaborator PRs to review and merge, when reviewing external PRs that need local build/test before merge, or when triaging the open PR queue without mistaking pre-existing CI failures for regressions.
license: MIT
---

# PR Review

Reviews open, human-authored pull requests with the care of the Forge operating model
(`/core:agent-loop`): a read-only collector classifies the queue, one stack-aware reviewer
runs per PR, each branch is built and tested locally under baseline-diff discipline, and the
operator owns every merge. Repo-agnostic — stack and gates are discovered, never hardcoded.

## Scope: human-authored PRs only

List open PRs and exclude bots:

```bash
gh pr list --state open \
  --json number,title,author,headRefName,headRefOid,files
```

Drop every PR whose `author.is_bot` is true or whose login is `app/dependabot`. Bot
dependency PRs belong to `/github:dependabot-consolidator`, not this skill. Verify the
filtered list contains only human authors before dispatching reviewers.

## Classify each PR: stack and gates

Classify before reviewing. Two inputs drive the classification:

1. **Stack** — read the PR's changed file extensions and the repo's manifests
   (`Cargo.toml`, `mix.exs`, `build.zig`, `package.json`, `go.mod`). Map to the reviewer's
   language skills. See `references/stack-detection.md` for the full table.
2. **Gates** — discover the repo's own gate tasks with `/core:mise`: run `mise tasks` and
   pick the PR-gating tasks (`ci`, `pre-commit`, `test`, `lint`, `fmt:check`, `audit`,
   `gitleaks`). Run the discovered tasks — never assume `cargo`/`mix`/`npm` directly.

Hand this read-only classification to the `pr-collector` agent.

## Per-PR review: one agent per PR

Dispatch one `pr-review-worker` per PR. Fan-out width equals the open-PR count, the Forge
slice model. Run the reviewers **sequentially** when the gates need exclusive hardware
(integration tests, container or cluster spawns) — parallel branch checkouts in one working
tree pollute each other. Before any checkout, confirm the working tree carries no other
worker's branch changes and no uncommitted *source* changes — operator-owned tracker files or
untracked local dirs are fine to leave in place (see `agents/pr-review-worker.md`).

Every reviewer loads, at minimum:

```
/core:git
/core:mise
/core:security
/core:anti-fabrication
```

plus the stack-specific skills from the classification (for example `/rust:rust`,
`/rust:testing`, `/rust:error-handling` for Rust; `/core:documentation` for docs;
`/github:workflows`, `/github:actions` for Actions changes).

## Verify with baseline-diff gates

**THE key insight**: run each gate on `main` FIRST, then on the PR branch. Only a gate that
was PASSING on `main` and is now FAILING on the branch is a regression worth blocking on.

Gate discipline:

1. Discover the gate tasks (`mise tasks`).
2. Run each gate on `main`. Capture verbatim output. Record pass/fail.
3. Check out the PR branch (`git checkout <headRefName>`). Run the same gates. Capture output.
4. Classify: only gates PASSING on main and FAILING on branch block.
5. Gates that fail identically on both sides are pre-existing — not regressions. A gate
   failing on main and passing on the branch means the PR fixed it — note that.
6. Check out `main` again before the next PR.

Some gates run only on the operator machine (Apple Container clusters, hardware-dependent
tests) and are skipped by hosted CI. Run those locally under the same baseline-diff
discipline. See `references/baseline-diff-verification.md` and `/core:container`.

Use `/github:act` to replay hosted CI gates locally when useful.

## Review the diff

Read `git diff main...<headRefName>` against `references/review-rubric.md`: correctness,
security, test coverage, no leaked secrets, and match to the PR's stated intent. The reviewer
emits a structured verdict — `approve` or `request-changes` with `file:line` findings and
verbatim gate evidence. The reviewer never edits code and never merges.

## Merge and close out

Gate before merging:

1. Green on local gates (baseline-diff verified)
2. Green on remote CI (`gh pr checks` — all checks passing)
3. Explicit operator go-ahead, per PR

After operator approval:

```bash
gh pr merge <n> --squash --match-head-commit <headRefOid>
```

Pin to the `headRefOid` collected above — a merge without `--match-head-commit` is blocked by the claude-skills-340 merge-write gate and is unsafe in any case, since it can silently merge a commit that arrived after review. No attribution in the squash commit message. Confirm closure:

```bash
gh pr view <n> --json state
```

Verify `state` is `MERGED`. A `request-changes` PR gets a review comment instead and stays
open. See `references/merge-and-closeout.md`.

## Delegation

- Read-only PR collection and classification → `agents/pr-collector.md`.
- Per-PR baseline-diff gates and diff review → `agents/pr-review-worker.md`.

**Stop-and-report gates** (worker halts, does not thrash):

- A gate green on `main` but failing on the branch → STOP, report the gate name and output diff
- A diff that needs code changes to pass → STOP, report `request-changes` with the failure
- An ambiguous or contradictory PR intent → STOP, report what is unclear

**Hard constraint**: agents never merge unilaterally. Merge is operator-approved and executed
by this skill's close-out step.

## Registration

See `references/registration.md` for the marketplace.json, plugin.json, sources.toml, and sources.md edits,
plus the two validators to run before committing.

## Related skills

- `/core:agent-loop` — the Forge operating model this skill mirrors (collector hands, per-slice principals, operator-owned merge)
- `/core:anti-fabrication` — never claim a gate passed without showing command output
- `/core:mise` — discover the repo's gate tasks instead of assuming a toolchain
- `/core:container` — local integration gates using Apple Container
- `/github:act` — replay hosted CI gates locally before merge
- `/github:dependabot-consolidator` — the bot-PR counterpart this skill defers to

## Anti-Fabrication

- Never claim a gate passed without showing the command and its verbatim output.
- Always run the baseline gate on `main` before blaming a PR for a failure.
- Confirm PR closure with `gh pr view <n> --json state` — do not assert "it merged."
- Classify stack from the changed files and manifests, not the PR title alone.
- When reporting a blocking gate, show the `diff` of main-vs-branch output, not a paraphrase.

See `/core:anti-fabrication` for the full discipline.
