---
name: container
description: Guide for using Apple Container CLI to run Linux containers on Apple silicon Macs (macOS 26+). Use when managing OCI containers, building images, configuring networks/volumes, running long-lived Linux machines with container machine, or working with container system services on macOS.
license: MIT
---

# Apple Container CLI

This skill activates when working with Apple Container for running Linux containers natively on Apple silicon Macs.

## When to Use This Skill

Activate when:
- Running Linux containers on macOS 26+ with Apple silicon
- Managing container lifecycle (run, stop, exec, logs, inspect)
- Building OCI-compatible container images
- Managing container images (pull, push, tag, save, load)
- Configuring container networks and volumes
- Managing the container system service
- Running long-lived Linux machine environments with `container machine` (1.0.0+)
- Migrating between Apple Container versions (0.5.x to 1.0.0)

## What is Apple Container?

Apple Container is a macOS-native tool for running Linux containers as lightweight virtual machines on Apple silicon:

- **Swift-based**: Built on Apple's Virtualization.framework
- **OCI-compatible**: Produces and runs standard OCI container images
- **Apple silicon only**: Requires Apple silicon Mac (M1 or later)
- **Stable 1.0**: Currently at version 1.0.0 (released 2026-06-09); 0.x minor releases carried frequent breaking changes — see Version Differences below when upgrading
- **Lightweight VMs**: Each container runs as a lightweight Linux VM

## Prerequisites

