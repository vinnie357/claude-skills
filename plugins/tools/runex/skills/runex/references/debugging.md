# Debugging Runex Workflows

Patterns for inspecting and troubleshooting Runex workflow runs.

## Table of Contents

- [Step Log Inspection](#step-log-inspection)
- [Common Failure Patterns](#common-failure-patterns)
- [Health Check Validation](#health-check-validation)
- [Troubleshooting Reference](#troubleshooting-reference)

## Step Log Inspection

Default Runex port is 4000. Some operator setups (notably VantageEx co-deployment) use 4001 to avoid colliding with VantageEx on 4000 — adjust the `http://localhost:4001` examples accordingly if your deployment is on 4001.

### Basic Flow

1. Submit a workflow and capture the run ID:

```bash
RUN=$(curl -s -X POST http://localhost:4001/api/runs \
  -H "Content-Type: application/json" \
  -d '{"workflow_path": "bundles/core/workflows/system-info.toml"}')
RUN_ID=$(echo $RUN | jq -r '.data.id')
```

2. Poll run status until terminal:

```bash
curl -s http://localhost:4001/api/runs/$RUN_ID | jq '.data.status'
```

3. Fetch step logs:

```bash
curl -s http://localhost:4001/api/runs/$RUN_ID/steps | jq '.data[]'
```

4. Check individual step details:

```bash
# Show output of each step
curl -s http://localhost:4001/api/runs/$RUN_ID/steps | jq '.data[] | {name: .id, status, exit_code, output, error}'
```

### Reading Step Output

Each step run returns:
- `output` -- captured stdout from the step process
- `error` -- captured stderr or error message (null on success)
- `exit_code` -- 0 means success, non-zero indicates failure
- `attempt` -- retry attempt number (1 = first try)

### Identifying Failures

```bash
# Show only failed steps
curl -s http://localhost:4001/api/runs/$RUN_ID/steps | \
  jq '.data[] | select(.exit_code != 0) | {id, status, exit_code, error}'
```

## Common Failure Patterns

### Workflow Path Not Found (403)

```json
{"error": "Invalid workflow path"}
```

Causes:
- Typo in `workflow_path`
- Bundle directory not in the workflow search path
- Runex working directory differs from expected location

Fix: Verify the path exists on the filesystem. Check `RUNEX_WORKFLOWS_DIR` and `RUNEX_WORKFLOW_PATH` env vars. Use `ls` to confirm bundle location.

### Unsupported Format (400)

```json
{"error": "Unsupported workflow format"}
```

Cause: File extension is not `.toml`, `.yaml`, or `.yml`.

### Parse Error (422)

Cause: TOML/YAML syntax error in the workflow file. Check the error message for line numbers and details.

### Step Execution Failure

When a step fails (non-zero exit code):
1. Read the `error` field for stderr output
2. Read the `output` field for any partial stdout
3. Check if required tools are installed (`mise install`)
4. Check if the `BUNDLE_DIR` env var points to the correct location
5. Verify scripts exist at the expected paths

### Missing Tools

If a step fails because a tool is not found (e.g., `nu: command not found`):
1. Check the bundle's `mise.toml` for required tools
2. Run `mise install` in the Runex working directory
3. Verify with `mise ls` that tools are active

### Sensitive Param Masking

Params matching patterns like `password`, `secret`, `token`, `key`, or `url` are automatically masked in step output. If debugging requires seeing these values, check the actual environment rather than step logs.

## Long-Running Steps and Heartbeats

Long-running steps may timeout before completing. To prevent premature timeout kill, a step can call `POST /api/runs/:run_id/steps/:step_id/heartbeat` which extends the deadline by `timeout_extension`.

### Sending a Heartbeat

```bash
curl -s -X POST http://localhost:4001/api/runs/$RUN_ID/steps/$STEP_ID/heartbeat | jq '.'
```

Success returns:
```json
{
  "data": {
    "step_run_id": 42,
    "deadline": "2025-05-16T12:34:56.000000Z",
    "extensions_used": 1
  }
}
```

A 404 response means the step does not exist or is not in running status.

### Checking Heartbeat State

```bash
curl -s http://localhost:4001/api/runs/$RUN_ID/steps | jq '.data[] | {step_id: .id, last_heartbeat_at, extensions_used, deadline}'
```

Response includes:
- `last_heartbeat_at` -- timestamp of most recent heartbeat (null if none sent)
- `extensions_used` -- count of successful heartbeats sent
- `deadline` -- current deadline (extended by heartbeat, resets on restart)

## Agent Run Debugging

Agent runs (Claude Code tmux sessions) are decoupled from workflow lifecycle. A workflow can complete while the agent session is still running, or vice versa. Agent runs are tracked independently as their own resource.

### Inspecting a Specific Agent Run

```bash
curl -s http://localhost:4001/api/agent_runs/$AGENT_RUN_ID | jq '.data'
```

Response shape:
```json
{
  "data": {
    "id": "agent-123",
    "run_id": 42,
    "epic_id": "VIN-99",
    "session_name": "tmux-session-abc",
    "workspace_path": "/tmp/workspace-abc",
    "status": "running",
    "exit_classification": null,
    "started_at": "2025-05-16T10:00:00Z",
    "finished_at": null,
    "last_polled_at": "2025-05-16T10:15:30Z",
    "inserted_at": "2025-05-16T10:00:00Z"
  }
}
```

Key fields:
- `status` -- current state: `running`, `completed`, `failed`, etc.
- `exit_classification` -- reason for exit if finished (null while running)
- `last_polled_at` -- most recent poll timestamp (tracks heartbeat liveness)
- `workspace_path` -- where the agent session files and logs are stored

### Listing Recent Agent Runs

```bash
curl -s http://localhost:4001/api/agent_runs | jq '.data[] | {id, session_name, status, started_at}'
```

Returns paginated list of agent runs. Add `?limit=20&offset=0` to control pagination.

## Health Check Validation

Before debugging workflow issues, confirm Runex is healthy:

```bash
# Liveness
curl -s http://localhost:4001/api/health | jq '.status'
# Expected: "healthy"

# Readiness (includes DB check)
curl -s http://localhost:4001/api/ready | jq '.status'
# Expected: "ready"

# If not ready, check database
curl -s http://localhost:4001/api/ready | jq '.checks'
```

### Using the Core Bundle for Diagnostics

```bash
# System info
curl -X POST http://localhost:4001/api/runs \
  -H "Content-Type: application/json" \
  -d '{"workflow_path": "bundles/core/workflows/system-info.toml"}'

# Tool verification
curl -X POST http://localhost:4001/api/runs \
  -H "Content-Type: application/json" \
  -d '{"workflow_path": "bundles/core/workflows/tool-verify.toml"}'

# Health check
curl -X POST http://localhost:4001/api/runs \
  -H "Content-Type: application/json" \
  -d '{"workflow_path": "bundles/core/workflows/health-check.toml"}'
```

## Troubleshooting Reference

| Problem | Diagnosis | Fix |
|---------|-----------|-----|
| Health returns HTML | Database needs migration | `cd ~/github/runex && mix ecto.migrate` then restart |
| Postgres not ready | Check connectivity | `pg_isready -h localhost -p 5432` |
| Run stuck in "running" | Step process may be hanging | Check step logs, look for blocking commands |
| Auth 401 on API | Token mismatch | Verify `RUNEX_API_TOKEN` matches header value |
| Bundle not found | Path resolution miss | Check `RUNEX_WORKFLOWS_DIR`, verify bundle directory exists |
| Step output is masked | Sensitive param pattern match | Expected behavior for password/secret/token/key/url params |
| Too many Postgres conns | Zombie connections | Check with `pg_stat_activity` query |
| Heartbeat returns 404 | run_id or step_id mismatch | Verify both exist via `GET /api/runs/:id/steps`; step IDs are per-run, not global |
| Federation node not visible | libcluster/DNS misconfig OR not running Postgres | Check `RUNEX_DATABASE_URL` points at Postgres; verify `DNS_CLUSTER_QUERY` resolves; federation needs Postgres + libcluster (SQLite mode = no federation) |
