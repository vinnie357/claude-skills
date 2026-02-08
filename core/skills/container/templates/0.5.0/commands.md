# Apple Container CLI - Version 0.5.0 Commands

Current release with breaking changes from 0.4.x.

## Breaking Changes from 0.4.1

| Change | 0.4.1 | 0.5.0 |
|--------|-------|-------|
| Image listing alias | `container images` available | `container images` **removed** - use `container image list` |
| System properties | Scattered subcommands | Consolidated to `container system property` subcommands |
| Registry keychain ID | `com.apple.container` | `com.apple.container.registry` (re-login required) |

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
| `container image save` | Save image(s) to an archive (**multi-image support added**) |
| `container image load` | Load an image from an archive |
| `container image tag` | Tag an image |
| `container image delete` | Remove an image |
| `container image inspect` | Show image metadata |
| `container image prune` | Remove unused images |
| `container image list` / `ls` | List images |

**Removed**: `container images` alias no longer available.

## Build

| Command | Description |
|---------|-------------|
| `container build` | Build an image from a Dockerfile/Containerfile |
| `container builder start` | Start the builder process |
| `container builder stop` | Stop the builder process |
| `container builder delete` | Delete the builder |
| `container builder status` | Check builder status |

## Network Management

| Command | Description |
|---------|-------------|
| `container network create` | Create a network (**`--labels` flag added**) |
| `container network delete` | Remove a network |
| `container network list` | List networks |
| `container network inspect` | Show network details |
| `container network prune` | Remove unused networks |

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

### System Properties (Consolidated)

| Command | Description |
|---------|-------------|
| `container system property list` | List all properties |
| `container system property get` | Get a property value |
| `container system property set` | Set a property value |
| `container system property clear` | Clear a property |

### System DNS

| Command | Description |
|---------|-------------|
| `container system dns create` | Create a DNS entry |
| `container system dns delete` | Delete a DNS entry |
| `container system dns list` | List DNS entries |

### System Kernel

| Command | Description |
|---------|-------------|
| `container system kernel set` | Set a custom kernel (**`--force` flag added**) |

## Registry

| Command | Description |
|---------|-------------|
| `container registry login` | Log in to a registry |
| `container registry logout` | Log out from a registry |

**Keychain ID**: `com.apple.container.registry` (changed from `com.apple.container`)

## New Features in 0.5.0

- **Multi-image save**: `container image save img1 img2 -o archive.tar`
- **Network labels**: `container network create --labels env=dev mynet`
- **Kernel force set**: `container system kernel set --force <path>`
- **CVE-2026-20613 fix**: Security vulnerability patched
- **Relative bind mount fix**: Regression from 0.4.x resolved
- **Symlink handling**: Fixed in volume mounts
- **Platform filtering**: Fixed for multi-arch image pulls

## Dependencies

- Containerization 0.9.1
- CZ 0.8.0
- Builder shim 0.6.1
