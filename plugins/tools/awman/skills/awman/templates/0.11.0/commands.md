# awman v0.11.0 — Command Reference

Pinned to awman v0.11.0 (released 2026-07-13, accessed 2026-07-13).
Newer versions get their own `templates/X.Y.Z/commands.md` per the `/claude-code:skill-update` convention.

Source: https://github.com/prettysmartdev/awman (release notes + docs/, accessed 2026-07-13)

---

## What's new versus v0.10.0

- **Dynamic workflows** — `awman exec workflow --dynamic --work-item <N>` launches a leader agent that designs a custom workflow for the work item, then executes it. `--leader <agent::model>` overrides the leader; `dynamicWorkflows` config section (`agentsToModels`, `defaultLeader`, `maxConcurrentSteps`, `guidance`) constrains the plan. `--dynamic` auto-enforces `--yolo`, `--worktree`, and the `context(workflow)` overlay.
- **True parallel execution** — independent DAG steps (identical `depends_on` sets) run concurrently. Cap with `maxConcurrentAgents` config (repo or global), `AWMAN_MAX_CONCURRENT_AGENTS`, or `--max-concurrent <n>` per run. Unset = unlimited; `1` disables parallelism; `0` is rejected. TUI: `Ctrl-S` rotates focus between parallel containers.
- **Git sidebar** — `Ctrl-G` toggles a sidebar of changed files with per-file `+/-` counts (~2 s refresh); compact `+X -Y` summary in the status bar when closed.
- **`awman clean`** — removes stopped containers, dangling awman-labeled images, and completed-workflow data. `--dry-run` previews; `--yes` skips confirmation.
- **Container failure logging** — failed step output (~100 lines) saved to `~/.awman/logs/{workflow-id}-{step-name}-{container-name}.log`; teardown `on_failure` agents receive the failed command output as a readable file.
- Fixes: credentials injected via environment (not command line); workflow filenames sanitized against path traversal; OpenCode interactive prompt handling. Codex Dockerfiles updated for newer GPT models.
- No config migration required from 0.10.0; new settings are optional.

---

## `awman` (no args)

Open the TUI. Scrollback defaults to 10,000 lines (configurable via `terminal_scrollback_lines`). `Ctrl-G` toggles the git sidebar; `Ctrl-S` switches between parallel containers; `Ctrl-,` opens the config dialog (`Ctrl+N` adds nested `dynamicWorkflows` entries); `Ctrl-W` opens the Workflow Control Board.

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

Verify runtime, Dockerfiles, agent auth, and built images. `--refresh` re-audits and rebuilds the agent image. Run after switching `runtime`.

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
| `--overlay <spec>` | Add an overlay spec: `dir()`, `ssh()`, `env()`, `skill()`, `context()` |
| `--allow-docker` | Mount the Docker socket |
| `--mount-ssh` | Mount `~/.ssh` read-only |

---

## `awman exec`

```sh
awman exec prompt "<text>" [--issue <ref>] [--agent <name>] [--non-interactive] [--auto] [--yolo]
awman exec workflow <path> [--work-item <nnnn> | --issue <ref>] [--yolo] [--worktree] [--agent <name>] [--model <name>] [--max-concurrent <n>]
awman exec workflow --dynamic --work-item <N> [--leader <agent::model>] [--model <name>]
```

Both subcommands accept `--agent`, `--model`, `--non-interactive`/`-n`, `--plan`, `--auto`, `--yolo`, `--overlay`, `--allow-docker`, `--mount-ssh`. `exec workflow` adds `--worktree`, `--work-item <N>`, and `--max-concurrent <n>`.

`--issue <ref>`: for `exec workflow`, the issue is fetched and treated as if passed via `--work-item` (template variables populate from issue content). For `exec prompt`, the prompt text appears first, followed by the issue content. `--issue` and `--work-item` are mutually exclusive.

### Dynamic mode (`--dynamic`, 0.11.0)

A leader agent reads the work item, designs a `workflow.toml`, and executes it. `--yolo`, `--worktree`, and `context(workflow)` are enforced automatically — passing them explicitly is a no-op. Leader resolution order: `--leader <agent::model>` flag → `dynamicWorkflows.defaultLeader` config → `--model` applied to the project default agent → project default agent and model. An invalid generated workflow triggers a repair agent up to 3 times before erroring with the file path.