- macOS 26 or later (Tahoe)
- Apple silicon Mac (M1, M2, M3, M4 series)
- Install via signed `.pkg` from [GitHub releases](https://github.com/apple/container/releases)

## System Management

Manage the container system service (start, stop, status, version, logs, disk usage) and its TOML configuration file. Full command list, flag tables, and the TOML config detail: [references/command-reference.md](references/command-reference.md).

> **⚠ BREAKING — 1.0.0:** A TOML configuration file at `~/.config/container/config.toml` replaces the UserDefaults-backed system properties. `container system property get`, `set`, and `clear` are REMOVED — edit the TOML file, then restart the service (`container system stop && container system start`).

## Container Lifecycle

Run, manage, and export containers (`run`, `list`/`ls`, `start`, `stop`, `kill`, `delete`/`rm`, `exec`, `logs`, `inspect`, `cp`, `stats`, `prune`, `export`, `create`). Full flag tables and worked examples: [references/command-reference.md](references/command-reference.md).

Two corrections worth keeping in view: a custom MAC address is set via `--network <name>,mac=XX:XX:XX:XX:XX:XX` on `container run` — there is no separate `--mac-address` flag. `container export` produces a filesystem tar only (`-o/--output`); it does not create or tag an image, and there is no `-t/--tag` flag.

> **⚠ Observed — `--rm` does not reliably remove the container on 1.0.0.** `container run --rm ...` left a stopped container behind on one host running Apple Container 1.0.0, despite `--rm` being set. This is stated as a direct operator observation at 1.0.0, not independently reproduced or verified against the binary here — do not treat it as confirmed on every 1.0.0 install. It is the likely accumulation mechanism behind roughly 300 stopped containers found on a dev host, a large share of them anonymous short-lived scan containers (e.g. from a gitleaks pre-commit hook that also relied on `--rm`). If a workflow depends on containers being reaped automatically, do not trust `--rm` alone on 1.0.0 — give the container an explicit unique `--name` and follow up with a defensive `container rm -f <that-exact-name>` scoped to only the container you just created. See Troubleshooting below for why an unscoped cleanup is worse than no cleanup at all.

## Container Machines (1.0.0+)

Machines are long-lived Linux environments with tight host integration — a full Linux system with init support, not an ephemeral application container. Use machines for "edit on the Mac, build inside Linux" workflows, running system services under systemd, and testing across multiple distributions. The subcommand alias is `m` (`container m ls` = `container machine ls`).

> **Isolation caveat:** A machine auto-mounts the host home directory at `/Users/<username>` inside the VM. That tight host integration makes machines a development convenience, NOT an isolation boundary for untrusted workloads — run untrusted agents in regular containers or a dedicated sandboxing substrate instead.

```bash
# Create a machine from an image
container machine create alpine:latest --name dev

# Run a single command in the machine
container machine run -n dev uname -a
container machine run -n dev -- cat /proc/cpuinfo

# Open an interactive shell
container machine run -n dev

# Set a default machine, then omit -n
container machine set-default dev
container machine run

# List, inspect, stop, delete
container machine ls
container machine inspect dev
container machine stop dev
container machine rm dev

# Resize CPUs/memory (stop, then run to apply)
container machine set -n dev cpus=4 memory=8G
container machine stop dev
container machine run -n dev -- nproc
```

The machine maps the host user automatically: the host home directory is mounted at `/Users/<username>` inside the machine and the machine user matches the host UID/GID.

### Custom Machine Images

Machine images require `/sbin/init` (a process supervisor such as systemd). An optional first-boot script at `/etc/machine/create-user.sh` receives `CONTAINER_UID`, `CONTAINER_GID`, `CONTAINER_USER`, `CONTAINER_HOME`, and `CONTAINER_MACHINE_ID`:

```bash
# Build a custom machine image, then create a machine from it
container build -t local/ubuntu-machine:latest .
container machine create local/ubuntu-machine:latest --name ubuntu
```

See [templates/1.0.0/commands.md](templates/1.0.0/commands.md) and the [upstream machine guide](https://github.com/apple/container/blob/main/docs/container-machine.md) for the full machine reference.

## Image Management

Pull, tag, push, save/load, delete, inspect, and prune images (`container image ...`). Full flag tables: [references/command-reference.md](references/command-reference.md).

Architecture aliases (0.8.0+): `amd64`=`x86_64`, `arm64`=`aarch64`. Set `CONTAINER_DEFAULT_PLATFORM` (0.11.0+) to avoid specifying `--platform` on every pull/build.

## Build

Build OCI-compatible images from a Dockerfile or Containerfile (`container build`) and manage the builder process. Full flag tables: [references/command-reference.md](references/command-reference.md).

When no `Dockerfile` is found, the builder falls back to `Containerfile` (0.6.0+).

## Network Management

Create, inspect, and prune container networks (`container network ...`). Full flag tables: [references/command-reference.md](references/command-reference.md). See Common Workflows below for a multi-container networking example.

Full IPv6 support (0.8.0+); host-only/isolated modes (0.9.0+, verify syntax with `--help`); `mtu` network attachment (0.11.0+).

To reach host services from a container: the default network's gateway (`192.168.64.1`, no setup required) only reaches services bound to a non-loopback address. Services bound to `127.0.0.1` (the common local-dev-server case) are NOT reachable via the gateway — use `container system dns create <domain> --localhost <ip>` instead, which is a reachability feature, not just a naming convenience. See [references/command-reference.md](references/command-reference.md) "Reaching host services from a container".

## Volume Management

Create, inspect, and prune persistent volumes (`container volume ...`). Full flag tables: [references/command-reference.md](references/command-reference.md). Mount with `-v name:/path[:ro]` on `container run`; see Common Workflows below for a persistent-data example.

## Registry

Authenticate with container registries:

```bash
# Log in to a registry
container registry login <registry-url>

# Log out from a registry
container registry logout <registry-url>

# List configured registries (0.10.0+)
container registry list
```

**Note**: In 0.5.0, the keychain ID changed from `com.apple.container` to `com.apple.container.registry`. Re-login is required after upgrading from 0.4.x.

## Version Differences (0.5.0 to 1.0.0)

### Breaking Changes

| Version | Change | Migration |
|---------|--------|-----------|
| 0.6.0 | Image store directory moved from `.build` to `builder` | Update paths referencing `.build` |
| 0.7.0 | `--disable-progress-updates` removed | Use `--progress none\|ansi` instead |
| 0.8.0 | Client API reorganization | Update API consumers |
| 0.8.0 | Subnet allocation defaults changed | Review network configurations |
| 0.10.0 | ClientContainer reworked as generic client | Update API consumers for generic client interface |
| 0.10.0 | Bundle creation moved to SandboxService | Move bundle creation code from main container ops |
| 0.10.0 | Multiple network plugins support | Review network configuration for multi-plugin model |
| **0.12.0** | **Default Linux capability set REDUCED** | **Delete & recreate all existing containers; use `--cap-add` to restore needed capabilities** |
| 0.12.0 | Builder-shim gRPC protocol changed | Incompatible with pre-0.12.0 clients — update all builder clients |
| **1.0.0** | **TOML config file replaces UserDefaults-backed system properties** | **Move `property set` values into `~/.config/container/config.toml`; `property get/set/clear` are removed** |
| 1.0.0 | Structured (JSON/YAML/TOML) output shape changed for `container`/`image`/`network`/`volume` `ls` and `inspect` | Update scripts that parse structured output |
| 1.0.0 | Application major version 0 XPC API compatibility removed | Update XPC API consumers |

> **⚠ BREAKING — 0.12.0 capability change:** The default Linux capability set was **reduced**. Users MUST delete and recreate existing containers to apply the new defaults. Use `--cap-add` to restore capabilities; use `--cap-drop` to further restrict them. See [0.12.0 template](templates/0.12.0/commands.md) for details.

### Required Migrations

1. **0.12.0**: Delete and recreate all existing containers (reduced default capability set); add `--cap-add` for containers needing elevated capabilities
2. **0.12.0**: Update builder clients (gRPC protocol changed, incompatible with older clients)
3. **1.0.0**: Move `container system property set` values into `~/.config/container/config.toml`, then restart the service
4. **1.0.0**: Update automation that parses `ls`/`inspect` structured output (shape changed)

The full per-release feature history, the complete 0.5.x-to-1.0.0 migration checklist, and the dependency matrix live in [references/version-history.md](references/version-history.md). The exhaustive per-command flag reference lives in [references/command-reference.md](references/command-reference.md).

See `templates/<version>/commands.md` for version-specific details (0.4.1, 0.5.0, 0.6.0, 0.7.0, 0.8.0, 0.9.0, 0.10.0, 0.11.0, 0.12.0, 0.12.3, 1.0.0).

## Scripts

This skill includes focused Nushell scripts for container management:

### container-system.nu

System service management with health checks:

```bash
# Start system service
nu scripts/container-system.nu start

# Check status
nu scripts/container-system.nu status

# Full health check (status + disk + container count)
nu scripts/container-system.nu health

# View disk usage
nu scripts/container-system.nu df

# Show version
nu scripts/container-system.nu version
```

### container-images.nu

Image lifecycle operations:

```bash
# List images
nu scripts/container-images.nu list

# Pull an image
nu scripts/container-images.nu pull ubuntu:latest

# Build from Dockerfile
nu scripts/container-images.nu build -t myimage:latest .

# Prune unused images
nu scripts/container-images.nu prune
```

### container-lifecycle.nu

Container run/stop/exec/logs/export:

```bash
# List running containers
nu scripts/container-lifecycle.nu ps

# Run a container
nu scripts/container-lifecycle.nu run ubuntu:latest

# View logs
nu scripts/container-lifecycle.nu logs mycontainer

# Execute command
nu scripts/container-lifecycle.nu exec mycontainer /bin/bash

# Export container to image (0.10.0+)
nu scripts/container-lifecycle.nu export mycontainer -o exported.tar
```

### container-cleanup.nu

Prune and disk usage:

```bash
# Prune everything unused
nu scripts/container-cleanup.nu prune-all

# Prune only containers
nu scripts/container-cleanup.nu prune-containers

# Show disk usage
nu scripts/container-cleanup.nu df
```

## Mise Tasks

Copy `templates/mise.toml` to add container management tasks to any project:

```bash
mise container:start      # Start system service
mise container:stop       # Stop system service
mise container:status     # Show formatted status
mise container:run        # Run container (accepts image arg)
mise container:ps         # List running containers
mise container:images     # List images
mise container:build      # Build from Dockerfile/Containerfile
mise container:prune      # Clean up unused resources
mise container:health     # System status + disk + container count
mise container:df         # Disk usage
mise container:version    # CLI version
```

## Common Workflows

### Quick Start

```bash
# Start the system
container system start

# Pull and run an image
container run -it --rm ubuntu:latest /bin/bash

# Check what's running
container ls
```

### Build and Run

```bash
# Build your image
container build -t myapp:latest .

# Run it
container run -d --name myapp -p 8080:80 myapp:latest

# Check logs
container logs --follow myapp
```

### Multi-Container with Networking

```bash
# Create network
container network create mynet

# Start database
container run -d --name postgres --network mynet \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

# Start application
container run -d --name app --network mynet \
  -p 3000:3000 \
  -e DATABASE_URL=postgres://postgres:secret@postgres:5432/mydb \
  myapp:latest
```

### Persistent Data with Volumes

```bash
# Create a volume
container volume create appdata

# Run with volume
container run -d --name db -v appdata:/var/lib/data mydb:latest

# Volume persists after container removal
container rm db
container run -d --name db2 -v appdata:/var/lib/data mydb:latest
```

## Troubleshooting

### Accumulated Stopped Containers (`--rm` unreliable on 1.0.0)

If `container ls -a` shows a growing pile of stopped containers despite scripts using `--rm`, see the `--rm` note under Container Lifecycle above. Clean up deliberately, never with an unfiltered command:

```bash
# Inspect the full target list FIRST — always, before any destructive command
container ls -a

# Remove specific, identified containers by name or ID — never a blind splat
container rm -f <name-or-id> [<name-or-id> ...]
```

**Never run `container rm -f $(container ls -aq)`.** That command has no filter: on one host it removed every container present, including unrelated k8s control planes that happened to be running alongside the anonymous scan containers it was meant to clean up. Images and named volumes survived that incident; container state did not. Two lessons, both binding for any cleanup script or agent-authored one-liner touching this CLI:

1. **Inspect the target list before a destructive command.** `container ls -a` first, always — confirm what you are about to remove matches what you intend to remove.
2. **Never splat an unfiltered `ls` into `rm`.** Scope every cleanup to specific names or IDs you created or explicitly identified, not "everything the list command currently returns."

### System Not Started

```bash
# Check status
container system status

# Start if not running
container system start

# View logs for errors
container system logs
```

### Image Pull Failures

```bash
# Check system is running
container system status

# Try with explicit platform
container image pull --platform linux/arm64 <image>

# Check registry authentication
container registry login <registry>
```

### Volume Permission Issues

```bash
# Check volume exists
container volume list

# Inspect volume for mount details
container volume inspect <name>

# Run container with specific user
container run -u 1000:1000 -v myvol:/data myimage:latest
```

### Builder Issues

```bash
# Check builder status
container builder status

# Restart builder
container builder stop
container builder start

# Delete and recreate if stuck
container builder delete
container builder start
```

## Key Principles

- **Stable 1.0**: The CLI surface stabilized at 1.0.0; the 0.x-to-1.0.0 migration is breaking (TOML config, structured-output shape)
- **Apple silicon only**: No Intel Mac support
- **macOS 26+ required**: Not available on earlier macOS versions
- **OCI-compatible**: Standard container images work as expected
- **Lightweight VMs**: Each container is an isolated lightweight VM
- **System service**: Start the system service before running containers
- **Verify, never fabricate**: Confirm flags against `container <cmd> --help` before scripting them — see /core:anti-fabrication
