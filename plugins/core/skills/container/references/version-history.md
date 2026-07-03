# Apple Container CLI - Version History

Per-release feature history, the full migration checklist, and the dependency matrix for Apple Container 0.5.0 through 1.0.0. Breaking changes are summarized in SKILL.md; version-specific command snapshots live in `templates/<version>/commands.md`.

## New Features by Release

**0.6.0**: Multiple `--tag` on build, `--network none`, `network create --subnet`, anonymous volumes, `volume prune`, Containerfile fallback, DNS list `--format`/`--quiet`

**0.7.0**: `--rosetta` flag, image download progress, stdio save/load, Dockerfile from stdin, `container stats`, port range publishing, `--mac-address`, `system df`, `image prune -a`, `exec -d` (detached), network creationDate

**0.8.0**: `--read-only` for run/create, architecture aliases (amd64/arm64/x86_64/aarch64), `network prune`, full IPv6, volume relative paths, env vars from named pipes, CVE-2026-20613 fix

**0.9.0**: Resource limits (`--cpus`/`--memory`), `host.docker.internal`, host-only/isolated networks, `--dns` on build, `--force` on image delete, zstd compression, container prune improvements, enhanced image inspection, Kata 3.26.0 kernel

**0.10.0**: `--init-image` selection, `container export`, `--runtime` flag, `container registry list`, `--format` on `system status`, minimum memory validation, multiple network plugins, SELinux kernel panic fix, env var duplication fix

**0.11.0**: `container export` for stopped containers, build secrets, `--init` flag for run/create, `CONTAINER_DEFAULT_PLATFORM` env var, `mtu` network attachment option, system properties `container.cpus`/`container.memory`/`build.cpus`/`build.memory`, Dockerfile-specific ignore files, ARG-parsing and docker-ignore bug fixes

> **⚠ BREAKING — 0.12.0 capability change:** The default Linux capability set was **reduced**. Users MUST delete and recreate existing containers to apply the new defaults. Use `--cap-add` to restore capabilities; use `--cap-drop` to further restrict them. See `templates/0.12.0/commands.md` for details.

**0.12.0**: `--cap-add`/`--cap-drop` on run/create, plain/color progress modes (auto-plain when stderr non-TTY), YAML output format, TOML plugin config files, `SSH_AUTH_SOCK` passthrough, kernel kata-3.28.0, `journal` option for `volume create`, single-file-mount fix, improved `image save` error messaging

**0.12.1**: macOS 15 (Sequoia) compat — `network list` and `network delete` now work on macOS 15

**0.12.3** (security): HTTP downgrade prevention in registry commands, path/rule injection prevention in `system dns`, `image push` prints image reference to stdout on success

> **⚠ BREAKING — 1.0.0 configuration change:** A TOML configuration file (`~/.config/container/config.toml`) replaces the UserDefaults-backed system properties. `container system property get`, `set`, and `clear` are REMOVED; `property list` remains as a read-only view of the merged configuration. Structured (JSON/YAML/TOML) output shape changed for `container`/`image`/`network`/`volume` `ls` and `inspect`. Application major version 0 XPC API compatibility was removed. See `templates/1.0.0/commands.md` for details.

**1.0.0**: `container machine` (alias `m`) for long-lived Linux environments with tight host integration, `container cp` for host-container file copy, `-s`/`--signal` on `container stop`, `--shm-size` on `container run`, image `variant` support, `container help <subcommand>` fixed, `system df` accounting fixes, XPC-connection-as-lease fixes IP address leaks

## Migration Checklist (0.5.x to 1.0.0)

1. Replace `--disable-progress-updates` with `--progress none` in scripts
2. Update any paths referencing `.build` directory to `builder`
3. Review subnet configurations (allocation defaults changed in 0.8.0)
4. Update API consumers for client API reorganization (0.8.0)
5. Test build workflows with updated dependencies
6. Update API consumers for generic ClientContainer interface (0.10.0)
7. Move bundle creation code from main container operations to SandboxService (0.10.0)
8. Review network configurations for multiple network plugins model (0.10.0)
9. **0.12.0 REQUIRED**: Delete and recreate all existing containers (reduced default capability set)
10. **0.12.0 REQUIRED**: Update builder clients (gRPC protocol changed, incompatible with older clients)
11. Add `--cap-add` flags to any containers that require elevated capabilities (0.12.0+)
12. **1.0.0 REQUIRED**: Move `container system property set` values into `~/.config/container/config.toml`, then `container system stop && container system start`
13. **1.0.0 REQUIRED**: Update automation that parses `ls`/`inspect` structured output (JSON/YAML/TOML shape changed for container, image, network, and volume commands)
14. Update XPC API consumers — application major version 0 XPC API compatibility removed in 1.0.0

## Dependencies

| Version | Containerization | Other |
|---------|-----------------|-------|
| 0.5.0 | 0.9.1 | Builder shim 0.6.1 |
| 0.6.0 | 0.12.1 | |
| 0.7.0 | 0.16.0 | Builder shim 0.7.0 |
| 0.8.0 | 0.21.1 | |
| 0.9.0 | 0.24.0 | Kata 3.26.0 |
| 0.10.0 | 0.26.2 | |

Dependency versions for releases after 0.10.0 require verification against the upstream release notes before being added here.
