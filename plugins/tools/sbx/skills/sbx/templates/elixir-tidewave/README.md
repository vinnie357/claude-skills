# Docker-in-sbx: Phoenix + Postgres + Tidewave

A worked example for running a Phoenix app inside a Docker Sandbox with Postgres in a container and Tidewave configured so Claude (running inside the same sandbox) can introspect the live Phoenix app via MCP.

## Topology

```
Host
└── sbx VM (microVM)
    ├── Docker daemon (per-sandbox)
    │   └── postgres:16  (container)
    ├── Claude Code (agent process)
    └── Phoenix app (mix phx.server)
            └── /mcp endpoint (Tidewave plug)
```

Claude and Phoenix share `localhost` inside the VM. Tidewave's MCP endpoint defaults to localhost-only (`allow_remote_access: false`), which fits this same-VM setup.

## Files in this template

| File | Where it goes in your repo |
|------|----------------------------|
| `mise.toml` | repo root — pins Erlang + Elixir for the agent to install in the VM |
| `compose.yaml` | repo root — Postgres service definition |
| `mix.exs.snippet` | merge into your `mix.exs` `deps/0` |
| `config-dev.exs.snippet` | merge into `config/dev.exs` |
| `endpoint.ex.snippet` | merge into `lib/<app>_web/endpoint.ex` |

## Workflow

### 1. Drop the template files into the repo

```bash
cp -r templates/elixir-tidewave/* .
```

Merge the `*.snippet` files into the matching Phoenix project files. Add `.sbx/` to `.gitignore`.

### 2. Start a sandbox with Claude

```bash
sbx run claude --branch auto .
```

`--branch auto` opens a Git worktree under `.sbx/` so all of the agent's writes stay on a reviewable branch.

### 3. Inside the sandbox — bring up Postgres and the Phoenix app

The agent (or you, via `sbx exec -it <name> bash`) runs:

```bash
mise install                       # installs erlang + elixir per mise.toml
mix local.hex --force
mix local.rebar --force
mix deps.get
docker compose up -d postgres
mix ecto.setup                     # mix ecto.create + mix ecto.migrate
mix phx.server
```

### 4. Verify Tidewave MCP is live

From inside the sandbox:

```bash
curl -s http://localhost:4000/mcp/version
```

Claude inside the sandbox uses the MCP endpoint to call Tidewave's introspection tools (`get_ecto_schemas`, `project_eval`, `execute_sql_query`, `get_logs`, etc.). See `/elixir:tidewave` for the tool list.

### 5. (Optional) Reach the Phoenix UI from the host

```bash
sbx ports <sandbox-name> --publish 4000:4000
open http://localhost:4000
```

## Notes

- Postgres data lives in a named volume inside the VM. `sbx rm` wipes the VM filesystem, including that volume; the workspace directory is preserved.
- The agent has its own Docker daemon — `docker ps` inside the sandbox only shows containers running in this VM.
- Tidewave's `allow_remote_access: false` is the right default here because the agent and the Phoenix app share the VM's loopback. Flip it to `true` only if you forward port 4000 to the host AND need MCP access from the host.
