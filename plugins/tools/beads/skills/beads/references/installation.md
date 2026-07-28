# Beads Installation Reference

Installation methods for the `bd` binary: npm, Homebrew, Go install, and mise
(multi-architecture).

### npm (Recommended)

```bash
npm install -g @anthropic/beads
```

### Homebrew (macOS)

```bash
brew install anthropic/tap/beads
```

### Go Install

```bash
go install github.com/steveyegge/beads/cmd/bd@latest
```

### mise (Multi-Architecture)

Add to your `mise.toml`:

```toml
[tools."github:steveyegge/beads"]
version = "latest"

[tools."github:steveyegge/beads".platforms]
linux-x64 = { asset_pattern = "beads_*_linux_amd64.tar.gz" }
macos-arm64 = { asset_pattern = "beads_*_darwin_arm64.tar.gz" }
```

