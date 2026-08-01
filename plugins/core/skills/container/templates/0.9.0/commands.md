# Apple Container CLI - Version 0.9.0 Commands

Changes from 0.8.0.

## New Features in 0.9.0

- Resource limits: `--cpus` and `--memory` flags on `container run`/`container create`
- `container system dns create <domain-name> --localhost <ip>` for a named local DNS domain that redirects to the host (apple/container#346, PR #1078) — per the upstream `docs/how-to.md` "Access a host service from a container" guide, whose own example domain is `host.container.internal`; `host.docker.internal` in the 0.9.0 release notes was an illustrative name, not a hostname resolved automatically. See [references/command-reference.md](../../references/command-reference.md) "Reaching host services from a container".
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
