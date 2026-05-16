---
name: amux
description: Guide for using amux to run AI coding agents in isolated containers with multi-step workflows and a headless REST API. Use when configuring parallel agent sessions, authoring amux workflows, driving the headless REST API, managing worktrees, or troubleshooting amux container runs.
license: Apache-2.0
---

# amux

amux is a Rust CLI and TUI for running AI coding agents (Claude Code, codex, opencode, and others) in isolated Docker or Apple Containers sandboxes. It coordinates parallel agent sessions, executes multi-step workflows, and exposes a REST API for headless programmatic control.

**amux is not a tmux wrapper.** The name invites that assumption. amux ships its own tab-based TUI with its own keybindings. Tmux is not a dependency.

Source: https://github.com/prettysmartdev/amux (accessed 2026-05-16)
License: Apache-2.0 | Latest at research time: v0.8.0 (2026-04-12)

## When to Use This Skill

Activate when:
- Setting up a project for parallel agent sessions (`amux init`, `amux ready`)
- Running a chat session or one-off prompt via the amux CLI
- Authoring or executing multi-step workflows (`amux new workflow`, `amux exec workflow`)
- Driving the headless REST server from an automation script
- Troubleshooting container isolation, worktrees, or config file conflicts
- Configuring agent selection, container runtimes, or environment passthrough

## Prerequisites

- A container runtime: **Docker** (Linux, macOS, Windows) or **Apple Containers** (macOS 26+). Set via global `runtime` config key. The two runtimes are mutually exclusive.
- Runtime running and healthy before any `amux` session starts.

## Install

Mise is the recommended install path. It manages the version, pins reproducibly, and uses the GitHub releases backend — no extra dependencies.

A ready-to-copy pin lives at `templates/0.8.0/mise.toml` in this skill — copy it into the target repo's `mise.toml` (or merge under `[tools]`) and run `mise install`.

**Global pin (one-time, any project):**
```sh
mise use -g github:prettysmartdev/amux@0.8.0
```

**Per-project pin (recommended for repos that run amux):**
```sh
cp templates/0.8.0/mise.toml <your-repo>/mise.toml   # then: cd <your-repo> && mise install
```

The template's contents:
```toml
[tools]
"github:prettysmartdev/amux" = "0.8.0"
```

**Verify:**
```sh
mise which amux && amux --version
```

Fall back to the upstream installer (`curl -s https://prettysmart.dev/install/amux.sh | sh`) or a pre-built binary from https://github.com/prettysmartdev/amux/releases only when mise is unavailable (locked-down CI image, no GitHub release network access). State the reason explicitly when doing so. Building from source requires Rust 1.94+ (`git clone` + `sudo make install`). Do not use Homebrew, asdf, or mason — none are documented by upstream.

## First-Run Diagnostic

amux is pre-1.0 and ships weekly. Run these before trusting that docs match the installed binary:

```sh
amux --version
amux config show
```

`amux config show` prints the merged effective config (global + per-repo). Use it to verify `runtime`, `default_agent`, and overlay state rather than reading JSON files directly.

## Command Tree

| Command | Purpose |
|---------|---------|
| `amux init [--agent <name>]` | Scaffold project: writes `aspec/.amux.json`, populates `.amux/Dockerfile.*` |
| `amux ready [--refresh]` | Verify environment; `--refresh` rebuilds the agent Dockerfile |
| `amux chat [--agent <name>] [--auto] [--yolo]` | Interactive agent session in TUI tab |
| `amux exec prompt "<text>"` | One-off prompt without a persistent session |
| `amux exec workflow <path> [--work-item <nnnn>] [--yolo] [--worktree]` | Run a multi-step workflow file |
| `amux new spec [--interview]` | Create a numbered work item file |
| `amux new workflow [--interview]` | Scaffold a workflow file |
| `amux new skill [--interview]` | Create a custom skill for the skills overlay |
| `amux specs amend <nnnn>` | Update an existing spec |
| `amux status [--watch]` | Session/workflow dashboard |
| `amux config show` | Merged effective config |
| `amux config get <field>` | Single field with precedence breakdown |
| `amux config set [--global] <field> <value>` | Write a config key |
| `amux headless start [--port <n>]` | Start REST server (default port 9876) |
| `amux headless status` | Check headless server |
| `amux headless kill` | Stop headless server |
| `amux remote run <cmd> [--follow]` | Submit command to remote headless server |
| `amux remote session start <dir>` | Create session on headless server |
| `amux remote session kill <id>` | Close session on headless server |
| `amux` (no args) | Open TUI |

See `templates/0.8.0/commands.md` for the full v0.8.0 command surface with flags and examples.

## Agents

Supported agents: `claude`, `codex`, `opencode`, `maki`, `gemini`, `copilot`, `crush`, `cline`.

Each agent has a Dockerfile in `.amux/Dockerfile.<agent>` (seeded from upstream templates). Customize the Dockerfile to add tools or environment configuration for that agent.