| Violation | Error |
|-----------|-------|
| `--dynamic` + workflow file path | `cannot specify a workflow file path with --dynamic...` |
| `--dynamic` without `--work-item` | `--dynamic requires --work-item` |
| `--leader` without `--dynamic` | `--leader is only valid with --dynamic` |
| `--dynamic --plan` | `--dynamic cannot be used with --plan...` |
| Malformed `--leader` | `invalid --leader value: expected agent::model...` |

---

## `awman clean` (0.11.0)

```sh
awman clean [--dry-run] [--yes]
```

| Flag | Effect |
|------|--------|
| `--dry-run` | Preview removable items without deleting; no confirmation needed |
| `--yes` / `-y` | Skip the confirmation prompt; required in non-TTY contexts |

Removes: stopped awman containers, completed repo workflow state files (`GITROOT/.awman/workflows/`), completed workflow context directories (`~/.awman/context/workflows/`), and dangling awman-labeled Docker images. Preserves in-progress workflows and active containers. Does **not** clean `~/.awman/logs/`. If Docker is unavailable, container/image cleanup is skipped with a warning and filesystem cleanup proceeds.

Exit codes: `0` success / nothing to clean / dry-run; `1` one or more deletions failed; `2` interactive input required but unavailable (non-TTY without `--yes`).

---

## `awman new`

```sh
awman new spec [--interview] [--issue <ref>]
awman new workflow [--interview] [--global] [--format <toml|yaml>]
awman new skill [--interview]
```

`new spec --issue` uses the fetched issue as input for spec generation; with `--interview`, the issue content pre-populates the interview text box.

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

`--global` writes to `~/.awman/config.json`; without it, writes to the per-repo `GITROOT/.awman/config.json`. Works even when the configured runtime is not installed. Nested `dynamicWorkflows` keys are settable via dotted paths:

```sh
awman config set dynamicWorkflows.defaultLeader claude::claude-opus-4-8
awman config set dynamicWorkflows.maxConcurrentSteps 3
awman config set dynamicWorkflows.agentsToModels.claude "claude-opus-4-8, claude-sonnet-4-6"
awman config set dynamicWorkflows.guidance.0 "Never spawn more than two agents in parallel."
awman config set maxConcurrentAgents 3
awman config set --global maxConcurrentAgents 2
```

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

Add `--dangerously-skip-tls` for plain HTTP, `--dangerously-skip-auth` to disable auth for this process lifetime only (the `api_key.hash` file is untouched; the next normal start re-enables auth). Default port configurable via the `api.port` global key. See `references/api.md` for the REST surface.

---

## `awman remote`

```sh
awman remote run "<cmd>" [--session <ID>] [--follow] [--remote-addr <URL>]
awman remote session start [dir] [--remote-addr <URL>] [--api-key <KEY>]
awman remote session kill <id> [--remote-addr <URL>] [--api-key <KEY>]
```

Reads `remote.defaultAddr` / `remote.defaultAPIKey` from `~/.awman/config.json`; `AWMAN_REMOTE_ADDR`, `AWMAN_API_KEY`, and `AWMAN_REMOTE_SESSION` override at runtime. `--session` is required in CLI mode.

---

## Runtimes (v0.11.0)

| `runtime` value | Platforms | Requirements |
|-----------------|-----------|--------------|
| `docker` (default) | Linux, macOS, Windows | Docker daemon |
| `apple-containers` | macOS 26+ | native `container` CLI |
| `docker-sbx-experimental` | macOS arm64, Windows x86_64 | `sbx` CLI + Docker account (`sbx login`) |

`runtime` is global-only. Switch with `awman config set --global runtime <value>`, then run `awman ready`. Each runtime keeps separate state; switching does not delete the others' data. sbx requires Apple Silicon on macOS; Linux x86_64 is blocked by a virtiofs bug and returns an error if configured.

---

## Agents Supported in v0.11.0

`claude` | `codex` | `opencode` | `maki` | `gemini` (deprecated) | `antigravity` | `copilot` | `crush` | `cline`

Each has a corresponding `Dockerfile.<agent>` in `.awman/`. The project base image path is configurable via the per-repo `dockerfile` key (default `Dockerfile.dev`). Codex Dockerfiles were updated in 0.11.0 for newer GPT models.

