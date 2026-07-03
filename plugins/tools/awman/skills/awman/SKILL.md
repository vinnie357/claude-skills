---
name: awman
description: Guide for using awman to run AI coding agents in isolated containers with multi-step workflows and a REST API. Use when configuring parallel agent sessions, authoring awman workflows, driving the awman api server, managing worktrees, migrating from amux, or troubleshooting awman container runs.
license: Apache-2.0
---

# awman

awman is a Rust CLI and TUI for running AI coding agents (Claude Code, Codex, OpenCode, and others) in isolated Docker or Apple Containers sandboxes. It coordinates parallel agent sessions, executes multi-step workflows, and exposes a REST API for headless programmatic control.

**awman is not a tmux wrapper.** The name invites that assumption. awman ships its own tab-based TUI with its own keybindings. Tmux is not a dependency.

awman was previously named **amux**. See "Migrating from amux" below.

Source: https://github.com/prettysmartdev/awman (accessed 2026-06-11)
License: Apache-2.0 | Latest at research time: v0.10.0 (2026-06-11)

## When to Use This Skill

Activate when:
- Setting up a project for parallel agent sessions (`awman init`, `awman ready`)
- Running a chat session or one-off prompt via the awman CLI
- Authoring or executing multi-step workflows (`awman new workflow`, `awman exec workflow`)
- Driving the REST API server (`awman api`) from an automation script
- Migrating an existing amux setup to awman
- Troubleshooting container isolation, worktrees, or config resolution
- Configuring agent selection, container runtimes, or environment passthrough

## Prerequisites

A container runtime, set via the global-only `runtime` config key (`awman config set --global runtime <value>`, then `awman ready`):

| `runtime` value | Platforms | Requirements |
|-----------------|-----------|--------------|
| `docker` (default) | Linux, macOS, Windows | Docker daemon |
| `apple-containers` | macOS 26+ | native `container` CLI |
| `docker-sbx-experimental` | macOS arm64, Windows x86_64 | `sbx` CLI (`brew install docker/tap/sbx` + `sbx login`) |

`docker-sbx-experimental` (new in 0.10.0) runs each session in a dedicated microVM — private kernel, filesystem, and Docker daemon. It does **not** honor `dir()`, skill, or context overlays; networking goes through an HTTP/HTTPS proxy (raw TCP/UDP blocked); sandboxes persist between sessions. The runtime must be running and healthy before any `awman` session starts. This runtime requires a free Docker account; `sbx login` is a one-time authentication step that must complete before `awman ready` reports the runtime healthy.

## Install

Mise is the recommended install path. It manages the version, pins reproducibly, and uses the GitHub releases backend — no extra dependencies.

A ready-to-copy pin lives at `templates/0.10.0/mise.toml` in this skill — copy it into the target repo's `mise.toml` (or merge under `[tools]`) and run `mise install`.

**Global pin (one-time, any project):**
```sh
mise use -g github:prettysmartdev/awman@0.10.0
```

**Per-project pin (recommended for repos that run awman):**
```sh
cp templates/0.10.0/mise.toml <your-repo>/mise.toml   # then: cd <your-repo> && mise install
```

The template's contents:
```toml
[tools]
"github:prettysmartdev/awman" = "0.10.0"
```

**Verify:**
```sh
mise which awman && awman --version
```

Fall back to the upstream installer (`curl -s https://prettysmart.dev/install/awman.sh | sh`) only when mise is unavailable (locked-down CI image, no GitHub release network access). State the reason explicitly when doing so. Building from source requires Rust 1.94+ and `make` (`git clone https://github.com/prettysmartdev/awman.git && cd awman && make install`). Do not use Homebrew, asdf, or mason — none are documented by upstream.

## Migrating from amux

The rename is automatic for existing users:

- Config migrates automatically on first run. Change any `AMUX_*` environment variables to `AWMAN_*` and you are done.
- The binary is now `awman`; the installer offers to clean up old `amux` binaries.
- Config keys under `headless.*` are now under `api.*` (e.g. `headless.workDirs` → `api.workDirs`).
- The server command `amux headless start` is now `awman api start`.
- Per-repo config moved from `aspec/.amux.json` to `GITROOT/.awman/config.json` (see Config below).
- Markdown workflow files (`.md`) are **no longer supported** — use TOML or YAML.

## First-Run Diagnostic

awman is pre-1.0 and ships frequently. Run these before trusting that docs match the installed binary:

```sh
awman --version
awman config show
```

`awman config show` prints the merged effective config (global + per-repo). Use it to verify `runtime`, `default_agent`, and overlay state rather than reading JSON files directly.

## Command Tree

