# Runex API Reference

Full REST API reference for Runex. Default base URL: `http://localhost:4001`.

## Table of Contents

- [Authentication](#authentication)
- [Health Endpoints](#health-endpoints)
- [Workflow Endpoints](#workflow-endpoints)
- [Info Endpoints](#info-endpoints)
- [Run Endpoints](#run-endpoints)
- [Bundle Endpoints](#bundle-endpoints)

## Authentication

Controlled by the `RUNEX_API_TOKEN` environment variable.

- **Unset**: API is open, no auth required (dev-friendly default)
- **Set**: Requires `Authorization: Bearer <token>` header on all `/api/*` requests

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

Server build and version information.

**Response 200:**
```json
{
  "git_sha": "abc1234",
  "build_time": "2026-03-29T12:00:00Z",
  "version": "0.1.0"
}
```

## Workflow Endpoints

### GET /api/workflows

List all registered workflows, ordered by last update.

**Response 200:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "core",
      "description": "Shared primitives for all Runex instances",
      "schedule": null,
      "source_path": "bundles/core/workflow.toml",
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

Import a workflow from content, URL, or git source.

**Request body:**
```json
{
  "source": "content",
  "content": "# TOML workflow content...",
  "name": "my-workflow"
}
```

Source types:
- `content`: Inline TOML/YAML workflow definition
- `url`: URL to fetch workflow from
- `git`: Git repository URL with optional path and ref

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

## Run Endpoints

### GET /api/runs

List runs (latest 50). Optional query parameter: `?workflow_id=<id>`.

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

Execute a workflow.

**Request body:**
```json
{
  "workflow_path": "bundles/core/workflows/tool-verify.toml",
  "params": {
    "TOOLS": "mise,nu,git",
    "FORMAT": "json"
  }
}
```

- `workflow_path` (string, required): Path to workflow file. Resolved via the workflow search order documented in `Runex.Paths`.
- `params` (object, optional): Key-value pairs injected as environment variables into step execution. Sensitive params (matching `password`, `secret`, `token`, `key`, `url` patterns) are auto-masked in output.

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
| 403 | `{"error": "Invalid workflow path"}` | Path not found or path traversal attempt |
| 400 | `{"error": "Unsupported workflow format"}` | File extension not `.toml`, `.yaml`, or `.yml` |
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
- `id`: Unique step run identifier
- `status`: Step execution status
- `output`: Captured stdout from the step
- `error`: Captured stderr or error message (null on success)
- `exit_code`: OS process exit code (0 = success)
- `started_at` / `finished_at`: Execution timestamps
- `attempt`: Retry attempt number (1 = first attempt)

### GET /api/runs/:id/steps/:step_id

Show detail for a single step run.

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

## Bundle Endpoints

### POST /api/bundles/import

Import a workflow bundle from a tar.gz archive. Accepts multipart form upload.

**Request:** `Content-Type: multipart/form-data`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| file | file | yes | tar.gz archive of the bundle directory |

**Response 201:**
```json
{
  "data": {
    "name": "my-bundle",
    "workflows_imported": 3,
    "message": "Bundle imported successfully"
  }
}
```

**Error responses:**

| Status | Body | Cause |
|--------|------|-------|
| 400 | `{"error": "Invalid archive format"}` | Not a valid tar.gz |
| 422 | `{"error": "<details>"}` | Bundle validation failed |

### POST /api/bundles/sync

Trigger re-sync of all bundles from configured sources.

**Response 200:**
```json
{
  "data": {
    "synced": 5,
    "message": "Bundle sync complete"
  }
}
```

### POST /api/bundles/webhook

Webhook receiver for automated bundle sync triggers.

**Request body:**
```json
{
  "event": "push",
  "repository": "org/repo"
}
```

**Response 200:**
```json
{
  "status": "accepted"
}
```
