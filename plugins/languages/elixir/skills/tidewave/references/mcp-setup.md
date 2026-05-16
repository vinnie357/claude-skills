# Tidewave MCP — Editor Setup

Why connect: once Tidewave MCP is wired, the assistant calls `get_docs` /
`search_package_docs` / `get_source_location` directly against the running
Phoenix app — version-pinned to `mix.lock`, single round-trip, no `hexdocs.pm`
WebFetch and no `deps/` file-reading. Same applies to `execute_sql_query` and
`project_eval`. Token savings are largest on Elixir-heavy work.

Default URL: `http://localhost:$PORT/tidewave/mcp` — replace `$PORT` with the
Phoenix app port (commonly `4000`).

Transport: HTTP streamable. **Do not** select SSE — Tidewave dropped SSE
support in v0.4.0.

No authentication: Tidewave is dev-only and localhost-only. Decline any
"Authenticate" prompt — Tidewave implements no auth endpoints.

## Claude Code

CLI:

```bash
claude mcp add --transport http tidewave http://localhost:4000/tidewave/mcp
```

Verify: launch `claude`, run `/mcp`, look for `✔ connected` next to
`tidewave`. If the dialog offers an "Authenticate" option, decline — choosing
it surfaces an auth error because Tidewave has no auth endpoints.

Encourage MCP tool use by adding to project `CLAUDE.md`:

```markdown
Always prefer Tidewave's MCP tools for Elixir lookups in this project:
- `get_docs` over WebFetch on hexdocs.pm
- `search_package_docs` over broader hex searches
- `get_source_location` over reading `deps/` source directly
- `execute_sql_query` and `project_eval` over shelling into `psql` / `iex`
```

## Codex CLI

CLI:

```bash
codex mcp add tidewave --url http://localhost:4000/tidewave/mcp
```

Verify:

```bash
codex mcp list           # confirm tidewave appears
codex                    # then /mcp inside the session
```

## Gemini CLI

Gemini CLI has no Tidewave-specific docs upstream, but supports standard
streamable HTTP MCP servers via `httpUrl`.

Config file (user-scope `~/.gemini/settings.json` or project-scope
`.gemini/settings.json`):

```json
{
  "mcpServers": {
    "tidewave": {
      "httpUrl": "http://localhost:4000/tidewave/mcp"
    }
  }
}
```

The field is `httpUrl` (streamable HTTP), **not** `url` (SSE) — Tidewave only
speaks streamable HTTP.

CLI alternative:

```bash
gemini mcp add --transport http tidewave http://localhost:4000/tidewave/mcp
```

## opencode

Config file (global `~/.config/opencode/opencode.json` or project
`./opencode.json`):

```json
{
  "mcp": {
    "tidewave": {
      "type": "remote",
      "url": "http://localhost:4000/tidewave/mcp",
      "enabled": true
    }
  }
}
```

## Verification (all editors)

Raw MCP ping — answers `200 OK` with a JSON-RPC result when Tidewave is
serving:

```bash
curl -v http://localhost:4000/tidewave/mcp \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"ping"}'
```

End-to-end probe — ask the assistant to run `SELECT 1` via
`execute_sql_query`. A successful round-trip confirms transport, auth (none),
and DB wiring.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `405 Method Not Allowed` | Editor configured as SSE | Reconfigure as HTTP streamable (Tidewave dropped SSE in 0.4.0) |
| `Authenticate` prompt then error | Editor offered auth flow; Tidewave has none | Decline the prompt |
| `Connection refused` | Phoenix not running, or wrong port | `mix phx.server`; confirm `$PORT` matches `endpoint.ex` config |
| Tools missing from `/mcp` list | `plug Tidewave` placed after `code_reloading?` block | Move the plug before `code_reloading?` and restart |
| MCP works on macOS, fails over the network | `allow_remote_access: false` (default) | Set `allow_remote_access: true` on the plug, **only** on trusted networks |
