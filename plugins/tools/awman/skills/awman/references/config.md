# awman Configuration Reference

Reference for awman configuration files and keys as of v0.10.0.

Source: https://github.com/prettysmartdev/awman/blob/main/docs/07-configuration.md and docs/08-overlays.md — accessed 2026-06-11.

**Never hand-edit the JSON files.** Use `awman config set` to write values and `awman config show` to inspect the merged effective configuration. Keys marked "edit file" below are the exception — they are not settable via the CLI.

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

The per-repo `.awman/` directory also holds per-agent Dockerfiles (`Dockerfile.claude`, `Dockerfile.codex`, …) seeded by `awman init`. The Dockerfiles are safe to commit and customize — they define the container each agent runs in. The project base image path is configurable via the per-repo `dockerfile` key (default `Dockerfile.dev`).

XDG base-directory environment variables are honored as of 0.10.0.

> **Migrating from amux:** the old split between `aspec/.amux.json` and `.amux/config.json` is gone. awman uses a single per-repo `GITROOT/.awman/config.json`, and config migrates automatically on first run. No migration is required from 0.9.1 to 0.10.0.

If you are unsure which value awman is using, run `awman config show` — it displays the merged effective config. As of 0.10.0, `awman config` works even when the configured runtime is not installed.

---

## Global-only keys

Stored in `$HOME/.awman/config.json`; apply to all awman projects on this machine.

| Key | Type | Default | Settable via CLI |
|-----|------|---------|------------------|
| `default_agent` | string | unset | Yes |
| `runtime` | string | `"docker"` | Yes — `docker`, `apple-containers`, or `docker-sbx-experimental` |
| `workers` | integer | `2` | No (edit file) |
| `api.workDirs` | array of strings | `[]` | Yes |
| `api.alwaysNonInteractive` | boolean | `false` | No (edit file) |
| `api.port` | integer | `9876` | Yes |
| `auto_agent_auth_accepted` | boolean | unset | No (managed by awman) |

> `headless.*` keys from amux are renamed: `headless.workDirs` → `api.workDirs`, `headless.alwaysNonInteractive` → `api.alwaysNonInteractive`.

### Runtime values

| Value | Platforms | Requirements |
|-------|-----------|--------------|
| `docker` (default) | Linux, macOS, Windows | Docker daemon |
| `apple-containers` | macOS 26+ | native `container` CLI |
| `docker-sbx-experimental` | macOS arm64, Windows x86_64 | `sbx` CLI (`brew install docker/tap/sbx`) + `sbx login` |

Each runtime maintains separate state; switching does not delete other runtimes' data. Run `awman ready` after switching. `docker-sbx-experimental` does not honor directory, skill, or context overlays; networking is proxy-only; sandboxes persist between sessions.

---

## Per-repo-only keys

Stored in `$GITROOT/.awman/config.json`, created by `awman init`. Commit this file.

| Key | Type | Default | Settable via CLI |
|-----|------|---------|------------------|
| `workItems.dir` | string | `aspec/work-items` | Yes |
| `workItems.template` | string | `<workItems.dir>/0000-template.md` | Yes |
| `dockerfile` | string | `Dockerfile.dev` | No (edit file) |

---

## Both-scope keys

Per-repo overrides global on scalar conflicts; `overlays` merges additively.

| Key | Type | Default | Settable via CLI |
|-----|------|---------|------------------|
| `agent` | string | falls back to `default_agent` | Yes |
| `terminal_scrollback_lines` | integer | `10000` | Yes |
| `yoloDisallowedTools` | array of strings | `[]` | Yes |
| `overlays` | array of overlay specs | `[]` | Yes |
| `agentStuckTimeout` | integer | `30` (seconds) | Yes |
| `baseImage` | string | unset | No (edit file) |
| `remote.defaultAddr` | string | unset | Yes |
| `remote.defaultAPIKey` | string | unset | Yes |
| `remote.savedDirs` | array of strings | `[]` | No (edit file) |

---

## Overlays

> **`envPassthrough` removed in 0.10.0.** The config key `envPassthrough` is gone; querying it via `awman config get envPassthrough` returns a removal notice. Express env forwarding as `env(VAR)` entries in the `overlays` array.
>
> **Migration:** replace `"envPassthrough": ["MY_VAR", "OTHER_VAR"]` in your config with:
> ```json
> "overlays": ["env(MY_VAR)", "env(OTHER_VAR)"]
> ```
> Or use the CLI flag per invocation: `--overlay "env(MY_VAR)"`. The `env()` overlay is silently omitted if the named variable is not set on the host.

