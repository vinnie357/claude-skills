# Apple Container CLI - Version 0.12.3 Commands

Changes from 0.12.0. Includes 0.12.1 compat fix.

NOTE: There is no 0.12.2 release.

## Breaking Changes

None. 0.12.1 and 0.12.3 are non-breaking releases.

## Changes in 0.12.1 (2026-04-29)

- macOS 15 (Sequoia) compatibility: allow listing and deleting networks on macOS 15

## Changes in 0.12.3 (2026-04-30, Security)

- Prevent HTTP downgrade in registry commands
- Prevent path/rule injection in `container system dns`
- `ImagePush` now prints the image reference to stdout on success

## Security Fixes Summary

| Fix | Impact |
|-----|--------|
| Prevent HTTP downgrade in registry commands | Registry operations now enforce HTTPS |
| Prevent path/rule injection in `container system dns` | DNS operations sanitize inputs |
| `ImagePush` prints image reference to stdout on success | Scripting / automation can capture the pushed reference |

## Registry

| Command | Change |
|---------|--------|
| `container image push IMAGE` | **Now prints the image reference to stdout on success (0.12.3+)** |

## System

| Command | Change |
|---------|--------|
| `container system dns create/delete/list` | **Path/rule injection prevented (0.12.3+)** |

## Network (from 0.12.1)

| Platform | Change |
|----------|--------|
| macOS 15 (Sequoia) | **`container network list` and `container network delete` now work correctly** |

## Install / Upgrade

```bash
# Install 0.12.3
curl -LO https://github.com/apple/container/releases/download/0.12.3/container-0.12.3-installer-signed.pkg
sudo installer -pkg container-0.12.3-installer-signed.pkg -target /

# Upgrade existing installation
/usr/local/bin/update-container.sh
```
