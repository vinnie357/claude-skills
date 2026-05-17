---
name: runex
description: "Runex workflow engine: submit workflows via REST API, author TOML bundles, inspect step logs, and debug runs. Use when interacting with Runex API endpoints, creating or modifying workflow bundles, submitting workflow runs, reading step output, or configuring workflow path resolution."
license: MIT
---

# Runex Workflow Engine

Runex is a single-binary Elixir workflow orchestrator. It parses TOML (primary) and YAML workflow definitions, builds a DAG of steps, and executes them via pluggable drivers (`shell, mise, nushell, runex, wasm, container, flame, workflow`). It runs in standalone mode (SQLite, default — no configuration required) or federated mode (Postgres + libcluster) for multi-node deployments.

Current documented version: **0.0.6** (`mix.exs @version`). Legacy templates for older deployments remain under `templates/0.1.0/` and `scripts/0.1.0/`.

## When to Use This Skill

Activate when:
- Submitting workflows via the Runex REST API
- Authoring or modifying TOML/YAML workflow files
- Creating or updating workflow bundles
- Inspecting run status or step logs for debugging
- Configuring workflow path resolution (`RUNEX_WORKFLOW_PATH`, `RUNEX_WORKFLOWS_DIR`) or bundle search (`RUNEX_BUNDLE_DIRS`)
- Calling the step heartbeat endpoint from long-running steps
- Working with agent runs (decoupled from workflow lifecycle) or federation endpoints

## Install

Pin Runex via mise's github backend:

```toml
[tools]
"github:vinnie357/runex" = "0.0.6"
```

Copy the template and install:

```bash
cp templates/0.0.6/mise.toml <your-repo>/mise.toml
cd <your-repo> && GITHUB_TOKEN=<token-with-repo-read> mise install
```

`vinnie357/runex` is a **private** GitHub repository. `mise install` and `mise ls-remote github:vinnie357/runex` both require `GITHUB_TOKEN` (or `GH_TOKEN`) with `repo` read scope. Without a token, mise reports "no versions found" — that is an auth failure, not a backend mismatch. Source the token from `op read` (1Password CLI) or your shell secret manager rather than hardcoding it in shell history.

## Scripts

This skill provides versioned Nushell scripts for direct API interaction. Current scripts are in `scripts/0.0.6/`.

### runex.nu — API Client

```bash
# Server info, health, readiness
nu scripts/0.0.6/runex.nu info
nu scripts/0.0.6/runex.nu health

# Workflows and runs
nu scripts/0.0.6/runex.nu workflows
nu scripts/0.0.6/runex.nu workflow 1
nu scripts/0.0.6/runex.nu runs
nu scripts/0.0.6/runex.nu run 42
nu scripts/0.0.6/runex.nu steps 42
nu scripts/0.0.6/runex.nu submit "bundles/core/workflows/tool-verify.toml" '{"TOOLS":"mise,nu,git"}'

# Step heartbeat (extends long-running step deadlines)
nu scripts/0.0.6/runex.nu heartbeat 42 7
nu scripts/0.0.6/runex.nu heartbeat 42 7 60000   # extend by 60s

# Agent runs (decoupled from workflow lifecycle)
nu scripts/0.0.6/runex.nu agent-runs
nu scripts/0.0.6/runex.nu agent-run 12
nu scripts/0.0.6/runex.nu submit-agent "bundles/core/workflows/run-agent.toml" '{"SESSION":"foo"}'

# Federation (requires Postgres + libcluster)
nu scripts/0.0.6/runex.nu federation-nodes
nu scripts/0.0.6/runex.nu federation-runs
nu scripts/0.0.6/runex.nu federation-run 99
```

### bundles.nu — Bundle Discovery + Distribution

```bash
# Local bundle filesystem operations
nu scripts/0.0.6/bundles.nu list
nu scripts/0.0.6/bundles.nu show bundles/core
nu scripts/0.0.6/bundles.nu validate bundles/core
nu scripts/0.0.6/bundles.nu pack bundles/core

# Server-side bundle catalog
nu scripts/0.0.6/bundles.nu bundles               # GET /api/bundles
nu scripts/0.0.6/bundles.nu reload                # POST /api/bundles/reload
nu scripts/0.0.6/bundles.nu import core.tar.gz    # multipart upload
nu scripts/0.0.6/bundles.nu pull core 0.0.1       # JSON pull via BUNDLE_SOURCES
```

### debug.nu — Step Log Inspection

```bash
nu scripts/0.0.6/debug.nu steps 42
nu scripts/0.0.6/debug.nu log 42 7
nu scripts/0.0.6/debug.nu failures 42
nu scripts/0.0.6/debug.nu watch 42 --interval 5
nu scripts/0.0.6/debug.nu heartbeat-status 42 7   # last heartbeat ts + timeout state
```

## Configuration

Scripts and Runex itself read configuration from environment variables. Defaults below are the application defaults from `config/runtime.exs`; operator deployments often override.

