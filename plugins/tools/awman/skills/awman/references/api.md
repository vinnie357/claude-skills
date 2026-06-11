# awman REST API

Reference for the awman REST API server as of v0.10.0.

Source: https://github.com/prettysmartdev/awman/blob/main/docs/09-api-mode.md and
docs/10-remote-mode.md — accessed 2026-06-11.

**Prefer `awman remote` over raw curl** when driving the server from a shell. The `awman remote` CLI carries auth, sets the session header, and formats output — raw curl is appropriate only when integrating from external systems that cannot invoke awman.

> **Migrating from amux:** the server command `amux headless start/status/kill` is now `awman api start/status/logs/kill`, and the `headless.*` config keys are now `api.*`. The endpoint surface and the `x-awman-session` header are otherwise unchanged in shape.

---

## Server lifecycle

```sh
awman api start --port 9876 --workdirs /home/user/my-project        # foreground
awman api start --background --port 9876 --workdirs /repo            # background
awman api start --refresh-key --port 9876 --workdirs /repo           # regenerate API key
awman api status                                                     # check state
awman api logs                                                       # tail logs (background server)
awman api kill                                                       # graceful shutdown (30s grace)
```

The plaintext API key prints once on first `awman api start`; only its SHA-256 hash is stored at `~/.awman/api/api_key.hash`. Save the key — it is not recoverable. The default port is configurable via the `api.port` global config key (`awman config set --global api.port <n>`); `--port` overrides it per start.

### TLS

The server speaks **HTTPS with a self-signed certificate by default**. For local plain-HTTP use, pass `--dangerously-skip-tls`. Examples below assume `--dangerously-skip-tls` (so curl uses `http://`); for the default HTTPS server use `https://` and trust the self-signed cert (e.g. `curl --cacert` or `-k` for local testing).

---

## Authentication

All endpoints except `/v1/status` require an `Authorization` header.

```
Authorization: Bearer <api-key>
Authorization: <api-key>
```

Hash verification uses constant-time comparison. A missing header returns HTTP 401 `{"error": "API key required..."}`; a wrong key returns HTTP 401 `{"error": "Invalid API key."}`.

---

## Allowlisted working directories

Sessions can only be created in directories supplied via `--workdirs` at startup or listed in the `api.workDirs` global config key (the two are merged). A `POST /v1/sessions` with a `workdir` outside the allowlist returns HTTP 403 with the allowed list:

```json
{"error": "...", "allowed_workdirs": ["/home/user/my-project"]}
```

Add a directory:

```sh
awman config set --global api.workDirs "/home/user/my-project"
```

---

## FIFO command queue

Within a single session, only one command runs at any moment; commands are processed in strict FIFO order. **Submission never blocks** — `POST /v1/commands` returns immediately with a `command_id` (HTTP 202, or 201 on success) and the command is enqueued. When a session is transitioning to `closing`, new submissions return HTTP 409 `"session is closing"`.

---

## Endpoint table

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/v1/status` | No | Server health: uptime, active sessions, running commands |
| `GET` | `/v1/workdirs` | Yes | List allowlisted working directories |
| `POST` | `/v1/sessions` | Yes | Create a session in an allowlisted workdir |
| `GET` | `/v1/sessions` | Yes | List sessions (supports `?status=active`) |
| `GET` | `/v1/sessions/:id` | Yes | Session details |
| `GET` | `/v1/sessions/:id/queue` | Yes | Queue status for the session |
| `DELETE` | `/v1/sessions/:id` | Yes | Close a session |
| `POST` | `/v1/commands` | Yes | Submit a command (requires `x-awman-session: <id>` header) |
| `GET` | `/v1/commands/:id` | Yes | Command status and metadata |
| `GET` | `/v1/commands/:id/logs` | Yes | Full captured output (snapshot) |
| `GET` | `/v1/commands/:id/logs/stream` | Yes | Live output via Server-Sent Events |
| `GET` | `/v1/workflows/:id` | Yes | Workflow state for a workflow-type command |

---

## Request and response shapes

### `POST /v1/sessions`

Request: `{"workdir": "/absolute/path/to/project"}` (must be in the allowlist, else 403).
Response (201): `{"id": "<session-id>", "workdir": "...", "status": "active", "created_at": "<ISO-8601>"}`.

### `POST /v1/commands`

Required header: `x-awman-session: <session-id>`.

```json
{
  "subcommand": "exec",
  "args": ["prompt", "<prompt text>", "--non-interactive"]
}
```

The `subcommand` + `args` mirror the CLI surface in `command-reference.md`. Response (202): `{"id": "<command-id>", "session_id": "<session-id>", "status": "running", "created_at": "<ISO-8601>"}`.

### `GET /v1/commands/:id`

```json
{
  "id": "<command-id>",
  "session_id": "<session-id>",
  "status": "running | completed | failed",
  "created_at": "<ISO-8601>",
  "completed_at": "<ISO-8601 | null>",
  "exit_code": "<integer | null>"
}
```

Poll until `status` is `completed` or `failed`. Buffered logs are also written to disk under `~/.awman/api/sessions/<session-id>/commands/<command-id>/`. For `exec workflow` commands, workflow state lands at `.../workflow.state.json`.

### `GET /v1/commands/:id/logs/stream`

Server-Sent Events (`Content-Type: text/event-stream`). Each `data: <line>\n\n` is one line of agent output; the stream closes when the command completes or fails.

### `GET /v1/status`

No auth. `{"uptime_seconds": 3600, "active_sessions": 2, "running_commands": 1}`.

---

## Wired curl example (plain-HTTP server started with --dangerously-skip-tls)

```sh
# 1. Create a session
SESSION=$(curl -s -X POST http://localhost:9876/v1/sessions \
  -H 'Authorization: Bearer <api-key>' \
  -H 'Content-Type: application/json' \
  -d '{"workdir":"/home/user/my-project"}' | jq -r '.id')

# 2. Submit a command
COMMAND=$(curl -s -X POST http://localhost:9876/v1/commands \
  -H 'Authorization: Bearer <api-key>' \
  -H "x-awman-session: $SESSION" \
  -H 'Content-Type: application/json' \
  -d '{"subcommand":"exec","args":["prompt","Fix the failing tests","--non-interactive"]}' \
  | jq -r '.id')

# 3. Stream logs until completion, then check final status
curl -N http://localhost:9876/v1/commands/$COMMAND/logs/stream \
  -H 'Authorization: Bearer <api-key>'
curl -s http://localhost:9876/v1/commands/$COMMAND \
  -H 'Authorization: Bearer <api-key>' | jq '{status, exit_code}'
```

---

## Using `awman remote` instead of curl

```sh
# Configure once (global config)
awman config set --global remote.defaultAddr https://build-server.example.com:9876
awman config set --global remote.defaultAPIKey <your-api-key>

# Create a session, dispatch and stream, then close
SESSION=$(awman remote session start /home/user/my-project | grep 'Session started:' | awk '{print $NF}')
awman remote run "exec prompt 'Fix the failing tests'" --session "$SESSION" --follow
awman remote session kill "$SESSION"
```

`awman remote` handles the `x-awman-session` header and auth. Session target resolves from `--session`, then `AWMAN_REMOTE_SESSION`, then (TUI only) the last/picked session. `AWMAN_REMOTE_ADDR` and `AWMAN_API_KEY` override the configured address and key for CI use.

---

Back to skill: [SKILL.md](../SKILL.md)
