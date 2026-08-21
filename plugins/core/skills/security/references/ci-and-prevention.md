# CI and Prevention

Reference for wiring gitleaks into `pre-commit` and CI/CD pipelines outside this skill's own PreToolUse hook, and the general best-practice checklist for shift-left secret prevention and response.

## Pre-Commit Integration

Add gitleaks to pre-commit hooks:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
```

Install and run:

```bash
pre-commit install
pre-commit run gitleaks --all-files
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Gitleaks

on: [push, pull_request]

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - uses: gitleaks/gitleaks-action@v3
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### GitLab CI

```yaml
gitleaks:
  stage: security
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks git . -v
  allow_failure: false
```

## Best Practices

### Shift-Left Security

- Enable gitleaks in pre-commit hooks to catch secrets before they enter history
- Run scans on every PR in CI/CD pipelines
- Scan regularly even if not making changes

### When Secrets Are Found

1. **Revoke immediately** - Rotate the exposed credential
2. **Remove from history** - Use `git filter-branch` or BFG Repo Cleaner
3. **Add to .gitignore** - Prevent future commits of sensitive files
4. **Update baseline** - If false positive, add to baseline

### Prevention

- Use environment variables for secrets
- Use secret management tools (Vault, AWS Secrets Manager)
- Add secret patterns to `.gitignore`
- Configure IDE plugins to warn about secrets
- Use `.env.example` files without real values
