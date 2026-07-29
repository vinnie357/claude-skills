# Setup, Integration, and Troubleshooting

Installation, shims, IDE and CI/CD integration, diagnostics, and `.tool-versions` migration. The core install one-liner and shell activation live in `SKILL.md`.

## Table of Contents

- [Installation](#installation)
- [Shims](#shims)
- [IDE integration](#ide-integration)
- [CI/CD integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)
- [Legacy .tool-versions](#legacy-tool-versions)

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

## IDE integration

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

## CI/CD integration

### GitHub Actions

```yaml
name: CI

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: jdx/mise-action@v4

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

## Legacy .tool-versions

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
