# Sandboxing — Full Flag Reference and Platform Support

mise sandboxing is a lightweight process-isolation feature for `mise exec` and `mise run` that restricts filesystem, network, and environment-variable access using OS-level primitives — not a container, not a VM. Enable the feature flag before using any sandbox options:

```bash
mise settings experimental=true
```

## Platform support

| Platform | Filesystem | Network | Per-host net filter |
|----------|------------|---------|---------------------|
| Linux (kernel 5.13+) | Landlock | seccomp-bpf | No (all-or-nothing in v1) |
| macOS | Seatbelt | Seatbelt | Yes |
| Windows | unsupported | unsupported | unsupported |

## Allow/deny flags

Deny flags (apply to `mise exec` / `mise run`):
- `--deny-all` — deny filesystem, network, and env by default
- `--deny-read` — deny all filesystem reads
- `--deny-write` — deny all filesystem writes
- `--deny-net` — deny all network access
- `--deny-env` — deny all environment variables

Allow flags (grant specific access back):
- `--allow-read=<path>` — grant read access to a path
- `--allow-write=<path>` — grant write access to a path
- `--allow-net=<host>` — grant access to a specific host (macOS only for per-host filtering)
- `--allow-env=<var>` — grant access to an env var; supports globs (e.g. `MYAPP_*`)

```bash
mise x --deny-all --allow-read=. --allow-write=./dist --allow-net=registry.npmjs.org -- npm install
```

## Task-level config

Define sandbox policy inline in `mise.toml`:

```toml
[tasks.build]
run = "npm run build"
deny_net = true
allow_write = ["./dist"]
```

Task-level keys map 1:1 to CLI flags. CLI flags override task config when both are present.

## Limitations

- `mise settings experimental=true` is required; without it, deny/allow flags are silently no-ops.
- Linux v1 lacks per-host network filtering — network access is all-or-nothing.
- Landlock failures terminate the command immediately on Linux.
- Windows is unsupported; commands run unsandboxed with a warning.

## See also

- `templates/sandboxing.md` (in this skill's `templates/` directory) — runnable examples for task-level and ad-hoc sandbox invocations.
