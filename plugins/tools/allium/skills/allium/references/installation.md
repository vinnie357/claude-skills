# Allium Installation

## Two Components

Allium has two separately installed components:

1. **Claude skills plugin** (`allium@juxt`) — provides `/allium:elicit`, `/allium:propagate`, `/allium:weed`, `/allium:distill`, `/allium:tend` slash commands
2. **CLI binary** (`allium-tools`) — validates specs, runs `allium check` in CI, powers `allium weed` locally

## Installing the Claude Plugin (upstream)

```
/plugin marketplace add juxt/claude-plugins
/plugin install allium@juxt
```

This installs the upstream Allium skills directly from the juxt marketplace. Our `plugins/tools/allium` plugin is an opinion layer on top — both must be installed for full functionality.

## Installing the CLI (mise)

The CLI binary is distributed from `juxt/allium-tools` (separate repo from the skills plugin). Install via mise using the `github:` backend, which resolves pre-built binaries from GitHub Releases.

### Per-project (recommended)

Add to `mise.toml` in your project root:

```toml
[tools]
"github:juxt/allium-tools" = "3.0.4"
```

Then run:

```bash
mise install
```

### Global (optional)

```bash
mise use -g "github:juxt/allium-tools@3.0.4"
```

### Verifying Available Versions

```bash
mise ls-remote github:juxt/allium-tools
```

As of 2026-04-17, available versions: `3.0.0`, `3.0.1`, `3.0.2`, `3.0.3`, `3.0.4`. Pinned to `3.0.4` for supply-chain hygiene.

### Verify Installation

```bash
allium --version
```

## When Is the CLI Required?

| Scenario | CLI needed? |
|---|---|
| Authoring specs with `/allium:elicit` | No |
| Running `/allium:propagate` to seed tests | No |
| Running `allium check` in CI | Yes |
| Running `/allium:weed` locally | Yes (wraps `allium check`) |
| Reviewing spec syntax in editor | No |

If CI is the only environment running weed-checks, install the CLI only in CI via mise:

```bash
mise install github:juxt/allium-tools
```

## No Fallback Script

mise is the sole install entry point per `/core:mise` conventions. Do not author a shell-chain fallback installer — mise handles resolution, version pinning, and cross-platform binary selection automatically.
