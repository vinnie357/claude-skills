# Backend Detail — ls-remote Examples, GitHub, Cargo, Multi-Arch

Per-backend installation detail for mise. The backend list, the ls-remote verification rule, and the wrong-repo gotcha live in `SKILL.md`; this file holds the worked examples and per-backend options.

## Table of Contents

- [ls-remote output per backend](#ls-remote-output-per-backend)
- [GitHub backend](#github-backend)
- [Multi-architecture tool installation](#multi-architecture-tool-installation)
- [Cargo backend](#cargo-backend)
- [Managing installed tools](#managing-installed-tools)
- [Tool aliases](#tool-aliases)

## ls-remote output per backend

`mise ls-remote <backend>:<target>` returns all available versions for any backend.

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

# github backend — the GitHub CLI itself
$ mise ls-remote github:cli/cli | head -5
2.74.0
2.74.1
2.74.2
2.75.0
2.75.1

# cargo backend — lists versions from crates.io
$ mise ls-remote cargo:ripgrep | head -5
0.1.0
0.1.1
0.1.2
0.1.3
0.1.4

# go backend — requires Go installed (mise use go@latest)
$ mise ls-remote go:mvdan.cc/gofumpt | head -5
0.1.0
0.1.1
0.2.0
0.2.1
0.3.0

# npm backend — lists versions from the npm registry
$ mise ls-remote npm:typescript | head -5
0.8.0
0.8.1-1
0.8.1
0.8.2
0.8.3
```

## GitHub backend

The **github** backend installs tools directly from GitHub release assets without requiring plugins. It is built into mise, works cross-platform including Windows, and adds provenance verification and download progress over the older ubi backend.

Note: The `ubi:` prefix is deprecated (per upstream mise docs); migrate any existing `ubi:owner/repo` entries to `github:owner/repo`.

### Basic GitHub backend usage

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

### GitHub backend advanced options

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

### GitHub backend supported syntax

Two installation formats:
- **GitHub shorthand (latest)**: `github:owner/repo`
- **GitHub shorthand (version)**: `github:owner/repo@1.2.3`

## Multi-architecture tool installation

When installing tools from GitHub releases that provide separate binaries for different platforms/architectures, use platform-specific asset patterns.

See `templates/multi-arch.md` (in this skill's `templates/` directory) for the pattern:

```toml
[tools."github:owner/repo"]
version = "latest"

[tools."github:owner/repo".platforms]
linux-x64 = { asset_pattern = "tool_*_linux_amd64.tar.gz" }
macos-arm64 = { asset_pattern = "tool_*_darwin_arm64.tar.gz" }
```

### Platform keys

Common platform keys for mise:
- `linux-x64` - Linux on x86_64/amd64
- `linux-arm64` - Linux on ARM64/aarch64
- `macos-x64` - macOS on Intel (x86_64)
- `macos-arm64` - macOS on Apple Silicon (M1/M2/M3)
- `windows-x64` - Windows on x86_64

### Asset pattern wildcards

Use `*` as a wildcard in asset patterns to match version numbers or other variable parts of release asset names.

Example for a tool with releases like `beads_1.0.0_darwin_arm64.tar.gz`:
```toml
asset_pattern = "beads_*_darwin_arm64.tar.gz"
```

## Cargo backend

The **cargo** backend installs Rust packages from crates.io. **Requires Rust to be installed first.**

### Cargo prerequisites

Install Rust before using cargo backend:

```bash
# Option 1: Install Rust via mise
mise use -g rust

# Option 2: Install Rust directly
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Cargo usage

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

### Cargo from Git repositories

```bash
# Specific tag
mise use cargo:https://github.com/username/demo@tag:v1.0.0

# Branch
mise use cargo:https://github.com/username/demo@branch:main

# Commit hash
mise use cargo:https://github.com/username/demo@rev:abc123
```

### Cargo settings

Configure cargo behavior globally:

```toml
[settings]
# Use cargo-binstall for faster installs (default: true)
cargo.binstall = true

# Use alternative cargo registry
cargo.registry_name = "my-registry"
```

## Managing installed tools

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

## Tool aliases

```bash
# Create alias for a tool
mise alias node 20 20.10.0

# Use alias
mise use node@20
```
