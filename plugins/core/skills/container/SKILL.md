---
name: container
description: Guide for using Apple Container CLI to run Linux containers on Apple silicon Macs (macOS 26+). Use when managing OCI containers, building images, configuring networks/volumes, or working with container system services on macOS.
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
- Migrating between Apple Container versions (0.5.x to 0.9.x)

## What is Apple Container?

Apple Container is a macOS-native tool for running Linux containers as lightweight virtual machines on Apple silicon:

- **Swift-based**: Built on Apple's Virtualization.framework
- **OCI-compatible**: Produces and runs standard OCI container images
- **Apple silicon only**: Requires Apple silicon Mac (M1 or later)
- **Pre-1.0**: Currently at version 0.9.0, breaking changes expected between minor versions
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

# Show CLI version
container system version

# View system logs
container system logs

# Show disk usage
container system df
```

### System Properties

Configure system-level settings (consolidated in 0.5.0):

```bash
# List all properties
container system property list

# Get a specific property
container system property get <key>

# Set a property
container system property set <key> <value>

# Clear a property
container system property clear <key>
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

# Container resource stats
container stats

# Remove all stopped containers
container prune
```

### Create Without Starting

```bash
# Create container without starting
container create --name myapp nginx:latest

# Start it later
container start myapp
```

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

**Network capabilities (0.8.0+)**: Full IPv6 support. Host-only and isolated network modes available in 0.9.0+ (verify flag syntax with `container network create --help`).

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
```

**Note**: In 0.5.0, the keychain ID changed from `com.apple.container` to `com.apple.container.registry`. Re-login is required after upgrading from 0.4.x.

## Version Differences (0.5.0 to 0.9.0)

### Breaking Changes

| Version | Change | Migration |
|---------|--------|-----------|
| 0.6.0 | Image store directory moved from `.build` to `builder` | Update paths referencing `.build` |
| 0.7.0 | `--disable-progress-updates` removed | Use `--progress none\|ansi` instead |
| 0.8.0 | Client API reorganization | Update API consumers |
| 0.8.0 | Subnet allocation defaults changed | Review network configurations |

### New Features by Release

**0.6.0**: Multiple `--tag` on build, `--network none`, `network create --subnet`, anonymous volumes, `volume prune`, Containerfile fallback, DNS list `--format`/`--quiet`

**0.7.0**: `--rosetta` flag, image download progress, stdio save/load, Dockerfile from stdin, `container stats`, port range publishing, `--mac-address`, `system df`, `image prune -a`, `exec -d` (detached), network creationDate

**0.8.0**: `--read-only` for run/create, architecture aliases (amd64/arm64/x86_64/aarch64), `network prune`, full IPv6, volume relative paths, env vars from named pipes, CVE-2026-20613 fix

**0.9.0**: Resource limits (`--cpus`/`--memory`), `host.docker.internal`, host-only/isolated networks, `--dns` on build, `--force` on image delete, zstd compression, container prune improvements, enhanced image inspection, Kata 3.26.0 kernel

### Migration Checklist (0.5.x to 0.9.0)

1. Replace `--disable-progress-updates` with `--progress none` in scripts
2. Update any paths referencing `.build` directory to `builder`
3. Review subnet configurations (allocation defaults changed in 0.8.0)
4. Update API consumers for client API reorganization (0.8.0)
5. Test build workflows with updated dependencies

### Dependencies

| Version | Containerization | Other |
|---------|-----------------|-------|
| 0.5.0 | 0.9.1 | Builder shim 0.6.1 |
| 0.6.0 | 0.12.1 | |
| 0.7.0 | 0.16.0 | Builder shim 0.7.0 |
| 0.8.0 | 0.21.1 | |
| 0.9.0 | 0.24.0 | Kata 3.26.0 |

See `templates/<version>/commands.md` for version-specific details (0.4.1, 0.5.0, 0.6.0, 0.7.0, 0.8.0, 0.9.0).

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

Container run/stop/exec/logs:

```bash
# List running containers
nu scripts/container-lifecycle.nu ps

# Run a container
nu scripts/container-lifecycle.nu run ubuntu:latest

# View logs
nu scripts/container-lifecycle.nu logs mycontainer

# Execute command
nu scripts/container-lifecycle.nu exec mycontainer /bin/bash
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

- **Pre-1.0 software**: Breaking changes expected between minor versions
- **Apple silicon only**: No Intel Mac support
- **macOS 26+ required**: Not available on earlier macOS versions
- **OCI-compatible**: Standard container images work as expected
- **Lightweight VMs**: Each container is an isolated lightweight VM
- **System service**: Start the system service before running containers
