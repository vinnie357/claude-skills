# Apple Container CLI - Command Reference

Exhaustive reference for all Apple Container CLI commands and their flags/options.

## Container Lifecycle

### `container run`

Create and start a container from an image.

```
container run [FLAGS] IMAGE [COMMAND] [ARGS...]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--interactive` | `-i` | Keep STDIN open |
| `--tty` | `-t` | Allocate a pseudo-TTY |
| `--detach` | `-d` | Run in background |
| `--name` | | Assign a name to the container |
| `--rm` | | Automatically remove container when it exits |
| `--publish` | `-p` | Publish port(s) `host:container` |
| `--volume` | `-v` | Bind mount a volume `host:container[:ro]` |
| `--env` | `-e` | Set environment variable `KEY=VALUE` |
| `--network` | | Connect to a network |
| `--platform` | | Target platform (e.g., `linux/arm64`) |
| `--user` | `-u` | Run as user `UID[:GID]` |
| `--workdir` | `-w` | Working directory inside the container |
| `--entrypoint` | | Override default entrypoint |
| `--hostname` | `-h` | Container hostname |
| `--restart` | | Restart policy (`no`, `always`, `on-failure`) |
| `--cpus` | | CPU limit (0.9.0+) |
| `--memory` | | Memory limit, e.g., `4g` (0.9.0+) |
| `--read-only` | | Read-only rootfs (0.8.0+) |
| `--rosetta` | | Enable Rosetta x86_64 emulation (0.7.0+) |
| `--mac-address` | | Custom MAC address (0.7.0+) |
| `--dns` | | DNS server address |
| `--dns-domain` | | DNS domain |
| `--dns-option` | | DNS option |
| `--dns-search` | | DNS search domain |
| `--no-dns` | | Disable DNS |
| `--mount` | | Mount specification |
| `--tmpfs` | | Mount a tmpfs filesystem |
| `--cidfile` | | Write container ID to file |
| `--publish-socket` | | Publish a socket |
| `--init-image` | | Init image for VM |
| `--kernel` | | Custom kernel for VM |
| `--virtualization` | | Virtualization backend |
| `--runtime` | | Container runtime |
| `--scheme` | | Image scheme |
| `--progress` | | Progress output (`none`, `ansi`) (0.7.0+) |
| `--gid` | | Group ID |
| `--uid` | | User ID |

Common combinations:
- `-it` - Interactive terminal session
- `-d --name` - Named background service
- `-d -p -v -e --name --rm` - Full service with ports, volumes, env vars

### `container create`

Create a container without starting it.

```
container create [FLAGS] IMAGE [COMMAND] [ARGS...]
```

Accepts all the same flags as `container run` except `--detach`. Includes `--read-only` (0.8.0+), `--cpus`/`--memory` (0.9.0+), and all DNS flags.

### `container start`

Start one or more stopped containers.

```
container start CONTAINER [CONTAINER...]
```

### `container stop`

Stop one or more running containers.

```
container stop CONTAINER [CONTAINER...]
```

### `container kill`

Force stop one or more running containers.

```
container kill CONTAINER [CONTAINER...]
```

| Flag | Description |
|------|-------------|
| `--signal` | Signal to send (default: SIGKILL) |

### `container delete` / `container rm`

Remove one or more containers.

```
container delete CONTAINER [CONTAINER...]
container rm CONTAINER [CONTAINER...]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Force removal of running container |

### `container exec`

Execute a command in a running container.

```
container exec [FLAGS] CONTAINER COMMAND [ARGS...]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--interactive` | `-i` | Keep STDIN open |
| `--tty` | `-t` | Allocate a pseudo-TTY |
| `--detach` | `-d` | Run in background (0.7.0+) |
| `--env` | `-e` | Set environment variable |
| `--workdir` | `-w` | Working directory |
| `--user` | `-u` | Run as user |

### `container logs`

Fetch logs of a container.

```
container logs [FLAGS] CONTAINER
```

| Flag | Short | Description |
|------|-------|-------------|
| `--follow` | `-f` | Follow log output |
| `--tail` | `-n` | Number of lines from end |
| `--timestamps` | `-t` | Show timestamps |

### `container inspect`

Show detailed information about a container.

```
container inspect CONTAINER
```

### `container stats`

Display resource usage statistics for running containers.

```
container stats [CONTAINER...]
```

### `container prune`

Remove all stopped containers.

```
container prune
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip confirmation |

### `container list` / `container ls`

List containers.

```
container list [FLAGS]
container ls [FLAGS]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--all` | `-a` | Show all containers (including stopped) |
| `--quiet` | `-q` | Only show container IDs |
| `--format` | | Output format |

## Image Management

### `container image pull`

Pull an image from a registry.

```
container image pull [FLAGS] IMAGE
```

| Flag | Description |
|------|-------------|
| `--platform` | Target platform (e.g., `linux/arm64`) |
| `--arch` | Target architecture |
| `--os` | Target OS |
| `--scheme` | Image scheme (e.g., `oci`) |

### `container image push`

Push an image to a registry.

```
container image push IMAGE
```

### `container image save`

Save one or more images to a tar archive.

```
container image save [FLAGS] IMAGE [IMAGE...]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--output` | `-o` | Output file path |

**Notes**: Multi-image save added in 0.5.0. Stdio support added in 0.7.0+ (pipe to/from stdout/stdin).

