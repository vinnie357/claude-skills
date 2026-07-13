# awman Command Reference

Exhaustive reference for all awman CLI subcommands, flags, and options as of v0.11.0.

Source: https://github.com/prettysmartdev/awman (README + docs/, accessed 2026-07-13).
Run `awman <subcommand> --help` to verify flags match the installed binary. Pre-1.0 releases drift between minors.

---

## Global flags

| Flag | Description |
|------|-------------|
| `--version` | Print the awman version and exit |
| `--help` | Print help for the command or subcommand |

Run `awman` with no arguments to open the TUI.

---

## `awman init`

Initialize a project for awman. Runs an interactive setup and creates `GITROOT/.awman/config.json` plus per-agent Dockerfiles in `.awman/`.

```
awman init [FLAGS]
```

| Flag | Type | Description |
|------|------|-------------|
| `--agent <name>` | string | Set the default agent for this repo (e.g. `claude`, `codex`) |
| `--aspec` | bool | Also download specification/workflow templates during setup |

**What it writes:**
- `GITROOT/.awman/config.json` — per-repo config file (commit to source control)
- `.awman/Dockerfile.claude`, `.awman/Dockerfile.codex`, … — per-agent Dockerfiles seeded from upstream templates

**After init**, run `awman ready --refresh` to build the agent Docker image before starting any session.

---

## `awman ready`

Verify that the environment is correctly configured (runtime, Dockerfiles, agent auth) and that the agent container image is built.

```
awman ready [FLAGS]
```

| Flag | Description |
|------|-------------|
| `--refresh` | Re-run the Dockerfile audit and rebuild the agent image |

---

## `awman config`

Inspect and modify awman configuration. Reads from `$HOME/.awman/config.json` (global) and `$GITROOT/.awman/config.json` (per-repo); per-repo wins on conflicts. As of 0.10.0, `awman config` works even when the configured runtime is not installed.

### `awman config show`

Print the merged effective configuration — all keys, resolved in precedence order. Run this first when debugging unexpected behavior.

```
awman config show
```

### `awman config get <field>`

Show the current value of a single config key.

```sh
awman config get default_agent
awman config get runtime
awman config get api.workDirs
```

### `awman config set [--global] <field> <value>`

Set a config key. Without `--global`, writes to the per-repo `.awman/config.json`; with `--global`, writes to `$HOME/.awman/config.json`.

```sh
# Set the repo default agent
awman config set agent codex

# Set the global default agent
awman config set --global default_agent claude

# Set the runtime globally (docker | apple-containers | docker-sbx-experimental)
awman config set --global runtime docker

# Add allowlisted API workdirs (comma-separated)
awman config set --global api.workDirs "/path1,/path2"

# Nested dynamicWorkflows keys use dotted paths (0.11.0)
awman config set dynamicWorkflows.defaultLeader claude::claude-opus-4-8
awman config set dynamicWorkflows.maxConcurrentSteps 3
awman config set dynamicWorkflows.agentsToModels.claude "claude-opus-4-8, claude-sonnet-4-6"
awman config set dynamicWorkflows.guidance.0 "Never spawn more than two agents in parallel."

# Cap parallel workflow containers (0.11.0)
awman config set maxConcurrentAgents 3            # this repo
awman config set --global maxConcurrentAgents 2   # all projects
```

**Do not hand-edit the JSON files directly.** Use `awman config set` and verify with `awman config show`.

---

## `awman chat`

Start an interactive agent session in the TUI.

```
awman chat [FLAGS]
```

| Flag | Type | Description |
|------|------|-------------|
| `--agent <name>` | string | Agent to use (`claude`, `codex`, `opencode`, `maki`, `gemini`, `antigravity`, `copilot`, `crush`, `cline`) |
| `--model <name>` | string | Override the model for this session |
| `--plan` | bool | Read-only analysis/planning mode |
| `--auto` | bool | Auto-approve file edits; still prompts for shell commands |
| `--yolo` | bool | Fully autonomous mode (no permission prompts) |
| `--worktree` | bool | Run the session in a dedicated Git worktree |
| `--non-interactive` / `-n` | bool | Run in print/batch (headless) mode |
| `--overlay <spec>` | string | Mount additional directories or skills |
| `--allow-docker` | bool | Mount the Docker socket into the container |
| `--mount-ssh` | bool | Mount `~/.ssh` read-only into the container |

**Examples:**

```sh
# Interactive session with the repo default agent
awman chat

# Use codex in auto-approve mode
awman chat --agent codex --auto

# Fully autonomous in a worktree (worktree never auto-deleted)
awman chat --yolo --worktree
```

---

## `awman exec`

Run a one-shot command without entering the TUI. Both subcommands accept `--agent`, `--model`, `--non-interactive`/`-n`, `--plan`, `--auto`, `--yolo`, `--overlay`, `--allow-docker`, `--mount-ssh`.

