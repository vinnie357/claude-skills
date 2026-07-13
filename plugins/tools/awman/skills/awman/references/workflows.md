# awman Workflow Authoring

Reference for authoring awman workflow files as of v0.11.0. Two formats are supported: **TOML** and **YAML**.

Source: https://github.com/prettysmartdev/awman/blob/main/docs/05-workflows.md and docs/15-parallel-workflows.md — accessed 2026-07-13.

> **Migrating from amux:** Markdown workflow files (`.md`) are **no longer supported as of 0.9.1**. Any extension other than `.toml`, `.yml`, or `.yaml` is rejected. Convert Markdown workflows to TOML or YAML.

---

## Critical rules (read first)

1. **Lowercase keys only.** Field names are `name`, `prompt`, `depends_on`, `agent`, `model`, `overlays`. Uppercase variants are not accepted.
2. **`name` and `prompt` are required** on every main step; `depends_on`, `agent`, `model`, and `overlays` are optional. Setup/teardown steps require `type` instead.
3. **No prescribed field order** — structure follows normal TOML/YAML syntax.
4. **Template variables** are substituted at execution time and require `--work-item` or `--issue`.

---

## Creating workflows

```sh
awman new workflow                 # interactive
awman new workflow --interview     # AI-generated from a summary
awman new workflow --global        # write to the personal library
awman new workflow --format yaml   # choose output format (toml | yaml)
```

## Executing workflows

```sh
awman exec workflow aspec/workflows/implement.toml
awman exec workflow <path> --work-item 0027
awman exec workflow <path> --issue owner/repo#84
awman exec workflow <path> --yolo --worktree
```

Execution flags: `--agent`, `--model`, `--non-interactive`, `--plan`, `--yolo`, `--worktree`, `--allow-docker`, `--mount-ssh`, `--work-item <N>`, `--issue <ref>` (0.10.0; fetches a GitHub issue and treats it as the work item — mutually exclusive with `--work-item`), `--max-concurrent <n>` (0.11.0; caps parallel step containers for this run).

The `--agent` flag sets the **default** for steps that do not name an agent; it does **not** override steps that explicitly specify one.

For workflows designed on the fly by a leader agent (`--dynamic`), see `references/command-reference.md` — dynamic mode generates and executes a `workflow.toml` from a work item without a hand-authored file.

---

## Parallel execution (0.11.0)

Steps with **identical `depends_on` sets** form a parallel group and launch concurrently — neither depends on the other, so the engine runs them at the same time:

```
implement → tests
          → docs
          → review (depends_on = ["tests", "docs"])
```

Once `implement` completes, `tests` and `docs` start immediately; `review` waits for both.

- **Scheduling:** eligible steps launch in workflow file order up to the `maxConcurrentAgents` cap; when a slot frees, the next queued step starts. Unset cap = unlimited; `1` disables parallelism; `0` is rejected. Precedence: `--max-concurrent` → `AWMAN_MAX_CONCURRENT_AGENTS` → repo config → global config. See `references/config.md`.
- **Failure:** a failed step without `abort_on_failure` lets siblings continue; `abort_on_failure = true` kills all active peers in the group instantly.
- **Per-container tracking:** stuck detection (30 s silent) and yolo countdowns (60 s) apply to each container independently — one stuck or expired container does not affect its siblings.
- **TUI:** `Ctrl-S` rotates focus between running containers (passes through to the PTY when only one runs). The Workflow Control Board (`Ctrl-W`) scopes actions to the focused container; "Restart current step", "Cancel to previous step", and "Finish workflow" are disabled while peers run, but "Pause" and "Abort" stay available.

---

## Template variables

Available in all workflow text fields (not in `type`). Substituted at execution time; require `--work-item <nnnn>` or `--issue <ref>`. Omitting both replaces variables with empty strings and emits a warning.

| Variable | Substituted with |
|----------|-----------------|
| `{{work_item_number}}` | Zero-padded 4-digit number (e.g. `0027`) |
| `{{work_item}}` | The bare number |
| `{{work_item_content}}` | Full Markdown text of the work item file (or fetched GitHub issue) |
| `{{work_item_section:[Name]}}` | Named section within the work item (case-insensitive) |

---

## Step fields (main steps)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | string | yes | Step identifier; referenced by `depends_on` |
| `prompt` | string | yes | Prompt body; supports template variables |
| `depends_on` | array of step names | no | Steps that must finish before this one |
| `agent` | string | no | Overrides the default agent for this step |
| `model` | string | no | Overrides the model for this step |
| `overlays` | array of overlay specs | no | Per-step overlays, e.g. `["ssh()", "skill(search)"]`; workflow-level `overlays` under `[workflow]` apply to all steps |
| `abort_on_failure` | boolean | no | On failure, kill all active parallel peers and stop the workflow (0.11.0); without it, siblings continue. With an `on_failure` block, the remediation loop runs first — abort triggers only after `max_attempts` is exhausted |

---

## Setup and teardown phases (0.10.0)

Setup steps run before main steps; teardown steps run after. Each is a typed step (`type` required) rather than a prompt step. Setup/teardown overlays support `dir()`, `ssh()`, and `env()` — **not** `skill()`.

**Setup step types:**

| Type | Required fields | Optional fields |
|------|-----------------|-----------------|
| `clone_repo` | `url` | `branch`, `into` |
| `checkout_create_branch` | `branch` | `base` |
| `pull_branch` | — | `remote`, `branch` |
| `run_shell` | `command` | `env` |
| `run_script` | `path` | `env` |
| `poll_ci` | — | `interval_secs` (default 30), `max_retries` (default 10) |