| Command | Purpose |
|---------|---------|
| `awman init [--aspec] [--agent <name>]` | Scaffold project: writes `.awman/config.json` and per-agent Dockerfiles |
| `awman ready [--refresh]` | Verify environment; `--refresh` re-audits and rebuilds the agent Dockerfile |
| `awman chat [--agent <name>] [--auto] [--yolo]` | Interactive agent session in a TUI tab |
| `awman exec prompt "<text>" [--issue <ref>]` | One-off prompt without a persistent session |
| `awman exec workflow <path> [--work-item <nnnn> \| --issue <ref>] [--yolo] [--worktree]` | Run a multi-step workflow file |
| `awman new spec\|workflow\|skill [--interview] [--issue <ref>]` | Scaffold a work item, workflow, or custom skill |
| `awman specs amend <nnnn>` | Update an existing work item |
| `awman status [--watch]` | Session/workflow dashboard |
| `awman config show\|get\|set [--global]` | Inspect/modify merged config |
| `awman api start\|status\|logs\|kill` | Manage the REST API server (default port 9876) |
| `awman remote run\|session` | Drive a remote awman api server |
| `awman` (no args) | Open the TUI |

See `templates/0.10.0/commands.md` for the full v0.10.0 command surface with flags and examples.

## GitHub Issue Integration (0.10.0)

`--issue <ref>` on `new spec`, `exec workflow`, and `exec prompt` fetches a GitHub issue and injects it. Reference forms: bare number (`--issue 84`, requires a GitHub `origin` remote), shorthand (`--issue owner/repo#84`), or full URL. Auth resolution: `gh` CLI → `GITHUB_TOKEN` → unauthenticated REST (public repos, 60 requests/hour). For `exec workflow` the issue populates the `{{work_item_*}}` template variables exactly as `--work-item` does; `--issue` and `--work-item` are mutually exclusive.

## Agents

Supported agents: `claude`, `codex`, `opencode`, `maki`, `antigravity`, `copilot`, `crush`, `cline`.

> **`gemini` is deprecated** by Google upstream. Migrate to `antigravity` (`awman chat --agent antigravity` or `awman config set agent antigravity`). The `gemini` agent name remains accepted but logs a deprecation warning and has degraded system-prompt-injection support.

Each agent has a Dockerfile in `.awman/Dockerfile.<agent>` (seeded from upstream templates). Customize the Dockerfile to add tools or environment configuration for that agent. The project base image path is configurable via the per-repo `dockerfile` config key (default `Dockerfile.dev`) as of 0.10.0.

**Selection precedence** (highest wins):
1. Per-step `agent:` field in the workflow file
2. `--agent <name>` flag on the CLI invocation
3. `agent` key in per-repo `.awman/config.json`
4. `default_agent` key in `~/.awman/config.json` (global default; factory default: `"claude"`)

## Worktrees

Opt-in via `--worktree` on `awman chat` / `awman exec`. All steps in a single workflow run share one worktree.

Worktrees are **never auto-deleted**. At session end, awman prompts: merge / discard / keep. On abort, the worktree is preserved for manual inspection. Monitor disk use when running repeated `--yolo --worktree` workflow runs.

Containers run `--rm` and auto-remove at session end. Only the Git repository is bind-mounted; `/workspace` inside the container is ephemeral beyond what lands in the Git tree.

## Config Files

awman reads one `config.json` per scope:

| File | Scope | Created by | Commit? |
|------|-------|-----------|---------|
| `~/.awman/config.json` | Global | Manually or `awman config set --global` | No |
| `GITROOT/.awman/config.json` | Per-repo | `awman init` | Yes |

Per-repo takes precedence on overlapping scalar keys. The `overlays` string array merges **additively** across all sources (global config, repo config, `AWMAN_OVERLAYS`, `--overlay` flags, workflow steps); other list fields replace. The repo `.awman/` directory also holds per-agent Dockerfiles seeded by `awman init`. XDG base-directory environment variables are honored as of 0.10.0. Always use `awman config show` to see merged values rather than hand-editing the JSON.

See `references/config.md` for the full per-key schema (type, default, scope, merge behavior).

## Overlays

Overlay specs grant agent containers access to host resources: `dir(HOST:CONTAINER[:ro|rw])`, `ssh()`, `env(VAR)`, `skill(*)`/`skill(NAME)`, and — new in 0.10.0 — `context(global|repo|workflow[:ro])`. Context overlays combine a persistent host directory (`~/.awman/context/...`) with automatic system-prompt injection, giving agents a durable shared workspace across sessions; they default to `rw` so agents accumulate knowledge — pass `:ro` to lock them. On host-path conflicts, `:ro` always overrides `:rw`. See `references/config.md` for the full overlay grammar.

### env passthrough example

To make an agent use a local provider or custom endpoint, forward the relevant vars via `env()` overlays:

```json
{
  "overlays": [
    "env(ANTHROPIC_BASE_URL)",
    "env(ANTHROPIC_API_KEY)"
  ]
}
```

Or one-off via CLI flag (repeatable, or comma-separated in a single flag):

