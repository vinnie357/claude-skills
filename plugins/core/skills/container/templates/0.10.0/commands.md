# Apple Container CLI - Version 0.10.0 Commands

Changes from 0.9.0.

## Breaking Changes from 0.9.0

| Change | Migration |
|--------|-----------|
| ClientContainer reworked as generic client | Update API consumers for generic client interface |
| API terminology: 'cleanup' corrected to 'clean up' | Update API calls using old terminology |
| Container bundle creation moved to SandboxService | Move bundle creation code from main container ops |
| Multiple network plugins support | Review network configuration for multi-plugin model |

## New Features in 0.10.0

- VM init image selection: `--init-image` flag on `container run`/`container create`
- Container export: create images from running containers (`container export`)
- Runtime flag: `--runtime` on `container run`/`container create`
- `--init` flag on `container run`/`container create`
- `container registry list` to list configured registries
- `--format` option on `container system status`
- Minimum memory validation on container creation
- Enhanced directory watcher functionality

## Container Lifecycle

| Command | Description |
|---------|-------------|
| `container run` | **`--init`, `--init-image`, `--runtime` flags formalized** |
| `container create` | **`--init`, `--init-image`, `--runtime` flags formalized** |
| `container export` | **New command: create image from running container** |

## Registry

| Command | Description |
|---------|-------------|
| `container registry list` | **New command: list configured registries** |

## System Management

| Command | Description |
|---------|-------------|
| `container system status` | **`--format` flag added** |

## Bug Fixes

- Kernel panic fix for SELinux inode security under load
- Environment variable duplication fix in run operations
- Coldstart integration test fixes
- Enhanced directory watcher

## Dependencies

- Containerization 0.26.2
