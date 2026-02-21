# Git Troubleshooting and Best Practices

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

## Best Practices

### Commits

- Make atomic commits — one logical change per commit
- Commit often — small, focused commits are better
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
