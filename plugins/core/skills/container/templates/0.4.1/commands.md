# Apple Container CLI - Version 0.4.1 Commands

Last stable release in the 0.4.x series.

## Container Lifecycle

| Command | Description |
|---------|-------------|
| `container run` | Create and start a container |
| `container create` | Create a container without starting |
| `container start` | Start a stopped container |
| `container stop` | Stop a running container |
| `container kill` | Force stop a container |
| `container delete` / `rm` | Remove a container |
| `container exec` | Execute a command in a running container |
| `container logs` | View container logs |
| `container inspect` | Show container details |
| `container stats` | Show container resource usage |
| `container prune` | Remove all stopped containers |
| `container list` / `ls` | List containers |

## Image Management

| Command | Description |
|---------|-------------|
| `container image pull` | Pull an image from a registry |
| `container image push` | Push an image to a registry |
| `container image save` | Save an image to an archive |
| `container image load` | Load an image from an archive |
| `container image tag` | Tag an image |
| `container image delete` | Remove an image |
| `container image inspect` | Show image metadata |
| `container image prune` | Remove unused images |
| `container image list` / `ls` | List images |
| `container images` | **Alias for `image list`** (removed in 0.5.0) |

## Build

| Command | Description |
|---------|-------------|
| `container build` | Build an image from a Dockerfile/Containerfile |
| `container builder start` | Start the builder process |
| `container builder stop` | Stop the builder process |
| `container builder delete` | Delete the builder |
| `container builder status` | Check builder status |

## Volume Management

| Command | Description |
|---------|-------------|
| `container volume create` | Create a volume |
| `container volume delete` | Remove a volume |
| `container volume list` | List volumes |
| `container volume inspect` | Show volume details |
| `container volume prune` | Remove unused volumes |

## System Management

| Command | Description |
|---------|-------------|
| `container system start` | Start the system service |
| `container system stop` | Stop the system service |
| `container system status` | Check service status |
| `container system version` | Show CLI version |
| `container system logs` | View system logs |
| `container system df` | Show disk usage |

### System Properties (Pre-Consolidation)

In 0.4.1, system properties are accessed via scattered subcommands. In 0.5.0, these are consolidated under `container system property`.

### System DNS

| Command | Description |
|---------|-------------|
| `container system dns create` | Create a DNS entry |
| `container system dns delete` | Delete a DNS entry |
| `container system dns list` | List DNS entries |

### System Kernel

| Command | Description |
|---------|-------------|
| `container system kernel set` | Set a custom kernel (no `--force` flag) |

## Registry

| Command | Description |
|---------|-------------|
| `container registry login` | Log in to a registry |
| `container registry logout` | Log out from a registry |

**Keychain ID**: `com.apple.container` (changed in 0.5.0)

## Known Issues Fixed in 0.5.0

- Relative bind mount regression
- Symlink handling in volume mounts
- Platform filtering when pulling multi-arch images
