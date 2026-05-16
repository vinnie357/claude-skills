# amux Configuration Reference

Reference for all amux configuration files and keys as of v0.8.0.

Source: https://github.com/prettysmartdev/amux/blob/main/docs/07-configuration.md — accessed 2026-05-16.

**Never hand-edit the JSON files.** Use `amux config set` to write values and `amux config show` to inspect the merged effective configuration.

---

## Table of Contents

- [Two config files at a glance](#two-config-files-at-a-glance)
- [Per-repo `.amux/` directory vs `aspec/.amux.json`](#per-repo-amux-directory-vs-aspectamuxjson)
- [Global config: `$HOME/.amux/config.json`](#global-config-homeamuxconfigjson)
- [Per-repo config: `$GITROOT/aspec/.amux.json`](#per-repo-config-gitrootaspectamuxjson)
- [Precedence and merge behavior](#precedence-and-merge-behavior)
- [Full key reference](#full-key-reference)
- [Example files](#example-files)

---

## Two config files at a glance

| | Global | Per-repo |
|-|--------|----------|
| **Path** | `$HOME/.amux/config.json` | `$GITROOT/aspec/.amux.json` |
| **Created by** | manually / `amux config set --global` | `amux init` |
| **Commit to source control?** | No | Yes |
| **Wins on conflict?** | No | Yes — per-repo takes precedence |
| **Scope** | All amux projects on this machine | This Git repository only |

---

## Per-repo `.amux/` directory vs `aspec/.amux.json`

This is the most common source of confusion when working with amux.

**`$GITROOT/aspec/.amux.json`** — the canonical per-repo configuration file.
- Created by `amux init`.
- Commit this file to source control so all contributors share the same agent, workItems, and overlay settings.
- This is what `amux config show` reads when resolving per-repo config.
- Read and written by `amux config get` and `amux config set` (without `--global`).

**`$GITROOT/.amux/`** — a directory of per-agent Dockerfiles and a local-only config file.
- Also populated by `amux init`, seeded from upstream Dockerfile templates.
- Contains: `Dockerfile.claude`, `Dockerfile.codex`, `Dockerfile.copilot`, `Dockerfile.crush`, `Dockerfile.gemini`, `Dockerfile.maki`, `Dockerfile.opencode`.
- Also contains `.amux/config.json` — a **local-only** override layer that is NOT the canonical per-repo config. Do not commit this file.
- The Dockerfiles are safe to commit and customize (they define the container your agent runs in). The `.amux/config.json` inside this directory is a local overlay that overrides `aspec/.amux.json` for your machine only.

**In practice:** if you have two JSON files and are unsure which one amux is reading, run `amux config show`. It displays the merged effective config and the source that contributed each key.

| File | Commit? | Purpose |
|------|---------|---------|
| `aspec/.amux.json` | Yes | Canonical per-repo config — shared with all contributors |
| `.amux/config.json` | No | Local per-machine overrides (add to `.gitignore`) |
| `.amux/Dockerfile.*` | Yes | Per-agent container definitions |

---

## Global config: `$HOME/.amux/config.json`

Applies to all amux projects on this machine. Written by `amux config set --global`.

### Key reference

| Key | Type | Default | Scope note |
|-----|------|---------|-----------|
| `default_agent` | string | `"claude"` | Global only. Per-repo `agent` key overrides this for a specific project. |
| `runtime` | string | `"docker"` | Global only. Accepts `"docker"` or `"container"` (Apple Containers on macOS 26+). Cannot be set per-repo. |
| `terminal_scrollback_lines` | integer | `10000` | Both scopes. Per-repo value overrides global if set. |
| `yoloDisallowedTools` | array of strings | `[]` | Both scopes. Tools that `--yolo` mode is not allowed to invoke without confirmation (merged additively across scopes — amux v0.8.0 docs do not confirm additive vs replace; verify with `amux config show` after setting). |
| `envPassthrough` | array of strings | `[]` | Both scopes. Environment variable names passed into the agent container from the host (merged additively). |
| `overlays.skills` | boolean | `false` | Both scopes (additive). When `true`, mounts custom skills (created via `amux new skill`) into the agent container. |
| `overlays.directories` | array of objects | `[]` | Both scopes (additive). Additional host directories to mount read-only (or read-write) into the container. |
| `headless.workDirs` | array of strings | `[]` | Global only. Absolute paths the headless server is allowed to create sessions in. |
| `headless.alwaysNonInteractive` | boolean | `false` | Global only. Forces all commands submitted via the headless API to run non-interactively. |
| `remote.defaultAddr` | string | unset | Global only. Default `host:port` for `amux remote` commands. |
| `remote.defaultAPIKey` | string | unset | Global only. Default API key for `amux remote` commands. |
| `remote.savedDirs` | array of strings | `[]` | Global only. Directories saved by `amux remote session start` for quick reuse. |

Source: https://github.com/prettysmartdev/amux/blob/main/docs/07-configuration.md (section: global config keys)

### `overlays.directories` object shape

Each entry in the array is a JSON object:

| Field | Type | Description |
|-------|------|-------------|
| `host` | string | Absolute path on the host machine (tilde expansion supported) |
| `container` | string | Absolute path inside the container where the directory is mounted |
| `permission` | string | `"ro"` (read-only) or `"rw"` (read-write) |

---

## Per-repo config: `$GITROOT/aspec/.amux.json`

Applies to one Git repository. Created by `amux init`; read by `amux config get` / `amux config show`. Commit this file.

### Key reference

| Key | Type | Default | Scope note |
|-----|------|---------|-----------|
| `agent` | string | (falls back to `default_agent`) | Per-repo only. Sets the default agent for all sessions and workflow steps in this repository. |
| `terminal_scrollback_lines` | integer | `10000` | Both scopes. Per-repo value overrides global. |
| `yoloDisallowedTools` | array of strings | `[]` | Both scopes. Tools blocked in `--yolo` mode. |
| `envPassthrough` | array of strings | `[]` | Both scopes. Env vars forwarded into the container. |
| `overlays.skills` | boolean | `false` | Both scopes (additive). Enable custom skills mounting. |
| `overlays.directories` | array of objects | `[]` | Both scopes (additive). Additional host→container directory mounts. |
| `workItems.dir` | string | unset | Per-repo only. Directory (relative to Git root) where `amux new spec` writes work item files. |
| `workItems.template` | string | unset | Per-repo only. Path to a work item template file used by `amux new spec`. |

Source: https://github.com/prettysmartdev/amux/blob/main/docs/07-configuration.md (section: per-repo config keys)

---

## Precedence and merge behavior

When the same key appears in both config files:

- **Per-repo wins** on scalar keys (`agent`, `runtime`, `terminal_scrollback_lines`, `headless.*`, etc.).
- **Additive merge** for `overlays.skills` and `overlays.directories`: both files contribute their entries; neither replaces the other.
- `yoloDisallowedTools` and `envPassthrough` — the research report does not explicitly confirm additive vs replace behavior for these array keys. Run `amux config show` after setting both scopes to verify the effective merged value before relying on it.

`amux config show` always reflects the merged effective state. Read its output, not the raw files.

---

## Full key reference

Consolidated table of all documented keys across both scopes.

| Key | Type | Default | Global? | Per-repo? | Merge |
|-----|------|---------|---------|-----------|-------|
| `default_agent` | string | `"claude"` | Yes | No | N/A |
| `runtime` | string | `"docker"` | Yes | No | N/A |
| `terminal_scrollback_lines` | integer | `10000` | Yes | Yes | Per-repo overrides global |
| `yoloDisallowedTools` | array | `[]` | Yes | Yes | Verify with `config show` |
| `envPassthrough` | array | `[]` | Yes | Yes | Verify with `config show` |
| `overlays.skills` | boolean | `false` | Yes | Yes | Additive (either `true` enables) |
| `overlays.directories` | array | `[]` | Yes | Yes | Additive (both contribute entries) |
| `headless.workDirs` | array | `[]` | Yes | No | N/A |
| `headless.alwaysNonInteractive` | boolean | `false` | Yes | No | N/A |
| `remote.defaultAddr` | string | unset | Yes | No | N/A |
| `remote.defaultAPIKey` | string | unset | Yes | No | N/A |
| `remote.savedDirs` | array | `[]` | Yes | No | N/A |
| `agent` | string | (default_agent) | No | Yes | N/A |
| `workItems.dir` | string | unset | No | Yes | N/A |
| `workItems.template` | string | unset | No | Yes | N/A |

Source for all keys: https://github.com/prettysmartdev/amux/blob/main/docs/07-configuration.md — accessed 2026-05-16.

---

## Example files

### Global config example

Source: verbatim from amux docs, accessed 2026-05-16.

```json
{
  "default_agent": "claude",
  "terminal_scrollback_lines": 10000,
  "runtime": "docker",
  "yoloDisallowedTools": ["Bash"],
  "envPassthrough": ["ANTHROPIC_API_KEY"],
  "overlays": {
    "skills": true,
    "directories": [
      { "host": "~/personal-prompts", "container": "/mnt/prompts", "permission": "ro" }
    ]
  }
}
```

### Per-repo config example

Source: verbatim from amux docs, accessed 2026-05-16.

```json
{
  "agent": "claude",
  "terminal_scrollback_lines": 10000,
  "yoloDisallowedTools": ["Bash", "computer"],
  "envPassthrough": ["ANTHROPIC_API_KEY"],
  "overlays": {
    "skills": true,
    "directories": [
      { "host": "/data/fixtures", "container": "/mnt/fixtures", "permission": "ro" }
    ]
  },
  "workItems": {
    "dir": "docs/work-items",
    "template": "docs/work-items/0000-template.md"
  }
}
```

### Setting config values via CLI

```sh
# Set the per-repo default agent
amux config set agent codex

# Set the global runtime to Apple Containers (macOS 26+ only)
amux config set --global runtime container

# Add an allowlisted workdir for the headless server
amux config set --global headless.workDirs /home/user/my-project

# Enable skills overlay per-repo
amux config set overlays.skills true

# Verify merged effective config
amux config show
```

---

Back to skill: [SKILL.md](../SKILL.md)
