# Advanced Git Operations

## Rebasing Feature Branch

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

## Interactive Rebase

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

## Viewing History

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

## Undoing Changes

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

## Cherry-Picking

Apply specific commits to current branch:

```bash
# Apply single commit
git cherry-pick abc123

# Apply multiple commits
git cherry-pick abc123 def456

# Cherry-pick without committing
git cherry-pick -n abc123
```

## Bisect

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

## Submodules

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
