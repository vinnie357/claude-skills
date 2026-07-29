---
name: act
description: Test GitHub Actions locally using act. Use when debugging workflows locally, testing workflow changes before pushing, or troubleshooting action failures.
---

# act - Local GitHub Actions Testing

Activate when testing GitHub Actions workflows locally, debugging workflow issues, or developing actions without committing to remote repositories. This skill covers act installation, configuration, and usage patterns.

## When to Use This Skill

Activate when:
- Testing workflow changes before committing
- Debugging workflow failures locally
- Developing new workflows iteratively
- Validating workflow syntax and logic
- Testing actions with different events
- Running workflows without GitHub runners
- Troubleshooting act-specific issues

## Installation

Install via mise: `mise install act` (pinned in the github plugin's mise.toml), then verify with `act --version`. Homebrew, Linux script, source, and Chocolatey methods: see `references/setup-and-config.md`.

## How act Works

act reads workflow files from `.github/workflows/` and:
1. Determines which actions and jobs to execute
2. Pulls or builds required Docker images
3. Creates containers matching GitHub's runner environment
4. Executes steps in isolated containers
5. Provides output matching GitHub Actions format

**Key Concept:** act uses Docker to simulate GitHub's runner environment locally.

## Prerequisites

act requires a running Docker daemon (verify with `docker ps`) and valid `.github/workflows/*.yml` files. Details: see `references/setup-and-config.md`.

## Basic Usage

### List Available Workflows

```bash
# List all workflows
act -l

# Output:
# Stage  Job ID  Job name  Workflow name  Workflow file  Events
# 0      build   build     CI             ci.yml         push,pull_request
# 0      test    test      CI             ci.yml         push,pull_request
```

### Run Default Event (push)

```bash
# Run all jobs triggered by push event
act

# Run specific job
act -j build

# Run specific workflow
act -W .github/workflows/ci.yml
```

### Run Specific Events

```bash
# Pull request event
act pull_request

# Manual workflow dispatch
act workflow_dispatch

# Push to specific branch
act push -e .github/workflows/push-event.json

# Schedule event
act schedule
```

### Dry Run

```bash
# Show what would run without executing
act -n

# Show with full details
act -n -v
```

## Event Payloads

Custom event JSON and `workflow_dispatch` input payloads, passed with `-e file.json`: see `references/setup-and-config.md`. A worked PR-event example stays under Common Patterns below.

## Secrets Management

### Via Command Line

```bash
# Single secret
act -s GITHUB_TOKEN=ghp_xxxxx

# Multiple secrets
act -s API_KEY=key123 -s DB_PASSWORD=pass456
```

### Via .secrets File

Create `.secrets` file (add to .gitignore):
```
GITHUB_TOKEN=ghp_xxxxx
API_KEY=key123
DB_PASSWORD=pass456
```

Run with secrets file:
```bash
act --secret-file .secrets
```

### Environment Variables

```bash
# Use existing env var
act -s GITHUB_TOKEN

# Set from command
export MY_SECRET=value
act -s MY_SECRET
```

## Configuration

`.actrc` defaults, custom runner images, and image size trade-offs (medium `catthehacker/ubuntu:act-latest` recommended over micro): see `references/setup-and-config.md`.

## Environment Variables

### Via .env File

Create `.env` file:
```
NODE_ENV=test
API_URL=http://localhost:3000
LOG_LEVEL=debug
```

Use with act:
```bash
act --env-file .env
```

### Via Command Line

```bash
act --env NODE_ENV=test --env API_URL=http://localhost:3000
```

## Advanced Usage

`--bind`, `--reuse`, per-platform images, `--container-architecture` (needed on Apple silicon), networking (`--network` defaults to host; `--container-daemon-socket` is the Docker socket URI), and the artifact server: see `references/setup-and-config.md`.

## Debugging

### Verbose Output

```bash
# Verbose logging
act -v

# Very verbose (debug level)
act -vv
```

### Watch Mode

```bash
# Watch for file changes and re-run
act --watch
```

### Container Inspection

```bash
# List act containers
docker ps -a | grep act

# Inspect specific container
docker inspect <container-id>

# View logs
docker logs <container-id>
```

## Limitations and Differences

### Not Supported by act

- Some GitHub-hosted runner features
- GitHub Apps and installations
- OIDC token generation
- Some GitHub API interactions
- Certain cache implementations
- Job summaries and annotations (limited)

### Workarounds

**Missing tools:**
```yaml
steps:
  - name: Install missing tool
    run: |
      if ! command -v tool &> /dev/null; then
        apt-get update && apt-get install -y tool
      fi
```

**GitHub API calls:**
```yaml
# Use GITHUB_TOKEN from secrets
- env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: gh api repos/${{ github.repository }}/issues
```

## Common Patterns

### Testing Pull Request Workflow

```bash
# Create PR event payload
cat > pr-event.json << EOF
{
  "pull_request": {
    "number": 1,
    "head": { "ref": "feature" },
    "base": { "ref": "main" }
  }
}
EOF

# Run PR workflow
act pull_request -e pr-event.json -j test
```

### CI/CD Pipeline Testing

```bash
# Test entire CI pipeline
act push

# Test specific stages
act push -j build
act push -j test
act push -j deploy --secret-file .secrets
```

### Matrix Testing

```bash
# Run matrix strategy locally
act -j test

# Test specific matrix combination (modify workflow temporarily)
act -j test --matrix node-version:24
```

### Workflow Development Cycle

```bash
# 1. List jobs
act -l

# 2. Dry run
act -n -j build

# 3. Run with verbose output
act -v -j build

# 4. Iterate and test
act --reuse -j build
```

## Troubleshooting

### Docker Issues

**Error: Cannot connect to Docker daemon**
```bash
# Start Docker
# macOS: Start Docker Desktop
# Linux:
sudo systemctl start docker
```

**Error: Permission denied**
```bash
# Add user to docker group (Linux)
sudo usermod -aG docker $USER
newgrp docker
```

### Image Pull Issues

**Error: Failed to pull image**
```bash
# Use specific image version
act -P ubuntu-latest=ubuntu:22.04

# Or use act's recommended images
act -P ubuntu-latest=catthehacker/ubuntu:act-latest
```

### Workflow Not Found

**Error: No workflows found**
```bash
# Verify workflow files exist
ls -la .github/workflows/

# Check workflow syntax
act -n -v
```

### Secret Issues

**Error: Secret not found**
```bash
# List required secrets from workflow
grep -r "secrets\." .github/workflows/

# Provide via command line
act -s SECRET_NAME=value

# Or use secrets file
act --secret-file .secrets
```

### Action Failures

**Error: Action not found or fails**
```yaml
# Ensure action versions are compatible
# Some actions may not work locally

# Use alternative actions if needed
# Or skip problematic steps under act. There is no 'act' event — act passes
# the real event name — so test the ACT env var (per nektos/act docs):
- name: Problematic step
  if: ${{ !env.ACT }}
  uses: some/action@v1
```

### Platform Differences

**Error: Command not found**
```bash
# Use medium-sized images with more tools
act -P ubuntu-latest=catthehacker/ubuntu:act-latest

# Or install tools in workflow
- run: apt-get update && apt-get install -y <tool>
```

## Best Practices

### .actrc Configuration

Commit an `.actrc` so every run gets the same platform image, secrets file, and architecture flags — full example in `references/setup-and-config.md`.

### .gitignore Entries

```gitignore
# act secrets and config
.secrets
.env

# act artifacts
/tmp/artifacts/
```

### Conditional Logic for Local Testing

act sets the `ACT` environment variable inside its containers — per nektos/act docs, which give this exact `!env.ACT` form. The event name is whatever you invoke (`act pull_request` runs as `pull_request`; a bare `act` runs as `push`), so there is no `act` event to test for:

```yaml
steps:
  # Skip in local testing
  - name: Deploy
    if: ${{ !env.ACT }}
    run: ./deploy.sh

  # Run only in local testing
  - name: Local setup
    if: ${{ env.ACT }}
    run: ./local-setup.sh
```

### Fast Feedback Loop

```bash
# Use reuse flag for faster iterations
act --reuse -j test

# Run specific job being developed
act -j my-new-job -v

# Watch mode for continuous testing
act --watch -j test
```

## Integration with Development Workflow

### Pre-commit Testing

```bash
# Test before committing
act -j test && git commit -m "message"

# Git hook (.git/hooks/pre-commit)
#!/bin/bash
act -j test --quiet
```

For quick validation use the dry run (`act -n`, see Basic Usage). For CI parity, pin the same runner images and secrets structure locally via `.actrc` — see `references/setup-and-config.md`.

## Scripts and Automation

### Installation Script

The plugin includes an installation script at `scripts/install-act.nu` (nushell). It installs act via mise when available, falling back to Homebrew on macOS, the nektos/act install script on Linux, or Chocolatey on Windows, then verifies the install with `act --version`.

Run with:
```bash
nu scripts/install-act.nu
```

## Anti-Fabrication Requirements

- Execute `act --version` before documenting version numbers
- Use `act -l` to verify actual workflows before claiming their presence
- Execute `docker ps` to confirm Docker is running before troubleshooting
- Run `act -n` to validate workflow syntax before claiming correctness
- Execute actual `act` commands to verify behavior before documenting output format
- Use `docker images` to verify available images before recommending specific versions
- Never claim success rates or performance metrics without actual measurement
- Execute `act -v` to observe actual error messages before documenting troubleshooting steps
- Use Read tool to verify workflow files exist before testing them with act
- Run actual event payloads through act before claiming they work correctly

## References

- `references/setup-and-config.md` — installation methods, prerequisites, `.actrc` configuration, runner images, event payloads, and advanced flags (`--bind`, `--reuse`, networking, artifact server)