**Selection precedence** (highest wins):
1. Per-step `Agent:` field in the workflow file
2. `--agent <name>` flag on the CLI invocation
3. `agent` key in `aspec/.amux.json` (per-repo default)
4. `default_agent` key in `~/.amux/config.json` (global default; factory default: `"claude"`)

## Worktrees

Opt-in via `--worktree` on `amux chat` / `amux exec`, or implicitly when `--yolo` is used with `amux exec workflow`. All steps in a single workflow run share one worktree.

Worktrees are **never auto-deleted**. At session end, amux prompts: merge / discard / keep. On abort, the worktree is preserved for manual inspection. Monitor disk use when running repeated `--yolo` workflow runs.

Containers run `--rm` and auto-remove at session end. Only the Git repository is bind-mounted; `/workspace` inside the container is ephemeral beyond what lands in the Git tree.

## Config Files

Two JSON files coexist — do not confuse them:

| File | Scope | Created by | Commit? |
|------|-------|-----------|---------|
| `~/.amux/config.json` | Global | Manually or `amux config set --global` | No |
| `GITROOT/aspec/.amux.json` | Per-repo | `amux init` | Yes |

Per-repo takes precedence on overlapping scalar keys. `overlays.skills` and `overlays.directories` merge **additively** across scopes.

The `.amux/` directory inside the repo holds per-agent Dockerfiles and a `config.json` for local-only overrides — this is a separate file from `aspec/.amux.json`. Always use `amux config show` to see merged values rather than hand-editing either JSON file.

See `references/config.md` for the full per-key schema (type, default, scope, merge behavior).

## Headless Mode

`amux headless start` runs a REST server on port 9876 (configurable via `--port`). It accepts bearer-token auth. Sessions are restricted to directories listed in `headless.workDirs` in the global config.

**One active command per session.** Submitting a second command while one is in flight returns HTTP 403. Commands are async — `POST /v1/commands` returns a `command_id` immediately; poll `/v1/commands/:id` or stream `/v1/commands/:id/logs/stream` (Server-Sent Events) to track progress.

Prefer `amux remote run` over raw curl when driving the headless server from the CLI — it is the canonical wrapper per the operator-tooling-first convention.

See `references/headless-api.md` for the full endpoint table and curl examples.

## Workflow Authoring

Workflows are Markdown (`.md`), TOML (`.toml`), or YAML (`.yml`/`.yaml`) files authored via `amux new workflow [--interview]` and executed via `amux exec workflow <path>`.

Template variables available in prompts: `{{work_item_number}}` (zero-padded 4-digit), `{{work_item_content}}` (full file), `{{work_item_section:[Name]}}` (named section).

See `references/workflows.md` for grammar in all three formats, field ordering rules, and worked examples.

## Known Sharp Edges (Pre-1.0)

- **Not a tmux wrapper.** amux ships its own TUI. The name is misleading.
- **Two config files with similar paths.** `aspec/.amux.json` (canonical, commit it) vs `.amux/config.json` (local overlay). Use `amux config show` — never hand-edit.
- **Worktrees never auto-clean.** Each aborted `--yolo` run leaves a worktree on disk. Run `git worktree list` periodically and prune stale ones.
- **One concurrent command per headless session.** HTTP 403 on a second submit. Poll completion before re-using a session.
- **`runtime` is global-only.** No per-repo selection between Docker and Apple Containers.
- **Weekly release cadence.** Re-run `amux --version` when output looks unexpected. Pin in mise to control when you upgrade.
- **Markdown workflow field order is mandatory.** `Depends-on` → `Agent` → `Model` → `Prompt`. Anything after `Prompt:` becomes prompt text — trailing fields are silently consumed.
- **Lowercase keys only in all workflow formats.** Uppercase variants are parse errors.
- **No MCP server and no hooks as of v0.8.0.** amux does not expose MCP and has no pre/post lifecycle hooks. Server-Sent Events on `/v1/commands/:id/logs/stream` are the only streaming interface.

## References

- `references/headless-api.md` — REST endpoint table, bearer auth, curl examples
- `references/workflows.md` — Workflow grammar in Markdown, TOML, and YAML
- `references/config.md` — Per-key config schema for both config files
- `references/command-reference.md` — Full CLI surface with flags and examples
- `templates/0.8.0/commands.md` — Immutable v0.8.0 command snapshot

## Anti-Fabrication

Run `amux --version` and `amux config show` before asserting that any documented behavior matches the installed binary. amux is pre-1.0 and minor bumps carry breaking changes. Every command form in this skill traces to the research report sourced from https://github.com/prettysmartdev/amux (accessed 2026-05-16). Mark any behavior not confirmed by that source as "requires verification against amux v0.8.0 source." Apply `/core:anti-fabrication` rules to all outputs produced with this skill active.
