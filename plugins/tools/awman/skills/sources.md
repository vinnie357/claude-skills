# awman Plugin Sources

This file documents the sources used to create and maintain the awman plugin skill.

awman was previously named **amux** (repo `prettysmartdev/amux`). The skill was renamed and refreshed to awman v0.9.1 on 2026-06-02; all sources below point at the current `prettysmartdev/awman` repository.

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
- **Date Accessed**: 2026-06-02
- **Individual Pages**:
  - `docs/00-getting-started.md` — install methods (awman.sh, mise github backend, make install / Rust 1.94+), `awman init`/`awman ready`, supported agents, runtimes
  - `docs/01-using-the-tui.md` — TUI usage and keybindings
  - `docs/02-agent-sessions.md` — `awman chat` / `awman exec` flags (`--agent`, `--model`, `--plan`, `--auto`, `--yolo`, `--worktree`, `--non-interactive`, `--overlay`, `--allow-docker`, `--mount-ssh`), session lifecycle
  - `docs/03-security-and-isolation.md` — container isolation, worktree opt-in, mount semantics
  - `docs/04-workflows.md` — workflow authoring in TOML/YAML (Markdown removed), step fields (`name`, `prompt`, `depends_on`, `agent`, `model`), template variables
  - `docs/05-yolo-mode.md` — `--yolo` semantics, `--auto` selective permission skipping
  - `docs/06-headless-mode.md` — automatic non-interactive (TTY-detection) behavior; relationship to API mode
  - `docs/07-configuration.md` — global (`~/.awman/config.json`) and per-repo (`GITROOT/.awman/config.json`) config, per-key table, `api.*` keys, `overlays.*` additive merge, `AWMAN_*` env vars
  - `docs/08-overlays.md` — skills and directory overlays
  - `docs/09-api-mode.md` — REST API server (`awman api start/status/logs/kill`), endpoints, bearer auth, `x-awman-session` header, `api.workDirs` allowlist, FIFO queue, HTTPS self-signed default
  - `docs/10-remote-mode.md` — `awman remote run/session`, `remote.*` config keys, `AWMAN_REMOTE_ADDR` / `AWMAN_API_KEY` / `AWMAN_REMOTE_SESSION`
  - `docs/11-architecture-overview.md` / `docs/architecture.md` — architectural summary

### awman Releases
- **URL**: https://github.com/prettysmartdev/awman/releases
- **Purpose**: Release history and cadence; pinned-version reference
- **Date Accessed**: 2026-06-02
- **Key Topics**: v0.9.1 released 2026-05-28; pre-1.0 minor bumps may carry breaking changes

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
- **Version**: 0.2.0
- **Description**: awman: parallel AI code agent sessions with container isolation, worktrees, and a REST API
- **Skills**: 1 skill (awman)
- **Renamed from amux**: 2026-06-02 (upstream renamed amux → awman; refreshed to v0.9.1)
