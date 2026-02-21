# Apple Container CLI - Version 0.9.0 Commands

Changes from 0.8.0.

## New Features in 0.9.0

- Resource limits: `--cpus` and `--memory` flags on `container run`/`container create`
- `host.docker.internal` support for accessing host services from containers
- Host-only and isolated network capabilities (verify flag syntax with `container network create --help`)
- `--dns` flag on `container build`
- `--force` on `container image delete` (verify flag syntax with `container image delete --help`)
- zstd compression for image layers and kernels
- Container prune improvements
- Enhanced image inspection output
- Full size in `container image list` JSON output
- `container system stop` works across all launchd domains
- Kata 3.26.0 kernel

## Container Lifecycle

| Command | Description |
|---------|-------------|
| `container run` | **`--cpus`, `--memory` flags added** |
| `container create` | **`--cpus`, `--memory` flags added** |
| `container prune` | **Improved behavior** |

## Image Management

| Command | Description |
|---------|-------------|
| `container image delete` | **`--force` flag added (verify with `--help`)** |
| `container image inspect` | **Enhanced output** |
| `container image list` / `ls` | **Full size in JSON output** |

## Build

| Command | Description |
|---------|-------------|
| `container build` | **`--dns` flag added** |

## Network Management

| Command | Description |
|---------|-------------|
| `container network create` | **Host-only and isolated network capabilities (verify flags with `--help`)** |

## System Management

| Command | Description |
|---------|-------------|
| `container system stop` | **Works across all launchd domains** |

## Dependencies

- Containerization 0.24.0
- Kata kernel 3.26.0
