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

### Tool Backends

mise uses different backends (package managers) to install tools. Understanding backends helps you install tools correctly.

#### Available Backends

- **asdf** - Traditional asdf plugins (default for many tools)
- **ubi** - Universal Binary Installer (GitHub/GitLab releases)
- **cargo** - Rust packages (requires Rust installed)
- **npm** - Node.js packages (requires Node installed)
- **go** - Go packages (requires Go installed)
- **aqua** - Package manager
- **pipx** - Python packages (requires Python installed)
- **gem** - Ruby packages (requires Ruby installed)
- **github/gitlab** - Direct from repositories
- **http** - Direct HTTP downloads

#### Verifying Tool Names

Always verify tool names using `mise ls-remote` before adding to configuration:

```bash
# Check if tool exists in registry
mise ls-remote node

# Check tool with specific backend
mise ls-remote cargo:ripgrep
mise ls-remote ubi:sharkdp/fd

# Search the registry
mise registry | grep <tool-name>
```

### Installing Tools

```bash
# List available tools in registry
mise registry

# Install from default backend
mise install node@20.10.0
mise install python@3.12
mise install ruby@3.3

# Install with specific backend
mise install cargo:ripgrep        # From Rust crates
mise install ubi:sharkdp/fd       # From GitHub releases
mise install npm:typescript       # From npm

# Install latest version
mise install node@latest

# Install from .mise.toml or .tool-versions
mise install
```

### Using Tools with `mise use`

The `mise use` command is the primary way to add tools to projects. It combines two operations:
1. **Installs** the tool (if not already installed)
2. **Adds** the tool to your configuration file

**Key Difference**: `mise install` only installs tools, while `mise use` installs AND configures them.

#### Basic Usage

```bash
# Interactive selection
mise use

# Add tool with fuzzy version (default)
mise use node@20              # Saves as "20" in mise.toml

# Add tool with exact version
mise use --pin node@20.10.0   # Saves as "20.10.0"

# Add latest version
mise use node@latest          # Saves as "latest"

# Add with specific backend
mise use cargo:ripgrep@latest
mise use ubi:sharkdp/fd
```

#### Configuration File Selection

`mise use` writes to configuration files in this priority order:

1. **`--global` flag**: `~/.config/mise/config.toml`
2. **`--path <file>` flag**: Specified file path
3. **`--env <env>` flag**: `.mise.<env>.toml`
4. **Default**: `mise.toml` in current directory

```bash
# Global (all projects)
mise use --global node@20

# Local (current project)
mise use node@20              # Creates/updates ./mise.toml

# Environment-specific
mise use --env local node@20  # Creates .mise.local.toml

# Specific file
mise use --path ~/.config/mise/custom.toml node@20
```

#### Important Flags

```bash
# Pin exact version
mise use --pin node@20.10.0        # Saves "20.10.0"

# Fuzzy version (default)
mise use --fuzzy node@20           # Saves "20"

# Force reinstall
mise use --force node@20

# Dry run (preview changes)
mise use --dry-run node@20

# Remove tool from config
mise use --remove node
```

#### Version Pinning

```bash
# Fuzzy (recommended) - auto-updates within major version
mise use node@20                   # Uses latest 20.x.x

# Exact - locks to specific version
mise use --pin node@20.10.0        # Always uses 20.10.0

# Latest - always uses newest version
mise use node@latest               # Always updates to latest
```

**Best Practice**: Use fuzzy versions for flexibility, `mise.lock` for reproducibility.

### Setting Tool Versions

The `mise use` command automatically sets tool versions by updating configuration files.

#### .mise.toml Configuration

```toml
[tools]
node = "20.10.0"
python = "3.12"
ruby = "3.3"
go = "1.21"

# Use latest version
terraform = "latest"

# Backends - use quotes for namespaced tools
"cargo:ripgrep" = "latest"        # Requires rust installed
"ubi:sharkdp/fd" = "latest"       # GitHub releases
"npm:typescript" = "latest"       # Requires node installed

# Version from file
node = { version = "lts", resolve = "latest-lts" }
```

### UBI Backend (Universal Binary Installer)

The **ubi** backend installs tools directly from GitHub/GitLab releases without requiring plugins. It's built into mise and works cross-platform including Windows.

#### Basic UBI Usage

```bash
# Install from GitHub releases
mise use -g ubi:goreleaser/goreleaser
mise use -g ubi:sharkdp/fd
mise use -g ubi:BurntSushi/ripgrep

# Specific version
mise use -g ubi:goreleaser/goreleaser@1.25.1

# In .mise.toml
[tools]
"ubi:goreleaser/goreleaser" = "latest"
"ubi:sharkdp/fd" = "2.0.0"
```

#### UBI Advanced Options

Configure tool-specific options when binary names differ or filtering is needed:

```toml
[tools]
# When executable name differs from repo name
"ubi:BurntSushi/ripgrep" = { version = "latest", exe = "rg" }

# Filter releases with matching pattern
"ubi:some/tool" = { version = "latest", matching = "linux-gnu" }

# Use regex for complex filtering
"ubi:some/tool" = { version = "latest", matching_regex = ".*-linux-.*\\.tar\\.gz$" }

# Extract entire tarball
"ubi:some/tool" = { version = "latest", extract_all = true }

# Rename extracted executable
"ubi:some/tool" = { version = "latest", rename_exe = "my-tool" }
```

#### UBI Supported Syntax

Three installation formats:
- **GitHub shorthand (latest)**: `ubi:owner/repo`
- **GitHub shorthand (version)**: `ubi:owner/repo@1.2.3`
- **Direct URL**: `ubi:https://github.com/owner/repo/releases/download/v1.2.3/...`

### Cargo Backend

The **cargo** backend installs Rust packages from crates.io. **Requires Rust to be installed first.**

#### Cargo Prerequisites

Install Rust before using cargo backend:

```bash
# Option 1: Install Rust via mise
mise use -g rust

# Option 2: Install Rust directly
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

#### Cargo Usage

```bash
# Install from crates.io
mise use -g cargo:ripgrep
mise use -g cargo:eza
mise use -g cargo:bat

# In .mise.toml - requires rust installed first
[tools]
rust = "latest"              # Install rust first
"cargo:ripgrep" = "latest"   # Then cargo tools
"cargo:eza" = "latest"
"cargo:bat" = "latest"
```

#### Cargo from Git Repositories

```bash
# Specific tag
mise use cargo:https://github.com/username/demo@tag:v1.0.0

# Branch
mise use cargo:https://github.com/username/demo@branch:main

# Commit hash
mise use cargo:https://github.com/username/demo@rev:abc123
```

#### Cargo Settings

Configure cargo behavior globally:

```toml
[settings]
# Use cargo-binstall for faster installs (default: true)
cargo.binstall = true

# Use alternative cargo registry
cargo.registry_name = "my-registry"
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
