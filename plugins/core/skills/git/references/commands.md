# Git Command Reference

## Creating and Switching Branches

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

## Deleting Branches

```bash
# Delete local branch
git branch -d feature/completed-feature

# Force delete unmerged branch
git branch -D feature/abandoned-feature

# Delete remote branch
git push origin --delete feature/old-feature
```

## Staging Changes

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

## Committing

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

## Viewing Changes

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
    clean-branches = !git branch --merged | grep -v "\\*" | xargs -n 1 git branch -d
```
