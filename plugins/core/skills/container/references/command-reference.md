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
| `--init` | | Run an init process in the container (0.11.0+) |
| `--init-image` | | Init image for VM (0.10.0+ selection support) |
| `--kernel` | | Custom kernel for VM |
| `--virtualization` | | Virtualization backend |
| `--runtime` | | Container runtime (0.10.0+) |
| `--cap-add` | | Add a Linux capability (0.12.0+) |
| `--cap-drop` | | Drop a Linux capability (0.12.0+) |
| `--stop-signal` | | Signal sent to stop the container (1.0.0+) |
| `--shm-size` | | Shared-memory size, e.g., `1g` (1.0.0+) |
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

Accepts all the same flags as `container run` except `--detach`. Includes `--read-only` (0.8.0+), `--cpus`/`--memory` (0.9.0+), `--init`/`--init-image`/`--runtime` (0.10.0+), `--cap-add`/`--cap-drop` (0.12.0+), and all DNS flags.

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

### `container cp`

Copy files between the host and a container. (1.0.0+)

```
container cp CONTAINER:SRC_PATH DEST_PATH
container cp SRC_PATH CONTAINER:DEST_PATH
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

### `container export`

Create an OCI layout tar from a container. (0.10.0+; 0.11.0+ supports stopped containers)

```
container export [FLAGS] CONTAINER
```

| Flag | Short | Description |
|------|-------|-------------|
| `--output` | `-o` | Output file path |
| `--tag` | `-t` | Name and tag for the exported image |

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

**Note (0.12.3+)**: Prints the image reference to stdout on success, enabling scripting/automation to capture the pushed reference.

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
| `--mtu` | MTU for the network attachment (0.11.0+) |

**Note**: Full IPv6 support in 0.8.0+. Host-only and isolated network capabilities in 0.9.0+ (verify flag syntax with `container network create --help`). MTU network attachment option added in 0.11.0+.

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
| `--journal` | | Enable journaling for the volume (0.12.0+) |

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

### `container registry list`

List configured container registries. (0.10.0+)

```
container registry list
```

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
container system status [FLAGS]
```

| Flag | Description |
|------|-------------|
| `--format` | Output format (e.g., `json`) (0.10.0+) |

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

List the merged system configuration. (0.5.0+ consolidated; read-only view of `config.toml` in 1.0.0+)

```
container system property list [--format json]
container system property ls
```

### `container system property get` / `set` / `clear`

**REMOVED in 1.0.0.** A TOML configuration file at `~/.config/container/config.toml` (fallback `<installRoot>/etc/container/config.toml`) replaces the UserDefaults-backed properties. Edit the file, then restart the service with `container system stop && container system start`. Pre-1.0.0 syntax:

```
container system property get KEY     # removed in 1.0.0
container system property set KEY VALUE   # removed in 1.0.0
container system property clear KEY   # removed in 1.0.0
```

### `container system dns create`

Create a DNS entry.

```
container system dns create NAME IP
```

**Security (0.12.3+)**: Path/rule injection is prevented — inputs are sanitized.

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

## Machine Management (1.0.0+)

Long-lived Linux environments with tight host integration. Subcommand alias: `m`.

### `container machine create`

Create a machine from an image. The image requires `/sbin/init`; an optional first-boot script `/etc/machine/create-user.sh` receives `CONTAINER_UID`, `CONTAINER_GID`, `CONTAINER_USER`, `CONTAINER_HOME`, and `CONTAINER_MACHINE_ID`.

```
container machine create IMAGE --name NAME
```

### `container machine run`

Open an interactive shell, or run a single command. Host home directory is mounted at `/Users/<username>` inside the machine.

```
container machine run [-n NAME] [-- COMMAND [ARGS...]]
```

### `container machine set-default`

Set the default machine so `-n` is optional afterward.

```
container machine set-default NAME
```

### `container machine ls` / `inspect` / `stop` / `rm`

```
container machine ls
container machine inspect NAME
container machine stop NAME
container machine rm NAME
```

### `container machine set`

Update machine resources. Stop and run the machine to apply.

```
container machine set -n NAME cpus=N memory=SIZE
```

## Environment Variables (0.11.0+)

| Variable | Description |
|----------|-------------|
| `CONTAINER_DEFAULT_PLATFORM` | Sets the default image platform (e.g., `linux/arm64`). Applies to `image pull`, `container run`, and `container build` when `--platform` is not specified. |

## Output Formats (0.12.0+)

Commands that accept `--format` support these values:

| Format | Description |
|--------|-------------|
| `json` | JSON output (0.10.0+) |
| `yaml` | YAML output (0.12.0+) |

Progress output modes (0.12.0+):

| Mode | Description |
|------|-------------|
| `plain` | Plain text progress output |
| `color` | Colored progress output |
| (auto) | Automatically falls back to `plain` when stderr is not a TTY |

**Note (1.0.0)**: The structured (JSON, YAML, TOML) output shape was cleaned up for `container`, `image`, `network`, and `volume` `ls` and `inspect`. Scripts parsing pre-1.0.0 shapes require updates.

## Build Secrets (0.11.0+)

Build secrets can be passed to build steps without baking them into image layers. Use the `--secret` flag with `container build`:

```bash
container build --secret id=mysecret,src=/path/to/secret -t myimage:latest .
```

Reference the secret in a Dockerfile using `RUN --mount=type=secret`.

## Plugin Configuration (0.12.0+)

TOML-based plugin configuration files are supported. Plugin config files allow per-plugin settings without modifying the main container configuration.
