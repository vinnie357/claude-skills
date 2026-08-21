# Container Runtimes

Reference for the three container runtimes the gitleaks scripts fall back to when no native binary is found, and the copyable mise tasks template that wires gitleaks scanning into any project.

## Container Runtimes

The scripts support three container runtimes with automatic detection.

### Detection Priority

1. **Apple Container** (macOS 26+) - Native macOS containerization
2. **Docker** - Docker Desktop or Docker Engine
3. **Colima** - Lightweight container runtime via mise (macOS only)

The three examples below scan `/code` with `git`, which walks commit history — a mount that isn't a git repository, or is a git repository with no commits yet, has no history to walk and exits 0 with "no leaks found" (verified: both cases scan ~0 bytes and report clean, even with an untracked secret sitting in the mount). Use `dir /code` in place of `git /code` when the mount is not guaranteed to be a committed git repo, or to scan working-tree file content regardless of git state.

### Apple Container (macOS 26+)

Native container support in macOS 26 and later:

```bash
# Check status
container system status

# Start runtime
container system start

# Run gitleaks
container run -v $(pwd):/code zricethezav/gitleaks git /code -v
```

### Docker

Docker Desktop or Docker Engine:

```bash
# Check status
docker info >/dev/null 2>&1

# Start (macOS)
open -a Docker

# Run gitleaks
docker run -v $(pwd):/code zricethezav/gitleaks git /code -v
```

### Colima via mise

Lightweight runtime managed through mise, macOS only — the template's colima fallback exits with an explicit error on other platforms rather than attempting to start it:

```bash
# Check status
mise exec colima@latest -- colima status

# Start runtime
mise exec colima@latest -- colima start

# Run gitleaks
mise exec colima@latest -- docker run -v $(pwd):/code zricethezav/gitleaks git /code -v
```

Using `mise exec` provides automatic installation and version management without requiring global installation.

## Mise Tasks Template

Copy the mise tasks from `templates/mise.toml` to add gitleaks scanning to any project — merge the `[tools]` section, don't append the whole file. The template declares `[tools."github:nushell/nushell"]`; a duplicate declaration of that exact key anywhere else in the same `mise.toml` is a TOML duplicate-key error that breaks every task in the file, not just gitleaks — even when both entries pin the identical version. Verified: appending the template onto a `mise.toml` that already declared that same key raised `TOML parse error ... duplicate key`, and `mise tasks` failed outright. If the project already declares nushell at 0.113.1 or newer, skip the `[tools]` block and copy only the `[tasks.*]` blocks below it. An older pin is untested, not assumed broken — the one data point available is nushell 0.107.0 (six minors back), which ran the extracted task body and `gitleaks.nu --self-test` correctly (21/21); the task scripts use version-sensitive nushell surface (`split row`, `parse -r`, `is-not-empty`, optional `def main` params, `^cmd ...$spread`), so that single result doesn't generalize to a range. With the security skill installed, run `nu .../scripts/gitleaks.nu --self-test` under your own pinned nushell to check directly rather than assuming compatibility or incompatibility from the version number alone. With no existing nushell entry, copy the `[tools]` block too, unmodified.

`gitleaks:docker` and `gitleaks:colima` are one-line delegations (`GITLEAKS_RUNTIME=docker`/`colima` env var, `run = "mise run gitleaks"`) — the native-resolution, `--no-git`, and bytes-verification logic exists in exactly one place, `[tasks.gitleaks]`, not copied per runtime. Ran all three task names against the template directly: `mise gitleaks` and `mise gitleaks:docker` both resolved the native binary and scanned a real commit correctly (native resolution runs before the runtime fallback, so `GITLEAKS_RUNTIME` only takes effect when no native binary is found); an empty-commit repo (no file changes) correctly failed closed with "Scan unverified!" rather than reporting clean. Same committed-history-only scan scope as `gitleaks.nu` and the manual `git` invocations — see the SKILL.md's References list for the full write-up.

```bash
# Available tasks after copying template
mise gitleaks              # Scan — native binary preferred; falls back to Apple Container if none found
mise gitleaks:docker       # Scan — native binary preferred; forces the Docker fallback if none found
mise gitleaks:colima       # Scan — native binary preferred; forces the Colima fallback if none found (macOS only)

mise gitleaks:stop         # Stop all runtimes
mise gitleaks:stop:container
mise gitleaks:stop:docker
mise gitleaks:stop:colima
```

The tasks automatically:
- Detect and use `.gitleaks-baseline.json` if present
- Start the container runtime if not running
- Scan the repository root
