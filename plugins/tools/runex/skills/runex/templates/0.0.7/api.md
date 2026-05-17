# Runex API Reference

Full REST API reference for Runex v0.0.7. Default base URL: `http://localhost:4000`.

> **Note:** Operators commonly run Runex on port 4001 to coexist with VantageEx on port 4000, but the application default (from `runtime.exs`) is 4000.

## Table of Contents

- [Authentication](#authentication)
- [Health Endpoints](#health-endpoints)
- [Info Endpoints](#info-endpoints)
- [Workflow Endpoints](#workflow-endpoints)
- [Run Endpoints](#run-endpoints)
- [Step Heartbeat](#step-heartbeat)
- [Bundle Endpoints](#bundle-endpoints)
- [Federation Endpoints](#federation-endpoints)

## Authentication

Controlled by the `RUNEX_API_TOKEN` environment variable.

- **Unset**: API is open, no auth required (dev-friendly default)
- **Set**: Requires `Authorization: Bearer <token>` header on all `/api/*` requests

The `RunexWeb.Plugs.APIAuth` plug gates the entire `/api` scope, which includes
`/api/workflows`, `/api/runs`, `/api/bundles`, and `/api/federation/*`.

Unauthorized requests return:
```json
{"error": "Invalid or missing API token"}
```
HTTP status: 401

## Health Endpoints

### GET /api/health

Liveness probe. Always returns 200 if the application is running.

**Response 200:**
```json
{
  "status": "healthy",
  "node": "runex@hostname",
  "timestamp": "2026-03-29T12:00:00Z"
}
```

### GET /api/ready

Readiness probe. Checks database connectivity and PTY state.

**Response 200:**
```json
{
  "status": "ready",
  "checks": {"database": "ok"},
  "pty": {"active_ttys": 5, "orphan_shells": 0},
  "timestamp": "2026-03-29T12:00:00Z"
}
```

**Response 503** (database unreachable):
```json
{
  "status": "not_ready",
  "checks": {"database": "error"},
  "pty": {"active_ttys": 0, "orphan_shells": 0},
  "timestamp": "2026-03-29T12:00:00Z"
}
```

## Info Endpoints

### GET /api/info

Server build and version information. Served by `Runex.BuildInfo.info/0`.

**Response 200:**
```json
{
  "app": "runex",
  "version": "0.0.7",
  "git_sha": "abc1234",
  "build_time": "2026-03-29T12:00:00Z",
  "node": "runex@hostname",
  "uptime_seconds": 1234
}
```

Fields `app`, `node`, and `uptime_seconds` are present in the openapi.yaml schema; field
presence depends on the `Runex.BuildInfo` implementation — mark any field absent from
an actual response as unreliable.

## Workflow Endpoints

### GET /api/workflows

List all registered workflows. The openapi.yaml schema shows the response contains two
top-level arrays: `bundles` (workflows grouped by bundle) and `workflows` (standalone
workflows). The `run_controller.ex` list action returns `%{data: [...]}` — callers should
check the actual response shape.

**Response 200 (per openapi.yaml):**
```json
{
  "bundles": [
    {
      "name": "core",
      "workflows": [
        {
          "id": 1,
          "name": "system-info",
          "description": "Report system information",
          "schedule": null,
          "source_path": "bundles/core/0.0.10/system-info.toml",
          "inserted_at": "2026-03-29T12:00:00Z",
          "updated_at": "2026-03-29T12:00:00Z"
        }
      ]
    }
  ],
  "workflows": [
    {
      "id": 2,
      "name": "my-workflow",
      "description": null,
      "schedule": null,
      "source_path": "workflows/my-workflow.toml",
      "inserted_at": "2026-03-29T12:00:00Z",
      "updated_at": "2026-03-29T12:00:00Z"
    }
  ]
}
```

### GET /api/workflows/:id

Show workflow detail including its steps.

**Response 200:**
```json
{
  "data": {
    "id": 1,
    "name": "core",
    "description": "Shared primitives",
    "schedule": null,
    "source_path": "bundles/core/workflow.toml",
    "inserted_at": "2026-03-29T12:00:00Z",
    "updated_at": "2026-03-29T12:00:00Z",
    "steps": [
      {
        "id": 1,
        "name": "dispatch",
        "driver": "shell",
        "command": "case \"$ACTION\" in ...",
        "depends": null,
        "position": 0
      }
    ]
  }
}
```

**Response 404:**
```json
{"error": "Workflow not found"}
```

### POST /api/workflows/import

Import a workflow from inline content or a remote URL.

**Request body (inline content):**
```json
{
  "source": "content",
  "content": "# TOML workflow content...",
  "name": "my-workflow"
}
```

**Request body (URL fetch):**
```json
{
  "source": "url",
  "url": "https://example.com/workflows/hello.toml"
}
```

Source types per openapi.yaml:
- `content`: Inline TOML workflow definition (field: `content`)
- `url`: URL to fetch workflow from (field: `url`)
- `git`: Not yet implemented — returns 501

**Response 201:**
```json
{
  "data": {
    "id": 5,
    "name": "my-workflow",
    "source_path": "imports/my-workflow.toml"
  }
}
```

**Error responses:**

| Status | Cause |
|--------|-------|
| 400 | Missing or malformed request body |
| 401 | Missing or invalid API token |
| 422 | Parse error or validation failure |
| 501 | Source type not implemented (e.g. `git`) |

## Run Endpoints

### GET /api/runs

List runs (latest 50, newest first). Optional query parameter: `?workflow_id=<id>`.

**Response 200:**
```json
{
  "data": [
    {
      "id": 1,
      "status": "completed",
      "started_at": "2026-03-29T12:00:00Z",
      "finished_at": "2026-03-29T12:00:05Z",
      "workflow": "core",
      "inserted_at": "2026-03-29T12:00:00Z"
    }
  ]
}
```

### GET /api/runs/:id

Show run detail with step runs.

**Response 200:**
```json
{
  "data": {
    "id": 1,
    "status": "completed",
    "started_at": "2026-03-29T12:00:00Z",
    "finished_at": "2026-03-29T12:00:05Z",
    "workflow": "core",
    "inserted_at": "2026-03-29T12:00:00Z",
    "step_runs": [
      {
        "id": 1,
        "status": "completed",
        "output": "system info output...",
        "error": null,
        "exit_code": 0,
        "started_at": "2026-03-29T12:00:00Z",
        "finished_at": "2026-03-29T12:00:05Z",
        "attempt": 1
      }
    ]
  }
}
```

**Response 404:**
```json
{"error": "Run not found"}
```

### POST /api/runs

Execute a workflow. Exactly one workflow identifier field is required. Resolution
precedence when multiple fields are provided: `workflow_id` (highest) → `workflow_name`
→ `workflow_path` (lowest).

**Request body — by DB id:**
```json
{
  "workflow_id": 1,
  "params": {
    "NAME": "world"
  }
}
```

**Request body — by name:**
```json
{
  "workflow_name": "system-info",
  "params": {}
}
```

Accepts bare name (`"system-info"`) or name@version form (`"core@0.0.10"`). Matched by
name in the workflows DB table.

**Request body — by path:**
```json
{
  "workflow_path": "bundles/core/workflows/tool-verify.toml",
  "params": {
    "TOOLS": "mise,nu,git",
    "FORMAT": "json"
  }
}
```

Accepts a filename, relative path, or version-pinned bundle path segment
(e.g. `"core/0.0.10/system-info"`). Resolved via `Runex.Paths.resolve_workflow/1`.

**Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `workflow_id` | integer | one of three | Direct DB row id (highest priority) |
| `workflow_name` | string | one of three | Bare name or `name@version` |
| `workflow_path` | string | one of three | Filesystem or bundle-path segment |
| `params` | object | no | Key-value pairs injected as env vars into step execution |

Sensitive params whose names contain any of `TOKEN`, `SECRET`, `KEY`, `PASSWORD`,
`CREDENTIAL`, or `DATABASE_URL` (controlled by `RUNEX_MASKED_VARS`) are auto-masked in
output.

**Response 201:**
```json
{
  "data": {
    "id": 42,
    "status": "running",
    "started_at": "2026-03-29T12:00:00Z",
    "finished_at": null,
    "workflow": "tool-verify",
    "inserted_at": "2026-03-29T12:00:00Z"
  }
}
```

**Error responses:**

| Status | Body | Cause |
|--------|------|-------|
| 400 | `{"error": "workflow_id, workflow_name, or workflow_path required"}` | No identifier supplied |
| 403 | `{"error": "Invalid workflow path"}` | Path not found or path traversal attempt |
| 400 | `{"error": "Unsupported workflow format"}` | File extension not `.toml`, `.yaml`, or `.yml` |
| 404 | `{"error": "Workflow not found"}` | `workflow_id` or `workflow_name` not in DB |
| 422 | `{"error": "<details>"}` | Parse error or execution setup failure |

### GET /api/runs/:id/steps

List step runs for a specific run, ordered by insertion time.

**Response 200:**
```json
{
  "data": [
    {
      "id": 1,
      "status": "completed",
      "output": "step output text",
      "error": null,
      "exit_code": 0,
      "started_at": "2026-03-29T12:00:00Z",
      "finished_at": "2026-03-29T12:00:03Z",
      "attempt": 1
    }
  ]
}
```

Step run fields:

| Field | Description |
|-------|-------------|
| `id` | Unique step run identifier |
| `status` | Step execution status |
| `output` | Captured stdout from the step |
| `error` | Captured stderr or error message (null on success) |
| `exit_code` | OS process exit code (0 = success) |
| `started_at` / `finished_at` | Execution timestamps |
| `attempt` | Retry attempt number (1 = first attempt) |

### GET /api/runs/:id/steps/:step_id

Show detail for a single step run. `:step_id` may be a numeric id or the step name
string — the controller resolves both (`find_step_run/2` in `run_controller.ex`).

**Response 200:**
```json
{
  "data": {
    "id": 7,
    "status": "completed",
    "output": "step output text",
    "error": null,
    "exit_code": 0,
    "started_at": "2026-03-29T12:00:00Z",
    "finished_at": "2026-03-29T12:00:03Z",
    "attempt": 1
  }
}
```

**Response 404:**
```json
{"error": "Step not found"}
```

## Step Heartbeat

### POST /api/runs/:run_id/steps/:step_id/heartbeat

Extends the deadline for a step that is currently in `running` status, preventing
premature timeout termination. Intended for long-running steps (such as interactive
Claude Code agent sessions) that are actively making progress but exceed the default
step timeout.

The step must exist and must be in `running` status. Both `:run_id` and `:step_id`
must be integer IDs.

**Request body:** None required.

**Response 200:**
```json
{
  "data": {
    "step_run_id": 7,
    "deadline": "2026-03-29T12:05:00Z",
    "extensions_used": 2
  }
}
```

**Response fields:**

| Field | Description |
|-------|-------------|
| `step_run_id` | ID of the step run whose deadline was extended |
| `deadline` | New deadline as an ISO 8601 UTC timestamp |
| `extensions_used` | Running count of how many times this step's deadline has been extended |

**Error responses:**

| Status | Body | Cause |
|--------|------|-------|
| 404 | `{"error": "Step not found"}` | Step run does not exist |
| 404 | `{"error": "Step is not running"}` | Step exists but is not in `running` status |
| 422 | `{"error": "<changeset details>"}` | Deadline update changeset failure |

## Bundle Endpoints

### GET /api/bundles

List bundles in the Runex cache. Discovers bundle directories via
`Runex.Paths.discover_bundles/0` and merges filesystem presence with DB-backed
provenance. The DB is the authoritative source for `imported_at`, `sha256`, and
`source`; `version` is read from the bundle's `mise.toml`. Bundles not yet in
the DB have `null` provenance fields.

**Response 200:**
```json
{
  "bundles": [
    {
      "name": "core",
      "version": "0.0.10",
      "imported_at": "2026-03-29T12:00:00Z",
      "sha256": "abc123...",
      "source": "https://github.com/vinnie357/vantageex/releases/download/core-v0.0.10/core-0.0.10.tar.gz"
    },
    {
      "name": "legacy-bundle",
      "version": null,
      "imported_at": null,
      "sha256": null,
      "source": null
    }
  ]
}
```

Note: The response key is `"bundles"` (not `"data"`), as returned by the `index/2` action
in `bundle_controller.ex`.

### POST /api/bundles/import

Import a workflow bundle. Supports two modes sharing one route:

**Mode 1 — Multipart upload (push mode):**

`Content-Type: multipart/form-data`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `archive` or `bundle` | file | yes | tar.gz archive of the bundle directory |
| `sha256` | string | no | Expected SHA-256 checksum of the archive |

**Response 201:**
```json
{
  "data": {
    "name": "my-bundle",
    "version": "0.0.1",
    "workflow_count": 3
  }
}
```

**Mode 2 — JSON pull mode (via `BUNDLE_SOURCES`):**

Resolves the tarball from the instance's `BUNDLE_SOURCES` configuration
(comma- or whitespace-separated list of GitHub Release base URLs or bare `owner/repo`
shorthand, which is auto-expanded to `https://github.com/<owner>/<repo>/releases/download`).
The first source that returns HTTP 200 wins.

**Request body:**
```json
{
  "name": "core",
  "version": "0.0.10"
}
```

**Response 201:**
```json
{
  "data": {
    "name": "core",
    "version": "0.0.10",
    "workflow_count": 5,
    "source": "https://github.com/vinnie357/vantageex/releases/download/core-v0.0.10/core-0.0.10.tar.gz"
  }
}
```

**Mode 3 — Direct URL pull:**

When a full source URL is known at call time, pass `source` explicitly to bypass
`BUNDLE_SOURCES` resolution.

**Request body:**
```json
{
  "name": "core",
  "version": "0.0.10",
  "source": "https://github.com/vinnie357/vantageex/releases/download/core-v0.0.10/core-0.0.10.tar.gz"
}
```

**Error responses:**

| Status | Body | Cause |
|--------|------|-------|
| 404 | `{"error": "bundle <name>@<version> not found ...", "tried": [...]}` | Bundle not found in any source |
| 422 | `{"error": "BUNDLE_SOURCES not configured"}` | Pull mode but env not set |
| 422 | `{"error": "<details>"}` | Bundle validation failed |
| 502 | `{"error": "fetch failed: ..."}` | Upstream fetch error |

### POST /api/bundles/reload

Invalidate the bundle resolver cache for the listed bundles. An empty body or omitted
`bundles` field triggers a full reload. Currently, `Runex.Paths.discover_bundles/0`
reads the filesystem on every call (no in-process cache), so this endpoint confirms
which bundles exist on disk and reports missing ones in `failed`.

**Request body (optional):**
```json
{
  "bundles": ["core", "my-bundle"]
}
```

**Response 200:**
```json
{
  "reloaded": ["core", "my-bundle"],
  "failed": [
    {"name": "nonexistent-bundle", "reason": "not_found"}
  ]
}
```

Always returns HTTP 200. Missing bundle names appear in `failed`, not as an error status.

### POST /api/bundles/sync

Trigger re-sync of all bundles from configured sources. Submits the `bundle-sync`
workflow internally. Requires either the `bundle_sources` param or the `BUNDLE_SOURCES`
environment variable.

**Request body (optional):**
```json
{
  "bundle_sources": "https://github.com/org/repo/releases/download"
}
```

**Response 201:**
```json
{
  "data": {
    "run_id": 99,
    "status": "started",
    "watch": "/api/runs/99"
  }
}
```

Note: The 0.1.0 api.md showed a `200` with `{"data": {"synced": 5, "message": ...}}`.
The controller (`submit_and_respond/2`) actually returns `201` with a `run_id` and
`watch` path. The sync runs asynchronously; poll `/api/runs/:run_id` for completion.

**Error responses:**

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "bundle_sources required (param or BUNDLE_SOURCES env)"}` | No sources configured |
| 422 | `{"error": "<details>"}` | Workflow submission failed |

### POST /api/bundles/webhook

Webhook receiver for automated bundle sync triggers (GitHub/GitLab push events).
Checks whether the repository in the payload appears in `BUNDLE_SOURCES`. If matched,
submits the `bundle-sync` workflow. Ignores webhooks from repositories not in
`BUNDLE_SOURCES`.

**Request body (GitHub push event format):**
```json
{
  "event": "push",
  "repository": {
    "clone_url": "https://github.com/org/repo.git",
    "ssh_url": "git@github.com:org/repo.git",
    "html_url": "https://github.com/org/repo"
  }
}
```

The controller accepts `clone_url`, `ssh_url`, or `html_url` — first non-null value wins.

**Response 201** (sync submitted):
```json
{
  "data": {
    "run_id": 100,
    "status": "started",
    "watch": "/api/runs/100"
  }
}
```

**Response 200** (repo not in sources — ignored):
```json
{
  "status": "ignored",
  "reason": "repo not in BUNDLE_SOURCES"
}
```

**Error responses:**

| Status | Body | Cause |
|--------|------|-------|
| 400 | `{"error": "no repository in payload"}` | Payload missing `repository` object |
| 422 | `{"error": "BUNDLE_SOURCES not configured"}` | Env not set |

## Federation Endpoints

Federation requires Postgres mode (`RUNEX_DATABASE_URL=postgres://...`) and cluster
formation via libcluster. In standalone SQLite mode these endpoints respond but cluster
operations will see zero peers. See `docs/federation.md` for deployment patterns.

### GET /api/federation/nodes

Lists all nodes in the Erlang cluster with their metadata. The calling node is always
first in the list with `"status": "self"`. Peers discovered via `Runex.Network.Cluster.peers/0`
are queried via `:rpc.call` and marked `"connected"` on success or `"unreachable"` on
RPC failure.

**Response 200:**
```json
{
  "nodes": [
    {
      "node": "runex@host-a",
      "region": "us-east-1",
      "datacenter": "dc1",
      "hostname": "host-a",
      "ip": "100.64.0.1",
      "status": "self"
    },
    {
      "node": "runex@host-b",
      "region": "us-east-1",
      "datacenter": "dc1",
      "hostname": "host-b",
      "ip": "100.64.0.2",
      "status": "connected"
    },
    {
      "node": "runex@host-c",
      "status": "unreachable"
    }
  ]
}
```

Node fields (present when reachable):

| Field | Description |
|-------|-------------|
| `node` | BEAM node name (`runex@<hostname>`) |
| `region` | `RUNEX_REGION` value advertised by this node |
| `datacenter` | `RUNEX_DATACENTER` value advertised by this node |
| `hostname` | System hostname |
| `ip` | Advertised IP address |
| `status` | `"self"`, `"connected"`, or `"unreachable"` |

### POST /api/federation/runs

Submit a workflow run, optionally routed to a specific cluster node. Requires
`workflow_id` (integer DB row id). If `target_node` is specified, the run is
dispatched to that peer via Erlang distribution (`:rpc.call`); otherwise it runs
on the local node.

**Request body:**
```json
{
  "workflow_id": 1,
  "target_node": "runex@host-b",
  "params": {
    "ENV": "production"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `workflow_id` | integer | yes | DB row id of the workflow to execute |
| `target_node` | string | no | BEAM node name to route the run to |
| `params` | object | no | Environment variable overrides for steps |

**Response 201:**
```json
{
  "data": {
    "id": 55,
    "status": "running",
    "workflow_id": 1,
    "started_at": "2026-03-29T12:00:00Z",
    "finished_at": null,
    "node": "runex@host-b",
    "inserted_at": "2026-03-29T12:00:00Z"
  }
}
```

**Error responses:**

| Status | Body | Cause |
|--------|------|-------|
| 400 | `{"error": "workflow_id is required"}` | Missing `workflow_id` |
| 404 | `{"error": "workflow not found"}` | Workflow DB row not found |
| 422 | `{"error": "<details>"}` | Local execution failure |
| 502 | `{"error": "remote node unreachable: ..."}` | RPC to `target_node` failed |
| 502 | `{"error": "unknown node: ..."}` | `target_node` not in the known atom table |

### GET /api/federation/runs/:id

Query run status by ID. First checks the local database; if not found, queries each
peer via `:rpc.call`. Returns 404 only when the run is not found on any node.

**Response 200:**
```json
{
  "data": {
    "id": 55,
    "status": "completed",
    "workflow_id": 1,
    "started_at": "2026-03-29T12:00:00Z",
    "finished_at": "2026-03-29T12:00:10Z",
    "node": "runex@host-b",
    "inserted_at": "2026-03-29T12:00:00Z"
  }
}
```

**Response 404:**
```json
{"error": "run not found"}
```