### `container image load`

Load an image from a tar archive.

```
container image load [FLAGS]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--input` | `-i` | Input file path |

### `container image tag`

Create a new tag for an image.

```
container image tag SOURCE TARGET
```

### `container image delete`

Remove one or more images.

```
container image delete IMAGE [IMAGE...]
```

**Note**: `--force` flag available in 0.9.0+ (verify syntax with `container image delete --help`).

### `container image inspect`

Show detailed information about an image. Enhanced output in 0.9.0+.

```
container image inspect IMAGE
```

### `container image prune`

Remove unused images.

```
container image prune
```

| Flag | Short | Description |
|------|-------|-------------|
| `--all` | `-a` | Remove all unused images, not just dangling (0.7.0+) |
| `--force` | `-f` | Skip confirmation |

### `container image list` / `container image ls`

List images. Full size included in JSON output (0.9.0+).

```
container image list [FLAGS]
container image ls [FLAGS]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--quiet` | `-q` | Only show image IDs |
| `--format` | | Output format |

## Build

### `container build`

Build an image from a Dockerfile or Containerfile.

```
container build [FLAGS] PATH
```

| Flag | Short | Description |
|------|-------|-------------|
| `--tag` | `-t` | Name and optionally tag (`name:tag`) |
| `--file` | `-f` | Path to Dockerfile/Containerfile |
| `--build-arg` | | Set build-time variable `KEY=VALUE` |
| `--no-cache` | | Do not use cache |
| `--target` | | Set target build stage |
| `--platform` | | Target platform |
| `--output` | `-o` | Output destination (`type=local,dest=path`) |
| `--progress` | | Progress output (`none`, `ansi`) (0.7.0+, replaces `--disable-progress-updates`) |
| `--network` | | Network mode, e.g., `none` (0.6.0+) |
| `--pull` | | Pull policy |
| `--quiet` | `-q` | Suppress build output |
| `--cpus` | | CPU limit for build |
| `--memory` | | Memory limit for build |
| `--vsock-port` | | Vsock port for builder |
| `--dns` | | DNS server for build (0.9.0+) |

### `container builder start`

Start the builder process.

```
container builder start
```

### `container builder stop`

Stop the builder process.

```
container builder stop
```

### `container builder delete`

Delete the builder.

```
container builder delete
```

### `container builder status`

Check builder status.

```
container builder status
```

## Network Management

### `container network create`

Create a network.

```
container network create [FLAGS] NAME
```

| Flag | Description |
|------|-------------|
| `--subnet` | Subnet in CIDR format (e.g., `10.0.0.0/24`) (0.6.0+) |
| `--labels` | Labels for the network (0.5.0+) |

**Note**: Full IPv6 support in 0.8.0+. Host-only and isolated network capabilities in 0.9.0+ (verify flag syntax with `container network create --help`).

### `container network delete`

Remove a network.

```
container network delete NETWORK
```

### `container network list`

List networks.

```
container network list
```

### `container network inspect`

Show detailed information about a network.

```
container network inspect NETWORK
```

### `container network prune`

Remove unused networks.

```
container network prune
```

## Volume Management

### `container volume create`

Create a volume.

```
container volume create [FLAGS] [NAME]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--size` | `-s` | Size limit (e.g., `10G`) |
| `--label` | | Label for the volume |
| `--opt` | | Driver-specific options (e.g., `type=tmpfs`) |

### `container volume delete`

Remove a volume.

```
container volume delete VOLUME
```

### `container volume list`

List volumes.

```
container volume list
```

### `container volume inspect`

Show detailed information about a volume.

```
container volume inspect VOLUME
```

### `container volume prune`

Remove unused volumes.

```
container volume prune
```

## Registry

### `container registry login`

Log in to a container registry.

```
container registry login REGISTRY
```

Prompts for username and password. Credentials stored in macOS Keychain.

**Keychain ID**:
- 0.4.x: `com.apple.container`
- 0.5.0+: `com.apple.container.registry`

### `container registry logout`

Log out from a container registry.

```
container registry logout REGISTRY
```

## System Management

### `container system start`

Start the container system service.

```
container system start
```

### `container system stop`

Stop the container system service.

```
container system stop
```

### `container system status`

Check if the system service is running.

```
container system status
```

Exit code 0 if running, non-zero if not.

### `container system version`

Show the CLI version.

```
container system version
```

### `container system logs`

View system service logs.

```
container system logs
```

### `container system df`

Show disk usage of container resources.

```
container system df
```

### `container system property list`

List all system properties. (0.5.0+ consolidated)

```
container system property list
```

### `container system property get`

Get a system property value.

```
container system property get KEY
```

### `container system property set`

Set a system property value.

```
container system property set KEY VALUE
```

### `container system property clear`

Clear a system property.

```
container system property clear KEY
```

### `container system dns create`

Create a DNS entry.

```
container system dns create NAME IP
```

### `container system dns delete`

Delete a DNS entry.

```
container system dns delete NAME
```

### `container system dns list`

List DNS entries.

```
container system dns list
```

### `container system kernel set`

Set a custom Linux kernel.

```
container system kernel set [FLAGS] PATH
```

| Flag | Description |
|------|-------------|
| `--force` | Force set (0.5.0+ only) |
