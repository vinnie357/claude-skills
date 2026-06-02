# awman v0.9.1 — Command Reference

Pinned to awman v0.9.1 (released 2026-05-28, accessed 2026-06-02).
Newer versions get their own `templates/X.Y.Z/commands.md` per the `/claude-code:skill-update` convention.

Source: https://github.com/prettysmartdev/awman (README + docs/, accessed 2026-06-02)

---

## What's in v0.9.1

awman is the renamed successor to **amux**. Versus the last amux snapshot (0.8.0):

- Binary, repo, and install script renamed to `awman` / `prettysmartdev/awman` / `awman.sh`.
- Per-repo config moved from `aspec/.amux.json` to `GITROOT/.awman/config.json`; config migrates automatically.
- Environment variables `AMUX_*` → `AWMAN_*`.
- `headless.*` config keys → `api.*`; the server command `amux headless …` → `awman api …` (HTTPS self-signed by default).
- Markdown workflow files (`.md`) are no longer supported — TOML and YAML only.
- New `chat`/`exec` flags: `--model`, `--overlay`, `--allow-docker`, `--mount-ssh`, `--non-interactive`/`-n`.
- New agent option: `antigravity`.

---

## `awman` (no args)

Open the TUI. Scrollback defaults to 10,000 lines (configurable via `terminal_scrollback_lines`).

---

## `awman init`

```sh
awman init [--agent <name>] [--aspec]
```

Interactive project setup. Creates `GITROOT/.awman/config.json` (commit this) and per-agent Dockerfiles in `.awman/`. `--aspec` also downloads spec/workflow templates.

---

## `awman ready`

```sh
awman ready [--refresh]
```

Verify runtime, Dockerfiles, agent auth, and built images. `--refresh` re-audits and rebuilds the agent image.

---

## `awman chat`

```sh
awman chat [--agent <name>] [--model <name>] [--plan] [--auto] [--yolo] [--worktree] [--non-interactive] [--overlay <spec>] [--allow-docker] [--mount-ssh]
```

| Flag | Effect |
|------|--------|
| `--agent <name>` | Override the default agent |
| `--model <name>` | Override the model for this session |
| `--plan` | Read-only analysis/planning mode |
| `--auto` | Auto-approve file edits; prompt for shell commands |
| `--yolo` | Fully autonomous (no prompts) |
| `--worktree` | Run in a dedicated Git worktree |
| `--non-interactive` / `-n` | Print/batch (headless) mode |
| `--overlay <spec>` | Mount extra directories or skills |
| `--allow-docker` | Mount the Docker socket |
| `--mount-ssh` | Mount `~/.ssh` read-only |

---

## `awman exec`

```sh
awman exec prompt "<text>" [--agent <name>] [--non-interactive] [--auto] [--yolo]
awman exec workflow <path> [--work-item <nnnn>] [--yolo] [--worktree] [--agent <name>]
```

Both subcommands accept `--agent`, `--model`, `--non-interactive`/`-n`, `--plan`, `--auto`, `--yolo`, `--overlay`, `--allow-docker`, `--mount-ssh`. `exec workflow` adds `--worktree` and `--work-item <N>`.

---

## `awman new`

```sh
awman new spec [--interview]
awman new workflow [--interview] [--global] [--format <toml|yaml>]
awman new skill [--interview]
```

---

## `awman specs`

```sh
awman specs amend <nnnn>   # Update work item <nnnn>
```

---

## `awman status`

```sh
awman status [--watch]
```

---

## `awman config`

```sh
awman config show                              # Merged effective config
awman config get <field>                       # One field
awman config set [--global] <field> <value>    # Write a key
```

`--global` writes to `~/.awman/config.json`; without it, writes to the per-repo `GITROOT/.awman/config.json`.

---

## `awman api`

Manage the REST API server (default port 9876, HTTPS self-signed by default).

```sh
awman api start --port 9876 --workdirs /repo          # foreground
awman api start --background --port 9876 --workdirs /repo
awman api start --refresh-key --port 9876 --workdirs /repo
awman api status
awman api logs                                        # background server only
awman api kill
```

Add `--dangerously-skip-tls` for plain HTTP. See `references/api.md` for the REST surface.

---

## `awman remote`

```sh
awman remote run "<cmd>" [--session <ID>] [--follow] [--remote-addr <URL>]
awman remote session start [dir] [--remote-addr <URL>] [--api-key <KEY>]
awman remote session kill <id> [--remote-addr <URL>] [--api-key <KEY>]
```

