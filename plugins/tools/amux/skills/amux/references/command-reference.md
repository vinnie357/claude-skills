# amux Command Reference

Exhaustive reference for all amux CLI subcommands, flags, and options as of v0.8.0.

Source: https://github.com/prettysmartdev/amux — accessed 2026-05-16.
Run `amux <subcommand> --help` to verify flags match the installed binary. Pre-1.0 releases drift between minors.

---

## Global flags

| Flag | Description |
|------|-------------|
| `--version` | Print the amux version and exit |
| `--help` | Print help for the command or subcommand |

Run `amux` with no arguments to open the TUI.

---

## `amux init`

Initialize a project for amux. Creates `aspec/.amux.json` in the Git repository root and populates `.amux/` with per-agent Dockerfiles.

```
amux init [FLAGS]
```

| Flag | Type | Description |
|------|------|-------------|
| `--agent <name>` | string | Set the default agent for this repo (e.g. `claude`, `codex`) |

**What it writes:**
- `aspec/.amux.json` — per-repo config file (commit to source control)
- `.amux/Dockerfile.claude`, `.amux/Dockerfile.codex`, … — per-agent Dockerfiles seeded from upstream templates
- `.amux/config.json` — local-only overrides (do not commit; see config.md for the distinction)

**Examples:**

```sh
# Initialize with the default agent (claude)
amux init

# Initialize and set codex as the repo default
amux init --agent codex
```

**After init**, run `amux ready --refresh` to build the agent Docker image before starting any session.

---

## `amux ready`

Verify that the environment is correctly configured and that the agent container image is built.

```
amux ready [FLAGS]
```

| Flag | Description |
|------|-------------|
| `--refresh` | Force rebuild of the agent Docker image |

**Examples:**

```sh
# Check environment without rebuilding
amux ready

# Check AND rebuild the agent image (run after amux init or after editing a Dockerfile)
amux ready --refresh
```

---

## `amux config`

Inspect and modify amux configuration. Reads from both `$HOME/.amux/config.json` (global) and `$GITROOT/aspec/.amux.json` (per-repo); per-repo wins on conflicts.

### `amux config show`

Print the merged effective configuration — all keys, resolved in precedence order.

```
amux config show
```

No flags. Run this first when debugging unexpected behavior.

**Example:**

```sh
amux config show
```

### `amux config get`

Show the current value of a single config key, indicating which scope (global or per-repo) provided it.

```
amux config get <field>
```

**Examples:**

```sh
amux config get default_agent
amux config get runtime
amux config get workItems.dir
```

### `amux config set`

Set a config key. Without `--global`, writes to the per-repo `aspec/.amux.json`; with `--global`, writes to `$HOME/.amux/config.json`.

```
amux config set [FLAGS] <field> <value>
```

| Flag | Description |
|------|-------------|
| `--global` | Write to the global config instead of the per-repo config |

**Examples:**

```sh
# Set the repo default agent
amux config set agent codex

# Set the global default agent
amux config set --global default_agent claude

# Set the runtime globally (docker or container)
amux config set --global runtime docker

# Set the scrollback buffer globally
amux config set --global terminal_scrollback_lines 20000
```

**Do not hand-edit the JSON files directly.** Use `amux config set` to ensure merge logic is applied correctly; use `amux config show` to verify effective values.

---

## `amux chat`

Start an interactive agent session in the TUI.

```
amux chat [FLAGS]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--agent <name>` | string | repo or global default | Agent to use (`claude`, `codex`, `opencode`, `maki`, `gemini`, `copilot`, `crush`, `cline`) |
| `--plan` | bool | false | Start in plan mode (agent reads the spec before taking action) |
| `--auto` | bool | false | Auto-approve file edits; still prompts for other tool uses |
| `--yolo` | bool | false | Disable all permission prompts; implies a Git worktree for the session |
| `--worktree` | bool | false | Run the session in a dedicated Git worktree (opt-in; implied by `--yolo`) |

**Examples:**

```sh
# Interactive session with the repo default agent
amux chat

# Use codex in auto-approve mode
amux chat --agent codex --auto

# Full autonomous mode in a worktree (worktree never auto-deleted)
amux chat --yolo
```