```sh
awman chat --overlay "env(ANTHROPIC_BASE_URL)" --overlay "env(ANTHROPIC_API_KEY)"
# or
awman chat --overlay "env(ANTHROPIC_BASE_URL),env(ANTHROPIC_API_KEY)"
```

If `ANTHROPIC_BASE_URL` is not set on the host, awman silently omits it — not an error.

> **`envPassthrough` is removed in 0.10.0.** The old `envPassthrough` array config key no longer works; `awman config get envPassthrough` returns a removal notice. Express env forwarding as `env()` overlay entries in the `overlays` array (config file, `AWMAN_OVERLAYS`, or `--overlay` flag) instead. See `references/config.md` for the migration table.

## API Mode

`awman api start` runs a REST server on port 9876 (configurable via `--port`). It serves **HTTPS with a self-signed certificate by default** — pass `--dangerously-skip-tls` for plain HTTP in trusted local setups. It accepts bearer-token auth. Sessions are restricted to directories in `api.workDirs` (global config) or passed via `--workdirs`.

**FIFO queue per session.** Submitting a second command while one is in flight enqueues it — submission never blocks and returns immediately with a `command_id`. Poll `GET /v1/commands/:id` or stream `/v1/commands/:id/logs/stream` (Server-Sent Events) to track progress. A `POST /v1/sessions` with a workdir outside the allowlist returns HTTP 403.

Prefer `awman remote` over raw curl when driving the server from the CLI — it carries auth and the session header per the operator-tooling-first convention.

See `references/api.md` for the full endpoint table and curl examples.

## Workflow Authoring

Workflows are TOML (`.toml`) or YAML (`.yml`/`.yaml`) files authored via `awman new workflow [--interview]` and executed via `awman exec workflow <path>`. **Markdown (`.md`) workflows are no longer supported as of 0.9.1.**

Step fields are lowercase only: `name` and `prompt` are required; `depends_on`, `agent`, `model`, and `overlays` are optional. Template variables available in prompts: `{{work_item_number}}` (zero-padded 4-digit), `{{work_item}}` (bare number), `{{work_item_content}}` (full file or fetched issue), `{{work_item_section:[Name]}}` (named section).

New in 0.10.0, workflows support **setup and teardown phases** with typed steps (`clone_repo`, `checkout_create_branch`, `run_shell`, `commit_changes`, `push_branch`, `create_pull_request`, …), including `poll_ci` (block until the branch's GitHub Actions run completes; `interval_secs`/`max_retries`) and per-step `on_failure` blocks that launch a remediation agent and retry the step up to `max_attempts` times.

See `references/workflows.md` for grammar in both formats and worked examples.

## Known Sharp Edges (Pre-1.0)

- **Not a tmux wrapper.** awman ships its own TUI. The name is misleading.
- **Markdown workflows dropped in 0.9.1.** Only TOML and YAML are accepted; other extensions are rejected.
- **API server is HTTPS by default.** Local curl needs `--dangerously-skip-tls` (server side) or trusting the self-signed cert.
- **Commands queue, not reject.** A busy session enqueues new commands in FIFO order rather than returning 403; a closing session returns HTTP 409.
- **`runtime` is global-only.** No per-repo runtime selection.
- **`docker-sbx-experimental` skips all overlays.** `dir()`, skills, and context mounts are not honored; networking is proxy-only; sandboxes persist between sessions and lose port mappings on stop.
- **`--issue` and `--work-item` are mutually exclusive.** Bare `--issue <N>` requires a GitHub `origin` remote — use `owner/repo#N` or a URL otherwise.
- **Context overlays default to `rw`.** Use `context(SCOPE:ro)` to stop agents from modifying accumulated knowledge.
- **`envPassthrough` is removed.** The old config key returns a removal notice. Use `env()` overlay entries in the `overlays` array instead.
- **`gemini` is deprecated.** Use `antigravity` as the replacement (`awman config set agent antigravity`).
- **Frequent release cadence.** Re-run `awman --version` when output looks unexpected. Pin in mise to control when you upgrade.
- **Lowercase keys only in workflow files.** Uppercase variants are parse errors.

## References

- `references/api.md` — REST endpoint table, bearer auth, curl examples
- `references/workflows.md` — Workflow grammar in TOML and YAML
- `references/config.md` — Per-key config schema for both scopes
- `references/command-reference.md` — Full CLI surface with flags and examples
- `templates/0.10.0/commands.md` — Immutable v0.10.0 command snapshot
- `templates/0.9.1/commands.md` — Immutable v0.9.1 command snapshot (previous version)

## Anti-Fabrication

Run `awman --version` and `awman config show` before asserting that any documented behavior matches the installed binary. awman is pre-1.0 and minor bumps carry breaking changes. Every command form in this skill traces to upstream docs sourced from https://github.com/prettysmartdev/awman (accessed 2026-06-11). Mark any behavior not confirmed by that source as "requires verification against awman v0.10.0 source." Apply `/core:anti-fabrication` rules to all outputs produced with this skill active.
