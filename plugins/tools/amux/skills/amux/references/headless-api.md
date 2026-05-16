# amux Headless REST API

Reference for the amux headless HTTP server REST API as of v0.8.0.

Source: https://github.com/prettysmartdev/amux/blob/main/docs/08-headless-mode.md — accessed 2026-05-16.
Remote-mode CLI docs: https://github.com/prettysmartdev/amux/blob/main/docs/09-remote-mode.md — accessed 2026-05-16.

**Prefer `amux remote` over raw curl** when driving the server from a shell. The `amux remote` CLI carries auth, sets the session header, and formats output — raw curl is appropriate only when integrating from external systems or scripts that cannot invoke amux.

---

## Server lifecycle

Start the server (prints the API key on first run — save it; it is not recoverable):

```sh
amux headless start                # default port 9876
amux headless start --port 9877   # custom port
```

Check status:

```sh
amux headless status
```

Stop the server:

```sh
amux headless kill
```

---

## Authentication

All endpoints except `/v1/status` require an `Authorization` header.

**Accepted forms:**

```
Authorization: Bearer <api-key>
Authorization: <api-key>
```

The API key is generated as 32 random bytes on the first `amux headless start`. The server stores only its SHA-256 hash and prints the plaintext key once at startup. If the key is lost, delete `$HOME/.amux/headless/` to regenerate (this also destroys all session state).

---

## Allowlisted working directories

Sessions can only be created in directories listed in the `headless.workDirs` global config key. Attempting to create a session in any other directory returns HTTP 403.

Add a directory:

```sh
amux config set --global headless.workDirs /home/user/my-project
```

List currently allowlisted directories:

```sh
curl http://localhost:9876/v1/workdirs \
  -H 'Authorization: Bearer <api-key>'
```

---

## One-command-per-session contract

A session accepts exactly one running command at a time. Submitting a `POST /v1/commands` while the session already has a running command returns **HTTP 403**. Poll `GET /v1/commands/:id` until `status` is `completed` or `failed` before submitting the next command.

---

## Endpoint table

| Method | Path | Auth required | Purpose |
|--------|------|--------------|---------|
| `GET` | `/v1/status` | No | Server health: uptime, active session count, running command count |
| `GET` | `/v1/workdirs` | Yes | List allowlisted working directories |
| `POST` | `/v1/sessions` | Yes | Create a session in an allowlisted workdir |
| `GET` | `/v1/sessions` | Yes | List sessions; supports `?status=active` query param |
| `GET` | `/v1/sessions/:id` | Yes | Get session details |
| `DELETE` | `/v1/sessions/:id` | Yes | Close a session |
| `POST` | `/v1/commands` | Yes | Submit a subcommand to a session (requires `x-amux-session: <id>` header) |
| `GET` | `/v1/commands/:id` | Yes | Command status and metadata |
| `GET` | `/v1/commands/:id/logs` | Yes | Full captured output (buffered) |
| `GET` | `/v1/commands/:id/logs/stream` | Yes | Live output via Server-Sent Events |
| `GET` | `/v1/workflows/:id` | Yes | Workflow state for a workflow-type command |

---

## Request and response schemas

### `POST /v1/sessions`

**Request body:**

```json
{
  "workdir": "/absolute/path/to/project"
}
```

`workdir` must be in `headless.workDirs`. Returns HTTP 403 if not.

**Response (201 Created):**

```json
{
  "id": "<session-id>",
  "workdir": "/absolute/path/to/project",
  "status": "active",
  "created_at": "<ISO-8601 timestamp>"
}
```

---

### `GET /v1/sessions`

**Query parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | Filter by status; `active` is the documented value |

**Response (200 OK):**

```json
[
  {
    "id": "<session-id>",
    "workdir": "/absolute/path/to/project",
    "status": "active",
    "created_at": "<ISO-8601 timestamp>"
  }
]
```

---

### `GET /v1/sessions/:id`

**Response (200 OK):** same shape as a single session object from the list endpoint.

---

### `DELETE /v1/sessions/:id`

No request body. Returns 204 No Content on success.

---

### `POST /v1/commands`

**Required header:** `x-amux-session: <session-id>`

**Request body:**

