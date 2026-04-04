# Linear MCP Server Setup

## Table of Contents

- [Claude Code Setup](#claude-code-setup)
- [Authentication](#authentication)
- [Alternative Clients](#alternative-clients)
- [Bearer Token Fallback](#bearer-token-fallback)
- [Troubleshooting](#troubleshooting)
- [OAuth Endpoints](#oauth-endpoints)

## Claude Code Setup

Add the Linear MCP server:

```bash
claude mcp add --transport http linear-server https://mcp.linear.app/mcp
```

Complete authentication:

1. Start a Claude Code session
2. Run `/mcp` to list connected servers
3. The first connection opens a browser for OAuth authorization
4. Authorize Linear access
5. The MCP server is now available for the session

After setup, Linear MCP tools are available directly in Claude Code conversations. Use them for all Linear operations (query issues, create issues, update states, add comments).

## Authentication

The Linear MCP server uses **OAuth 2.1 with Dynamic Client Registration**.

Flow:
1. Client registers dynamically at the registration endpoint
2. User authorizes via browser (PKCE supported, S256)
3. Access token and refresh token returned
4. Refresh tokens maintain long-lived sessions

No manual API key configuration is needed for MCP — OAuth handles everything.

## Alternative Clients

### Claude Desktop

Settings > Connectors > Add Linear connector (built-in support).

### Claude.ai (Team/Enterprise)

Connectors page in settings.

### VS Code

Use `mcp-remote` for clients that do not natively support streamable HTTP:

```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"]
    }
  }
}
```

### Cursor

One-click install from MCP tools directory, or manual configuration with the URL above.

### WSL on Windows

Use the SSE transport endpoint:

```json
{
  "mcpServers": {
    "linear": {
      "command": "wsl",
      "args": ["npx", "-y", "mcp-remote", "https://mcp.linear.app/sse", "--transport sse-only"]
    }
  }
}
```

### Zed

Add to settings under `context_servers`:

```json
{
  "context_servers": {
    "linear": {
      "url": "https://mcp.linear.app/mcp"
    }
  }
}
```

## Bearer Token Fallback

For headless environments, CI pipelines, or scripting where OAuth is not available, use a Linear API key directly:

1. Generate a personal API key in Linear: Settings > API > Personal API Keys
2. Set the environment variable: `export LINEAR_API_KEY=lin_api_...`
3. Use the GraphQL API directly (see `graphql-api.md`) or the nushell client (`scripts/0.1.0/linear.nu`)

The MCP server also accepts Bearer token auth via the `Authorization` header, bypassing the interactive OAuth flow.

## Troubleshooting

### "Internal Server Error" on authentication

Clear cached OAuth state:

```bash
rm -rf ~/.mcp-auth
```

Then retry the connection.

### Node.js version issues

The `mcp-remote` proxy requires a recent Node.js version. Update Node.js if you encounter errors with the npx-based configurations.

### MCP server not responding

Verify the endpoint is reachable:

```bash
curl -I https://mcp.linear.app/mcp
```

Expected: HTTP 401 (requires authentication). If you get a network error, check your internet connection and any proxy settings.

### OAuth flow does not open browser

Ensure your default browser is set and accessible. In headless environments, use the Bearer token fallback instead.

## OAuth Endpoints

For custom integrations or debugging:

| Endpoint | URL |
|----------|-----|
| Authorization | `https://mcp.linear.app/authorize` |
| Token | `https://mcp.linear.app/token` |
| Registration | `https://mcp.linear.app/register` |
| MCP (Streamable HTTP) | `https://mcp.linear.app/mcp` |
| SSE (Legacy) | `https://mcp.linear.app/sse` |

Supported grant types: `authorization_code`, `refresh_token`
Code challenge methods: `plain`, `S256`
