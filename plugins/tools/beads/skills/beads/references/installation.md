# Beads Installation Reference

Installation methods for the `bd` binary: npm, Homebrew, Go install, and mise
(multi-architecture).

### npm (Recommended)

```bash
npm install -g @beads/bd
```

### Homebrew (macOS/Linux)

```bash
brew install beads
```

This is the `homebrew-core` formula (no tap needed).

### Go Install

Prefer Homebrew, npm, or the install script above unless you specifically
need `go install`. It has two supported modes, both requiring an env
prefix:

```bash
# Server-mode only (no C compiler needed) — no embedded Dolt; run an
# external `dolt sql-server` and use `bd init --server`
CGO_ENABLED=0 go install github.com/steveyegge/beads/cmd/bd@latest

# Embedded-capable (requires a C compiler) — `bd init` Just Works
CGO_ENABLED=1 GOFLAGS=-tags=gms_pure_go go install github.com/steveyegge/beads/cmd/bd@latest
```

The repository now lives under `gastownhall/beads`, but released Go
modules still declare the `github.com/steveyegge/beads` path for
compatibility — use that path for `go install`, not the new org.

### mise (Multi-Architecture)

Add to your `mise.toml`:

```toml
[tools."github:gastownhall/beads"]
version = "latest"

[tools."github:gastownhall/beads".platforms]
linux-x64 = { asset_pattern = "beads_*_linux_amd64.tar.gz" }
macos-arm64 = { asset_pattern = "beads_*_darwin_arm64.tar.gz" }
```

