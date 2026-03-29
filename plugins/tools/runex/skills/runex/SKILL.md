---
name: runex
description: "Runex workflow engine: submit workflows via REST API, author TOML bundles, inspect step logs, and debug runs. Use when interacting with Runex API endpoints, creating or modifying workflow bundles, submitting workflow runs, reading step output, or configuring workflow path resolution."
license: MIT
---

# Runex Workflow Engine

Runex is a single-binary Elixir workflow orchestrator. It parses TOML (primary) and YAML workflow definitions, builds a DAG of steps, and executes them via pluggable drivers (shell, mise, nushell). It runs in standalone mode (SQLite) or peered mode (Postgres).

## When to Use This Skill

Activate when:
- Submitting workflows via the Runex REST API
- Authoring or modifying TOML/YAML workflow files
- Creating or updating workflow bundles
- Inspecting run status or step logs for debugging
- Configuring workflow path resolution (`RUNEX_WORKFLOW_PATH`, `RUNEX_WORKFLOWS_DIR`)
- Running `mise tasks` to discover repo-level helpers that wrap Runex operations

## Scripts

This skill provides versioned Nushell scripts for direct API interaction. Scripts are in `scripts/0.1.0/`.

### runex.nu — API Client

Main Runex API client. All commands return structured data (tables/records).

```bash
# Health check
nu scripts/0.1.0/runex.nu health

# List recent runs
nu scripts/0.1.0/runex.nu runs

# Show run detail with step runs
nu scripts/0.1.0/runex.nu run 42

# Submit a workflow
nu scripts/0.1.0/runex.nu submit "bundles/core/workflows/tool-verify.toml"

# Submit with params
nu scripts/0.1.0/runex.nu submit "bundles/core/workflows/tool-verify.toml" --params '{"TOOLS":"mise,nu,git"}'

# List step runs for a run
nu scripts/0.1.0/runex.nu steps 42

# List workflows
nu scripts/0.1.0/runex.nu workflows

# Show workflow detail with steps
nu scripts/0.1.0/runex.nu workflow 1
```

### bundles.nu — Bundle Discovery

Discover and inspect workflow bundles on the filesystem.

```bash
# List bundles in default search paths
nu scripts/0.1.0/bundles.nu list

# List bundles in a specific directory
nu scripts/0.1.0/bundles.nu list ~/github/runex-workflows/bundles

# Show bundle details (name, params, steps, sub-workflows)
nu scripts/0.1.0/bundles.nu show bundles/core

# Validate bundle structure
nu scripts/0.1.0/bundles.nu validate bundles/core
```

### debug.nu — Step Log Inspection

Inspect run execution, step output, and failures.

```bash
# Show step statuses and timing
nu scripts/0.1.0/debug.nu steps 42

# Show full output for a specific step
nu scripts/0.1.0/debug.nu log 42 7

# Show only failed steps with error output
nu scripts/0.1.0/debug.nu failures 42

# Watch a run until completion (polls every 2 seconds)
nu scripts/0.1.0/debug.nu watch 42

# Watch with custom interval
nu scripts/0.1.0/debug.nu watch 42 --interval 5
```

## Configuration

Scripts read configuration from environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `RUNEX_HOST` | Base URL for API requests | `http://localhost:4001` |
| `RUNEX_API_TOKEN` | Bearer token for API auth | unset (open) |
| `RUNEX_WORKFLOW_PATH` | Colon-separated extra workflow search dirs | unset |
| `RUNEX_WORKFLOWS_DIR` | Project workflows directory | `./workflows` |
| `RUNEX_DATABASE_URL` | Postgres URL for peered mode | unset (SQLite) |
| `RUNEX_REGION` | Region identifier | unset |
| `RUNEX_DATACENTER` | Datacenter identifier | unset |
| `PORT` / `RUNEX_PORT` | HTTP listen port | 4001 |

## Workflow Path Resolution

Runex resolves `workflow_path` values through an ordered search:

1. **Custom dirs**: `RUNEX_WORKFLOW_PATH` env var (colon-separated directories)
2. **Project dir**: `RUNEX_WORKFLOWS_DIR` env var (defaults to `./workflows` relative to Runex cwd)
3. **Core priv**: Workflows shipped with the Runex release (`priv/workflows/`)
4. **User dir**: `~/Library/Application Support/Runex/workflows/` (macOS) or `~/.local/share/runex/workflows/` (Linux)
5. **Bundles**: `./bundles/*/` directories containing `.toml`/`.yaml` files

Accepts absolute paths, filenames with extension, or bare names (tries `.toml`, `.yaml`, `.yml` in order).

## Bundle Structure

A bundle is a self-contained directory with workflows, scripts, and tool dependencies:

```
bundle-name/
  workflow.toml          # Root dispatcher workflow (routes ACTION param)
  mise.toml              # Tool dependencies for the bundle
  workflows/             # Sub-workflows (invocable directly)
    action-one.toml
    action-two.toml
  scripts/               # Nushell/shell scripts called by steps
    do-thing.nu
    another.sh
```

Bundle names are globally unique. Workflow names are unique within their containing directory. Use `bundles.nu show` and `bundles.nu validate` to inspect and verify bundle structure.

## Version Detection

Scripts are versioned under `scripts/<version>/`. To check the current version:

```bash
ls scripts/ | get name
```

## mise Tasks Integration

Run `mise tasks` in any repo to discover available helpers. Repos using Runex typically define mise tasks that wrap API calls:

```bash
mise tasks        # List available tasks
mise run dev      # Start dev server (live-reload)
mise run ci       # Run full CI suite
```

## References

For detailed information, see:
- **[templates/0.1.0/api.md](templates/0.1.0/api.md)** -- Full API reference with request/response shapes
- **[references/bundles.md](references/bundles.md)** -- Bundle authoring guide with patterns
- **[references/debugging.md](references/debugging.md)** -- Step log inspection and troubleshooting
