# Apple Container CLI - Version 0.6.0 Commands

Changes from 0.5.0.

## Breaking Changes from 0.5.0

| Change | 0.5.0 | 0.6.0 |
|--------|-------|-------|
| Image store directory | `.build` | `builder` |

## New Features in 0.6.0

- Multiple `--tag` flags on build (`container build -t img:latest -t img:v1 .`)
- `--network none` for builds (isolated builds)
- `container network create --subnet` for custom subnets
- Anonymous volumes support
- `container volume prune` to remove unused volumes
- Containerfile fallback (builder uses Containerfile when no Dockerfile found)
- DNS list `--format`/`--quiet` flags (`container system dns list --format json`)

## Container Lifecycle

No changes from 0.5.0.

## Image Management

No changes from 0.5.0.

## Build

| Command | Description |
|---------|-------------|
| `container build` | **Multiple `--tag` flags; `--network none`; Containerfile fallback** |

## Network Management

| Command | Description |
|---------|-------------|
| `container network create` | **`--subnet` flag added** |

## Volume Management

| Command | Description |
|---------|-------------|
| `container volume create` | **Anonymous volumes supported** |
| `container volume prune` | **New command** |

## System Management

### System DNS

| Command | Description |
|---------|-------------|
| `container system dns list` | **`--format`/`--quiet` flags added** |

## Dependencies

- Containerization 0.12.1
