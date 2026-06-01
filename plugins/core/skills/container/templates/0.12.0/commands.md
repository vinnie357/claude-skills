# Apple Container CLI - Version 0.12.0 Commands

Changes from 0.11.0.

## Breaking Changes from 0.11.0

> **CRITICAL — Capability model change.** The default Linux capability set has been **REDUCED** in 0.12.0. Existing containers created with prior versions run with a broader capability set than new containers will receive.
>
> **Migration required:** Delete and recreate all existing containers to apply the reduced default capability set. Containers that need elevated capabilities must use `--cap-add` to restore them. Containers that do not need existing defaults should use `--cap-drop` to reduce their surface.

| Change | Migration |
|--------|-----------|
| Default Linux capability set REDUCED | Delete & recreate all existing containers |
| `--cap-add` / `--cap-drop` flags added to `run`/`create` | Use `--cap-add` to restore needed capabilities |
| Builder-shim gRPC protocol changed | Incompatible with pre-0.12.0 clients — update all builder clients |

## New Features in 0.12.0

- `--cap-add` / `--cap-drop` flags on `container run` / `container create`
- Plain and color progress output modes; auto-falls back to plain when stderr is not a TTY
- YAML output format support
- TOML-based plugin configuration files
- `SSH_AUTH_SOCK` passthrough after user login
- Kernel updated to kata-3.28.0
- `journal` option for `container volume create`
- Single-file-mount fix
- Improved `image save` platform error messaging

## Container Lifecycle

| Command | Description |
|---------|-------------|
| `container run` | **`--cap-add`/`--cap-drop` flags added; reduced default capability set** |
| `container create` | **`--cap-add`/`--cap-drop` flags added; reduced default capability set** |

### Capability Flags

```bash
# Add a capability
container run --cap-add NET_ADMIN myimage:latest

# Drop a capability
container run --cap-drop ALL --cap-add NET_BIND_SERVICE myimage:latest
```

## Volume Management

| Option | Description |
|--------|-------------|
| `--journal` | **Enable journaling for a volume (0.12.0+)** |

```bash
# Create a volume with journaling
container volume create --journal mydata
```

## Output Formats

| Feature | Description |
|---------|-------------|
| YAML output | **`--format yaml` now supported where format flags are accepted** |
| Progress output | **Plain/color modes; auto-plain when stderr is not a TTY** |

## Plugin Configuration

TOML-based plugin configuration files supported in 0.12.0+.

## SSH Auth

`SSH_AUTH_SOCK` is now passed through to containers after user login.

## Dependencies

- Kernel: kata-3.28.0