```json
{
  "subcommand": "exec",
  "args": ["prompt", "<prompt text>", "--non-interactive"]
}
```

The `subcommand` field identifies the amux subcommand to run (`exec`, `chat`, etc.). The `args` array passes positional arguments and flags to that subcommand, matching the CLI surface documented in `command-reference.md`.

Returns HTTP 403 immediately if the session already has a running command (one-command-per-session contract).

**Response (202 Accepted):**

```json
{
  "id": "<command-id>",
  "session_id": "<session-id>",
  "status": "running",
  "created_at": "<ISO-8601 timestamp>"
}
```

---

### `GET /v1/commands/:id`

**Response (200 OK):**

```json
{
  "id": "<command-id>",
  "session_id": "<session-id>",
  "status": "running | completed | failed",
  "created_at": "<ISO-8601 timestamp>",
  "completed_at": "<ISO-8601 timestamp | null>",
  "exit_code": "<integer | null>"
}
```

Poll this endpoint until `status` is `completed` or `failed` before submitting the next command to the session.

---

### `GET /v1/commands/:id/logs`

**Response (200 OK):** plain text body containing the full buffered output of the command. Also written to disk at:

```
~/.amux/headless/sessions/<session-id>/commands/<command-id>/output.log
```

---

### `GET /v1/commands/:id/logs/stream`

Server-Sent Events stream. Connect and receive newline-delimited events while the command is running.

**Response headers:**

```
Content-Type: text/event-stream
Cache-Control: no-cache
```

**SSE event format:**

```
data: <line of output>\n\n
```

Each `data:` line is one line of output from the agent process. The stream closes when the command completes or fails.

---

### `GET /v1/workflows/:id`

`id` is the command ID of a workflow-type command (i.e. one submitted via `amux exec workflow`).

**Response (200 OK):**

```json
{
  "command_id": "<command-id>",
  "steps": [
    {
      "name": "<step-name>",
      "status": "pending | running | completed | failed",
      "agent": "<agent-name>",
      "started_at": "<ISO-8601 timestamp | null>",
      "completed_at": "<ISO-8601 timestamp | null>"
    }
  ]
}
```

---

### `GET /v1/status`

No auth required. Returns server health.

**Response (200 OK):**

```json
{
  "uptime_seconds": 3600,
  "active_sessions": 2,
  "running_commands": 1
}
```

---

## Wired curl examples: create session → submit command → stream logs

The three commands below form a complete workflow. Run them in sequence; each uses the output of the previous step.

**Step 1: Create a session**

```sh
SESSION=$(curl -s -X POST http://localhost:9876/v1/sessions \
  -H 'Authorization: Bearer <api-key>' \
  -H 'Content-Type: application/json' \
  -d '{"workdir":"/home/user/my-project"}' \
  | jq -r '.id')

echo "Session: $SESSION"
```

**Step 2: Submit a command**

```sh
COMMAND=$(curl -s -X POST http://localhost:9876/v1/commands \
  -H 'Authorization: Bearer <api-key>' \
  -H "x-amux-session: $SESSION" \
  -H 'Content-Type: application/json' \
  -d '{
    "subcommand": "exec",
    "args": ["prompt", "Fix the failing tests", "--non-interactive"]
  }' \
  | jq -r '.id')

echo "Command: $COMMAND"
```

**Step 3: Stream logs until completion**

```sh
curl -N http://localhost:9876/v1/commands/$COMMAND/logs/stream \
  -H 'Authorization: Bearer <api-key>'
```

After the stream closes, verify the final status:

```sh
curl -s http://localhost:9876/v1/commands/$COMMAND \
  -H 'Authorization: Bearer <api-key>' \
  | jq '{status, exit_code}'
```

---

## Using `amux remote` instead of curl

The same three-step sequence using `amux remote` (requires `remote.defaultAddr` and `remote.defaultAPIKey` in global config, or `AMUX_*` env vars):

```sh
# Create a session
amux remote session start /home/user/my-project

# Submit a command and stream output
amux remote run "exec prompt 'Fix the failing tests'" --follow
```

`amux remote` automatically resolves the session created for that directory and handles the `x-amux-session` header.

---

Back to skill: [SKILL.md](../SKILL.md)
