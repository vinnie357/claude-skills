# awman Configuration Reference

Reference for awman configuration files and keys as of v0.9.1.

Source: https://github.com/prettysmartdev/awman/blob/main/docs/07-configuration.md — accessed 2026-06-02.

**Never hand-edit the JSON files.** Use `awman config set` to write values and `awman config show` to inspect the merged effective configuration.

---

## Config files

awman reads one `config.json` per scope. The same filename lives in two directories:

| | Global | Per-repo |
|-|--------|----------|
| **Path** | `$HOME/.awman/config.json` | `$GITROOT/.awman/config.json` |
| **Created by** | manually / `awman config set --global` | `awman init` |
| **Commit to source control?** | No | Yes |
| **Wins on conflict?** | No | Yes — per-repo takes precedence |
| **Scope** | All awman projects on this machine | This Git repository only |

The per-repo `.awman/` directory also holds per-agent Dockerfiles (`Dockerfile.claude`, `Dockerfile.codex`, …) seeded by `awman init`. The Dockerfiles are safe to commit and customize — they define the container each agent runs in.

> **Migrating from amux:** the old split between `aspec/.amux.json` and `.amux/config.json` is gone. awman uses a single per-repo `GITROOT/.awman/config.json`, and config migrates automatically on first run.

If you are unsure which value awman is using, run `awman config show` — it displays the merged effective config.

---

## Global-only keys

Written by `awman config set --global`; apply to all awman projects on this machine.

| Key | Type | Default | Notes |
|-----|------|---------|-------|
| `default_agent` | string | `"claude"` | Per-repo `agent` overrides this for a specific project |
| `runtime` | string | `"docker"` | `"docker"` or the Apple Containers value (macOS 26+). Cannot be set per-repo |
| `api.workDirs` | array of strings | `[]` | Absolute paths the API server may create sessions in |
| `api.alwaysNonInteractive` | boolean | `false` | Auto-injects `--non-interactive` into all API-dispatched commands |
| `api.workers` | integer | `2` | Number of API server worker processes |
| `remote.defaultAddr` | string | unset | Default server address for `awman remote` |
| `remote.defaultAPIKey` | string | unset | API key, sent only when the target matches `remote.defaultAddr` |
| `remote.savedDirs` | array of strings | `[]` | Directories offered in the remote TUI picker |

> `headless.*` keys from amux are renamed: `headless.workDirs` → `api.workDirs`, `headless.alwaysNonInteractive` → `api.alwaysNonInteractive`.

---

## Per-repo keys

Stored in `$GITROOT/.awman/config.json`, created by `awman init`. Commit this file.

| Key | Type | Default | Notes |
|-----|------|---------|-------|
| `agent` | string | (falls back to `default_agent`) | Default agent for all sessions and workflow steps in this repo |
| `base_image` | string | from global / `make build` | Base container image for this repo |
| `workItems.dir` | string | unset | Directory (relative to Git root) where `awman new spec` writes work items |
| `workItems.template` | string | unset | Path to a work item template used by `awman new spec` |

---

## Both-scope keys

| Key | Type | Default | Merge |
|-----|------|---------|-------|
| `terminal_scrollback_lines` | integer | `10000` | Per-repo overrides global |
| `yoloDisallowedTools` | array of strings | `[]` | Tools blocked even in `--yolo` mode |
| `envPassthrough` | array of strings | `[]` | Env var names forwarded into the agent container |
| `overlays.skills` | boolean | `false` | Additive — either scope `true` enables custom-skill mounting |
| `overlays.directories` | array of objects | `[]` | Additive — both scopes contribute mount entries |

### `overlays.directories` object shape

| Field | Type | Description |
|-------|------|-------------|
| `host` | string | Absolute host path (tilde expansion supported) |
| `container` | string | Mount path inside the container |
| `permission` | string | `"ro"` (read-only) or `"rw"` (read-write) |

---

## Environment variables

awman reads several `AWMAN_*` environment variables (override config at runtime):

| Variable | Overrides |
|----------|-----------|
| `AWMAN_OVERLAYS` | Overlay directory/skill spec |
| `AWMAN_REMOTE_ADDR` | `remote.defaultAddr` |
| `AWMAN_API_KEY` | `remote.defaultAPIKey` / API auth key |
| `AWMAN_REMOTE_SESSION` | Target session id for `awman remote` |

> **Migrating from amux:** rename all `AMUX_*` variables to `AWMAN_*`.

---

## Precedence and merge behavior

- **Per-repo wins** on scalar keys (`agent`, `terminal_scrollback_lines`, etc.).
- **Additive merge** for `overlays.skills` and `overlays.directories` — both scopes contribute; neither replaces the other.
- `awman config show` always reflects the merged effective state. Read its output, not the raw files.

---

## Example global config

```json
{
  "default_agent": "claude",
  "runtime": "docker",
  "terminal_scrollback_lines": 10000,
  "yoloDisallowedTools": ["Bash"],
  "envPassthrough": ["ANTHROPIC_API_KEY"],
  "api": {
    "workDirs": ["/home/user/my-project"],
    "workers": 2
  },
  "overlays": {
    "skills": true,
    "directories": [
      { "host": "~/personal-prompts", "container": "/mnt/prompts", "permission": "ro" }
    ]
  }
}
```

## Example per-repo config

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

## Setting values via CLI

```sh
awman config set agent codex                            # per-repo default agent
awman config set --global runtime container             # Apple Containers (macOS 26+)
awman config set --global api.workDirs "/home/user/my-project"
awman config set overlays.skills true                   # enable skills overlay per-repo
awman config show                                       # verify merged effective config
```

---

Back to skill: [SKILL.md](../SKILL.md)
