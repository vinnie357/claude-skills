---
name: security
description: Secret detection and credential scanning using gitleaks. Use when scanning repositories for leaked secrets, API keys, passwords, tokens, or implementing pre-commit security checks.
license: MIT
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./hooks/check-secrets-before-commit.sh"
          timeout: 120
---

# Security: Secret Detection

This skill activates when performing secret detection, credential scanning, or implementing security checks for leaked sensitive data in code repositories.

## When to Use This Skill

Activate when:
- Scanning repositories for leaked secrets, API keys, or credentials
- Setting up pre-commit hooks for secret detection
- Auditing codebases for exposed passwords or tokens
- Implementing CI/CD security pipelines
- Checking git history for accidentally committed secrets
- Validating that .gitignore excludes sensitive files

## Pre-Commit Hook (Automatic)

When this skill is loaded, a pre-commit hook automatically scans staged files for secrets before every `git commit` command. This provides defense-in-depth by catching secrets before they enter git history.

### Hook Behavior

```
git commit -m "message"
         ↓
PreToolUse hook fires
         ↓
Extract staged files
         ↓
Run gitleaks --no-git
         ↓
    ┌─ Clean ─┴─ Secrets ─┐
    ↓                     ↓
  Allow               Block commit
  commit              (exit code 2)
```

### What Gets Scanned

- Only **staged files** are scanned (not the entire working tree)
- Uses `.gitleaks-baseline.json` if present to ignore known false positives
- Uses `.gitleaks.toml` if present for custom detection rules

### When Secrets Are Detected

If the hook detects secrets, the commit is blocked with guidance:

```
[gitleaks] SECRETS DETECTED in staged files!
[gitleaks] Commit blocked. Remove secrets before committing.
[gitleaks]
[gitleaks] Options:
[gitleaks]   1. Remove the secret from the file
[gitleaks]   2. Use environment variables instead
[gitleaks]   3. Add to .gitleaks-baseline.json if false positive
```

### Container Runtime Requirements

The hook requires a container runtime to run gitleaks. It auto-detects:
1. **Apple Container** (macOS 26+)
2. **Docker** (Docker Desktop or Engine)
3. **Colima** via mise

If no runtime is available, the hook logs a warning and allows the commit.

## When to Use security-review Instead

Use the `security-review` skill for:
- STRIDE threat modeling
- Security architecture reviews
- Vulnerability assessments
- Security documentation and reports
- Risk prioritization
- Attack surface analysis

| Task | Use `security` | Use `security-review` |
|------|---------------|----------------------|
| Scan for secrets in code | ✓ | |
| Detect leaked API keys | ✓ | |
| Pre-commit secret scanning | ✓ | |
| STRIDE threat modeling | | ✓ |
| Security architecture review | | ✓ |
| Vulnerability assessment | | ✓ |
| Security report documentation | | ✓ |
| Risk prioritization | | ✓ |

## Gitleaks

Gitleaks is an open-source tool for detecting secrets and sensitive information in git repositories. It scans commit history and file contents for patterns matching known secret formats.

### Common Secrets Detected

- AWS Access Keys and Secret Keys
- Google Cloud API Keys
- GitHub Personal Access Tokens
- Private Keys (RSA, SSH, PGP)
- Database Connection Strings
- JWT Tokens
- Stripe API Keys
- Slack Tokens
- Generic Passwords and API Keys

### Basic Usage

```bash
# Scan current directory
gitleaks detect --source="." -v

# Scan with JSON report
gitleaks detect --source="." -v --report-path=report.json --report-format=json

# Scan only staged changes (pre-commit)
gitleaks protect --staged

# Scan git history
gitleaks detect --source="." --log-opts="--all"
```

### Configuration

Create a `.gitleaks.toml` file to customize detection:

```toml
[extend]
# Extend default rules
useDefault = true

[[rules]]
id = "custom-api-key"
description = "Custom API Key Pattern"
regex = '''(?i)custom[_-]?api[_-]?key['\"]?\s*[=:]\s*['\"]([a-zA-Z0-9]{32,})'''
keywords = ["custom_api_key", "custom-api-key"]

[allowlist]
paths = [
  '''\.gitleaks\.toml$''',
  '''(.*)?test(.*)''',
  '''\.git'''
]

regexes = [
  '''EXAMPLE_.*''',
  '''REDACTED'''
]
```