**TUI keybindings** (amux's own — not tmux):

| Key | Action |
|-----|--------|
| `Ctrl+T` | Open new session tab |
| `Ctrl+A` | Switch between tabs |
| `Ctrl+D` | Detach from current session |
| `Ctrl+Y` | Copy selection to clipboard |

---

## `amux exec`

Run a one-shot command without entering the TUI.

### `amux exec prompt`

Submit a single prompt to an agent and return when complete.

```
amux exec prompt "<prompt>" [FLAGS]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--agent <name>` | string | repo/global default | Agent to use |
| `--auto` | bool | false | Auto-approve file edits |
| `--yolo` | bool | false | Disable all permission prompts; implies worktree |

**Examples:**

```sh
# One-off prompt with the default agent
amux exec prompt "Explain the build script"

# Non-interactive auto-approve run with a specific agent
amux exec prompt "Add type hints to lib/utils.py" --agent codex --auto
```

### `amux exec workflow`

Execute a multi-step workflow file.

```
amux exec workflow <path> [FLAGS]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--work-item <nnnn>` | string | none | Work item number to inject into template vars (zero-padded) |
| `--yolo` | bool | false | Disable permission prompts; auto-advances steps after 60-second countdown; implies worktree |
| `--worktree` | bool | false | Run all steps in a dedicated Git worktree |

**Examples:**

```sh
# Execute a workflow without a work item
amux exec workflow ./workflows/refactor.md

# Execute with a work item bound (populates {{work_item_number}} and {{work_item_content}})
amux exec workflow ./workflows/plan-implement-review.md --work-item 0027 --yolo
```

**Note:** `--yolo` implies `--worktree` for `exec workflow`. The worktree is never auto-deleted — a merge/discard/keep dialog appears at completion or abort.

---

## `amux new`

Scaffold new project assets interactively.

### `amux new spec`

Create a numbered work-item file in `workItems.dir`.

```
amux new spec [FLAGS]
```

| Flag | Description |
|------|-------------|
| `--interview` | Guided interview mode; amux prompts for structured fields |

Work items are zero-padded four-digit files (e.g. `0027`). The template comes from `workItems.template` in `aspec/.amux.json`.

### `amux new workflow`

Scaffold a new workflow file.

```
amux new workflow [FLAGS]
```

| Flag | Description |
|------|-------------|
| `--interview` | Guided interview to generate step structure |

### `amux new skill`

Create a custom skill that can be mounted into agent containers via the `overlays.skills` config key.

```
amux new skill [FLAGS]
```

| Flag | Description |
|------|-------------|
| `--interview` | Guided interview to define skill parameters |

---

## `amux specs`

Manage work items.

### `amux specs amend <nnnn>`

Open the specified work item for editing.

```
amux specs amend <nnnn>
```

---

## `amux status`

Show a dashboard of active agent sessions, running workflows, and headless server state.

```
amux status [FLAGS]
```

| Flag | Description |
|------|-------------|
| `--watch` | Continuously refresh the dashboard |

**Examples:**

```sh
amux status
amux status --watch
```

---

## `amux workflow`

Validate or preview workflow files without executing them.

### `amux workflow validate`

Parse a workflow file and report any syntax or ordering errors.

```
amux workflow validate <path>
```

**Examples:**

```sh
amux workflow validate ./workflows/plan-implement-review.md
amux workflow validate ./workflows/refactor.toml
```

Common errors caught: uppercase field keys, wrong field order in Markdown, unknown `Agent:` values, malformed template variable syntax.

### `amux workflow render`

Render a workflow with template variables substituted, printing the expanded steps to stdout. Useful for previewing what an agent will receive before executing.

```
amux workflow render <path> [FLAGS]
```

| Flag | Type | Description |
|------|------|-------------|
| `--work-item <nnnn>` | string | Work item to inject into template vars |

**Examples:**

```sh
# Preview the rendered prompts for work item 0027
amux workflow render ./workflows/plan-implement-review.md --work-item 0027
```

---

## `amux headless`

Manage the amux headless HTTP server (default port 9876).

### `amux headless start`

Start the REST server. Prints the API key plaintext on first run (stored as SHA-256 hash only — the key is not recoverable after this point).

```
amux headless start [FLAGS]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--port <n>` | integer | `9876` | Port to listen on |

**Example:**

```sh
amux headless start
amux headless start --port 9877
```

### `amux headless status`

Check whether the headless server is running and print its uptime and active session count.

```
amux headless status
```

### `amux headless kill`

Stop the running headless server.

```
amux headless kill
```

---

## `amux remote`

CLI client for a running headless server. Prefer `amux remote` over raw curl per the operator tooling-first convention — it carries auth, handles the session header, and formats output.

### `amux remote run`

Submit a subcommand string to the remote server.

```
amux remote run "<cmd>" [FLAGS]
```

| Flag | Description |
|------|-------------|
| `--follow` | Stream command logs to stdout until the command completes |

**Examples:**

```sh
# Submit a prompt non-interactively and return immediately
amux remote run "exec prompt 'Fix the failing tests'"

# Submit and stream output until complete
amux remote run "exec prompt 'Add docstrings to lib/' --auto" --follow
```

### `amux remote session start`

Create a new session on the remote server in the given working directory. The directory must be in `headless.workDirs`.

```
amux remote session start <dir>
```

**Example:**

```sh
amux remote session start /home/user/my-project
```

### `amux remote session kill`

Close a session on the remote server.

```
amux remote session kill <id>
```

---

## `amux tui`

Explicitly open the TUI. Equivalent to running `amux` with no arguments.

```
amux tui
```

---

## Common error modes

| Error | Likely cause |
|-------|-------------|
| `runtime not found` | Docker or Apple Containers not running; check `docker info` or `container system status` |
| `workdir not in allowlist` | `headless.workDirs` does not include the requested path; add it via `amux config set --global` |
| `HTTP 403 on POST /v1/commands` | Session already has a running command; wait for it to complete or poll `/v1/commands/:id` |
| `parse error: uppercase key` | Workflow file uses uppercase field names (e.g. `PROMPT:` instead of `Prompt:`); lowercase all keys |
| `field order error` | Markdown workflow has `Prompt:` before `Agent:` or `Model:`; correct order is `Depends-on` → `Agent` → `Model` → `Prompt` |
| `worktree already exists` | Previous `--yolo` run was aborted; find and resolve or discard the leftover worktree with `git worktree list` / `git worktree remove` |
| `no agent Dockerfile found` | Run `amux ready --refresh` to build the image after `amux init` or after editing `.amux/Dockerfile.*` |

---

Back to skill: [SKILL.md](../SKILL.md)
