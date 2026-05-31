# Apple Container CLI - Version 0.11.0 Commands

Changes from 0.10.0.

## Breaking Changes from 0.10.0

None. 0.11.0 is a non-breaking release.

## New Features in 0.11.0

- `container export` (OCI layout tar) for **stopped** containers
- Build secrets support in `container build`
- `--init` flag on `container run`/`container create`
- `CONTAINER_DEFAULT_PLATFORM` environment variable (sets default image platform)
- `mtu` option for network attachments
- Configurable default CPU/memory via system properties: `container.cpus`, `container.memory`, `build.cpus`, `build.memory`
- Dockerfile-specific ignore files support
- ARG-parsing and docker-ignore bug fixes

## Container Lifecycle

| Command | Description |
|---------|-------------|
| `container run` | **`--init` flag: run an init process in the container** |
| `container create` | **`--init` flag: run an init process in the container** |
| `container export` | **Writes OCI layout tar for a STOPPED container** |

## Build

| Feature | Description |
|---------|-------------|
| Build secrets | **Pass secrets to build steps without baking into image layers** |
| Dockerfile ignore files | **Dockerfile-specific `.dockerignore` files now respected** |

## System Properties (0.11.0+)

| Property | Description |
|----------|-------------|
| `container.cpus` | Default CPU count for new containers |
| `container.memory` | Default memory for new containers |
| `build.cpus` | Default CPU count for image builds |
| `build.memory` | Default memory for image builds |

```bash
# Set default resources
container system property set container.cpus 2
container system property set container.memory 2g
container system property set build.cpus 4
container system property set build.memory 4g
```

## Network

| Option | Description |
|--------|-------------|
| `mtu` | **Network attachment MTU option (0.11.0+)** |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CONTAINER_DEFAULT_PLATFORM` | Sets default image platform (e.g., `linux/arm64`) |

## Bug Fixes

- ARG-parsing fix in Dockerfile handling
- Docker-ignore bug fixes

## Dependencies

- No dependency version changes listed for this release
