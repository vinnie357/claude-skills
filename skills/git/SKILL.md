---
name: git-operations
description: Guide for Git operations including commits, branches, rebasing, conflict resolution, and following Git best practices and conventional commits
---

# Git Operations and Best Practices

This skill activates when performing Git operations, managing repositories, resolving conflicts, or following Git workflows and conventions.

## When to Use This Skill

Activate when:
- Creating commits or commit messages
- Managing branches and merging
- Resolving merge conflicts
- Rebasing or rewriting history
- Creating pull requests
- Following Git workflows (Git Flow, GitHub Flow, trunk-based)
- Troubleshooting Git issues

## Commit Message Conventions

### Conventional Commits

Follow the Conventional Commits specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring without changing behavior
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `build`: Changes to build system or dependencies
- `ci`: CI/CD configuration changes
- `chore`: Other changes that don't modify src or test files
- `revert`: Revert a previous commit

**Examples:**
```
feat(auth): add JWT authentication

Implement JWT-based authentication with refresh tokens.
- Add JWT generation and validation
- Implement refresh token rotation
- Add authentication middleware

Closes #123

fix(api): handle null values in user response

Previously, null email addresses would cause the API to crash.
Now returns empty string for null emails.

Fixes #456

docs: update installation instructions

Add section on environment variable configuration.

test(user): add tests for email validation

refactor(database): simplify query builder

perf(api): add caching for user endpoints

Reduces response time by 40% for user list endpoint.
```

### Writing Good Commit Messages

**Subject line (first line):**
- Keep under 50 characters
- Start with lowercase (after type)
- No period at the end
- Use imperative mood ("add" not "added" or "adds")

**Body:**
- Wrap at 72 characters
- Explain what and why, not how
- Separate from subject with blank line
- Can have multiple paragraphs

**Footer:**
- Reference issues and pull requests
- Note breaking changes
- Add co-authors

```
feat(api): add user search endpoint

Implement full-text search across user names and emails using
PostgreSQL's full-text search capabilities. Search results are
ranked by relevance.

Performance tested with 1M users - average response time < 100ms.

BREAKING CHANGE: API now requires PostgreSQL 12+

Closes #789
Co-authored-by: Jane Doe <jane@example.com>
```

## Branch Management

### Branch Naming

Use descriptive, hierarchical branch names:

```
<type>/<short-description>
<type>/<issue-number>-<short-description>
```

**Examples:**
```
feature/user-authentication
feature/123-add-search
fix/456-null-pointer-error
bugfix/password-reset-email
hotfix/critical-security-patch
refactor/database-queries
docs/api-documentation
chore/update-dependencies
```

### Creating and Switching Branches

```bash
# Create and switch to new branch
git checkout -b feature/new-feature

# Switch to existing branch
git checkout main
git switch main  # Modern alternative

# Create branch from specific commit
git checkout -b hotfix/bug origin/main

# List branches
git branch                    # Local branches
git branch -r                 # Remote branches
git branch -a                 # All branches
git branch -v                 # With last commit
```

### Deleting Branches

```bash
# Delete local branch
git branch -d feature/completed-feature

# Force delete unmerged branch
git branch -D feature/abandoned-feature

# Delete remote branch
git push origin --delete feature/old-feature
```

## Working with Changes

### Staging Changes

```bash
# Stage specific files
git add file1.ex file2.ex

# Stage all changes
git add .
git add -A

# Stage parts of a file (interactive)
git add -p file.ex

# Unstage files
git restore --staged file.ex
git reset HEAD file.ex  # Old syntax
```

### Committing

```bash
# Commit staged changes
git commit -m "feat: add user authentication"

# Commit with body
git commit -m "feat: add user authentication" -m "Implement JWT-based auth with refresh tokens"

# Amend last commit (change message or add files)
git add forgotten-file.ex
git commit --amend

# Amend without changing message
git commit --amend --no-edit
```

### Viewing Changes

```bash
# Show unstaged changes
git diff

# Show staged changes
git diff --cached
git diff --staged

# Show changes in specific file
git diff path/to/file.ex

# Show changes between branches
git diff main..feature/new-feature

# Show changes between commits
git diff abc123..def456

# Show stats only
git diff --stat
```

## Branching Workflows

### Feature Branch Workflow

```bash
# Start new feature
git checkout main
git pull origin main
git checkout -b feature/new-feature

# Work on feature
git add .
git commit -m "feat: implement new feature"

# Keep feature updated with main
git checkout main
git pull origin main
git checkout feature/new-feature
git merge main

# Push feature
git push -u origin feature/new-feature

# After PR is merged, clean up
git checkout main
git pull origin main
git branch -d feature/new-feature
```