### `awman exec prompt`

Submit a single prompt to an agent and return when complete.

```sh
awman exec prompt "Explain the build script"
awman exec prompt "Add type hints to lib/utils.py" --agent codex --auto
awman exec prompt "Fix this bug" --issue 84      # prompt text first, then issue content
```

### `awman exec workflow`

Execute a multi-step workflow file. Adds workflow-only flags `--worktree`, `--work-item <N>`, and `--max-concurrent <n>` (0.11.0).

```sh
awman exec workflow ./workflows/refactor.toml
awman exec workflow ./workflows/implement.toml --work-item 0027 --yolo --worktree
awman exec workflow ./workflows/implement.toml --issue prettysmartdev/awman#84
awman exec workflow ./workflows/implement.toml --work-item 0027 --max-concurrent 4
```

`--work-item <nnnn>` injects template variables (`{{work_item_number}}`, `{{work_item_content}}`, etc.) into step prompts. `--issue <ref>` (0.10.0) fetches a GitHub issue and populates the same variables — mutually exclusive with `--work-item`. Reference forms: bare number (requires GitHub `origin` remote), `owner/repo#N`, or full URL; auth via `gh` CLI, then `GITHUB_TOKEN`, then unauthenticated (public repos, 60 req/hr). The worktree is never auto-deleted — a merge/discard/keep dialog appears at completion or abort.

`--max-concurrent <n>` (0.11.0) caps simultaneous step containers for this run, overriding `AWMAN_MAX_CONCURRENT_AGENTS` and the `maxConcurrentAgents` config key. See `references/workflows.md` for parallel-group semantics.

### `awman exec workflow --dynamic` (0.11.0)

A leader agent reads the work item, designs a `workflow.toml`, and executes it.

```sh
awman exec workflow --dynamic --work-item 27
awman exec workflow --dynamic --work-item 27 --leader claude::claude-opus-4-8
awman exec workflow --dynamic --work-item 27 --model claude-sonnet-4-6   # default model for generated steps
```

| Flag | Description |
|------|-------------|
| `--dynamic` | Enable dynamic mode; requires `--work-item`, rejects a workflow file path and `--plan` |
| `--leader <agent::model>` | Override the leader agent and model (only valid with `--dynamic`) |
| `--model <name>` | Default model for generated workflow steps |

`--yolo`, `--worktree`, and the `context(workflow)` overlay are enforced automatically — passing them explicitly has no effect. Leader resolution order: `--leader` flag → `dynamicWorkflows.defaultLeader` config → `--model` on the project default agent → project default agent and model. If the generated `workflow.toml` is invalid, missing, or references unknown agents, a repair agent runs up to 3 times before the run errors with the file path.

| Violation | Error |
|-----------|-------|
| `--dynamic` + workflow file path | `cannot specify a workflow file path with --dynamic...` |
| `--dynamic` without `--work-item` | `--dynamic requires --work-item` |
| `--leader` without `--dynamic` | `--leader is only valid with --dynamic` |
| `--dynamic --plan` | `--dynamic cannot be used with --plan...` |
| Malformed `--leader` | `invalid --leader value: expected agent::model...` |

---

## `awman clean` (0.11.0)

Remove leftover awman resources.

```sh
awman clean --dry-run   # preview what would be removed
awman clean             # interactive confirmation (y/N)
awman clean --yes       # no prompt; required in non-TTY contexts
```

| Flag | Description |
|------|-------------|
| `--dry-run` | List removable items without deleting; no confirmation needed |
| `--yes` / `-y` | Skip the confirmation prompt |

**Removes:** stopped awman containers; completed workflow state files in `GITROOT/.awman/workflows/`; completed workflow context directories under `~/.awman/context/workflows/`; dangling awman-labeled Docker images.

**Preserves:** in-progress workflows, active containers and images, and `~/.awman/logs/` (failure logs are never auto-cleaned).

**Exit codes:** `0` success / nothing to clean / dry-run; `1` one or more deletions failed; `2` interactive input required but unavailable (non-TTY without `--yes`). If Docker is unavailable, container/image cleanup is skipped with a warning and filesystem cleanup proceeds. In the TUI, a confirmation modal replaces the text prompt.

---

## `awman new`

Scaffold new project assets.

```sh
awman new spec [--interview] [--issue <ref>]  # Create a numbered work-item file
awman new workflow [--interview] [--global] [--format yaml]   # Scaffold a workflow file
awman new skill [--interview]                 # Create a custom skill for the skills overlay
```

