# Apple Container CLI - Version 0.7.0 Commands

Changes from 0.6.0.

## Breaking Changes from 0.6.0

| Change | 0.6.0 | 0.7.0 |
|--------|-------|-------|
| Progress flag | `--disable-progress-updates` | `--progress none\|ansi` |

## New Features in 0.7.0

- `--rosetta` flag for x86_64 emulation via Rosetta on Apple silicon
- `--progress none|ansi` replaces `--disable-progress-updates`
- Image download progress display
- Stdio support for `container image save` and `container image load` (pipe to/from stdout/stdin)
- Dockerfile from stdin (`container build -t img:latest -f - .`)
- `container stats` for resource usage monitoring
- Port range publishing (`-p 8000-8010:8000-8010`)
- `--mac-address` flag on `container run`
- `container system df` for disk usage reporting
- `container image prune -a` to prune all unused images (not just dangling)
- `container exec -d` for detached command execution
- Network `creationDate` field in network inspect output

## Container Lifecycle

| Command | Description |
|---------|-------------|
| `container run` | **`--rosetta`, `--mac-address`, `--progress none\|ansi` flags added; port range publishing** |
| `container exec` | **`-d` (detach) flag added** |
| `container stats` | **New command** |

## Image Management

| Command | Description |
|---------|-------------|
| `container image pull` | **Download progress display** |
| `container image save` | **Stdio support (pipe to stdout)** |
| `container image load` | **Stdio support (pipe from stdin)** |
| `container image prune` | **`-a` flag to prune all unused images** |

## Build

| Command | Description |
|---------|-------------|
| `container build` | **Dockerfile from stdin (`-f -`); `--progress` flag** |

## Network Management

| Command | Description |
|---------|-------------|
| `container network list` | **`creationDate` field added** |

## System Management

| Command | Description |
|---------|-------------|
| `container system df` | **New command** |

## Dependencies

- Containerization 0.16.0
- Builder Shim 0.7.0
