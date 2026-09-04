---
name: git
description: Guide for Git operations including commits, branches, rebasing, and conflict resolution. Use when working with version control, creating commits, managing branches, or resolving merge conflicts.
---

# Git Operations

Activate when creating commits, managing branches, creating pull requests, resolving conflicts, or following Git workflows.

## Anti-fabrication

This skill follows `core:anti-fabrication`. The commit/PR format rules are house
convention, but the "Remote and Authentication Conventions" section makes specific,
checkable claims about Git and the GitHub API — this is the one skill in this set that
does, and its two claims are verified two different ways:

- **Anonymous access to GitHub Releases on a private repo returns 404, not 403.**
  Confirmed against GitHub's own documentation, cited in `sources.md`: "GitHub uses a 404
  Not Found response instead of a 403 Forbidden response to avoid confirming the
  existence of private repositories."
- **SSH key auth bypasses the `workflow` OAuth scope that HTTPS push enforces.** GitHub
  documents the `workflow` scope requirement for OAuth apps/PATs pushing Actions workflow
  files (cited in `sources.md`), but does not document the SSH-side exemption as a general
  principle — that half is empirically observed, not centrally documented: pushing a
  `.github/workflows/*.yml` change over HTTPS with a token lacking `workflow` scope is
  rejected ("Refusing to allow an OAuth App to create or update workflow ... without
  `workflow` scope"); the identical push over SSH succeeds.

Don't assert `git`/`gh`/`glab` CLI or GitHub/GitLab API behavior this skill doesn't
already cover without checking the current docs, or testing it directly when the docs
don't say — CLI flags and API responses do change across versions.

- **`glab` command/flag names** throughout this skill and `references/gitlab-mr.md`
  come from the official docs at `https://docs.gitlab.com/cli/` (per-command pages
  cited in `sources.md`), NOT from local execution — `glab` was not installed on the
  machine where this content was authored, and no command here was tested by running
  it. No `glab` version is pinned deliberately: pinning a version never actually run
  against would overstate the evidence. Re-check with `glab <cmd> --help` before
  relying on a flag.

## Commit Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): description

optional body

optional footer
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

**Subject line rules:**
- Keep under 50 characters
- Lowercase after type prefix
- No period at the end
- Use imperative mood ("add" not "added" or "adds")

**Body** (optional): Wrap at 72 characters. Focus on the what and how — never describe the changes themselves, as the git diff handles that.

**Footer** (optional): Reference issues (`Closes #123`), note breaking changes (`BREAKING CHANGE: ...`).

**NEVER include attribution** — no `Co-Authored-By`, `Signed-off-by`, or similar footers. This rule has no exceptions, and it is not limited to commits: it covers everything posted through `gh`/`glab` under the authenticated identity — PR/MR titles and descriptions, PR/MR comments and review bodies (`gh pr comment --body`, `gh pr review --body`, `glab mr note create --message`), issue comments, release notes, and annotated-tag messages. Unlike gitleaks (which has the `check-secrets-before-commit.sh` PreToolUse hook as a backstop), this rule has **no enforcement hook at all** — a known gap, not an oversight to assume away. A commit message is amendable while the PR is open; a posted comment is public immediately, and edits leave a visible history.

**Examples:**

```bash
# Single-line (preferred for most commits)
feat(auth): add JWT authentication
fix(api): handle null values in user response
docs(readme): add installation instructions
chore(deps): bump plugin versions

# With body and footer
feat(api): add user search endpoint

Implement full-text search across user names and emails using
PostgreSQL's full-text search capabilities.

BREAKING CHANGE: API now requires PostgreSQL 12+
Closes #789
```

## PR / MR Format

Title matches commit format. Body is a bullet list of changes only.

```bash
gh pr create --title "feat(auth): add JWT authentication" --body "- Add JWT generation and validation
- Implement refresh token rotation
- Add authentication middleware"

glab mr create --title "feat(auth): add JWT authentication" --description "- Add JWT generation and validation
- Implement refresh token rotation
- Add authentication middleware"
```

Note `glab`'s flag is `--description`, not `--body` — the flag name differs from `gh`'s.

**Rules:**
- No attribution (no "Generated with Claude Code" or similar)
- No PR / MR templates or boilerplate sections
- No "Summary", "Test Plan", or other headers
- Just the changes as bullet points
- Keep it minimal and scannable

## PR / MR Workflow

1. **Gate 1 — Local CI**: `mise run ci` — fix until 0 failures
2. **Commit**: Conventional commit, no attribution
3. **Gitleaks**: Scan committed changes for secrets — `$(mise which gitleaks) git . --staged`, never a bare `gitleaks` (`/core:security`). The `check-secrets-before-commit.sh` PreToolUse hook backstops this on `git commit`, but only while `/core:security` is loaded (hooks are scoped to their own skill's lifecycle) and it fails open — allows the commit — when no scanner is available. Run the scan yourself; don't treat the hook as a substitute for it.
4. **Push**: `git push -u origin <branch>`
5. **Create PR**: `gh pr create` (GitHub) or `glab mr create` (GitLab) with minimal format (title + bullets)
6. **Gate 2 — Watch remote CI**: `gh pr checks --watch` (GitHub) or `glab ci status --live` (GitLab) (wait for CI to complete)
7. **After CI passes** (if using bees):
   - `bees close <task-id>`
   - `git add .bees/ && git commit -m "chore(bees): close <task-id>"`
   - `git push`
8. **Notify** (Gate 2 satisfied — local + remote green): "CI passed, PR ready for merge review"
9. **Cleanup** (after user merges):
   - `git checkout main && git pull`
   - `git branch -d <branch>`
10. **Continue**: `bees ready` for next task

## Three-Gate Merge Policy

Three gates protect main. None is optional, and none substitutes for another.

**Gate 1 — Local (before every commit).** `mise run ci` runs green — tests, lint, and format, 0 failures — before each `git commit`. A red local CI means the commit is broken: fix it locally, never push past it. Scan staged changes with gitleaks before push — resolved binary path, never a bare `gitleaks`: `$(mise which gitleaks) git . --staged`. The PreToolUse hook backstops this on `git commit`, but only while `/core:security` is loaded, and fails open when no scanner is available — it is not a substitute for the scan (`/core:security`).

**Gate 2 — Remote (before every squash merge).** Squash-merge a PR only when **both** conditions hold:

1. Local `mise run ci` is green on the branch HEAD being merged, **and**
2. `gh pr checks` (GitHub) or `glab ci status` (GitLab) reports every remote check passing.

**Gate 3 — Adversarial review (before every squash merge).** Every PR gets a review from a separate agent on the strongest thinking model the harness offers — the same tier as `/core:agent-loop`'s reviewer default, and overridable by its model-overrides convention. Name a capability, never a model literal. No exemption: not for one-line fixes, not for documentation, not for version bumps.

The reviewer is briefed to **defeat the change, not approve it**. Give it the specific failure the change is meant to prevent and ask it to construct a case that still gets through. A reviewer told to "check this over" returns nothing useful; a reviewer told "assume a defect exists and find it" returns the defect.

**Three focus areas are standing — every review carries them, whatever else the brief adds:**

1. **Restraint** (`/core:restraint`). Does this change need to exist? Is it the minimum that works, or does it add a symbol, an abstraction, or a config knob the task never asked for? Could an existing helper, stdlib call, or platform feature have done it? A reviewer that only hunts bugs approves well-built things that should not have been built.

2. **Documentation the change obligates.** If the change alters behaviour, an interface, or a decision, did it update what depends on that — user docs, READMEs, ADRs, system-design documents, and the skill or reference that describes the thing? A change that silently invalidates a document is a defect with a delayed fuse.

3. **Claims in the PR body.** Every measurement, count, and "verified" in the description is checkable. Check them. Overstated PR bodies are a common defect this process finds.

Gate 3 requirements:

- **A separate agent.** The author cannot review its own work — the point is a reader without the author's assumptions.
- **Read-only, with a scratchpad clone for destructive tests.** See `/core:agent-loop`'s `references/dispatch-discipline.md`, "Read-only agents never touch the shared working tree".
- **Findings are addressed or answered, not waved through.** Applying a fix, disputing it with evidence, and filing it as a tracked follow-up all count. Silence does not.
- **Verify the reviewer's claims independently** before acting on them. A review is evidence, not a verdict.
- **Grep for attribution before posting a comment or declaring gates green** — both the branch's commits and the comment text about to be posted: `git log origin/main..HEAD --format='%B' | grep -niE 'co-authored-by|signed-off-by|assisted-by|generated with'`, same pattern against the comment body. The pattern deliberately excludes bare model/vendor names — in this repo (`claude-skills`, scopes like `feat(claude-code):`) a bare `grep -i claude` would be a constant false positive. Eyeball the trailer block to catch what the pattern misses.
- **The verdict and each finding's disposition land as a durable record on the PR** — a PR comment, or a bees comment the PR links. Gates 1 and 2 have observables (`mise run ci` output, `gh pr checks`); Gate 3 needs one too, or "review done" is an unverifiable assertion of exactly the kind this gate exists to catch. Check it with `gh pr view <n> --comments`.

No `gh pr merge --squash` while any gate is red. Who may take the merge is set by the deployment's merge policy — see "Merge authorization" below.

### Merge authorization

`AGENT_LOOP_MERGE_POLICY` selects the authorization source. It never carries the authorization itself.

| Value | Source consulted | Effect |
|---|---|---|
| `operator` (default) | none | The agent reports the PR and stops. |
| `approval` | a forge review approval bound to `headRefOid` by a non-author identity, read at merge time | A leader-tier agent merges once the precondition holds. |

Unset and `""` resolve to `operator` silently. Any other unrecognised value resolves to `operator` and emits one line: `merge-policy: AGENT_LOOP_MERGE_POLICY=<value> not recognized; proceeding as operator`.

Under `operator` no agent merges, so no agent evaluates the precondition. Step 8 of the PR / MR Workflow above is unchanged.

**Scope.** This policy governs first-party work only. The `github` plugin's `pr-review` and `dependabot-consolidator` skills merge third-party code and stay operator-approved whatever this variable is set to. A PR with `isCrossRepository == true` is out of scope.

#### The precondition

The precondition binds a merging agent. It does not bind a human. Read the forge immediately before the merge, for every rule except rule 3's default-branch read, cached once per session. The transcript is not an input. An earlier tool result is not an input.

```bash
gh pr view <n> --json headRefOid,baseRefName,isCrossRepository,mergeStateStatus,mergeable,statusCheckRollup,reviews,comments,autoMergeRequest
```

1. **Checks.** `statusCheckRollup` returns two types with different fields: `CheckRun` carries `status` and `conclusion`; `StatusContext` carries `state` and no `conclusion`. BLOCK on any `CheckRun` conclusion in {FAILURE, CANCELLED, TIMED_OUT, ACTION_REQUIRED, STARTUP_FAILURE, STALE}, or any `StatusContext` state in {ERROR, FAILURE}. WAIT on any `CheckRun` status other than COMPLETED, or any `StatusContext` state in {PENDING, EXPECTED}. Accept conclusions {SUCCESS, NEUTRAL, SKIPPED} and state SUCCESS. Require at least one SUCCESS — an all-SKIPPED rollup satisfies "a check is present" and proves nothing.
2. **Gate 3 record.** A PR comment carries, on its own line, `Gate 3: APPROVE <40-hex-oid>` matching `headRefOid` exactly. A free-text sha mention does not satisfy this. Treat a comment whose `includesCreatedEdit` is true as absent. The comment's author must not be the identity performing the merge. A `Gate 3: REJECT <40-hex-oid>` comment matching `headRefOid` BLOCKS regardless of any APPROVE marker at the same head, and blocks whether or not it was edited. Do not extend the `includesCreatedEdit` rule to a REJECT: discarding an edited APPROVE fails closed, and discarding an edited REJECT fails open, because anyone with write access can edit another user's comment. Any block signal wins.
3. **Base.** `baseRefName` equals the repository default branch. Read the default branch once per session with `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`; `gh pr view --json` carries no such field (verified against gh 2.93.0's field list).
4. **Mergeability.** `mergeStateStatus` is in {CLEAN, HAS_HOOKS}, or UNSTABLE when rule 1 is independently satisfied. BLOCK on DIRTY, BLOCKED, and BEHIND. On UNKNOWN, re-read a bounded number of times — watching `mergeable` alongside it — then WAIT. Never merge on UNKNOWN.
5. **Reviews.** Compute each author's latest review from `reviews[]` by `submittedAt`, restricted to entries whose state is APPROVED or CHANGES_REQUESTED. This restriction drops DISMISSED and COMMENTED entries from consideration (a COMMENTED review never clears a CHANGES_REQUESTED block — GitHub keeps the block until dismissal or a new approving review from the same author). Any author whose latest qualifying review is CHANGES_REQUESTED blocks, whatever commit it targets. Read `reviews[]`, never `latestReviews[]`.
6. **Under `approval` only.** A `reviews[]` entry has `state == APPROVED` and `commit.oid == headRefOid`, from a login other than the PR author and other than the identity performing the merge, which the merging agent learns via `gh api user -q .login`.
7. **Under `approval` only.** `isCrossRepository == false`.
8. **Dismissals — allowlist, not denylist.** Evaluate this rule only when rule 5's `reviews[]` read contains a DISMISSED entry; the common path with no dismissal skips this read entirely. When triggered, run `gh api repos/<owner>/<repo>/issues/<n>/timeline --paginate` after the `gh pr view` read. WAIT on a non-zero exit, or when the output is not a JSON array of events. BLOCK unless every `review_dismissed` event's `dismissed_review.state` is in {`approved`, `commented`}. A DISMISSED entry is dropped by rule 5's APPROVED/CHANGES_REQUESTED filter; a dismissed CHANGES_REQUESTED can silently restore an earlier approval as that author's latest qualifying review.

Then merge pinned to the sha that was read:

```bash
gh pr merge <n> --squash --match-head-commit <headRefOid>
glab mr merge <n> --squash --yes --auto-merge=false --sha <headRefOid>
```

**Forbidden — each one defers the merge, bypasses a requirement, or edits the evidence.** `gh pr merge --auto` queues a merge that fires later. `gh pr merge --admin` bypasses branch requirements and a merge queue. `glab mr merge` without `--auto-merge=false` queues on a flag that defaults to true. On a repo with a merge queue, plain `gh pr merge` adds the PR to the queue instead of merging it. Detect the queue and wait. `autoMergeRequest` in the read is the observable for "no auto-merge is already queued". A merging agent never dismisses a review or deletes a Gate 3 comment — both are writes on the evidence this precondition reads. `gh` has no dismissal verb; dismissal requires `gh api --method PUT .../pulls/<n>/reviews/<id>/dismissals -f message=...`.

**A missing signal means WAIT, never denied.** Denied is a terminal disposition, and an unattended session may act on it — close the PR, abandon the branch, fail the issue. Wait means this: leave the PR exactly as it is, report what is being waited on, and end the turn. Safe means the PR's forge state is unchanged by the session.

**Re-attestation.** The Gate 3 record names the sha that merges. When commits land after the record, the reviewer reads `git diff <reviewed-sha>..<head>` only, confirms the delta addresses its findings and introduces nothing else, then posts the marker line at the new sha. A marker posted without reading the delta is the unverifiable assertion Gate 3 exists to catch.

#### What `approval` is entitled to claim

An APPROVED review pinned to head by a login other than the PR author, with `author.login` as the actor record. That is a distinct forge identity — not a human. Two consequences follow. In a single-identity deployment `approval` is unsatisfiable, because the author cannot self-approve; it is `operator` with a longer read. In a bot-identity deployment, one agent holding tokens for two identities satisfies it with zero humans. The deployment obligation therefore lands on the approving identity: it must not be one the agent can authenticate as. An allowed-approver list or an `authorAssociation` filter is the knob.

#### Residual risks

1. `approval` guarantees a distinct forge identity, not a human review.
2. Field consistency inside one `gh pr view --json` read is treated as a consistent snapshot; GitHub does not document it as one. `--match-head-commit` bounds the damage to a check status flipping on an unchanged head.
3. Base moved, not head: the checks ran against the branch, not against a squash onto current main. BEHIND is reported only under a "require branches up to date" rule, so `mergeStateStatus` does not cover this. Post-merge main verification (`/core:tdd`, `references/ci-discipline.md`) is the only backstop.
4. `reviews[].commit.oid` is the field this precondition reads. A reader who substitutes `latestReviews[]` may get a value that does not equal `headRefOid` — it fails safe, but silently.
5. GitLab here is docs-only: `--sha`, `glab mr view` approval fields, and self-approval project settings are unverified, the same evidence class disclosed in "Anti-fabrication" above.
6. A merge queue inverts the meaning of plain `gh pr merge` — it queues rather than merges. The forbidden-command list and the `autoMergeRequest` observable handle it; it is restated because it changes a command this skill otherwise uses.
7. A repo with no CI, or with fully path-filtered CI, never satisfies the at-least-one-SUCCESS rule and waits permanently under `approval`. That is correct behavior, not a defect.
8. `mergedBy` records the agent's forge identity, so the audit trail cannot distinguish an agent merge from a human one. Removing the standing axiom grows this risk.
9. Records are editable. Rule 2 handles it through `includesCreatedEdit`; an implementer who reads records as immutable reintroduces it.
10. A force-push orphans a review's commit. The `commit.oid == headRefOid` pin handles APPROVED, and the per-author-latest rule keeps a CHANGES_REQUESTED on an unreachable commit blocking.
11. A repo-local `mise.toml` `[env]` block can set `AGENT_LOOP_MERGE_POLICY`, so on a deployment that trusts repo config the policy is settable by a PR branch. Set the variable in the launcher environment and do not let repo config override it.
12. Rule 8 waits permanently once a disallowed dismissal lands, including an operator's legitimate one, because the timeline event never clears; the remedy is an operator merge, not a re-review. It reads a second endpoint, so risk 2's single-snapshot treatment does not cover it. Deleting an APPROVE comment fails rule 2 closed; deleting a REJECT comment is undetectable, since GitHub documents no REST event type for comment deletion. An agent that dismisses a review after completing every read can still merge, because no rule pins review state at merge time. A sample of 8 public repositories, over each repository's last 100 PRs, found 21 review dismissals with prior state `approved` and 8 with `changes_requested`, and none at all in 3 of them — evidence that a bot self-dismissing its own CHANGES_REQUESTED occurs, not a measured rate for `approval` deployments generally. Rule 8 detects a dismissal; it does not prevent one. The forge-side control that does is branch protection's restriction on who may dismiss reviews, the counterpart to the allowed-approver knob above. Rule 8's trigger depends on a dismissed review remaining in `reviews[]`; requires verification: whether GraphQL `deletePullRequestReview` can remove a submitted review, which would leave no such entry and silence the rule. A REJECT marker at a stale sha does not block, which follows from re-attestation but is asymmetric with rule 5, where a CHANGES_REQUESTED blocks whatever commit it targets.

### Gate 3 is not the pipeline's review tier

`/core:agent-loop`'s five-tier pipeline has its own reviewers — P5 verifies tests exercise the acceptance criteria, the test-review stage checks for redundancy. Those judge whether the implementation meets **the issue's spec**.

Gate 3 runs **on the PR** and judges whether the change is defensible against someone trying to break it. Identify it by its brief, not its timing: no pipeline reviewer counts, even one that read the full PR diff — Forge's Final Reviewer does exactly that and is still not Gate 3. Gate 3 is the review carrying the defeat-the-change brief and the three standing focus areas, dispatched after the pipeline reports done.

### Why three gates and not two

Gates 1 and 2 prove the suite passes, not that the change is correct. A green build is evidence the tests ran, not evidence the work is right — and the defects worth catching here are the ones a passing suite cannot see: documentation that describes behaviour the code does not have, a check that reports success without checking, a claim in a PR body that nobody verified.

## Merge Strategy

Squash merge only, and only after all three gates are green:

```bash
mise run ci                              # Gate 1: local, already green before the last commit
gh pr checks <number>                    # Gate 2: remote (GitHub)
glab ci status --branch <branch>         # Gate 2: remote (GitLab)
# Gate 3: adversarial review reported, findings addressed or answered
# Merge authorization: see "Merge authorization" above for the full read set
gh pr view <number> --json headRefOid,baseRefName,isCrossRepository,mergeStateStatus,mergeable,statusCheckRollup,reviews,comments,autoMergeRequest
gh pr merge <number> --squash --match-head-commit <headRefOid>               # GitHub
glab mr merge <number> --squash --yes --auto-merge=false --sha <headRefOid>  # GitLab
```

Never use regular merge or rebase merge for PRs or MRs. Squash merge keeps main history clean with one commit per PR.

**Deferred-firing and bypass paths.** A merge that fires later is a merge nobody authorized at the moment it happened, against forge state nobody read. `glab mr merge`'s `--auto-merge` defaults to true, so an unset flag queues one — always pass `--auto-merge=false`. `gh pr merge --auto` queues the same way. `gh pr merge --admin` bypasses branch requirements and a merge queue. On a repo with a merge queue, plain `gh pr merge` adds the PR to the queue rather than merging it (`gh pr merge --help`, gh 2.93.0). Detect the queue and wait; never queue.

## Branch Naming

```
<type>/<description>
<type>/<issue-number>-<description>
```

**Examples:** `feature/user-authentication`, `fix/456-null-pointer-error`, `chore/update-dependencies`

Branch naming is platform-agnostic — identical on GitHub and GitLab. So are the Three-Gate Merge Policy and Key Rules; only the CLI verbs change.

## Remote and Authentication Conventions

### SSH-form remote URLs for operations

Use SSH-form remote URLs (`git@github.com:<owner>/<repo>.git`, or `git@gitlab.com:<group>/<project>.git` on GitLab), not HTTPS, for any worker that performs `git push`, `git fetch`, or other operations. SSH key-based auth bypasses OAuth scope checks that HTTPS push enforces, so it works reliably across container hosts and CI runners that do not carry GitHub-aware credential helpers.

```bash
# Convert an https remote to ssh form
git remote set-url origin git@github.com:<owner>/<repo>.git
git remote set-url origin git@gitlab.com:<group>/<project>.git
```

### No git worktrees for agent isolation

Do not use `git worktree add` to create isolated workspaces for parallel agents. Worktrees share the parent repository's object database and branch lock; concurrent operations across worktrees corrupt the index and break checkouts.

Use one of these instead:
- **Shallow clone**: `git clone --depth 50 --reference /<canonical-path>/<repo> --dissociate /tmp/agent-<id>/<repo>` — separate object DB, fast.
- **Plain `cp -R`**: of the canonical clone into a temp dir — slower but no shared state at all.

### GitHub Releases on private repositories require authentication

Anonymous `curl` against `https://github.com/<owner>/<repo>/releases/...` for a PRIVATE repository returns HTTP 404, not 401. Always authenticate (`gh auth login` or `Authorization: token <gh-token>` header) before fetching release assets from a private repo. Anonymous-first probes silently report "not found" when the real problem is "not authenticated".

### Layered GitHub authentication

Prefer the layered auth chain over a single static `GITHUB_TOKEN` env var:

1. `gh` keychain (primary on operator boxes — `gh auth login`).
2. Scoped Personal Access Tokens for unattended hosts (containers, CI runners), with the minimum scopes the workflow needs.
3. Per-node OAuth for federated deployments.

A single `GITHUB_TOKEN` env var blanket-deployed across hosts loses scope granularity and rotation independence. Use `gh auth refresh -h github.com -s workflow` to add the `workflow` scope when CI scripts need it.

GitLab's entry point is `glab auth login` (`--hostname` for self-managed instances, `--stdin` for CI token input, `--job-token` in CI) — the same layering principle applies: keyring first, scoped token for unattended hosts.

### Prefer git-backed substrate

Default to git-backed designs (local, private, or GitHub) for any system that needs an audit trail, replicability, or merge semantics. Git provides commit-level history, signature verification, hooks, and a uniform protocol across local files, private servers, and public hosts. Build atop git before introducing a new storage layer.

## GitHub PR Commands

```bash
gh pr create --title "type(scope): description" --body "- change 1"
gh pr create --draft                    # Draft PR
gh pr list                              # List PRs
gh pr view 123                          # View PR
gh pr checkout 123                      # Checkout PR locally
gh pr merge 123 --squash                # Squash merge PR — see "Merge authorization" for the pinned form required at merge time
```

## GitLab MR Commands

Same workflow, different verbs. `glab` mirrors `gh`'s shape, including the `-R, --repo` global flag. Flag detail, auth, and the surfaces this skill deliberately does not model are in [gitlab-mr.md](references/gitlab-mr.md).

| Action | GitHub | GitLab |
|--------|--------|--------|
| Create | `gh pr create --title "..." --body "..."` | `glab mr create --title "..." --description "..."` |
| Draft | `gh pr create --draft` | `glab mr create --draft` |
| List | `gh pr list` | `glab mr list` |
| View | `gh pr view 123` | `glab mr view 123` |
| View with comments | `gh pr view 123 --comments` | `glab mr view 123 --comments` |
| Checkout | `gh pr checkout 123` | `glab mr checkout 123` |
| Comment (Gate 3 record) | `gh pr comment 123 --body "..."` | `glab mr note create 123 -m "..."` |
| CI status (Gate 2) | `gh pr checks 123` | `glab ci status --branch <branch>` |
| Watch CI | `gh pr checks --watch` | `glab ci status --live` |
| Squash-merge | `gh pr merge 123 --squash` | `glab mr merge 123 --squash --yes --auto-merge=false` |
| Authenticate | `gh auth login` | `glab auth login` |

`gh pr checks` is scoped to the PR; `glab ci status` is scoped to a branch (current branch by default). They are not interchangeable at Gate 2 — on GitLab, confirm the branch being checked is the MR's actual source branch before trusting the result.

The squash-merge row above shows the bare command for reference. Never run it unpinned — see "Merge authorization" for the required `--match-head-commit` / `--sha` form.

## Key Rules

- **No attribution**: Never add `Co-Authored-By`, `Signed-off-by`, or similar to commits. No "Generated with Claude Code" or similar in PRs
- **Squash merge PRs**: Always use `gh pr merge --squash`
- **Single-line commits preferred**: Use body only when explanation is needed
- **Merge per policy**: Under the default, wait for the user; never queue a deferred merge — see "Merge authorization"
- **Clean up after merge**: Delete branches locally and remotely
- **Use gcms**: Generate commit messages with `/core:gcms` skill

## References

For detailed command references and advanced topics, see:

- **[commands.md](references/commands.md)** — Branch management, staging, committing, viewing changes, stashing, remote operations, tags, aliases
- **[gitlab-mr.md](references/gitlab-mr.md)** — GitLab MR equivalents in full: `glab` flag detail for create/view/note/merge, `glab ci status` vs `gh pr checks` scoping, `glab auth login`, and the GitLab-only surfaces this skill deliberately does not model
- **[advanced.md](references/advanced.md)** — Rebasing, merge strategies, conflict resolution, interactive rebase, history management, cherry-picking, bisect, submodules
- **[troubleshooting.md](references/troubleshooting.md)** — Common issues (wrong branch, sensitive data, recover deleted branch, bad merge) and best practices
- **[shallow-clone-remotes.md](references/shallow-clone-remotes.md)** — When `origin` is a file-based local clone: add `github` remote, push there, verify with `gh api`
- **[build-source-staleness.md](references/build-source-staleness.md)** — Before submitting a build chain that clones from a local source cache: `git pull` not `git fetch`. Verify via `git rev-parse HEAD`, not `git rev-parse origin/<branch>`

`shallow-clone-remotes.md` and `build-source-staleness.md` are one family of bugs — a file-based git remote silently absorbing an operation that should have reached (or read from) GitHub — covering the push side and the read side respectively. Read both when a git chain touches a local source cache or a shallow clone.
