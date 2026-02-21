# Tidewave MCP Dev Tools for Phoenix

Tidewave is a dev tool by Dashbit that connects AI coding assistants to running Phoenix applications via the Model Context Protocol (MCP). It exposes runtime introspection tools that make AI assistants aware of live application state — Ecto schemas, code execution, documentation lookup, log inspection, and SQL queries.

## Installation

### New Projects (via Igniter)

```bash
mix archive.install hex igniter_new
mix igniter.install tidewave
```

### Existing Projects (Manual)

1. Add the dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:tidewave, "~> 0.5", only: :dev}
  ]
end
```

2. Add the plug to `lib/my_app_web/endpoint.ex` before the `code_reloading?` block:

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

Apply manual steps to the application defining your Phoenix endpoint (typically `apps/your_app_web`).

### Non-Phoenix Elixir Projects

Combine Bandit with Tidewave using a mix alias for standalone MCP server functionality.

## MCP Server Configuration

Tidewave exposes an MCP server at `/tidewave/mcp` on your Phoenix app's port. The transport type is HTTP (streamable).

Default URL: `http://localhost:4000/tidewave/mcp`

### Claude Code Setup

Add the Tidewave MCP server to Claude Code:

```bash
claude mcp add --transport http tidewave http://localhost:4000/tidewave/mcp
```

Replace `4000` with your application's port if different.

Add rules to `CLAUDE.md` to encourage MCP tool usage:

```markdown
Always use Tidewave's tools for evaluating code, querying the database, etc.
Use `get_docs` to access documentation and the `get_source_location` tool
to find module/function definitions.
```

### Other Editors

For other MCP-compatible editors, point to the same HTTP endpoint:

| Editor | Config File | URL Key |
|--------|-------------|---------|
| Cursor | `.cursor/mcp.json` | `mcpServers.tidewave.url` |
| VS Code | `.vscode/mcp.json` | `servers.tidewave.url` |
| Zed | Zed `settings.json` | `context_servers.tidewave.settings.url` |

All use the same URL: `http://localhost:4000/tidewave/mcp`

## MCP Tools Reference

| Tool | Description |
|------|-------------|
| `project_eval` | Execute Elixir code within the running application runtime |
| `execute_sql_query` | Run SQL queries against the application database |
| `get_ecto_schemas` | List all Ecto schema modules with their fields and associations |
| `get_ash_resources` | List all Ash resources (when using the Ash framework) |
| `get_docs` | Retrieve documentation for modules/functions using exact project versions |
| `search_package_docs` | Query hexdocs.pm filtered to project dependencies |
| `get_source_location` | Find module/function source code file paths and line numbers |
| `get_models` | List all application modules with their file locations |
| `get_logs` | Access server logs written during development |

### Tool Usage Patterns

**Introspect Ecto schemas before writing queries:**
```
Use get_ecto_schemas to discover available schemas, then execute_sql_query to run queries.
```

**Look up documentation for project dependencies:**
```
Use get_docs for specific modules, search_package_docs for broader searches across hex dependencies.
```

**Execute and test code in the running app:**
```
Use project_eval to run Elixir expressions against the live application state.
```

## Plug Configuration Options

Configure via plug options in `endpoint.ex`:

```elixir
if Mix.env() == :dev do
  plug Tidewave,
    allow_remote_access: false,
    inspect_opts: [pretty: true, limit: 50]
end
```

| Option | Default | Description |
|--------|---------|-------------|
| `allow_remote_access` | `false` | Allow connections from non-localhost. Keep `false` in development. |
| `inspect_opts` | `[]` | Options passed to `Kernel.inspect/2` for formatting tool output |
| `team` | `nil` | Team configuration (e.g., `[id: "my-company"]`) |

## LiveView Debug Annotations

For LiveView-heavy applications, enable debug annotations in `config/dev.exs`:

```elixir
config :phoenix_live_view,
  debug_heex_annotations: true

config :phoenix,
  debug_attributes: true
```

These annotations help Tidewave (and other dev tools) map rendered HTML back to source HEEx templates and components. Requires Phoenix LiveView v1.1+.

## Security Considerations

- **Dev-only**: Always guard with `Mix.env() == :dev` or `only: :dev` in deps
- **Localhost-only**: Tidewave only accepts localhost requests by default, even if the server listens on other interfaces
- **No production use**: Tidewave exposes code execution and database access — never deploy to production
- **Docker/remote dev**: If developing in containers, configure `allow_remote_access: true` only when the network is trusted
- **Content Security Policy**: Tidewave injects `unsafe-eval` in `script-src` directives for browser testing and disables `frame-ancestors` restrictions

## Troubleshooting

### MCP connection fails

- Verify the Phoenix server is running: `mix phx.server`
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

- Add the plug only in the endpoint of the web application, not in other umbrella apps
- Ensure `:tidewave` dependency is added to the correct `mix.exs` in the umbrella
