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

Manage the container system service that runs in the background:

```bash
# Start the system service
container system start

# Stop the system service
container system stop

# Check service status
container system status

# Check service status with format (0.10.0+)
container system status --format json

# Show CLI version
container system version

# View system logs
container system logs

# Show disk usage
container system df
```

### System Configuration (TOML, 1.0.0+)

> **⚠ BREAKING — 1.0.0:** A TOML configuration file replaces the UserDefaults-backed system properties. `container system property get`, `set`, and `clear` are REMOVED. Migrate stored property values into `config.toml`, then restart the service.

Configuration lives at `~/.config/container/config.toml`, with a package-shipped fallback at `<installRoot>/etc/container/config.toml` (first match wins; missing keys fall back to built-in defaults):

```bash
mkdir -p ~/.config/container
touch ~/.config/container/config.toml
```

```toml
[container]
cpus = 8
memory = "4g"

[dns]
domain = "test"
```

Top-level tables: `[container]`, `[dns]`, `[build]`, `[kernel]`, `[network]`, `[registry]`, `[vminit]`.

Apply changes by restarting the service:

```bash
container system stop
container system start
```

`container system property list` (alias `ls`) remains as a read-only view of the merged configuration:

```bash
container system property list --format json
```

### System DNS

Manage DNS configuration for containers:

```bash
# Create a DNS entry
container system dns create <name> <ip>

# Delete a DNS entry
container system dns delete <name>

# List DNS entries
container system dns list
```

### Custom Kernel

Set a custom Linux kernel for containers:

```bash
# Set custom kernel
container system kernel set <path>

# Force set (0.5.0+)
container system kernel set --force <path>
```

## Container Lifecycle

### Run Containers

```bash
# Run interactively
container run -it ubuntu:latest /bin/bash

# Run detached
container run -d --name myapp nginx:latest

# Run with port mapping
container run -d -p 8080:80 nginx:latest

# Run with volume mount
container run -v /host/path:/container/path ubuntu:latest

# Run with environment variables
container run -e FOO=bar -e BAZ=qux myimage:latest

# Run with auto-remove
container run --rm -it alpine:latest /bin/sh

# Combined common flags
container run -d --name web -p 8080:80 -v ./html:/usr/share/nginx/html -e ENV=prod nginx:latest

# Run with resource limits (0.9.0+)
container run -d --name app --cpus 2 --memory 4g myapp:latest

# Run with read-only rootfs (0.8.0+)
container run --read-only -v tmpdata:/tmp myapp:latest

# Run with Rosetta x86_64 emulation (0.7.0+)
container run --rosetta -it amd64-image:latest /bin/bash

# Run with DNS configuration
container run --dns 8.8.8.8 --dns-search example.com myapp:latest

# Run with custom MAC address (0.7.0+)
container run --mac-address 02:42:ac:11:00:02 --network mynet myapp:latest

# Access host from container (0.9.0+)
# Use host.docker.internal to reach host services
container run -e API_URL=http://host.docker.internal:3000 myapp:latest

# Run with custom init image (0.10.0+)
container run --init-image custom-init:latest -d --name app myapp:latest

# Run with runtime selection (0.10.0+)
container run --runtime myruntime -d --name app myapp:latest

# Run with init process (0.11.0+)
container run --init -d --name app myapp:latest

# Run with reduced/custom capabilities (0.12.0+)
container run --cap-add NET_ADMIN myimage:latest
container run --cap-drop ALL --cap-add NET_BIND_SERVICE myimage:latest

# Run with a shared-memory size (1.0.0+)
container run --shm-size 1g -d --name app myapp:latest
```

Custom stop signals are set on `container stop`, not `container run` (1.0.0+):

```bash
container stop --signal SIGTERM app
```

### Manage Running Containers

```bash
# List running containers
container list
container ls

# List all containers (including stopped)
container list --all

# Start a stopped container
container start <name-or-id>

# Stop a running container
container stop <name-or-id>

# Kill a container (force stop)
container kill <name-or-id>

# Remove a container
container delete <name-or-id>
container rm <name-or-id>

# Execute command in running container
container exec -it <name-or-id> /bin/bash

# Execute command detached (0.7.0+)
container exec -d <name-or-id> /usr/bin/background-task

# View container logs
container logs <name-or-id>
container logs --follow <name-or-id>

# Inspect container details
container inspect <name-or-id>

# Copy files between host and container (1.0.0+)
container cp <name-or-id>:/path/in/container ./local-path
container cp ./local-file <name-or-id>:/path/in/container

# Container resource stats
container stats

# Remove all stopped containers
container prune
```

### Export Container (0.10.0+)

