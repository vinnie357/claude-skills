# amux Plugin Sources

This file documents the sources used to create the amux plugin skill.

## amux Skill

### amux Repository
- **URL**: https://github.com/prettysmartdev/amux
- **Purpose**: Primary source for amux overview, tagline, feature list, supported agents, install methods, and runtime requirements
- **Date Accessed**: 2026-05-16
- **Key Topics**: CLI/TUI overview, parallel agent sessions, container isolation, worktree model, agent list (claude, codex, opencode, maki, gemini, copilot, crush, cline), license (Apache-2.0)

### amux README
- **URL**: https://github.com/prettysmartdev/amux/blob/main/README.md
- **Purpose**: Top-level reference for tagline, command summary table, install instructions, and representative examples
- **Date Accessed**: 2026-05-16
- **Key Topics**: Tagline verbatim ("Run and coordinate AI code agents from your terminal. Parallel sessions, multi-step workflows, full container isolation."), top-level command tree, curl + mise install paths, pre-built binary assets (linux/macos/windows × amd64/arm64)

### amux docs/ Directory
- **URL**: https://github.com/prettysmartdev/amux/tree/main/docs
- **Purpose**: Parent tree for all numbered documentation pages; individual pages cited below
- **Date Accessed**: 2026-05-16
- **Individual Pages**:
  - `docs/contents.md` — https://github.com/prettysmartdev/amux/blob/main/docs/contents.md — documentation index listing all numbered pages
  - `docs/00-getting-started.md` — https://github.com/prettysmartdev/amux/blob/main/docs/00-getting-started.md — prerequisites, `amux init`, `amux ready`, first session walkthrough
  - `docs/01-using-the-tui.md` — https://github.com/prettysmartdev/amux/blob/main/docs/01-using-the-tui.md — TUI keybindings (Ctrl+T new tab, Ctrl+A switch, Ctrl+D detach, Ctrl+Y copy), scrollback configuration
  - `docs/02-agent-sessions.md` — https://github.com/prettysmartdev/amux/blob/main/docs/02-agent-sessions.md — session lifecycle, agent selection precedence, Dockerfile architecture per agent
  - `docs/03-security-and-isolation.md` — https://github.com/prettysmartdev/amux/blob/main/docs/03-security-and-isolation.md — container isolation model, worktree opt-in, credentials as masked env vars, --rm lifecycle, mount semantics
  - `docs/04-workflows.md` — https://github.com/prettysmartdev/amux/blob/main/docs/04-workflows.md — workflow authoring in Markdown/TOML/YAML, step fields, template variables ({{work_item_number}}, {{work_item_content}}, {{work_item_section:[Name]}}), field ordering rules
  - `docs/05-yolo-mode.md` — https://github.com/prettysmartdev/amux/blob/main/docs/05-yolo-mode.md — --yolo flag semantics, 60-second auto-advance, --auto selective permission skipping, implicit worktree creation
  - `docs/07-configuration.md` — https://github.com/prettysmartdev/amux/blob/main/docs/07-configuration.md — global config (~/.amux/config.json) and per-repo config (GITROOT/aspec/.amux.json), per-key table (types, defaults, scopes), overlays.skills and overlays.directories additive merge, .amux/ Dockerfile directory
  - `docs/08-headless-mode.md` — https://github.com/prettysmartdev/amux/blob/main/docs/08-headless-mode.md — REST API reference (all endpoints, bearer auth, one-command-per-session constraint, port 9876, allowlisted workdirs), output log path
  - `docs/09-remote-mode.md` — https://github.com/prettysmartdev/amux/blob/main/docs/09-remote-mode.md — `amux remote` CLI wrapper over the headless REST API, remote.defaultAddr and remote.defaultAPIKey config keys
  - `docs/10-architecture-overview.md` — https://github.com/prettysmartdev/amux/blob/main/docs/10-architecture-overview.md — high-level architectural summary for end users
  - `docs/architecture.md` — https://github.com/prettysmartdev/amux/blob/main/docs/architecture.md — detailed four-layer architecture (data → engine → command → frontend) introduced in v0.8.0

### amux Releases Page
- **URL**: https://github.com/prettysmartdev/amux/releases
- **Purpose**: Release history, cadence, and binary asset naming (amux-linux-amd64, amux-linux-arm64, amux-macos-amd64, amux-macos-arm64, amux-windows-amd64.exe)
- **Date Accessed**: 2026-05-16
- **Key Topics**: Weekly release cadence (~weekly through April 2026), pre-1.0 minor-bump may carry breaking changes, binary asset names per platform

### amux Release v0.8.0
- **URL**: https://github.com/prettysmartdev/amux/releases/tag/v0.8.0
- **Purpose**: Specific release notes for the version pinned in `skills/amux/templates/0.8.0/mise.toml`
- **Date Accessed**: 2026-05-16
- **Release Date**: 2026-04-12
- **Key Topics**: Internal four-layer architecture refactor, skills overlay feature (overlays.skills config key), CLI/config/state unchanged from v0.7.x (no migration required)

### amux Install Script
- **URL**: https://prettysmart.dev/install/amux.sh
- **Purpose**: Official one-liner install script referenced in the README (`curl -s https://prettysmart.dev/install/amux.sh | sh`)
- **Date Accessed**: 2026-05-16
- **Access Note**: **Returned HTTP 403 to anonymous WebFetch on 2026-05-16.** The next maintainer must fetch this URL directly via `curl` from a shell (not an automated agent WebFetch) to inspect the install script content. The prettysmart.dev marketing site also returned 403 to anonymous WebFetch on the same date. Do not assume the script is unavailable — the 403 is consistent with Cloudflare bot protection on anonymous requests.

### amux License
- **URL**: https://github.com/prettysmartdev/amux/blob/main/LICENSE
- **Purpose**: Confirm upstream license for skill frontmatter
- **Date Accessed**: 2026-05-16
- **Key Topics**: Apache-2.0 license (skill frontmatter declares `license: Apache-2.0` to match upstream)

### amux Templates Directory
- **URL**: https://github.com/prettysmartdev/amux/tree/main/templates
- **Purpose**: Per-agent Dockerfile templates seeded by `amux init` into the repo's .amux/ directory
- **Date Accessed**: 2026-05-16
- **Key Topics**: Dockerfile.claude, Dockerfile.codex, Dockerfile.copilot, Dockerfile.crush, Dockerfile.gemini, Dockerfile.maki, Dockerfile.opencode, Dockerfile.project

## Plugin Information

- **Name**: amux
- **Version**: 0.1.0
- **Description**: amux: parallel AI code agent sessions with container isolation, worktrees, and a headless REST API
- **Skills**: 1 skill (amux)
- **Created**: 2026-05-16
