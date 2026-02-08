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
- Migrating between Apple Container versions (0.4.x to 0.5.x)

## What is Apple Container?

Apple Container is a macOS-native tool for running Linux containers as lightweight virtual machines on Apple silicon:

- **Swift-based**: Built on Apple's Virtualization.framework
- **OCI-compatible**: Produces and runs standard OCI container images
- **Apple silicon only**: Requires Apple silicon Mac (M1 or later)
- **Pre-1.0**: Currently at version 0.5.0, breaking changes expected between minor versions
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

# Inspect image metadata
container image inspect ubuntu:latest

# Remove unused images
container image prune
```

### Platform Flags

When pulling or building images, specify the target platform:

```bash
--platform linux/arm64       # Full platform string
--arch arm64                 # Architecture only
--os linux                   # OS only
--scheme oci                 # Image scheme
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
```

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

## Version Differences (0.4.1 vs 0.5.0)

### Breaking Changes in 0.5.0

| Change | 0.4.1 | 0.5.0 |
|--------|-------|-------|
| Image listing | `container images` alias available | `container images` removed, use `container image list` |
| System properties | Scattered subcommands | Consolidated to `container system property` |
| Registry keychain | `com.apple.container` | `com.apple.container.registry` (re-login required) |

### New Features in 0.5.0

- Multi-image save (`container image save img1 img2 -o archive.tar`)
- Network labels (`container network create --labels key=val`)
- Kernel force set (`container system kernel set --force`)
- CVE-2026-20613 fix
- Dependencies: Containerization 0.9.1, CZ 0.8.0, Builder shim 0.6.1

### Migration Checklist (0.4.x to 0.5.0)

1. Replace `container images` with `container image list` in scripts
2. Update system property commands to use `container system property`
3. Re-login to registries (keychain ID changed)
4. Review scripts for removed aliases
5. Test build workflows (builder shim updated to 0.6.1)

See `templates/0.4.1/commands.md` and `templates/0.5.0/commands.md` for version-specific details.

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