### Rebasing Feature Branch

```bash
# Keep feature branch up-to-date with clean history
git checkout feature/new-feature
git fetch origin
git rebase origin/main

# If conflicts occur, resolve them, then:
git add resolved-file.ex
git rebase --continue

# Abort rebase if needed
git rebase --abort

# Force push after rebase (careful!)
git push --force-with-lease origin feature/new-feature
```

## Merge Strategies

### Fast-Forward Merge

```bash
# Default when possible - no merge commit
git checkout main
git merge feature/simple-feature
```

### No Fast-Forward

```bash
# Always create merge commit for history
git merge --no-ff feature/important-feature
```

### Squash Merge

```bash
# Combine all feature commits into one
git merge --squash feature/many-small-commits
git commit -m "feat: add complete feature"
```

## Conflict Resolution

### Identifying Conflicts

```bash
# See conflicted files
git status

# See conflict markers in file
# <<<<<<< HEAD
# Current branch changes
# =======
# Incoming changes
# >>>>>>> feature/branch
```

### Resolving Conflicts

```bash
# Edit files to resolve conflicts, then:
git add resolved-file.ex
git commit  # Or git rebase --continue if rebasing

# Use merge tools
git mergetool

# Choose one side completely
git checkout --ours file.ex    # Keep our version
git checkout --theirs file.ex  # Keep their version
```

### Aborting Merge/Rebase

```bash
# Abort merge
git merge --abort

# Abort rebase
git rebase --abort
```

## History Management

### Interactive Rebase

Clean up commit history before merging:

```bash
# Rebase last 3 commits
git rebase -i HEAD~3

# Rebase since main
git rebase -i main

# Interactive rebase options:
# pick - keep commit as-is
# reword - change commit message
# edit - modify commit
# squash - combine with previous commit
# fixup - like squash but discard message
# drop - remove commit
```

**Example workflow:**
```bash
# You have commits:
# abc123 fix typo
# def456 add feature
# ghi789 fix bug in feature
# jkl012 add tests

git rebase -i HEAD~4

# Change to:
# pick def456 add feature
# fixup ghi789 fix bug in feature
# squash jkl012 add tests
# reword abc123 fix typo
```

### Viewing History

```bash
# View commit history
git log

# Compact one-line format
git log --oneline

# Graph view
git log --graph --oneline --all

# With file changes
git log --stat

# Search commits
git log --grep="authentication"

# Commits by author
git log --author="John"

# Commits in date range
git log --since="2 weeks ago"
git log --after="2024-01-01" --before="2024-02-01"

# Follow file history
git log --follow -- path/to/file.ex

# Show specific commit
git show abc123
```

### Undoing Changes

```bash
# Undo uncommitted changes
git restore file.ex
git checkout -- file.ex  # Old syntax

# Restore all files
git restore .

# Undo commit (keep changes)
git reset --soft HEAD~1

# Undo commit (discard changes) - DANGEROUS
git reset --hard HEAD~1

# Create new commit that undoes a commit
git revert abc123

# Revert merge commit
git revert -m 1 abc123
```

## Stashing

Temporarily save uncommitted changes:

```bash
# Stash changes
git stash
git stash push -m "work in progress on feature"

# Stash including untracked files
git stash -u

# List stashes
git stash list

# Apply most recent stash
git stash apply

# Apply and remove stash
git stash pop

# Apply specific stash
git stash apply stash@{2}

# Delete stash
git stash drop stash@{0}

# Clear all stashes
git stash clear

# Create branch from stash
git stash branch feature/from-stash
```

## Remote Operations

### Working with Remotes

```bash
# View remotes
git remote -v

# Add remote
git remote add origin git@github.com:user/repo.git

# Change remote URL
git remote set-url origin git@github.com:user/new-repo.git

# Remove remote
git remote remove origin

# Rename remote
git remote rename origin upstream
```

### Fetching and Pulling

```bash
# Fetch changes from remote
git fetch origin

# Fetch all remotes
git fetch --all

# Pull changes (fetch + merge)
git pull origin main

# Pull with rebase
git pull --rebase origin main

# Set upstream branch
git push -u origin feature/new-feature
git branch --set-upstream-to=origin/feature feature/new-feature
```

### Pushing

```bash
# Push to remote
git push origin main

# Push and set upstream
git push -u origin feature/new-feature

# Force push (CAREFUL!)
git push --force origin feature/branch

# Safer force push - fails if remote has new commits
git push --force-with-lease origin feature/branch

# Push all branches
git push --all origin

# Push tags
git push --tags
```