| Variable | Purpose | Default |
|----------|---------|---------|
| `RUNEX_HOST` | Base URL for scripts' API requests | `http://localhost:4000` |
| `RUNEX_API_TOKEN` | Bearer token for API auth | unset (open) |
| `PORT` / `RUNEX_PORT` | HTTP listen port | `4000` (operators often run on `4001` to coexist with VantageEx on `4000`) |
| `BIND_ADDRESS` | Listen address | IPv4 all (`{0,0,0,0}`) |
| `RUNEX_WORKFLOW_PATH` | Colon-separated extra workflow search dirs | unset |
| `RUNEX_WORKFLOWS_DIR` | Project workflows directory | `./workflows` |
| `RUNEX_ROOT_DIR` | Root for bundles/, workflows/ | cwd |
| `RUNEX_BUNDLE_DIRS` | Colon-separated bundle search dirs | `<RUNEX_ROOT_DIR>/bundles` |
| `RUNEX_BUNDLES_AUTO_SYNC` | Run bundle-sync workflow on boot | `false` |
| `BUNDLE_SOURCES` | Colon-separated GH Release base URLs for pull-mode bundle import | unset |
| `RUNEX_DATABASE_URL` | Postgres URL for federated mode | unset (SQLite) |
| `RUNEX_DB_PATH` | SQLite override (ignored if DATABASE_URL set) | XDG-compliant |
| `RUNEX_REGION` / `RUNEX_DATACENTER` | Node region/datacenter labels for federation routing | unset |
| `RUNEX_MASKED_VARS` | Comma-separated env var name patterns to redact from logs | `TOKEN,SECRET,KEY,PASSWORD,CREDENTIAL,DATABASE_URL` |
| `RUNEX_PEER_HOST` | Cluster peer identity + registration host | auto-detect (Tailscale -> hostname) |
| `PHX_PUBLIC_HOSTS` | Internet-facing user URLs (operator-curated) | unset |
| `RUNEX_MISE_BIN` | Path to mise binary | auto-detect |

## Workflow Path Resolution

Runex resolves `workflow_path` values through an ordered search (`lib/runex/paths.ex` `workflows_dirs/0`):

1. **Custom dirs**: `RUNEX_WORKFLOW_PATH` env var (colon-separated)
2. **Project dir**: `RUNEX_WORKFLOWS_DIR` env var (default `./workflows`, relative to Runex cwd)
3. **Core priv**: `priv/workflows/` shipped with the Runex release

Accepts absolute paths, filenames with extension, or bare names (tries `.toml`, `.yaml`, `.yml` in order).

Bundles use a separate search path: `RUNEX_BUNDLE_DIRS` (colon-separated; defaults to `<RUNEX_ROOT_DIR>/bundles`). Workflows inside bundles are reachable by the `bundles/<name>/<file>.toml` path form once the bundle directory is on a search path.

## Bundle Structure

A bundle is a self-contained directory with workflows, scripts, and tool dependencies:

```
bundle-name/
  workflow.toml          # Root dispatcher workflow (routes ACTION param)
  mise.toml              # Tool dependencies for the bundle
  workflows/             # Sub-workflows (invocable directly)
    action-one.toml
  scripts/               # Nushell/shell scripts called by steps
    do-thing.nu
```

Bundle names are globally unique. Workflow names are unique within their containing directory. Use `bundles.nu show` and `bundles.nu validate` to inspect and verify bundle structure.

### Pull-based distribution

Bundles can ship as GitHub Release assets and be pulled into a Runex node on demand. Set `BUNDLE_SOURCES` to a colon-separated list of GitHub Release base URLs, then either:

- Call `POST /api/bundles/import` with `{"name": "...", "version": "..."}`
- Run `bundles.nu pull <name> <version>`

The server resolves the asset URL, downloads, extracts into the bundle cache, and registers it. See the **Bundle Endpoints** section of `templates/0.0.6/api.md` for the multipart vs JSON pull modes.

## Version Detection

Scripts and templates are versioned under `scripts/<version>/` and `templates/<version>/`. To list available versions:

```bash
ls scripts/ | get name
```

The current documented version is `0.0.6` (matches Runex `mix.exs @version`). `0.1.0` remains for older deployments — the API endpoints it documented are still wire-compatible with current Runex, but it predates heartbeat, agent_runs, federation, and the expanded driver set.

## mise Tasks Integration

Run `mise tasks` in any repo to discover available helpers. Repos using Runex typically define mise tasks that wrap API calls:

```bash
mise tasks        # List available tasks
mise run dev      # Start dev server (live-reload)
mise run ci       # Run full CI suite
```

## References

For detailed information:
- **[templates/0.0.6/mise.toml](templates/0.0.6/mise.toml)** — Ready-to-copy mise pin for Runex `0.0.6`
- **[templates/0.0.6/api.md](templates/0.0.6/api.md)** — Full API reference with request/response shapes (heartbeat, agent_runs, federation, bundles)
- **[references/bundles.md](references/bundles.md)** — Bundle authoring guide with step schema and per-driver examples
- **[references/debugging.md](references/debugging.md)** — Step log inspection, heartbeat debugging, troubleshooting

Legacy:
- **[templates/0.1.0/api.md](templates/0.1.0/api.md)** — API reference snapshot for older Runex deployments (no heartbeat/agent_runs/federation)
