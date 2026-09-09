# Apple Container CLI - Version 1.3.1 Commands

Changes from 1.2.1. Includes 1.2.2 and 1.3.0.

**Verification note:** Everything in this file comes from upstream release notes. None of 1.2.2, 1.3.0, or 1.3.1's surface was checked against a live binary — only 1.4.1 was, on this host (see `templates/1.4.1/commands.md`). Treat all text here as release-notes-only unless stated otherwise.

## Breaking Changes from 1.2.1

> **⚠ BREAKING — 1.3.0 image-scheme default change.** Upstream marks this with its own CLI-breaking marker: "Removed `--scheme auto` for image operations, default is now `https`." (#2099/#2100)

| Change | Migration |
|--------|-----------|
| `--scheme auto` removed for image operations; default is now `https` | Update scripts that pass `--scheme auto` — that value no longer exists. Explicit `--scheme http` or `--scheme https` still work; an unset `--scheme` now resolves to `https` instead of auto-detecting. The prior `auto` default is not stated in the release note — it comes from PR #2100's own diff, which changes `public var scheme: String = "auto"` to `"https"` and removes the auto-downgrade logic that selected `http` for localhost, RFC1918 and internal-DNS hosts. |

## 1.2.2 (2026-08-08) — packaging fix only, no CLI surface change

Verbatim from the release notes: "This release fixes a glitch that prevented `container k8s` working when installed from the release package." (#2097)

## 1.3.0 (2026-08-24) — breaking, see above

- **BREAKING**: `--scheme auto` removed for image operations; default is now `https` (#2099/#2100) — see the Breaking Changes table above.
- Default Kata kernel is now 3.32.0-debug (#2143)
- "Relax maskedPaths and readonlyPaths for container machines" — commit "Do not set default maskedPaths and readonlyPaths for container machines" (#2137). This reverses, for container **machines** specifically, the default that 1.2.0's #1996 introduced for the Container API.
- Upstream docs reorganised (#2032)
- Fix: `tmpfsMounts()` path processing (#2103)
- Fix: volume name validation in the volume disk-usage call (#2107)

## 1.3.1 (2026-08-29) — security patch release, no breaking changes

Six security advisories fixed via the containerization 0.42.0 bump (#2207):

| Advisory | Description |
|----------|-------------|
| GHSA-x7pf-2jmj-pgcq | `container create`/`exec` could delete files outside its bundle through an unchecked id |
| GHSA-f689-h8m7-3jp2 | `ContainerizationOCI` accepted unvalidated OCI descriptor digests, enabling path traversal in the local content store |
| GHSA-r3h2-rgqf-9hv9 | Loading an OCI image layout could read host files through a symlink |
| CVE-2026-65388 / GHSA-mx96-5vvg-x2mg | `RegistryClient` followed the `WWW-Authenticate` realm without validating its host or scheme |
| GHSA-697p-8837-37h3 | A crafted image layer with a long invalid file name crashed the unpacking process |
| GHSA-g3rx-2m58-rr63 | A crafted image layer with an invalid length extended-attribute name crashed the unpacking process |

Other fix:

- `--mount type=tmpfs` left the tmpfs mount `source` field empty (#2138)
