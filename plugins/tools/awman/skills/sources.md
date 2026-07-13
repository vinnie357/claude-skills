# awman Plugin Sources

This file documents the sources used to create and maintain the awman plugin skill.

awman was previously named **amux** (repo `prettysmartdev/amux`). The skill was renamed and refreshed to awman v0.9.1 on 2026-06-02; all sources below point at the current `prettysmartdev/awman` repository.

## Release History

### v0.11.0 (2026-07-13, skill updated 2026-07-13)
- **URL**: https://github.com/prettysmartdev/awman/releases/tag/v0.11.0
- **Summary**: Additive release, no config migration required. **Dynamic workflows**: `awman exec workflow --dynamic --work-item <N>` launches a leader agent that designs and executes a workflow; `--leader <agent::model>` override; new `dynamicWorkflows` config section (`agentsToModels`, `defaultLeader`, `maxConcurrentSteps`, `guidance`); `--dynamic` force-enables `--yolo`/`--worktree`/`context(workflow)`. **True parallel execution**: steps with identical `depends_on` sets run concurrently; `maxConcurrentAgents` config / `AWMAN_MAX_CONCURRENT_AGENTS` / `--max-concurrent` cap (unset = unlimited, 1 disables, 0 rejected); per-step `abort_on_failure` kills active peers. **Git sidebar** (`Ctrl-G`), parallel-container switching (`Ctrl-S`), config-dialog nested-key editing (`Ctrl-,` + `Ctrl+N`). **`awman clean`** (`--dry-run`, `--yes`; exit codes 0/1/2). **Container failure logging** to `~/.awman/logs/{workflow-id}-{step-name}-{container-name}.log` (never auto-cleaned); teardown `on_failure` agents receive failed output as a file, setup steps get no capture. Fixes: credentials injected via environment; workflow filename path-traversal sanitization; OpenCode prompt handling; Codex Dockerfiles updated for newer GPT models. Docs tree additive: new `13-dynamic-workflows.md`, `14-cleaning-up.md`, `15-parallel-workflows.md` (no renumbering).
- **Skill changes**: `templates/0.11.0/` snapshot added; SKILL.md gained Dynamic Workflows / Parallel Execution / Cleanup and Failure Logs sections + 4 sharp edges; references/config.md gained `dynamicWorkflows.*` and `maxConcurrentAgents`; references/workflows.md gained parallel-group semantics, `abort_on_failure`, failure-log and teardown-capture contracts; references/api.md re-verified against current `docs/09-api-mode.md` and updated where our 0.10.0-era snapshot had drifted (session `type: local|remote` with remote git-clone sessions, `POST /v1/commands` → `{command_id, flags_applied}` with `non_interactive`/`yolo` API-profile defaults, command status enum `queued/running/done/error/cancelled` with `queue_position`/`worker_id`, `--dangerously-skip-auth`).
- **Discrepancy noted**: the end-to-end example in upstream `docs/09-api-mode.md` uses `[[steps]]` in a TOML workflow; `docs/05-workflows.md` uses `[[step]]` exclusively (16 occurrences). The skill documents `[[step]]` per the authoritative workflows page.

