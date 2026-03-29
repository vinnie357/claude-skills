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

## API Quick Reference

Runex exposes a REST API at `http://localhost:4001/api` (default port). Authentication is via Bearer token when `RUNEX_API_TOKEN` is set; otherwise the API is open.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/health` | Liveness probe (returns node name, timestamp) |
| GET | `/api/ready` | Readiness probe (checks database, PTY info) |
| GET | `/api/workflows` | List registered workflows |
| GET | `/api/workflows/:id` | Show workflow detail with steps |
| GET | `/api/runs` | List runs (latest 50, optional `?workflow_id=` filter) |
| GET | `/api/runs/:id` | Show run detail with step runs |
| POST | `/api/runs` | Execute a workflow |
| GET | `/api/runs/:id/steps` | List step runs for a run |

### Submitting a Workflow

```bash
curl -X POST http://localhost:4001/api/runs \
  -H "Content-Type: application/json" \
  -d '{"workflow_path": "bundles/core/workflows/tool-verify.toml", "params": {"TOOLS": "mise,nu,git"}}'
```

**Request body:**
- `workflow_path` (required): Path to a `.toml`, `.yaml`, or `.yml` workflow file. Resolved via the workflow search order (see below).
- `params` (optional): Key-value map injected as environment variables into workflow steps.

**Param security:** Params matching patterns like `password`, `secret`, `token`, `key`, or `url` are auto-masked in step output logs.

**Response:** Returns a run object with `id`, `status`, `workflow` name, and timestamps. Use the run `id` to poll status and inspect step logs.

### Authentication

When `RUNEX_API_TOKEN` is set, include a Bearer token header:

```bash
curl -H "Authorization: Bearer $RUNEX_API_TOKEN" http://localhost:4001/api/health
```

If unset, the API is open (dev-friendly default).

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

**Root workflow pattern** -- dispatches via an `ACTION` param:

```toml
[workflow]
name = "my-bundle"
description = "What this bundle does"

[workflow.params]
ACTION = { required = true, description = "Action to run: action-one, action-two" }

[workflow.env]
BUNDLE_DIR = "bundles/my-bundle"

[[step]]
name = "dispatch"
driver = "shell"
command = """
case "$ACTION" in
  action-one) nu "$BUNDLE_DIR/scripts/do-thing.nu" ;;
  action-two) sh "$BUNDLE_DIR/scripts/another.sh" ;;
  *) echo "Unknown ACTION: $ACTION" && exit 1 ;;
esac
"""
```

**Sub-workflows** can be invoked directly without the dispatcher:

```bash
curl -X POST http://localhost:4001/api/runs \
  -d '{"workflow_path": "bundles/my-bundle/workflows/action-one.toml"}'
```

Bundle names are globally unique. Workflow names are unique within their containing directory.

## Debugging with Step Logs

Inspect a run's step-by-step execution:

```bash
# Get run status
curl http://localhost:4001/api/runs/<id>

# Get step logs
curl http://localhost:4001/api/runs/<id>/steps
```

Each step run includes:
- `status`: Current state of the step
- `output`: stdout captured from the step
- `error`: stderr or error message
- `exit_code`: Process exit code
- `started_at` / `finished_at`: Timing
- `attempt`: Retry attempt number

**Debugging pattern:**

1. Submit workflow, capture run `id` from response
2. Poll `GET /api/runs/<id>` until status is terminal
3. Fetch `GET /api/runs/<id>/steps` to see per-step output
4. Check `exit_code` and `error` fields for failures
5. Re-submit with adjusted `params` if needed

## Bundle Discovery

List available bundles and workflows:

```bash
# Discover bundles on the filesystem
ls ~/github/runex-workflows/bundles/
ls ~/github/<app>/bundles/

# List registered workflows via API
curl http://localhost:4001/api/workflows | jq '.data[].name'

# Check a specific workflow
curl http://localhost:4001/api/workflows/<id> | jq '.data.steps'
```

## mise Tasks Integration

Run `mise tasks` in any repo to discover available helpers. Repos using Runex typically define mise tasks that wrap API calls:

```bash
mise tasks        # List available tasks
mise run dev      # Start dev server (live-reload)
mise run ci       # Run full CI suite
```

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `RUNEX_WORKFLOW_PATH` | Colon-separated extra workflow search dirs | unset |
| `RUNEX_WORKFLOWS_DIR` | Project workflows directory | `./workflows` |
| `RUNEX_API_TOKEN` | Bearer token for API auth | unset (open) |
| `RUNEX_DATABASE_URL` | Postgres URL for peered mode | unset (SQLite) |
| `RUNEX_REGION` | Region identifier | unset |
| `RUNEX_DATACENTER` | Datacenter identifier | unset |
| `PORT` / `RUNEX_PORT` | HTTP listen port | 4001 |

## References

For detailed information, see:
- **[references/api.md](references/api.md)** -- Full API reference with request/response shapes
- **[references/bundles.md](references/bundles.md)** -- Bundle authoring guide with patterns
- **[references/debugging.md](references/debugging.md)** -- Step log inspection and troubleshooting
