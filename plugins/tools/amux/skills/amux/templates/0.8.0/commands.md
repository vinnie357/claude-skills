# amux v0.8.0 — Command Reference

Pinned to amux v0.8.0 (released 2026-04-12, accessed 2026-05-16).
Newer versions get their own `templates/X.Y.Z/commands.md` per the `/claude-code:skill-update` convention.

Source: https://github.com/prettysmartdev/amux (README + docs/, accessed 2026-05-16)

---

## What's in v0.8.0

Internal refactor into a strict four-layer architecture (data → engine → command → frontend). CLI surfaces, config files, and persisted state are **unchanged from v0.7.x** — no migration required. New feature: `overlays.skills` config key for mounting custom skill directories into agent containers.

---

## `amux` (no args)

Open the TUI.

| TUI Keybinding | Action |
|----------------|--------|
| `Ctrl+T` | New tab / new session |
| `Ctrl+A` | Switch between sessions |
| `Ctrl+D` | Detach from current session |
| `Ctrl+Y` | Copy selected text to clipboard |

Scrollback: 10,000 lines by default (configurable via `terminal_scrollback_lines`).

---

## `amux init`

Scaffold a project for amux use.

```sh
amux init [--agent <name>]
```

Creates:
- `aspec/.amux.json` — per-repo config (commit this)
- `.amux/Dockerfile.<agent>` — per-agent Dockerfiles (one per supported agent)
- `.amux/config.json` — local-only overlay (do not commit)

**Example:**
```sh
amux init --agent claude
```

---

## `amux ready`

Verify environment and optionally rebuild agent Dockerfiles.

```sh
amux ready [--refresh]
```

`--refresh` — Rebuild the agent container image. Run after editing `.amux/Dockerfile.<agent>` or after an amux version upgrade that changes base image requirements.

**Example:**
```sh
amux ready --refresh
```

---

## `amux chat`

Start an interactive agent session inside the TUI.

```sh
amux chat [--agent <name>] [--plan] [--auto] [--yolo]
```

| Flag | Effect |
|------|--------|
| `--agent <name>` | Override the per-repo / global default agent |
| `--plan` | Agent operates in planning mode |
| `--auto` | Auto-approve file edits; still prompts for other tools |
| `--yolo` | Disable all permission prompts; run in a Git worktree |

**Examples:**
```sh
# Default agent, interactive
amux chat

# Override agent for this session
amux chat --agent codex

# Fully autonomous, worktree-isolated
amux chat --yolo
```

---

## `amux exec`

One-off execution without a persistent TUI session.

### `amux exec prompt`

```sh
amux exec prompt "<prompt-text>" [--agent <name>] [--non-interactive]
```

**Example:**
```sh
amux exec prompt "Explain the build script"
amux exec prompt "Fix the failing tests" --agent codex --non-interactive
```

### `amux exec workflow`

```sh
amux exec workflow <path> [--work-item <nnnn>] [--yolo] [--worktree] [--agent <name>]
```

| Flag | Effect |
|------|--------|
| `--work-item <nnnn>` | Zero-padded work item number; injects `{{work_item_number}}` and `{{work_item_content}}` |
| `--yolo` | Disable prompts; implicit `--worktree` |
| `--worktree` | Run workflow steps in a Git worktree |
| `--agent <name>` | Default agent for steps that don't specify one |

**Example:**
```sh
amux exec workflow ./workflows/plan-implement-review.md --work-item 0027 --yolo
```

---

## `amux new`

Scaffold new project artifacts.

```sh
amux new spec [--interview]       # Create numbered work item (e.g. 0028)
amux new workflow [--interview]   # Scaffold a workflow file
amux new skill [--interview]      # Create a custom skill for the skills overlay
```

`--interview` — Interactive prompting mode for guided creation.

**Examples:**
```sh
amux new spec --interview
amux new workflow
```

---

## `amux specs`

Manage work item files.

```sh
amux specs amend <nnnn>   # Update spec file <nnnn>
```

**Example:**
```sh
amux specs amend 0027
```

---

## `amux status`

Show a dashboard of active sessions and workflow runs.

```sh
amux status [--watch]
```

`--watch` — Continuously refresh the dashboard.

**Example:**
```sh
amux status --watch
```

---

## `amux config`

Read and write amux configuration.

```sh
amux config show                              # Merged effective config (global + per-repo)
amux config get <field>                       # Show one field with precedence breakdown
amux config set [--global] <field> <value>   # Write a config key
```

`--global` on `set` — Write to `~/.amux/config.json`. Without the flag, writes to the per-repo `aspec/.amux.json`.

**Examples:**
```sh
amux config show
amux config get default_agent
amux config set --global default_agent codex
amux config set agent claude
```

---

## `amux headless`

Manage the embedded REST server.

```sh
amux headless start [--port <n>]   # Start server (default: 9876)
amux headless status               # Check server state
amux headless kill                 # Stop server
```

**Examples:**
```sh
amux headless start
amux headless start --port 9000
amux headless status
amux headless kill
```

---

## `amux remote`

CLI client for a running headless server. Wraps the REST API.

```sh
amux remote run <cmd> [--follow]         # Submit a subcommand; --follow streams output
amux remote session start <dir>          # Create a headless session for <dir>
amux remote session kill <id>            # Close a headless session
```

**Examples:**
```sh
# Run a prompt against the headless server and stream output
amux remote run "exec prompt 'Fix the failing tests'" --follow

# Create a session
amux remote session start /home/user/my-project

# Close a session
amux remote session kill <session-id>
```