---

## Workflow File Formats

Two formats — **TOML and YAML**. Fields are lowercase only. Main steps: `name`, `prompt` (required), `depends_on`, `agent`, `model`, `overlays` (optional).

### Parallel execution (0.11.0)

Steps with identical `depends_on` sets form a parallel group and launch concurrently, in workflow file order, up to the `maxConcurrentAgents` cap. A failed step without `abort_on_failure` lets siblings continue; `abort_on_failure = true` kills all active peers in the group. Stuck detection (30 s) and yolo countdowns (60 s) track per container.

### Main steps (TOML)

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

### Setup phase steps

| Type | Required | Optional |
|------|----------|----------|
| `clone_repo` | `url` | `branch`, `into` |
| `checkout_create_branch` | `branch` | `base` |
| `pull_branch` | — | `remote`, `branch` |
| `run_shell` | `command` | `env` |
| `run_script` | `path` | `env` |
| `poll_ci` | — | `interval_secs` (default 30), `max_retries` (default 10) |

### Teardown phase steps

| Type | Required | Optional |
|------|----------|----------|
| `run_shell` | `command` | `env` |
| `run_script` | `path` | `env` |
| `commit_changes` | `message` | `add_all` |
| `push_branch` | — | `remote`, `branch` |
| `create_pull_request` | — | `title`, `body`, `base` |
| `poll_ci` | — | `interval_secs`, `max_retries` |

Top-level `teardown_on_failure = true` runs teardown even when main steps fail (default `false`). Failed teardown steps log and continue (best-effort cleanup).

### on_failure remediation

```toml
[[setup]]
type = "run_shell"
command = "npm test"
[setup.on_failure]
prompt = "Tests failed. Fix issues and verify."
agent = "claude"              # optional; inherits if omitted
model = "claude-opus-4-6"     # optional; inherits if omitted
max_attempts = 2              # required; must be >= 1
```

On step failure, a remediation agent runs the prompt, then the step retries — up to `max_attempts` cycles. New in 0.11.0: teardown `on_failure` agents receive the failed command's stdout/stderr as a readable file (see failure logging below); setup `on_failure` agents get no automatic capture.

### Failure logging (0.11.0)

Failed step container output (~100 lines, combined stdout/stderr) is saved to `~/.awman/logs/{workflow-id}-{step-name}-{container-name}.log`. The directory is created on demand and never auto-cleaned (`awman clean` does not touch it).

### Template Variables

| Variable | Resolves to |
|----------|-------------|
| `{{work_item_number}}` | Zero-padded 4-digit number (e.g. `0027`) |
| `{{work_item}}` | The bare number |
| `{{work_item_content}}` | Full text of the work item (or fetched GitHub issue via `--issue`) |
| `{{work_item_section:[Name]}}` | Named section within the work item (case-insensitive) |

---

## Overlays (v0.11.0 syntax)

`overlays` is a string array (config, `AWMAN_OVERLAYS`, `--overlay`, or workflow/step `overlays = [...]`):

| Spec | Effect |
|------|--------|
| `dir(HOST:CONTAINER[:ro\|rw])` | Mount a host directory (default read-only) |
| `ssh()` | Mount `~/.ssh` read-only |
| `env(VAR)` | Forward one env var (one call per var; unset vars skip silently) |
| `skill(*)` / `skill(NAME)` | Mount all or one skill from `~/.awman/skills/` |
| `context(global\|repo\|workflow[:ro])` | Durable context dir + system-prompt injection (default `rw`) |

Context locations: `~/.awman/context/global/`, `~/.awman/context/repo/{owner}/{repo}/`, `~/.awman/context/workflow/` (per invocation). All sources merge additively; on host-path conflicts higher priority wins, but `:ro` always overrides `:rw`. Setup/teardown steps support `dir()`, `ssh()`, `env()` only — not `skill()`.

---

## Configuration Keys (v0.11.0)

