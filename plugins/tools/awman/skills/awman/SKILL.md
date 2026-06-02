---
name: awman
description: Guide for using awman to run AI coding agents in isolated containers with multi-step workflows and a REST API. Use when configuring parallel agent sessions, authoring awman workflows, driving the awman api server, managing worktrees, migrating from amux, or troubleshooting awman container runs.
license: Apache-2.0
---

# awman

awman is a Rust CLI and TUI for running AI coding agents (Claude Code, Codex, OpenCode, and others) in isolated Docker or Apple Containers sandboxes. It coordinates parallel agent sessions, executes multi-step workflows, and exposes a REST API for headless programmatic control.

**awman is not a tmux wrapper.** The name invites that assumption. awman ships its own tab-based TUI with its own keybindings. Tmux is not a dependency.

awman was previously named **amux**. See "Migrating from amux" below.

Source: https://github.com/prettysmartdev/awman (accessed 2026-06-02)
License: Apache-2.0 | Latest at research time: v0.9.1 (2026-05-28)

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

- A container runtime: **Docker** (Linux, macOS, Windows) or **Apple Containers** (macOS 26+). Set via global `runtime` config key. The two runtimes are mutually exclusive.
- Runtime running and healthy before any `awman` session starts.

## Install

Mise is the recommended install path. It manages the version, pins reproducibly, and uses the GitHub releases backend — no extra dependencies.

A ready-to-copy pin lives at `templates/0.9.1/mise.toml` in this skill — copy it into the target repo's `mise.toml` (or merge under `[tools]`) and run `mise install`.

**Global pin (one-time, any project):**
```sh
mise use -g github:prettysmartdev/awman@0.9.1
```

**Per-project pin (recommended for repos that run awman):**
```sh
cp templates/0.9.1/mise.toml <your-repo>/mise.toml   # then: cd <your-repo> && mise install
```

The template's contents:
```toml
[tools]
"github:prettysmartdev/awman" = "0.9.1"
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
| `awman exec prompt "<text>"` | One-off prompt without a persistent session |
| `awman exec workflow <path> [--work-item <nnnn>] [--yolo] [--worktree]` | Run a multi-step workflow file |
| `awman new spec\|workflow\|skill [--interview]` | Scaffold a work item, workflow, or custom skill |
| `awman specs amend <nnnn>` | Update an existing work item |
| `awman status [--watch]` | Session/workflow dashboard |
| `awman config show\|get\|set [--global]` | Inspect/modify merged config |
| `awman api start\|status\|logs\|kill` | Manage the REST API server (default port 9876) |
| `awman remote run\|session` | Drive a remote awman api server |
| `awman` (no args) | Open the TUI |

See `templates/0.9.1/commands.md` for the full v0.9.1 command surface with flags and examples.

## Agents

Supported agents: `claude`, `codex`, `opencode`, `maki`, `gemini`, `antigravity`, `copilot`, `crush`, `cline`.

Each agent has a Dockerfile in `.awman/Dockerfile.<agent>` (seeded from upstream templates). Customize the Dockerfile to add tools or environment configuration for that agent.

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

Per-repo takes precedence on overlapping scalar keys. `overlays.skills` and `overlays.directories` merge **additively** across scopes. The repo `.awman/` directory also holds per-agent Dockerfiles seeded by `awman init`. Always use `awman config show` to see merged values rather than hand-editing the JSON.

See `references/config.md` for the full per-key schema (type, default, scope, merge behavior).

## API Mode

`awman api start` runs a REST server on port 9876 (configurable via `--port`). It serves **HTTPS with a self-signed certificate by default** — pass `--dangerously-skip-tls` for plain HTTP in trusted local setups. It accepts bearer-token auth. Sessions are restricted to directories in `api.workDirs` (global config) or passed via `--workdirs`.

**FIFO queue per session.** Submitting a second command while one is in flight enqueues it — submission never blocks and returns immediately with a `command_id`. Poll `GET /v1/commands/:id` or stream `/v1/commands/:id/logs/stream` (Server-Sent Events) to track progress. A `POST /v1/sessions` with a workdir outside the allowlist returns HTTP 403.

Prefer `awman remote` over raw curl when driving the server from the CLI — it carries auth and the session header per the operator-tooling-first convention.

See `references/api.md` for the full endpoint table and curl examples.

## Workflow Authoring

Workflows are TOML (`.toml`) or YAML (`.yml`/`.yaml`) files authored via `awman new workflow [--interview]` and executed via `awman exec workflow <path>`. **Markdown (`.md`) workflows are no longer supported as of 0.9.1.**

Step fields are lowercase only: `name` and `prompt` are required; `depends_on`, `agent`, and `model` are optional. Template variables available in prompts: `{{work_item_number}}` (zero-padded 4-digit), `{{work_item}}` (bare number), `{{work_item_content}}` (full file), `{{work_item_section:[Name]}}` (named section).

See `references/workflows.md` for grammar in both formats and worked examples.

## Known Sharp Edges (Pre-1.0)

- **Not a tmux wrapper.** awman ships its own TUI. The name is misleading.
- **Markdown workflows dropped in 0.9.1.** Only TOML and YAML are accepted; other extensions are rejected.
- **API server is HTTPS by default.** Local curl needs `--dangerously-skip-tls` (server side) or trusting the self-signed cert.
- **Commands queue, not reject.** A busy session enqueues new commands in FIFO order rather than returning 403; a closing session returns HTTP 409.
- **`runtime` is global-only.** No per-repo selection between Docker and Apple Containers.
- **Frequent release cadence.** Re-run `awman --version` when output looks unexpected. Pin in mise to control when you upgrade.
- **Lowercase keys only in workflow files.** Uppercase variants are parse errors.

## References

- `references/api.md` — REST endpoint table, bearer auth, curl examples
- `references/workflows.md` — Workflow grammar in TOML and YAML
- `references/config.md` — Per-key config schema for both scopes
- `references/command-reference.md` — Full CLI surface with flags and examples
- `templates/0.9.1/commands.md` — Immutable v0.9.1 command snapshot

## Anti-Fabrication

Run `awman --version` and `awman config show` before asserting that any documented behavior matches the installed binary. awman is pre-1.0 and minor bumps carry breaking changes. Every command form in this skill traces to upstream docs sourced from https://github.com/prettysmartdev/awman (accessed 2026-06-02). Mark any behavior not confirmed by that source as "requires verification against awman v0.9.1 source." Apply `/core:anti-fabrication` rules to all outputs produced with this skill active.
