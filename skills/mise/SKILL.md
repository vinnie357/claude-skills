---
name: mise
description: Guide for using mise (mise-en-place) to manage development tools, runtime versions, environment variables, and tasks across projects
---

# mise - Development Environment Management

This skill activates when working with mise for managing tool versions, environment variables, and project tasks.

## When to Use This Skill

Activate when:
- Setting up development environments
- Managing tool and runtime versions (Node.js, Python, Ruby, Go, etc.)
- Configuring environment variables and secrets
- Defining and running project tasks
- Creating reproducible development setups
- Working with monorepos or multiple projects

## What is mise?

mise is a polyglot runtime manager and development environment tool that combines:
- **Tool version management** - Install and manage multiple versions of dev tools
- **Environment configuration** - Set environment variables per project
- **Task automation** - Define and run project tasks
- **Cross-platform** - Works on macOS, Linux, and Windows

## Installation

```bash
# macOS/Linux (using curl)
curl https://mise.run | sh

# macOS (using Homebrew)
brew install mise

# Windows
# See https://mise.jdx.dev for Windows install instructions

# Activate mise in your shell
echo 'eval "$(mise activate bash)"' >> ~/.bashrc   # bash
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc     # zsh
echo 'mise activate fish | source' >> ~/.config/fish/config.fish  # fish
```

## Managing Tools

### Installing Tools

```bash
# List available tools
mise list-all

# Install specific version
mise install node@20.10.0
mise install python@3.12
mise install ruby@3.3

# Install latest version
mise install node@latest

# Install from .mise.toml or .tool-versions
mise install
```

### Setting Tool Versions

#### Global versions (all projects)

```bash
# Set global default
mise use --global node@20
mise use --global python@3.12
```

#### Local versions (current project)

```bash
# Set for current directory
mise use node@20.10.0
mise use python@3.12

# Creates .mise.toml or .tool-versions file
```

#### .mise.toml Configuration

```toml
[tools]
node = "20.10.0"
python = "3.12"
ruby = "3.3"
go = "1.21"

# Use latest version
terraform = "latest"

# Version from file
node = { version = "lts", resolve = "latest-lts" }
```

### Managing Installed Tools

```bash
# List installed tools
mise list

# List all versions of a tool
mise list node

# Uninstall a version
mise uninstall node@18.0.0

# Update all tools to latest
mise upgrade

# Update specific tool
mise upgrade node
```

### Tool Aliases

```bash
# Create alias for a tool
mise alias node 20 20.10.0

# Use alias
mise use node@20
```

## Environment Variables

### Setting Environment Variables

#### In .mise.toml

```toml
[env]
DATABASE_URL = "postgresql://localhost/myapp"
API_KEY = "development-key"
NODE_ENV = "development"

# Template values
APP_ROOT = "{{ config_root }}"
DATA_DIR = "{{ config_root }}/data"
```

#### File-based env vars

```toml
[env]
_.file = ".env"
_.path = ["/custom/bin"]
```

### Environment Templates

Use Go templates in environment variables:

```toml
[env]
PROJECT_ROOT = "{{ config_root }}"
LOG_FILE = "{{ config_root }}/logs/app.log"
PATH = ["{{ config_root }}/bin", "$PATH"]
```

### Secrets Management

```bash
# Use with sops
mise set SECRET_KEY sops://path/to/secret

# Use with age
mise set API_TOKEN age://path/to/secret

# Use from command
mise set BUILD_ID "$(git rev-parse HEAD)"
```

## Tasks

### Defining Tasks

#### In .mise.toml

```toml
[tasks.build]
description = "Build the project"
run = "npm run build"

[tasks.test]
description = "Run tests"
run = "npm test"

[tasks.lint]
description = "Run linter"
run = "npm run lint"
depends = ["build"]

[tasks.ci]
description = "Run CI pipeline"
depends = ["lint", "test"]

[tasks.dev]
description = "Start development server"
run = "npm run dev"
```

### Running Tasks

```bash
# Run a task
mise run build
mise run test

# Short form
mise build
mise test

# Run multiple tasks
mise run lint test

# List available tasks
mise tasks

# Run task with arguments
mise run script -- arg1 arg2
```

### Task Dependencies

```toml
[tasks.deploy]
depends = ["build", "test"]
run = "npm run deploy"

# Tasks run in order: build, test, then deploy
```

### Task Options

```toml
[tasks.build]
description = "Build the project"
run = "npm run build"
sources = ["src/**/*.ts"]      # Only run if sources changed
outputs = ["dist/**/*"]         # Check outputs for changes
dir = "frontend"                # Run in specific directory
env = { NODE_ENV = "production" }

[tasks.watch]
run = "npm run watch"
raw = true                      # Don't wrap in shell
```

### Task Files

Create separate task files:

```bash
# .mise/tasks/deploy
#!/bin/bash
# mise description="Deploy to production"
# mise depends=["build", "test"]

echo "Deploying..."
npm run deploy
```

