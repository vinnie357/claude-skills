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

Don't assert `git`/`gh` CLI or GitHub API behavior this skill doesn't already cover
without checking the current docs, or testing it directly when the docs don't say —
CLI flags and API responses do change across versions.

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

**NEVER include attribution** — no `Co-Authored-By`, `Signed-off-by`, or similar footers. This rule has no exceptions.

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

## PR Format

Title matches commit format. Body is a bullet list of changes only.

```bash
gh pr create --title "feat(auth): add JWT authentication" --body "- Add JWT generation and validation
- Implement refresh token rotation
- Add authentication middleware"
```

**Rules:**
- No attribution (no "Generated with Claude Code" or similar)
- No PR templates or boilerplate sections
- No "Summary", "Test Plan", or other headers
- Just the changes as bullet points
- Keep it minimal and scannable

## PR Workflow

1. **Gate 1 — Local CI**: `mise run ci` — fix until 0 failures
2. **Commit**: Conventional commit, no attribution
3. **Gitleaks**: Scan committed changes for secrets — `$(mise which gitleaks) git . --staged`, never a bare `gitleaks` (`/core:security`). The `check-secrets-before-commit.sh` PreToolUse hook backstops this on `git commit`, but only while `/core:security` is loaded (hooks are scoped to their own skill's lifecycle) and it fails open — allows the commit — when no scanner is available. Run the scan yourself; don't treat the hook as a substitute for it.
4. **Push**: `git push -u origin <branch>`
5. **Create PR**: `gh pr create` with minimal format (title + bullets)
6. **Gate 2 — Watch remote CI**: `gh pr checks --watch` (wait for CI to complete)
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
2. `gh pr checks` reports every remote check passing.

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
- **The verdict and each finding's disposition land as a durable record on the PR** — a PR comment, or a bees comment the PR links. Gates 1 and 2 have observables (`mise run ci` output, `gh pr checks`); Gate 3 needs one too, or "review done" is an unverifiable assertion of exactly the kind this gate exists to catch. Check it with `gh pr view <n> --comments`.

No `gh pr merge --squash` while any gate is red. The user approves the merge; agents never merge.

### Gate 3 is not the pipeline's review tier

`/core:agent-loop`'s five-tier pipeline has its own reviewers — P5 verifies tests exercise the acceptance criteria, the test-review stage checks for redundancy. Those judge whether the implementation meets **the issue's spec**.

Gate 3 runs **on the PR** and judges whether the change is defensible against someone trying to break it. Identify it by its brief, not its timing: no pipeline reviewer counts, even one that read the full PR diff — Forge's Final Reviewer does exactly that and is still not Gate 3. Gate 3 is the review carrying the defeat-the-change brief and the three standing focus areas, dispatched after the pipeline reports done.

### Why three gates and not two

Gates 1 and 2 prove the suite passes, not that the change is correct. A green build is evidence the tests ran, not evidence the work is right — and the defects worth catching here are the ones a passing suite cannot see: documentation that describes behaviour the code does not have, a check that reports success without checking, a claim in a PR body that nobody verified.

## Merge Strategy

Squash merge only, and only after all three gates are green:

```bash
mise run ci                    # Gate 1: local, already green before the last commit
gh pr checks <number>          # Gate 2: remote
# Gate 3: adversarial review reported, findings addressed or answered
gh pr merge <number> --squash
```

Never use regular merge or rebase merge for PRs. Squash merge keeps main history clean with one commit per PR.

## Branch Naming

```
<type>/<description>
<type>/<issue-number>-<description>
```

**Examples:** `feature/user-authentication`, `fix/456-null-pointer-error`, `chore/update-dependencies`

## Remote and Authentication Conventions

### SSH-form remote URLs for operations

Use SSH-form remote URLs (`git@github.com:<owner>/<repo>.git`), not HTTPS, for any worker that performs `git push`, `git fetch`, or other operations. SSH key-based auth bypasses OAuth scope checks that HTTPS push enforces, so it works reliably across container hosts and CI runners that do not carry GitHub-aware credential helpers.

```bash
# Convert an https remote to ssh form
git remote set-url origin git@github.com:<owner>/<repo>.git
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

### Prefer git-backed substrate

Default to git-backed designs (local, private, or GitHub) for any system that needs an audit trail, replicability, or merge semantics. Git provides commit-level history, signature verification, hooks, and a uniform protocol across local files, private servers, and public hosts. Build atop git before introducing a new storage layer.

## GitHub PR Commands

```bash
gh pr create --title "type(scope): description" --body "- change 1"
gh pr create --draft                    # Draft PR
gh pr list                              # List PRs
gh pr view 123                          # View PR
gh pr checkout 123                      # Checkout PR locally
gh pr merge 123 --squash                # Squash merge PR
```

## Key Rules

- **No attribution**: Never add `Co-Authored-By`, `Signed-off-by`, or similar to commits. No "Generated with Claude Code" or similar in PRs
- **Squash merge PRs**: Always use `gh pr merge --squash`
- **Single-line commits preferred**: Use body only when explanation is needed
- **Never merge without approval**: Always wait for user to approve PR merges
- **Clean up after merge**: Delete branches locally and remotely
- **Use gcms**: Generate commit messages with `/core:gcms` skill

## References

For detailed command references and advanced topics, see:

- **[commands.md](references/commands.md)** — Branch management, staging, committing, viewing changes, stashing, remote operations, tags, aliases
- **[advanced.md](references/advanced.md)** — Rebasing, merge strategies, conflict resolution, interactive rebase, history management, cherry-picking, bisect, submodules
- **[troubleshooting.md](references/troubleshooting.md)** — Common issues (wrong branch, sensitive data, recover deleted branch, bad merge) and best practices
- **[shallow-clone-remotes.md](references/shallow-clone-remotes.md)** — When `origin` is a file-based local clone: add `github` remote, push there, verify with `gh api`
- **[build-source-staleness.md](references/build-source-staleness.md)** — Before submitting a build chain that clones from a local source cache: `git pull` not `git fetch`. Verify via `git rev-parse HEAD`, not `git rev-parse origin/<branch>`

`shallow-clone-remotes.md` and `build-source-staleness.md` are one family of bugs — a file-based git remote silently absorbing an operation that should have reached (or read from) GitHub — covering the push side and the read side respectively. Read both when a git chain touches a local source cache or a shallow clone.