Overlays grant agent containers access to host resources. Each entry in the `overlays` array is a spec string:

| Spec | Effect |
|------|--------|
| `dir(HOST:CONTAINER[:ro\|rw])` | Mount a host directory; `~/` expands on both sides; default read-only |
| `ssh()` | Mount `~/.ssh` read-only (always read-only; for Git auth) |
| `env(VAR)` | Forward one env var into the container; one call per var; unset vars skip silently; values masked as `***` in logs |
| `skill(*)` | Mount all skills from `~/.awman/skills/` |
| `skill(NAME)` | Mount one named skill; missing names error before container launch |
| `context(SCOPE[:ro])` | Durable context dir + automatic system-prompt injection (0.10.0) |

### Context overlays (0.10.0)

`context()` combines a **directory mount** (persistent files on the host) with **system prompt injection** (agent-specific delivery of context instructions). Default permission is `rw` so agents accumulate knowledge across sessions; pass `:ro` to lock a scope (e.g. `context(repo:ro)`).

| Scope | Location |
|-------|----------|
| `global` | `~/.awman/context/global/` |
| `repo` | `~/.awman/context/repo/{owner}/{repo}/` (maintained automatically) |
| `workflow` | `~/.awman/context/workflow/` (auto-created per invocation) |

Agents without native system-prompt injection still get the directory mount; reference it manually in prompts.

### Overlay sources and merge order

1. Global config `"overlays": [...]`
2. Per-repo config `"overlays": [...]`
3. `AWMAN_OVERLAYS="dir(...),env(...)"` environment variable
4. CLI: `--overlay "ssh()" --overlay "env(TOKEN)"` (repeatable)
5. Workflow `overlays = [...]` — workflow-level (all steps) or per-step

All sources combine **additively**. On a host-path conflict, the higher-priority source wins, but `:ro` always overrides `:rw`. Setup/teardown workflow steps support `dir()`, `ssh()`, and `env()` — not `skill()`.

---

## Environment variables

awman reads several `AWMAN_*` environment variables (override config at runtime):

| Variable | Overrides |
|----------|-----------|
| `AWMAN_OVERLAYS` | Overlay spec list (comma-separated) |
| `AWMAN_REMOTE_ADDR` | `remote.defaultAddr` |
| `AWMAN_API_KEY` | `remote.defaultAPIKey` / API auth key |
| `AWMAN_REMOTE_SESSION` | Target session id for `awman remote` |

> **Migrating from amux:** rename all `AMUX_*` variables to `AWMAN_*`.

---

## Precedence and merge behavior

- **Per-repo wins** on scalar keys (`agent`, `terminal_scrollback_lines`, etc.).
- **`overlays` merges additively** across all sources; other list fields **replace** (repo replaces global entirely).
- `awman config show` always reflects the merged effective state. Read its output, not the raw files.

---

## Example global config

```json
{
  "default_agent": "claude",
  "runtime": "docker",
  "terminal_scrollback_lines": 10000,
  "yoloDisallowedTools": ["Bash"],
  "api": {
    "workDirs": ["/home/user/my-project"],
    "port": 9876
  },
  "overlays": [
    "env(ANTHROPIC_API_KEY)",
    "env(ANTHROPIC_BASE_URL)",
    "context(global)"
  ]
}
```

`env(ANTHROPIC_BASE_URL)` forwards a custom API endpoint (e.g. a local provider) into every agent container. If the variable is not set on the host, awman silently omits it — no error. Replace the old `envPassthrough` array with individual `env()` entries like this.

## Example per-repo config

```json
{
  "agent": "claude",
  "terminal_scrollback_lines": 10000,
  "yoloDisallowedTools": ["Bash", "computer"],
  "overlays": ["ssh()", "dir(/data/fixtures:/mnt/fixtures:ro)", "context(repo)"],
  "workItems": {
    "dir": "docs/work-items",
    "template": "docs/work-items/0000-template.md"
  }
}
```

## Setting values via CLI

```sh
awman config set agent codex                                  # per-repo default agent
awman config set --global runtime apple-containers            # Apple Containers (macOS 26+)
awman config set --global runtime docker-sbx-experimental     # Docker Sandboxes microVMs
awman config set --global api.workDirs "/home/user/my-project"
awman config set overlays "env(ANTHROPIC_BASE_URL)"           # add one overlay (per-repo)
awman config show                                             # verify merged effective config
```

---

Back to skill: [SKILL.md](../SKILL.md)