Make executable:
```bash
chmod +x .mise/tasks/deploy
```

## Common Workflows

### Node.js Project Setup

```toml
# .mise.toml
[tools]
node = "20"

[env]
NODE_ENV = "development"

[tasks.install]
run = "npm install"

[tasks.dev]
run = "npm run dev"
depends = ["install"]

[tasks.build]
run = "npm run build"
depends = ["install"]

[tasks.test]
run = "npm test"
depends = ["install"]
```

```bash
# Setup and run
cd project
mise install      # Installs Node 20
mise dev         # Runs dev server
```

### Python Project Setup

```toml
# .mise.toml
[tools]
python = "3.12"

[env]
PYTHONPATH = "{{ config_root }}/src"

[tasks.venv]
run = "python -m venv .venv"

[tasks.install]
run = "pip install -r requirements.txt"
depends = ["venv"]

[tasks.test]
run = "pytest"
depends = ["install"]

[tasks.format]
run = "black src tests"
```

### Monorepo Setup

```toml
# Root .mise.toml
[tools]
node = "20"
python = "3.12"

[env]
WORKSPACE_ROOT = "{{ config_root }}"

[tasks.install-all]
run = """
npm install
cd services/api && npm install
cd services/web && npm install
"""

[tasks.test-all]
depends = ["install-all"]
run = """
mise run test --dir services/api
mise run test --dir services/web
"""
```

### Multi-Tool Project

```toml
# .mise.toml
[tools]
node = "20"
python = "3.12"
ruby = "3.3"
go = "1.21"
terraform = "latest"

[env]
PROJECT_ROOT = "{{ config_root }}"
PATH = ["{{ config_root }}/bin", "$PATH"]

[tasks.setup]
description = "Setup all dependencies"
run = """
npm install
pip install -r requirements.txt
bundle install
go mod download
"""
```

## Lock Files

Generate lock files for reproducible environments:

```bash
# Generate .mise.lock
mise lock

# Use locked versions
mise install --locked
```

```toml
# .mise.toml
[tools]
node = "20"

[settings]
lockfile = true  # Auto-generate lock file
```

## Shims

Use shims for tool binaries:

```bash
# Enable shims
mise settings set experimental true
mise reshim

# Now tools are in PATH via shims
node --version  # Uses mise-managed node
python --version  # Uses mise-managed python
```

## Configuration Locations

mise reads configuration from multiple locations (in order):

1. `.mise.toml` - Project local config
2. `.mise/config.toml` - Project local config (alternative)
3. `~/.config/mise/config.toml` - Global config
4. Environment variables - `MISE_*`

## IDE Integration

### VS Code

Add to `.vscode/settings.json`:

```json
{
  "terminal.integrated.env.linux": {
    "PATH": "${env:HOME}/.local/share/mise/shims:${env:PATH}"
  },
  "terminal.integrated.env.osx": {
    "PATH": "${env:HOME}/.local/share/mise/shims:${env:PATH}"
  }
}
```

### JetBrains IDEs

Use mise shims or configure tool paths:

```bash
# Find tool path
mise which node
mise which python
```

## CI/CD Integration

### GitHub Actions

```yaml
name: CI

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: jdx/mise-action@v2

      - name: Run tests
        run: mise run test
```

### GitLab CI

```yaml
test:
  image: ubuntu:latest
  before_script:
    - curl https://mise.run | sh
    - eval "$(mise activate bash)"
    - mise install
  script:
    - mise run test
```

## Troubleshooting

### Check mise status

```bash
# Show configuration
mise config

# Show environment
mise env

# Show installed tools
mise list

# Debug mode
mise --verbose install node
```

### Clear cache

```bash
# Clear tool cache
mise cache clear

# Remove and reinstall
mise uninstall node@20
mise install node@20
```

### Legacy .tool-versions

mise is compatible with asdf's `.tool-versions`:

```
# .tool-versions
nodejs 20.10.0
python 3.12.0
ruby 3.3.0
```

Convert to mise:

```bash
# mise auto-reads .tool-versions
# Or convert to .mise.toml
mise config migrate
```

## Best Practices

- **Use .mise.toml for projects**: Better than .tool-versions (more features)
- **Pin versions in projects**: Ensure consistency across team
- **Use tasks for common operations**: Document and standardize workflows
- **Lock files in production**: Use `mise lock` for reproducibility
- **Global tools for dev**: Set global defaults, override per project
- **Environment per project**: Keep secrets and config in .mise.toml
- **Commit .mise.toml**: Share config with team
- **Don't commit .mise.lock**: Let mise generate per environment

## Key Principles

- **Reproducible environments**: Lock versions for consistency
- **Project-specific config**: Each project defines its own tools and env
- **Task automation**: Centralize common development tasks
- **Cross-platform**: Same config works on all platforms
- **Zero setup for team**: Clone and `mise install` to get started
