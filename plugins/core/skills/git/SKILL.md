---
name: git-operations
description: Guide for Git operations including commits, branches, rebasing, and conflict resolution. Use when working with version control, creating commits, managing branches, or resolving merge conflicts.
---

# Git Operations

Activate when creating commits, managing branches, creating pull requests, resolving conflicts, or following Git workflows.

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

1. **Local CI**: `mise run ci` — fix until 0 failures
2. **Commit**: Conventional commit, no attribution
3. **Gitleaks**: Scan committed changes for secrets (`/core:security`)
4. **Push**: `git push -u origin <branch>`
5. **Create PR**: `gh pr create` with minimal format (title + bullets)
6. **Watch CI**: `gh pr checks --watch` (wait for CI to complete)
7. **After CI passes** (if using bees):
   - `bees close <task-id>`
   - `git add .bees/ && git commit -m "chore(bees): close <task-id>"`
   - `git push`
8. **Notify**: "CI passed, PR ready for merge review"
9. **Cleanup** (after user merges):
   - `git checkout main && git pull`
   - `git branch -d <branch>`
10. **Continue**: `bees ready` for next task

## Merge Strategy

Always squash merge PRs:

```bash
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