Reads `remote.defaultAddr` / `remote.defaultAPIKey` from `~/.awman/config.json`; `AWMAN_REMOTE_ADDR`, `AWMAN_API_KEY`, and `AWMAN_REMOTE_SESSION` override at runtime. `--session` is required in CLI mode.

---

## Agents Supported in v0.9.1

`claude` | `codex` | `opencode` | `maki` | `gemini` | `antigravity` | `copilot` | `crush` | `cline`

Each has a corresponding `Dockerfile.<agent>` in `.awman/`. Templates live at https://github.com/prettysmartdev/awman/tree/main/templates.

---

## Workflow File Formats

Two formats — **TOML and YAML** (Markdown dropped in 0.9.1). Fields are lowercase only: `name`, `prompt` (required), `depends_on`, `agent`, `model`.

### TOML (`.toml`)

```toml
title = "Implement Feature Workflow"

[[step]]
name = "plan"
prompt = "Read the work item and produce an implementation plan.\n\n{{work_item_content}}"

[[step]]
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
      Read the work item and produce an implementation plan.
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
| `{{work_item_number}}` | Zero-padded 4-digit number (e.g. `0027`) |
| `{{work_item}}` | The bare number |
| `{{work_item_content}}` | Full text of the work item file |
| `{{work_item_section:[Name]}}` | Named section within the work item (case-insensitive) |

---

## Configuration Keys (v0.9.1)

| Key | Type | Default | Scope |
|-----|------|---------|-------|
| `default_agent` | string | `"claude"` | Global only |
| `runtime` | string | `"docker"` | Global only |
| `api.workDirs` | array | `[]` | Global only |
| `api.alwaysNonInteractive` | boolean | `false` | Global only |
| `api.workers` | integer | `2` | Global only |
| `remote.defaultAddr` | string | unset | Global only |
| `remote.defaultAPIKey` | string | unset | Global only |
| `remote.savedDirs` | array | `[]` | Global only |
| `terminal_scrollback_lines` | integer | `10000` | Both |
| `yoloDisallowedTools` | array | `[]` | Both |
| `envPassthrough` | array | `[]` | Both |
| `overlays.skills` | boolean | `false` | Both (additive) |
| `overlays.directories` | array | `[]` | Both (additive) |
| `agent` | string | (default_agent) | Per-repo only |
| `base_image` | string | from global / `make build` | Per-repo only |
| `workItems.dir` | string | unset | Per-repo only |
| `workItems.template` | string | unset | Per-repo only |

---

## REST API (v0.9.1)

Default port `9876`, HTTPS self-signed by default. Auth: `Authorization: Bearer <api-key>`.

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/status` | Server health (no auth) |
| `GET` | `/v1/workdirs` | List allowlisted directories |
| `POST` | `/v1/sessions` | Create session (`{"workdir": "..."}`) |
| `GET` | `/v1/sessions` | List sessions (`?status=active`) |
| `GET` | `/v1/sessions/:id` | Session details |
| `GET` | `/v1/sessions/:id/queue` | Queue status |
| `DELETE` | `/v1/sessions/:id` | Close session |
| `POST` | `/v1/commands` | Submit subcommand (`x-awman-session: <id>` header) |
| `GET` | `/v1/commands/:id` | Command status |
| `GET` | `/v1/commands/:id/logs` | Captured output |
| `GET` | `/v1/commands/:id/logs/stream` | Live output (SSE) |
| `GET` | `/v1/workflows/:id` | Workflow state for a command |

Commands queue FIFO per session — submission never blocks (returns `command_id`). A workdir outside the allowlist → HTTP 403; a closing session → HTTP 409; missing/bad key → HTTP 401.

---

## Known Sharp Edges in v0.9.1

1. Not a tmux wrapper — ships its own TUI.
2. Single per-repo config `GITROOT/.awman/config.json` (same filename as the global `~/.awman/config.json`). Use `awman config show`.
3. Worktrees are never auto-deleted.
4. API server is HTTPS self-signed by default — local curl needs `--dangerously-skip-tls` or cert trust.
5. `runtime` is global-only — no per-repo docker vs Apple Containers selection.
6. Markdown workflows removed — TOML/YAML only.
7. Lowercase keys only in workflow files.
