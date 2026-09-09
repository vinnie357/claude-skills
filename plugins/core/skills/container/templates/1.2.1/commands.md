# Apple Container CLI - Version 1.2.1 Commands

Changes from 1.0.0. Includes 1.1.0 and 1.2.0.

**Verification note:** Everything in this file comes from upstream release notes. None of 1.1.0, 1.2.0, or 1.2.1's surface was checked against a live binary — only 1.4.1 was, on this host (see `templates/1.4.1/commands.md`). Flag text below marked "live 1.4.1 binary" was captured from that later version's `--help` output, not from the version where the flag was introduced; wording could have drifted between introduction and that capture. Treat unmarked text as release-notes-only.

## Breaking Changes from 1.0.0

None.

## 1.1.0 (2026-07-06) — fixes only, no CLI surface change

- Unix domain socket mounts now work in non-root containers (#1750)
- `container cp` with relative source paths fixed (#1738)
- `container image save` reference list routed to stderr in stdout mode (#1804)
- Duplicate "(default: 3)" removed from `--max-concurrent-downloads` help text (#1725)
- Machine nested virtualization (#1742)
- Containerization bumped 0.33.4 → 0.34.0 → 0.35.0 across the release cycle (commit-log level — no Highlights summary line for this bump)

## 1.2.0 (2026-07-29) — security release, no breaking changes

Five security advisories fixed:

| Advisory | Description |
|----------|-------------|
| CVE-2026-64786 / GHSA-xwgf-4rc5-p4m4 | Bare-name image `Config.Env` entries inherited the launching process's environment |
| CVE-2026-64773 / GHSA-wg28-286f-56v6 | TCP port forwarder buffered unbounded pre-connect data from published ports |
| CVE-2026-64777 / GHSA-2v2q-4q35-h585 | Build filesystem sync disclosed host files outside the build context via symlinks |
| GHSA-g57j-434g-5xj2 | `BuildFSSync.walk()` JSON response mode reported resolved host paths of out-of-context symlinks |
| GHSA-5h49-6pr7-9mv4 | Containerization: reset special permission bits when extracting archives onto the host |

Other 1.2.0 changes:

- `--kernel-arg` landed in the commit history (#1744). It does not appear in the curated release-notes Highlights, so treat it as a real 1.2.0 addition rather than a headline feature. Current verbatim help text, checked against the live 1.4.1 binary (not against 1.2.0 itself): `--kernel-arg <arg>      Append a raw boot argument to the kernel command line (repeatable).`
- OCI `maskedPaths`/`readonlyPaths` support added to the Container API (#1996)
- Containerization bumped 0.36.0 → 0.37.0 → 0.40.0 → 0.40.1 across the release cycle

## New Features in 1.2.1 (2026-08-07)

No breaking changes.

- **`container k8s`** (#2043/#2044) — new plugin for a turnkey local Kubernetes cluster. Verified against the live 1.4.1 binary, which marks it EXPERIMENTAL — the 1.2.1 release notes do not use that word, so the mark is attributed to 1.4.1 rather than to this release: subcommands are `create | delete, rm | list, ls | load-image | start | write-config` (six subcommands).
- **`container export` for LIVE containers** (#1400/#1630) — previously stopped-containers-only since 0.11.0.
- **`--ssh` for `container build`** (#1472/#1508). Verbatim help text (live 1.4.1 binary): `--ssh <default>         Forward SSH agent authentication to the build (format: default)`. This flag takes a value. It is distinct from `run`/`create`'s bare `--ssh` flag ("Forward SSH agent socket to container"), which dates from 0.4.1 (issue 498, PR 502, closed 2025-08-15) and is not new at 1.2.1 — do not group the two.
- **`--read-only-path` and `--masked-path`** for `container run` AND `container create` (#2041/#2069). Verbatim help text (live 1.4.1 binary):
  - `--read-only-path <path> [EXPERIMENTAL] Mark a path inside the container read-only, in addition to the runtime defaults (or NONE to clear prior values and the defaults)`
  - `--masked-path <path>    [EXPERIMENTAL] Hide a path inside the container, in addition to the runtime defaults (or NONE to clear prior values and the defaults)`
- Guest-VM default adjustment: overcommit and `max_map_count` defaults adjusted in guest VMs (#2055). Upstream does not state the specific values changed to — requires verification: read #2055's diff for the actual default numbers, if needed.
- `container-builder-shim` bumped to 0.13.1 (#2056)