```bash
# Create an image from a running container (0.10.0+: running; 0.11.0+: stopped containers also supported)
container export <name-or-id> -o exported.tar

# Export with a tag
container export <name-or-id> -t myimage:snapshot
```

### Create Without Starting

```bash
# Create container without starting
container create --name myapp nginx:latest

# Start it later
container start myapp
```

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

```bash
# Pull an image
container image pull ubuntu:latest

# Pull with platform specification
container image pull --platform linux/arm64 nginx:latest
container image pull --arch arm64 --os linux nginx:latest

# List images
container image list
container image ls

# Tag an image
container image tag ubuntu:latest myregistry/ubuntu:v1

# Push to registry
container image push myregistry/ubuntu:v1

# Save image to archive
container image save ubuntu:latest -o ubuntu.tar

# Load image from archive
container image load -i ubuntu.tar

# Delete an image
container image delete ubuntu:latest

# Force delete an image (0.9.0+, verify flag with --help)
container image delete --force ubuntu:latest

# Inspect image metadata (enhanced output in 0.9.0+)
container image inspect ubuntu:latest

# Remove unused images
container image prune

# Remove all unused images, not just dangling (0.7.0+)
container image prune -a
```

### Platform Flags

When pulling or building images, specify the target platform:

```bash
--platform linux/arm64       # Full platform string
--arch arm64                 # Architecture only
--os linux                   # OS only
--scheme oci                 # Image scheme
```

Architecture aliases (0.8.0+): `amd64`=`x86_64`, `arm64`=`aarch64`

**Default platform (0.11.0+)**: Set `CONTAINER_DEFAULT_PLATFORM` to avoid specifying `--platform` on every pull/build:

```bash
export CONTAINER_DEFAULT_PLATFORM=linux/arm64
```

## Build

Build OCI-compatible images from Dockerfiles or Containerfiles:

```bash
# Build from current directory
container build -t myimage:latest .

# Build with specific Dockerfile
container build -t myimage:latest -f Dockerfile.prod .

# Build with build arguments
container build -t myimage:latest --build-arg VERSION=1.0 .

# Build without cache
container build -t myimage:latest --no-cache .

# Multi-stage build with target
container build -t myimage:latest --target builder .

# Build with platform
container build -t myimage:latest --platform linux/arm64 .

# Build with output
container build -t myimage:latest -o type=local,dest=./output .

# Build with multiple tags (0.6.0+)
container build -t myimage:latest -t myimage:v1.0 .

# Build with no network access (0.6.0+)
container build -t myimage:latest --network none .

# Build with DNS configuration (0.9.0+)
container build -t myimage:latest --dns 8.8.8.8 .

# Build from stdin (0.7.0+)
container build -t myimage:latest -f - . <<EOF
FROM alpine:latest
RUN echo "hello"
EOF
```

**Note**: When no `Dockerfile` is found, the builder falls back to `Containerfile` (0.6.0+).

### Builder Management

The builder runs as a separate process:

```bash
# Start the builder
container builder start

# Stop the builder
container builder stop

# Delete the builder
container builder delete

# Check builder status
container builder status
```

## Network Management

Create and manage container networks:

```bash
# Create a network
container network create mynetwork

# Create with subnet
container network create --subnet 10.0.0.0/24 mynetwork

# Create with labels
container network create --labels env=dev mynetwork

# List networks
container network list

# Inspect a network
container network inspect mynetwork

# Delete a network
container network delete mynetwork

# Remove unused networks
container network prune
```

**Network capabilities (0.8.0+)**: Full IPv6 support. Host-only and isolated network modes available in 0.9.0+ (verify flag syntax with `container network create --help`). `mtu` network attachment option available in 0.11.0+.

### Multi-Container Networking

```bash
# Create a shared network
container network create app-net

# Run containers on the network
container run -d --name db --network app-net postgres:latest
container run -d --name web --network app-net -p 8080:80 myapp:latest

# Containers can reach each other by name
container exec web curl http://db:5432
```

## Volume Management

Create and manage persistent volumes:

```bash
# Create a volume
container volume create mydata

# Create with size limit
container volume create -s 10G mydata

# Create with labels
container volume create --label env=prod mydata

# Create with driver options
container volume create --opt type=tmpfs mydata

# Create with journaling (0.12.0+)
container volume create --journal mydata

# List volumes
container volume list

# Inspect a volume
container volume inspect mydata

# Delete a volume
container volume delete mydata

# Remove unused volumes
container volume prune
```

### Using Volumes

```bash
# Mount a named volume
container run -v mydata:/data myimage:latest

# Mount a host directory (bind mount)
container run -v /host/path:/container/path myimage:latest

# Read-only mount
container run -v mydata:/data:ro myimage:latest
```

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