| Key | Type | Default | Scope | Settable via CLI |
|-----|------|---------|-------|------------------|
| `default_agent` | string | unset | Global only | Yes |
| `runtime` | string | `"docker"` | Global only | Yes |
| `workers` | integer | `2` | Global only | No (edit file) |
| `baseImage` | string | unset | Global / repo | No (edit file) |
| `api.workDirs` | array | `[]` | Global only | Yes |
| `api.alwaysNonInteractive` | boolean | `false` | Global only | No (edit file) |
| `api.port` | integer | `9876` | Global only | Yes |
| `remote.defaultAddr` | string | unset | Both | Yes |
| `remote.defaultAPIKey` | string | unset | Both | Yes |
| `remote.savedDirs` | array | `[]` | Both | No (edit file) |
| `agent` | string | unset | Both | Yes |
| `auto_agent_auth_accepted` | bool | unset | Global only | No (managed) |
| `terminal_scrollback_lines` | integer | `10000` | Both | Yes |
| `yoloDisallowedTools` | array | `[]` | Both | Yes |
| `overlays` | string array | `[]` | Both (additive) | Yes |
| `agentStuckTimeout` | integer | `30` (seconds) | Both | Yes |
| `maxConcurrentAgents` | integer ≥1 | unset (unlimited) | Both | Yes |
| `dynamicWorkflows.agentsToModels` | map | `{}` (Dockerfile discovery) | Both | Yes (dotted path) |
| `dynamicWorkflows.defaultLeader` | `agent::model` string | unset | Both | Yes |
| `dynamicWorkflows.maxConcurrentSteps` | integer ≥1 | unset | Both | Yes |
| `dynamicWorkflows.guidance` | string array (max 50 × 1,000 chars) | `[]` | Both | Yes (indexed path) |
| `workItems.dir` | string | `aspec/work-items` | Repo only | Yes |
| `workItems.template` | string | `<workItems.dir>/0000-template.md` | Repo only | Yes |
| `dockerfile` | string | `Dockerfile.dev` | Repo only | No (edit file) |

Overlays merge additively across sources; other list fields replace (repo overrides global). `maxConcurrentAgents` precedence: `--max-concurrent` flag → `AWMAN_MAX_CONCURRENT_AGENTS` env → repo config → global config → unlimited.

---

## REST API (v0.11.0)

Default port `9876` (configurable via `api.port`), HTTPS self-signed by default. Auth: `Authorization: Bearer <api-key>` (or `--dangerously-skip-auth` at start).

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
| `GET` | `/v1/commands/:id` | Command status (`queued`/`running`/`done`/`error`/`cancelled`) |
| `GET` | `/v1/commands/:id/logs` | Captured output |
| `GET` | `/v1/commands/:id/logs/stream` | Live output (SSE) |
| `GET` | `/v1/workflows/:id` | Workflow state for a command |

Commands queue FIFO per session — submission never blocks (returns `command_id`, HTTP 202). A workdir outside the allowlist → HTTP 403; a closing session → HTTP 409; missing/bad key → HTTP 401.

---

## Known Sharp Edges in v0.11.0

1. Not a tmux wrapper — ships its own TUI.
2. Single per-repo config `GITROOT/.awman/config.json` (same filename as the global `~/.awman/config.json`). Use `awman config show`.
3. Worktrees are never auto-deleted.
4. API server is HTTPS self-signed by default — local curl needs `--dangerously-skip-tls` or cert trust.
5. `runtime` is global-only — no per-repo runtime selection.
6. Markdown workflows removed (since 0.9.1) — TOML/YAML only.
7. Lowercase keys only in workflow files.
8. `--issue` and `--work-item` are mutually exclusive; bare `--issue <N>` requires a GitHub `origin` remote.
9. `docker-sbx-experimental` does not honor `dir()`, skills, or context overlays; networking is proxy-only (raw TCP/UDP blocked); sandboxes persist between sessions; port mappings are lost when a sandbox stops.
10. Context overlays default to `rw` — use `context(SCOPE:ro)` to prevent agents modifying accumulated knowledge.
11. `--dynamic` force-enables `--yolo`, `--worktree`, and `context(workflow)` — there is no supervised dynamic mode.
12. `maxConcurrentAgents` unset means **unlimited** parallelism; `1` disables it; `0` is rejected.
13. `~/.awman/logs/` grows unbounded — `awman clean` does not remove failure logs.
14. Setup-step `on_failure` agents get no automatic failure-output capture (teardown steps do).