### skill update 0.2.1 → 0.2.2 (2026-06-12)
- **Source verified**: `docs/08-overlays.md` (https://github.com/prettysmartdev/awman/blob/main/docs/08-overlays.md, accessed 2026-06-12) and `docs/03-agent-sessions.md` (accessed 2026-06-12)
- **Changes**: Added `envPassthrough` removal notice + `env()` overlay migration example to SKILL.md and references/config.md. Added `gemini` deprecation note with `antigravity` migration guidance. Added env-passthrough worked example (ANTHROPIC_BASE_URL pattern) to SKILL.md Overlays section. Updated example global config in references/config.md to show env passthrough via `overlays` array. Added two items to Known Sharp Edges.
- **Discrepancy noted**: Upstream `docs/08-overlays.md` "Removed forms" section says `envPassthrough` is "deprecated"; live awman 0.10.0 session returns a hard REMOVAL notice ("the 'envPassthrough' field was removed"). The skill documents the live behavior (removed) and notes the upstream wording discrepancy.

### v0.10.0 (2026-06-11, skill updated 2026-06-11)
- **URL**: https://github.com/prettysmartdev/awman/releases/tag/v0.10.0
- **Summary**: Additive release, no config migration required. New experimental `docker-sbx-experimental` runtime (microVM-per-session via Docker's `sbx` CLI; macOS arm64 / Windows x86_64; no overlay support, proxy-only networking, persistent sandboxes). New `--issue <ref>` GitHub integration on `new spec` / `exec workflow` / `exec prompt` (auth: gh CLI → GITHUB_TOKEN → unauthenticated). Workflow setup/teardown phases gained `poll_ci` steps and `on_failure` remediation blocks with retries. New `context()` overlays (global/repo/workflow scopes, durable on-disk workspace + system-prompt injection). Configurable base Dockerfile (`dockerfile` key, default `Dockerfile.dev`) and XDG base-dir support. Fix: Codex deprecated `--full-auto` flag in yolo mode. Docs tree renumbered: new `01-concepts.md`, `11-github-integration.md`, `12-runtimes.md`; workflows moved `04` → `05`; the standalone headless-mode page was removed.
- **Skill changes**: SKILL.md refreshed; `templates/0.10.0/` snapshot added; references/config.md rewritten to the 0.10.0 schema (`overlays` is now a string array of `dir()/ssh()/env()/skill()/context()` specs; new keys `dockerfile`, `agentStuckTimeout`, `api.port`, `workers`; `envPassthrough` no longer appears in upstream config docs — env forwarding is via `env()` overlays).

### v0.9.1 (2026-05-28, skill updated 2026-06-02)
- Rename from amux; Markdown workflows dropped; `headless.*` → `api.*`. See `templates/0.9.1/commands.md`.

## awman Skill

### awman Repository
- **URL**: https://github.com/prettysmartdev/awman
- **Purpose**: Primary source for awman overview, tagline, feature list, supported agents, install methods, and runtime requirements
- **Date Accessed**: 2026-06-02
- **Key Topics**: CLI/TUI overview, parallel agent sessions, container isolation, worktree model, agent list (claude, codex, opencode, maki, gemini, antigravity, copilot, crush, cline), license (Apache-2.0), rename from amux

### awman README
- **URL**: https://github.com/prettysmartdev/awman/blob/main/README.md
- **Purpose**: Top-level reference for tagline, command summary, install instructions, and the amux→awman migration note
- **Date Accessed**: 2026-06-02
- **Key Topics**: Flat top-level command tree (init, ready, chat, exec, new, specs, status, config, api, remote), curl + mise install paths, automatic config migration, `AMUX_*` → `AWMAN_*` env rename

### awman docs/ Directory
- **URL**: https://github.com/prettysmartdev/awman/tree/main/docs
- **Purpose**: Parent tree for all numbered documentation pages; individual pages cited below
- **Date Accessed**: 2026-06-11 (tree renumbered in 0.10.0)
- **Individual Pages**:
  - `docs/00-getting-started.md` — install methods (awman.sh, mise github backend, make install / Rust 1.94+), `awman init`/`awman ready`, supported agents, runtimes
  - `docs/01-concepts.md` — concept overview (new in 0.10.0 docs tree)
  - `docs/02-using-the-tui.md` — TUI usage and keybindings
  - `docs/03-agent-sessions.md` — `awman chat` / `awman exec` flags (`--agent`, `--model`, `--plan`, `--auto`, `--yolo`, `--worktree`, `--non-interactive`, `--overlay`, `--allow-docker`, `--mount-ssh`), session lifecycle
  - `docs/04-security-and-isolation.md` — container isolation, worktree opt-in, mount semantics
  - `docs/05-workflows.md` — workflow authoring in TOML/YAML, main step fields, setup/teardown phases, `poll_ci`, `on_failure` blocks, template variables, `teardown_on_failure`
  - `docs/06-yolo-mode.md` — `--yolo` semantics, `--auto` selective permission skipping
  - `docs/07-configuration.md` — global (`~/.awman/config.json`) and per-repo (`GITROOT/.awman/config.json`) config, per-key table, `api.*` keys, `overlays` string-array additive merge, `dockerfile`/`agentStuckTimeout`/`api.port` keys
  - `docs/08-overlays.md` — overlay spec grammar: `dir()`, `ssh()`, `env()`, `skill()`, `context()` (context overlays new in 0.10.0)
  - `docs/09-api-mode.md` — REST API server (`awman api start/status/logs/kill`), endpoints, bearer auth, `x-awman-session` header, `api.workDirs` allowlist, FIFO queue, HTTPS self-signed default
  - `docs/10-remote-mode.md` — `awman remote run/session`, `remote.*` config keys, `AWMAN_REMOTE_ADDR` / `AWMAN_API_KEY` / `AWMAN_REMOTE_SESSION`
  - `docs/11-github-integration.md` — `--issue <ref>` flag: reference formats, auth resolution order, content injection per command (new in 0.10.0)
  - `docs/12-runtimes.md` — runtime values (`docker`, `apple-containers`, `docker-sbx-experimental`), platform support, sbx install/login, caveats (new in 0.10.0)
  - `docs/architecture.md` — architectural summary

### awman Releases
- **URL**: https://github.com/prettysmartdev/awman/releases
- **Purpose**: Release history and cadence; pinned-version reference
- **Date Accessed**: 2026-06-11
- **Key Topics**: v0.10.0 released 2026-06-11; pre-1.0 minor bumps may carry breaking changes

### awman Install Script
- **URL**: https://prettysmart.dev/install/awman.sh
- **Purpose**: Official one-liner install script referenced in the README (`curl -s https://prettysmart.dev/install/awman.sh | sh`)
- **Date Accessed**: 2026-06-02
- **Access Note**: prettysmart.dev may return HTTP 403 to anonymous WebFetch (Cloudflare bot protection). Fetch via `curl` from a shell to inspect the script content directly.

### awman Templates Directory
- **URL**: https://github.com/prettysmartdev/awman/tree/main/templates
- **Purpose**: Per-agent Dockerfile templates seeded by `awman init` into the repo's `.awman/` directory
- **Date Accessed**: 2026-06-02
- **Key Topics**: Per-agent Dockerfiles (Dockerfile.claude, Dockerfile.codex, …)

## Plugin Information

- **Name**: awman
- **Version**: 0.2.4
- **Description**: awman: parallel AI code agent sessions with container isolation, worktrees, and a REST API
- **Skills**: 1 skill (awman)
- **Renamed from amux**: 2026-06-02 (upstream renamed amux → awman; refreshed to v0.9.1)
- **Refreshed to v0.10.0**: 2026-06-11
- **Refreshed to v0.11.0**: 2026-07-13
