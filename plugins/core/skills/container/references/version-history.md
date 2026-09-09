# Apple Container CLI - Version History

Per-release feature history, the full migration checklist, and the dependency matrix for Apple Container 0.5.0 through 1.4.1. Breaking changes are summarized in SKILL.md; version-specific command snapshots live in `templates/<version>/commands.md`.

## New Features by Release

**0.6.0**: Multiple `--tag` on build, `--network none`, `network create --subnet`, anonymous volumes, `volume prune`, Containerfile fallback, DNS list `--format`/`--quiet`

**0.7.0**: `--rosetta` flag, image download progress, stdio save/load, Dockerfile from stdin, `container stats`, port range publishing, `--mac-address`, `system df`, `image prune -a`, `exec -d` (detached), network creationDate

**0.8.0**: `--read-only` for run/create, architecture aliases (amd64/arm64/x86_64/aarch64), `network prune`, full IPv6, volume relative paths, env vars from named pipes, CVE-2026-20613 fix

**0.9.0**: Resource limits (`--cpus`/`--memory`), `container system dns create --localhost` for named local DNS domains that redirect to the host (apple/container#346 — per upstream `docs/how-to.md`, `host.docker.internal` was an illustrative example name, not a hostname resolved automatically; see `templates/0.9.0/commands.md`), host-only/isolated networks, `--dns` on build, `--force` on image delete, zstd compression, container prune improvements, enhanced image inspection, Kata 3.26.0 kernel

**0.10.0**: `--init-image` selection, `container export`, `--runtime` flag, `container registry list`, `--format` on `system status`, minimum memory validation, multiple network plugins, SELinux kernel panic fix, env var duplication fix

**0.11.0**: `container export` for stopped containers, build secrets, `--init` flag for run/create, `CONTAINER_DEFAULT_PLATFORM` env var, `mtu` network attachment option, system properties `container.cpus`/`container.memory`/`build.cpus`/`build.memory`, Dockerfile-specific ignore files, ARG-parsing and docker-ignore bug fixes

> **⚠ BREAKING — 0.12.0 capability change:** The default Linux capability set was **reduced**. Users MUST delete and recreate existing containers to apply the new defaults. Use `--cap-add` to restore capabilities; use `--cap-drop` to further restrict them. See `templates/0.12.0/commands.md` for details.

**0.12.0**: `--cap-add`/`--cap-drop` on run/create, plain/color progress modes (auto-plain when stderr non-TTY), YAML output format, TOML plugin config files, `SSH_AUTH_SOCK` passthrough, kernel kata-3.28.0, `journal` option for `volume create`, single-file-mount fix, improved `image save` error messaging

**0.12.1**: macOS 15 (Sequoia) compat — `network list` and `network delete` now work on macOS 15

**0.12.3** (security): HTTP downgrade prevention in registry commands, path/rule injection prevention in `system dns`, `image push` prints image reference to stdout on success

> **⚠ BREAKING — 1.0.0 configuration change:** A TOML configuration file (`~/.config/container/config.toml`) replaces the UserDefaults-backed system properties. `container system property get`, `set`, and `clear` are REMOVED; `property list` remains as a read-only view of the merged configuration. Structured (JSON/YAML/TOML) output shape changed for `container`/`image`/`network`/`volume` `ls` and `inspect`. Application major version 0 XPC API compatibility was removed. See `templates/1.0.0/commands.md` for details.

**1.0.0**: `container machine` (alias `m`) for long-lived Linux environments with tight host integration, `container cp` for host-container file copy, `-s`/`--signal` on `container stop`, `--shm-size` on `container run`, image `variant` support, `container help <subcommand>` fixed, `system df` accounting fixes, XPC-connection-as-lease fixes IP address leaks

**1.1.0** (2026-07-06, fixes only, no CLI surface change): Unix domain socket mounts fixed for non-root containers (#1750), `container cp` relative source paths fixed (#1738), `container image save` reference list routed to stderr in stdout mode (#1804), duplicate "(default: 3)" removed from `--max-concurrent-downloads` help text (#1725), machine nested virtualization (#1742). None of this version's surface was checked against a live binary — release-notes only; see `templates/1.2.1/commands.md`.

**1.2.0** (2026-07-29, security release, no breaking changes): five security advisories (CVE-2026-64786/GHSA-xwgf-4rc5-p4m4, CVE-2026-64773/GHSA-wg28-286f-56v6, CVE-2026-64777/GHSA-2v2q-4q35-h585, GHSA-g57j-434g-5xj2, GHSA-5h49-6pr7-9mv4 — full descriptions in `templates/1.2.1/commands.md`), `--kernel-arg` (#1744, commit-log level only — not in the curated release-notes Highlights), OCI `maskedPaths`/`readonlyPaths` support added to the Container API (#1996). Release-notes only; not checked against a live binary.

**1.2.1** (2026-08-07, no breaking changes): `container k8s` plugin for a turnkey local Kubernetes cluster (#2043/#2044; the EXPERIMENTAL mark is observed on the 1.4.1 binary, not stated in the 1.2.1 notes), `container export` for LIVE containers (#1400/#1630 — previously stopped-only since 0.11.0), `--ssh` for `container build` (#1472/#1508 — takes a value; distinct from `run`/`create`'s bare `--ssh`, which dates from 0.4.1), `--read-only-path` and `--masked-path` for `container run` AND `container create` (#2041/#2069), overcommit/`max_map_count` VM defaults adjusted (#2055, specific values not stated upstream), `container-builder-shim` 0.13.1 (#2056). Release-notes only; the `k8s` subcommand list and the `--ssh`/`--masked-path`/`--read-only-path` flag text were later cross-checked against the live 1.4.1 binary — see `templates/1.2.1/commands.md`.

**1.2.2** (2026-08-08, packaging fix only, no CLI surface change): verbatim from the release notes, "This release fixes a glitch that prevented `container k8s` working when installed from the release package." (#2097)

> **⚠ BREAKING — 1.3.0 image-scheme default change:** Upstream marks this with its own CLI-breaking marker: "Removed `--scheme auto` for image operations, default is now `https`." (#2099/#2100) See `templates/1.3.1/commands.md` for the migration table.

**1.3.0** (2026-08-24, breaking — see above): `--scheme auto` removed for image operations, default now `https` (#2099/#2100); default Kata kernel now 3.32.0-debug (#2143); maskedPaths/readonlyPaths defaults relaxed for container **machines** specifically, reversing 1.2.0's #1996 default for machines (#2137); upstream docs reorganised (#2032); fixes to `tmpfsMounts()` path processing (#2103) and volume name validation in the volume disk-usage call (#2107).

**1.3.1** (2026-08-29, security patch release, no breaking changes): six security advisories via the containerization 0.42.0 bump (#2207 — GHSA-x7pf-2jmj-pgcq, GHSA-f689-h8m7-3jp2, GHSA-r3h2-rgqf-9hv9, CVE-2026-65388/GHSA-mx96-5vvg-x2mg, GHSA-697p-8837-37h3, GHSA-g3rx-2m58-rr63 — full descriptions in `templates/1.3.1/commands.md`), fix for `--mount type=tmpfs` leaving the tmpfs mount `source` field empty (#2138).

> **⚠ BREAKING — 1.4.1 `system status` output-shape change:** Upstream's own API-breaking marker: "`container system status` now reports host, client, paths, and resources" (#1769) — an output-schema change, not observable via `--help`. See `templates/1.4.1/commands.md` for the migration table.

**1.4.1** (2026-09-09): there was no 1.4.0 release — upstream states verbatim, "There was no 1.4.0 release, we had to discard that tag so this release contains every change since 1.3.1." (a `1.4.0` git tag exists, dated 2026-09-08, but carries no GitHub Release). New command `container clean` (#1949) — operates on RUNNING containers with explicit IDs, not a fix for accumulated stopped containers; JSON output no longer escapes forward slashes (#2205); security fixes GHSA-4587-w9mm-xxvh and GHSA-rgqp-277h-gcwj; containerization updated to 0.45.0 (#2250). Verified against a live 1.4.1 binary on 2026-09-09 (client-side `--help` only) — see `templates/1.4.1/commands.md` for full verification detail and what stayed unchanged (`container export`, `container system property`, no `--mac-address`).

## Migration Checklist (0.5.x to 1.4.1)

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
15. **1.3.0 REQUIRED**: Replace any `--scheme auto` usage on image operations — that value was removed; the default is now `https`, and explicit `--scheme http`/`--scheme https` still work
16. **1.4.1 REQUIRED**: Update any script or tool that parses `container system status` structured output (`--format json/yaml/toml`) for the new host/client/paths/resources field set

## Dependencies

| Version | Containerization | Other |
|---------|-----------------|-------|
| 0.5.0 | 0.9.1 | Builder shim 0.6.1 |
| 0.6.0 | 0.12.1 | |
| 0.7.0 | 0.16.0 | Builder shim 0.7.0 |
| 0.8.0 | 0.21.1 | |
| 0.9.0 | 0.24.0 | Kata 3.26.0 |
| 0.10.0 | 0.26.2 | |
| 1.1.0 | 0.35.0 | |
| 1.2.0 | 0.40.1 | Builder shim 0.13.0 |
| 1.2.1 | | Builder shim 0.13.1 |
| 1.2.2 | | |
| 1.3.0 | | Kata 3.32.0-debug |
| 1.3.1 | 0.42.0 | |
| 1.4.1 | 0.45.0 | |

Dependency versions for releases between 0.10.0 and 1.1.0, and any cell left blank above (1.2.1, 1.2.2, and 1.3.0 do not state a containerization version in their release notes), require verification against the upstream release notes before being added here. Blank cells are a deliberate absence of a stated value, not an oversight.