| Flag | Description |
|------|-------------|
| `--interview` | Guided interview mode; awman prompts for structured fields |
| `--issue <ref>` | (`new spec`, 0.10.0) Use a fetched GitHub issue as spec input; with `--interview`, pre-populates the interview text box |
| `--global` | Write to the personal (global) library instead of the repo |
| `--format <toml\|yaml>` | Choose the output format for a new workflow |

Work items are zero-padded four-digit files (e.g. `0027`). The template comes from `workItems.template` in the per-repo config.

---

## `awman specs`

Manage work items.

```sh
awman specs amend <nnnn>   # Open the specified work item for editing
```

---

## `awman status`

Show a dashboard of active agent sessions and running workflows.

```sh
awman status
awman status --watch   # Continuously refresh
```

---

## `awman api`

Manage the awman REST API server (default port 9876). The server speaks **HTTPS with a self-signed certificate by default**; use `--dangerously-skip-tls` for plain HTTP.

```sh
awman api start --port 9876 --workdirs /path/to/repo        # Foreground
awman api start --background --port 9876 --workdirs /repo    # Background
awman api start --refresh-key --port 9876 --workdirs /repo   # Regenerate the API key
awman api status                                             # Check server state
awman api logs                                               # Tail logs (background server only)
awman api kill                                               # Graceful shutdown
```

| Flag | Description |
|------|-------------|
| `--port <n>` | Port to listen on (default `9876`) |
| `--workdirs <paths>` | Allowlisted directories; merged with `api.workDirs` config |
| `--background` | Run the server detached |
| `--refresh-key` | Generate a new API key (prints plaintext once) |
| `--dangerously-skip-tls` | Serve plain HTTP instead of self-signed HTTPS |
| `--dangerously-skip-auth` | Disable auth for this process lifetime only; `api_key.hash` is untouched and the next normal start re-enables auth |

See `references/api.md` for the full REST endpoint table and auth model.

---

## `awman remote`

CLI client for a running awman api server. Prefer `awman remote` over raw curl per the operator tooling-first convention — it carries auth and sets the session header.

### `awman remote run`

Submit an awman subcommand string to the remote server.

```
awman remote run "<command>" [--session <ID>] [--follow] [--remote-addr <URL>]
```

| Flag | Description |
|------|-------------|
| `--session <ID>` | Target session (required in CLI mode; or set `AWMAN_REMOTE_SESSION`) |
| `--follow` / `-f` | Stream command logs to stdout until completion |
| `--remote-addr <URL>` | Override `remote.defaultAddr` |

### `awman remote session start [dir]`

Create a new session on the remote server in the given working directory (must be in the server's allowlist).

```
awman remote session start /home/user/my-project [--remote-addr <URL>] [--api-key <KEY>]
```

### `awman remote session kill <id>`

Close a session on the remote server.

```
awman remote session kill <session-id> [--remote-addr <URL>] [--api-key <KEY>]
```

**Worked example:**

```sh
# Configure once
awman config set --global remote.defaultAddr https://build-server.example.com:9876
awman config set --global remote.defaultAPIKey <your-api-key>

# Create, dispatch, stream, kill
SESSION=$(awman remote session start /home/user/my-project | grep 'Session started:' | awk '{print $NF}')
awman remote run "exec workflow path/to/workflow.toml" --session "$SESSION" --follow
awman remote session kill "$SESSION"
```

---

## Common error modes

| Error | Likely cause |
|-------|-------------|
| `runtime not found` | Configured runtime not running; check `docker info`, `container system status`, or `sbx` login state |
| sbx error on Linux / Intel Mac | `docker-sbx-experimental` requires macOS arm64 or Windows x86_64; Linux x86_64 is blocked by a virtiofs bug |
| Overlay missing inside sandbox | `docker-sbx-experimental` does not honor `dir()`, skill, or context overlays |
| `HTTP 403 on POST /v1/sessions` | `workdir` not in `api.workDirs` / `--workdirs`; add it and retry |
| `HTTP 401` | Missing or invalid API key on an authenticated endpoint |
| `HTTP 409 session is closing` | Session is shutting down; create a new session |
| `parse error: uppercase key` | Workflow file uses uppercase field names; lowercase all keys |
| `unsupported workflow format` | Markdown (`.md`) workflow; convert to TOML or YAML |
| `worktree already exists` | Previous `--worktree` run left a tree; resolve with `git worktree list` / `git worktree remove` |
| `no agent Dockerfile found` | Run `awman ready --refresh` after `awman init` or after editing `.awman/Dockerfile.*` |
| `--dynamic requires --work-item` | Dynamic mode needs a work item; add `--work-item <N>` |
| `invalid --leader value` | `--leader` expects `agent::model` (e.g. `claude::claude-opus-4-8`) |
| Value `0` rejected for `maxConcurrentAgents` | Use `1` to disable parallelism or unset for unlimited |

---

Back to skill: [SKILL.md](../SKILL.md)
