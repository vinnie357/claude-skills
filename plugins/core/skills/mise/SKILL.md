---
name: mise
description: Guide for using mise to manage development tools and runtime versions. Use when configuring project tooling, managing environment variables, or defining project tasks.
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

Current stable: v2026.3.15

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
- **github** - GitHub release-asset installer (replaces deprecated ubi backend)
- **cargo** - Rust packages (requires Rust installed)
- **npm** - Node.js packages (requires Node installed)
- **go** - Go packages (requires Go installed)
- **aqua** - Package manager
- **pipx** - Python packages (requires Python installed)
- **gem** - Ruby packages (requires Ruby installed)
- **gitlab** - Direct from GitLab repositories
- **http** - Direct HTTP downloads

#### Verifying Tool Names

Always verify tool names using `mise ls-remote` before adding to configuration:

```bash
# Check if tool exists in registry
mise ls-remote node

# Check tool with specific backend
mise ls-remote cargo:ripgrep
mise ls-remote github:sharkdp/fd

# Search the registry
mise registry | grep <tool-name>
```

### Discovering Available Tools with ls-remote

`mise ls-remote <backend>:<target>` returns all available versions for any backend. Run this BEFORE pinning a version in mise.toml to confirm the backend can actually see the tool.

```bash
# github backend — lists release tags from GitHub
$ mise ls-remote github:sharkdp/fd | head -5
7.0.0
7.1.0
7.2.0
7.3.0
7.4.0

# github backend — another tool
$ mise ls-remote github:goreleaser/goreleaser | head -5
2.8.1
2.8.2
2.9.0
2.10.0
2.10.1

# cargo backend — lists versions from crates.io
$ mise ls-remote cargo:ripgrep | head -5
0.1.0
0.1.1
0.1.2
0.1.3
0.1.4

# npm backend — lists versions from the npm registry
$ mise ls-remote npm:typescript | head -5
0.8.0
0.8.1-1
0.8.1
0.8.2
0.8.3
```

**Failure mode — the tool lives in a different repo than you expect.** Sometimes the CLI binary is released from a different repository than the documentation or project homepage. Example:

```bash
# Returns no versions — wrong repo
$ mise ls-remote github:juxt/allium | head -5
(no output)

# Returns versions — correct repo for the CLI releases
$ mise ls-remote github:juxt/allium-tools | head -5
0.1.0
0.1.1
0.1.2
0.1.3
0.1.5
```

If `ls-remote` returns nothing, check whether the project publishes releases to a separate repository (e.g., a `-tools`, `-cli`, or `-releases` repo).

Don't pin a version you haven't verified ls-remote can see.

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
mise install github:sharkdp/fd    # From GitHub releases
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
mise use github:sharkdp/fd
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
"cargo:ripgrep" = "latest"           # Requires rust installed
"github:sharkdp/fd" = "latest"       # GitHub releases
"npm:typescript" = "latest"          # Requires node installed
"github:nushell/nushell" = "latest"  # Nushell (structured shell)

# Version from file
node = { version = "lts", resolve = "latest-lts" }
```

### GitHub Backend

The **github** backend installs tools directly from GitHub release assets without requiring plugins. It is built into mise, works cross-platform including Windows, and adds provenance verification and download progress over the older ubi backend.

Note: The `ubi:` prefix is deprecated (per upstream mise docs); migrate any existing `ubi:owner/repo` entries to `github:owner/repo`.

#### Basic GitHub Backend Usage

```bash
# Install from GitHub releases
mise use -g github:goreleaser/goreleaser
mise use -g github:sharkdp/fd
mise use -g github:BurntSushi/ripgrep

# Specific version
mise use -g github:goreleaser/goreleaser@2.10.0

# In .mise.toml
[tools]
"github:goreleaser/goreleaser" = "latest"
"github:sharkdp/fd" = "10.0.0"
```

#### GitHub Backend Advanced Options

Configure tool-specific options when binary names differ or asset filtering is needed:

```toml
[tools]
# When executable name differs from repo name
"github:BurntSushi/ripgrep" = { version = "latest", exe = "rg" }

# Filter release assets with a glob pattern
"github:some/tool" = { version = "latest", asset_pattern = "*-linux-gnu*" }

# Asset pattern with exact architecture
"github:some/tool" = { version = "latest", asset_pattern = "*_darwin_arm64.tar.gz" }

# Extract entire tarball
"github:some/tool" = { version = "latest", extract_all = true }

# Rename extracted executable
"github:some/tool" = { version = "latest", rename_exe = "my-tool" }
```

#### GitHub Backend Supported Syntax

Two installation formats:
- **GitHub shorthand (latest)**: `github:owner/repo`
- **GitHub shorthand (version)**: `github:owner/repo@1.2.3`

## Templates

The `templates/` directory contains reusable configuration snippets for common mise patterns.

### Multi-Architecture Tool Installation

When installing tools from GitHub releases that provide separate binaries for different platforms/architectures, use platform-specific asset patterns.

See `templates/multi-arch.md` for the pattern:

```toml
[tools."github:owner/repo"]
version = "latest"

[tools."github:owner/repo".platforms]
linux-x64 = { asset_pattern = "tool_*_linux_amd64.tar.gz" }
macos-arm64 = { asset_pattern = "tool_*_darwin_arm64.tar.gz" }
```

#### Platform Keys

Common platform keys for mise:
- `linux-x64` - Linux on x86_64/amd64
- `linux-arm64` - Linux on ARM64/aarch64
- `macos-x64` - macOS on Intel (x86_64)
- `macos-arm64` - macOS on Apple Silicon (M1/M2/M3)
- `windows-x64` - Windows on x86_64

#### Asset Pattern Wildcards

Use `*` as a wildcard in asset patterns to match version numbers or other variable parts of release asset names.

Example for a tool with releases like `beads_1.0.0_darwin_arm64.tar.gz`:
```toml
asset_pattern = "beads_*_darwin_arm64.tar.gz"
```

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
