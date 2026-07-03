# Apple Container CLI - Version 1.0.0 Commands

Changes from 0.12.3.

## Breaking Changes from 0.12.3

> **CRITICAL — Configuration model change.** A TOML configuration file replaces the UserDefaults-backed system properties. `container system property get`, `set`, and `clear` are REMOVED.
>
> **Migration required:** Move stored property values (e.g. `container.cpus`, `container.memory`, `build.cpus`, `build.memory`) into `~/.config/container/config.toml`, then restart the service with `container system stop && container system start`.

| Change | Migration |
|--------|-----------|
| TOML config file replaces system properties; `property get/set/clear` removed | Move settings into `~/.config/container/config.toml` (`[container]` `cpus`/`memory`, etc.) |
| Structured (JSON/YAML/TOML) output shape changed for `container`/`image`/`network`/`volume` `ls` and `inspect` | Update scripts and automation that parse structured output |
| Application major version 0 XPC API compatibility removed | Update XPC API consumers |

## New Features in 1.0.0

- `container machine` (alias `m`) — long-lived Linux environments with tight host integration
- `container cp` — copy files between host and container
- `-s`/`--signal` option on `container stop`
- `--shm-size` option for shared-memory sizing
- Image `variant` support
- `container help <subcommand>` fixed
- `system df` accounting fixes
- XPC-connection-as-lease fixes IP address leaks

## Container Machines

| Command | Description |
|---------|-------------|
| `container machine create <image> --name <name>` | Create a machine from an image |
| `container machine run [-n <name>] [-- command]` | Open a shell or run a single command |
| `container machine set-default <name>` | Set the default machine (omit `-n` afterward) |
| `container machine ls` | List machines |
| `container machine inspect <name>` | Show machine details as JSON |
| `container machine stop <name>` | Stop a machine |
| `container machine rm <name>` | Delete a machine |
| `container machine set -n <name> cpus=<N> memory=<size>` | Update machine resources (stop, then run to apply) |

```bash
container machine create alpine:latest --name dev
container machine run -n dev uname -a
container machine run -n dev -- cat /proc/cpuinfo
container machine set-default dev
container machine run

container machine set -n dev cpus=4 memory=8G
container machine stop dev
container machine run -n dev -- nproc
```

- Host home directory auto-mounts at `/Users/<username>` inside the machine; machine user matches host UID/GID.
- Custom machine images require `/sbin/init` (a process supervisor such as systemd).
- Optional first-boot script `/etc/machine/create-user.sh` receives `CONTAINER_UID`, `CONTAINER_GID`, `CONTAINER_USER`, `CONTAINER_HOME`, `CONTAINER_MACHINE_ID`.

```bash
container build -t local/ubuntu-machine:latest .
container machine create local/ubuntu-machine:latest --name ubuntu
```

## System Configuration (TOML)

Configuration sources, first match wins; missing keys fall back to built-in defaults:

1. `~/.config/container/config.toml` (user)
2. `<installRoot>/etc/container/config.toml` (package-shipped)

Top-level tables: `[container]`, `[dns]`, `[build]`, `[kernel]`, `[network]`, `[registry]`, `[vminit]`.

```toml
[container]
cpus = 8
memory = "4g"

[dns]
domain = "test"
```

```bash
# Apply changes
container system stop
container system start

# Read-only view of the merged configuration
container system property list --format json
```

## Container Lifecycle

| Command | Description |
|---------|-------------|
| `container cp` | **New** — copy files between host and container |
| `container run` | `--shm-size` option added |
| `container stop` | `-s`/`--signal` option added |

```bash
container cp mycontainer:/var/log/app.log ./app.log
container cp ./config.yml mycontainer:/etc/app/config.yml
container run --shm-size 1g -d --name app myapp:latest
container stop --signal SIGTERM app
```

## Output Formats

Structured (JSON, YAML, TOML) output shape was cleaned up for `container`, `image`, `network`, and `volume` `ls` and `inspect`. Scripts parsing these outputs against pre-1.0.0 shapes require updates — verify field names against live output before depending on them.
