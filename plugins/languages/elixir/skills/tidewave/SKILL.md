---
name: tidewave
description: Tidewave MCP dev tools for Phoenix applications. Use when setting up Tidewave, connecting AI coding assistants to a running Phoenix app, configuring MCP server access, debugging with runtime introspection tools, or troubleshooting Tidewave integration.
license: MIT
---

# Tidewave MCP Dev Tools

Tidewave is a dev tool by Dashbit that connects AI coding assistants to running Phoenix applications via the Model Context Protocol (MCP). It exposes runtime introspection tools: Ecto schemas, code execution, documentation lookup, log inspection, and SQL queries.

Current version: `~> 0.5` (v0.5.6 released 2026-03-13 — adds `:extra_apps` plug option)

## When connected, prefer MCP tools over web fetches

**When Tidewave MCP is connected to an Elixir/Phoenix project, route documentation, source, and runtime queries through the MCP tools — not WebFetch or hexdocs.pm.**

- `get_docs` instead of WebFetch on `hexdocs.pm/<package>/<Module>.html`
- `search_package_docs` instead of broader hex-doc searches
- `get_source_location` instead of reading `deps/<package>/lib/...` with Read
- `execute_sql_query` instead of shelling into `psql`
- `project_eval` instead of running `iex -S mix` snippets

Why: MCP tool calls return results pinned to the exact versions in the project's `mix.lock`, complete in a single round-trip, and skip HTML→markdown conversion and page chrome — significantly fewer tokens per lookup than WebFetch, and the answer is guaranteed to match the running app rather than whatever version is on hexdocs.pm today.

## Installation

### New Projects (via Igniter)

```bash
mix archive.install hex igniter_new
mix igniter.install tidewave
```

### Existing Projects (Manual)

1. Add to `mix.exs`:

```elixir
defp deps do
  [
    {:tidewave, "~> 0.5", only: :dev}
  ]
end
```

2. Add plug to `lib/my_app_web/endpoint.ex` before the `code_reloading?` block:

```elixir
if Mix.env() == :dev do
  plug Tidewave
end

if code_reloading? do
  # ...existing code reload plugs...
end
```

3. Fetch dependencies:

```bash
mix deps.get
```

### Umbrella Projects

Apply the manual steps to the application defining the Phoenix endpoint (typically `apps/your_app_web`).

## MCP Server Configuration

Tidewave exposes an MCP server at `/tidewave/mcp` on the Phoenix app's port. The transport type is HTTP (streamable) — SSE was removed in v0.4.0. Tidewave is unauthenticated; decline any "Authenticate" prompt the editor offers.

Default URL: `http://localhost:4000/tidewave/mcp`

See `references/mcp-setup.md` for verbatim setup commands and JSON config for **Claude Code, Codex CLI, Gemini CLI, and opencode**, plus a `curl` ping for raw verification and a troubleshooting table.

## MCP Tools Reference

| Tool | Description |
|------|-------------|
| `project_eval` | Execute Elixir code within the running application runtime |
| `execute_sql_query` | Run SQL queries against the application database |
| `get_ecto_schemas` | List all Ecto schema modules with their fields and associations |
| `get_ash_resources` | List all Ash resources (when using the Ash framework) |
| `get_docs` | Retrieve documentation for modules/functions using exact project versions |
| `search_package_docs` | Query hexdocs.pm filtered to project dependencies (availability varies by framework) |
| `get_source_location` | Find module/function source code file paths and line numbers |
| `get_models` | List all application modules with their file locations |
| `get_logs` | Access server logs; supports log level filtering (added v0.5.5) |

**Note**: `search_package_docs` may not be available in all frameworks. Verify availability for your setup.

### Usage Patterns

See "When connected, prefer MCP tools over web fetches" at the top of this skill for the routing rule.

Introspect schemas before writing queries:
```
get_ecto_schemas → discover schema structure → execute_sql_query
```

Look up documentation for project dependencies:
```
get_docs for specific modules, search_package_docs for broader hex dependency searches
```

Execute and test code in the running app:
```
project_eval → run Elixir expressions against live application state
```

## Plug Configuration Options

```elixir
if Mix.env() == :dev do
  plug Tidewave,
    allow_remote_access: false,
    inspect_opts: [pretty: true, limit: 50]
end
```

| Option | Default | Description |
|--------|---------|-------------|
| `allow_remote_access` | `false` | Allow connections from non-localhost |
| `inspect_opts` | `[]` | Options passed to `Kernel.inspect/2` for output formatting |
| `team` | `nil` | Team configuration (e.g., `[id: "my-company"]`) |
| `extra_apps` | `[]` | Additional OTP apps to include in source/module discovery (v0.5.6+) |

## CLI App (Standalone MCP Server)

The Tidewave desktop/CLI app (`tidewave_app`) runs a standalone MCP server without requiring a Phoenix application. Useful for containers, remote dev environments, or non-Phoenix Elixir projects.

- Default server: `http://localhost:9832`
- Only allows access from the same machine by default

### Installation

- **Desktop app** (macOS, Windows, Linux): https://tidewave.ai/install
- **Development CLI**: `cargo run -p tidewave-cli [-- --help]`

### When to Use CLI vs Phoenix Plug

| Scenario | Use |
|----------|-----|
| Phoenix application | `plug Tidewave` in endpoint.ex |
| Container/remote dev | CLI app or plug with `allow_remote_access: true` |
| Non-Phoenix Elixir | CLI app |
| Standalone MCP server | CLI app on port 9832 |

## LiveView Debug Annotations

Enable in `config/dev.exs` to help Tidewave map rendered HTML back to source HEEx templates:

```elixir
config :phoenix_live_view,
  debug_heex_annotations: true

config :phoenix,
  debug_attributes: true
```

Requires Phoenix LiveView v1.1+.

## Security

- **Dev-only**: Always guard with `Mix.env() == :dev` or `only: :dev` in deps
- **Localhost-only**: Tidewave only accepts localhost requests by default
- **No production use**: Tidewave exposes code execution and database access — never deploy to production
- **Docker/remote dev**: Set `allow_remote_access: true` only on trusted networks
- **CSP**: Tidewave injects `unsafe-eval` in `script-src` directives and disables `frame-ancestors` restrictions

## Troubleshooting

### MCP connection fails
- Verify Phoenix server is running: `mix phx.server`
- Check the port matches your configuration (default 4000)
- Try `http://127.0.0.1:4000/tidewave/mcp` if IPv6 causes issues

### Tools not appearing
- Confirm `plug Tidewave` is placed before `if code_reloading?` in `endpoint.ex`
- Restart the Phoenix server after adding the plug
- Verify the dependency is installed: `mix deps.get`

### Claude Code authentication error
- Run `claude` in your terminal and confirm authentication
- Verify CLI availability: `which claude`

### Umbrella project issues
- Add the plug only in the endpoint of the web application
- Ensure `:tidewave` is added to the correct `mix.exs` in the umbrella