## Tags

### Creating Tags

```bash
# Lightweight tag
git tag v1.0.0

# Annotated tag (preferred)
git tag -a v1.0.0 -m "Release version 1.0.0"

# Tag specific commit
git tag -a v1.0.0 abc123 -m "Release version 1.0.0"
```

### Managing Tags

```bash
# List tags
git tag
git tag -l "v1.*"

# View tag details
git show v1.0.0

# Push tag
git push origin v1.0.0

# Push all tags
git push origin --tags

# Delete local tag
git tag -d v1.0.0

# Delete remote tag
git push origin --delete v1.0.0
```

## Advanced Operations

### Cherry-Picking

Apply specific commits to current branch:

```bash
# Apply single commit
git cherry-pick abc123

# Apply multiple commits
git cherry-pick abc123 def456

# Cherry-pick without committing
git cherry-pick -n abc123
```

### Bisect

Find which commit introduced a bug:

```bash
# Start bisect
git bisect start
git bisect bad                    # Current commit is bad
git bisect good abc123            # Known good commit

# Git will checkout commits to test
# After testing each:
git bisect good  # or
git bisect bad

# When found, Git shows first bad commit
# Reset
git bisect reset
```

### Submodules

```bash
# Add submodule
git submodule add git@github.com:user/repo.git path/to/submodule

# Clone with submodules
git clone --recurse-submodules git@github.com:user/repo.git

# Update submodules
git submodule update --init --recursive

# Pull submodule updates
git submodule update --remote
```

## GitHub Specific

### Pull Requests

```bash
# Using GitHub CLI (gh)
gh pr create --title "feat: add new feature" --body "Description of changes"

# Create draft PR
gh pr create --draft

# List PRs
gh pr list

# View PR
gh pr view 123

# Checkout PR locally
gh pr checkout 123

# Merge PR
gh pr merge 123 --squash
```

### Issues

```bash
# Create issue
gh issue create --title "Bug: authentication fails" --body "Description"

# List issues
gh issue list

# View issue
gh issue view 123

# Close issue
gh issue close 123
```

## Git Aliases

Add to `.gitconfig`:

```ini
[alias]
    co = checkout
    br = branch
    ci = commit
    st = status
    unstage = restore --staged
    last = log -1 HEAD
    lg = log --graph --oneline --all
    cm = commit -m
    ca = commit --amend
    undo = reset --soft HEAD~1
    sync = !git fetch origin && git rebase origin/main
    clean-branches = !git branch --merged | grep -v \"\\*\" | xargs -n 1 git branch -d
```

## Best Practices

### Commits

- Make atomic commits - one logical change per commit
- Commit often - small, focused commits are better
- Write clear commit messages following conventions
- Don't commit sensitive data (API keys, passwords)
- Don't commit generated files (add to `.gitignore`)
- Test before committing

### Branches

- Keep branches short-lived
- Pull main/master frequently to stay updated
- Delete branches after merging
- Use descriptive branch names
- One feature/fix per branch

### History

- Keep history clean with interactive rebase
- Don't rewrite public history (after pushing)
- Use `--force-with-lease` instead of `--force`
- Squash small fixup commits before merging

### Collaboration

- Pull before pushing
- Resolve conflicts promptly
- Review changes before committing
- Communicate about force pushes
- Use pull requests for code review

## Common Issues and Solutions

### Accidentally Committed to Wrong Branch

```bash
# Move commit to new branch
git branch feature/new-branch
git reset --hard HEAD~1
git checkout feature/new-branch
```

### Need to Change Last Commit Message

```bash
git commit --amend
```

### Committed Sensitive Data

```bash
# Remove from history - CAREFUL!
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/sensitive-file" \
  --prune-empty --tag-name-filter cat -- --all

# Or use BFG Repo-Cleaner (faster)
bfg --delete-files sensitive-file
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push to update remote
git push --force --all
```

### Recover Deleted Branch

```bash
# Find commit where branch was
git reflog

# Recreate branch
git checkout -b recovered-branch abc123
```

### Merge Went Wrong

```bash
# Undo merge (before pushing)
git reset --hard HEAD~1

# Undo merge (after pushing)
git revert -m 1 merge-commit-hash
```

## Key Principles

- **Commit early, commit often**: Small, focused commits
- **Write clear messages**: Follow conventional commits
- **Keep history clean**: Rebase and squash before merging
- **Don't rewrite public history**: Only rebase local commits
- **Use branches**: Never commit directly to main
- **Pull before push**: Stay in sync with remote
- **Review before commit**: Check what you're committing
- **Use descriptive names**: For branches, commits, and PRs
