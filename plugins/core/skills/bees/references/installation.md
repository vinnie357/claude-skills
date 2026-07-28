# Bees Installation

Full install matrix (mise, pre-built binaries, source build) and build troubleshooting. The mise route is the common case; a stub remains in the skill body.

## Installation

### mise (Preferred)

Add to your `mise.toml`:

```toml
[tools."github:ctxshift/bees"]
version = "latest"

[tools."github:ctxshift/bees".platforms]
linux-x64 = { asset_pattern = "bees-linux-x86_64.tar.gz" }
linux-arm64 = { asset_pattern = "bees-linux-aarch64.tar.gz" }
macos-arm64 = { asset_pattern = "bees-macos-aarch64.tar.gz" }
macos-x64 = { asset_pattern = "bees-macos-x86_64.tar.gz" }
```

See `templates/mise.toml` for the full mise task definitions.

### Pre-built Binaries

Download from [GitHub Releases](https://github.com/ctxshift/bees/releases):

| Platform | Asset |
|----------|-------|
| Linux x86_64 | `bees-linux-x86_64.tar.gz` |
| Linux aarch64 | `bees-linux-aarch64.tar.gz` |
| macOS aarch64 | `bees-macos-aarch64.tar.gz` |
| macOS x86_64 | `bees-macos-x86_64.tar.gz` |

### Build from Source

Requires Zig 0.15.0+:

```bash
git clone https://github.com/ctxshift/bees.git
cd bees
zig build -Doptimize=ReleaseSafe
```

## Troubleshooting

### Build Issues (from source)

```bash
# Verify Zig version (requires 0.15.0+)
zig version

# Clean build
rm -rf zig-cache zig-out
zig build -Doptimize=ReleaseSafe
```