**Teardown step types:**

| Type | Required fields | Optional fields |
|------|-----------------|-----------------|
| `run_shell` | `command` | `env` |
| `run_script` | `path` | `env` |
| `commit_changes` | `message` | `add_all` (boolean) |
| `push_branch` | — | `remote`, `branch` |
| `create_pull_request` | — | `title`, `body`, `base` |
| `poll_ci` | — | `interval_secs`, `max_retries` |

`poll_ci` polls GitHub for the CI run associated with the current commit on the current branch and waits for completion (success or failure) or times out after `max_retries` attempts. Auth: `gh` CLI first, then `GITHUB_TOKEN`.

Top-level `teardown_on_failure = true` runs teardown even when main steps fail (default `false`). A failed teardown step logs the error and execution continues to the next teardown step (best-effort cleanup).

### on_failure remediation blocks

Setup and teardown steps accept an optional `on_failure` block: when the step fails, a remediation agent runs the given prompt, then the step retries — repeating up to `max_attempts` cycles.

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

```yaml
setup:
  - type: run_shell
    command: npm test
    on_failure:
      prompt: Tests failed. Fix issues and verify.
      max_attempts: 2
```

### Automatic failure output capture (0.11.0)

When a **teardown** step's `on_failure` remediation agent launches, awman captures the failed command's stdout/stderr (capped at 100 KB per stream) and writes it to a file the agent can read; a note prepended to the remediation prompt says where:

- With a writable `context(workflow)` overlay: `/awman/context/workflow/teardown-failure-<step-name>.txt`
- Otherwise: a dedicated directory mounted read-only at `/awman/remediation/teardown-failure-<step-name>.txt`

On retry the file is overwritten with the latest failure. **Setup steps get no automatic capture** — include failure context explicitly in the `prompt` field.

### Failure logs (0.11.0)

Failed step container output (~100 lines rolling, combined stdout/stderr) is saved to `~/.awman/logs/{workflow-id}-{step-name}-{container-name}.log`. Logs are written only when the container failed **on its own** — containers awman itself stops (yolo auto-advance, control-board Abort/Pause/Finish, stuck-step cancel, `abort_on_failure` killing siblings) exit as expected and produce no log. `docker-sbx-experimental` runtimes do not produce these logs. The directory is created on demand and **never auto-cleaned** — `awman clean` does not touch it.

---

## TOML format

A TOML workflow is an array of step tables (`[[step]]`) with an optional top-level `title`.

```toml
title = "Implement Feature Workflow"

[[step]]
name = "plan"
prompt = """
Read the following work item and produce a detailed implementation plan.
Include file paths, function names, and acceptance criteria.

{{work_item_content}}
"""

[[step]]
name = "implement"
depends_on = ["plan"]
agent = "codex"
model = "claude-haiku-4-5"
prompt = """
Implement work item {{work_item_number}} according to the plan from the previous step.
Run the test suite after each significant change.
"""

[[step]]
name = "review"
depends_on = ["implement"]
agent = "claude"
prompt = """
Review the implementation against the acceptance criteria in:

{{work_item_section:[Acceptance Criteria]}}

Report any gaps or regressions.
"""
```

**Key rules:** all keys lowercase; `depends_on` is an array even for a single dependency; multi-line prompts use TOML triple-quoted strings (`"""`).

### Common TOML errors

| Error | Cause | Fix |
|-------|-------|-----|
| `depends_on` not an array | `depends_on = "plan"` | Use `depends_on = ["plan"]` |
| Template var not substituted | `--work-item` not passed | Add `--work-item <nnnn>` |
| Uppercase key rejected | `Name = "plan"` | Use `name = "plan"` |

---

## YAML format

A YAML workflow nests steps under a top-level `steps:` key. `depends_on` must be a YAML sequence, not a bare string.

```yaml
steps:
  - name: plan
    prompt: |
      Read the following work item and produce a detailed implementation plan.
      Include file paths, function names, and acceptance criteria.

      {{work_item_content}}

  - name: implement
    depends_on:
      - plan
    agent: codex
    model: claude-haiku-4-5
    prompt: |
      Implement work item {{work_item_number}} according to the plan from the previous step.
      Run the test suite after each significant change.

  - name: review
    depends_on:
      - implement
    agent: claude
    prompt: |
      Review the implementation against the acceptance criteria in:

      {{work_item_section:[Acceptance Criteria]}}

      Report any gaps or regressions.
```

**Key rules:** all keys lowercase; `depends_on` is a sequence; use block scalars (`|`) for multi-line prompts; 2-space indentation.

### Common YAML errors

| Error | Cause | Fix |
|-------|-------|-----|
| Indentation parse error | Inconsistent spaces | Use 2-space indentation throughout |
| `depends_on` not a list | `depends_on: plan` | Use a YAML sequence (`- plan`) |
| Template variable literal in output | Typo or no `--work-item` | Check spelling; add `--work-item <nnnn>` |

---

## Choosing a format

| Format | When to use |
|--------|-------------|
| TOML | Machine-generated workflows; strict schema; structured data alongside prompts |
| YAML | Teams that already use YAML tooling; shorter syntax for simple step sequences |

Both formats support identical features. Choose based on your team's tooling preferences.

---

Back to skill: [SKILL.md](../SKILL.md)
