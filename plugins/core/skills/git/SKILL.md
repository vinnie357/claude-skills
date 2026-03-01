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

1. **Push**: `git push -u origin <branch>`
2. **Create PR**: `gh pr create` with minimal format (title + bullets)
3. **Watch CI**: `gh pr checks --watch` (wait for CI to complete)
4. **After CI passes** (if using beads):
   - `bd close <task-id>`
   - `git add .beads/ && git commit -m "chore(beads): close <task-id>"`
   - `git push`
5. **Notify user**: "CI passed, PR ready for merge review"
6. **Cleanup** (after user merges):
   - `git checkout main && git pull`
   - `git branch -d <branch>`
7. **Continue**: `bd ready` for next task

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