### Exit Codes

- `0`: No leaks found
- `1`: Leaks detected
- Other: Configuration or runtime error

## Scripts

This skill includes scripts for running gitleaks with automatic container runtime detection.

### gitleaks.nu (Nushell)

Cross-platform Nushell script with automatic runtime detection:

```bash
# Run with auto-detected runtime
nu scripts/gitleaks.nu

# Specify runtime
nu scripts/gitleaks.nu --runtime docker
nu scripts/gitleaks.nu --runtime container  # Apple Container (macOS 26+)
nu scripts/gitleaks.nu --runtime colima

# Generate report
nu scripts/gitleaks.nu --report ./report.json

# Use custom config
nu scripts/gitleaks.nu --config ./.gitleaks.toml

# Scan specific path
nu scripts/gitleaks.nu --path ./src
```

### gitleaks.sh (Bash)

Bash script with the same capabilities:

```bash
# Run with auto-detected runtime
./scripts/gitleaks.sh

# Specify runtime
./scripts/gitleaks.sh --runtime docker
./scripts/gitleaks.sh -R container

# Generate report
./scripts/gitleaks.sh --report ./report.json

# Use custom config
./scripts/gitleaks.sh --config ./.gitleaks.toml
```

## Container Runtimes

The scripts support three container runtimes with automatic detection:

### Detection Priority

1. **Apple Container** (macOS 26+) - Native macOS containerization
2. **Docker** - Docker Desktop or Docker Engine
3. **Colima** - Lightweight container runtime via mise

### Apple Container (macOS 26+)

Native container support in macOS 26 and later:

```bash
# Check status
container system status

# Start runtime
container system start

# Run gitleaks
container run -v $(pwd):/code zricethezav/gitleaks detect --source="/code" -v
```

### Docker

Docker Desktop or Docker Engine:

```bash
# Check status
docker info >/dev/null 2>&1

# Start (macOS)
open -a Docker

# Run gitleaks
docker run -v $(pwd):/code zricethezav/gitleaks detect --source="/code" -v
```

### Colima via mise

Lightweight runtime managed through mise:

```bash
# Check status
mise exec colima@latest -- colima status

# Start runtime
mise exec colima@latest -- colima start

# Run gitleaks
mise exec colima@latest -- docker run -v $(pwd):/code zricethezav/gitleaks detect --source="/code" -v
```

Using `mise exec` provides automatic installation and version management without requiring global installation.

## Pre-Commit Integration

Add gitleaks to pre-commit hooks:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
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
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### GitLab CI

```yaml
gitleaks:
  stage: security
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source="." -v
  allow_failure: false
```

## Baseline Management

Create a baseline to ignore known false positives:

```bash
# Generate baseline
gitleaks detect --source="." -v --baseline-path=.gitleaks-baseline.json

# Scan using baseline
gitleaks detect --source="." -v --baseline-path=.gitleaks-baseline.json
```

Add `.gitleaks-baseline.json` to version control to track acknowledged findings.

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

## Mise Tasks Template

Copy the mise tasks from `templates/mise.toml` to add gitleaks scanning to any project:

```bash
# Available tasks after copying template
mise gitleaks              # Scan with Apple Container (default)
mise gitleaks:docker       # Scan with Docker
mise gitleaks:colima       # Scan with Colima

mise gitleaks:stop         # Stop all runtimes
mise gitleaks:stop:container
mise gitleaks:stop:docker
mise gitleaks:stop:colima
```

The tasks automatically:
- Detect and use `.gitleaks-baseline.json` if present
- Start the container runtime if not running
- Scan the repository root

## Key Principles

- **Defense in depth**: Run checks at multiple stages (local, CI, scheduled)
- **Fail fast**: Block PRs with detected secrets
- **Zero tolerance**: Treat all secret exposures as security incidents
- **Continuous monitoring**: Schedule regular scans of entire history
- **Clear ownership**: Define who handles secret remediation
