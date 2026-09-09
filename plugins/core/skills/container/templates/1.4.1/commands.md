# Apple Container CLI - Version 1.4.1 Commands

Changes from 1.3.1.

**Verification note:** This file's CLI-surface claims were checked against a live Apple Container 1.4.1 binary on this host (`container --version` → `container CLI version 1.4.1 (build: release, commit: 9a8917c)`, macOS 26.6.2, captured 2026-09-09, client-side `--help` output only — the system service was not started). Anything not derived from that capture is marked as coming from release notes only.

## There was no 1.4.0 release

Verbatim from the 1.4.1 release notes: "There was no 1.4.0 release, we had to discard that tag so this release contains every change since 1.3.1." A `1.4.0` git tag exists (a docs commit dated 2026-09-08) but carries no GitHub Release. This file documents 1.4.1 as the delta from 1.3.1 directly; 1.4.0 contents are not inferred from the discarded tag.

## Breaking Changes from 1.3.1

> **⚠ BREAKING — 1.4.1 `system status` output-shape change.** Upstream marks this with its own API-breaking marker: "`container system status` now reports host, client, paths, and resources" (#1769). This is an output-schema change, not observable from `--help` alone — it needs the running service. Attributed to the release note, not to a live observation of running output.

| Change | Migration |
|--------|-----------|
| `container system status` output schema now reports host, client, paths, and resources (previously a different shape) | Update any script or tool that parses `system status` structured output (`--format json/yaml/toml`) for the new field set before trusting it |

Verified against the live binary, unchanged at 1.4.1: `container system status --help` — `OVERVIEW: Show the status of \`container\` services and system-wide information`; `USAGE: container system status [--prefix <prefix>] [--format <format>] [--debug]`; `-p, --prefix <prefix>   Launchd prefix for services (default: com.apple.container.)`; `--format <format>       Format of the output (values: json, table, yaml, toml; default: table)`. The flag surface is unchanged — only the reported content changed.

## New command: `container clean` (#1949)

Verbatim `--help` output, live 1.4.1 binary:

```
OVERVIEW: Clean one or more running containers

USAGE: container clean [--debug] [<container-ids> ...]

ARGUMENTS:
  <container-ids>         Container IDs

OPTIONS:
  --debug                 Enable debug output [environment: CONTAINER_DEBUG]
  --version               Show the version.
  -h, --help              Show help information.
```

`clean` operates on RUNNING containers and takes explicit container IDs. It is not a fix for the accumulated-stopped-containers problem described in SKILL.md's Troubleshooting section — that remains `container prune` territory, which takes no arguments and no filter. No release in this delta (1.1.0 through 1.4.1) fixed the `--rm` non-removal behavior documented in SKILL.md; upstream issue 1445 closed 2026-05-28, before 1.0.0 shipped, so it predates and does not affect anything in this delta. `<container-ids>` is bracketed (optional-variadic) in `USAGE`; behavior with zero arguments is unverified — requires verification: run `container clean` with no arguments on a disposable host.

## JSON output no longer escapes forward slashes (#2205)

Output-format change affecting anything that parses CLI JSON output — a forward slash that previously appeared as `\/` in JSON output now appears as `/`. Update any parser or string-matching logic that depended on the escaped form.

## Security fixes

| Advisory | Description |
|----------|-------------|
| GHSA-4587-w9mm-xxvh | OCI image load followed symlinks for `oci-layout` and `index.json` outside the extraction directory |
| GHSA-rgqp-277h-gcwj | `UnixType.init(path:)` used a macOS length limit longer than the `sockaddr_un.sun_path` buffer it copied into |

Containerization updated to **0.45.0** (#2250).

## Verified unchanged at 1.4.1

Confirmed against the live binary, no change from 1.0.0:

- `container export --help`: options are exactly `--debug`, `-o`/`--output`, `--version`, `-h`/`--help`. No `-t`/`--tag`. `export` produces a filesystem tar only; it does not create or tag an image.
- `container system property --help`: `SUBCOMMANDS` is `list, ls` only — no `get`/`set`/`clear`. The 1.0.0 TOML-config breaking change (`~/.config/container/config.toml` replacing UserDefaults-backed properties) remains in effect.
- No `--mac-address` flag on `run`/`create`.

## `container k8s` at 1.4.1 (introduced 1.2.1, #2043/#2044)

Verified against the live binary: still marked EXPERIMENTAL. `OVERVIEW: Manage local Kubernetes development clusters (EXPERIMENTAL)`. Six subcommands: `create | delete, rm | list, ls | load-image | start | write-config`.

## Scripts in this skill are unaffected

`plugins/core/skills/container/scripts/*.nu` parse only `$status.exit_code` from `container system status` — none of the four scripts parse `system status`'s structured output. A search for `from json`, `--format`, `| get`, or `parse` across those scripts returns one hit (argument indexing in `container-images.nu`, unrelated to `system status`). The 1.4.1 `system status` schema change does not require script changes.