`amux remote` uses `remote.defaultAddr` and `remote.defaultAPIKey` from `~/.amux/config.json`. Override with `--addr` and `--api-key` flags when targeting a non-default server.

---

## `amux tui`

Explicit alias to open the TUI (same as running `amux` with no args).

```sh
amux tui
```

---

## Agents Supported in v0.8.0

`claude` | `codex` | `opencode` | `maki` | `gemini` | `copilot` | `crush` | `cline`

Each has a corresponding `Dockerfile.<agent>` in `.amux/`. Templates live at https://github.com/prettysmartdev/amux/tree/main/templates.

---

## Workflow File Formats

Three formats supported. Fields are **lowercase only** in all formats.

### Markdown (`.md`)

Field order is mandatory: `Depends-on` → `Agent` → `Model` → `Prompt`. Text after `Prompt:` is treated as prompt content.

```markdown
## Step: plan
Prompt: Read the following work item and produce an implementation plan.

{{work_item_content}}

## Step: implement
Depends-on: plan
Agent: codex
Model: claude-haiku-4-5
Prompt: Implement work item {{work_item_number}} according to the plan.
```

### TOML (`.toml`)

```toml
[[steps]]
name = "plan"
prompt = "Read the following work item and produce an implementation plan.\n\n{{work_item_content}}"

[[steps]]
name = "implement"
depends_on = ["plan"]
agent = "codex"
model = "claude-haiku-4-5"
prompt = "Implement work item {{work_item_number}} according to the plan."
```

### YAML (`.yml` / `.yaml`)

```yaml
steps:
  - name: plan
    prompt: |
      Read the following work item and produce an implementation plan.
      {{work_item_content}}
  - name: implement
    depends_on:
      - plan
    agent: codex
    model: claude-haiku-4-5
    prompt: "Implement work item {{work_item_number}} according to the plan."
```

### Template Variables

| Variable | Resolves to |
|----------|-------------|
| `{{work_item_number}}` | Zero-padded 4-digit spec number (e.g. `0027`) |
| `{{work_item_content}}` | Full text of the work item file |
| `{{work_item_section:[Name]}}` | Named section within the work item (case-insensitive) |

---

## Configuration Keys (v0.8.0)

| Key | Type | Default | Scope |
|-----|------|---------|-------|
| `default_agent` | string | `"claude"` | Global only |
| `runtime` | string | `"docker"` | Global only |
| `headless.workDirs` | array | `[]` | Global only |
| `headless.alwaysNonInteractive` | boolean | false | Global only |
| `remote.defaultAddr` | string | unset | Global only |
| `remote.defaultAPIKey` | string | unset | Global only |
| `remote.savedDirs` | array | `[]` | Global only |
| `terminal_scrollback_lines` | integer | 10000 | Both |
| `yoloDisallowedTools` | array | `[]` | Both |
| `envPassthrough` | array | `[]` | Both |
| `overlays.skills` | boolean | false | Both (additive) |
| `overlays.directories` | array | `[]` | Both (additive) |
| `agent` | string | `"claude"` | Per-repo only |
| `workItems.dir` | string | unset | Per-repo only |
| `workItems.template` | string | unset | Per-repo only |

`overlays.skills` and `overlays.directories` merge additively across scopes (not replaced). All other keys: per-repo wins over global.

---

## Headless REST API (v0.8.0)

Default port: `9876`. Auth: `Authorization: Bearer <api-key>`.

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/workdirs` | List allowlisted working directories |
| `POST` | `/v1/sessions` | Create session (`{"workdir": "..."}`) |
| `GET` | `/v1/sessions` | List sessions (`?status=active`) |
| `GET` | `/v1/sessions/:id` | Session details |
| `DELETE` | `/v1/sessions/:id` | Close session |
| `POST` | `/v1/commands` | Submit subcommand (`x-amux-session: <id>` header required) |
| `GET` | `/v1/commands/:id` | Command status |
| `GET` | `/v1/commands/:id/logs` | Captured output |
| `GET` | `/v1/commands/:id/logs/stream` | Live output (Server-Sent Events) |
| `GET` | `/v1/workflows/:id` | Workflow state for a command |
| `GET` | `/v1/status` | Server health (uptime, sessions, commands) |

One active command per session — second submit returns HTTP 403.
All commands are async — `POST /v1/commands` returns `command_id` immediately.

**Create session + submit command:**
```sh
curl -X POST http://localhost:9876/v1/sessions \
  -H 'Authorization: Bearer <api-key>' \
  -H 'Content-Type: application/json' \
  -d '{"workdir":"/home/user/my-project"}'

curl -X POST http://localhost:9876/v1/commands \
  -H 'Authorization: Bearer <api-key>' \
  -H 'x-amux-session: <session-id>' \
  -H 'Content-Type: application/json' \
  -d '{"subcommand":"exec","args":["prompt","Fix the failing tests","--non-interactive"]}'
```

---

## Known Sharp Edges in v0.8.0

1. Not a tmux wrapper — ships its own TUI.
2. Two config files: `aspec/.amux.json` (commit) vs `.amux/config.json` (local). Use `amux config show`.
3. Worktrees are never auto-deleted.
4. One active command per headless session.
5. `runtime` is global-only — no per-repo docker vs Apple Containers selection.
6. Markdown workflow field order is mandatory.
7. Lowercase keys only in workflow files.
8. No MCP server, no hooks in this version.
