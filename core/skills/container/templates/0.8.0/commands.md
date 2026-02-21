# Apple Container CLI - Version 0.8.0 Commands

Changes from 0.7.0.

## Breaking Changes from 0.7.0

| Change | 0.7.0 | 0.8.0 |
|--------|-------|-------|
| Client API | Previous layout | Reorganized |
| Subnet allocation | Previous defaults | Changed defaults |

## New Features in 0.8.0

- `--read-only` flag for `container run` and `container create` (read-only rootfs)
- Architecture aliases: `amd64` = `x86_64`, `arm64` = `aarch64`
- `container network prune` to remove unused networks
- Full IPv6 support for container networking
- Volume relative paths (bind mounts accept relative paths)
- Environment variables from named pipes
- CVE-2026-20613 security fix

## Container Lifecycle

| Command | Description |
|---------|-------------|
| `container run` | **`--read-only` flag added** |
| `container create` | **`--read-only` flag added** |

## Image Management

| Command | Description |
|---------|-------------|
| `container image pull` | **Architecture aliases: `amd64`/`arm64`/`x86_64`/`aarch64`** |

## Build

| Command | Description |
|---------|-------------|
| `container build` | **Architecture aliases supported in `--platform`** |

## Network Management

| Command | Description |
|---------|-------------|
| `container network create` | **Full IPv6 support** |
| `container network prune` | **New command** |

## Volume Management

| Command | Description |
|---------|-------------|
| `container volume create` | **Relative paths for bind mounts** |

## Dependencies

- Containerization 0.21.1
